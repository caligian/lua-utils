local inspect = require 'inspect'
local tuple = require 'lua-utils.tuple'

---Similar to python's callable. Check if object is callable
---@param x any
---@return boolean, string?
function callable(x)
  local type_ = type(x)
  if type_ == 'function' then
    return true
  elseif type_ ~= 'table' then
    return false, string.format('expected table with __call metatamethod, got `%s`', inspect(x))
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

---@class bless_opts
---@field __index? boolean | table | (fun(self: table, key: string): any)  (default: true)
---@field __call? (fun(self: table, ...): any)

---@param tbl? table
---@param opts? bless_opts
---@return table
function bless(tbl, opts)
  opts = opts or {}
  local metatable = opts.metatable
  local __index = opts.__index
  local __call = opts.__call
  local __index_type = type(__index)
  local mt = opts.metatable or tbl

  if __index == nil then
    __index = true
  end

  if __index_type == 'boolean' and __index then
    mt.__index = tbl
  elseif callable(__index) or __index_type == 'table' then
    mt.__index = __index
  end

  mt.__call = __call
  return setmetatable(tbl, mt)
end

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

---Metatable management utilities
---@overload fun(x: table, key?: string | number): any
---@overload fun(x: table): table?
metatable = bless {}

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

return true
