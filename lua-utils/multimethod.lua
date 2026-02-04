require 'lua-utils.utils'
local tuple = require 'lua-utils.tuple'
local types = require 'lua-utils.types'
local class = require 'lua-utils.class'

---@class Multimethod
---@field name string
---@field methods table<any[], function>
---@field default fun(...): any
local Multimethod

---@overload fun(name: string, default?: function): Multimethod
Multimethod = class 'Multimethod'

---Is object a multimethod
---@param x any
---@return boolean, string?
function Multimethod.is(x)
  local ok, msg = class.is_object(x)
  if not ok then
    return false, msg
  end

  local parents = class.get_parents(x)
  for i = 1, #parents do
    if parents[i] == 'Multimethod' then
      return true
    end
  end

  return false, 'Expected Multimethod, got ' .. x.__name
end

function Multimethod:match(...)
  local methods = self.methods
  local default = self.default
  local values = tuple.pack(...)
  local n = #values
  local sig_matches = function(sig)
    local m = #sig
    if m > n then
      return false
    end

    for i = 1, m do
      local x = values[i]
      if not types.is(x, sig[i]) then
        return false
      end
    end

    return true
  end

  for sig, fn in pairs(methods) do
    if type(sig) == 'table' and sig_matches(sig) then
      return fn
    end
  end

  if not default then
    error(sprintf('No default method defined in %s', self))
  end

  return default
end

---Add function signature
---@param sig any[]
---@param method? function
---@return function
function Multimethod:on(sig, method)
  if not types.pure_list(sig) then
    sig = {sig}
  end

  method = method or function(_method)
    self.methods[sig] = _method
    return method
  end

  return method
end

function Multimethod:initialize(name, default)
  self.methods = {}
  self.default = default or function (...)
    error('No method matched')
    return ...
  end
  self.name = name

  function self:__call(...)
    local fn = self:match(...)
    return fn(...)
  end
end

function Multimethod:import()
  if types.instance(self) then
    _G.Multimethod = self.__class
  else
    _G.Multimethod = self
  end
end

return Multimethod
