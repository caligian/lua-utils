require 'lua-utils.utils'

local tuple = require 'lua-utils.tuple'
local copy = require 'lua-utils.copy'
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

function Error:message()
  local message = self.args

  if #message == 1 then
    message = message[1]
  else
    message = dump(message)
  end

  return message
end

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
function Result.is_result(obj)
  return
      class.is_instance(obj)
      and obj.__name == 'Success'
      or obj.__name == 'Failure'
end

---Failure class
---@class Failure : Result
---@field value Error
local Failure

---@overload fun(value: Error): Failure
Failure = class('Failure', Result)

---Success class
---@class Success : Result
---@field value any
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
---@return boolean
function err.is_error(obj)
  if class.is_object(obj) then
    return obj.__name:match('Error') ~= nil
  end

  return false
end

---Is object an error instance?
---@param obj any
---@return boolean
function err.is_error_instance(obj)
  if class.is_instance(obj) then
    return obj.__name:match('Error') ~= nil
  end

  return false
end

---Is object an error instance?
---@param obj any
---@return boolean
function err.is_error_class(obj)
  if class.is_class(obj) then
    return obj.__name:match('Error') ~= nil
  end

  return false
end

---Returned by Failure | Success instance on unwrapping
---@class UnwrapError : Error
---@field error Error
local UnwrapError = err.new('UnwrapError')

function UnwrapError:initialize(error_instance)
  assert(
    err.is_error_instance(error_instance),
    "Expected error instance, got " .. dump(error_instance)
  )

  self.error = error_instance
end

function UnwrapError:throw(tbl)
  if tbl then
    error(self.error)
  else
    error(self.error:as_string())
  end
end

function UnwrapError.is_unwrap_error(obj)
  return err.is_error_instance(obj) and obj.__name == 'UnwrapError'
end

function Result:initialize(value)
  self.value = value
end

function Result:ok()
  return not err.is_error_instance(self.value)
end

function Result:not_ok()
  return err.is_error_instance(self.value)
end

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

function Result:unwrap_and(f, should_pcall)
  value = self:unwrap(should_pcall)
  if UnwrapError.is_unwrap_error(value) then
    return value
  else
    return f(value)
  end
end

function Result:is_success()
  return self.__name == 'Success'
end

function Result:is_failure()
  return self.__name == 'Failure'
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

function err.unwrap(value, should_pcall)
  if err.is_unwrap_error(value) then
    if should_pcall then
      return value
    else
      error(value)
    end
  elseif err.is_error(value) then
    if should_pcall then
      return UnwrapError(value)
    else
      error(value)
    end
  end

  assert(
    err.is_success(value) or err.is_failure(value),
    'value: Expected Success or Failure instance, got ' .. dump(value)
  )

  return value:unwrap(should_pcall)
end

function err.unwrap_and(value, f, should_pcall)
  value = err.unwrap(value, should_pcall)
  if err.is_unwrap_error(value) then
    return value
  else
    return f(value)
  end
end

function err.safe(f, ...)
  local outer = tuple.pack(...)
  return function(...)
    outer = copy.copy(outer)
    local inner = tuple.pack(...)
    list.append(outer, inner)
    local ok, result = pcall(f, unpack(inner))

    if not ok then
      if err.is_failure(result) then
        return result
      elseif err.is_error(result) then
        return Failure(result)
      else
        return Failure(Error(result))
      end
    elseif err.is_result(result) then
      return result
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

err.UnwrapError = UnwrapError
err.Success = Success
err.Failure = Failure

return err
