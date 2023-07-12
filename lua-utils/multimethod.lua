--- Multimethod implementation
-- @classmod multimethod
-- @alias mt
require "lua-utils.utils"
require "lua-utils.exception"
require "lua-utils.dict"
require "lua-utils.array"

multimethod = module 'multimethod'

multimethod.exception = {}
local err = multimethod.exception

--------------------------------------------------------------------------------
--- Raised when parameters' type signature is not recognized by method
err.invalid_type_signature = exception.new(
    "invalid_type_signature",
    "no callable associated with type signature"
)

--- Raised when multiple type signatures match the param's signatures
err.multiple_type_signatures =
    exception.new("duplicate_type_signature", "duplicate type signature found")

function multimethod.match_signature(signature, params, callback)
    local status_i = 0
    local status = {}
    local sig_n = #signature
    local param_len = #params

    if sig_n ~= param_len then return false end

    if param_len > sig_n then params = array.slice(params, 1, sig_n) end

    for i = 1, sig_n do
        local sig, param = signature[i], params[i]
        if sig == "*" and param ~= nil then
            status[status_i + 1] = true
        else
            local ok, _ = is_a(param, sig)
            if not ok then return false end
            status[status_i + 1] = ok
        end

        status_i = status_i + 1
    end

    for i = status_i + 1, #params do
        status[i] = false
    end

    for i = 1, status_i do
        if not status[i] then
            return false, status
        end
    end

    if callback then
        return callback(unpack(params))
    end

    return true, status
end

function multimethod.get_matches(signatures, params)
    return array.grep(signatures, function(sig)
        local ok, status = multimethod.match_signature(sig, params)
        if ok then return status end
    end)
end

function multimethod.get_best_match(signatures, params)
    local found = multimethod.get_matches(signatures, params)
    array.sort(found, function(x, y) return #x > #y end)

    err.invalid_type_signature:assert(#found ~= 0)

    local dups = {}
    array.each(found, function(x)
        local n = #x
        if not dups[n] then
            dups[n] = true
        else
            err.multiple_type_signatures:throw(x)
        end

        return x
    end)

    return found[1]
end

--- Get a multimethod callable with .get and .set methods
-- @static
-- @usage
-- mm = multimethod()
-- mm = multimethod.new()
-- @see multimethod.get
-- @see multimethod.set
-- @treturn callable
function multimethod.new(spec)
    local mt = {type = 'callable'}
    local mod = setmetatable({sig = {}}, mt)

    function mod:get_method(...)
        local match = multimethod.get_best_match(dict.keys(self.signatures), { ... })
        return self.signatures[match]
    end

    function mod:set_method(signature, callback) 
        self.signatures[signature] = callback
    end

    function mt:__call(...) 
        return self:get_method(...)(...) 
    end

    if spec then
        dict.each(spec, function(sig, callback)
            sig = array.to_array(sig)
            mod:set_method(sig, callback)
        end)
    end

    return mod
end

filetype.format_buffer('lua', buffer.bufnr())
