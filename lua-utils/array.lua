--- Tables as arrays - utilties
-- @module array
local types = require "lua-utils.types"
local utils = require "lua-utils.utils"
local array = {}

--------------------------------------------------------------------------------
-- Reverse array
-- @tparam array x
-- @treturn array
function array.reverse(x)
  local out = {}
  local j = 1

  for i = #x, 1, -1 do
    out[j] = x[i]
    j = j + 1
  end

  return out
end

--- Pop N items from an array
-- @tparam array t
-- @tparam number n of items to pop
-- @treturn array|any
function array.pop(t, n)
  n = n or 1
  local out = {}

  for i = 1, n do
    out[i] = table.remove(t, #t)
  end

  if n == 1 then
    return out[1]
  else
    return out
  end
end

--- Shallow copy array
-- @tparam array x
-- @treturn array
function array.copy(x) return utils.copy(x) end

--- Concat all elements of an array with a sep
-- @tparam array x
-- @tparam[opt=single_space] string sep separator
-- @treturn string
function array.concat(x, sep)
  x = x or " "
  return table.concat(x, sep)
end

--- Concat all elements of an array with a sep
-- @tparam array x
-- @tparam[opt=single_space] string sep separator
-- @treturn string
function array.join(x, sep)
  x = x or " "
  return table.concat(x, sep)
end

--- Remove element at index. Modifies the array
-- @param x array
-- @param i index
-- @treturn ?any element found at index
function array.remove(x, i) return table.remove(x, i) end

--- Sort array. Modifies the array
-- @tparam array x
-- @tparam[opt] callable cmp For comparison
-- @treturn array
function array.sort(x, cmp)
  table.sort(x, cmp)
  return x
end

--- Is array blank?
-- @param x array
-- @treturn boolean
function array.isblank(x) return #x == 0 end

--- Append elements to array. Modifies the array
-- @tparam array x
-- @tparam any ... elements to append
-- @treturn array
function array.append(x, ...)
  local idx = #x
  for i, value in ipairs { ... } do
    x[idx + i] = value
  end

  return x
end

--- Append elements to array at index. Modifies the array
-- @tparam array t
-- @tparam index idx
-- @tparam any ... elements to append
-- @treturn array
function array.iappend(t, idx, ...)
  for _, value in ipairs { ... } do
    table.insert(t, idx, value)
  end

  return t
end

--- Add elements at the beginning of the array. Modifies the array
-- @param t array
-- @param ... elements to prepend the array with
-- @treturn array
function array.unshift(t, ...)
  for idx, value in ipairs { ... } do
    table.insert(t, idx, value)
  end

  return t
end

--- Convert an element into an array
-- @tparam non-table x that is not a table
-- @tparam boolean force listify the element?
-- @treturn array
function array.tolist(x, force)
  if force or type(x) ~= "table" then return { x } end

  return x
end

--- Convert an element into an array
-- @tparam any x that is not a table
-- @tparam boolean force listify the element?
-- @treturn array
function array.toarray(x, force) return array.tolist(x, force) end

--- Convert array values to keys
-- @tparam array x
-- @treturn dict
function array.todict(x)
  if type(x) ~= "table" then return { [x] = x } end

  local out = {}
  for _, v in pairs(x) do
    out[v] = v
  end

  return out
end

--- Remove the 1st element n times. Modifies the array
-- @tparam array t
-- @tparam[opt=1] number times optional number of times
-- @treturn array
function array.shift(t, times)
  local out = {}
  local l = #t
  times = times or 1

  for i = 1, times do
    if i > l then return t end
    out[i] = table.remove(t, 1)
  end

  if times == 1 then return out[1] end

  return t
end

--- Find an element in an array using BFS search
-- @tparam array t
-- @tparam any item
-- @tparam callable test optional test callable taking 2 args
-- @tparam number depth max depth to traverse. -1 for a full search
-- @treturn key|array[keys]
function array.index(t, item, test, depth)
  depth = depth or -1
  test = test or function(x, y) return x == y end
  local cache = {}

  local function _index(x, d, layer)
    if cache[x] then return cache[x] end
    if d == depth then return layer end

    layer = layer or {}
    local later = {}
    local later_i = 0
    cache[x] = layer

    for i = 1, #x do
      array.append(layer, i)

      local v = x[i]
      if types.is_table(v) then
        later[later_i + 1] = { i, v }
        later_i = later_i + 1
      elseif test(v, item, layer) then
        return layer
      end

      array.pop(layer)
    end

    for i = 1, later_i do
      local k, v = unpack(later[i])
      local out = _index(v, d + 1, array.append(layer, k))

      array.pop(layer)

      if out then
        if #out == 1 then return out[1] end
        return out
      end
    end
  end

  return _index(t, 0)
end

--- Apply function on an array
-- @tparam array t
-- @tparam callable f accepting two args: index, value
function array.ieach(t, f)
  for _, v in ipairs(t) do
    f(_, v)
  end
end

--- Apply function on an array
-- @tparam array t
-- @tparam callable f to run on the value
function array.each(t, f)
  for _, v in ipairs(t) do
    f(v)
  end
end

--- Returns array filtered by a callable
-- @tparam array t
-- @tparam callable f to determine the element accepting two args: index, callback
-- @treturn array[found]
function array.igrep(t, f)
  local out = {}
  local i = 1

  for k, v in ipairs(t) do
    local o = f(k, v)
    if o then
      out[i] = v
      i = i + 1
    end
  end

  return out
end

-- Returns array filtered by a callable
-- @tparam array t
-- @tparam callable f to determine the element accepting two args: index, callback
-- @treturn array[found]
function array.grep(t, f)
  local out = {}
  local i = 1
  for _, v in ipairs(t) do
    local o = f(v)
    if o then
      out[i] = v
      i = i + 1
    end
  end

  return out
end

--- Filter an array
-- @tparam array t
-- @tparam callable f to act as a filter
-- @treturn array[boolean]
function array.filter(t, f)
  local out = {}
  for idx, v in ipairs(t) do
    local o = f(v)
    if o then
      out[idx] = true
    else
      out[idx] = false
    end
  end

  return out
end

--- Filter an array
-- @tparam array t
-- @tparam callable f to act as a filter, takes 2 args: index, value
-- @treturn array[boolean]
function array.ifilter(t, f)
  local out = {}
  for idx, v in ipairs(t) do
    local o = f(idx, v)
    if o then
      out[idx] = true
    else
      out[idx] = false
    end
  end

  return out
end

--- Apply a callable to an array
-- @tparam array t
-- @tparam callable f to transform the array
-- @tparam boolean in_place if true then transform the array in-place
-- @treturn array
function array.map(t, f, in_place)
  local out = {}
  for idx, v in ipairs(t) do
    v = f(v)
    assert(v ~= nil, "non-nil expected")
    if in_place then t[idx] = v end
    out[idx] = v
  end

  return out
end

--- Apply a callable to an array
-- @tparam array t
-- @tparam callable f to transform the array, with 2 args: index, value
-- @tparam boolean in_place if true then transform the array in-place
-- @treturn array
function array.imap(t, f, in_place)
  local out = {}
  for idx, v in ipairs(t) do
    v = f(idx, v)
    assert(v ~= nil, "non-nil expected, got " .. tostring(v))
    if in_place then t[idx] = v end
    out[idx] = v
  end

  return out
end

--- Get array length
-- @tparam array x
-- @treturn number
function array.len(x) return #x == 0 end

--- Extend array with other tables or non-tables. Modifies the array
-- @tparam array tbl to extend
-- @tparam any ... rest of the elements
-- @treturn array
function array.extend(tbl, ...)
  for i, t in ipairs { ... } do
    if type(t) == "table" then
      local n = #tbl
      for j, value in ipairs(t) do
        tbl[n + j] = value
      end
    else
      tbl[#tbl + i] = t
    end
  end

  return tbl
end

--- Compare two arrays/tables
-- @usage
-- -- output: {true, false, false}, false
-- array.compare({1, 2, 3}, {1, 3, 4, 5})
--
-- -- output: {true, false, {true, false}}, false
-- array.compare({1, 2, {3, 4}}, {1, 9, {3, 5}})
--
-- -- output: false
-- array.compare({'a', 'b'}, {'a', 'c'}, nil, true)
--
-- @tparam array a
-- @tparam array b
-- @tparam callable callback to compare element of table1 with that of table2's
-- @tparam boolean no_state if specified then return false as soon an equality is found
-- @treturn[1] array[boolean]
-- @treturn[2] boolean if no_state is truthy
function array.compare(a, b, callback, no_state)
  local compared = {}
  local state = compared
  local all_equal
  local unique_id = 0
  local cache = {}
  local ok, ffi = pcall(require, "ffi")

  local function hash(x, y)
    if ok then
      local x_ptr = ffi.cast("int*", x)
      local y_ptr = ffi.cast("int*", y)
      local id = array.concat({ x_ptr, ",", y_ptr }, "")

      return id
    end

    x = tostring(unique_id + 1)
    y = tostring(unique_id + 2)
    return (x .. ":" .. y)
  end

  local function cache_get(x, y)
    local id = hash(x, y)

    if not cache[id] then
      cache[id] = true
      unique_id = unique_id + 1
    end
  end

  local function _compare(x, y)
    if cache_get(x, y) then return end

    local later = {}

    for key, value in pairs(x) do
      local y_value = y[key]
      if not y_value then
        state[key] = false
      elseif types.is_table(y_value) and types.is_table(value) then
        state[key] = {}
        state = state[key]
        later[#later + 1] = { value, y_value }
      elseif callback then
        state[key] = callback(value, y_value)
      else
        state[key] = value == y_value
      end

      for _, v in ipairs(later) do
        _compare(unpack(v))
      end

      all_equal = state[key]
      if no_state and not all_equal then return false end
    end
  end

  _compare(a, b)

  if no_state then return all_equal end
  return compared, all_equal
end

--- Return the first N-1 elements in the array.
-- @tparam array t
-- @tparam number n of first N-n-1 elements
-- @treturn array of N-n-1 elements
function array.butlast(t, n)
  n = n or 1
  local len = #t
  local new = {}
  local idx = 1
  for i = 1, len - n do
    new[idx] = t[i]
    idx = idx + 1
  end

  return new
end

--- Return the first N elements
-- @tparam array t
-- @tparam first n n element[s]
-- @treturn any|array
function array.head(t, n)
  if n == 1 then return t[1] end

  n = n or 1
  local out = {}
  for i = 1, n do
    out[i] = t[i]
  end

  return out
end

--- Return the first N elements
-- @param t array
-- @param n first n element[s]
-- @treturn any|array
function array.first(t, n) return array.head(t, n or 1) end

--- Return the last N elements in the array
-- @tparam  array t
-- @tparam  number n of last elements. default: 1
-- @treturn array of N elements defined
function array.last(t, n)
  if n == 1 then return t[#t] end

  n = n or 1
  local out = {}
  local len = #t
  local idx = 1
  for i = len - (n - 1), len do
    out[idx] = t[i]
    idx = idx + 1
  end

  return out
end

--- Return the last N elements in the array
-- @tparam array t
-- @tparam number n of elements. default: 1
-- @treturn array of N elements defined
function array.tail(t, n) return array.last(t, n) end

--- Return the last N-1-n elements in the array. Like cdr() and nthcdr()
-- @param t array
-- @param n number of last elements. default: 1
-- @treturn array of N-1-n elements defined
function array.rest(t, n)
  n = n or 1
  local out = {}
  local idx = 1
  for i = n + 1, #t do
    out[idx] = t[i]
    idx = idx + 1
  end

  return out
end

--- Update an array with keys
-- @tparam array|table tbl
-- @tparam array[keys] keys
-- @tparam any value
-- @treturn any
-- @treturn array
function array.update(tbl, keys, value)
  keys = array.tolist(keys)
  local len_ks = #keys
  local t = tbl
  local i = 1

  while i < len_ks do
    local k = keys[i]
    local v = t[k]

    if v == nil then
      t[k] = {}
      v = t[k]
    end

    if type(v) == "table" then
      t = v
    else
      return
    end

    i = i + 1
  end

  t[keys[i]] = value

  return value, t
end

--- Get element at path specified by key(s)
-- @tparam array|table tbl
-- @tparam key|array[keys] ks to get the element from
-- @tparam boolean create_path if true then create a table if element is absent
-- @treturn any
function array.get(tbl, ks, create_path)
  if type(ks) ~= "table" then ks = { ks } end

  local t = tbl
  local i = 1

  while i < #ks do
    local k = ks[i]
    local v = t[k]

    if v == nil and create_path then
      t[k] = {}
      v = t[k]
    end

    if type(v) == "table" then
      t = t[k]
    else
      break
    end

    i = i + 1
  end

  local n = #ks
  local v = t[ks[n]]
  if v == nil and create_path then t[ks[n]] = {} end
  if t[ks[n]] then return t[ks[n]], t end
end

--- Return a subarray specified by index
-- @tparam array t
-- @tparam number from start index. If negative then N-from
-- @tparam number till end index. If negative then N-till
-- @treturn array
function array.slice(t, from, till)
  local l = #t
  from = from or 1
  till = till or 0
  till = till == 0 and l or till
  from = from == 0 and l or from
  if from < 0 then from = l + from end
  if till < 0 then till = l + till end
  if from > till then return {} end

  local out = {}
  local idx = 1
  for i = from, till do
    out[idx] = t[i]
    idx = idx + 1
  end

  return out
end

--- Get element at path specified by key(s)
-- @tparam array|table tbl
-- @tparam key|array[keys] ... to get the element from
-- @treturn any
function array.contains(tbl, ...) return (array.get(tbl, { ... })) end

--- Create a table at the path specified by key(s). Modifies the array
-- @tparam array t
-- @tparam any ... key(s) where the new table shall be made
-- @treturn array
function array.makepath(t, ...) return array.get(t, { ... }, true) end

--- Return a number range
-- @tparam number from start index
-- @tparam number till end index
-- @tparam number step default: 1
-- @treturn array
function array.range(from, till, step)
  step = step or 1
  local out = {}
  local idx = 1

  for i = from, till, step do
    out[idx] = i
    idx = idx + 1
  end

  return out
end

--- Zip two arrays element-wise in the form {x, y}
-- @tparam array a
-- @tparam array b
-- @treturn array[array[a[i],b[i]]]
function array.zip2(a, b)
  assert(type(a) == "table", "expected table, got " .. tostring(a))
  assert(type(b) == "table", "expected table, got " .. tostring(a))

  local len_a, len_b = #a, #b
  local n = len_a > len_b and len_b or len_a < len_b and len_a or len_a
  local out = {}
  for i = 1, n do
    out[i] = { a[i], b[i] }
  end

  return out
end

--- Delete index from array. Modifies the array
-- @tparam array tbl
-- @tparam any ... key|key(s)
-- @treturn any
function array.delete(tbl, ...)
  local ks = { ... }
  local _, t = array.get(tbl, ks)
  if not t then return end

  local k = ks[#ks]
  local obj = t[k]
  table.remove(t, k)

  return obj
end

--- Check if all the elements are truthy
-- @tparam array t
-- @treturn boolean
function array.all(t)
  local is_true = 0
  local n = #t

  for i = 1, n do
    if t[i] then is_true = is_true + 1 end
  end

  return is_true == n
end

--- Check if some elements are truthy
-- @tparam array t
-- @treturn boolean
function array.some(t)
  local is_true = 0
  for i = 1, #t do
    if t[i] then is_true = is_true + 1 end
  end
  return is_true > 0
end

--- Get the array part. This mutates the array
-- @tparam table x Table to get array from
-- @treturn array
function array.extract(x)
  local out = {}
  local j = 1
  for i = 1, #x do
    out[j] = x[i]
    x[i] = nil
    j = j + 1
  end

  return out
end

function array.deepcopy(x, new)
  if type(x) ~= "table" then return x end

  local cache = {}
  new = new or {}
  local current = new

  local function walk(tbl, current)
    if cache[tbl] then
      return
    else
      cache[tbl] = true
    end

    dict.each(tbl, function(key, value)
      if type(value) == "table" then
        current[key] = {}
        current = current[key]
        array.deepcopy(value, current)
      else
        current[key] = value
      end
      pp(new)
    end)
  end

  walk(x, current)

  return new
end

return array
