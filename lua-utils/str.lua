--- String utilities
-- This module adds some much needed string manipulation utilities to lua.
-- All the methods in this module are added to builtin string module
-- @module str
local utils = require "lua-utils.utils"
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
    local from, till = str.find(s, pat, init + 1)
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

--- Split string by lua pattern N times
-- @param s string
-- @param delim delimiter pattern
-- @param times number of times to split the string
-- @treturn array[string]
function str.split(s, delim, times)
  delim = delim or " "
  local pos = str.find_all(s, delim, times)
  if #pos == 0 then
    return { s }
  end
  local out = {}
  local from = 0
  local last = 1

  for i = 1, #pos do
    out[i] = s:sub(from + 1, pos[i][1] - 1)
    from = pos[i][2]
    last = i
  end

  if from ~= 0 then
    out[last + 1] = s:sub(from + 1, #s)
  end

  return out
end

--- Alias for string.format
-- @param fmt format string
-- @param ... placeholder variables
-- @treturn string
function str.sprintf(fmt, ...)
  return string.format(fmt, ...)
end

--- Print formatted string
-- @see sprintf
-- @param fmt format string
-- @param ... placeholder variables
function str.printf(fmt, ...)
  print(sprintf(fmt, ...))
end

--- Alias for string.format
-- @param fmt format string
-- @param ... placeholder variables
-- @treturn string
function sprintf(fmt, ...)
  return str.format(fmt, ...)
end

--- Print formatted string
-- @see sprintf
-- @param fmt format string
-- @param ... placeholder variables
function printf(fmt, ...)
  print(sprintf(fmt, ...))
end

--- Match any of the lua patterns
-- @param s string
-- @param ... lua patterns for OR matching
-- @treturn string
function str.match_any(s, ...)
  for _, value in ipairs { ... } do
    local m = tostring(s):match(tostring(value))
    if m then
      return m
    end
  end
end

--- Is string blank?
-- @param x string
-- @treturn boolean
function str.isblank(x)
  return #x == 0
end

--- Print string
-- @param x any
function str.print(x)
  print(x)
end

--- Left and right trim the string
-- @param x string
-- @treturn string
function str.trim(x)
  return x:gsub("^%s*", ""):gsub("%s*$", "")
end

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

--- Print string
-- @param s string
function str.print(s)
  print(s)
end

--- alias for string.format
-- @param fmt string.format format
-- @param ... placeholder variables
-- @treturn string
function str.printf(fmt, ...)
  return string.format(fmt, ...)
end

for key, value in pairs(string) do
  str[key] = value
end

for key, value in pairs(str) do
  string[key] = value
end

return str
