require 'lua-utils.metatable'
require 'lua-utils.utils'

local copy = require 'lua-utils.copy'
local list = require('lua-utils.list')
local class = require('lua-utils.class')
local types = {}

---@param x any
---@return boolean
function types.callable(x)
  return callable(x, true)
end

---Is value thread
---@param x any
---@return boolean, string?
function types.thread(x)
  if x == nil then
    return false, 'expected thread, got nothing'
  else
    local ok
    ok = type(x) == 'thread'
    if not ok then return false, sprintf('expected thread, got %s [%s]', x, type(x)) end
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
    if not ok then return false, sprintf('expected userdata, got %s [%s]', x, type(x)) end
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
    if not ok then return false, sprintf('expected function, got %s [%s]', x, type(x)) end
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
    if not ok then return false, sprintf('expected number, got %s [%s]', x, type(x)) end
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
    if not ok then return false, sprintf('expected table, got %s [%s]', x, type(x)) end
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
    if not ok then return false, sprintf('expected string, got %s [%s]', x, type(x)) end
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
    if not ok then return false, sprintf('expected boolean, got %s [%s]', x, type(x)) end
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

---Does value (a table) have a metatable
---@param x any
---@return boolean, string?
function types.hasmetatable(x)
  local ok, msg = types.table(x)
  if not ok then return false, msg end

  local mt = getmetatable(x)
  if not mt then return false, sprintf('expected table with metatable, got %s [%s]', x, type(x)) end

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
    elseif types.metatable(x) then
      return false, sprintf('expected table without metatable, got %s [%s]', x, type(x))
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
    elseif types.metatable(x) then
      return false, sprintf('expected dict without metatable, got %s [%s]', x, type(x))
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
      return false, sprintf('expected list without metatable, got %s [%s]', x, type(x))
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
  local ok, msg = types.table(x)
  if not ok then
    return false, ('x: ' .. msg)
  end

  ok, msg = types.table(y)
  if not ok then
    return false, ('y: ' .. msg)
  end

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
  if class.is_object(x) then
    return x.__name
  elseif types.pure_table(x) then
    return 'pure_list'
  elseif types.pure_dict(x) then
    return 'pure_dict'
  elseif types.pure_table(x) then
    return 'pure_table'
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

typeof = types.type

---@param x any
---@return boolean
function types.object(x)
  return class.is_object(x, true)
end

---@param x any
---@return boolean
function types.instance(x)
  return class.is_instance(x, true)
end

---@param x any
---@return boolean
function types.class(x)
  return class.is_class(x, true)
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

---Is value userdata
---Object precendence:
---> pure_list > pure_dict > (class >= instance >= object) > callable > list > dict > type(child)
function types.is(child, parent)
  if child == nil and parent == nil then
    return true
  elseif child == parent then
    return true
  end

  if types[parent] then
    local ok, msg = types[parent](child)
    if not ok then
      return false, msg
    else
      return true, nil
    end
  elseif class.is_object(parent) then
    if type(child) == 'table' then
      local ok, msg = class.is_child(child, parent)
      if not ok then
        return false, msg
      else
        return true, nil
      end
    else
      return false, sprintf('expected object, got %s [table]', child)
    end
  elseif types.union_object(parent) then
    return parent(child)
  elseif callable(parent) then
    local ok, msg = parent(child)
    if not ok then
      msg = msg or sprintf('assertion failure: callable[%s](%s)', parent, child)
      return false, msg
    end
  elseif type(parent) == 'string' then
    if class.is_object(child) then
      local ok = child.__name == parent
      if not ok then
        return false, sprintf('expected %s, got %s [%s]', parent, child, child.__name)
      else
        return true, nil
      end
    end

    local child_type = types.type(child)
    local parent_type = types.type(parent)

    if child_type == parent_type then
      return true, nil
    else
      return false, sprintf('expected %s, got %s [%s]', parent_type, child, child_type)
    end
  end

  return types.is(child, types.type(parent))
end

---Is object a union of ...?
---@param ... any
---@return (fun(x: any): boolean, string?)
function types.union(...)
  local signature = { ... }
  local fn = bless({
    __union = true,
    prefix = nil,
    signature = signature,
    make_msg = function(self, msg)
      local all_str = true
      local sigs = self.signature

      for i = 1, #sigs do
        all_str = type(sigs[i]) == 'string'
      end

      if all_str then
        self.prefix = sprintf("expected %s, got", table.concat(sigs, "|"))
      else
        local msgs = list.map(sigs, types.type)
        msgs = table.concat(msgs, "|")
        self.prefix = sprintf("expected %s, got", table.concat(msgs, "|"))
      end

      return sprintf('%s %s', self.prefix, msg)
    end,
  }, {
      ---@param self table
      ---@param x any
      ---@return boolean, string?
    __call = function(self, x)
      signature = copy.copy(self.signature)
      for i, sig in ipairs(signature) do
        if types.union_object(sig) then
          local ok, _ = sig(x)
          if ok then
            return true
          else
            list.remove(self.signature, i)
            list.extend(self.signature, sig.signature)
          end
        elseif types.is(x, sig) then
          return true
        end
      end

      local msg = self:make_msg(sprintf('%s [%s]', x, types.type(x)))
      ---@diagnostic disable-next-line
      return false, msg
    end,
  })

  ---@type (fun(x: any): boolean, string?)
  return fn
end

---Is union object
---@param x any
---@return boolean, string?
function types.union_object(x)
  local ok = types.table(x)
  if not ok then
    return false, sprintf('expected union object, got %s [%s]', x, types.type(x))
  elseif x.__union and x.__call then
    return true, nil
  else
    return false, sprintf('expected union object, got %s [%s]', x, types.type(x))
  end
end

---Is object a union of ...?
---@param x any
---@param ... any
---@return boolean, string?
function types.is_union_of(x, ...)
  local f = types.union(...)
  return f(x)
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

function types.is_list_of(x, what, assert_)
  local ok, msg = types.list(x)
  if not ok then return false, msg end

  for i = 1, #x do
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
  local ok, msg = types.dict(x)
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

function types.multimethod(x)
  local ok, msg = types.object(x)
  if not ok then
    return false, msg
  end

  if x.__name == 'multimethod' then
    return true
  end

  local parents = class.parents(x)
  for i = 1, #parents do
    if parents[i] == 'multimethod' then
      return true
    end
  end

  return false, 'expected multimethod, got ' .. dump(x)
end

----Is x undefined
---@param x any
---@return boolean, string?
function types.undefined(x)
  local ok = undefined(x)
  if not ok then
    return false, 'expected nil, got ' .. dump(x)
  else
    return true
  end
end

----Is x defined
---@param x any
---@return boolean, string?
function types.defined(x)
  local ok = undefined(x)
  if not ok then
    return false, 'expected non-nil, got ' .. dump(x)
  else
    return true
  end
end

---Import things in global domain
function types:import()
  _G.types = self
end

types.metatable = types.hasmetatable
types.def = types.defined
types.undef = types.undefined

return types
