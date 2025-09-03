---@overload fun(x: table, deep?: boolean): table
local copy = {}
setmetatable(copy, copy)

---Shallow copy table
---@param x table src table
---@param res? table dest table
---@return table
function copy.copy(x, res)
  res = res or {}
  local mt = getmetatable(x)

  for key, value in pairs(x) do
    res[key] = value
  end

  if mt then
    setmetatable(res, mt)
  end

  return res
end

---Deep copy table
---@param x table src table
---@param res? table dest table
---@return table
function copy.deep(x, res)
  local mt = getmetatable(x)
  res = res or {}
  local cache = {}
  cache[x] = true

  for key, value in pairs(x) do
    if type(value) == 'table' then
      if cache[value] then
        res[key] = value
      else
        res[key] = {}
        cache[value] = true
        copy.deep(value, res[key])
      end
    else
      res[key] = value
    end
  end

  if mt then
    setmetatable(res, mt)
  end

  return res
end

function copy:__call(x, deep)
  if deep then
    return copy.deep(x)
  else
    return copy.copy(x)
  end
end

return copy
