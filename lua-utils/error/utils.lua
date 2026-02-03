require 'lua-utils.utils'

local list = require 'lua-utils.list'
local class = require 'lua-utils.class'

---Base error class
---@class Error : class
local Error

---@overload fun(...): Error
Error = class 'Error'

function Error:initialize(message)
  self.message = message
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
    return sprintf('%s.%s: "%s"', parents, self.__name, self.message)
  else
    return self.__name .. ': "' .. dump(self.message) .. '"'
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

---Important error handling functions
local err = {Error = Error}
setmetatable(err, err)

function err:__call(name, parent)
  if not name:match('Error') then
    name = name .. 'Error'
  end

  parent = parent or Error
  local cls = class(name, parent)
  cls.name = name

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

---@class UnwrapError : Error
local UnwrapError = err('UnwrapError', Error)
err.UnwrapError = UnwrapError

function UnwrapError:initialize(exception)
  assert(err.is_error_instance(exception))
  Error.initialize(self, exception)
end

function UnwrapError:throw(tbl)
  if tbl then
    error(self.message)
  else
    error(self.message:as_string())
  end
end

return err
