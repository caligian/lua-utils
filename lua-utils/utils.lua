inspect = require 'lua-utils.inspect'
local tuple = require('lua-utils.tuple')
local list = require('lua-utils.list')
unpack = unpack or table.unpack


---@alias Condition (fun(...): boolean) | boolean | nil
---@alias Mapper (fun(...): any)

---@param cond Condition
local function run_cond(cond, ...)
  local cond_type = type(cond)
  if cond_type == 'boolean' then
    return cond
  elseif cond_type == 'function' then
    return cond(...)
  elseif cond == nil then
    return false
  else
    error('cond: Expected fun(): bool | boolean, got ' .. (cond_type == nil and 'nil' or cond_type))
  end
end

---@param tbl? table
---@return table
function refself(tbl)
  tbl = tbl or {}
  tbl.__index = tbl

  return setmetatable(tbl, tbl)
end

--- Dump object as string
---@param x any
---@return string
function dump(x)
  if x == nil then
    return 'NIL'
  elseif type(x) == 'string' then
    return x
  elseif type(x) == 'number' then
    return tostring(x)
  elseif type(x) == 'table' then
    if x.as_string then
      return x:as_string()
    elseif x.__tostring then
      return x:__tostring()
    else
      return inspect(x, { indent = '  ' })
    end
  else
    return inspect(x, { indent = '  ' })
  end
end

---Is value a callable (function or table with .call metamethod)
---@param x any
---@return boolean, string?
function callable(x)
  if x == nil then
    return false, 'expected function|callable, got nothing'
  elseif not types.fun(x) and not types.table(x) then
    return false, sprintf('expected function | callable, got %s', x)
  elseif types.fun(x) then
    return true
  elseif types.table(x) then
    local mt = getmetatable(x)
    if mt and mt.__call then
      return types.callable(mt.__call)
    else
      return false, sprintf('expected table with __call, got %s', x)
    end
  else
    return false, 'expected function|callable, got ' .. type(x)
  end
end

---@param value any
---@param skip_fn? boolean (default: true)
function literal(value, skip_fn)
  if type(value) == 'function' and skip_fn then
    return value
  else
    return function()
      return value
    end
  end
end

---Inverse of ifelse
---@param cond boolean
---@param ok any
---@param err? any
---@return any
---@overload fun(x: any): boolean
function unless(cond, err, ok)
  cond = (type(cond) == 'boolean' and cond) or function(x)
    return not cond(x)
  end
  return ifelse(cond, err, ok)
end

---Call a function with arguments (with pcall optionally)
---@param f function
---@param args any[]
---@param should_pcall? boolean (default: false)
---@return any, string?
function apply(f, args, should_pcall)
  if should_pcall then
    local ok, msg = pcall(f, unpack(args))
    if ok then
      return msg
    else
      return false, msg
    end
  else
    return f(unpack(args))
  end
end

---Curry functions with arguments at the beginning of the function call
---@param f function
---@param ... any
---@return function
function partial(f, ...)
  local args = tuple.pack(...)
  return function(...)
    local inner = tuple.pack(...)
    args = { unpack(args) }
    list.extend(args, inner)
    return f(unpack(args))
  end
end

---Curry functions with arguments at the end of the function call
---@param f function
---@param ... any
---@return function
function rpartial(f, ...)
  local args = tuple.pack(...)
  return function(...)
    local inner = tuple.pack(...)
    args = { unpack(args) }
    args = list.extend(inner, args)
    return f(unpack(args))
  end
end

---Basically string.format with automatic table dumping
---@param fmt string
---@param ... any
---@return string
function sprintf(fmt, ...)
  local args = tuple.pack(...)

  for i = 1, #args do
    local x = args[i]
    local _type = type(x)

    if _type == 'table' then
      if x.as_string then
        args[i] = x:as_string()
      elseif x.__tostring then
        args[i] = x:__tostring()
      else
        args[i] = dump(x)
      end
    elseif _type == 'string' and _type == 'number' then
      args[i] = tostring(args[i])
    else
      args[i] = dump(args[i])
    end
  end

  return apply(string.format, list.extend({ fmt }, args))
end

---Same as sprintf but print the string
---@param fmt string
---@param ... any
function printf(fmt, ...)
  print(sprintf(fmt, ...))
end

---Poor man's thread operator
---Thread the object and its results into consecutive functions
---Use [l]partial in conjunction with this function to actually make this function useful
---@param obj any
---@param ... function
function thread(obj, ...)
  local res = obj
  local map = tuple.pack(...)

  if #map == 0 then
    return res
  end

  res = { map[1](res) }
  for i = 2, #map do
    res = { map[i](unpack(res)) }
  end

  return unpack(res)
end

---Return arguments as is
---@param ... any
---@return ...
function identity(...)
  return ...
end

---Print a list of dumped values
---@param ... any
function pp(...)
  local args = tuple.pack(...)
  if #args == 0 then
    return
  else
    printf('%s', args)
  end
end

---Similar to R's paste0 with automatic dumping of arguments
---@param ... any
---@return string
function paste0(...)
  local args = tuple.pack(...)
  for i = 1, #args do args[i] = dump(args[i]) end
  return table.concat(args, '')
end

---Similar to R's paste with automatic dumping of arguments
---This function automatically flattens a nested list with depth 1
---@param collapse string Use this to join the dumped arguments
---@param ... any
---@return string
function paste(collapse, ...)
  collapse = collapse or ' '
  local args = tuple.pack(...)
  local s = {}
  local ind = 0

  for i = 1, #args do
    if type(args[i]) == 'table' then
      for j = 1, #args[i] do
        s[ind + 1] = dump(args[i][j])
        ind = ind + 1
      end
    elseif type(args[i]) == 'string' then
      s[ind + 1] = dump(args[i])
      ind = ind + 1
    end
  end

  return table.concat(s, collapse)
end

---Similar to python's callable. Check if object is callable
---@param x any
---@return boolean, string?
function callable(x)
  local type_ = type(x)
  if type_ == 'function' then
    return true
  elseif type_ ~= 'table' then
    return false, sprintf('expected table with __call metatamethod, got ', x)
  end

  local mt = getmetatable(x)
  if not mt then
    return false, sprintf('expected table with metatable, got %s', x)
  elseif mt.__call then
    return callable(mt.__call)
  else
    return false, sprintf('expected table with metamethod __call, got ', mt)
  end
end

---Convert any object into a table by boxing it returning it as-is
---@param x any
---@param force? boolean Box the value anyway even if it's a table
---@return table
function as_list(x, force)
  if force then
    return { x }
  elseif type(x) == 'table' then
    return x
  else
    return { x }
  end
end

totable = as_list

---Read a file
---@param filename string
---@return string?
function slurp(filename)
  local fh = io.open(filename, 'r')
  if not fh then
    return
  end

  local text = fh:read('*all')
  fh:close()

  return text
end

---Write text to a file
---@param filename string
---@return number?
function spit(s, filename)
  local fh = io.open(filename, 'w')
  if not fh then
    return
  end

  fh:write(s)
  fh:write("\n")
  fh:close()

  return #s
end

---Similar to slurp but returns list of strings
---@param filename string
---@return string[]?
function readlines(filename)
  local text = slurp(filename)
  if not text then
    return
  end

  local res = {}
  for match in text:gmatch("[^\n]+") do
    res[#res + 1] = match
  end

  return res
end

---Similar to spit but writes list of strings separated by newline
---@param filename string
---@return number?
function writelines(lines, filename)
  local fh = io.open(filename, 'w')
  if not fh then
    return
  end

  local size = 0
  local l = #lines

  for i = 1, l do
    fh:write(lines[i])
    fh:write("\n")
    size = #lines[i] + 1
  end

  fh:close()
  return size + #lines[l]
end

---Error messages on steroids - error + sprintf
---@param msg string Message format or message
---@param ... any Rest arguments to pass to sprintf
function errorf(msg, ...)
  error(sprintf(msg, ...))
end

---Assertion error messages on steroids - assert + sprintf
---@param cond boolean Condition to test
---@param msg string Message format or message
---@param ... any Rest arguments to pass to sprintf
function assertf(cond, msg, ...)
  if not cond then
    errorf(msg, ...)
  end
end

---Metatable management utilities
---@overload fun(x: table, key?: string | number): any
---@overload fun(x: table): table?
metatable = refself {}

---Check if a metatable field exists
---@param x table
---@return boolean
function metatable.exists(x)
  return getmetatable(x) ~= nil
end

---Get a metatable or metatable field
---@param x table
---@return table?
function metatable.get(x)
  return getmetatable(x)
end

---Get a metatable or metatable field
---@param x table
---@param key string
---@return table?
function metatable.get_key(x, key)
  local mt = getmetatable(x)
  if mt then
    return mt[key]
  end
end

---@param x table
---@param ks []string
---@return table<string,any>?
function metatable.get_keys(x, ks)
  local mt = getmetatable(x)
  if mt == nil then
    return nil
  end

  local res = {}
  for k, v in pairs(mt) do
    res[k] = v
  end

  return res
end

---Set a metatable or metatable field
---@param x table
---@param mt table
---@return table
function metatable.set(x, mt)
  return setmetatable(x, mt)
end

---Set a metatable or metatable field
---@param x table
---@param key string
---@param value any
---@return table
function metatable.set_key(x, key, value)
  local mt = metatable.get(x) or {}
  mt[key] = value

  return setmetatable(x, mt)
end

---@param x table
---@param keys_and_values table<string,any>
---@return table
function metatable.set_keys(x, keys_and_values)
  local mt = getmetatable(x) or {}
  for key, value in pairs(keys_and_values) do
    mt[key] = value
  end

  return setmetatable(x, mt)
end

---@param x any
---@param ok? (fun(x): any)
---@param ... any Arguments to pass when x is defined and cond is a function
---@return any
---@overload fun(x: any): boolean
function undefined(x, ok, ...)
  if x == nil then
    if ok ~= nil then
      return run_cond(ok, ...)
    else
      return true
    end
  else
    return false
  end
end

---@param x any
---@param ok? (fun(x): any)
---@param ... any Arguments to pass when x is defined and cond is a function
---@return any
---@overload fun(x: any): boolean
function defined(x, ok, ...)
  if x ~= nil then
    if ok ~= nil then
      return run_cond(ok, ...)
    else
      return true
    end
  else
    return false
  end
end

---@class ifelse_opts
---@field ok? []any
---@field err? []any
---@field cond? []any

---@param cond? Condition
---@param true_fn? (fun(x): any)
---@param false_fn? (fun(x): any)
---@param opts? ifelse_opts
---@return any
---@overload fun(x: any): boolean
function ifelse(cond, true_fn, false_fn, opts)
  opts = opts or {}
  local ok_args = opts.ok or {}
  local err_args = opts.err or {}
  local cond_args = opts.cond or {}
  local cond_type = type(cond)
  local cond_fn = cond_type == 'function'
  local cond_bool = cond_type == 'boolean'
  local ok = false

  if cond_fn then
    ok = cond_fn(unpack(cond_args))
  elseif cond_bool then
    ok = cond_bool
  elseif cond == nil then
    ok = false
  end

  if not ok then
    if false_fn then
      return false_fn(unpack(err_args))
    else
      return false
    end
  elseif true_fn then
    return true_fn(unpack(ok_args))
  else
    return true
  end
end

---@param value any
---@return (fun(): any)
function literal(value)
  return function() return value end
end

---@param x boolean
function invert(x)
  return not x
end

---For equality checks - to eliminate the nonsense of operators
equals = refself {}

---@param x any
---@param y any
---@return boolean
function equals.equals(x, y)
  return x == y
end

---@param x any
---@param y any
---@return boolean
function equals.invert(x, y)
  return invert(equals(x, y))
end

function equals:__call(x, y, invert)
  if invert then
    return equals.equals(x, y)
  else
    return equals.invert(x, y)
  end
end

---@overload fun(cond: boolean | (fun(): boolean), fmt: string, ...: string)
claim = refself {}

---@param x any
---@param ... string
---@return boolean?
function claim.type(x, ...)
  local x_type = type(x)
  x_type = x_type == nil and 'nil' or x_type
  local expected_args = { ... }

  for _, expected in ipairs(expected_args) do
    if x_type ~= expected then
      local exp_type = expected == nil and 'nil' or expected
      error(string.format('x: Expected %s, got %s', exp_type, x_type))
    else
      return true
    end
  end

  return false
end

---@param cond (fun(): boolean) | boolean
---@param fmt string
---@param ... string
function claim.when(cond, fmt, ...)
  local cond_type = type(cond)
  local fmt_type = type(fmt)
  local cond_is_boolean = cond_type == 'boolean'
  local cond_is_fun = cond_type == 'function'

  if (not cond_is_boolean) and (not cond_is_fun) then
    error(
      'cond: Expected boolean | (fun(): boolean), got ' ..
      (cond_type == nil and 'nil' or cond_type)
    )
  end

  if invert(fmt_type == 'string') then
    error(
      'fmt: Expected string, got ' ..
      (fmt_type == nil and 'nil' or fmt_type)
    )
  end
end
