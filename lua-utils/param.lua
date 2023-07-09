--- Type validation utilities
local param = {}
local Set = require "Set"
local types = require "types"
local dict = require "dict"
local array = require "array"
local str = require "str"
local valid_types = types.builtin

local function filter_optional(spec, param)
    dict.each(dict.copy(spec), function(key, value)
        local is_opt = str.match_any(tostring(key), "^opt_", "^%?")
        local new_key = key

        if is_opt then
            new_key = str.gsub(key, "^" .. is_opt, "")
            spec[key] = nil

            if param[new_key] ~= nil then spec[new_key] = value end
        end
    end)
end

local function get_common_keys(spec, param)
    filter_optional(spec, param)

    local t_name = spec.__name or "<spec>"
    local nonexistent = spec.__nonexistent
    if spec.__nonexistent == nil then extra = true end

    local ks_spec = Set(
        array.grep(
            dict.keys(spec),
            function(key, _)
                return not str.match_any(key, "__nonexistent", "__name")
            end
        )
    )

    local ks_param = Set(
        array.grep(
            dict.keys(param),
            function(key, _)
                return not str.match_any(key, "__nonexistent", "__name")
            end
        )
    )

    local missing = ks_spec - ks_param
    local extra = ks_param - ks_spec
    local common = ks_param ^ ks_spec

    if Set.len(missing) > 0 then
        local msg = sprintf(
            "%s: missing keys: %s",
            t_name,
            array.join(Set.items(missing), ",")
        )
        error(msg)
    end

    if not nonexistent and Set.len(extra) > 0 then
        local msg = sprintf(
            "%s: extra keys: %s",
            t_name,
            array.join(Set.items(extra), ",")
        )
        error(msg)
    end

    return common
end

local function validate_table(spec, param)
    Set.each(get_common_keys(spec, param), function(k)
        local expected, got = spec[k], param[k]
        local t_name = spec.__name
        local nonexistent = spec.__nonexistent
        if nonexistent == nil then nonexistent = true end

        if
            types.typeof(expected) == "table"
            and types.typeof(got) == "table"
        then
            expected.__name = k
            expected.__nonexistent = nonexistent
            validate_table(expected, got)
        elseif types.typeof(expected) == "callable" then
            local ok, msg = expected(got)
            msg = msg or sprintf("%s.%s: callable failed", t_name, k)
            if not ok then error(msg) end
        else
            local ok, msg = is_a(got, expected)
            if not ok then error(sprintf("%s.%s: %s", t_name, k, msg)) end
        end
    end)
end

--- Validate parameters. Similar to vim.inspect.
-- @usage
--
-- -- syntax: {display = {spec, param}, ...}
--
-- -- rules:
-- -- * tables (not classes) will be recursed
-- -- * classes will be compared by name or <class>.is_a
-- -- * callable should return boolean, error_message or just boolean
-- -- * strings will be directly compared with either class name or .typeof(param)
-- -- * anything else will be compared by type
-- -- * optional keys should be prefixed with "opt_" or "?"
--
-- -- Nested tables supported. They should not be classes
-- -- b.c: expected string, got number
-- param.validate {
--   dict = {
--     {
--       a = 'number',
--       b = {
--         c = 'string'
--       }
--     },
--     {
--       a = 1,
--       b = {
--         c = 2
--       }
--     }
--   }
-- }
--
-- --- Indexing is also supported
-- -- error thrown
-- param.param.number('number', 'a')
--
-- @function param.validate
-- @param spec_with_param type specs for params. See usage
param.validate = setmetatable({}, {
    __call = function(_, spec_with_param)
        dict.each(spec_with_param, function(key, value)
            local is_opt = str.match_any(key, "^opt_", "^%?")
            local new_key = key

            if is_opt then new_key = str.gsub(key, "^" .. is_opt, "") end

            local spec, param = unpack(value)
            if is_opt and param == nil then return end

            if types.is_string(spec) then
                local ok, msg = types.is_a(param, spec)
                if not ok then error(key .. ": " .. msg) end
            elseif types.is_callable(spec) then
                local ok, msg = spec(param)
                if not ok then
                    error(key .. ": " .. (msg or "callable failed"))
                end
            elseif types.is_array(spec) or types.is_dict(spec) then
                if not types.is_table(param) then
                    error(
                        key
                            .. ": "
                            .. "expected table, got "
                            .. types.typeof(param)
                    )
                end

                spec.__name = spec.__name or key
                spec.__nonexistent = spec.__nonexistent == nil and true
                    or spec.__nonexistent

                validate_table(spec, param)
            else
                local ok, msg = types.is_a(param, spec)
                if not ok then error(sprintf("%s: %s", key, msg)) end
            end
        end)
    end,

    __index = function(self, display)
        return function(spec, param) self { [display] = { spec, param } } end
    end,
})

return param
