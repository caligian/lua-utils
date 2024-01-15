--- String utilities
require "lua-utils.utils"
require "lua-utils.table"

substr = string.sub

local function pat_split(x, sep, opts)
  opts = opts or {}
  local max = opts.max
  local results = {}
  local len = 0
  local init = opts.init or 1

  while init do
    local next_sep = { string.find(x, sep, init) }

    if #next_sep == 0 then
      break
    elseif max and len == max then
      break
    else
      local word = x:sub(init, next_sep[1] - 1)
      init = next_sep[2] + 1
      results[len + 1] = word
      len = len + 1
    end
  end

  if #results == 0 then
    return { x }
  else
    if max and max == len then
      return results
    end

    results[len + 1] = x:sub(init, #x)
    return results
  end
end

--- Split string
--- @overload fun(x: string, sep: string, maxtimes: number): string[]
function strsplit(x, sep, opts)
  assert(type(x) == "string", "needed string, got " .. tostring(x))
  assert(type(sep) == "string", "needed string, got " .. tostring(sep))

  if sep == "" then
    local out = {}
    for i = 1, #x do
      out[i] = x:sub(i, i)
    end

    return out
  end

  opts = opts or {}
  if opts.pattern then
    opts.ignore_escaped = false
  end

  if opts.ignore_escaped then
    opts.pattern = false
  end

  if (not opts.pattern and not opts.ignore_escaped) or opts.pattern then
    return pat_split(x, sep, opts)
  end

  local init = opts.init
  local max = opts.max
  local ignore_escaped = opts.ignore_escaped
  local word = ignore_escaped and string.format("[^%s]+|\\%s+", sep, sep)
  local pos = opts.pos
  init = init or 1
  local lpeg = require "lpeg"
  local sep_pat = lpeg.P(sep)

  local function match_seps_only(init_from)
    local pat = lpeg.C(sep_pat ^ 1) * lpeg.Cp()
    local matched, next_pos = pat:match(x, init_from)

    if not matched then
      return
    end

    len = #matched
    if len > 0 then
      return len - 1, next_pos
    end
  end

  local function get_next(init_from, results)
    local len = #results

    if max and len == max then
      return
    end

    init_from = init_from or 1
    local full_word, next_init
    local word
    local pat
    local extra_sep, new_init = match_seps_only(init_from, 0)
    local found, next_init

    if extra_sep then
      if max and len + extra_sep > max then
        extra_sep = (len + extra_sep) - max
      end

      for i = 1, extra_sep do
        results[#results + 1] = ""
      end

      return new_init
    end

    if ignore_escaped then
      local escaped = lpeg.P("\\" .. sep)
      local new_sep = lpeg.B(1 - escaped) * sep_pat
      word = ((1 - new_sep) + escaped)
      pat = lpeg.C(word ^ 1 * word ^ 0) * lpeg.Cp()
    else
      word = (1 - sep_pat)
      pat = lpeg.C(word ^ 1) * lpeg.Cp()
    end

    found, next_init = pat:match(x, init_from or 1)
    if found then
      results[#results + 1] = found
      return next_init
    end
  end

  local results = {}
  next_init = get_next(init, results)

  if not next_init then
    return { x }
  end

  while next_init do
    next_init = get_next(next_init, results)
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

--- Get start and ending index of a matched pattern
--- @param x string
--- @param pattern string
--- @param init? number initial position (default: 1)
--- @param times? number number of times. -1 to get all matches (default: -1)
--- @return number[]|nil
function strfind(x, pattern, init, times)
  init = init or 1
  local a, b = init, 1
  local len = #x
  local res = {}
  local n = 0
  times = times or -1

  while a <= len do
    if times ~= -1 and n > times then
      break
    end

    a, b = x:find(pattern, a)

    if a then
      list.append(res, { { a, b } })
      a = b + 1
      n = n + 1
    else
      break
    end
  end

  if #res == 0 then
    return
  end

  return res
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
