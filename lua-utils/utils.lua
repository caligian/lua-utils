local _ = require 'lua-utils._'
local metatable = require 'lua-utils.metatable'
local tuple = require('lua-utils.tuple')

unpack = unpack or table.unpack
inspect = require 'lua-utils.inspect'

---@alias Filter fun(...): boolean?
---@alias Mapper fun(...): any
---@alias Condition boolean | Filter | nil
---@alias OkCallback fun(): any
---@alias ErrCallback fun(): any

---Anything other than nil and false are truthy values.
---No more 0 and 1 shenanigans
---@param x any
---@return boolean
function is_truthy(x)
  if x ~= nil then
    return true
  elseif x ~= false then
    return true
  else
    return false
  end
end

---nil and false are falsy values
---No more 0 and 1 shenanigans
---@param x any
---@return boolean
function is_falsy(x)
  if x == nil then
    return true
  elseif x == false then
    return true
  else
    return false
  end
end

---@param x any
---@param f fun(...): any
---@param ... any
---@return boolean, any
function when_truthy(x, f, ...)
  if x ~= nil then
    return true, f(...)
  elseif x ~= false then
    return true, f(...)
  else
    return false, nil
  end
end

---@param x any
---@param f fun(...): any
---@param ... any
---@return boolean, any
function when_falsy(x, f, ...)
  if x == nil then
    return true, f(...)
  elseif x == false then
    return true, f(...)
  else
    return false, nil
  end
end

---Similar to python's callable()
---@param x any
---@param err_msg? boolean
---@return boolean, string?
---@overload fun(x: any): boolean, nil
---@overload fun(x: any, err_msg: boolean): boolean, string
function callable(x, err_msg)
  local type_ = type(x)
  if type_ == 'function' then
    return true, nil
  elseif type_ ~= 'table' then
    if err_msg then
      return false, 'x: Expected with table with __call metamethod'
    else
      return false, nil
    end
  end

  local mt = getmetatable(x)
  if not mt then
    if err_msg then
      return false, 'x: Expected table with metamethod'
    else
      return false, nil
    end
  elseif mt.__call then
    return callable(mt.__call)
  else
    return false, "x: No __call metamethod defined"
  end
end

--- Dump object as string
---@param x any
---@return string
function dump(x)
  if x == nil then
    return 'nil'
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

---@param value any
---@return (fun(): any)
function literal(value)
  return function() return value end
end

---Inverse functional version of if-else
---@param cond boolean
---@param ok any
---@param err? any
---@return any
function unless(cond, ok, err)
  local use
  if callable(cond) then
    use = cond()
  else
    use = cond
  end

  return when(not use, ok, err)
end

---Functional version of if-else
---@param cond Condition
---@param ok? OkCallback
---@param err? ErrCallback
---@return any
---@overload fun(cond: Condition): boolean
function when(cond, ok, err)
  local use
  if callable(cond) then
    use = cond()
  else
    use = cond
  end

  if use then
    if ok then
      return ok()
    else
      return true
    end
  elseif err then
    return err()
  else
    return false
  end
end

---Call a function with arguments (with pcall optionally)
---Do not return more than 2 arguments, variadic returns other than 2 can cause chaos
---@param f function
---@param args any[]
---@param should_pcall? boolean (default: false)
---@return boolean, string?
---@overload fun(f: function, args: []any, should_pcall: true): boolean, any
---@overload fun(f: function, args: []any, should_pcall: false): any
function apply(f, args, should_pcall)
  if should_pcall then
    local ok, msg = pcall(f, unpack(args))
    if ok then
      return true, msg
    else
      return false, msg
    end
  else
    return f(unpack(args))
  end
end

---Curry functions with arguments at the beginning of the function call
---@param default any non-nil value
---@param f function
---@param ... any Outer function arguments
---@return function
function partial(default, f, ...)
  local outer = tuple.pack(default, ...)
  return function(...)
    local inner = tuple.pack(default, ...)
    local len = #outer

    for i=1, #inner do
      outer[len+1] = inner[i]
      len = len + 1
    end

    return f(unpack(outer))
  end
end

---Curry functions with arguments at the beginning of the function call
---@param default any non-nil value
---@param f function
---@param ... any Outer function arguments
---@return function
function rpartial(default, f, ...)
  local outer = tuple.pack(default, ...)
  return function(...)
    local inner = tuple.pack(default, ...)
    local len = #inner

    for i=1, #outer do
      inner[len+1] = outer[i]
      len = len + 1
    end

    return f(unpack(inner))
  end
end

---Basically string.format with automatic table dumping
---@param fmt string
---@param ... any
---@return string
function sprintf(fmt, ...)
  local args = tuple.pack('`nil`', ...)

  for i = 1, #args do
    local x = args[i]
    local _type = type(x)

    if _type == 'table' then
      local mt = getmetatable(x)
      if mt and mt.__tostring then
        args[i] = mt.__tostring(x)
      else
        args[i] = dump(x)
      end
    elseif _type == 'string' and _type == 'number' then
      args[i] = tostring(args[i])
    else
      args[i] = inspect(args[i])
    end
  end

  return string.format(fmt, unpack(args))
end

---Same as sprintf but print the string
---@param fmt string
---@param ... any
function printf(fmt, ...)
  print(sprintf(fmt, ...))
end

---Return argument as is
---@param x any
---@return any
function identity(x)
  return x
end

---@overload fun(obj: any, ...: (fun(x: any): boolean, any)): boolean, any
thread = {}
thread.__index = thread
setmetatable(thread, thread)

function thread:__call(obj, ...)
  local res = obj
  local mappers = {...}

  if #mappers == 0 then
    return true, res
  end

  for i=1, #mappers do
    local result = {mappers[i](res)}
    local result_len = #result
    local ok, msg

    if result_len > 2 then
      errorf("%s: Expected <= 2 return values, got %d", tostring(mappers[i]), result_len)
    elseif #result == 1 then
      ok = is_truthy(result[1])
      msg = ((not ok) and sprintf('%s: Function returned a falsy value', tostring(result[1]))) or result[1]
    else
      ok, msg = unpack(result)
    end

    if not ok then
      return false, msg
    else
      res = msg
    end
  end

  return true, res
end

---Use pcall instead of returning (false, string?) | (true, {value})
---@param obj any
---@param ... fun(obj: any): any
---@return boolean, any
function thread.pcall(obj, ...)
  local res = obj
  local mappers = {...}

  if #mappers == 0 then
    return true, res
  end

  for i=1, #mappers do
    local ok, msg = pcall(mappers[i], res)
    if not ok then
      return false, msg
    else
      res = msg
    end
  end

  return true, res
end

---Print a list of dumped values
---Do not mistake this with sprintf
---@param default non-nil value
---@param ... any
function pp(default, ...)
  local args = tuple.pack(default, ...)
  if #args == 0 then
    return
  else
    printf('%s', args)
  end
end

---Similar to R's paste0
---@param ... string 
---@return string
function paste0(...)
  return table.concat({...}, '')
end

---Similar to R's paste0
---@param sep? string (default: ' ')
---@param ... string 
---@return string
function paste(sep, ...)
  return table.concat({...}, sep or ' ')
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

---Read a file
---@param filename string
---@param chomp? boolean (default: true)
---@return string?
function slurp(filename, chomp)
  chomp = (chomp == nil and true) or chomp
  local fh = io.open(filename, 'r')

  if not fh then
    return
  end

  local text = fh:read('*all')
  fh:close()

  return (chomp and string.gsub(text, "\n$", "")) or text
end

---Write text to a file
---@param s string
---@param filename string
---@param newline? boolean (default: true)
---@return number?
function spit(s, filename, newline)
  newline = (newline == nil and true) or false
  local fh = io.open(filename, 'w')

  if not fh then
    return
  end

  s = newline and (s .. "\n") or s
  local len = #s

  fh:write(s)
  fh:close()

  return len
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
---@param lines []string
---@param filename string
---@param newline? boolean (default: true) Add newline at the end of every line? 
---@return number?
function writelines(lines, filename, newline)
  newline = (newline == nil and true) or newline
  local fh = io.open(filename, 'w')

  if not fh then
    return
  end

  local size = 0
  local len = #lines

  for i = 1, len do
    fh:write(lines[i])
    size = #lines[i]

    if newline then
      fh:write("\n")
      size = size + 1
    end
  end

  fh:close()
  return size
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
---@return boolean?
function assertf(cond, msg, ...)
  if not cond then
    errorf(msg, ...)
  else
    return true
  end
end

---@param x any
---@param ok? (fun(...): any)
---@return any
---@overload fun(x: any): boolean
---@overload fun(x: any, ok: (fun(...): any), ...): any
function undefined(x, ok, ...)
  if x == nil then
    if ok ~= nil then
      if callable(ok) then
        return ok(...)
      else
        return true
      end
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
---@overload fun(x: any, ok: (fun(...): any), ...): any
function defined(x, ok, ...)
  if x ~= nil then
    if ok ~= nil then
      return _.cond(ok, ...)
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
---@field ok_args? []any
---@field err_args? []any

---@param cond? Condition
---@param true_fn? (fun(x): any)
---@param false_fn? (fun(x): any)
---@param opts? ifelse_opts
---@return any
---@overload fun(x: any): boolean
function when(cond, true_fn, false_fn, opts)
  opts = opts or {}
  local ok_args = opts.ok or opts.ok_args or {}
  local err_args = opts.err or opts.err_args or {}
  local ok = _.cond(cond)

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

---@param x any
---@param expected_types []string
---@return boolean?
function assert_type(x, expected_types)
  local x_type = _.type(type(x))
  x_type = x_type == nil and 'nil' or x_type

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

---@param cond Condition
---@param fmt string
---@param ... string
function assert_when(cond, fmt, ...)
  local ok = ((callable(cond)) and cond()) or cond
  if not ok then
    errorf(fmt, ...)
  else
    return true
  end
end

function assert_unless(cond, fmt, ...)
  local use = ((callable(cond)) and not cond()) or cond
  return assert_when(cond, fmt, ...)
end

L = literal
when_nil = undefined
unless_nil = defined
unless_truthy = when_falsy
unless_falsy = when_truthy
