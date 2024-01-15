require "lua-utils.table"

--- dictionary based set
--- Other support operators:
--- > == (exactly equal), ~= (unequal), < (subset), > (superset)
--- @class Set : table
--- @operator add(Set | list):Set union
--- @operator sub(Set | list):Set difference
--- @operator pow(Set | list):Set intersection

Set = namespace()

local Setmt = {
  type = "Set",
  __tostring = function(x)
    return dump(copy(x))
  end,
}

--- Get set items
--- @param x table|Set
--- @return table
function Set.items(x)
  return keys(Set(x))
end

--- @param x Set
--- @return boolean
function Set.is_set(x)
  return mtget(x, "type") == "Set"
end

function Set:__call(x)
  asserttype(x, "table")

  if Set.is_set(x) then
    return x
  end

  x = dict.from_list(x)
  mtset(x, Setmt)

  return x
end

function Setmt:__add(y)
  if not is_table(y) then
    self = Set(copy(self))
    self[y] = nil

    return self
  end

  y = Set(y)
  local out = copy(self)

  for key, _ in pairs(y) do
    out[key] = true
  end

  return Set(keys(out))
end

function Setmt:__pow(y)
  y = Set(y)
  local out = copy(self)

  for value, _ in pairs(out) do
    if not y[value] then
      out[value] = nil
    end
  end

  return Set(keys(out))
end

function Setmt:__mod(f)
  return Set(list.map(keys(self), f))
end

function Setmt:__div(f)
  return Set(list.filter(keys(self), f))
end

function Setmt:__sub(y)
  if not is_table(y) then
    self = copy(Set(self))
    self[y] = nil
    return self
  end

  y = Set(y)
  local out = copy(self)

  for value, _ in pairs(y) do
    out[value] = nil
  end

  return Set(keys(out))
end

function Setmt:__eq(y)
  y = Set(y)
  local out = copy(self)

  for value, _ in pairs(y) do
    if not out[value] then
      return false
    end
  end

  return size(out) == size(y) and Set(keys(out)) or false
end

function Setmt:__le(y)
  y = Set(y)
  local out = copy(self)

  for value, _ in pairs(out) do
    if not y[value] then
      return false
    end
  end

  return size(out) <= size(y)
end

function Setmt:__lt(y)
  y = Set(y)
  local out = copy(self)

  for value, _ in pairs(out) do
    if not y[value] then
      return false
    end
  end

  return size(out) < size(y)
end

function Setmt:__ne(y)
  return not Setmt:__eq(y)
end

function Setmt:__ge(y)
  y = Set(y)
  local out = copy(self)

  for value, _ in pairs(y) do
    if not out[value] then
      return false
    end
  end

  return size(out) >= size(y)
end

function Setmt:__gt(y)
  y = Set(y)
  local out = copy(self)

  for value, _ in pairs(y) do
    if not out[value] then
      return false
    end
  end

  return size(out) > size(y)
end

--- Set union
--- @param x Set|table
--- @param y Set|table
--- @return Set
function Set.union(x, y)
  return Set(x) + Set(y)
end

--- Set intersection
--- @param x Set|table
--- @param y Set|table
--- @return Set
function Set.intersection(x, y)
  return Set(x) ^ Set(y)
end

--- Set difference
--- @param x Set|table
--- @param y Set|table
--- @return Set
function Set.difference(x, y)
  return Set(x) - Set(y)
end

--- Is x superset of y
--- @param x Set|table
--- @param y Set|table
--- @return boolean|Set
function Set.superset(x, y)
  return Set(x) >= Set(y) and x or false
end

--- Is x subset of y
--- @param x Set|table
--- @param y Set|table
--- @return Set|boolean
function Set.subset(x, y)
  return Set(x) <= Set(y) and x or false
end

--- Are sets exactly equal?
--- @param x table|Set
--- @param y table|Set
--- @return Set|boolean
function Set.eq(x, y)
  return Set(x) == Set(y) and x or false
end

--- Are sets unequal?
--- @param x table|Set
--- @param y table|Set
--- @return Set|boolean
function Set.ne(x, y)
  return not Set.eq(x, y)
end

--- Union of list elements
--- @param x table|Set
--- @param y table|Set
--- @return list
function list.union(x, y)
  return Set.items(Set(x) + Set(y))
end

--- Intersection of list elements
--- @param x table|Set
--- @param y table|Set
--- @return list
function list.intersection(x, y)
  return Set.items(Set(x) ^ Set(y))
end

--- Difference of list elements
--- @param x table|Set
--- @param y table|Set
--- @return list
function list.difference(x, y)
  return Set.items(Set(x) - Set(y))
end

--- Is list x superset of list y
--- @param x table|Set
--- @param y table|Set
--- @return list|boolean
function list.superset(x, y)
  return Set(x) >= Set(y) and x or false
end

--- Is list x subset of list y
--- @param x table|Set
--- @param y table|Set
--- @return list|boolean
function list.subset(x, y)
  return Set(x) <= Set(y) and x or false
end

--- Do lists have the same elements?
--- @param x table|Set
--- @param y table|Set
--- @return list|boolean
function list.seteq(x, y)
  return Set(x) == Set(y) and x or false
end

--- Do lists not have the same elements
--- @param x table|Set
--- @param y table|Set
--- @return list|boolean
function list.setne(x, y)
  return not list.eqset(x, y)
end
