local copy = require 'lua-utils.copy'
local tuple = require 'lua-utils.tuple'

---@class list.opts
---@field default? (fun(): any)
---@field strict? boolean (default: true)

---Flatten everything and return a flattened list
---Directly analogous to c() of R
---@overload fun(size?: number, opts?: list.opts)
local list = {}
setmetatable(list, list)

list.concat = table.concat
list.collapse = table.concat
list.join = table.concat
list.insert = table.insert
list.remove = table.remove

---Get max number
---@param x table
---@return number
function list.max(x)
  return math.max(unpack(x))
end

---Get max number
---@param x table
---@return number
function list.min(x)
  return math.min(unpack(x))
end

---Is list empty?
---@param x table
---@return boolean
function list.empty(x)
  return #x == 0
end

list.is_empty = list.empty

---Get a list of indices
---@param x table
---@return number[]
function list.seq_along(x)
  local res = {}
  for i, _ in ipairs(x) do
    res[i] = i
  end
  return res
end

---Get list length
---@param x table
---@return number
function list.length(x)
  return #x
end

list.len = list.length

---Reverse elements in a list
---@param x table
---@return table
function list.reverse(x)
  local res = {}
  local ind = 1

  for i = #x, 1, -1 do
    res[ind] = x[i]
    ind = ind + 1
  end

  return res
end

---Push elements at the end
---@param x table
---@param ... any
---@return table
function list.push(x, ...)
  for _, arg in ipairs({ ... }) do
    table.insert(x, arg)
  end

  return x
end

---Push elements at the start
---@param x table
---@param ... any
---@return table
function list.unpush(x, ...)
  for _, arg in ipairs(list.reverse({ ... })) do
    table.insert(x, 1, arg)
  end

  return x
end

---Push elements or extend table at the end
---@param x table
---@param ... any
---@return table
function list.lextend(x, ...)
  local lextend = function(a, b)
    if type(b) == 'table' then
      list.unpush(a, unpack(b))
    else
      list.unpush(a, b)
    end
  end

  for _, arg in ipairs({ ... }) do
    lextend(x, arg)
  end

  return x
end

---Push elements or extend table at the end
---@param x table
---@param ... any
---@return table
function list.extend(x, ...)
  for _, arg in ipairs({ ... }) do
    if type(arg) == 'table' then
      for i = 1, #arg do list.append(x, arg[i]) end
    else
      list.append(x, arg)
    end
  end

  return x
end

---Get sequence of elements. Similar to for i=<int>, i<j, <int>
---@param start number
---@param end_ number
---@param by? number (default: 1)
---@return number[]
function list.seq(start, end_, by)
  by        = by or 1
  local res = {}
  local ind = 1

  for i = start, end_, by do
    res[ind] = i
    ind = ind + 1
  end

  return res
end

---Get a list or {x}
---@param x any
---@param force? boolean
---@return table
function list.as_list(x, force)
  if force then
    return { x }
  elseif type(x) == 'table' then
    return x
  else
    return { x }
  end
end

---Extract the list component (Mutates the table)
---@param x table
---@return table
function list.extract(x)
  local res = {}
  for i = 1, #x do res[i] = x[i] end
  return res
end

---Take N elements from the beginning of the list
---@param x table
---@param n number
---@return table
function list.take(x, n)
  local res = {}
  local len = #x
  if n > len then return x end
  for i = 1, n do res[i] = x[i] end
  return res
end

---Filter list elements
---@param x table
---@param f function
---@param pass_index? boolean
---@param map? (fun(any): any)
---@return table
function list.filter(x, f, pass_index, map)
  local out = {}

  for i = 1, #x do
    local v = x[i]

    if pass_index then
      ok = f(i, v)
    else
      ok = f(v)
    end

    if ok then
      if map then
        if pass_index then
          list.push(out, map(i, v))
        else
          list.push(out, map(v))
        end
      else
        list.push(out, v)
      end
    end
  end

  return out
end

---Map list elements
---@param x table
---@param f (fun(e: any): boolean) | (fun(i: number, e: any): boolean)
---@param pass_index? boolean Pass index along with the element
---@return table
function list.map(x, f, pass_index)
  local res = {}

  for i = 1, #x do
    if pass_index then
      res[i] = f(i, x[i])
    else
      res[i] = f(x[i])
    end
  end

  return res
end

---Get nth element of list
---@param x table
---@param n number Negative indices will be treated as #x + i
---@return any?
function list.nth(x, n)
  if n < 0 then n = n + #x end
  return x[n]
end

---Is table a valid list?
---@param t table
---@return boolean
function list.is_list(t)
  local i = 0
  for _ in pairs(t) do
    i = i + 1
    if t[i] == nil then return false end
  end
  return true
end

---Pop element (at index or at the end)
---@param x table
---@param pos? number Negative indexing: #x + <index>
---@return any?, table
function list.pop(x, pos)
  pos = pos or #x
  pos = pos < 0 and pos + #x or pos
  local v = x[pos]

  if v ~= nil then
    table.remove(x, pos)
    return v, x
  end

  return nil, x
end

---Pop several elements (at index or at the end)
---@param x table
---@param times? number (default: 1)
---@return any?, table
function list.popn(x, times)
  local len = #x
  times = times or 1
  times = times > len and len or times
  local out = {}
  local ind = 1

  for i = 0, times - 1 do
    out[ind] = table.remove(x, len - i)
    ind = ind + 1
  end

  return out, x
end

---Return a boolean list
---@param x table
---@param y table
---@param res? table resulting table
---@return boolean[]
function list.compare(x, y, res)
  res = res or {}
  local limit = math.min(#x, #y)

  for i = 1, limit do
    if type(x[i]) == 'table' and type(y[i]) == 'table' then
      res[i] = {}
      list.compare(x[i], y[i], res[i])
    else
      res[i] = x[i] == y[i]
    end
  end

  return res
end

---Calculate absolute equality between lists
---@param x table
---@param y table
---@param cmp? fun(x: any, y: any): boolean
---@return boolean
function list.equal(x, y, cmp)
  cmp = cmp or function(a, b) return a == b end

  for key, value in pairs(x) do
    local y_value = y[key]
    if type(value) == 'table' and type(y_value) == 'table' then
      local ok = list.equal(value, y[key], cmp)
      if not ok then return false end
    elseif not cmp(value, y_value) then
      return false
    end
  end

  return true
end

---Set list element if indices are valid
---@param x table
---@param ks number[]
---@param value any
---@return any?, table
function list.set(x, ks, value)
  local _x = x

  for i = 1, #ks - 1 do
    local k = ks[i]
    local v = x[k]
    if type(v) == 'table' then
      x = v
    else
      return nil, x
    end
  end

  x[ks[#ks]] = value
  return _x, x
end

---Check if element exists at index
---@param x table
---@param ks number[]
---@return boolean
function list.has(x, ks)
  for i = 1, #ks - 1 do
    local k = ks[i]
    local v = x[k]
    if type(v) ~= 'table' then
      return false
    else
      x = v
    end
  end

  return x[ks[#ks]] ~= nil
end

---Get element at index
---@param x table
---@param ks number[]
---@param map? (fun(x: any): any) apply function to the retrieved element
---@return any?, table
function list.get(x, ks, map)
  for i = 1, #ks - 1 do
    local k = ks[i]
    local v = x[k]
    if type(v) ~= 'table' then
      return nil, x
    else
      x = v
    end
  end

  local v = x[ks[#ks]]
  if v ~= nil then
    if map then return map(v), x end
    return v, x
  else
    return nil, x
  end
end

---Check if index is a table
---@param x table
---@param ks number[]
---@return boolean
function list.has_path(x, ks)
  return type((list.get(x, ks))) == 'table'
end

---Slice list elements. Supports negative indexing
---@param x table
---@param i number
---@param j? number (default: #x)
---@return table
function list.slice(x, i, j)
  local res = {}
  local len = #x
  j = j or len
  i = i < 0 and len + i or i
  j = j < 0 and len + j or j

  if i > j then
    return {}
  end

  local ind = 1
  for _i = i, j do
    res[ind] = x[_i]
    ind = ind + 1
  end

  return res
end

---Sort table inplace
---@param x table
---@param cmp? function
---@return table
function list.sort(x, cmp)
  table.sort(x, cmp)
  return x
end

---Return the index of the value queried
---@param x table
---@param value any
---@param cmp? (fun(a: any, b: any): boolean)
---@return number | boolean
function list.index1(x, value, cmp)
  cmp = cmp or function(a, b) return a == b end

  for i = 1, #x do
    local x_value = x[i]
    if cmp(x_value, value) then
      return i
    end
  end

  return false
end

---@class list.index.opts
---@field times? number (default: 1)
---@field once? boolean (default: true)
---@field cmp? (fun(a: any, b: any): boolean)
---@field compare? (fun(a: any, b: any): boolean) alias for opts.cmp

---Find indices/index of the value
---@param x table
---@param value any
---@param opts? list.index.opts
---@return (number | number[])?
function list.index(x, value, opts)
  opts = opts or {}
  local times = ifnil(opts.times, 1)
  local once = ifelse(times == 1, true, opts.once)
  once = ifelse(times > 1, false, once)
  local res = {}
  local ind = 1
  local cmp = opts.cmp or opts.compare or function(a, b)
    return a == b
  end

  for i = 1, #x do
    local v = x[i]
    local ok = cmp(v, value)

    if times == 0 then
      if ok and once then
        return i
      else
        return res
      end
    elseif ok and once then
      return i
    elseif ok then
      res[ind] = i
      ind = ind + 1
      times = times - 1
    end
  end

  return res
end

---Recursively flatten the list
---@param x table
---@param res? table resulting table
---@return table
function list.flatten(x, res)
  res = res or {}

  for i = 1, #x do
    local v = x[i]
    if type(v) == 'table' then
      list.flatten(v, res)
    else
      res[#res + 1] = v
    end
  end

  return res
end

---Apply function to each element
---@param x table
---@param f (fun(number, any) | fun(any))
---@param pass_index? boolean
function list.each(x, f, pass_index)
  for i = 1, #x do
    if pass_index then
      f(i, x[i])
    else
      f(x[i])
    end
  end
end

---Zip two lists
---@param x table
---@param y table
---@param shortest? boolean (default: false) zip elements according to the longer list
---@param mkdefault? (fun(): any) (default: `function() return false end`) fill value to compute will zipping
---@return table
function list.zip2(x, y, shortest, mkdefault)
  mkdefault = mkdefault or function() return false end
  local res = {}
  local x_len = #x
  local y_len = #y
  shortest = ifnil(shortest, false, true)
  local len

  if shortest then
    len = math.min(x_len, y_len)
  else
    len = math.max(x_len, y_len)
  end

  for i = 1, len do
    local x_value = ifnil(x[i], mkdefault())
    local y_value = ifnil(y[i], mkdefault())
    res[i] = { x_value, y_value }
  end

  return res
end

---Filter list elements if condition does not match
---@param x table
---@param f (fun(any): boolean)
---@param pass_index? boolean
---@param map? (fun(any): any)
---@return table
function list.filter_unless(x, f, pass_index, map)
  local out = {}

  for i = 1, #x do
    local ok
    local v = x[i]

    if pass_index then
      ok = f(i, v)
    else
      ok = f(v)
    end

    if not ok then
      if map then
        if pass_index then
          list.push(out, map(i, v))
        else
          list.push(out, map(v))
        end
      else
        list.push(out, v)
      end
    end
  end

  return out
end

---Return all elements but the last one
---@param t table
---@param n? number (default: 1) elements returned are #t - 1 in number
---@return table
function list.butlast(t, n)
  n = n or 1
  local len = #t
  local new = {}

  for i = 1, len - n do
    new[i] = t[i]
  end

  return new
end

---Return elements at the beginning of the list
---@param t table
---@param n number? (default: 1)
---@return table
function list.head(t, n)
  n = n or 1
  local out = {}

  for i = 1, n do
    out[i] = t[i]
  end

  return out
end

---Return elements at the end of the list
---@param t table
---@param n number? (default: 1)
---@return table
function list.tail(t, n)
  n = n or 1
  local len = #t

  if n == 1 then
    return { t[len] }
  end

  n = n or 1
  local out = {}

  for i = len - (n - 1), len do
    list.push(out, t[i])
  end

  return out
end

---Similar to lisp's cdr. Skips N elements at the beginning
---@param t table
---@param n? number (default: 1)
---@return table
function list.rest(t, n)
  n = n or 1
  local out = {}

  for i = n + 1, #t do
    list.push(out, t[i])
  end

  return out
end

---Reduce list with an accumulator
---@param x table
---@param acc any initial value
---@param f function
---@return any
function list.reduce(x, acc, f)
  for i = 1, #x do acc = f(x[i], acc) end
  return acc
end

---Return the last element
---@param x table
---@return any
function list.last(x)
  return x[#x]
end

---Zip several lists together by shortest length
---@param ... table
---@return table[]
function list.zip(...)
  local args = { ... }
  local lens = list.map(args, list.length)
  local minlen = list.min(lens)
  local out = {}

  local function zip(start)
    if start > minlen then
      return
    end

    local current = out[start]
    if not current then
      list.push(out, {})
      current = list.last(out)
    end

    for j = 1, #args do
      local v = args[j][start]
      list.push(current, v)
    end

    zip(start + 1)
  end

  zip(1)
  return out
end

---Zip several lists together by longest length
---@param ... table
---@return table[]
function list.zip_longest(fillvalue, ...)
  local args = { ... }
  local lens = list.map(args, list.length)
  local maxlen = list.max(lens)
  local out = {}

  local function zip(start)
    start = start or 1
    if start > maxlen then
      return
    end

    local current = out[start]
    if not current then
      list.push(out, {})
      current = list.last(out)
    end

    for j = 1, #args do
      local v = args[j][start]
      if v == nil then v = fillvalue end
      list.push(current, v)
    end

    zip(start + 1)
  end

  zip()
  return out
end

---Pop element at the beginning of the list
---@param x table
---@return any, table
function list.shift(x)
  local pos = 1
  if x[pos] == nil then return nil, x end
  return list.pop(x, pos)
end

---Pop N elements at the beginning of the list
---@param x table
---@param times? number (default: 1)
---@return any, table
function list.shiftn(x, times)
  local out = {}
  local len = #x

  if len == 0 then
    return nil, x
  end

  times = math.min(len, times or 1)
  for _ = 1, times or 1 do
    list.push(out, (list.pop(x, 1)))
  end

  return out, x
end

---Check if all elements are truthy
---@param t table
---@param f fun(x: any): any
---@return boolean
function list.all(t, f)
  f = f or function(x)
    return x
  end

  for i = 1, #t do
    if f then
      if not f(t[i]) then
        return false
      end
    elseif not t[i] then
      return false
    end
  end

  return true
end

---Check if some elements are truthy
---@param t table
---@param f fun(x: any): any
---@return boolean
function list.some(t, f)
  for i = 1, #t do
    if f then
      if f(t[i]) then
        return true
      end
    elseif t[i] then
      return true
    end
  end

  return false
end

---Partition or chunk list
---@param x table
---@param fun_or_num number | (fun(x: any): boolean)
---@return table[]
function list.partition(x, fun_or_num)
  if type(fun_or_num) ~= 'number' then
    local result = { {}, {} }
    for i = 1, #x do
      if fun_or_num(x[i]) then
        list.append(result[1], x[i])
      else
        list.append(result[2], x[i])
      end
    end
    return result
  end

  local len = #x
  local chunk_size = math.ceil(len / fun_or_num)
  local result = {}

  for i = 1, len, chunk_size do
    list.push(result, {})
    local curr = list.last(result)
    for j = 1, chunk_size do
      list.push(curr, x[i + j - 1])
    end
  end

  return result
end

---Chunk list
---@param x table
---@param chunk_size number
---@return table[]
function list.chunk(x, chunk_size)
  chunk_size = chunk_size or 2
  return list.partition(x, chunk_size)
end

---Binary search for an element
---@param x table
---@param value any
---@param f? (fun(a: any, b: any): number)
---@return number?, any
function list.bsearch(x, value, f)
  local function bsearch(arr, elem, cmp, i, j)
    i = i or 1
    j = j or #arr

    if j < i then
      return nil, nil
    end

    local mid = i + math.floor((j - i) / 2)
    local mid_elem = arr[mid]
    local result = cmp(elem, mid_elem)

    if result == 0 then
      return mid, mid_elem
    elseif result == 1 then
      return bsearch(arr, elem, cmp, i, mid - 1)
    elseif result == -1 then
      return bsearch(arr, elem, cmp, mid + 1, j)
    end
  end

  f = f or function(a, b)
    if a == b then
      return 0
    elseif a > b then
      return -1
    else
      return 1
    end
  end

  return bsearch(x, value, f)
end

local function join_tables(x, y, force, visited)
  visited = visited or setmetatable({}, { __mode = 'k' })
  local cache = function(a, b)
    visited[a] = visited[a] or {}
    visited[a][b] = true
  end
  local exists = function(a, b)
    local ok = visited[a]
    if ok then return ok[b] end
  end

  for key, value in pairs(y) do
    local x_value = x[key]
    local y_value = value

    if x_value == nil then
      x[key] = y_value
    elseif type(y_value) == 'table' then
      if type(x_value) == 'table' and not exists(y_value, x_value) then
        cache(y_value, x_value)
        join_tables(x_value, y_value, force, visited)
      elseif force then
        x[key] = y_value
      end
    else
      x[key] = y_value
    end
  end
end

---Merge two lists. Warning! This can lead to holes in the list
---@param x table
---@param y table
---@param force boolean
---@return table
function list.merge(x, y, force)
  join_tables(x, y, force)
  return x
end

---Merge two lists but take elements from the right directly. Warning! This can lead to holes in the list
---@param x table
---@param y table
---@return table
function list.force_merge(x, y)
  return list.merge(x, y, true)
end

---Fix list by using a fill value in place of non-consecutive indices
---Do not use this function often as it is expensive to run
---@param x table
---@param fillvalue (fun(): any) Fill value generating function. By default, 'false' will be used
---@param depth? number (default: -1) Recursively fix all lists. If depth < 0, then recursively fix all the lists
---@param visited? table Cache table to prevent unnecessary recursion
---@return table
function list.fix(x, fillvalue, depth, visited)
  visited = visited or setmetatable({}, { __mode = 'k' })
  local ks = {}
  local i = 1
  fillvalue = fillvalue or function() return false end
  local tbls = {}
  local tbl_i = 1
  depth = depth or -1

  for key, value in pairs(x) do
    ks[i] = key
    i = i + 1

    if type(value) == 'table' and not visited[value] then
      tbls[tbl_i] = value
      tbl_i = tbl_i + 1
      visited[value] = true
    end
  end

  ks = list.filter(ks, function(k) return type(k) == 'number' end)
  local min = math.min(unpack(ks))
  local max = math.max(unpack(ks))

  for _i = 1, min - 1 do
    if not x[_i] then x[_i] = fillvalue() end
  end

  for _i = min + 1, max - 1 do
    if not x[_i] then x[_i] = fillvalue() end
  end

  if depth == 1 or depth == 0 then
    return x
  elseif depth < 0 then
    for _, t in ipairs(tbls) do
      list.fix(t, fillvalue, -1, visited)
    end
  else
    for _, t in ipairs(tbls) do
      list.fix(t, fillvalue, depth - 1, visited)
    end
  end

  return x
end

---Copy list
---@param x table
---@param deep? boolean
---@return table
function list.copy(x, deep)
  return copy(x, deep)
end

---Match elements and return their elements
---@param x table
---@param elems table
---@return (number|boolean)[]
function list.match(x, elems)
  local res = {}

  for i, elem in ipairs(elems) do
    res[i] = list.index(x, elem)
  end

  return res
end

---Return elements by indices
---@param x table
---@param pos (number | number[])[]
---@return table
function list.select(x, pos)
  local res = {}

  for key, p in pairs(pos) do
    local v = list.get(x, as_list(p))
    res[key] = ifnil(v, false)
  end

  return res
end

---Flatten everything and return a single list. Directly analogous to c() of R
---@return table
function list:__call(...)
  local res = {}
  local res_i = 1
  local args = tuple.pack(...)
  local function call(elem)
    if type(elem) == 'table' then
      for i = 1, #elem do
        local x = elem[i]
        if type(x) == 'table' then
          call(x)
        else
          res[res_i] = x
          res_i = res_i + 1
        end
      end
    else
      res[res_i] = elem
      res_i = res_i + 1
    end
  end

  for i = 1, #args do call(args[i]) end
  return res
end

---Is x a subset of y?
---@param x table
---@param y table
---@return boolean
function list.subset_of(x, y)
  local y_ = {}
  for i = 1, #y do
    y_[y[i]] = true
  end

  for value, _ in pairs(x) do
    if not y_[value] then
      return false
    end
  end

  return true
end

---Is x a superset of y?
---@param x table
---@param y table
---@return boolean
function list.superset_of(x, y)
  local x_ = {}
  for i = 1, #x do
    x_[x[i]] = true
  end

  for value, _ in pairs(y) do
    if not x_[value] then
      return false
    end
  end

  return true
end

---Set difference
---@param x table
---@param y table
---@return table
function list.difference(x, y)
  local res = {}
  local ind = 0
  local y_ = {}

  for i = 1, #y do
    y_[y[i]] = true
  end

  for i = 1, #x do
    if not y_[x[i]] then
      res[ind + 1] = x[i]
      ind = ind + 1
    end
  end

  return res
end

---Set intersection
---@param x table
---@param y table
---@return table
function list.intersection(x, y)
  local cache = {}
  local res = {}
  local ind = 0

  for _, value in pairs(x) do
    if y[value] then
      cache[value] = true
      res[ind + 1] = value
      ind = ind + 1
    end
  end

  for _, value in pairs(y) do
    if x[value] and not cache[value] then
      res[ind + 1] = value
      ind = ind + 1
    end
  end

  return res
end

---Set union
---@param x table
---@param y table
---@return table
function list.union(x, y)
  local cache = {}
  local res = {}
  local ind = 0

  for i = 1, #x do
    local v = x[i]
    if not cache[v] then
      res[ind + 1] = v
      cache[v] = true
      ind = ind + 1
    end
  end

  for i = 1, #y do
    local v = y[i]
    if not cache[v] then
      res[ind + 1] = v
      cache[v] = true
      ind = ind + 1
    end
  end

  return res
end

---Get list as a dict with keys as its elements
---@param x table
---@param default? (fun(value: any): any) By default maps every element to true
---@return table
function list.as_dict(x, default)
  default = default or function(_)
    return true
  end

  local res = {}
  for i = 1, #x do
    res[x[i]] = default(x[i])
  end

  return res
end

---Select index if elem at index is truthy
---To be used in conjunction with list.test
---@param x table
---@param bool_x boolean[]
---@param invert? boolean (default: false)
---@return table
function list.pick(x, bool_x, invert)
  invert = ifnil(invert, false)
  local len_x = #x
  local len_bool_x = #bool_x

  if len_x ~= len_bool_x then
    error(sprintf('expected x and bool_x to be of equal length, got %d (x), %s (bool_x)', len_x, len_bool_x))
  end

  local res = {}
  local res_i = 1

  for i = 1, len_x do
    local ok = bool_x[i]
    ok = ifelse(invert, not ok, ok)
    if ok then
      res[res_i] = x[i]
      res_i = res_i + 1
    end
  end

  return res
end

---Return a boolean array by applying f() to every element
---@param x table
---@param f function | table
function list.test(x, f)
  local res = {}

  for i = 1, #x do
    local v = x[i]
    res[i] = ifelse(f(v), true, false)
  end

  return res
end

list.lappend = list.unpush
list.fmerge = list.force_merge
list.cdr = list.rest
list.nthcdr = list.rest
list.append = list.push
list.size = list.length

function list:import()
  _G.list = self
end

return list
