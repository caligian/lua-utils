--- Tables as dictionaries
-- @module dict
local types = require "lua-utils.types"
local utils = require "lua-utils.utils"
local array = require "lua-utils.array"

--------------------------------------------------------------------------------
local dict = {}

--- Shallow copy table
-- @tparam dict x
-- @treturn dict
function dict.copy(x)
  return utils.copy(x)
end

--- Get dict values
-- @tparam dict t
-- @treturn array[values]
function dict.values(t)
  local out = {}
  local i = 1
  for _, value in pairs(t) do
    out[i] = value
    i = i + 1
  end

  return out
end

--- Get dict keys
-- @tparam dict t
-- @tparam boolean sort keys?
-- @tparam callable cmp callable(a, b)
-- @treturn array[keys]
function dict.keys(t, sort, cmp)
  local out = {}
  local i = 1

  for key, _ in pairs(t) do
    out[i] = key
    i = i + 1
  end

  if sort then
    return array.sort(out, cmp)
  end

  return out
end

--- Is dict blank?
-- @tparam dict t
-- @treturn boolean
function dict.isblank(t)
  return #dict.keys(t) == 0
end

--- Return dict filtered by a callable
-- @tparam dict t
-- @tparam callable f to determine the element accepting two args: key, callback
-- @treturn dict[found]
function dict.grep(t, f)
  local out = {}

  for k, v in pairs(t) do
    local o = f(k, v)
    if o then
      out[k] = v
    end
  end

  return out
end

--- Return boolean dict filtered by a callable
-- @tparam dict t
-- @tparam callable f to determine the element accepting two args: key, callback
-- @treturn dict[boolean]
function dict.filter(t, f)
  local out = {}
  for idx, v in pairs(t) do
    local o = f(idx, v)
    if o then
      out[idx] = v
    else
      out[idx] = false
    end
  end

  return out
end

--- Return dict transformed by a callable
-- @tparam dict t
-- @tparam callable f to determine the element accepting two args: key, callback
-- @tparam boolean in_place if true then modify the dict in place
-- @treturn dict
function dict.map(t, f, in_place)
  local out = {}
  for k, v in pairs(t) do
    local o = f(k, v)
    assert(o ~= nil, "non-nil expected")
    if in_place then
      t[k] = o
    end
    out[k] = o
  end

  return out
end

--- Return zipped dict keys and items
-- @tparam dict t
-- @treturn array[key,value]
function dict.items(t)
  local out = {}
  local i = 1
  for key, val in pairs(t) do
    out[i] = { key, val }
    i = i + 1
  end

  return out
end

--- Get dict length
-- @tparam dict t
-- @treturn number
function dict.len(t)
  return #dict.keys(t)
end

--- Compare two dicts
-- @tparam dict a
-- @tparam dict b
-- @tparam[opt] callable callback to compare element of table1 with that of table2's
-- @tparam[opt] boolean no_state if specified then return false as soon an equality is found
-- @see array.compare
-- @treturn[1] boolean if no_state is given
-- @treturn[2] array[boolean]
function dict.compare(a, b, callback, no_state)
  return array.compare(a, b, callback, no_state)
end

--- Update an dict with keys
-- @tparam dict tbl
-- @tparam array keys
-- @tparam any value value to replace with
-- @treturn any
-- @treturn dict predecessor
-- @treturn dict
function dict.update(tbl, keys, value)
  return array.update(tbl, keys, value)
end

--- Find an element in a dict using BFS search
-- @tparam dict t
-- @tparam any item
-- @tparam[opt] boolean test callable taking 2 args
-- @tparam[opt] number depth max depth to traverse. -1 for a full search
-- @treturn key|array[keys]
function dict.index(t, item, test, depth)
  depth = depth or -1
  test = test or function(x, y)
    return x == y
  end
  local cache = {}

  local function _index(x, d, layer)
    if cache[x] then
      return
    end
    if d == depth then
      return
    end

    local ks = dict.keys(x)
    local n = #ks
    cache[x] = true
    layer = layer or {}
    local later = {}
    local later_i = 0

    for i = 1, n do
      local k = ks[i]
      local v = x[k]

      if types.is_table(v) then
        later[later_i + 1] = k
        later_i = later_i + 1
      elseif test(v, item) then
        return array.append(layer, k)
      end
    end

    for i = 1, later_i do
      array.append(layer, ks[i])
      local out = _index(x[later[i]], d + 1, layer)
      if out then
        return out
      else
        array.pop(layer)
      end
    end
  end

  return _index(t, 0)
end

--- Get element at path specified by key(s)
-- @tparam dict|table tbl
-- @tparam key|array[keys] ks to get the element from
-- @tparam boolean create_path if true then create a table if element is absent
-- @treturn any
function dict.get(tbl, ks, create_path)
  return array.get(tbl, ks, create_path)
end

--- Get element at path specified by key(s)
-- @tparam dict|table tbl
-- @tparam key|dict[keys] ... to get the element from
-- @treturn any
function dict.contains(tbl, ...)
  return (dict.get(tbl, { ... }))
end

--- Create a table at the path specified by key(s). Modifies the dict
-- @tparam dict t
-- @tparam array[keys] ... where the new table shall be made
-- @treturn dict
function dict.makepath(t, ...)
  return dict.get(t, { ... }, true)
end

--- Apply callable to a dict
-- @tparam dict t
-- @tparam callable f with 2 args: key, value
function dict.each(t, f)
  for key, value in pairs(t) do
    f(key, value)
  end
end

--- Merge two dicts but keep the elements if they already exist
-- @tparam dict ...
-- @treturn dict
function dict.lmerge(...)
  local cache = {}

  local function _merge(t1, t2)
    local later = {}

    dict.each(t2, function(k, v)
      local a, b = t1[k], t2[k]
      if cache[a] then
        return
      end

      if a == nil then
        t1[k] = v
      elseif types.typeof(a) == "table" and types.typeof(b) == "table" then
        cache[a] = true
        array.append(later, { a, b })
      end
    end)

    array.each(later, function(next)
      _merge(unpack(next))
    end)
  end

  local args = { ... }
  local l = #args
  local start = args[1]

  for i = 2, l do
    _merge(start, args[i])
  end

  return start
end

--- Merge two dicts
-- @tparam  dict ...
-- @treturn dict
function dict.merge(...)
  local cache = {}

  local function _merge(t1, t2)
    local later = {}

    dict.each(t2, function(k, v)
      local a, b = t1[k], t2[k]
      if cache[a] then
        return
      end

      if a == nil then
        t1[k] = v
      elseif types.typeof(a) == "table" and types.typeof(b) == "table" then
        cache[a] = true
        array.append(later, { a, b })
      else
        t1[k] = v
      end
    end)

    array.each(later, function(vs)
      _merge(unpack(vs))
    end)
  end

  local args = { ... }
  local l = #args
  local start = args[1]

  for i = 2, l do
    _merge(start, args[i])
  end

  return start
end

--- Remove an element by key(s)
-- @tparam dict x
-- @tparam key|dict[keys] ks
-- @treturn any
function dict.delete(x, ks)
  local _, t = dict.get(x, ks)
  if not t then
    return
  end

  local k = ks[#ks]
  local obj = t[k]
  t[k] = nil

  return obj
end

--- Get the dict part. This mutates the table passed
-- @tparam table x Table to get dict from
-- @treturn dict, array
function dict.extract(x)
  local array_part = array.extract(x)
  local dict_part = x

  return x, array_part
end

function dict.isdict(x)
  if type(x) ~= 'table' then 
    return false 
  elseif #x > 0 then
    return false
  elseif #(dict.keys(x)) > 0 then
    return true
  end
end

return dict
