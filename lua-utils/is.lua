require 'lua-utils.metatable'
require 'lua-utils.utils'
require 'lua-utils.class'

local is = bless {}

is.callable = callable

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
---@return boolean
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
---@return boolean
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
---@return boolean
function is.callable(x)
  return callable(x)
end

---Is value number
---@param x any
---@return boolean
function is.number(x)
  return type(x) == 'number'
end

---Is value string
---@param x any
---@return boolean
function is.string(x)
  return type(x) == 'string'
end

---Is value userdata
---@param x any
---@return boolean
function is.userdata(x)
  return type(x) == 'userdata'
end

---Is value fun
---@param x any
---@return boolean
function is.fun(x)
  return type(x) == 'function'
end

is['function'] = is.fun

---Is value thread
---@param x any
---@return boolean
function is.thread(x)
  return type(x) == 'thread'
end

---Is value thread
---@param x any
---@return boolean
function is.table(x)
  return type(x) == 'table'
end

---@param x any
---@return boolean
function is.undefined(x)
  return x == nil
end

---@param x any
---@return boolean
function is.defined(x)
  return x ~= nil
end

---Does value (a table) have a metatable
---@param x any
---@return boolean
function is.metatable(x)
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
---@return boolean
function is.pure_table(x)
  if x == nil then
    return false
  else
    local ok = is.table(x)
    if not ok then
      return false
    elseif is.metatable(x) then
      return false
    else
      return true
    end
  end
end

---Is value a dict without metatable?
---@param x any
---@return boolean
function is.dict(x)
  if not is.table(x) then
    return false
  end

  local n = 0
  for _ in pairs(x) do n = n + 1 end
  local ok = n ~= #x
  return ok
end

---Is value a dict (non-contiguously indexed table)
---@param x any
---@return boolean
function is.pure_dict(x)
  return is.dict(x) and not is.metatable(x)
end

---Is value a list (non-contiguously indexed table)
---@param x any
---@return boolean
function is.pure_list(x)
  return is.list(x) and not is.metatable(x)
end

---Is value a list without metatable?
---@param x any
---@return boolean
function is.list(x)
  if not is.table(x) then
    return false
  end

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
---@return boolean
function is.includes(x, y)
  if not is.table(x) or not is.table(y) then
    return false
  end

  for key, _ in pairs(y) do
    if x[key] == nil then
      return false
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

---Does x inherit from y
---@param x any
---@param y any
---@return boolean
function is.inherits(x, y)
  local x_is_obj, y_is_obj = class.is_object(x), class.is_object(y)
  if x_is_obj and y_is_obj then
    return class.inherits(x, y)
  else
    return false
  end
end

---Is x a parent of y
---@param x any
---@param y any
---@return boolean
function is.parent(x, y)
  return is.inherits(y, x)
end

---Is y a parent of x
---@param x any
---@param y any
---@return boolean
function is.child(x, y)
  return is.inherits(x, y)
end

---@param x any
---@param y any
---@return boolean
function is.is(x, y)
  local x_type = type(x)
  if is.object(y) then
    if not is.child(x, y) then return false end
  elseif callable(y) then
    if not y(x) then return false end
  elseif is.string(y) then
    if is.object(x) then
      if not x.__name == y then return false end
    elseif is[y] then
      if not is[y](x) then return false end
    elseif x_type ~= y then
      return false
    end
  elseif x_type ~= type(y) then
    return false
  end

  return true
end

---Is x a union of ... <is>?
---@param x any
---@param ... any
---@return boolean
function is.union(x)
  return function(...)
    for _, guard in ipairs { ... } do
      if not is.is(x, guard) then return false end
    end
    return true
  end
end

---Is x a union of ... <is>?
---@param x any
---@param ... any
---@return boolean
function is.union_of(x, ...)
  for _, guard in ipairs { ... } do
    if not is.is(x, guard) then return false end
  end
  return true
end

---@param x []any
---@param spec any
---@return boolean
function is.list_of(x, spec)
  assert(is.list(x), dump { expected = 'list', got = type(x) })

  for i = 1, #x do
    if not is.is(x[i], spec) then
      return false
    end
  end

  return true
end

---@param x table<string|number, any>
---@param spec any
---@return boolean
function is.dict_of(x, spec)
  assert(is.dict(x), dump { expected = 'dict', got = type(x) })

  for _, value in pairs(x) do
    if not is.is(value, spec) then return false end
  end

  return true
end

---@param x table<string|number, any>
---@param key_spec any
---@param value_spec any
---@return boolean
function is.table_of(x, key_spec, value_spec)
  assert(is.table(x), dump { expected = 'table', got = type(x) })

  for key, value in pairs(x) do
    if not is.is(key, key_spec) then return false end
    if not is.is(value, value_spec) then return false end
  end

  return true
end

---@param x any
---@param spec? any
---@return boolean
function is.optional(x, spec)
  if x == nil then
    return true
  elseif x == spec then
    return true
  else
    return is.is(x, spec)
  end
end

---@param x any
---@param y any
---@return boolean
function is:__call(x, y)
  return is.is(x, y)
end

---Is union object
---@param x any
---@return boolean, string?
function is.union_object(x)
  local ok = is.table(x)
  if not ok then
    return false
  elseif x.__union and x.__call then
    return true
  else
    return false
  end
end

is.opt = is.optional

return is
