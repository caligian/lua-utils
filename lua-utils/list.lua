loadfile('core.lua')()

--- Checks if x implements y's methods
list = {
  _meta = {
    type = 'ns',
  },
	at = at,
  slice = function (x, I, J, inc)
    I = I or 1
    J = J or -1
    inc = inc or 1
		x.length = x.length or #x
		local out = {}

    if I < 0 then
      I = x.length + I
    end

    if J < 0 then
      J = x.length + J
    end

    local out =  {}
    for i = I, J, inc do
			list.push(out, x[i])
    end

    return out
  end,
  insert = function (x, pos, ...)
    local args = {...}
		x.length = x.length or #x
    for i = 1, #args do
      table.insert(x, pos, args[i])
      x.length = x.length + 1
    end
    return x
  end,
  pop = function (x, pos)
		x.length = x.length or #x
    pos = pos or x.length
    local v = x[pos]
    if v ~= nil then
      table.remove(x, pos)
      x.length = x.length - 1
      return x, v
    end
    return x
  end,
	push = function (x, ...)
    local args = {...}
		x.length = x.length or #x
    local n = x.length
    for i = 1, #args do
      n = n + 1
      x[n] = args[i]
    end
    x.length = n
    return x
  end,
  unpush = function (x, ...)
    local args = {...}
		x.length = x.length or #x
    for i = #args, 1, -1 do
      table.insert(x, 1, args[i])
      x.length = x.length + 1
    end
    return x
  end,
  extend = function (x, ...)
    local args = {...}
    for i = 1, #args do
      if type(args[i]) == 'table' then
				list.push(x, unpack(args[i]))
      else
				list.push(x, args[i])
      end
    end
    return x
  end,
  map = function (x, fn)
    local out = {} 
		x.length = x.length or #x 
    for i = 1, x.length do
			list.push(out, fn(x[i]))
    end
    return out
  end,
  filter = function (x, fn)
    local out = {}
		x.length = x.length or #x 
    for i = 1, x.length do
      if fn(x[i]) then
				list.push(out, x[i])
      end
    end
    return out
  end,
  filter_map = function (x, fn, mapfn)
    local out = {}
    out = list.filter(x, fn)
    return mapfn and list.map(out, mapfn) or out
  end,

  --- Filter list if f() fails
  --- @param x list
  --- @param f list_mapper
  --- @param mapper? list_mapper
  --- @return list
  filter_unless = function(x, f, mapper)
    local out = {length = 0}
		x.length = x.length or 1
    for i = 1, x.length do
      if not f(x[i]) then
				out.length = out.length + 1
        if mapper then
          out[out.length] = mapper(x[i])
        else
          out[out.length] = x[i]
        end
      end
    end
    return out
  end,
}

list.sub = list.slice

function is_list(x)
	return type(x) == 'table' and x._meta and x._meta.type == 'list'
end

list.append = list.push

--- Map list with index
--- @param x list
--- @param f (fun(index: number, elem: any): any)
--- @param inplace? boolean
--- @return list
function list.mapi(x, f)
  local res = {}
  for i = 1, #x do
    res:push(f(i, x[i]))
  end
  return res
end

--- Extend list at the beginning with other lists
--- @param x list
--- @param args list
--- @return list
function list.lextend(x, ...)
  local args = { ... }

  for i = #args, 1, -1 do
    local X = args[i]
    if type(X) == 'table' then
      x:unpush(unpack(X))
    else
      x:unpush(X)
    end
  end

  return x
end

--- Pop head
--- @param x list
--- @return any
function list.shift(x)
  local pos = 1
  if x[pos] == nil then
    return x
  end
  return x:pop(pos)
end

--- Join list with a string
--- @param x list
--- @param sep string
--- @return string
function list.join(x, sep)
  sep = sep or " "
  return table.concat(x, sep)
end

--- Reverse list or string
--- @param x list|string
--- @return list|string
function list.reverse(x)
  local res = {}
  for i = #x, 1, -1 do
    res:push(x[i])
  end
  return res
end

--- Sort table
--- @param x list
--- @param cmp? function
--- @return list
function list.sort(x, cmp)
  table.sort(x, cmp)
  return x
end

--- Apply function to each element with index
--- @param t list
--- @param f fun(index:number, elem:any)
function list.eachi(t, f)
  for _, v in ipairs(t) do
    f(_, v)
  end
end

--- Apply function to each element
--- @param t list
--- @param f fun(elem:any)
function list.each(t, f)
  for _, v in ipairs(t) do
    f(v)
  end
end

--- Return the first N-1 elements in the list
--- @param t list
--- @param n? number
--- @return list
function list.butlast(t, n)
  n = n or 1
  local len = t.length
  local new = {}

  for i = 1, len - n do
    new:push(t[i])
  end

  return new
end

--- Return the first N elements
--- @param t list
--- @param n number element[s]
--- @return list
function list.head(t, n)
  n = n or 1
  local out = {}

  for i = 1, n do
    list:push(t[i])
  end

  return out
end

--- Return the last N elements in the list
--- @param t list
--- @param n? number
--- @return list
function list.tail(t, n)
  n = n or 1

  if n == 1 then
    return  { t[t.length] }
  end

  n = n or 1
  local out =  {}
  local len = t.length

  for i = len - (n - 1), len do
    out:push(t[i])
  end

  return out
end

function list.rest(t, n)
  n = n or 1
  local out = {}

  for i = n + 1, t.length do
    out:push(t[i])
  end

  return out
end

function list.contains(x, query_value, cmp)
  for key = 1, x.length do
    local value = x[key]

    if cmp then
      if cmp(query_value, value) then
        return key
      end
    elseif query_value == value then
      return key
    end
  end
end

--- Zip two lists element-wise in the form {x, y}
function list.zip2(a, b)
  local len_a, len_b = a.length, b.length
  local n = math.min(len_a, len_b)
  local out = {}
  for i = 1, n do
    out:push( { a[i], b[i] })
  end

  return out
end

--- Check if all the elements are truthy
-- @tparam list t
-- @treturn boolean
function list.all(t, f)
  for i = 1, t.length do
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

--- Check if some elements are truthy
-- @tparam list t
-- @treturn boolean
function list.some(t, f)
  for i = 1, t.length do
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

--- Apply a reduce to X
--- @param x list
--- @param acc any
--- @param f fun(a:any, acc:any): any
--- @return any
function list.reduce(x, acc, f)
  for i = 1, x.length do
    acc = f(x[i], acc)
  end

  return acc
end

function list.max(x)
  return math.max(unpack(x))
end

function list.last(x)
  return x[x.length]
end

function list.enumerate(...)
  local args = {...}
  local x = args[1]
  local i, j, inc
  local n = #args
  local f
  local out = {}

  if n == 3 then
    i = args[2]
    f = args[3]
    j = #x
  elseif n == 4 then
    i = args[2]
    j = args[3]
    f = args[4]
  elseif n == 5 then
    i = args[2]
    j = args[3]
    inc = args[4]
    f = args[5]
  else
    f = args[2]
    i = 1
    j = #x
  end

  inc = inc or 1
  for _ = i, j, inc  do
    out:push(f(_, x[_]))
  end

  return out
end

function list.range(...)
  local args = {...}
  local x = args[1]
  local i, j, inc
  local n = #args
  local f

  if n == 3 then
    i = args[2]
    j = args[3]
    f = args[4]
  elseif n == 4 then
    i = args[2]
    j = args[3]
    f = args[4]
  elseif n == 5 then
    i = args[2]
    j = args[3]
    inc = args[4]
    f = args[5]
  else
    f = args[2]
    i = 1
    j = #x
  end

  inc = inc or 1
  for _ = i, j, inc  do
    f(_, x[_])
  end
end

function list.take(x, n)
  n = n or x.length
  if n == x.length then
    return x
  else
    local out =  {}
    for i = 1, n do
      local v = x[i]
      if v == nil then
        break
      end
      out:push(v)
    end

    return out
  end
end

function list.min(x)
  return math.min(unpack(x))
end

function list.zip(...)
  local args = {...}
  local lens = args:map(length)
  local minlen = lens:min()
  local out = {}
  local i = 1

  local function zip(start)
    start = start or 1
    if start > minlen then
      return
    end
    local current = out[start]
    if not current then
      out:push({})
      current = out:last()
    end

    for j = 1, args.length do
      local v = args[j][start]
      current:push(v)
    end

    zip(start+1)
  end

  zip()
  return out
end

function list.zip_longest(...)
  local args = {...}
  local _, fillvalue = args:pop()
  local lens = args:map(length)
  local maxlen = lens:max()
  local out = {}

  local function zip(start)
    start = start or 1
    if start > maxlen then
      return
    end
    local current = out[start]
    if not current then
      out:push({})
      current = out:last()
    end

    for j = 1, args.length do
      local v = args[j][start]
      if v == nil then
        v = fillvalue
      end
      current:push(v)
    end

    zip(start+1)
  end

  zip()
  return out
end

--- Pop head
--- @param x list
--- @return any
function list.shift(x)
  if x.length == 0 then
    return x, nil
  end
  return x:pop(1)
end

--- Pop head n times
--- @param x list
--- @param times? number (default: 1)
--- @return any
function list.shiftn(x, times)
  local out = {}
  if x.length == 0 then
    return x, nil
  end

  times = math.min(x.length, times)
  for _ = 1, times or 1 do
    out:push(select(2, x:pop(1)))
  end

  return x, out
end

list.cdr = list.rest

function list.popn(x, pos, times)
  pos = pos or x.length
  times = times or 1
  local out = {}

  for _=1, times do
    out:push(select(2, x:pop(pos)))
  end

  return x, out
end

--- Modify list/string at a position. Returns nil on invalid index
--- @param X list|string returns `x` when no other args are given
--- @param at? number if `n` is not given, return everything from `at` till the end
--- @param n? number if given then pop N elements at index `at`
--- @param args any If given then insert these strings/elements at index `at`
--- @return (list|string)? popped Popped elements if any
--- @return (list|string)? new Resulting list|string
function list.splice(x, _at, n, ...)
  local args =  {...}
  local len = x.length
  _at = _at or 1
  n = n or 0
  n = math.min(x.length, n)

  if _at < 0 then
    _at = n + (_at + 1)
  end

  if x[_at] == nil then
    return
  end

  local popped
  x, popped = x:popn(_at, n)

  for i = args.length, 1, -1 do
    x:insert(_at, args[i])
  end

  return x, popped
end

local function bsearch(arr, elem, cmp, i, j)
  i = i or 1
  j = j or #arr

  if j < i then
    return
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

function list.bsearch(arr, elem, cmp)
  cmp = cmp or equals
  return bsearch(arr, elem, cmp)
end

function list.with_index(x)
  local out =  {}
  for i = 1, #x do
    out:push { i, x[i] }
  end
  return out
end

function list.drop_while(x, fn)
  local out =  {}
  for i = 1, #x do
    if not fn(x[i]) then
      out:push(x[i])
    end
  end

  return out
end

local function _flatten(x, depth, _len, _current_depth, _result)
  depth = depth or -1
  _len = _len or #x
  _current_depth = _current_depth or 1
  _result = _result or  {}

  if depth ~= -1 and _current_depth > depth then
    return _result
  end

  for i = 1, _len do
    local elem = x[i]
    if type(elem) == 'table' then
      _flatten(x[i], depth, _len, _current_depth + 1, _result)
    else
      _result:push(elem)
    end
  end

  return _result
end

--- Flatten list
--- @param x list
--- @param depth? number (default: 1)
--- @return list
function list.flatten(x, depth)
  return _flatten(x, depth)
end

--- Partition/chunk list
--- > local function greater_than_2(x) return x > 2 end
--- > partition({1, 2, 3, 4, 5}, greater_than_2) -- {{3, 4, 5}, {1, 2}}
--- > partition({1, 2, 3, 4}, 3) -- {{1, 2, 3}, {4}}
--- @param x list
--- @param fun_or_num number|function If method then elements that succeed the method will be placed in `result[1]` and the failures in `result[2]`. If number than chunk list
--- @return list result
function list.partition(x, fun_or_num)
  if is_method(fun_or_num) then
    local result =  { list:new {}, list:new {} }
    for i = 1, #x do
      if fun_or_num(x[i]) then
        result[1]:append(x[i])
      else
        result[2]:append(x[i])
      end
    end

    return result
  end

  local len = x.length
  local chunk_size = math.ceil(len / fun_or_num)
  local result =  {}

  for i = 1, len, chunk_size do
    result:push({})
    local curr = result:last()
    for j = 1, chunk_size do
      curr:push(x[i + j - 1])
    end
  end

  return result
end

--- Chunk list
--- > chunk_every({1, 2, 3, 4}, 2) -- {{1, 2}, {3, 4}}
--- @param x list
--- @param chunk_size? number (default: 2)
--- @return list
function list.chunk(x, chunk_size)
  chunk_size = chunk_size or 2
  return x:partition(chunk_size)
end

function list.eq(a, b, opts)
  opts = opts or {}
  local absolute = opts.absolute
  local cmp = opts.eq
  local res = {}

  local function rec(x, y, state)
    for i = 1, y.length do
      local _x, _y = x[i], y[i]
      if type(_x) == 'table' and type(_y) == 'table' then
        return rec(_x, _y, state:push({}):last())
      else
        local ok
        if cmp then
          ok = cmp(x[i], y[i])
        else
          ok = y[i] == x[i]
        end
        if not ok and absolute then
          return false
        else
          state:push(ok)
        end
      end
    end

    if absolute then
      return true
    else
      return state
    end
  end

  local ok = rec(a, b, res)
  if type(ok) == 'table' then
    return res
  else
    return ok
  end
end

function list.ne(a, b, opts)
  opts = opts or {}
  local absolute = opts.absolute
  local cmp = opts.eq
  local res = {}

  local function rec(x, y, state)
    for i = 1, y.length do
      local _x, _y = x[i], y[i]
      if type(_x) == 'table' and type(_y) == 'table' then
        return rec(_x, _y, state:push({}):last())
      else
        local ok
        if cmp then
          ok = not cmp(x[i], y[i])
        else
          ok = y[i] ~= x[i]
        end
        if not ok and absolute then
          return false
        else
          state:push(ok)
        end
      end
    end

    if absolute then
      return true
    else
      return state
    end
  end

  local ok = rec(a, b, res)
  if type(ok) == 'table' then
    return res
  else
    return ok
  end
end

function list.merge(x, ...)
  local args = { ... }
  local cache = setmetatable({}, {__mode = 'kv'})

  for i = 1, #args do
    local X = x
    local Y = args[i]
    local queue = setmetatable({}, {__mode = 'kv'})

    if not is_table(Y) then
      error(i .. ": expected table, got " .. type(Y))
    end

    while X and Y do
      for key=1, #Y do
				local value = Y[key]
        local x_value = X[key]

        if is_table(value) then
          if is_table(x_value) then
            if not cache[value] and not cache[x_value] then
              queue[#queue + 1] = { x_value, value }
            else
              cache[value] = true
              cache[x_value] = true
            end
          else
            X[key] = value
          end
        else
          X[key] = value
        end
      end

      local len = #queue
      if len ~= 0 then
        X, Y = unpack(queue[len])
        queue[len] = nil
      else
        break
      end
    end
  end

  return x
end


