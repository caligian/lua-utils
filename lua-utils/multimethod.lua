--- Multimethod implementation
-- @classmod multimethod
-- @alias mt
local utils = require "lua-utils.utils"
local dict = require "lua-utils.dict"
local array = require "lua-utils.array"
local class = require "lua-utils.class"
local types = require "lua-utils.types"
local exception = require "lua-utils.exception"
local param = require "lua-utils.param"
local is_a = param.is_a
local mt = {}
local multimethod = setmetatable({}, mt)

--------------------------------------------------------------------------------
--- Raised when parameters' type signature is not recognized by method
multimethod.InvalidTypeSignatureException =
  exception "no callable associated with type signature"

--- Raised when multiple type signatures match the param's signatures
multimethod.MultipleSignaturesException =
  exception "duplicate type signature found"

--- Set callable for type signature
-- @tparam callable f
-- @tparam any ... type specs
function multimethod:set(f, ...) self.sig[{ ... }] = f end

function multimethod.compare_sig(signature, params)
  local status_i = 0
  local status = {}
  local sig_n = #signature
  local param_len = #params

  if param_len > sig_n then params = array.slice(params, 1, sig_n) end

  for i = 1, sig_n do
    local sig, param = signature[i], params[i]
    if sig == "*" and param ~= nil then
      status[status_i + 1] = true
    else
      local ok, _ = is(signature[i])(params[i])
      status[status_i + 1] = ok
    end

    status_i = status_i + 1
  end

  for i = status_i + 1, #params do
    status[i] = false
  end

  return status
end

function multimethod.get_matches(signatures, params)
  return array.grep(
    signatures,
    function(sig) return array.all(multimethod.compare_sig(sig, params)) end
  )
end

function multimethod.get_best_match(signatures, params)
  local found = multimethod.get_matches(signatures, params)
  array.sort(found, function(x, y) return #x > #y end)

  if #found == 0 then multimethod.InvalidTypeSignatureException:raise() end

  local dups = {}
  array.each(found, function(x)
    local n = #x
    if not dups[n] then
      dups[n] = true
    else
      multimethod.MultipleSignaturesException:raise(x)
    end

    return x
  end)

  return found[1]
end

--- Get callable for a type signature
-- @tparam any ... type specs
-- @treturn callable or throw error
function multimethod:get(...)
  local match = multimethod.get_best_match(dict.keys(self.sig), { ... })
  return self.sig[match]
end

--- Get a multimethod callable with .get and .set methods
-- @static
-- @usage
-- mm = multimethod()
-- mm = multimethod.new()
-- @see multimethod.get
-- @see multimethod.set
-- @treturn callable
function multimethod.new()
  return setmetatable({
    get = multimethod.get,
    set = multimethod.set,
    sig = {},
  }, {
    __call = function(self, ...) return self:get(...)(...) end,
  })
end

function mt:__call() return self.new() end

return multimethod
