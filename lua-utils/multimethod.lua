require 'lua-utils.utils'
local copy = require 'lua-utils.copy'
local list = require 'lua-utils.list'
local tuple = require 'lua-utils.tuple'
local types = require 'lua-utils.types'

local multimethod = {}
setmetatable(multimethod, multimethod)

function multimethod.is_multimethod(x)
  local ok, msg = types.table(x)
  if not ok then
    return false, msg
  end

  ok, msg = types.hasmetatable(x)
  if not ok then
    return false, msg
  end

  local mt = getmetatable(x)
  if mt ~= x then
    return false, sprintf('expected multimethod, got %s', x)
  elseif not (x.name and x.methods and x.__call) then
    return false, sprintf('expected multimethod, got %s', x)
  else
    return types.callable(x.__call)
  end
end

function multimethod.match(mm, ...)
  local values = tuple.pack(...)
  local n = #values
  local sig_matches = function(sig)
    local m = #sig
    if m > n then
      return false
    end

    for i=1, m do
      local x = values[i]
      if not types.is(x, sig[i]) then
        return false
      end
    end

    return true
  end

  for sig, fn in pairs(mm.methods) do
    if type(sig) == 'table' and sig_matches(sig) then
      return fn
    end
  end

  if not mm.default then
    error(sprintf('No default method defined in %s', mm))
  end

  return mm.default
end

function multimethod.define(name)
  local fun = {name = name, methods = {}}
  setmetatable(fun, fun)

  function fun:__call(...)
    return multimethod.match(self, ...)(...)
  end

  function fun.define(sig, method)
    fun[sig] = method
  end

  function fun.odefine(sig, method)
    sig = copy.copy(sig)
    sig = list.unpush(sig, 'table')
    fun[sig] = method
  end

  fun.def = fun.define
  fun.odef = fun.odefine
  fun.__index = fun.methods

  return fun
end

function multimethod:__call(name)
  return multimethod.define(name)
end

return multimethod
