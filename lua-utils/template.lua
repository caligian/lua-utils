require "lua-utils.utils"
require 'lua-utils.string'

local lpeg = require "lpeg"
local P = lpeg.P
local Cb = lpeg.Cb
local B = lpeg.B
local Cg = lpeg.Cg
local S = lpeg.S
local R = lpeg.R
local C = lpeg.C
local Ct = lpeg.Ct
local Cp = lpeg.Cp()
local Cs = lpeg.Cs
local V = lpeg.V

lpeg.locale(lpeg)

--[[
f strings like in python. However they cannot execute arbitrary code

echo {1} {2} {3}
echo {path}
sed -i '{sed_pat}' {fname}

Add {} around the parenthesis to ignore it
echo {{1}} -- will print echo {1}

--]]

local parse = {}

function parse.keys(match, repl)
  local ks = strsplit(match, '%.')

  ks = list.map(ks, function (x)
    return tonumber(x) or x
  end)
  return dict.get(repl, ks)
end

function parse.sed(match, repl)
  local matches = strsplit(match, "/", {ignore_escaped = true})
  if #matches ~= 3 then
    error('spec should be {var_name, pattern, replacement}, got ' .. match)
  end

  local var, regex, with = unpack(matches)
  if not repl[var] then
    error("undefined placeholder: " .. var)
  else
    assert_is_a(repl[var], union("string", "number"))
  end

  return (tostring(repl[var]):gsub(regex, with))
end

function parse.optional(match, repl)
  local var, default = match:match "^([^?]+)%?(.+)$"

  if not default then
    error("default key is undefined in " .. match)
  end

  local ok = repl[var] or repl[default]
  if not ok then
    if not default then
      error("undefined placeholder: " .. var)
    else
      error("undefined placeholder: " .. default)
    end
  end

  return ok
end

function parse.match(match, repl)
  repl = repl or {}
  local _, till = match:find "/"
  local var = match:sub(1, till - 1)

  if not repl[var] then
    error("undefined placeholder: " .. var)
  else
    assert_is_a(repl[var], union("string", "number"))
  end

  local regex = string.sub(match, till + 1, #match)
  if #regex == 0 then
    error("no regex defined for placeholder: " .. match)
  end

  local ok = repl[var]:match(regex)
  if not ok then
    error("match failure for " .. match .. " using " .. regex)
  end

  return ok
end

function parse.parse(match, repl)
  local sed_open = match:find "[^\\]/"
  local sed_close = sed_open and match:find("[^\\]/", sed_open + 1)

  if sed_open and sed_close then
    return parse.sed(match, repl)
  elseif sed_open then
    return parse.match(match, repl)
  elseif match:match "%." then
    return parse.keys(match, repl)
  elseif match:match "%?" then
    return parse.optional(match, repl)
  else
    local ok = repl[match]
    if not ok then
      error("undefined placeholder: " .. match)
    end

    return ok
  end
end

local function gmatch(s, repl)
  assert_is_a(repl, union('callable', 'table'))

  local nl = P"\n" ^ 0
  local escaped_open = P"\\{"
  local escaped_close = P"\\}"
  local paren_open = -B("\\") * P"{"
  local paren_close = -B("\\") * P"}"
  local before = C((1 - paren_open) ^ 0 + nl) 
  local chars = C((1 - paren_close) ^ 1 + nl) / function (x)
    if is_callable(repl) then
      return repl(x)
    end

    local v = parse.parse(x, repl)
    if is_nil(v) then
      error('undefined placeholder: ' .. x)
    end

    return v
  end

  local pat = Ct((before * paren_open * chars * paren_close * before) ^ 0)
  local ok = pat:match(s)

  if #ok > 0 then
    return (join(ok, ''):gsub('\\([{}])', '%1'))
  end

  return
end

function F(x, vars)
  local function use(_vars)
    return gmatch(x, _vars)
  end

  if not vars then
    return use
  end

  return use(vars)
end

template = F
