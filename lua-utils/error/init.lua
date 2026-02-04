local class = require 'lua-utils.class'
local err = require 'lua-utils.error.utils'
local Result = require 'lua-utils.error.result'

err.Result = Result
err.Success = Result.Success
err.Failure = Result.Failure

local Success = err.Success
local Failure = err.Failure
local Error = err.Error
local UnwrapError = err.UnwrapError

---Is object a UnwrapError object
---@param obj any
---@return boolean, string?
function err.is_unwrap_error(obj)
  local ok, msg = class.is_object(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, UnwrapError)
  end
end

---Is object a UnwrapError class
---@param obj any
---@return boolean, string?
function err.is_unwrap_error_class(obj)
  local ok, msg = class.is_class(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, UnwrapError)
  end
end

---Is object a UnwrapError instance
---@param obj any
---@return boolean, string?
function err.is_unwrap_error_instance(obj)
  local ok, msg = class.is_instance(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, UnwrapError)
  end
end

---Is object a Result object
---@param obj any
---@return boolean, string?
function err.is_result_class(obj)
  local ok, msg = class.is_class(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, Result)
  end
end

---Is object a Success class
---@param obj any
---@return boolean, string?
function err.is_success_class(obj)
  local ok, msg = class.is_class(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, Success)
  end
end

---Is object a Failure class
---@param obj any
---@return boolean, string?
function err.is_failure_class(obj)
  local ok, msg = class.is_class(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, Failure)
  end
end

---Is object a Result object
---@param obj any
---@return boolean, string?
function err.is_result_instance(obj)
  local ok, msg = class.is_instance(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, Result)
  end
end

---Is object a Success instance
---@param obj any
---@return boolean, string?
function err.is_success_instance(obj)
  local ok, msg = class.is_instance(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, Success)
  end
end

---Is object a Failure instance
---@param obj any
---@return boolean, string?
function err.is_failure_instance(obj)
  local ok, msg = class.is_instance(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, Failure)
  end
end

---Is object a Result object
---@param obj any
---@return boolean, string?
function err.is_result(obj)
  local ok, msg = class.is_object(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, Result)
  end
end

---Is object a Success object
---@param obj any
---@return boolean, string?
function err.is_success(obj)
  local ok, msg = class.is_object(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, Success)
  end
end

---Is object a Failure object
---@param obj any
---@return boolean, string?
function err.is_failure(obj)
  local ok, msg = class.is_object(obj)
  if not ok then
    return false, msg
  else
    return class.inherits(obj, Failure)
  end
end

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

function err:import()
  _G.UnwrapError = self.UnwrapError
  _G.Result = self.Result
  _G.Success = self.Success
  _G.Failure = self.Failure
  _G.err = self
end

return err
