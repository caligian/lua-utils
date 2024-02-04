require 'lua-utils.types.utils'

--- Define a ns which is essentially a table with functions and other attributes
--- Contains several useful methods to query the properties of the ns
--- You can also set metatable attributes directly via with the ns table
--- Useful for skeleton classes
--- @class ns
--- @overload fun(name?: string): ns
ns = {}
local ns_mt = { __tostring = dump, type = "ns"}
mtset(ns--[[@as table]], ns_mt)

function ns_mt:__call(name)
  return copy.table(ns, {metatable=true})
end

function ns_mt:__newindex(key, value)
  if package:is_valid_event(key) then
    mtset(self, key, value)
  else
    rawset(self, key, value)
  end
end

function ns_mt:__index(key)
  if package:is_valid_event(key) then
    return mtget(self, key)
  end
end

--- Get ns name if defined
--- @return string?
function ns:get_ns_name()
  return mtget(self, "name")
end

--- Include this table (basically merge the table)
--- @param other table
--- @return ns
function ns:include(other)
  return dict.merge(mod,  other)
end

--- Get all callables in a dict with their names
--- @return table<any,function>
function ns:get_methods()
  return dict.filter(self, function(_, value)
    return is_callable(value)
  end)
end

--- Get method as a function or an instance method
--- @param name any
--- @param inst_method? boolean instance method as f(self, ...)
--- @return function?
--- @return string? message failure message
function ns:get_method(name, inst_method)
  local f = self[name]
  if not f then
    return nil, "invalid method name " .. dump(fn)
  end

  assert(is_callable(f))

  if inst_method then
    return function (...)
      return f(self, ...)
    end
  end

  return function(...)
    return fn(self, ...)
  end
end

--- Check if self is a valid ns
--- @param other table Check if other is the same ns as self
--- @return table?, string?
function ns:is_a(other)
  throw('self', is_ns(self))
  throw('other', is_ns(other))

  ok = self:get_ns_name() == other:get_ns_name()

  if not ok then
    return nil, 'expected ' .. dump(other) .. ', got ' .. dump(self)
  end

  return self
end
