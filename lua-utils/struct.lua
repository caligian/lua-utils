require "utils"
require "exception"
require "array"
require "dict"

struct = module "struct"

struct.exception = exception.new {
    invalid_attribute = "undefined attribute passed",
}

function struct.is_struct(st)
    return is_struct(st)
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

        if is_table(st1_v) then
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

    assert_type(ctor, "struct")

    if static then
        local methods = mtget(ctor, "static_methods")
        return methods[name]
    end

    local methods = mtget(ctor, "instance_methods")
    return methods[name]
end

function struct.get_methods(ctor, static)
    if static then return mtget(ctor, "static_methods") end

    return mtget(ctor, "instance_methods")
end

function struct.name(x) return mtget(x, "name") end

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
        if get_type_name(st) == struct.name(ctor) and inst_exists then
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

    local function new(opts, init_before, init)
        if get_type_name(opts) == name then return opts end

        local mt = {
            name = name,
            type = "struct",
            valid_attribs = valid_attribs,
            __newindex = function(self, key, value)
                if valid_metatable_keys[key] then
                    return mtset(self, key, value)
                elseif valid_attribs[key] then
                    return rawset(self, key, value)
                end

                error("attempting to add attribute to " .. dump(opts))
            end,
        }

        opts = opts or {}
        if init_before then opts = init_before(opts) end

        opts = setmetatable(copy(opts), mt)

        if init then return init(opts) end

        return opts
    end

    return setmetatable({
        init = function(obj) return obj end,
        valid_attribs = valid_attribs,
        new = new,
    }, {
        type = "module",
        name = name,
        instance_methods = {},
        static_methods = {},
        __call = function(self, opts)
            return new(opts, self.init_before, self.init)
        end,
        __newindex = function(self, key, value)
            if valid_metatable_keys[key] then
                return mtset(self, key, value)
            else
                if is_callable(value) then
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
            end

            struct.exception.invalid_attribute:assert(key)
            rawset(self, key, value)

            return value
        end,
    })
end
