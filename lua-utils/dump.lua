require 'lua-utils.metatable'

inspect = require 'inspect'
local tuple = require 'lua-utils.tuple'

---Inspect tables and/or tostring() 
---@overload fun(x: any): string
dump = bless {
  missing = 'NIL',
  default_missing = 'NIL'
}

---Reset nil placeholder
function dump:reset()
  self.missing = self.default_missing
end

function dump:__call(x)
  local missing = self.missing
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
  return print(dump({...}))
end

---@param ... any
function tee(...)
  local s = dump({...})
  print(s)
  return s
end


---table.concat with dumping values
---@param sep string? (default: ' ')
---@return (fun(args: []string): string)
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
