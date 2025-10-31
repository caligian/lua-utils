require 'lua-utils.string'
require 'lua-utils.utils'

---String matching utilities for template strings
local placeholder = {}

---Check if placeholder name is valid
---@param name string | number
---@return boolean?
function placeholder.check_name(name)
  if type(name) == 'string' and not string.match(name, '^[a-zA-Z0-9_.-]+$') then
    errorf('Placeholder `%s` did not match `^[a-zA-Z0-9_.-]+$`', name)
  else
    return true
  end
end

---Find the next opening or closing bracket
---@param s string
---@param start number (default: 1) Start index
---@param is_closing? boolean Whether to match '}' instead of '{'
---@return number?
function placeholder.find_next_bracket(s, start, is_closing)
  local open = not is_closing
  local bracket = open and '{' or '}'
  start = start or 1
  local l = #s
  local i = start

  while i <= l do
    local c = s:sub(i, i)

    if c == bracket then
      local pos = i
      local till = string.sub(s, start, pos - 1)
      local escaped = string.match(till, '\\+$')

      if not escaped then
        return pos
      elseif #escaped % 2 == 0 then
        return pos
      else
        start = pos + 1
        i = pos + 1
      end
    else
      i = i + 1
    end
  end
end

---Find '{'
---@param s string
---@param start? number Start index
---@return number?
function placeholder.find_opening_bracket(s, start)
  return placeholder.find_next_bracket(s, start, false)
end

placeholder.opening = placeholder.find_opening_bracket

---Find '}'
---@param s string
---@param start? number Start index
---@return number?
function placeholder.find_closing_bracket(s, start)
  return placeholder.find_next_bracket(s, start, true)
end

placeholder.closing = placeholder.find_closing_bracket

---Return the position of next '{' and '}' in string 
---@param s string
---@param start? number
---@return number[]?
function placeholder.find_next_brackets(s, start)
  local open_pos = placeholder.opening(s, start)
  local close_pos = placeholder.closing(s,
    open_pos and open_pos + 1 or start
  )

  if open_pos and close_pos then
    if open_pos > close_pos then
      errorf('No opening bracket given for closing bracket at char %d in `%s`', open_pos, s)
    else
      return { open_pos, close_pos }
    end
  elseif not open_pos and not close_pos then
    return
  elseif not open_pos then
    errorf('No opening bracket given for closing bracket at char %d in `%s`', close_pos, s)
  elseif not close_pos then
    errorf('No closing bracket given for opening bracket at char %d in `%s`', open_pos, s)
  end
end

placeholder.pair = placeholder.find_next_brackets

---@class placeholder.next.result
---@field before string
---@field placeholder string | number
---@field next number
---@field string string

---Parse one placeholder and return the next state
---@param s string
---@return placeholder.next.result?
function placeholder.next(s, start)
  local pos = placeholder.pair(s, start)

  if not pos then
    return {
      string = s,
      next = false
    }
  end

  start = start or 1
  local open_pos, close_pos = unpack(pos)
  local name = s:sub(open_pos + 1, close_pos - 1)
  placeholder.check_name(name)
  local before = s:sub(start, open_pos - 1)
  local result = {}

  result.before = before

  if name:match('^[0-9]+$') then
    result.placeholder = tonumber(name)
  else
    result.placeholder = name
  end

  result.before = before
  result.next = close_pos + 1
  result.string = s

  return result
end

return placeholder
