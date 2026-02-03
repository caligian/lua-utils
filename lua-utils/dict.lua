local copy = require('lua-utils.copy')
local dict = {}

function dict.copy(x, deep)
  return copy(x, deep)
end

---Get dict keys
---@param x table
---@return table
function dict.keys(x)
  --- Stub method
  return {x}
end

dict.keys = {}
setmetatable(dict.keys, dict.keys)

---Are x's keys a subset of y's keys?
---@param x table
---@param y table
---@return boolean
function dict.keys.subset_of(x, y)
  for key, _ in pairs(x) do
    if not y[key] then
      return false
    end
  end

  return true
end

---Are x's keys a superset of y's keys?
---@param x table
---@param y table
---@return boolean
function dict.keys.superset_of(x, y)
  for key, _ in pairs(y) do
    if not x[key] then
      return false
    end
  end

  return true
end

---Set difference of dict keys
---@param x table
---@param y table
---@return table
function dict.keys.difference(x, y)
  local x_ks = dict.keys(x)
  local res = {}
  local ind = 0

  for x_key in pairs(x_ks) do
    if not y[x_key] then
      res[ind+1] = x_key
      ind = ind + 1
    end
  end

  return res
end

---Set intersection of dict keys
---@param x table
---@param y table
---@return table
function dict.keys.intersection(x, y)
  local cache = {}
  local res = {}
  local ind = 0

  for x_key in pairs(x) do
    if y[x_key] then
      cache[x_key] = true
      res[ind+1] = x_key
      ind = ind + 1
    end
  end

  for y_key in pairs(y) do
    if x[y_key] and not cache[y_key] then
      res[ind+1] = y_key
      ind = ind + 1
    end
  end

  return res
end

---Set union of dict keys
---@param x table
---@param y table
---@return table
function dict.keys.union(x, y)
  local x_ks = dict.keys(x)
  local y_ks = dict.keys(y)
  local cache = {}
  local res = {}
  local ind = 0

  for i=1, #x_ks do
    local k = x_ks[i]
    if not cache[k] then
      res[ind+1] = k
      cache[k] = true
      ind = ind + 1
    end
  end

  for i=1, #y_ks do
    local k = y_ks[i]
    if not cache[k] then
      res[ind+1] = k
      cache[k] = true
      ind = ind + 1
    end
  end

  return res
end

function dict.keys:__call(x)
  local ks = {}
  local i = 0

  for key, _ in pairs(x) do
    i = i + 1
    ks[i] = key
  end

  return ks
end

---Get dict values
---@param x table
---@return table
function dict.values(x)
  local vs = {}
  local i = 0

  for _, value in pairs(x) do
    i = i + 1
    vs[i] = value
  end

  return vs
end

---Get dict size
---@param x table
---@return number
function dict.size(x)
  local n = 0
  for _ in pairs(x) do
    n = n + 1
  end
  return n
end

dict.len = dict.size
dict.length = dict.len

---Is dict empty?
---@param x table
---@return boolean
function dict.empty(x)
  for _ in pairs(x) do return false end
  return true
end

dict.is_empty = dict.empty

---Set value at keys
---@param x table
---@param ks table
---@param value any
---@param force? boolean (default: false)
function dict.set(x, ks, value, force)
  local _x = x
  for i=1, #ks-1 do
    local k = ks[i]
    local v = x[k]
    if type(v) == 'table' then
      x = v
    elseif not force then
      return
    else
      x[k] = {}
      x = x[k]
    end
  end

  x[ks[#ks]] = value
  return _x
end

---Force set value at keys and create tables if necessary
---@param x table
---@param ks table
---@param value any
function dict.force_set(x, ks, value)
  return dict.set(x, ks, value, true)
end

dict.fset = dict.force_set

---Check if keys exist
---@param x table
---@param ks table
---@return boolean
function dict.has(x, ks)
  for i=1, #ks-1 do
    local k = ks[i]
    local v = x[k]
    if type(v) ~= 'table' then
      return false
    else
      x = v
    end
  end

  return x[ks[#ks]] ~= nil
end

---Check if keys exist and return the value. When invalid keys are passed, return arguments are both nil otherwise the value and the level of the found are returned
---Usage:
---> value, tbl_level = dict.get(<table>, {<ks>, ...})
---> value, ok = dict.get(<table>, {<ks>, ...})
---@param x table
---@param ks table
---@param map? fun(x: any): any
---@return any, table?
function dict.get(x, ks, map)
  for i=1, #ks-1 do
    local k = ks[i]
    local v = x[k]
    if type(v) ~= 'table' then
      return nil, nil
    else
      x = v
    end
  end

  local v = x[ks[#ks]]
  if v ~= nil then
    if map then return map(v) end
    return v, x
  else
    return nil, nil
  end
end

function dict.has_path(x, ks)
  return type((dict.get(x, ks))) == 'table'
end

function dict.contains(x, value, cmp)
  cmp = cmp or function(a, b) return a == b end
  for key, x_value in pairs(x) do
    if type(x_value) == 'table' then
      local _key, _x = dict.contains(x_value, value, cmp)
      if _key then return _key, _x end
    elseif cmp(x_value, value) then
      return key, x
    end
  end
end

function dict.map(x, f)
  local res = {}
  for key, value in pairs(x) do
    res[key] = f(key, value)
  end
  return res
end

function dict.filter(x, f, map)
  local res = {}
  for key, value in pairs(x) do
    if f(key, value) then
      res[key] = map and map(value) or value
    end
  end
  return res
end

function dict.compare(x, y, cmp, res)
  cmp = cmp or function (a, b) return a == b end
  res = res or {}

  for key, value in pairs(x) do
    if type(value) == 'table' and type(y[key]) == 'table' then
      res[key] = {}
      dict.compare(value, y[key], cmp, res[key])
    else
      res[key] = cmp(x[key], y[key])
    end
  end

  return res
end

function dict.equal(x, y, cmp)
  cmp = cmp or function(a, b) return a == b end

  for key, value in pairs(x) do
    if type(value) == 'table' and type(y[key]) == 'table' then
      local ok = dict.equal(value, y[key], cmp)
      if not ok then return false end
    elseif not cmp(value, y[key]) then
      return false
    end
  end

  return true
end

function dict.is_dict(x)
  local n = 0
  for _ in pairs(x) do n = n + 1 end
  return n ~= #x
end

function dict.take(x, ks, filter, map)
  local res = {}
  for _, k in ipairs(ks) do res[k] = x[k] end

  if filter then res = dict.filter(x, filter) end
  if map then res = dict.map(x, map) end

  return res
end

dict.select = dict.take

function dict.flatten(x, collapse, res, last_key)
  collapse = collapse or '.'
  res = res or {}
  local function create_key(k)
    if last_key then
      return last_key .. collapse .. k
    else
      return k
    end
  end

  for key, value in pairs(x) do
    if type(value) == 'table' then
      dict.flatten(value, collapse, res, create_key(key))
    else
      res[create_key(key)] = value
    end
  end

  return res
end

local function join_tables(x, y, force, visited)
  visited = visited or setmetatable({}, {__mode = 'k'})
  local cache = function (a, b)
    visited[a] = visited[a] or {}
    visited[a][b] = true
  end
  local exists = function (a, b)
    local ok = visited[a]
    if ok then return ok[b] end
  end

  for key, value in pairs(y) do
    local x_value = x[key]
    local y_value = value
    local x_type = type(x_value)
    local y_type = type(y_value)
    local x_is_table = x_type == 'table'
    local y_is_table = y_type == 'table'

    if x_value == nil then
      x[key] = y_value
    elseif y_is_table then
      if force then
        x[key] = y_value
      elseif x_is_table and not exists(y_value, x_value) then
        cache(y_value, x_value)
        join_tables(x_value, y_value, force, visited)
      end
    elseif force then
      x[key] = y_value
    elseif x_value == nil then
      x[key] = y_value
    end
  end
end

function dict.merge(x, y, force)
  join_tables(x, y, force)
  return x
end

function dict.force_merge(x, y)
  return dict.merge(x, y, true)
end

dict.fmerge = dict.force_merge

function dict.set_unless(x, ks, value, force)
  if not dict.has(x, ks) then
    force = ifnil(force, true)
    return dict.set(x, ks, value, force)
  end
end

function dict.from_keys(ks, default_fn)
  local res = {}
  for i=1, #ks do
    res[ks[i]] = default_fn()
  end
  return res
end

function dict.each(x, callback)
  for key, value in pairs(x) do
    callback(key, value)
  end
end

function dict.items(x)
  local res = {}
  local ind = 1

  for key, value in pairs(x) do
    res[ind] = {key, value}
    ind = ind + 1
  end

  return res
end

function dict.from_zipped(zipped)
  local out = {}
  dict.each(zipped, function(z)
    out[z[1]] = z[2]
  end)
  return out
end

function dict.partition(x, fn)
  local result = { {}, {} }
  for key, value in pairs(x) do
    if fn(value) then
      result[1][key] = value
    else
      result[2][key] = value
    end
  end
  return result
end

function dict.reduce(x, acc, f)
  for key, value in pairs(x) do
    acc = f(key, value, acc)
  end
  return acc
end

function dict.all(t, f)
  for key, value in pairs(t) do
    if f then
      if not f(key, value) then
        return false
      end
    elseif not value then
      return false
    end
  end

  return true
end

function dict.some(t, f)
  for key, value in pairs(t) do
    if f then
      if f(key, value) then
        return true
      end
    elseif value then
      return true
    end
  end

  return false
end

function dict.update(x, ks, default, fn)
  local len = #ks
  local tmp = x

  for i = 1, len - 1 do
    if type(tmp[ks[i]]) == "table" then
      tmp = tmp[ks[i]]
    else
      return
    end
  end

  local value
  local has = tmp[ks[len]]

  if has ~= nil then
    if fn then
      value = fn(has)
    else
      value = has
    end
  elseif default ~= nil then
    value = default
  else
    value = true
  end

  tmp[ks[len]] = value

  return x, tmp
end

function dict.pop1(x, ks)
  local value, level = dict.get(x, ks)
  if value then
    level[ks[#ks]] = nil
  end
  return value
end

function dict.pop(x, ...)
  local res = {}
  local args = {...}
  local ind = 1

  for i=1, #args do
    local ks = args[i]
    local value = dict.pop(x, ks)
    res[ind] = value
    ind = ind + 1
  end

  return res
end

function dict.extract(x)
  local res = {}

  for key, value in pairs(x) do
    if type(key) ~= 'number' then
      res[key] = value
    end
  end

  return res
end

function dict:import()
  _G.dict = self
end

return dict
