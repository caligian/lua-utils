inspect = require 'lua-utils.inspect'
local tuple = require('lua-utils.tuple')
local list = require('lua-utils.list')

function dump(x)
  if type(x) == 'string' then
    return x
  elseif type(x) == 'number' then
    return tostring(x)
  else
    return inspect(x, {indent = ' '})
  end
end

function ifelse(cond, when_true, when_false)
  if cond then
    return when_true
  else
    return when_false
  end
end

function unless(cond, when_false, when_true)
  if not cond then
    return when_false
  else
    return when_true
  end
end

function apply(f, args, should_pcall)
  if should_pcall then
    local ok, msg = pcall(f, unpack(args))
    if ok then
      return msg
    end
  else
    return f(unpack(args))
  end
end

function partial(f, ...)
  local args = tuple.pack(...)
  return function(...)
    list.extend(args, tuple.pack(...))
    return f(unpack(args))
  end
end

function rpartial(f, ...)
  local args = tuple.pack(...)
  return function(...)
    args = list.extend(tuple.pack(...), args)
    return f(unpack(args))
  end
end

function sprintf(fmt, ...)
  local args = tuple.pack(...)

  for i=1, #args do
    local x = args[i]
    local _type = type(x)
    if _type ~= "string" and type(_type) ~= "number" then
      args[i] = dump(args[i])
    end
  end

  return apply(string.format, list.extend({fmt}, args))
end

function printf(fmt, ...)
  local args = tuple.pack(...)
  list.unpush(args, fmt)
  local s = apply(sprintf, args)
  print(s)
end

function ifnonnil(obj, if_nonnil, if_nil)
  if obj ~= nil then
    return if_nonnil
  else
    return if_nil
  end
end

function ifnil(obj, if_nil, if_nonnil)
  if if_nonnil == nil then
    if_nonnil = obj
  end

  if obj == nil then
    return if_nil
  else
    return if_nonnil
  end
end

function thread(obj, ...)
  local res = obj
  local map = tuple.pack(...)

  if #map == 0 then
    return res
  end

  res = {map[1](res)}
  for i=2, #map do
    res = {map[i](unpack(res))}
  end

  return unpack(res)
end

function identity(...)
  return ...
end

function pprint(fmt, ...)
  local args = tuple.pack(...)
  printf(fmt or '%s', unpack(args))
end

function pp(...)
  local args = tuple.pack(...)
  if #args == 0 then
    return
  else
    printf('%s', args)
  end
end

function paste0(...)
  local args = tuple.pack(...)
  for i=1, #args do args[i] = tostring(args[i]) end
  return table.concat(args, '')
end

function paste(collapse, ...)
  collapse = collapse or ' '
  local args = tuple.pack(...)
  local s = {}
  local ind = 0

  for i=1, #args do
    if type(args[i]) == 'table' then
      for j=1, #args[i] do
        s[ind+1] = dump(args[i][j])
        ind = ind + 1
      end
    elseif type(args[i]) == 'string' then
      s[ind+1] = dump(args[i])
      ind = ind + 1
    end
  end

  return table.concat(s, collapse)
end

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

function hasmetatable(x)
  if type(x) ~= 'table' then
    return false
  end

  local mt = getmetatable
  return mt ~= nil
end

function as_list(x, force)
  if force then
    return {x}
  elseif type(x) == 'table' then
    return x
  else
    return {x}
  end
end

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
    res[#res+1] = match
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

  for i=1, l do
    fh:write(lines[i])
    fh:write("\n")
    size = #lines[i] + 1
  end

  fh:close()
  return size + #lines[l]
end
