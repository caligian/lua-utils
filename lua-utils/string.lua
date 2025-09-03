---Get string length
string.length = string.len

---Trim string from both ends.
---@param x string
---@return string  
function string.trim(x)
  x = x:gsub('^%s+', '')
  x = x:gsub('%s+$', '')
  return x
end

---Trim string at the start
---@param x string
---@return string  
function string.ltrim(x)
  x = x:gsub('^%s+', '')
  return x
end

---Trim string at the end
---@param x string
---@return string  
function string.rtrim(x)
  x = x:gsub('%s+$', '')
  return x
end

---String starts with?
---@param x string
---@param pat string
---@return boolean
function string.startswith(x, pat)
  return string.match(x, '^' .. pat) ~= nil
end

---String ends with?
---@param x string
---@param pat string
---@return boolean
function string.endswith(x, pat)
  return string.match(x, pat .. '$') ~= nil
end

---@class string.findall.opts
---@field max? number max number of splits
---@field plain? boolean match pattern plainly instead of using regex
---@field escaped? boolean ignore escaped pattern
---@field ignore_escaped? boolean alias for escaped
---@field capture? boolean capture the string matched
---@field init? number init position
---@field limit? number alias for opts.max

---@class string.findall.result
---@field [1] number init pos
---@field [2] number end pos
---@field [3] string captured string

---Find the index of string `sep`
---@param x string
---@param sep string
---@param opts? string.findall.opts
---@return string.findall.result[]
function string.findall(x, sep, opts)
  opts = opts or {}
  local max = opts.max or opts.limit
  local plain = opts.plain
  local escaped = opts.escaped or opts.ignore_escaped
  local capture = opts.capture
  local results = {}
  local init = opts.init or 1
  local results_len = 0

  local function get_next_sep(start_from)
    local next_sep =
      { string.find(x, sep, start_from, plain) }

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

---Split string
---@param x string
---@param sep string
---@param opts? string.findall.opts
---@return string[]
function string.split(x, sep, opts)
  if sep == "" then
    local out = {}
    for i = 1, #x do
      out[i] = x:sub(i, i)
    end
    return out
  end

  opts = opts or {}
  local results = {}
  local pos = string.findall(x, sep, opts)

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

---Capitalize every word
---@param x string input string
---@return string
function string.title(x)
  local words = string.split(x, "%s")
  for i=1, #words do
    local letter = words[i]:sub(1, 1):upper()
    words[i] = letter .. words[i]:sub(2, #words[i])
  end
  return table.concat(words, " ")
end

return string
