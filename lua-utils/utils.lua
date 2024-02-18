--- Stringify element
--- @overload fun(x:any): string
require "lua-utils.types"

function tuple_size(...)
  return select("#", ...)
end

--- Pack varargs into a list filling all the nils with false
--- @param ... any
--- @return any[]
function pack_tuple(...)
  local args = { ... }

  for i = 1, select("#", ...) do
    if args[i] == nil then
      args[i] = false
    end
  end

  return args
end

do
  local mt = {type = 'ns'}
  tuple = setmetatable({}, mt)
  tuple.unpack = table.unpack or unpack
  tuple.pack = pack_tuple

  function tuple.size(...)
    return select("#", ...)
  end
  tuple.length = tuple.size

  function tuple.cdr(n, ...)
    return select(n, ...)
  end

  function tuple.nth(n, ...)
    local found = tuple.cdr(n, ...)
    return found
  end

  function tuple.first(...)
    return tuple.nth(1, ...)
  end

  function tuple.last(...)
    return select(-1, ...)
  end

  function tuple.slice(i, j, ...)
    local args = tuple.pack(select(i, ...))
    if #args == 0 then
      return {}
    else
      for a = j+1, #args do
        args[a] = nil
      end
    end
    return args
  end
end

--- @param x any
--- @param force? bool forcefully wrap the elem in a table?
--- @return table
function totable(x, force)
  if force then
    return { x }
  elseif type(x) == "table" then
    return x
  else
    return { x }
  end
end

--- @alias dict table
--- @alias list any[]
--- @alias bool boolean
--- @alias num number
--- @alias str string
--- @alias fn function

--- Valid lua metatable keys
--- @enum
mtkeys = {
  __unm = true,
  __eq = true,
  __ne = true,
  __ge = true,
  __gt = true,
  __le = true,
  __lt = true,
  __add = true,
  __sub = true,
  __mul = true,
  __div = true,
  __mod = true,
  __pow = true,
  __tostring = true,
  __tonumber = true,
  __index = true,
  __newindex = true,
  __call = true,
  __metatable = true,
  __mode = true,
}

--- Stringify object
--- @param x any object
--- @return string
function dump(x)
  return inspect(x)
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

--- Get table values
--- @param t table
--- @return any[]
function values(t)
  local out = {}
  local i = 1

  for _, value in pairs(t) do
    out[i] = value
    i = i + 1
  end

  return out
end

--- Get table keys
--- @param t table
--- @param sort? boolean
--- @param cmp? fun(x:any): boolean
--- @return any[]
function keys(t, sort, cmp)
  local out = {}
  local i = 1

  for key, _ in pairs(t) do
    out[i] = key
    i = i + 1
  end

  if sort then
    table.sort(out, cmp)
  end

  return out
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
