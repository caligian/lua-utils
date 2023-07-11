require 'lua-utils.utils'
require "lua-utils.dict"
require "lua-utils.array"

exception = module "exception"

local function new_exception(name, default_reason)
    local mt = {
        type = "exception",
        __tostring = function(x) return dump(copy(x)) end,
        __mod = function (x, self)
            if not x then self:throw() end
            return x
        end,
    }

    local self = { name = name, reason = default_reason }

    function self:throw(reason, context)
        if not context then
            if not self.reason then error "no_default_reason" end

            local obj = setmetatable(
                { name, reason = self.reason, context = reason },
                { __tostring = mt.__tostring }
            )

            error(tostring(obj))
        else
            local obj = setmetatable(
                { name, reason = reason, context = context },
                { __tostring = mt.__tostring }
            )

            error(tostring(obj))
        end
    end

    function self:assert(test, reason, context)
        if test then return true end
        self:throw(reason, context)
    end

    mt.__call = self.throw

    return setmetatable(self, mt)
end

function exception.new(name, reason)
    if is_table(name) then
        local out = {}

        dict.each(
            name,
            function(err_name, reason)
                out[err_name] = new_exception(err_name, reason)
            end
        )

        return out
    end

    return new_exception(name, reason)
end

function exception:__call(self, ...)
	return exception.new(self, ...)
end
