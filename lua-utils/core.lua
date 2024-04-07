inspect = require 'inspect'
dump = inspect.inspect

function size(x)
	local n = 0
	for _, _ in pairs(x) do
		n = n + 1
	end
	return n
end

function mtget(t, k)
	if not k then return getmetatable(t) end

	local mt = getmetatable(t)
	if not mt then return end

	return mt[k]
end

function mtset(t, k, v)
	if type(k) == 'table' then 
		return setmetatable(t, k)
	end

	local mt = getmetatable(t) or {}
	mt[k] = v

	return setmetatable(t, mt)
end

function errorf(err, fmt, ...)
	local args = {...}
	for i=1, #args do
		if type(args[i]) ~= 'string' then
			args[i] = dump(args[i])
		end
	end
	error(dump {
		error = err,
		message = string.format(fmt, unpack(args))
	})
end

function typeof(x) 
	local tp = type(x)
	if tp == 'table' then
		return x._meta and x._meta.type or 'table'
	end
	return tp
end

function tolist(x, force)
	if force then
		return {x}
	elseif type(x) == 'table' then
		if x._meta then
			return {x}
		end
		return x
	else
		return {x}
	end
end

function is_nil(x)
  return x == nil
end

function length(x)
  return #x
end

function keys(x)
  local ks = {}
  for key, _ in pairs(x) do
    ks[#ks+1] = key
  end
  return ks
end

function values(x)
  local vs = {}
  local ks = {}
  for _, value in pairs(x) do
    vs[#ks+1] = value
  end
  return vs
end

function at(x, ...)
  local ks = {...}
  local tmp = x

  for i = 1, #ks-1 do
    local key = ks[i]
    local v = x[key]
    if type(v) ~= 'table' then
      return nil
    else
      tmp = v
    end
  end

  local v = tmp[ks[#ks]]
  if v ~= nil then
    return v, tmp
  else
    return nil
  end
end

function is_method(x)
  return type(x) == 'function' or type(x) == 'table' and x._meta and x._meta.type == 'method'
end

--- Alias for table.concat
--- @param x list
--- @param sep? string
--- @return string
function concat(x, sep)
  return table.concat(x, sep)
end

--- Alias for table.concat
--- @param x list a list
--- @param sep? string separator string
function join(x, sep)
  return table.concat(x, sep)
end

--- Stringify and print object
--- @param ... any object
function pp(...)
  local args = { ... }
  for i = 1, #args do
    print(inspect(args[i]))
  end
end

--- sprintf with stringification
--- @param fmt string string.format compatible format
--- @param ... any placeholder variables
--- @return string
function sprintf(fmt, ...)
  local args = { ... }
  for i = 1, #args do
    args[i] = type(args[i]) ~= "string" and inspect(args[i])
      or args[i]
  end

  return string.format(fmt, unpack(args))
end

--- printf with stringification
--- @param fmt string string.format compatible format
--- @param ... any placeholder variables
function printf(fmt, ...)
  print(sprintf(fmt, ...))
end
--- if X == nil then return Y else Z
--- @param a any
--- @param ret any returned when a is nil
--- @param orelse any returned when a is not nil
--- @return any
function if_nil(a, ret, orelse)
  if a == nil then
    return ret
  else
    return orelse
  end
end

--- if X ~= nil then return Y else Z
--- @param a any
--- @param ret any returned when a is not nil
--- @param orelse any returned when a is nil
--- @return any
function unless_nil(a, ret, orelse)
  if a == nil then
    return ret
  else
    return orelse
  end
end

--- @param test boolean
--- @param message str
--- @param orelse? any
--- @return any value return if test fails
function assert_unless(test, message, orelse)
  if test then
    error(message)
  end

  return orelse
end

--- Return length of string|lists
--- @param x string|table
--- @return integer?
function length(x)
  if not is_string(x) and not is_table(x) then
    return
  end

  return #x
end

--- Similar to mtset
--- @param x table
--- @param key any if table then treat `key` as kv pairs else set `value` for `key`
--- @param value? any
--- @return any
function overload(x, key, value)
  if is_table(key) then
    for k, v in pairs(key) do
      mtset(x, k, v)
    end
  else
    mtset(x, key, value)
  end

  return x
end

--- Get object attribute via a function
--- > map({{a=1}, {a=10}}, getter('a', false))
--- @param key any
--- @param default? any value to return in case of absence
--- @return fun(x:table): any
function getter(key, default)
  return function(x)
    if x[key] == nil then
      return default
    end
    return x[key]
  end
end

--- Set object attribute in a mapping function
--- > each({{}, {}}, setter('a', false))
--- @param key any
--- @param value any value to set
--- @return fun(x:table): any
function setter(key, value)
  return function(x)
    x[key] = value
    return x
  end
end

--- X == nil?
--- @param x any
--- @param orelse? any
--- @return any result if X is nonnil otherwise return `orelse`
function defined(x, orelse)
  if x ~= nil then
    return x
  else
    return orelse
  end
end

loadfile 'tuple.lua'()
loadfile 'copy.lua' ()
loadfile 'function.lua'()
loadfile 'string.lua'()
