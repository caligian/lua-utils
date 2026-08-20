inspect = require 'inspect'
local tuple = require 'lua-utils.tuple'

---Inspect tables and/or tostring() 
---@overload fun(x: any): string
dump = {
  missing = 'NIL',
  default_missing = 'NIL',
  __type = 'callable',
  __name = 'dump',
}

dump.__index = dump
setmetatable(dump, dump)

---Reset nil placeholder
function dump.reset()
  dump.missing = dump.default_missing
end

function dump:__call(x)
  local missing = dump.missing
  local x_type = type(x)

  if x == nil then
    return missing
  elseif x_type == 'string' then
    return x
  elseif x_type == 'number' then
    return tostring(x)
  elseif x_type == 'table' then
    local mt = getmetatable(x)
    if mt then
      if mt.__tostring then
        return tostring(x)
      else
        return inspect(x, {indent = '  '})
      end
    else
      return inspect(x, {indent = '  '})
    end
  else
    return tostring(x)
  end
end

---@param fmt string
---@param x any
---@return string
function dump.format(fmt, x, ...)
  return string.format(fmt, dump(x), ...)
end

---@param fmt string
---@param x any
---@return string
function dump.raise(fmt, x, ...)
  error(dump.format(fmt, x, ...))
end

---@param cond boolean
---@param fmt string
---@param x any
---@param ... any
---@return `true`?
function dump.raise_unless(cond, fmt, x, ...)
  if cond then
    return true
  end

  dump.raise(fmt, x, ...)
end

---@param fmt string
---@param ... any 
---@return string
function sprintf(fmt, ...)
  local missing = dump.missing
  local args = tuple.pack(missing, ...)
  local res = {}

  for i=1, #args do
    res[i] = dump(args[i])
  end

  return string.format(fmt, unpack(res))
end

---@param fmt string
---@param ... any
---@return string
function printf(fmt, ...)
  local s = sprintf(fmt, ...)
  print(s)
  return s
end

---@param ... any
function pp(...)
  print(dump({...}))
end

---@param x any
---@return string
function tee(x)
  local s = dump(x)
  print(s)
  return s
end

---table.concat with dumping values
---@param sep string? (default: ' ')
---@return (fun(args: string[]): string)
function paste(sep)
  sep = sep or ' '
  return function (args)
    local res = {}
    for i=1, #args do res[i] = dump(args[i]) end
    local s = table.concat(res, sep)
    return s
  end
end

function paste0(args)
  return paste('')(args)
end

return true
