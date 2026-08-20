local _ = require 'lua-utils._'
local tuple = require('lua-utils.tuple')

unpack = unpack or table.unpack

---@class BlessedTable
---@field __index table

---@class CallableTable
---@field __call table|function

---@alias Callable CallableTable|function
---@alias Filter fun(...): boolean?
---@alias Condition boolean | fun(...): boolean, string?
---@alias Map fun(...): any
---@alias Fun fun(...): ...
---@alias PcallFun fun(...): boolean, any

---Anything other than nil and false are truthy values.
---No more 0 and 1 shenanigans
---@param x any
---@return boolean
function is_truthy(x)
  if x ~= nil and x ~= false then
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
  if x == false or x == nil then
    return true
  else
    return false
  end
end

---@param value any
---@return (fun(): any)
function literal(value)
  return function() return value end
end

---Call a function with arguments (with pcall optionally)
---Do not return more than 2 arguments, variadic returns other than 2 can cause chaos
---@param f function
---@param args any[]
---@param should_pcall? boolean (default: false)
---@return boolean, any
---@overload fun(f: function, args: any[], should_pcall: true): boolean, any
---@overload fun(f: function, args: any[], should_pcall: false): ...
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
---Remember that outer arguments will not be mutable
---This is not a closure
---@param default any non-nil value
---@param f function
---@param ... any Outer function arguments
---@return function
function partial(default, f, ...)
  local outer_args = tuple.pack(default, ...)
  return function(...)
    local inner = tuple.pack(default, ...)
    local outer = { unpack(outer_args) }
    local len = #outer

    for i = 1, #inner do
      outer[len + 1] = inner[i]
      len = len + 1
    end

    return f(unpack(outer))
  end
end

---Curry functions with arguments at the beginning of the function call
---Remember that outer arguments will not be mutable
---This is not a closure
---@param default any non-nil value
---@param f function
---@param ... any Outer function arguments
---@return function
function rpartial(default, f, ...)
  local outer_args = tuple.pack(default, ...)
  return function(...)
    local inner = tuple.pack(default, ...)
    local outer = { unpack(outer_args) }
    local len = #inner

    for i = 1, #outer do
      inner[len + 1] = outer[i]
      len = len + 1
    end

    return f(unpack(inner))
  end
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
  local mappers = { ... }

  if #mappers == 0 then
    return true, res
  end

  for i = 1, #mappers do
    local f = mappers[i]
    assert(callable(f), string.format("...[%d]: Expected callable, got " .. type(f)))

    local result = { f(res) }
    assert(#result == 2, string.format("...[%d]: Callable must return 2 values"))

    local ok, msg = unpack(result)
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
  local mappers = { ... }

  if #mappers == 0 then
    return true, res
  end

  for i = 1, #mappers do
    local f = mappers[i]
    assert(callable(f), string.format("...[%d]: Expected callable, got " .. type(f)))

    local ok, msg = pcall(f, res)
    if not ok then
      return false, msg
    else
      res = msg
    end
  end

  return true, res
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
---@param lines string[]
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
---@return boolean
function defined(x)
  return x ~= nil
end

---@param x any
---@return boolean
function undefined(x)
  return x == nil
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

---Get the actual size of tables or get string length
---@param x string|table
---@return number
function size(x)
  local x_type = type(x)
  if x_type ~= 'table' and x_type ~= 'string' then
    errorf('x: Expected string|table, got %s', x)
  elseif type(x) == 'string' then
    return #x
  end

  local size = 0
  for _, _ in pairs(x) do
    size = size + 1
  end

  return size
end

---Get the actual size of tables or get string length
---@param x string|table
---@return number
function length(x)
  local x_type = type(x)
  if x_type ~= 'string' and x_type ~= 'table' then
    errorf("Expected string|table, got [%s] %s", type(x), inspect(x))
  end

  if x_type == 'string' or is_pure_list(x) then
    return #x
  elseif x.__length then
    return x:__length()
  end

  local n = 0
  for _, _ in pairs(x) do
    n = n + 1
  end

  return n
end

---For hybrid dict+list tables, this will check the dict size, beware!
---@param x string|table
---@return boolean
function is_empty(x)
  if type(x) == 'string' then
    return #x == 0
  end

  return length(x) == 0
end

---For hybrid dict+list tables, this will check the dict size, beware!
---@param x string|table
---@return boolean
function is_not_empty(x)
  return not is_empty(x)
end

---@param x string|table
---@return boolean
function has_values(x)
  return not is_empty(x)
end

L = literal

require 'lua-utils.metatable'
