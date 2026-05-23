---@class refself_opts
---@field __index? boolean | (fun(self: table, key: string): any) | table
---@field __call? (fun(self: table, ...): any)

---@param tbl? table
---@param opts? refself_opts
---@return table
function refself(tbl, opts)
  opts = opts or {}
  local __index = opts.__index
  local __call = opts.__call

  if type(__index) == 'boolean' then
    tbl.__index = tbl
  else
    tbl.__index = __index
  end

  tbl.__call = __call
  return setmetatable(tbl, tbl)
end

---Metatable management utilities
---@overload fun(x: table, key?: string | number): any
---@overload fun(x: table): table?
local metatable = refself({}, {__index = true})

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

return metatable
