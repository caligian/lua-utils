require "lua-utils.types"
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

Set = {}
local mt = {}

--- get set size
--- @param self Set
--- @return integer?
function Set.size(self)
  return size(self)
end

--- get set difference
--- @param self Set
function Set.difference(self, y)
  if not is_a(y, types.Set) then
    self = copy(self, { metatable = true })
    self[y] = nil

    return self
  end

  self = copy(self, { metatable = true })
  for value, _ in pairs(y) do
    self[value] = nil
  end

  return self
end

function Set.intersection(self, y)
  y = Set:new(y)
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

  y = Set:new(y)
  self = copy(self)

  for value, _ in pairs(y) do
    self[value] = true
  end

  return self
end

function Set.union(self, y)
  if not is_table(y) then
    self = copy(self, { metatable = true })
    self[y] = true

    return self
  end

  y = Set:new(y)
  self = copy(self, { metatable = true })

  for value, _ in pairs(y) do
    self[value] = true
  end

  return self
end

function Set.eq(self, other)
  other = Set:new(other)

  for value, _ in pairs(other) do
    if not self[value] then
      return false
    end
  end

  return true
end

function Set.ne(other)
  other = Set:new(other)

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
  return Set.size(x - y) == 0
    and Set.size(x) >= Set.size(y)
    and x
end

function Set.subset(x, y)
  return Set.superset(y, x)
end

function Set.strict_superset(x, y)
  return Set.size(x - y) == 0
    and Set.size(x) > Set.size(y)
    and x
end

function Set.strict_subset(x, y)
  return Set.strict_superset(y, x)
end

function Set.items(self)
  return keys(self)
end

--------------------------------------------------
mt.__eq = Set.eq
mt.__ne = Set.ne
mt.__concat = Set.add
mt.__add = Set.union
mt.__sub = Set.difference
mt.__pow = Set.intersection
mt.__div = Set.filter
mt.__mod = Set.map
mt.__mul = Set.reduce
mt.__le = Set.subset
mt.__lt = Set.strict_subset
mt.__gt = Set.strict_superset
mt.__ge = Set.superset

function Set:new(tbl)
  if is_a(tbl, types.Set) then
    return tbl
  else
    return mtset(
      dict.from_list(tbl, function()
        return true
      end),
      mt
    )
  end
end

function types.Set(x)
  return mtget(x) == mt
end

--------------------------------------------------

function list.union(x, y)
  x = Set:new(x)
  y = Set:new(y)
  return Set.items(x + y)
end

function list.difference(x, y)
  return Set.items(x - y)
end

function list.intersection(x, y)
  return Set.items(x ^ y)
end

function list.strict_superset(x, y)
  local res = Set:new(x) < Set:new(y)
  if res then
    return Set.items(res)
  end
end

function list.superset(x, y)
  local res = Set:new(x) <= Set:new(y)
  if res then
    return Set.items(res)
  end
end

function list.strict_subset(x, y)
  local res = Set:new(x) < Set:new(y)
  if res then
    return Set.items(res)
  end
end

function list.subset(x, y)
  local res = Set:new(x) <= Set:new(y)
  if res then
    return Set.items(res)
  end
end
