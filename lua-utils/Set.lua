require "lua-utils.table"

--- dictionary based set
--- Other support operators:
--- > a == b -- exact equality
--- > a ~= b -- exact inequality
--- > a <= b -- a is subset of b
--- > a >= b -- a is superset of b
--- > a <  b -- a is subset of b but b has more elems than a
--- > a >  b -- b is subset of a but a has more elems than b
--- @class Set
--- @operator add(Set | list):Set union
--- @operator sub(Set | list):Set difference
--- @operator pow(Set | list):Set intersection
--- @operator mod(function):Set map
--- @operator mul(function):Set reduce
--- @operator div(function): Set filter
Set = ns "Set"

--- get set size
--- @param self Set
--- @return integer?
function Set.size(self)
  return size(self)
end

--- get set difference
--- @param self Set
function Set.difference(self, y)
  if typeof(y) ~= "Set" then
    self = copy(self)
    self[y] = nil

    return self
  end

  self = copy(self)
  for value, _ in pairs(y) do
    self[value] = nil
  end

  return self
end

function Set.intersection(self, y)
  assert_is_a.Set(y)

  self = copy(self)

  for value, _ in pairs(self) do
    if not y[value] then
      self[value] = nil
    end
  end

  for value, _ in pairs(y) do
    if not self[value] then
      self[value] = nil
    end
  end

  return self
end

function Set.add(self, y)
  if not is_table(y) then
    self = copy(self)
    self[y] = true

    return self
  end

  assert_is_a.Set(y)

  self = copy(self)
  for value, _ in pairs(y) do
    self[value] = true
  end

  return self
end

function Set.union(self, y)
  if not is_table(y) then
    self = copy(self)
    self[y] = true

    return self
  end

  assert_is_a.Set(y)

  self = copy(self)
  for value, _ in pairs(y) do
    self[value] = true
  end

  return self
end

function Set.eq(self, other)
  assert_is_a.Set(other)

  for value, _ in pairs(other) do
    if not self[value] then
      return false
    end
  end

  return true
end

function Set.ne(other)
  assert_is_a.Set(other)

  for value, _ in pairs(other) do
    if self[value] then
      return false
    end
  end

  return true
end

Set.filter = function(self, f, mapper)
  return list.filter(keys(self), f, mapper)
end

Set.map = function(self, f)
  return list.map(keys(self), f)
end

Set.reduce = function(self, f)
  local elems = keys(self)
  return list.reduce(elems, elems[1], f)
end

function Set.superset(x, y)
  assert_is_a.Set(y)
  return Set.size(x - y) == 0 and Set.size(x) >= Set.size(y) and x
end

function Set.subset(x, y)
  return Set.superset(y, x)
end

function Set.strict_superset(x, y)
  assert_is_a.Set(y)
  return Set.size(x - y) == 0 and Set.size(x) > Set.size(y) and x
end

function Set.strict_subset(x, y)
  return _Set.strict_superset(y, x)
end

function Set.items(self)
  return keys(self)
end

--------------------------------------------------
local mt = {
  type = "Set",
  __eq = Set.eq,
  __ne = Set.ne,
  __concat = Set.add,
  __add = Set.union,
  __sub = Set.difference,
  __pow = Set.intersection,
  __div = Set.filter,
  __mod = Set.map,
  __mul = Set.reduce,
  __le = Set.subset,
  __lt = Set.strict_subset,
  __gt = Set.strict_superset,
  __ge = Set.superset,
}

function Set:__call(tbl)
  if typeof(tbl) == "Set" then
    return tbl
  end

  --- @type Set
  local obj = dict.from_list(tbl, function()
    return true
  end)

  mtset(obj, mt)

  return obj
end

--------------------------------------------------

function list.union(x, y)
  x = Set(x)
  y = Set(y)
  return Set.items(x + y)
end

function list.difference(x, y)
  return Set.items(x - y)
end

function list.intersection(x, y)
  return Set.items(x ^ y)
end

function list.strict_superset(x, y)
  local res = Set(x) < Set(y)
  if res then
    return Set.items(res)
  end
end

function list.superset(x, y)
  local res = Set(x) <= Set(y)
  if res then
    return Set.items(res)
  end
end

function list.strict_subset(x, y)
  local res = Set(x) < Set(y)
  if res then
    return Set.items(res)
  end
end

function list.subset(x, y)
  local res = Set(x) <= Set(y)
  if res then
    return Set.items(res)
  end
end

dict.union = list.union
dict.difference = list.difference
dict.intersection = list.intersection
dict.strict_superset = list.strict_superset
dict.superset = list.superset
dict.strict_subset = list.strict_subset
dict.subset = list.subset
