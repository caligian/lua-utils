--- dict-based Set objects
-- @classmod Set
local class = require "lua-utils.class"
local array = require "lua-utils.array"
local dict = require "lua-utils.dict"
local utils = require "lua-utils.utils"
local types = require "lua-utils.types"
local Set = class "Set"

--------------------------------------------------------------------------------
--- Constructor
-- @usage
-- local a = Set {1,2,3}
-- local b = Set {3,3}
-- @param t table|Set
-- @treturn self
function Set:init(t)
  assert(type(t) == "table", "table expected, got " .. type(t))

  if types.is_class(t) then
    local name = t:get_name()
    if name ~= "Set" then
      error("Set|table expected, got " .. name)
      return self
    else
      t = t.value
    end
  end

  self.value = {}
  for _, value in pairs(t) do
    self.value[value] = value
  end

  return self
end

--- Set has value x?
-- @param x value
-- @treturn any
function Set:has(x)
  return self.value[x]
end

--- Add value to set
-- @param x value
function Set:add(x)
  self.value[x] = x
end

--- Get all elements
-- @param cmp optional callable to sort
-- @treturn array
function Set:items(cmp)
  cmp = cmp or function(x, y)
    return tostring(x) < tostring(y)
  end
  local X = dict.values(self.value)
  table.sort(X, cmp)

  return X
end

--- Apply a function to all set elements
-- @param f callable to apply
function Set:each(f)
  array.each(self:items(), f)
end

--- Apply a function to all set elements
-- @param f callable to apply
-- @treturn array of transformed elements
function Set:map(f)
  return array.map(self:items(), f)
end

--- Grep elements by callable
-- @param f callable criterion
-- @treturn array of matched elements
function Set:grep(f)
  return array.grep(self:items(), f)
end

--- Filter elements by callable
-- @param f callable criterion
-- @treturn boolean array of elements
function Set:filter(f)
  return array.filter(self:items(), f)
end

--- Get set length
-- @treturn set length
function Set:len()
  return dict.len(self.value)
end

--- Get set length
-- @treturn set length
function Set:length()
  return dict.len(self.value)
end

--- Set intersection
-- @param ... rest of Sets/arrays to intersect with this set
-- @treturn Set
function Set:intersection(...)
  local out = Set {}

  for _, Y in ipairs { ... } do
    Y = Set(Y)

    self:each(function(x)
      if Y:has(x) then
        out:add(x)
      end
    end)

    Y:each(function(y)
      if self:has(y) then
        out:add(y)
      end
    end)
  end

  return out
end

--- Are sets disjoint?
-- @param y other Set|table
-- @treturn boolean
function Set:is_disjoint(y)
  return self:intersection(y):len() == 0
end

--- Get the complement of current set with others sets
-- @param ... other Sets|tables
-- @treturn Set
function Set:complement(...)
  local out = Set.new {}
  local Z = self:intersection(...)

  self:each(function(x)
    if not Z:has(x) then
      out:add(x)
    end
  end)

  return out
end

--- Get a union of all sets
-- @usage
-- local a = Set {'a', 'b'}
-- local b = Set {'c', 'd'}
-- local c = a + b
-- local d = a + b + Set {'e', 'f'}
-- local e = a:union(b, c, d)
-- @param ... Sets|tables to use with current set
-- @treturn Set
function Set:union(...)
  local out = Set.new {}

  for _, Y in ipairs { ... } do
    Y = Set.new(Y)

    self:each(function(x)
      out:add(x)
    end)

    Y:each(function(y)
      out:add(y)
    end)
  end

  return out
end

--- Get set difference with current set
-- @usage
-- local a = Set {1,2,3}
-- local b = Set {3,4,5,6}
-- local c = Set {1, 2}
-- print(a - b - c)
-- print(a:difference(b, c))
-- @param ... other sets
-- @treturn Set
function Set:difference(...)
  local out = Set.new {}

  for _, Y in ipairs { ... } do
    Y = Set.new(Y)
    self:each(function(x)
      if not Y:has(x) then
        out:add(x)
      end
    end)
  end

  return out
end

--- Is this set equal to another Set|table?
-- @param other Set|table to compare
-- @treturn boolean
function Set:equals(other)
  if not types.is_table(other) then
    return
  end

  return array.compare(dict.values(self.value), dict.values(other), nil, true)
end

--- Is this set not equal to another Set|table?
-- @param other Set|table to compare
-- @treturn boolean
function Set:not_equals(other)
  return not self:equals(other)
end

--- Compare elements of two sets
-- @usage
-- Set({2, 3, 4}) == Set({3, 4, 2}) -- true
-- @param other other set
-- @treturn boolean
function Set:__eq(other)
  return self:equals(other)
end

--- Compare elements of two sets with not logic
-- @usage
-- Set({2, 3, 4}) ~= Set({3, 4, 2}) -- true
-- @param other other Set|table
-- @treturn boolean
function Set:__ne(other)
  return not self:equals(other)
end

--- Get set difference
-- @usage
-- Set({'a', 'b'}) - Set({'b', 'c'}) -- Set({'a'})
-- @param other Set|table
-- @treturn Set
function Set:__sub(other)
  return self:difference(other)
end

--- Get set union
-- @usage
-- Set({'a', 'b'}) + Set({'b', 'c'}) -- Set({'a', 'b', 'c'})
-- @param other Set|table
-- @treturn Set
function Set:__add(other)
  return self:union(other)
end

--- Get set intersection
-- @usage
-- Set({'a', 'b'}) ^ Set({'b', 'c'}) -- Set({'a'})
-- @param other Set|table
-- @treturn Set
function Set:__pow(other)
  return self:intersection(other)
end

--- Is this set a subset of other set?
-- @param other other Set|table
-- @treturn boolean
function Set:is_subset(other)
  return self:difference(other):len() == 0
end

--- Is this set a superset of other set?
-- @param other other Set|table
-- @treturn boolean
function Set:is_superset(other)
  return other:difference(self):len() == 0
end

--- Remove element from set
-- @treturn ?element
function Set:remove(element)
  local has = self.value[element]
  if has then
    self.value[element] = nil
    return utils.copy(has)
  end
end

--- Iterate over elements of a set
-- @treturn callable
function Set:iter()
  local ks = array.sort(dict.keys(self.value))
  local index = 1

  return function(idx)
    local value = self.value[ks[idx or index]]
    index = index + 1
    return value
  end
end

--- Is x a Set?
-- @param x object
-- @treturn boolean
function Set.is_a(x)
  return class.get_name(x) == "Set"
end

return Set
