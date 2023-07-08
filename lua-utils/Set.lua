--- dict-based Set objects
-- @classmod Set

local array = require "array"
local dict = require "dict"
local utils = require "utils"
local types = require "types"
local module = require "module"
local struct = require "struct"
local exception = require "exception"
local set = module.new "set"

set.Set = struct.new("Set", { "value" })
local Set = set.Set

--------------------------------------------------------------------------------
function set.new(tbl)
    tbl = tbl or {}

    if types.is_a(tbl, "Set") then
        return tbl
    elseif not types.is_table(tbl) or not types.is_array(tbl) then
        return
    end

    local st = Set {}
    st.value = array.todict(tbl)

    function st.__eq(obj, other) return Set.equals(obj, other) end
    function st.__ne(obj, other) return not Set.equals(obj, other) end
    function st.__sub(obj, other) return Set.difference(obj, other) end
    function st.__add(obj, other) return Set.union(obj, other) end
    function st.__pow(obj, other) return Set.intersection(obj, other) end

    return st
end

--- M has value x?
-- @param x value
-- @treturn any
function Set.has(obj, x) return obj.value[x] end

--- Add value to set
-- @param x value
function Set.add(obj, x)
    obj.value[x] = x

    return x
end

--- Get all elements
-- @param cmp optional callable to sort
-- @treturn array
function Set.items(obj, cmp)
    cmp = cmp or function(x, y) return tostring(x) < tostring(y) end

    local X = dict.values(obj.value)
    table.sort(X, cmp)

    return X
end

--- Apply a function to all set elements
-- @param f callable to apply
function Set.each(obj, f) array.each(Set.items(obj), f) end

--- Apply a function to all set elements
-- @param f callable to apply
-- @treturn array of transformed elements
function Set.map(obj, f) return array.map(Set.items(obj), f) end

--- Grep elements by callable
-- @param f callable criterion
-- @treturn array of matched elements
function Set.grep(obj, f) return array.grep(Set.items(obj), f) end

--- Filter elements by callable
-- @param f callable criterion
-- @treturn boolean array of elements
function Set.filter(obj, f) return array.filter(Set.items(obj), f) end

--- Get set length
-- @treturn set length
function Set.len(obj) return dict.len(obj.value) end

--- Get set length
-- @treturn set length
function Set.length(obj) return dict.len(obj.value) end

--- M intersection
-- @param ... rest of Ms/arrays to intersect with this set
-- @treturn M
function Set.intersection(obj, ...)
    local out = set.new {}

    for _, Y in ipairs { ... } do
        Y = set.new(Y)

        Set.each(obj, function(x)
            if Set.has(Y, x) then Set.add(out, x) end
        end)

        Set.each(Y, function(y)
            if Set.has(obj, y) then Set.add(out, y) end
        end)
    end

    return out
end

--- Are sets disjoint?
-- @param y other M|table
-- @treturn boolean
function Set.is_disjoint(obj, y) return Set.len(Set.intersection(obj, y)) == 0 end

--- Get the complement of current set with others sets
-- @param ... other Ms|tables
-- @treturn M
function Set.complement(obj, ...)
    local out = set.new {}
    local Z = Set.intersection(obj, ...)

    Set.each(obj, function(x)
        if not Set.has(Z, x) then Set.add(out, x) end
    end)

    return out
end

--- Get a union of all sets
-- @usage
-- local a = M {'a', 'b'}
-- local b = M {'c', 'd'}
-- local c = a + b
-- local d = a + b + M {'e', 'f'}
-- local e = Set.union(a, b, c, d)
-- @param ... Ms|tables to use with current set
-- @treturn M
function Set.union(obj, ...)
    local out = set.new {}

    for _, Y in ipairs { ... } do
        Y = set.new(Y)

        Set.each(obj, function(x) Set.add(out, x) end)

        Set.each(Y, function(y) Set.add(out, y) end)
    end

    return out
end

--- Get set difference with current set
-- @usage
-- local a = M {1,2,3}
-- local b = M {3,4,5,6}
-- local c = M {1, 2}
-- print(a - b - c)
-- print(Set.difference(a, b, c))
-- @param ... other sets
-- @treturn M
function Set.difference(obj, ...)
    local out = set.new {}

    for _, Y in ipairs { ... } do
        Y = set.new(Y)

        Set.each(obj, function(x)
            if not Set.has(Y, x) then Set.add(out, x) end
        end)
    end

    return out
end

--- Is this set equal to another M|table?
-- @param other M|table to compare
-- @treturn boolean
function Set.equals(obj, other)
    if not types.is_table(other) then return end

    return array.compare(dict.values(obj.value), dict.values(other), nil, true)
end

--- Is this set not equal to another M|table?
-- @param other M|table to compare
-- @treturn boolean
function Set.not_equals(obj, other) return not Set.equals(obj, other) end

-- M({'a', 'b'}) ^ M({'b', 'c'}) -- M({'a'})
-- @param other M|table
-- @treturn M

--- Is this set a subset of other set?
-- @param other other M|table
-- @treturn boolean
function Set.is_subset(obj, other)
    return Set.len(Set.difference(obj, other)) == 0
end

--- Is this set a superset of other set?
-- @param other other M|table
-- @treturn boolean
function Set.is_superset(obj, other)
    return Set.len(Set.difference(other, obj)) == 0
end

--- Remove element from set
-- @treturn ?element
function Set.remove(obj, element)
    local has = obj.value[element]
    if has then
        obj.value[element] = nil
        return utils.copy(has)
    end
end

--- Iterate over elements of a set
-- @treturn callable
function Set.iter(obj)
    local ks = array.sort(dict.keys(obj.value))
    local index = 1

    return function(idx)
        local value = obj.value[ks[idx or index]]
        index = index + 1
        return value
    end
end

return set


