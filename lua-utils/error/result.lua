require 'lua-utils.utils'

local class = require 'lua-utils.class'
local err = require 'lua-utils.error.utils'
local UnwrapError = err.UnwrapError

---Base result class
---@class Result : class
---@field value any
local Result

---@overload fun(value: any): Result
Result = class 'Result'

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

---Failure class
---@class Failure : Result
local Failure

---@overload fun(value: Error): Failure
Failure = class('Failure', Result)

function Failure:initialize(err_instance)
  if not err.is_error_instance(err_instance) then
    error('Expected Error instance, got ' .. dump(err_instance))
  end
  self.value = err_instance
end

function Failure:initialize(err_instance)
  if not err.is_error_instance(err_instance) then
    error('Expected Error instance, got ' .. dump(err_instance))
  end
  self.value = err_instance
end

---Success class
---@class Success : Result
local Success

---@overload fun(value: any): Success
Success = class('Success', Result)

function Success:initialize(value)
  if err.is_error_instance(value) then
    error('Expected a non Error instance, got ' .. dump(value))
  end
  self.value = value
end

Result.Success = Success
Result.Failure = Failure

return Result
