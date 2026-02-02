require 'lua-utils.utils'
local list = require('lua-utils.list')
local dict = require('lua-utils.dict')
local class = require('lua-utils.class')
local types = {}
types.object = class.is_object
types.instance = class.is_instance
types.class = class.is_class

---Is value thread
---@param x any
---@return boolean, string? 
function types.thread(x)
  if x == nil then
    return false, 'expected thread, got nothing'
  else
    local ok
    ok = type(x) == 'thread'
    if not ok then return false, sprintf('expected thread, got %s', x) end
    return true
  end
end

---Is value userdata
---@param x any
---@return boolean, string? 
function types.userdata(x)
  if x == nil then
    return false, 'expected userdata, got nothing'
  else
    local ok
    ok = type(x) == 'userdata'
    if not ok then return false, sprintf('expected userdata, got %s', x) end
    return true
  end
end

---Is value a function
---@param x any
---@return boolean, string? 
function types.fun(x)
  if x == nil then
    return false, 'expected function, got nothing'
  else
    local ok
    ok = type(x) == 'function'
    if not ok then return false, sprintf('expected function, got %s', x) end
    return true
  end
end

types['function'] = types.fun

---Is value a number
---@param x any
---@return boolean, string? 
function types.number(x)
  if x == nil then
    return false, 'expected number, got nothing'
  else
    local ok
    ok = type(x) == 'number'
    if not ok then return false, sprintf('expected number, got %s', x) end
    return true
  end
end

---Is value a table
---@param x any
---@return boolean, string? 
function types.table(x)
  if x == nil then
    return false, 'expected table, got nothing'
  else
    local ok
    ok = type(x) == 'table'
    if not ok then return false, sprintf('expected table, got %s', x) end
    return true
  end
end

---Is value a string?
---@param x any
---@return boolean, string? 
function types.string(x)
  if x == nil then
    return false, 'expected string, got nothing'
  else
    local ok
    ok = type(x) == 'string'
    if not ok then return false, sprintf('expected string, got %s', x) end
    return true
  end
end

---Is value a boolean
---@param x any
---@return boolean, string? 
function types.boolean(x)
  if x == nil then
    return false, 'expected boolean, got nothing'
  else
    local ok
    ok = type(x) == 'boolean'
    if not ok then return false, sprintf('expected boolean, got %s', x) end
    return true
  end
end

---Is value a list
---@param x any
---@return boolean, string? 
function types.list(x)
  local ok, msg = types.table(x)
  if not ok then
    return false, msg
  elseif not list.is_list(x) then
    return false, sprintf('expected list, got dict: %s', x)
  else
    return true
  end
end

---Is value a dict (non-contiguously indexed table)
---@param x any
---@return boolean, string? 
function types.dict(x)
  local ok, msg = types.table(x)
  if not ok then
    return false, msg
  elseif types.list(x) then
    return false, sprintf('expected dict, got list: %s', x)
  else
    return true
  end
end

---Is value a callable (function or table with .call metamethod)
---@param x any
---@return boolean, string? 
function types.callable(x)
  if x == nil then
    return false, 'expected function|callable, got nothing'
  elseif not types.fun(x) and not types.table(x) then
    return false, sprintf('expected function | callable, got %s', x)
  elseif types.fun(x) then
    return true
  elseif types.table(x) then
    local mt = getmetatable(x)
    if mt and mt.__call then
      return types.callable(mt.__call)
    else
      return false, sprintf('expected table with __call, got %s', x)
    end
  else
    return false, 'expected function|callable, got ' .. type(x)
  end
end

---Does value (a table) have a metatable
---@param x any
---@return boolean, string? 
function types.hasmetatable(x)
  local ok, msg = types.table(x)
  if not ok then return false, msg end

  local mt = getmetatable(x)
  if not mt then return false, sprintf('expected table with metatable, got %s', x) end

  return true
end


---Is value a table without metatable?
---@param x any
---@return boolean, string? 
function types.pure_table(x)
  if x == nil then
    return false, 'expected table, got nothing'
  else
    local ok, msg = types.table(x)
    if not ok then
      return false, msg
    elseif types.has_metatable(x) then
      return false, sprintf('expected table without metatable, got %s', x)
    else
      return true
    end
  end
end

---Is value a pure dict? (without a metatable)
---@param x any
---@return boolean, string? 
function types.pure_dict(x)
  if x == nil then
    return false, 'expected dict, got nothing'
  else
    local ok, msg = types.dict(x)
    if not ok then
      return false, msg
    elseif types.has_metatable(x) then
      return false, sprintf('expected dict without metatable, got %s', x)
    else
      return true
    end
  end
end

---Is value a pure list (without metatable)
---@param x any
---@return boolean, string? 
function types.pure_list(x)
  if x == nil then
    return false, 'expected list, got nothing'
  else
    local ok, msg = types.list(x)
    if not ok then
      return false, msg
    elseif types.hasmetatable(x) then
      return false, sprintf('expected list without metatable, got %s', x)
    else
      return true
    end
  end
end

---Does table x include table y? (are y's keys present in x?)
---@param x table
---@param y table
---@return boolean, string? 
function types.includes(x, y)
  for key, _ in pairs(y) do
    if x[key] == nil then
      return false, sprintf('expected x to have attribute %s', key)
    end
  end

  return true
end

---Are types of x and y identical?
---@param x any
---@param y any
---@return boolean
function types.identical(x, y)
  return type(x) == type(y)
end

---Get value type
---Valid types in ascending order of priority:
---  class, instance, pure_list, pure_dict, list, dict, function, callable, type(x)
---@param x any
---@return string 
function types.type(x)
  if types.class(x) then
    return 'class'
  elseif types.instance(x) then
    return 'instance'
  elseif types.pure_list(x) then
    return 'pure_list'
  elseif types.pure_dict(x) then
    return 'pure_dict'
  elseif types.list(x) then
    return 'list'
  elseif types.dict(x) then
    return 'dict'
  elseif types.fun(x) then
    return 'function'
  elseif types.callable(x) then
    return 'callable'
  else
    return type(x)
  end
end

---Is value userdata
---Object precendence:
---> pure_list > pure_dict > (class >= instance >= object) > callable > list > dict > type(child)
---@param child any
---@param parent any
---@return boolean, string? 
function types.is(child, parent)
  if child == nil and parent == nil then
    return true
  elseif types.string(parent) then
    if parent == 'pure_list' then
      return types.pure_list(child)
    elseif parent == 'pure_dict' then
      return types.pure_dict(child)
    elseif parent == 'multimethod' then
      return types.multimethod(child)
    elseif parent == 'exception' then
      return types.exception(child)
    elseif parent == 'class' then
      return types.class(child)
    elseif parent == 'instance' then
      return types.instance(child)
    elseif parent == 'object' then
      return types.object(child)
    elseif parent == 'callable' then
      return types.callable(child)
    elseif parent == 'list' then
      return types.list(child)
    elseif parent == 'dict' then
      return types.dict(child)
    else
      local ok = type(child) == parent
      if not ok then
        return false, sprintf('expected %s, got %s', parent, child)
      else
        return true
      end
    end
  elseif types.object(parent) then
    local ok, msg = types.object(child)
    if not ok then
      return false, msg
    else
      return class.isa(child, parent)
    end
  elseif types.exception(parent) then
    local ok, msg = types.exception(child)
    if not ok then
      return false, msg
    else
      return child:inherits(parent)
    end
  elseif types.callable(parent) then
    return parent(child)
  elseif types.table(parent) then
    local ok, msg = types.table(child)
    if not ok then
      return false, msg
    else
      return types.includes(child, parent)
    end
  else
    local parent_type = types.type(parent)
    local child_type = types.type(child)
    if parent_type ~= child_type then
      return false, sprintf(
        'expected %s, got (%s) %s',
        parent_type,
        child_type,
        child
      )
    else
      return true
    end
  end
end

---Does child inherit parent?
---@param child table
---@param parent table
---@return boolean, string?
function types.inherits(child, parent)
  local ok, msg = types.object(child)
  if not ok then
    return false, ('child: ' .. msg)
  end

  ok, msg = types.object(parent)
  if not ok then
    return false, ('parent: ' .. msg)
  end

  return class.isa(child, parent)
end

---Is object optional?
---@param cond any
---@return fun(x: any): boolean, string?
function types.optional(cond)
  return function(x)
    if x == nil then
      return true
    else
      return types.is(x, cond)
    end
  end
end

---Is object a union of ...?
---@param ... any
---@return fun(x: any): boolean, string?
function types.union(...)
  local signature = {...}
  return function (x)
    local ok, msg
    local msgs = {}

    for _, sig in ipairs(signature) do
      ok, msg = types.is(x, sig)
      if ok then
        return true
      else
        list.append(msgs, msg)
      end
    end

    msg = sprintf('error: \n%s', msgs)
    return false, msg
  end
end

---Is object a union of ...?
---@param x any
---@param ... any
---@return boolean, string?
function types.is_union_of(x, ...)
  local ok, msg
  local msgs = {}
  local signature = {...}

  for _, sig in ipairs(signature) do
    ok, msg = types.is(x, sig)
    if ok then
      return true
    else
      list.append(msgs, msg)
    end
  end

  msg = sprintf('error: \n%s', msgs)
  return false, msg
end

---Is object an optional value?
---@param x any
---@param cond any
---@return boolean, string?
function types.is_optional(x, cond)
  if x == nil then
    return true
  else
    return types.is(x, cond)
  end
end

types.is_opt = types.is_optional
types.opt = types.optional

function types.list_of(what)
  return function (x, assert_)
    return types.is_list_of(x, what, assert_)
  end
end

function types.dict_of(what)
  return function (x, assert_)
    return types.is_dict_of(x, what, assert_)
  end
end

function types.is_list_of(x, what, assert_)
  local ok, msg = types.list(x)
  if not ok then return false, msg end

  for i=1, #x do
    ok, msg = types.is(x[i], what)
    if not ok then
      msg = msg or sprintf('type mismatch (%s)', x)
      if assert_ then
        error(sprintf('error @ element %d: %s', i, msg))
      else
        return false, sprintf('error @ element %d: %s', i, msg)
      end
    end
  end
  return true
end

function types.is_dict_of(x, what, assert_)
  local ok, msg = types.list(x)
  if not ok then return false, msg end

  for key, value in pairs(x) do
    ok, msg = types.is(value, what)
    if not ok then
      msg = msg or sprintf('type mismatch (%s)', x)
      if assert_ then
        error(sprintf('error @ element %s: %s', key, msg))
      else
        return false, sprintf('error @ element %s: %s', key, msg)
      end
    end
  end
  return true
end

function types.table_of(key_f, value_f)
  return function (x, assert_)
    return types.is_table_of(x, key_f, value_f, assert_)
  end
end

function types.is_table_of(x, key_f, value_f, assert_)
  local ok, msg = types.table(x)
  if not ok then return false, msg end

  for key, value in pairs(x) do
    ok, msg = types.is(key, key_f)
    if not ok then
      msg = msg or 'type mismatch'
      msg = sprintf('error @ key %s: ', key, msg)
      if assert_ then
        error(msg)
      else
        return false, msg
      end
    end

    ok, msg = types.is(value, value_f)
    if not ok then
      msg = msg or 'type mismatch'
      msg = sprintf('error @ value @ key %s: %s', key, msg)
      if assert_ then
        error(msg)
      else
        return false, msg
      end
    end
  end

  return true
end

---Type assertion 
---usage:
---> types.assert.<prefix>(<value>, <condition (boolean)>)
---> types.assert(<value>, <condition>, <name>)

---Assert type of a value
---@param x any
---@param cond any
---@param name? string
function types.assert(x, cond, name)
  --- Stub method
  print(x, cond, name)
end

types.assert = {}
setmetatable(types.assert, types.assert)

function types.assert:__call(x, cond, name)
  if name then
    local ok, msg = types.string(name)
    if not ok then error(sprintf('%s: %s', name, msg)) end
  end

  local ok, msg = types.is(x, cond)
  if not ok then
    msg = msg or ''
    if name then
      error(name .. ': ' .. msg)
  else
      error(msg)
    end
  else
    return true
  end
end

function types.assert:__index(name)
  return function (x, cond)
    return types.assert(x, cond, name)
  end
end

---Assert a value with a type condition with the error message prefixed by `name`
---@param name string
---@param x any
---@param cond any
function types.assert.assert(name, x, cond)
  return types.assert[name](x, cond)
end

---Assert all type assertions
---@param elems table<string|number,any>
function types.assert.all(elems)
  for key, x in pairs(elems) do
    local cond = x[1]
    local value = x[2]
    types.assert.assert(tostring(key), value, cond)
  end
end

---Assert some type assertions
---@param elems table<string|number,any>
function types.assert.some(elems)
  local ind = 0
  local ks = dict.keys(elems)
  local n = #ks

  for i=1, n do
    local k = ks[i]
    local x = elems[k]

    if types.is(x[2], x[1]) then
      return true
    else
      ind = ind + 1
    end
  end

  if n == ind then
    error(sprintf('Type assertions failed for: %s', list.join(ks, ', ')))
  end
end

function types.multimethod(x)
  local ok, msg = types.table(x)
  if not ok then
    return false, msg
  end

  ok, msg = types.hasmetatable(x)
  if not ok then
    return false, msg
  end

  local mt = getmetatable(x)
  if mt ~= x then
    return false, sprintf('expected multimethod, got %s', x)
  elseif not (x.name and x.methods and x.__call) then
    return false, sprintf('expected multimethod, got %s', x)
  else
    return types.callable(x.__call)
  end
end

function types.exception(x)
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

types.has_metatable = types.hasmetatable
types.hasmt = types.hasmetatable
types.U = types.union
types.O = types.optional
types.n = types.number
types.t = types.table
types.th = types.thread
types.s = types.string
types.b = types.boolean
types.u = types.userdata
types.f = types.fun
types.c = types.callable
types.o = types.object
types.cls = types.class
types.i = types.instance
types.pt = types.pure_table
types.pl = types.pure_list
types.pd = types.pure_dict
types.l = types.list
types.d = types.dict
types.m = types.multimethod
types.e = types.exception

return types
