require 'lua-utils.utils'

local list = require 'lua-utils.list'
local class = require 'lua-utils.class'

---Error handling and creation function
local err = {}

---Base error class
---@class Error : class
local Error

---@overload fun(...): Error
Error = class 'Error'

function Error:initialize(...)
  self.args = { ... }
end

---Get string representation of error message or dump
---@return string
function Error:message()
  local message = self.args

  if #message == 1 then
    message = message[1]
  else
    message = dump(message)
  end

  return message
end

---Convert error object to a string (for use with luajit)
---@return string
function Error:as_string()
  local parents = class.get_parents(self)
  if parents then
    parents = list.map(parents, function(x)
      return x.__name
    end)
    parents = table.concat(parents, '.')
    return parents .. '.' .. self.__name .. ': ' .. self:message()
  else
    return self.__name .. ': ' .. self:message()
  end
end

---Raise error
function Error:throw(tbl)
  if tbl then
    error(self)
  else
    error(self:as_string())
  end
end

---Base result class
---@class Result : class
---@field value any
local Result

---@overload fun(value: any): Result
Result = class 'Result'

---Is object a result instance and Success instance or a Failure instance
---@param obj any
---@return boolean
function Result.is_result(obj)
  if class.is_instance(obj) then
    return obj.__name == 'Success' or obj.__name == 'Failure' or obj.__name == 'Result'
  else
    return false
  end
end

---Failure class
---@class Failure : Result
local Failure

---@overload fun(value: Error): Failure
Failure = class('Failure', Result)

---Success class
---@class Success : Result
local Success

---@overload fun(value: any): Success
Success = class('Success', Result)

---Create a new error object
---@param name string
---@param parent? Error
---@return Error
function err.new(name, parent)
  if not name:match('Error') then
    name = name .. 'Error'
  end

  parent = parent or Error
  local cls = class(name, parent)

  ---@type Error
  return cls
end

---Is object an error object?
---@param obj any
---@return boolean,string?
function err.is_error(obj)
  if class.is_object(obj) then
    local ok = obj.__name:match('Error') ~= nil
    if not ok then
      return false, "Expected Error object, got " .. obj.__name
    else
      return true
    end
  end

  return false, 'Expected Error object, got ' .. dump(obj)
end

---Is obj an error class?
---@param obj any
---@return boolean,string?
function err.is_error_class(obj)
  if class.is_class(obj) then
    local ok = obj.__name:match('Error') ~= nil
    if not ok then
      return false, "Expected Error class, got " .. obj.__name
    else
      return true
    end
  end

  return false, 'Expected Error class, got ' .. dump(obj)
end

---Is object an error instance?
---@param obj any
---@return boolean,string?
function err.is_error_instance(obj)
  if class.is_instance(obj) then
    local ok = obj.__name:match('Error') ~= nil
    if not ok then
      return false, "Expected Error instance, got " .. obj.__name
    else
      return true
    end
  end

  return false, 'Expected Error instance, got ' .. dump(obj)
end

---Returned by Failure | Success instance on unwrapping
---@class UnwrapError : Error
---@field error Error
local UnwrapError = err.new('UnwrapError')

function UnwrapError:initialize(error_instance)
  assert(
    err.is_error_instance(error_instance),
    "Expected Error instance, got " .. dump(error_instance)
  )

  self.error = error_instance
end

---Throw underlying error
---@param tbl? boolean Don't convert object to string
function UnwrapError:throw(tbl)
  if tbl then
    error(self.error)
  else
    error(self.error:as_string())
  end
end

---Is object an unwrap error
---@param obj any
---@return boolean, string?
function UnwrapError.is_unwrap_error(obj)
  local ok, msg = err.is_error(obj)
  if not ok then
    return false, msg
  elseif obj.__name == 'UnwrapError' then
    return true
  else
    return false, 'Expected UnwrapError, got ' .. dump(obj)
  end
end

UnwrapError.is = UnwrapError.is_unwrap_error

function Result:initialize(value)
  self.value = value
end

---Is value not an error value
---@return boolean
function Result:ok()
  return not err.is_error_instance(self.value)
end

---Is value an error value
---@return boolean
function Result:not_ok()
  return err.is_error_instance(self.value)
end

---Unwrap value and raise/return error
---@param should_pcall? boolean return UnwrapError on failure if true
---@param tbl? boolean Throw table instead of string
---@return any
function Result:unwrap(should_pcall, tbl)
  tbl = (tbl == nil and true) or false
  if not self:ok() then
    if should_pcall then
      return UnwrapError(self.value)
    else
      UnwrapError(self.value):throw(tbl)
    end
  else
    return self.value
  end
end

---Call function with underlying value if value is not error
---@param f fun(value: any): any
---@param should_pcall? boolean
---@param tbl? boolean
function Result:unwrap_and(f, should_pcall, tbl)
  value = self:unwrap(should_pcall, tbl)
  if UnwrapError.is(value) then
    return value
  else
    return f(value)
  end
end

---Is object a success instance?
---@param obj any
---@return boolean, string?
function Result.is_success(obj)
  local ok, msg = class.is_object(obj)
  if not ok then
    return false, msg
  end

  ok = obj.__name == 'Success'
  if not ok then
    return false, "Expected Success, got " .. dump(obj)
  else
    return true
  end
end

---Is object a failure instance?
---@param obj any
---@return boolean, string?
function Result.is_failure(obj)
  local ok, msg = class.is_object(obj)
  if not ok then
    return false, msg
  end

  ok = obj.__name == 'Failure'
  if not ok then
    return false, "Expected Failure, got " .. dump(obj)
  else
    return true
  end
end

function Success:initialize(value)
  if err.is_error_instance(value) then
    error('Expected a non Error value, got ' .. dump(value))
  end
  self.value = value
end

function Failure:initialize(err_instance)
  if not err.is_error_instance(err_instance) then
    error('Expected Error instance, got ' .. dump(err_instance))
  end
  self.value = err_instance
end

err.is_success = Result.is_success
err.is_failure = Result.is_failure
err.is_result = Result.is_result
err.is_unwrap_error = UnwrapError.is_unwrap_error

---@class errUnwrapOpts
---@field pcall? boolean
---@field ok? fun(x: any): any
---@field not_ok? fun(x: UnwrapError): any
---@field tbl? boolean (default: true) Use table when raising error

---@param value Result | UnwrapError | Error
---@param opts errUnwrapOpts
---@return any
function err.unwrap(value, opts)
  opts = opts or {}
  local should_pcall = opts.pcall
  local on_ok = opts.ok
  local on_not_ok = opts.not_ok
  local tbl = opts.tbl

  if on_not_ok then
    should_pcall = true
  end

  if err.is_unwrap_error(value) then
    if should_pcall then
      if on_not_ok then
        return on_not_ok(value)
      else
        return value --[[@type UnwrapError]]
      end
    else
      value --[[@type UnwrapError]]:throw(tbl)
    end
  elseif err.is_error(value) then
    if should_pcall then
      if on_not_ok then
        return on_not_ok(UnwrapError(value --[[@type Error]]))
      else
        return UnwrapError(value --[[@type Error]])
      end
    else
      value --[[@type Error]]:throw(tbl)
    end
  elseif err.is_success(value) then
    if on_ok then
      return on_ok(value --[[@type Success]]:unwrap(should_pcall, tbl))
    else
      return value --[[@type Success]]:unwrap(should_pcall, tbl)
    end
  elseif err.is_failure(value) then
    if on_not_ok then
      return on_not_ok(value:unwrap(should_pcall, tbl))
    else
      return value --[[@type Failure]]:unwrap(should_pcall, tbl)
    end
  elseif on_ok then
    return on_ok(value)
  else
    return value
  end
end

---Return a function that strictly returns a success or a failure
---@param f fun(...): any
---@return fun(...): Success | Failure
function err.safe(f)
  return function(...)
    local ok, result = pcall(f, ...)
    if not ok then
      if err.is_failure(result) then
        return result
      elseif err.is_unwrap_error(result) then
        local failure = Failure(result.error)
        return failure
      elseif err.is_error(result) then
        return Failure(result)
      else
        return Failure(Error(result))
      end
    elseif err.is_result(result) then
      return result
    elseif err.is_unwrap_error(result) then
      return Failure(result.error)
    elseif err.is_error(result) then
      return Failure(result)
    else
      return Success(result)
    end
  end
end

function err.add_globals()
  _G.UnwrapError = UnwrapError
  _G.Result = Result
  _G.Success = Success
  _G.Failure = Failure
  _G.err = err
end

err.Result = Result
err.UnwrapError = UnwrapError
err.Success = Success
err.Failure = Failure


-- local function error_throwing()
--   error(Error(1))
--   -- error("Something went wrong")
-- end
--
-- pp(err.unwrap(err.safe(error_throwing)(), {ok = function ()
--   print('success')
-- end, not_ok = function (unwrap_error)
--     pp(unwrap_error.error)
-- end}))
--

return err
