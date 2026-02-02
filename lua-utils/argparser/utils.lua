require "lua-utils.string"
local list = require "lua-utils.list"
local types = require 'lua-utils.types'
local sys = require 'system'
local utils = {}

function utils.print_and_exit(msg, ...)
  printf(msg, ...)
  os.exit(1)
end

function utils.get_term_width(default)
  default = default or 50
  local nrow, ncol = sys.termsize()
  if nrow == nil then
    return default
  else
    return ncol
  end
end

function utils.format_metavar(metavar, nargs)
  metavar = metavar or 'ARGUMENT'
  if nargs == '?' then
    return sprintf('[%s]', metavar)
  elseif nargs == '+' then
    return sprintf('{%s#1} [%s#2] ...', metavar, metavar)
  elseif nargs == '*' then
    return sprintf('[%s#1] [%s#2] ...', metavar, metavar)
  elseif nargs == 1 then
    return sprintf('{%s}', metavar, nargs)
  elseif type(nargs) == 'number' and nargs > 0 then
    return sprintf('{%s}<%d>', metavar, nargs)
  else
    return ''
  end
end

function utils.assert_nargs(name, args, nargs)
  local passed = #args

  if types.number(nargs) then
    if nargs ~= passed then
      utils.print_and_exit(
        '<keyword>%s: Expected %d arguments, got %d',
        name, nargs, passed
      )
    end
  elseif nargs == "?" then
    if passed > 1 then
      utils.print_and_exit(
        '<keyword>%s: Expected 1 or 0 argument, got %d',
        name, passed
      )
    end
  elseif nargs == "+" then
    if passed == 0 then
      utils.print_and_exit(
        '<keyword>%s: Expected more than 1 argument, got %d',
        name, passed
      )
    end
  end

  return true
end

function utils.assert(name, args, assertion)
  if not assertion then
    return true
  end

  list.each(args, function(x)
    local ok, msg = assertion(x)
    if not ok then
      msg = '<keyword>' .. name .. ": " .. msg
      utils.print_and_exit(msg)
    end
  end)

  return true
end

function utils.create_help(header, help, maxwidth)
  maxwidth = maxwidth or utils.get_term_width(72)
  local midpoint = math.ceil(maxwidth / 2) - 3
  midpoint = ifelse(midpoint < 20, 20, midpoint)
  local header_len = #header
  help = string.split(help, "%s+")
  help = list.filter(help, function (x)
    return #x > 0
  end)
  final = {}
  local push = function (x)
    final[#final+1] = x
  end
  local push_blank = function (how_much)
    how_much = how_much or midpoint
    push(string.rep(" ", how_much + 1))
  end

  if midpoint < header_len then
    push(header)
    push("\n")
    push_blank()
  else
    push(header)
    local dist = midpoint - #header
    push_blank(dist)
  end

  local size = 0
  for i=1, #help do
    if size > midpoint or (size + #help[i]) > midpoint then
      push("\n")
      push_blank()
      size = 0
    end

    push(help[i])
    push(" ")
    size = size + #help[i] + 1
  end

  table.remove(final, #final)
  return table.concat(final, '')
end

return utils
