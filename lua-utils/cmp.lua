local class = require 'lua-utils.class'
local types = require 'lua-utils.types'

---@class cmp.opts
---@field f? fun(x: any, y: any): boolean for computing equality
---@field eq? fun(x: any, y: any): boolean alias for .f
---@field cmp? fun(x: any, y: any): boolean alias for .f
---@field collapse? boolean Calculate total equality (for tables)
---@field res? table destination table

---@overload fun(x: any, y: any, opts?: cmp.opts): table<string | number, boolean>
local cmp = {}
setmetatable(cmp, cmp)

---Is x equal to y?
---@param x any
---@param y any
---@param f? fun(x: any, y: any): boolean to compute equality
---@return boolean
function cmp.equals(x, y, f)
  f = f or function (a, b) return a == b end
  return f(x, y)
end

---Is x (as a function) equal to y?
---@param x function|table
---@param y function|table
---@return boolean
function cmp.callable(x, y, f)
  local function get_fun(a)
    if type(a) == 'function' then
      return a
    end

    local mt = getmetatable(a)
    if types.table(mt.__call) then
      return get_fun(mt.__call)
    elseif type(mt.__call) == 'function' then
      return mt.__call
    else
      return false
    end
  end

  local _f = f or function (a, b) return a == b end
  function f(a, b)
    a = get_fun(a)
    b = get_fun(b)
    return _f(a, b)
  end

  return f(x, y)
end

---Is x equal to y as a table?
---@param x table
---@param y table
---@param opts? cmp.opts
---@return table<string | number, boolean> | boolean
function cmp.table(x, y, opts)
  opts = opts or {}
  local res = opts.res or {}
  local f = opts.f or opts.cmp or opts.eq or function (a, b)
    return a == b
  end
  local collapse = opts.collapse
  as_table = function (a)
    if types.object(a) then return class.attributes(a) end
    return a
  end
  x = as_table(x)
  y = as_table(y)

  for key, value in pairs(x) do
    local x_value = as_table(value)
    local y_value = as_table(y[key])

    if y_value == nil then
      res[key] = false
    elseif types.callable(x_value) then
      res[key] = cmp.callable(x_value, y_value, f)
    elseif type(x_value) == 'table' then
      if type(y_value) ~= 'table' then
        res[key] = false
      else
        res[key] = {}
        cmp.table(
          x_value,
          y_value,
          {f = f, res = res[key], collapse = collapse}
        )
      end
    else
      res[key] = cmp.equals(x_value, y_value, f)
    end

    if collapse and not res[key] then
      return false
    end
  end

  if collapse then
    return true
  else
    return res
  end
end

---Is x == y?
---@param x any
---@param y any
---@param opts cmp.opts
---@return table<string|number,boolean>|boolean
function cmp.cmp(x, y, opts)
  opts = opts or {}
  local f = opts.f or opts.eq or opts.cmp
  local res = opts.res
  local collapse = opts.collapse

  if types.callable(x) then
    if not types.callable(y) then
      return false
    else
      return cmp.callable(x, y, f)
    end
  elseif types.table(x) then
    if not types.table(y) then
      return false
    else
      return cmp.table(x, y, {f = f, res = res, collapse = collapse})
    end
  else
    return cmp.equals(x, y, f)
  end
end

function cmp:__call(x, y, opts)
  return cmp.cmp(x, y, opts)
end

return cmp
