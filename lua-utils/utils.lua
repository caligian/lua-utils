--- Misc utilities
-- @module utils
inspect = require "inspect"

valid_types = {
    userdata = true,
    number = true,
    string = true,
    table = true,
    thread = true,
    ["function"] = true,
    callable = true,
    boolean = true,
    struct = true,
    exception = true,
    ["nil"] = true,
}

valid_metatable_keys = {
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

--- Stringify object
-- @tparam any x
-- @treturn string
function dump(x) return inspect(x) end

--- Stringify and print object
-- @tparam any x object
function pp(x) print(inspect(x)) end

--- sprintf with stringification
-- @tparam string fmt string.format compatible format
-- @tparam any ... placeholder variables
-- @treturn string
function sprintf(fmt, ...)
    local args = { ... }
    for i = 1, #args do
        args[i] = type(args[i]) ~= "string" and inspect(args[i]) or args[i]
    end

    return string.format(fmt, unpack(args))
end

--- printf with stringification
-- @tparam string fmt string.format compatible format
-- @tparam any ... placeholder variables
function printf(fmt, ...) print(sprintf(fmt, ...)) end

--- Get metatable or metatable key
-- @param obj table
-- @param k key
-- @treturn[1] ?metatable
-- @treturn[2] ?metatable[k]
function mtget(obj, k)
    if type(obj) ~= "table" then return end
    local mt = getmetatable(obj)
    if not mt then return end
    if k then return mt[k] end
    return mt
end

--- Set metatable or metatable key
-- @param obj table
-- @param k key
-- @param v value
-- @treturn ?any
function mtset(obj, k, v)
    if type(obj) ~= "table" then return end
    local mt = getmetatable(obj)
    if not mt then return end
    if k and v then
        mt[k] = v
        return v
    end
end

--- Shallow copy a table
-- @param obj table
-- @treturn table
function copy(obj)
    local out = {}
    for key, value in pairs(obj) do
        out[key] = value
    end
    return out
end

function module(name)
    local mod = { type = "module", name = name }
    local mt = { __tostring = dump }

    function mt:__newindex(key, value)
        if valid_metatable_keys[key] then
            mt[key] = value
            return value
        end

        return rawset(self, key, value)
    end

    function mt:__index(key)
        if valid_metatable_keys[key] then return mt[key] end
    end

    return setmetatable(mod, mt)
end

--- Decorate a function
-- @tparam callable f1 to be decorated
-- @tparam callable f2 decorating function
-- @treturn function
function decorate(f1, f2)
    return function(...) return f2(f1(...)) end
end

--- Apply an array of args to a function
-- @tparam callable f
-- @tparam array args to apply
-- @treturn any
function apply(f, args) return f(unpack(args)) end

--- Prepend args and apply params
-- @tparam callable f
-- @tparam array ... params to prepend
-- @treturn any
function rpartial(f, ...)
    local outer = { ... }
    return function(...)
        local inner = { ... }
        local len = #outer
        for idx, a in ipairs(outer) do
            inner[len + idx] = a
        end

        return f(unpack(inner))
    end
end

--- Append args and apply params
-- @tparam callable f
-- @tparam array ... params to append
-- @treturn any
function partial(f, ...)
    local outer = { ... }
    return function(...)
        local inner = { ... }
        local len = #outer
        for idx, a in ipairs(inner) do
            outer[len + idx] = a
        end

        return f(unpack(outer))
    end
end

--- Return object
-- @tparam any x
-- @treturn any
function identity(x) return x end

--- Pass an element through N callables
-- @tparam any x
-- @tparam array[callable] ...
-- @treturn any
function thread(x, ...)
    local out = x
    local args = { ... }

    for i = 1, #args do
        local f = args[i]
        out = f(out)
    end

    return out
end

function values(t)
    local out = {}
    local i = 1

    for _, value in pairs(t) do
        out[i] = value
        i = i + 1
    end

    return out
end

function keys(t, sort, cmp)
    local out = {}
    local i = 1

    for key, _ in pairs(t) do
        out[i] = key
        i = i + 1
    end

    if sort then return table.sort(out, cmp) end

    return out
end

-- Lua has 7 (excluding nil) distinct  We add 'class' and 'callable' to that list.
-- However these types will be accessible only via .typeof
-- @module types
-- local module = require 'lua-module'
-- local types = module.new 'types'
-- local utils = require "utils"

--- Is x a number?
-- @tparam any x
-- @treturn boolean
function is_number(x) return type(x) == "number" end

--- Is x a string?
-- @tparam any x
-- @treturn boolean
function is_string(x) return type(x) == "string" end

--- Is x a userdata?
-- @tparam any x
-- @treturn boolean
function is_userdata(x) return type(x) == "userdata" end

--- Is x a coroutine?
-- @tparam any x
-- @treturn boolean
function is_thread(x) return type(x) == "thread" end

--- Is x a boolean?
-- @tparam any x
-- @treturn boolean
function is_boolean(x) return type(x) == "boolean" end

--- Is x a function?
-- @tparam any x
-- @treturn boolean
function is_function(x) return type(x) == "function" end

function is_callable(x)
    if type(x) == "function" then
        return true
    elseif type(x) ~= "table" then
        return false
    end

    local mt = getmetatable(x)
    if not mt then return false end

    return (mt.__call and #keys(mt) == 1) or mt.type == "callable" or false
end

--- Is x nil
-- @tparam any x
-- @treturn boolean
function is_nil(x) return x == nil end

--- Is x a table (array|dict)?
-- @tparam any x
-- @treturn boolean
function is_table(x) return type(x) == "table" end

function get_type_name(x)
    if not is_table(x) then return end

    local mt = getmetatable(x)
    if not mt then return end

    return mt.name
end

function is_array(x)
    if not is_table(x) then
        return false
    elseif mtget(x, "type") or is_callable(x) then
        return false
    elseif #x == 0 then
        return true
    end

    local mt = getmetatable(x) or {}
    if mt.array then return true end

    for k, v in pairs(x) do
        if not tostring(k):match "^[0-9]+$" then return false end
    end

    mt.array = true

    return setmetatable(x, mt)
end

function is_dict(x)
    if not is_table(x) then
        return false
    else
        local found
        for key, value in pairs(x) do
            found = key
            break
        end

        if found then
            return false
        elseif is_array(x) then
            return false
        end

        mtset(x, "dict", true)
        return true
    end
end

function is_empty(x)
    if not is_string(x) and not is_table(x) then 
        return 
    elseif is_string(x) then
        return #x == 0
    end

    local key = next(x)
    if key then return false end

    return true
end

function get_type(x)
    if not is_table(x) then
        return
    elseif is_empty(x) then
        return "table"
    elseif is_dict(x) then
        return "dict"
    elseif is_array(x) then
        return "array"
    end

    local mt = getmetatable(x)
    if not mt then return end

    if mt.array then
        return "array"
    elseif mt.dict then
        return "dict"
    elseif mt.type then
        return mt.type, mt.name
    end
end

function typeof(x)
    local tp = type(x)

    if not tp then
        return false
    elseif tp == "function" then
        return "callable"
    elseif tp ~= "table" then
        return tp
    elseif is_empty(x) then
        return 'table'
    else
        tp, name = get_type(x)
        if not tp then return "table" end
        return tp, name
    end
end

function is_struct(x, name) 
    local x, y = get_type(x)
     
    if x == 'struct' then
        if name then
            return name == y
        end
        return true
    end

    return false
end

function is_module(x) return get_type(x) == "module" end

function is_exception(x) return get_type(x) == "module" end

function union(...)
    local args = { ... }

    for i = 1, #args do
        if args[i] == "*" then
            return true
        elseif not is_string(args[i]) then
            args[i] = typeof(args[i])
        end
    end

    local err_string = "expected types: {"
        .. table.concat(args, " ")
        .. "}, got "

    return function(x)
        local tp = typeof(x)
        err_string = err_string .. tp

        for i = 1, #args do
            if tp == args[i] then return true end
        end

        return false, err_string
    end
end

is_a = setmetatable({}, {
    __index = function(self, key)
        return function(x)
            return self(x, key)
        end
    end,
    __call = function(self, x, tp, assert_type)
        if tp == 'table' and type(x) == 'table' then
            return true
        end

        local x_tp, x_tp_name = typeof(x)
        if not x_tp and x_tp_name then error("invalid object " .. dump(x)) end

        local tp_tp, tp_name = typeof(tp)
        if not tp_tp and tp_tp_name then error("invalid object " .. dump(x)) end

        local x_display
        local tp_display

        if x_tp_name then
            x_display = string.format("%s (%s)", x_tp_name or "", x_tp)
        else
            x_display = string.format("%s", x_tp)
        end

        if tp_name then
            tp_display = string.format("%s (%s)", tp_name or "", tp_tp)
        else
            tp_display = string.format("%s", tp_tp)
        end

        if tp_tp == "callable" then
            local ok, msg = tp(x)

            if not ok then
                if assert_type then error(msg) end
                return false, msg
            end

            return true
        elseif tp_tp == "array" then
            return is_a(x, union(unpack(tp)), assert_type)
        elseif tp_tp == "string" then
            tp_tp = ''
            tp_display = ''

            local match_tp, match_name
            match_tp = tp:match '^[a-zA-Z0-9_]+%.'
            match_name = tp:match '[a-zA-Z0-9_]+$'

            if not match_tp and not match_name then
                error('invalid type ' .. tp)
            elseif match_name then
                tp_tp = match_name
                tp_display = tp_tp
            else
                tp_tp = match_tp
                tp_name = match_name
                tp_display = sprintf('%s (%s)', tp_name, tp_tp)
            end

            local msg = 'expected ' .. tp_display .. ', got ' .. x_display

            if tp_tp and tp_name then
                if tp_tp == x_tp and tp_name == x_tp_name then
                    return true
                elseif assert_type then
                    error(msg)
                else
                    return false, msg
                end
            elseif tp_tp then
                if tp_tp == x_tp then
                    return true
                elseif assert_type then
                    error(msg)
                else
                    return false, msg
                end
            end
        
            return false, msg
        else
            local ok, msg

            if tp_name and x_tp_name then
                ok = tp_name == x_tp_name
                msg = "expected " .. tp_display .. ", got " .. x_display
                if not ok then error(msg) end
            end

            ok = x_tp == tp_tp
            msg = "expected " .. tp_display .. ", got " .. x_display

            if ok then
                return true
            elseif assert_type and not ok then
                error(msg)
            end

            return false, msg
        end
    end,
})

function is(x)
    if not is_array(x) then x = { x } end
    return union(unpack(x))
end

function assert_type(x, tp) return is_a(x, tp, true) end

function deepcopy(x, callback)
    if type(x) ~= "table" then return x end

    local cache = {}
    local new = new or {}
    local current = new

    local function walk(tbl)
        if cache[tbl] then
            return
        else
            cache[tbl] = true
        end

        for key, value in pairs(tbl) do
            if type(value) == "table" and not cache[tbl] then
                current[key] = {}
                current = current[key]
                deepcopy(value)
            elseif callback then
                current[key] = callback(value)
            else
                current[key] = value
            end
        end
    end

    walk(x)

    return new
end

function is_type(x)
    return get_type(x)
end

function is_named_type(x)
    local tp, name = get_type(x)

    if name then
        return false
    else
        return name, tp
    end
end
