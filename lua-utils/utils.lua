inspect = require 'lua-utils.inspect'
local tuple = require('lua-utils.tuple')
local list = require('lua-utils.list')

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
  else
    return inspect(x, { indent = ' ' })
  end
end

local function call_if_function(f, ...)
  if f == nil then
    return ...
  elseif type(f) == 'function' then
    return f(...)
  else
    return f
  end
end

---Functional version of if-else
---If when_true/when_false are functions, call them instead
---@param cond boolean
---@param when_true any
---@param when_false? any
---@return any
function ifelse(cond, when_true, when_false)
  if cond then
    return call_if_function(when_true)
  else
    return call_if_function(when_false)
  end
end

---Inverse of ifelse
---@param cond boolean
---@param when_true any
---@param when_false? any
---@return any
function unless(cond, when_false, when_true)
  if not cond then
    return call_if_function(when_false)
  else
    return call_if_function(when_true)
  end
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
    list.extend(args, tuple.pack(...))
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
    args = list.extend(tuple.pack(...), args)
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
    if _type ~= "string" and type(_type) ~= "number" then
      args[i] = dump(args[i])
    end
  end

  return apply(string.format, list.extend({ fmt }, args))
end

---Same as sprintf but print the string
---@param fmt string
---@param ... any
---@return string
function printf(fmt, ...)
  local args = tuple.pack(...)
  list.unpush(args, fmt)
  local s = apply(sprintf, args)
  print(s)

  return s
end

---If object ~= nil, then
---@param obj? any
---@param if_nonnil any
---@param if_nil any
---@return any
function ifnonnil(obj, if_nonnil, if_nil)
  if obj ~= nil then
    return call_if_function(if_nonnil)
  else
    return call_if_function(if_nil)
  end
end

---If object == nil, then
---@param obj? any
---@param if_nil any
---@param if_nonnil any
---@return any
function ifnil(obj, if_nil, if_nonnil)
  if if_nonnil == nil then
    if_nonnil = obj
  end

  if obj == nil then
    return call_if_function(if_nil)
  else
    return call_if_function(if_nonnil)
  end
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

---Pretty printing
---@param fmt string
---@param ... any
---@return string
function pprint(fmt, ...)
  local args = tuple.pack(...)
  return printf(fmt or '%s', unpack(args))
end

---Print a list of dumped values
---@param ... any
---@return string?
function pp(...)
  local args = tuple.pack(...)
  if #args == 0 then
    return
  else
    return printf('%s', args)
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

---Check if table has a metatable
---@param x any
---@return boolean, string?
function hasmetatable(x)
  local x_type = type(x)
  if x_type ~= 'table' then
    return false, 'Expected table, got ' .. x_type
  end

  local mt = getmetatable
  return mt ~= nil
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

function case(cond, obj, when_true, when_false)
  if cond(obj) then
    return call_if_function(when_true, obj)
  else
    return call_if_function(when_false, obj)
  end
end

---@class switch.form
---@field [1]? fun(x: any): boolean For checking condition
---@field [2]? fun(x: any): any For returning value
---@field when? (fun(x: any): boolean) Alias for [1]
---@field apply? (fun(x: any): any) Alias for [2]

---@param obj any
---@param default_callback fun(x: any): any
---@param ... switch.form
---@return any
function switch(obj, default_callback, ...)
  local specs = { ... }
  local validate_spec = function(i, spec)
    local when = spec.when or spec[1]
    local _apply = spec.apply or spec[2]

    if type(when) ~= 'function' then
      errorf('switch[%d].when: Expected function, got %s', i, type(when))
    end

    if type(_apply) ~= 'function' then
      errorf('switch[%d].apply: Expected function, got %s', i, type(_apply))
    end

    return when, _apply
  end

  for i = 1, #specs do
    local when, _apply = validate_spec(i, specs[i])
    if when(obj) then return _apply(obj) end
  end

  return default_callback(obj)
end

