require 'lua-utils.metatable'
require 'lua-utils.utils'

local is = {}

---@param obj any
---@return boolean
function is.object(obj)
  if type(obj) ~= 'table' then
    return false
  elseif not obj.__object then
    return false
  else
    return true
  end
end

---Is table an instance
---@param obj table
---@return boolean, string?
function is.instance(obj)
  if type(obj) ~= 'table' then
    return false
  elseif not obj.__object then
    return false
  elseif not obj.__instance then
    return false
  else
    return true
  end
end

---Is table an class?
---@param obj table
---@return boolean, string?
function is.class(obj)
  if type(obj) ~= 'table' then
    return false
  elseif not obj.__object then
    return false
  elseif obj.__instance then
    return false
  else
    return true
  end
end

---Is value thread
---@param x any
---@return boolean, string?
function is.callable(x)
  return callable(x, false)
end

---Is value number
---@param x any
---@return boolean, string?
function is.number(x)
  if x == nil then
    return false
  elseif type(x) ~= 'number' then
    return false
  else
    return true
  end
end

---Is value string
---@param x any
---@return boolean, string?
function is.string(x)
  if x == nil then
    return false
  elseif type(x) ~= 'string' then
    return false
  else
    return true
  end
end

---Is value userdata
---@param x any
---@return boolean, string?
function is.userdata(x)
  if x == nil then
    return false
  elseif type(x) ~= 'userdata' then
    return false
  else
    return true
  end
end

---Is value fun
---@param x any
---@return boolean, string?
function is.fun(x)
  if x == nil then
    return false
  elseif type(x) ~= 'function' then
    return false
  else
    return true
  end
end

is['function'] = is.fun

---Is value thread
---@param x any
---@return boolean, string?
function is.thread(x)
  if x == nil then
    return false
  elseif type(x) ~= 'thread' then
    return false
  else
    return true
  end
end

---Is value thread
---@param x any
---@return boolean, string?
function is.table(x)
  if x == nil then
    return false
  elseif type(x) ~= 'table' then
    return false
  else
    return true
  end
end

---Does value (a table) have a metatable
---@param x any
---@return boolean, string?
function is.hasmetatable(x)
  if not is.table(x) then
    return false
  elseif not getmetatable(x) then
    return false
  else
    return true
  end
end

---Is value a table without metatable?
---@param x any
---@return boolean, string?
function is.pure_table(x)
  if x == nil then
    return false, 'expected table, got nothing'
  else
    local ok, msg = is.table(x)
    if not ok then
      return false, msg
    elseif is.hasmetatable(x) then
      return false, sprintf('expected table without metatable, got %s', x)
    else
      return true
    end
  end
end

---Is value a dict without metatable?
---@param x any
---@return boolean, string?
function is.dict(x)
  local n = 0
  for _ in pairs(x) do n = n + 1 end
  local ok = n ~= #x
  return ok
end

---Is value a dict (non-contiguously indexed table)
---@param x any
---@return boolean, string?
function is.pure_dict(x)
  return is.dict(x) and not is.hasmetatable(x)
end

---Is value a list (non-contiguously indexed table)
---@param x any
---@return boolean, string?
function is.pure_list(x)
  return is.list(x) and not is.hasmetatable(x)
end

---Is value a list without metatable?
---@param x any
---@return boolean, string?
function is.list(x)
  local i = 0
  for _ in pairs(x) do
    i = i + 1
    if x[i] == nil then return false end
  end

  return true
end

---Does table x include table y? (are y's keys present in x?)
---@param x table
---@param y table
---@return boolean, string?
function is.includes(x, y)
  for key, _ in pairs(y) do
    if x[key] == nil then
      return false, key
    end
  end

  return true
end

---Are is of x and y identical?
---@param x any
---@param y any
---@return boolean
function is.identical(x, y)
  return type(x) == type(y)
end

is.with_metatable = is.hasmetatable
is.has_metatable = is.hasmetatable

return is
