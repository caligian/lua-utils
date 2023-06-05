--- Common function operations
-- @module fn
local fn = {}

--- Decorate a function
-- @tparam callable f1 to be decorated
-- @tparam callable f2 decorating function
-- @treturn function
function fn.decorate(f1, f2)
  return function(...)
    return f2(f1(...))
  end
end

--- Apply an array of args to a function
-- @tparam callable f
-- @tparam array args to apply
-- @treturn any
function fn.apply(f, args)
  return f(unpack(args))
end

--- Prepend args and apply params
-- @tparam callable f
-- @tparam array ... params to prepend
-- @treturn any
function fn.rpartial(f, ...)
  local outer = { ... }
  return function(...)
    local inner = { ... }
    local len = #outer
    for idx, a in ipairs(outer) do
      inner[len + idx] = a
    end

    return f(unpack(inner))
  end
end

--- Append args and apply params
-- @tparam callable f
-- @tparam array ... params to append
-- @treturn any
function fn.partial(f, ...)
  local outer = { ... }
  return function(...)
    local inner = { ... }
    local len = #outer
    for idx, a in ipairs(inner) do
      outer[len + idx] = a
    end

    return f(unpack(outer))
  end
end

--- Return object
-- @tparam any x
-- @treturn any
function fn.identity(x)
  return x
end

--- Pass an element through N callables
-- @tparam any x
-- @tparam array[callable] ...
-- @treturn any
function fn.thread(x, ...)
  local out = x
  local args = { ... }

  for i = 1, #args do
    local f = args[i]
    out = f(out)
  end

  return out
end

return fn
