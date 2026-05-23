---These functions are potentially performance intensive. Use with care
---@overload fun(default: any, ...): []any
local tuple = {}
tuple.__index = tuple
setmetatable(tuple, tuple)

tuple.unpack = table.unpack or unpack

---Pack varargs into a list filling all the nils with false
---@param default any A non-nil value
---@param ... any
---@return any[]
function tuple.pack(default, ...)
  if default == nil then
    error('default: Expected a non-nil value')
  end

  local args = { ... }
  for i = 1, select("#", ...) do
    if args[i] == nil then
      args[i] = default
    end
  end

  return args
end

function tuple:__call(default, ...)
  return tuple.pack(default, ...)
end

---Get size of varargs
---@param ... any
---@return number
function tuple.length(...)
  return select("#", ...)
end

---Similar to lisp's cdr for variadic arguments
---@param default any A non-nil value
---@return []any
function tuple.cdr(default, ...)
  return tuple.pack(default, select(2, ...))
end

---@param default any A non-nil value
---@param n number index
---@param ...
---@return any
function tuple.nth(default, n, ...)
  local args = tuple.pack(default, ...)
  local len = #args
  n = (n < 0) and (len + n) or n

  return args[n]
end

---Get the first value from variadic arguments
---@param default any A non-nil value
---@return any
function tuple.first(default, ...)
  return tuple.nth(default, 1, ...)
end

tuple.car = tuple.first

---Get the last value from variadic arguments
---@param default any A non-nil value
---@return any
function tuple.last(default, ...)
  local args = tuple.pack(default, ...)
  local len = #args

  return args[len]
end

---@param default any A non-nil value
---@param i number
---@param j number
---@param step? number (default: 1)
---@return []any
function tuple.slice(default, i, j, step, ...)
  local args = tuple.pack(default, select(i, ...))
  if #args == 0 then
    return {}
  else
    step = step == nil and 1 or step
    for a = j + 1, #args, step do
      args[a] = nil
    end
  end
  return args
end

---Import tuple module to global table
function tuple:import()
  _G.tuple = tuple
end

return tuple
