local _ = require 'lua-utils._'

---These functions are potentially performance intensive. Use with care
---@overload fun(missing: any, ...): []any
local tuple = {}

tuple.__index = tuple
setmetatable(tuple, tuple)

tuple.unpack = table.unpack or unpack

---Pack varargs into a list filling all the nils with false
---@param missing any A non-nil value
---@param ... any
---@return any[]
function tuple.pack(missing, ...)
  if missing == nil then
    error('missing: Expected a non-nil value')
  end

  local args = { ... }
  for i = 1, select("#", ...) do
    if args[i] == nil then
      args[i] = missing
    end
  end

  return args
end

function tuple:__call(missing, ...)
  return tuple.pack(missing, ...)
end

---Get size of varargs
---@param ... any
---@return number
function tuple.length(...)
  return select("#", ...)
end

---Similar to lisp's cdr for variadic arguments
---@param missing any A non-nil value
---@return []any
function tuple.cdr(missing, ...)
  return tuple.pack(missing, select(2, ...))
end

---@param missing any A non-nil value
---@param n number index
---@param ...
---@return any
function tuple.nth(missing, n, ...)
  local args = tuple.pack(missing, ...)
  local len = #args
  n = (n < 0) and (len + n) or n

  return args[n]
end

---Get the first value from variadic arguments
---@param missing any A non-nil value
---@return any
function tuple.first(missing, ...)
  return tuple.nth(missing, 1, ...)
end

tuple.car = tuple.first

---Get the last value from variadic arguments
---@param missing any A non-nil value
---@return any
function tuple.last(missing, ...)
  local args = tuple.pack(missing, ...)
  local len = #args

  return args[len]
end

---@class tuple_slice_opts
---@field missing any A non-nil value
---@field i? number (default: 1)
---@field j? number (default: length of the table)
---@field step? number (missing: 1)
---@field unpack? boolean (default: false)

---@param opts tuple_slice_opts
---@param ... any
---@return []any
function tuple.slice(opts, ...)
  opts = opts or {}
  local missing = (opts.missing == nil and false) or opts.missing
  local i = opts.i
  local j = opts.j
  local step = opts.step
  local args = tuple.pack(missing, ...)
  local args_len = #args
  local start_index, end_index
  local res = {}
  local res_len = 1
  step = step or 1
  local should_unpack = opts.unpack

  __, start_index = _.fix_index(args_len, i or 1, true, false)
  __, end_index = _.fix_index(args_len, j or args_len, true, false)
  start_index = start_index[1]
  end_index = end_index[1]

  for index = start_index, end_index, step do
    res[res_len] = args[index]
    res_len = res_len + 1
  end

  if should_unpack then
    return unpack(res)
  else
    return res
  end
end

---Import tuple module to global table
function tuple:import()
  _G.tuple = tuple
end

return tuple
