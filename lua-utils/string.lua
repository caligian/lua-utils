--- String utilities
require "lua-utils.utils"
require "lua-utils.table"

substr = string.sub

function strfind(x, sep, opts)
  opts = opts or {}
  local max = opts.max
  local plain = opts.plain
  local escaped = opts.escaped or opts.ignore_escaped
  local capture = opts.capture
  local results = {}
  local init = opts.init or 1
  local results_len = 0

  local function get_next_sep(start_from)
    local next_sep = { string.find(x, sep, start_from, plain) }

    if #next_sep == 0 then
      return
    elseif escaped then
      local last_pos = next_sep[2] - 1
      local last_char = x:sub(last_pos, last_pos)

      if last_char == "\\" then
        return get_next_sep(next_sep[2] + 1)
      end
    end

    if capture then
      next_sep[3] = x:sub(unpack(next_sep))
    end

    return next_sep
  end

  local function findall(start_from)
    if max and max == results_len then
      return results
    end

    local next_sep = get_next_sep(start_from)
    if not next_sep then
      return results
    else
      results_len = results_len + 1
      results[results_len] = next_sep
    end

    return findall(next_sep[2] + 1)
  end

  return findall(init)
end

function strsplit(x, sep, opts)
  if sep == "" then
    local out = {}
    for i = 1, #x do
      out[i] = x:sub(i, i)
    end
    return out
  end

  opts = opts or {}
  local results = {}
  local pos = strfind(x, sep, opts)

  if #pos == 0 then
    return { x }
  end

  local init = opts.init or 1
  for i = 1, #pos do
    local word = x:sub(init, pos[i][1] - 1)
    init = pos[i][2] + 1
    results[#results + 1] = word
  end

  local len = #x
  if init <= len then
    results[#results + 1] = x:sub(init, len)
  end

  return results
end

--- Matching multiple patterns
--- @param x string
--- @param ... string
--- @return string|nil
function strmatch(x, ...)
  local args = { ... }

  for i = 1, #args do
    local found = x:match(args[i])
    if found then
      return found
    end
  end
end

--- Check if string is ^[a-zA-Z_][0-9a-zA-Z_]*$
--- @param x string
--- @return string|nil
function is_identifier(x)
  return x:match "^[a-zA-Z_][0-9a-zA-Z_]*$"
end

--- Replace multiple patterns like sed
--- @param x string
--- @param subs list[] string.gsub arguments
--- @return string|nil
function sed(x, subs)
  local og = x

  for _, args in ipairs(subs) do
    x = x:gsub(unpack(args))
  end

  if og == x then
    return
  end

  return x
end

--- Remove excess whitespace from left and right ends
--- @param x string
--- @return string
function trim(x)
  return (x:gsub("^%s*", ""):gsub("%s*$", ""))
end

--- Remove excess whitespace from left
--- @param x string
--- @return string
function ltrim(x)
  return (x:gsub("^%s*", ""))
end

--- Remove excess whitespace from right
--- @param x string
--- @return string
function rtrim(x)
  return (x:gsub("%s*$", ""))
end

local function _chomp(x)
  if #x == 0 then
    return
  end

  local last = substr(x, -1, -1)

  if last == "\n" then
    return substr(x, 1, -2)
  end

  return x
end

--- Remove newlines from string or string[]
--- @param x string|string[]
--- @return string|string[]
function chomp(x)
  if #x == 0 then
    return x
  end

  if type(x) == "table" then
    local res = {}
    for i = 1, #x do
      res[#res + 1] = _chomp(x[i]) or x[i]
    end

    return res
  end

  return _chomp(x) or x
end

function startswith(x, s)
  return x:match("^" .. s)
end

function endswith(x, s)
  return x:match(s .. "$")
end

string.startswith = startswith
string.endswith = endswith
string.findall = strfind
string.ltrim = ltrim
string.rtrim = rtrim
string.trim = trim
string.chomp = chomp
