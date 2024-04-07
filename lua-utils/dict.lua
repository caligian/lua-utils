loadfile 'list.lua'()

local function is_size(x, n)
  return size(x) == n
end

local function is_table(x)
  return type(x) == 'table'
end

local function is_length(x, n)
  return length(x) == n
end

dict = {
  keys = function (x)
    return keys(x)
  end,
  values = function (x)
    return values(x)
  end,
}
dict.__index = dict

function dict.filter(x, f, mapper)
  local out = {}
  for i, v in pairs(x) do
    if f(i, v) then
      if mapper then
        out[i] = mapper(i, v)
      else
        out[i] = v
      end
    end
  end
  return out
end

--- Filter dict if f() fails
--- @param x table
--- @param f dict_mapper
--- @param mapper? dict_mapper
--- @return table
function dict.filter_unless(x, f, mapper)
  local out = {}
  for i, v in pairs(x) do
    if not f(i, v) then
      if mapper then
        out[i] = mapper(i, v)
      else
        out[i] = v
      end
    end
  end
  return out
end

--- Map table with a function
--- @param x table
--- @param f dict_mapper
--- @param inplace? bool
--- @return table
function dict.map(x, f)
  local res = {}
  for i, v in pairs(x) do
    res[i] = f(i, v)
  end
  return res
end

--- Apply function to each element in a table
--- @param t table
--- @param f fun(key: any, elem:any)
function dict.each(t, f)
  for _, v in pairs(t) do
    f(_, v)
  end
end

function dict.contains(x, query_value, cmp)
  for key, value in pairs(x) do
    if cmp then
      if cmp(query_value, value) then
        return key
      end
    elseif query_value == value then
      return key
    end
  end
end

function dict.some(t, f)
  for key, value in pairs(t) do
    if f then
      if f(key, value) then
        return true
      end
    elseif value then
      return true
    end
  end

  return false
end

function dict.all(t, f)
  for key, value in pairs(t) do
    if f then
      if not f(key, value) then
        return false
      end
    elseif not value then
      return false
    end
  end

  return true
end

--- Apply a reduce to X
--- @param x list
--- @param acc any
--- @param f fun(key, value, acc): any
--- @return any
function dict.reduce(x, acc, f)
  for key, value in pairs(x) do
    acc = f(key, value, acc)
  end
  return acc
end

--- Partition dict
--- @param x table
--- @param fn fun(x):bool elements that succeed the method will be placed in `result[1]` and the failures in `result[2]`
--- @return list result
function dict.partition(x, fn)
  local result = { {}, {} }
  for key, value in pairs(x) do
    if fn(value) then
      result[1][key] = value
    else
      result[2][key] = value
    end
  end
  return result
end

function dict.drop_while(x, fn)
  local out = {}
  for key, value in pairs(x) do
    if not fn(key, value) then
      out[key] = value
    end
  end
  return out
end

--- Get key-value pairs from a table
--- @param t table
--- @return table
function dict.items(t)
  local out = {}
  local i = 1
  for key, val in pairs(t) do
    out[i] = { key, val }
    i = i + 1
  end
  return out
end

function dict.lmerge(x, ...)
  local args = { ... }
  local cache = setmetatable({}, {__mode = 'kv'})

  for i = 1, #args do
    local X = x
    local Y = args[i]
    local queue = setmetatable({}, {__mode == 'kv'})

    if not is_table(Y) then
      error(i .. ": expected table, got " .. type(Y))
    end

    while X and Y do
      for key, value in pairs(Y) do
        local x_value = X[key]

        if is_table(value) then
          if is_table(x_value) then
            if not cache[value] and not cache[x_value] then
              queue[#queue + 1] = { x_value, value }
            else
              cache[value] = true
              cache[x_value] = true
            end
          elseif is_nil(x_value) then
            X[key] = value
          end
        elseif is_nil(x_value) then
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

function dict.merge(x, ...)
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
      for key, value in pairs(Y) do
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

--- Create a dict from kv pairs
--- @param zipped list
--- @return table
function dict.from_zipped(zipped)
  local out = {}
  dict.each(zipped, function (z)
    out[z[1]] = z[2]
  end)
  return out
end

--- Create a dict from list of keys
--- @param X list
--- @param default? any (default: true)
--- @return table
function dict.from_list(X, default)
  local res = {}
  for i = 1, #X do
    if default then
      res[X[i]] = is_method(default) and default() or default
    else
      res[X[i]] = true
    end
  end
  return res
end

function dict.eq(a, b, opts)
  if type(opts) == 'boolean' then
    opts = {absolute = opts}
  end

  opts = opts or {}
  local abs = opts.absolute or opts.abs
  local state = not abs and {}

  local cmp = opts.eq or function (x, y)
    return x == y
  end

  local function rec(x, y, _state)
    for key, b in pairs(y) do
      local a = x[key]
      if is_table(a) and is_table(b) then
        _state[key] = {}
        return rec(a, b, _state[key])
      end

      local ok = cmp(a, b)
      if _state then
        _state[key] = ok
      elseif abs then
        return false
      end
    end

    if _state then
      return _state
    else
      return true
    end
  end

  local ok = rec(a, b, state)
  if is_table(ok) then
    return state
  else
    return ok
  end
end

dict.get = at

function dict.set(x, ks, value, fn)
	ks.length = #ks
	local tmp = x

	for i=1, ks.length-1 do
		if type(tmp[ks[i]]) == 'table' then
			tmp = tmp[ks[i]]
		else
			tmp[ks[i]] = {}
			tmp = tmp[ks[i]]
		end
	end

	if fn then
		value = fn(value)
	end

	tmp[ks[ks.length]] = value
	return x
end

function dict.get_and_set(x, ks, value)
	ks.length = #ks
	local tmp = x

	for i=1, ks.length-1 do
		if type(tmp[ks[i]]) == 'table' then
			tmp = tmp[ks[i]]
		else
			return
		end
	end

	tmp[ks[ks.length]] = value
	return x
end

function dict.get_and_update(x, ks, default, fn)
	ks.length = #ks
	local tmp = x

	for i=1, ks.length-1 do
		if type(tmp[ks[i]]) == 'table' then
			tmp = tmp[ks[i]]
		else
			return
		end
	end

	local value
	local has = tmp[ks[ks.length]]

	if has ~= nil then
		if fn then
			has = fn(has)
		else
			has = value
		end
	elseif default ~= nil then
		value = default
	else
		value = true
	end

	tmp[ks[ks.length]] = value
	return x
end

function dict.update(x, ks, default, fn)
	ks.length = #ks
	local tmp = x

	for i=1, ks.length-1 do
		if type(tmp[ks[i]]) == 'table' then
			tmp = tmp[ks[i]]
		else
			tmp[ks[i]] = {}
			tmp = tmp[ks[i]]
		end
	end

	local value
	local has = tmp[ks[ks.length]]

	if has ~= nil then
		has = fn(has)
	elseif default ~= nil then
		value = default
	else
		value = true
	end

	tmp[ks[ks.length]] = value

	return x
end

list.update = dict.update
list.set = dict.set
list.get_and_update = dict.get_and_update
list.get_and_set = dict.get_and_set
