require 'lua-utils.utils'
local types = require 'lua-utils.types'
local list = require 'lua-utils.list'
local copy = require 'lua-utils.copy'

exception = {}
setmetatable(exception, exception)

function exception:__call(name, parent)
  local obj = { name = name, parent = parent, type = 'exception' }
  obj.throw = exception.throw
  obj.inherits = exception.inherits
  obj.__call = obj.throw
  obj.__index = parent
  obj.__tostring = exception.__tostring
  obj.throw_unless = exception.throw_unless
  obj.throw_when = exception.throw_when
  setmetatable(obj, obj)

  return obj
end

function exception:throw(msg, level)
  if msg then
    self = copy(self)
    self.msg = msg
    local name = tostring(self)
    self.__tostring = function (_)
      return name .. ': ' .. msg
    end
    setmetatable(self, self)
  end

  error(self, level or 2)
end

function exception:__tostring()
  local parents = nil
  local parent = self.parent

  if parent then
    parents = {}
    parents[#parents+1] = parent.name

    while parent do
      parent = parent.parent
      if parent then
        parents[#parents+1] = parent.name
      end
    end

    parents = list.reverse(parents)
    parents = list.join(parents, ".")
  end

  if parents then
    return sprintf('%s.%s', parents, self.name)
  else
    return self.name
  end
end

---Is exception a descendant of parent?
---@param parent table
---@return boolean
function exception:inherits(parent)
  if not self.parent then
    return false
  elseif not parent then
    return false
  elseif parent == self.parent then
    return true
  end

  parent = parent.parent
  while parent do
    if not parent then
      return false
    elseif parent == self.parent then
      return true
    else
      parent = self.parent
    end
  end

  return false
end

---Is table an exception?
---@param x table
---@return boolean, string?
function exception.is_exception(x)
  local ok, msg = types.t(x)
  if not ok then
    return false, msg
  end

  ok, msg = types.hasmetatable(x)
  if not ok then
    return false, msg
  end

  ok, msg = types.c(x)
  if not ok then
    return false, msg
  end

  ok = x.type == 'exception'
  if not ok then
    return false, sprintf('expected exception, got %s', x)
  end

  return true
end

function exception:throw_when(cond, msg)
  if cond then
    self:throw(msg)
  else
    return true
  end
end

function exception:throw_unless(cond, msg)
  if not cond then
    self:throw(msg)
  else
    return true
  end
end

return exception
