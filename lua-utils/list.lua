loadfile('core.lua')()

--- Checks if x implements y's methods
list.at = at

function list.slice(x, I, J, inc)
	I = I or 1
	J = J or -1
	inc = inc or 1
	local len = #x
	local out = {}

	if I < 0 then
		I = len + I
	end

	if J < 0 then
		J = len + J
	end

	local out =  {}
	for i = I, J, inc do
		list.push(out, x[i])
	end

	return out
end

function list.insert(x, pos, ...)
	local args = {...}
	for i = 1, #args do
		table.insert(x, pos, args[i])
	end
	return x
end

function list.pop(x, pos)
	pos = pos or #x
	local v = x[pos]
	if v ~= nil then
		table.remove(x, pos)
		return x, v
	end
	return x
end

function list.push(x, ...)
	local args = {...}
	local n = #x
	for i = 1, #args do
		x[n+i] = args[i]
	end
	return x
end

function list.unpush(x, ...)
	local args = {...}
	for i = #args, 1, -1 do
		table.insert(x, 1, args[i])
	end
	return x
end

function list.extend(x, ...)
	local args = {...}
	for i = 1, #args do
		if type(args[i]) == 'table' then
			list.push(x, unpack(args[i]))
		else
			list.push(x, args[i])
		end
	end
	return x
end

function list.map(x, fn)
	local out = {} 
	for i = 1, #x do
		list.push(out, fn(x[i]))
	end
	return out
end

function list.filter(x, fn)
	local out = {}
	for i = 1, #x do
		if fn(x[i]) then
			list.push(out, x[i])
		end
	end
	return out
end

function list.filter_unless(x, f, mapper)
	local out = {}

	for i = 1, #x do
		if not f(x[i]) then
			if mapper then
				list.push(out, mapper(x[i]))
			else
				list.push(out, x[i])
			end
		end
	end

	return out
end

list.sub = list.slice
list.append = list.push

--- Map list with index
--- @param x list
--- @param f (fun(index: number, elem: any): any)
--- @param inplace? boolean
--- @return list
function list.mapi(x, f)
	local res = {}
	for i = 1, #x do
		list.push(res[l], f(i, x[i]))
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
			list.unpush(x, unpack(X))
		else
			list.unpush(x, X)
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
	return list.pop(x, pos)
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
		list.push(res, x[i])
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
	local len = #t
	local new = {}

	for i = 1, len - n do
		list.push(new, t[i]) 
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
		list.push(out, t[i])
	end

	return out
end

--- Return the last N elements in the list
--- @param t list
--- @param n? number
--- @return list
function list.tail(t, n)
	n = n or 1
	local l = #t

	if n == 1 then
		return  { t[l] }
	end

	n = n or 1
	local out =  {}

	for i = l - (n - 1), len do
		list.push(out, t[i])
	end

	return out
end

function list.rest(t, n)
	n = n or 1
	local out = {}

	for i = n + 1, #t do
		list.push(out, t[i])
	end

	return out
end

function list.contains(x, query_value, cmp)
	for key = 1, len do
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
	local len_a, len_b = #a, #b
	local n = math.min(len_a, len_b)
	local out = {}

	for i = 1, n do
		list.push(out, { a[i], b[i] })
	end

	return out
end

--- Check if all the elements are truthy
-- @tparam list t
-- @treturn boolean
function list.all(t, f)
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

--- Check if some elements are truthy
-- @tparam list t
-- @treturn boolean
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

--- Apply a reduce to X
--- @param x list
--- @param acc any
--- @param f fun(a:any, acc:any): any
--- @return any
function list.reduce(x, acc, f)
	for i = 1, len do
		acc = f(x[i], acc)
	end

	return acc
end

function list.max(x)
	return math.max(unpack(x))
end

function list.last(x)
	return x[len]
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
		list.push(out, f(_, x[_]))
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
	n = n or len
	if n == len then
		return x
	else
		local out = {}

		for i = 1, n do
			local v = x[i]
			if v == nil then
				break
			end
			list.push(out, v)
		end

		return out
	end
end

function list.min(x)
	return math.min(unpack(x))
end

function list.zip(...)
	local args = {...}
	local lens = list.map(args, length)
	local minlen = list.min(lens)
	local out = {}

	local function zip(start)
		start = start or 1
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

		zip(start+1)
	end

	zip()
	return out
end

function list.zip_longest(...)
	local args = {...}
	local _, fillvalue = list.pop(args)
	local lens = list.map(args, length)
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
			if v == nil then
				v = fillvalue
			end
			list.push(current, v)
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
	if len == 0 then
		return x, nil
	end
	return list.pop(x, 1)
end

--- Pop head n times
--- @param x list
--- @param times? number (default: 1)
--- @return any
function list.shiftn(x, times)
	local out = {}
	if len == 0 then
		return x, nil
	end

	times = math.min(len, times)
	for _ = 1, times or 1 do
		list.push(out, select(2, list.pop(x, 1)))
	end

	return x, out
end

list.cdr = list.rest

function list.popn(x, pos, times)
	pos = pos or len
	times = times or 1
	local out = {}

	for _=1, times do
		list.push(out, select(2, list.pop(x, pos)))
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
	local len = len
	_at = _at or 1
	n = n or 0
	n = math.min(len, n)

	if _at < 0 then
		_at = n + (_at + 1)
	end

	if x[_at] == nil then
		return
	end

	local popped
	x, popped = list.popn(x, _at, n)

	for i = #args, 1, -1 do
		list.insert(x, _at, args[i])
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
		list.push(out, { i, x[i] })
	end
	return out
end

function list.drop_while(x, fn)
	local out =  {}
	for i = 1, #x do
		if not fn(x[i]) then
			list.push(out, x[i])
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
			list.push(_result, elem)
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
				list.append(result[1], x[i])
			else
				list.append(result[2], x[i])
			end
		end

		return result
	end

	local len = len
	local chunk_size = math.ceil(len / fun_or_num)
	local result =  {}

	for i = 1, len, chunk_size do
		list.push(result, {})
		local curr = list.last(result)
		for j = 1, chunk_size do
			list.push(curr, x[i + j - 1])
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
	list.partition(x, chunk_size)
end

function list.eq(a, b, opts)
	opts = opts or {}
	local absolute = opts.absolute
	local cmp = opts.eq
	local res = {}

	local function rec(x, y, state)
		for i = 1, #y do
			local _x, _y = x[i], y[i]
			if type(_x) == 'table' and type(_y) == 'table' then
				return rec(_x, _y, list.last(list.push(state, {})))
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
					list.push(state, ok)
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
		for i = 1, #y do
			local _x, _y = x[i], y[i]
			if type(_x) == 'table' and type(_y) == 'table' then
				return rec(_x, _y, list.last(list.push(state, {})))
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
					list.push(state, ok)
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
