local tuple = require 'lua-utils.tuple'

---@class multimethod : type_table
---@field __call function
---@field dispatch table<any,function>
---@field default function
---@field name string

---Multimethod creation utilties
---@overload fun(name: string, default: fun(...): any): multimethod
multimethod = module 'multimethod'

function multimethod:match(...)
  local methods = self.dispatch
  local default = self.default
  local values = tuple.pack(NIL, ...)
  local n = #values
  local sig_matches = function(sig)
    local m = #sig
    if m > n then
      return false
    end

    for i = 1, m do
      local x = values[i]
      x = x == NIL and nil or x

      if not is(x, sig[i]) then
        return false
      end
    end

    return true
  end

  for sig, fn in pairs(methods) do
    if sig_matches(sig) then
      return fn
    end
  end

  return default
end

---Add function signature
---@param guard.valid_type any[]
---@param method function
---@return function
function multimethod:on(sig, method)
  if not is.pure_list(sig) then
    sig = { sig }
  end

  self.dispatch[sig] = method
  return method
end

---@param name string 
---@param default function
---@return multimethod
function multimethod.new(name, default)
  assert(default, 'No default method specified')

  ---@type multimethod
  local self = bless()
  self.__type = 'multimethod'
  self.dispatch = {}
  self.default = default
  self.name = name
  self.on = multimethod.on
  self.match = multimethod.match

  function self:__call(...)
    local fn = self:match(...)
    return fn(...)
  end

  return self
end

---@param name string
---@param default function
---@return multimethod
function multimethod:__call(name, default)
  return multimethod.new(name, default)
end
