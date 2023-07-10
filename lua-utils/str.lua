--- String utilities
-- This module adds some much needed string manipulation utilities to lua.
-- All the methods in this module are added to builtin string module
-- @module str
require "utils"

local str = {}

--------------------------------------------------------------------------------
--- Zip the start and end positions of regex found in the entire string
-- @tparam string s
-- @tparam string pat lua pattern
-- @tparam number limit  of matches to record
-- @treturn array[start,end]
function str.find_all(s, pat, limit)
    local pos = {}
    local pos_n = 0
    local n = #s
    local i = 1
    local init = 0
    local limit = limit or n

    while i <= limit do
        local from, till = string.find(s, pat, init + 1)
        if from and till then
            pos[i] = { from, till }
            init = till
        else
            break
        end
        i = i + 1
    end

    return pos
end

function str.splat(s)
    local out = {}
    for i = 1, #s do
        out[i] = string.sub(s, i, i)
    end

    return out
end

function str.to_array(x)
    return str.splat(x)
end

--- Split string by lua pattern N times
-- @param s string
-- @param delim delimiter pattern
-- @param times number of times to split the string
-- @treturn array[string]
function str.split(s, delim, times)
    delim = delim or " "

    if #delim == 0 then return str.splat(s) end

    local pos = str.find_all(s, delim, times)
    if #pos == 0 then return { s } end
    local out = {}
    local from = 0
    local last = 1

    for i = 1, #pos do
        out[i] = s:sub(from + 1, pos[i][1] - 1)
        from = pos[i][2]
        last = i
    end

    if from ~= 0 then out[last + 1] = s:sub(from + 1, #s) end

    return out
end

--- Match any of the lua patterns
-- @param s string
-- @param ... lua patterns for OR matching
-- @treturn string
function str.match_any(s, ...)
    for _, value in ipairs { ... } do
        local m = tostring(s):match(tostring(value))
        if m then return m end
    end
end

--- Is string blank?
-- @param x string
-- @treturn boolean
function str.is_empty(x) return #x == 0 end

--- Print string
-- @param x any
function str.print(x) print(x) end

--- Left and right trim the string
-- @param x string
-- @treturn string
function str.trim(x) return x:gsub("^%s*", ""):gsub("%s*$", "") end

--- string.gsub but with multiple patterns
-- @usage
-- str.sed('aabcd', {
--   -- array[<.gsub spec>]
--   {'a', function (x) return 'b' end, 1},
-- })
--
-- ('aabcd'):sed {
--   -- array[<.gsub spec>]
--   {'a', function (x) return 'b' end, 1},
-- }
-- @param s string
-- @param rep array[<.gsub spec>]
-- @treturn string
function str.sed(s, rep)
    local final = s
    for i = 1, #rep do
        final = final:gsub(unpack(repl[i]))
    end

    return final
end

function str.printf(...)
    return printf(...)
end

function str.sprintf(...)
    return sprintf(...)
end

function str.is_number(x)
    return x:match '^[0-9]+$'
end

function str.is_alphanum(x)
    return x:match '^[a-zA-Z0-9]+$'
end

function str.is_alpha(x)
    return x:match '^[a-zA-Z]+$'
end

function str.is_variable(x)
    return x:match('^[A-Za-z_]') and str.alphanum(x)
end

string.printf = printf
string.sprintf = sprintf
string.sed = str.sed
string.splat = str.splat
string.to_array = str.splat
string.find_all = str.find_all
string.len = str.len
string.split = str.split
string.is_alphanum = str.is_alphanum
string.is_alpha = str.is_alpha
string.is_variable = str.is_variable
string.is_number = str.is_number

return str
