local parse = {}

function parse.keys(match, repl)
  local ks = strsplit(match, '%.', {escaped = true})
  ks = list.map(ks, function (x) return tonumber(x) or x end)
  local ok = dict.get(repl, ks)

  return ok
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
  local sub = repl[var]

  if not sub then
    error("undefined placeholder: " .. var)
  else
    assert_is_a(sub, union("string", "number"))
    sub = tostring(sub)
  end

  local regex = string.sub(match, till + 1, #match)
  if #regex == 0 then
    error("no regex defined for placeholder: " .. match)
  end

  local ok = sub:match(regex)
  if not ok then
    error("match failure for `" .. var .. "` with regex " .. regex)
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


function template_replace(cmd, replacements)
  local repl = mtset({}, {
    __index = function(_, key)
      local ok = parse.parse(key, replacements)
      if not ok then error('undefined placeholder: ' .. key) end
      return ok
    end,
  })

  results = results or {}
  local len = 0
  local pos = strfind(cmd, "%{", { escaped = true })

  if #pos == 0 then
    return
  end

  local init = 1
  for i = 1, #pos do
    local open_pos = pos[i][1]
    local close_pos = strfind(cmd, "%}", { init = open_pos + 1, escaped = true, max = 1 })
    if #close_pos == 0 then
      error("paren not closed for opening paren at char " .. open_pos)
    else
      close_pos = close_pos[1][1]
    end

    local before = cmd:sub(init, open_pos-1)
    local word = repl[cmd:sub(open_pos + 1, close_pos - 1)]
    init = close_pos+1
    results[len+1] = before
    results[len+2] = word
    len = len + 2
  end

  return join(results, "")
end
