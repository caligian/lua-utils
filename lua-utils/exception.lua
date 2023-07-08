local pprint = require "pprint"
local dict = require "dict"
local array = require "array"
local module = require "module"
exception = module.new "exception"

local function new_exception(name, default_reason)
    local mt = {
        type = "exception",
        __tostring = function(self) return pprint.dump(copy(self)) end,
    }

    local self = {}

    function self:throw(reason, context)
        if not context then
            if not default_reason then error "no_default_reason" end
            error(
                setmetatable(
                    { name, reason = default_reason, context = reason },
                    { __tostring = mt.__tostring }
                )
            )
        else
            error(
                setmetatable(
                    { name, reason = reason, context = context },
                    { __tostring = mt.__tostring }
                )
            )
        end
    end

    function self:assert(test, reason, context)
        if test then return end
        self:throw(reason, context)
    end

    mt.__call = self.throw

    return setmetatable(self, mt)
end

function exception.new(name)
    if types.is_table(name) then
        local out = {}

        dict.each(
            name,
            function(err_name, reason)
                out[err_name] = new_exception(err_name, reason)
            end
        )

        return out
    end

    return new_exception(name)
end

return exception


