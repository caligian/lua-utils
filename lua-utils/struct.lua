-- local module = require "module"
-- local exception = require "exception"
-- local utils = require 'lua-utils.utils'
-- local array = require 'lua-utils.array'
-- local dict = require 'lua-utils.dict'

local utils = require "utils"
local module = require "module"
local array = require "array"
local dict = require "dict"
local exception = require "exception"
local struct = module.new "struct"

local valid_mt_ks = {
    __unm = true,
    __eq = true,
    __ne = true,
    __ge = true,
    __gt = true,
    __le = true,
    __lt = true,
    __add = true,
    __sub = true,
    __mul = true,
    __div = true,
    __mod = true,
    __pow = true,
    __tostring = true,
    __tonumber = true,
    __index = true,
    __newindex = true,
    __call = true,
    __metatable = true,
    __mode = true,
}

struct.exception = exception.new {
    invalid_attribute = "undefined attribute passed",
}

function struct.is_struct(st)
    if not types.is_table(st) then
        return
    elseif not utils.mtget(st, "type") == "struct" then
        return
    end

    return utils.mtget(st, "name")
end

function struct.name(st) return struct.is_struct(st) end

function struct.equals(st1, st2, opts)
    assert(struct.is_struct(st1), "invalid_struct1")
    assert(struct.is_struct(st2), "invalid_struct2")

    opts = opts or {}
    local absolute = opts.compare_tables
    local callback = opts.callback

    if not struct.is_struct(st1) then return false end

    if not struct.is_struct(st2) then return false end

    local ks1 = dict.keys(st1)
    local ks2 = dict.keys(st2)

    if #ks1 ~= #ks2 then return false end

    for i = 1, #ks1 do
        local k = ks1[i]
        local st1_v = st1[k]
        local st2_v = st2[k]

        if type(st1_v) ~= type(st2_v) then return false end

        if types.is_table(st1_v) then
            if absolute and not dict.compare(st1_v, st2_v, callback, true) then
                return false
            elseif not st1_v == st2_v then
                return false
            end
        elseif not st1_v == st2_v then
            return false
        end
    end

    return true
end

function struct.not_equals(...) return not struct.equals(...) end

function struct.new(name, valid_attribs)
    if not valid_attribs then error "no_valid_attribs" end

    valid_attribs = array.todict(valid_attribs)

    local mt = {
        name = name,
        type = "struct",
        valid_attribs = valid_attribs,
        __newindex = function(self, key, value)
            if valid_mt_ks[key] then return utils.mtset(self, key, value) end

            struct.exception.invalid_attribute:assert(key)
            rawset(self, key, value)

            return value
        end,
    }

    return setmetatable({}, {
        __call = function(self, attribs)
            attribs = array.copy(attribs or {})

            dict.each(
                attribs,
                function(key, value)
                    struct.exception.invalid_attribute:assert(
                        mt.valid_attribs[key],
                        key
                    )
                end
            )

            return setmetatable(attribs, mt)
        end,
        __newindex = function (self, key, value)
            if types.is_function(value) then
                rawset(self, key, function (st, ...)
                    local tp, tp_name = types.typeof(st)
                    if tp ~= 'struct' or tp_name ~= name then
                        error('expected ' .. name .. ', got ' .. (tp_name or type(st)))
                    end

                    return value(st, ...)
                end)
            else
                rawset(self, key, value)
            end
        end
    })
end

function struct.include(dst, src, opts)
    assert(struct.is_struct(dst), "invalid_dst_struct")
    assert(struct.is_struct(src), "invalid_src_struct")

    opts = opts or {}
    local overwrite = opts.overwrite
    local missing = opts.missing

    if overwrite == nil then overwrite = true end
    if missing == nil then missing = true end

    dict.each(src, function(key, value)
        if not dst[key] then
            if missing then dst[key] = value end
        elseif overwrite then
            dst[key] = value
        end
    end)

    return dst
end

types.is_struct = struct.is_struct

return struct
