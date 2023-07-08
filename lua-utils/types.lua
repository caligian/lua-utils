--- Type checking utilities
-- Lua has 7 (excluding nil) distinct types. We add 'class' and 'callable' to that list.
-- However these types will be accessible only via .typeof
-- @module types
-- local module = require 'lua-utils.module'
-- local types = module.new 'types'
-- local utils = require "utils"

local module = require 'module'
types = module.new 'types'
local utils = require "utils"

--- Lua builtin types
-- @table types.builtin
types.builtin = {
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
}

--- Is x a number?
-- @tparam any x
-- @treturn boolean
function types.is_number(x)
  return type(x) == "number"
end


--- Is x a string?
-- @tparam any x
-- @treturn boolean
function types.is_string(x)
  return type(x) == "string"
end

--- Is x a userdata?
-- @tparam any x
-- @treturn boolean
function types.is_userdata(x)
  return type(x) == "userdata"
end

--- Is x a coroutine?
-- @tparam any x
-- @treturn boolean
function types.is_thread(x)
  return type(x) == "thread"
end

--- Is x a boolean?
-- @tparam any x
-- @treturn boolean
function types.is_boolean(x)
  return type(x) == "boolean"
end

--- Is x a function?
-- @tparam any x
-- @treturn boolean
function types.is_function(x)
  return type(x) == "function"
end

function types.is_callable(x)
    if type(x) == 'function' then
        return true
    elseif type(x) ~= 'table' then
        return false
    end

    local mt = getmetatable(x)
    if not mt then return false end

    return mt.__call or false
end

--- Is x nil
-- @tparam any x
-- @treturn boolean
function types.is_nil(x)
  return x == nil
end

--- Is x a table (array|dict)?
-- @tparam any x
-- @treturn boolean
function types.is_table(x)
  return type(x) == "table" 
end

function types.get_type_name(x)
    if not types.is_table(x) then
        return
    end

    local mt = getmetatable(x)
    if not mt then return end

    return mt.name
end

function types.get_type(x)
    if not types.is_table(x) then
        return
    end

    local mt = getmetatable(x)
    if not mt then return end

    if mt.array then
        return 'array'
    elseif mt.dict then
        return 'dict'
    elseif mt.type then
        return mt.type, mt.name
    end
end

function types.typeof(x)
    local tp = type(x)

    if not tp then
        return false
    elseif tp ~= 'table' then
        return tp
    else
        local tp, name = types.get_type(x)

        if not tp then
            return 'table', name
        end

        return tp, name
    end
end

function types.is_struct(x)
    return types.get_type(x) == 'struct'
end

function types.is_module(x)
    return types.get_type(x) == 'module'
end

function types.is_exception(x)
    return types.get_type(x) == 'module'
end

function types.is_array(x)
    if not types.is_table(x) then
        return false
    elseif types.get_type(x) or types.is_callable(x) then
        return false
    end

    local mt = getmetatable(x) or {}
    if mt.array then return true end

    for k, v in pairs(x) do
        if not tostring(k):match('^[0-9]+$') then
            return false
        end
    end

    mt.array = true

    return setmetatable(x, mt)
end

function types.is_dict(x)
    if not types.is_table(x) then
        return false
    elseif types.get_type(x) or types.is_callable(x) then
        return false
    end

    local mt = getmetatable(x) or {}
    if mt.dict then return true end

    for k, v in pairs(x) do
        if tostring(k):match('^[0-9]+$') then
            break
        end
    end

    mt.dict = true

    return setmetatable(x, mt)
end

function types.union(...)
    local args = {...}

    for i = 1, #args do
        if args[i] == '*' then
            return true
        elseif not types.is_string(args[i]) then
            args[i] = types.typeof(args[i])
        end
    end

    local err_string = 'expected types: {' .. table.concat(args, ' ') .. '}, got '

    return function (x)
        local tp = types.typeof(x)
        err_string = err_string .. tp

        for i=1, #args do
            if tp == args[i] then
                return true
            end
        end

        return false, err_string
    end
end

function types.is_a(x, tp, assert_type)
    local x_tp, x_tp_name = types.typeof(x)

    if types.is_callable(tp) then
        local ok, msg = tp(x)

        if not ok then 
            if assert_type then error(msg) end
            return false, msg 
        end

        return true
    elseif types.is_array(tp) then
        return types.is_a(x, types.union(unpack(tp)), assert_type)
    elseif types.is_string(tp) then
        if tp:match '^[A-Z]' then
            local ok = x_tp_name == tp
            local msg = 'expected ' .. tp .. ', got ' .. (x_tp_name or x_tp)

            if ok then
                return true
            elseif assert_type and not ok then
                error(msg)
            end

            return false, msg
        end

        local ok = x_tp == tp
        local msg = 'expected ' .. tp .. ', got ' .. x_tp

        if ok then
            return true
        elseif assert_type and not ok then
            error(msg)
        end

        return false, msg
    else
        tp = types.typeof(tp)
        local ok = x_tp == tp
        local msg = 'expected ' .. tp .. ', got ' .. x_tp

        if ok then
            return true
        elseif assert_type and not ok then
            error(msg)
        end

        return false, msg
    end
end

function types.is(...)
    return types.union(...)
end

function types.assert_type(x, tp)
    return types.is_a(x, tp, true)
end

return types
