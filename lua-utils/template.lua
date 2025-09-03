require 'lua-utils.string'
require 'lua-utils.utils'

---@overload fun(s: string, replacements: table?): (string | fun(replacements: table): string)
local template = {}
setmetatable(template, template)

---Get the first nonescaped opening parenthesis
---If the opening parenthesis is escaped, the closing one is skipped as well
---@param s string
---@param start? number (default: 1)
---@return number?
function template.find_opening_bracket(s, start)
  start = start or 1
  local open_pos = string.find(s, '{', start, true)

  if not open_pos then
    return
  end

  local till_open = string.sub(s, start, open_pos-1)
  local escaped = string.match(till_open, '\\+$')

  if not escaped then
    return open_pos
  elseif #escaped % 2 == 0 then
    return open_pos
  else
    return template.find_opening_bracket(s, open_pos+1)
  end
end

---Get the first nonescaped closing parenthesis
---@param s string
---@param start? number (default: 1)
---@return number?
function template.find_closing_bracket(s, start)
  start = start or 1
  local open_pos = string.find(s, '}', start, true)

  if not open_pos then
    return
  end

  local till_open = string.sub(s, start, open_pos-1)
  local escaped = string.match(till_open, '\\+$')

  if not escaped then
    return open_pos
  elseif #escaped % 2 == 0 then
    return open_pos
  else
    return template.find_closing_bracket(s, open_pos+1)
  end
end

function template:__call(str, replacements)
  local start_pos = 1
  local final = {}
  local len = #str

  while true do
    local open_pos = template.find_opening_bracket(str, start_pos)
    local close_pos

    if open_pos then
      close_pos = template.find_closing_bracket(str, open_pos+1)
      if not close_pos then
        error(sprintf(
          'parsing error at character %d: Cannot find closing parenthesis: >>>%s<<<',
          open_pos,
          str:sub(start_pos, open_pos)
        ))
      else
        final[#final+1] = str:sub(start_pos, open_pos - 1)
        final[#final+1] = {str:sub(open_pos + 1, close_pos - 1)}
        start_pos = close_pos + 1
      end
    else
      close_pos = template.find_closing_bracket(str, start_pos)
      if close_pos then
        final[#final+1] = str:sub(start_pos, close_pos)
        start_pos = close_pos + 1
      else
        final[#final+1] = str:sub(start_pos, len)
        break
      end
    end
  end

  local function do_replace(repls)
    for i=1, #final do
      local s = final[i]
      if type(s) == 'table' then
        local var = s[1]
        if var == '' then
          error(sprintf('expected variable name, got nothing at word %d in %s', i, final))
        end

        local found = repls[var]
        if found then
          final[i] = repls[var]
        else
          local opt = var:find('%?$')
          if not opt or opt == #s then
            error(sprintf('no such placeholder: %s', var))
          end

          local default = opt and var:match('.+', opt + 1)
          local name = var:sub(1, opt - 1)
          found = repls[name] or default
        end
      end
    end
  end

  if replacements then
    do_replace(replacements)
    return table.concat(final, "")
  else
    return function (repls)
      do_replace(repls)
      return table.concat(final, "")
    end
  end
end

---Create a template or substitute variables into a template
---When the opening parenthesis is escaped and the number of backslashes happen to be odd in number
---the opening parenthesis and its corresponding closing parenthesis is skipped. 
---If no closing unescaped parenthesis is provided, the function will throw an error
---@param str string
---@param replacements? table
---@return string | (fun(replacements: table): string)
function template.template(str, replacements)
  return template(str, replacements)
end

return template
