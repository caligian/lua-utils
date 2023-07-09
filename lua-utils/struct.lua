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

function struct.get_method(ctor, name, static)
    assert(struct.is_struct(ctor), "expected struct")

    types.assert_type(ctor, "struct")

    if static then
        local methods = utils.mtget(ctor, "static_methods")
        return methods[name]
    end

    local methods = utils.mtget(ctor, "instance_methods")
    return methods[name]
end

function struct.get_methods(ctor, static)
    if static then return utils.mtget(ctor, "static_methods") end

    return utils.mtget(ctor, "instance_methods")
end

function struct.name(x) return utils.mtget(x, "name") end

function struct.add_method(ctor, name, callback, static)
    local inst_methods = struct.get_methods(ctor)
    local static_methods = struct.get_methods(ctor, true)

    if static then
        static_methods[name] = callback
    else
        inst_methods[name] = callback
    end

    local inst_exists = inst_methods[name]
    local static_exists = static_methods[name]

    local function method(st, ...)
        if types.get_type_name(st) == struct.name(ctor) and inst_exists then
            return inst_exists(st, ...)
        elseif static_exists then
            return static_exists(st, ...)
        end
    end

    rawset(ctor, name, method)
end

function struct.new(name, valid_attribs)
    if not valid_attribs then error "no valid attribs passed" end

    for i = 1, #valid_attribs do
        valid_attribs[valid_attribs[i]] = i
    end

    return setmetatable({
        init = function(obj) return obj end,
        valid_attribs = valid_attribs,
    }, {
        type = "module",
        name = name,
        instance_methods = {},
        static_methods = {},
        __call = function(self, ...)
            local mt = {
                name = name,
                type = "struct",
                valid_attribs = valid_attribs,
            }

            local attribs = { ... }
            local n = #attribs
            local obj = {}

            if types.get_type_name(attribs[1]) == name then
                return attribs[1]
            end

            local args = {}

            local is_dict = types.is_dict(attribs[1])
                and n == 1
                and #array.grep(
                        dict.keys(attribs[1]),
                        function(x) return x:match "^[0-9]+$" end
                    )
                    == 0

            if is_dict then
                dict.each(attribs[1], function(key, value)
                    local i = mt.valid_attribs[key]
                    struct.exception.invalid_attribute:assert(i, key)
                    args[i] = value
                    obj[key] = value
                end)
            else
                for i = 1, #attribs do
                    local key = valid_attribs[i]

                    if not key then
                        error("undefined attribute passed " .. dump(key))
                    end

                    obj[key] = attribs[i]
                    args[i] = attribs[i]
                end
            end

            local n = #valid_attribs
            local m = #args
            if n ~= m then error("expected " .. n .. " args, got " .. m) end

            obj = setmetatable(obj, mt)

            if self.init then return self.init(obj, unpack(args)) end

            return attribs
        end,
        __newindex = function(self, key, value)
            if types.is_callable(value) then
                if key:match "^static_" then
                    struct.add_method(
                        self,
                        key:gsub("^static_", ""),
                        value,
                        true
                    )
                else
                    struct.add_method(self, key, value)
                end
            end

            if valid_mt_ks[key] then return utils.mtset(self, key, value) end

            struct.exception.invalid_attribute:assert(key)
            rawset(self, key, value)

            return value
        end,
    })
end

local Vector = struct.new("Vector", { "x", "y" })

function Vector.say(x) print "lkj" end

function Vector.static_say() print(1, 2, 3) end

local x = Vector(1, 2)
pp(x)

return struct


