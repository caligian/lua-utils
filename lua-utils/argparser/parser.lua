require "lua-utils.string"
local copy = require 'lua-utils.copy'
local list = require "lua-utils.list"
local dict = require 'lua-utils.dict'
local class = require 'lua-utils.class'
local types = require 'lua-utils.types'
local validate = require 'lua-utils.validate'
local path = require 'lua-utils.path_utils'
local utils = require 'lua-utils.argparser.utils'
local KeywordArgument = require 'lua-utils.argparser.keyword_argument'
local PositionalArgument = require 'lua-utils.argparser.positional_argument'

--- Parse defaults if possible

---@class ParsedArguments
---@field keyword_arguments table<string,any>
---@field positional_arguments any[]
---@field arguments string[] Rest of the arguments passed
---@field K table<string, any> Alias for .keyword_arguments
---@field P table<string, any> Alias for .positional_arguments
---@field args string[] Alias for .arguments

---@class Argparser
---@field description string
---@field parsed ParsedArguments
---@field filename string Name of the source script
---@field desc string Alias for .description
---@overload fun(description: string)
local Argparser = class "Argparser"

function Argparser:initialize(description)
  types.assert.desc(description, 'string')

  self.parsed = {
    keyword_arguments = {},
    positional_arguments = {},
    arguments = {}
  }
  self.parsed.K = self.parsed.keyword_arguments
  self.parsed.P = self.parsed.positional_arguments
  self.parsed.args = self.parsed.arguments
  self.keyword_arguments = {}
  self.positional_arguments = {}
  self.filename = path.basename(arg[0])
  self.description = description
  self.desc = description
  self:K('h', 'help', { help = "Show this help" })

  return self
end

function Argparser:add_keyword_argument(short_name, long_name, spec)
  local kw = KeywordArgument(short_name, long_name, spec)
  self.keyword_arguments[kw.name] = kw
  return kw
end

Argparser.K = Argparser.add_keyword_argument

function Argparser:add_positional_argument(name, spec)
  local pos = PositionalArgument(name, spec)
  self.positional_arguments[pos.name] = pos
  self.positional_arguments[#self.positional_arguments + 1] = pos
  pos.index = #self.positional_arguments

  return pos
end

Argparser.P = Argparser.add_positional_argument

function Argparser:_find_keyword_arguments(args, maxwidth)
  local findall = function(ls, x)
    if not x then
      return {}
    end

    local out = {}
    for i = 1, #ls do
      if ls[i] == x then
        out[#out + 1] = i
      end
    end

    return out
  end
  args = args or self.args
  local n = #args
  local withindex = {}

  dict.each(self.keyword_arguments, function(name, specs)
    local long_option = specs.long_name
    local short_option = specs.short_name
    local long = long_option and "--" .. long_option
    local short = short_option and "-" .. short_option
    local long_index = findall(args, long)
    local short_index = findall(args, short)
    local all = list.extend(long_index, short_index)
    specs.index = all
    specs.times_passed = #all

    if long_option == "help" and specs.times_passed > 0 then
      self:print_help(maxwidth)
      os.exit(0)
    end

    if #all > 1 and not specs.duplicate then
      utils.print_and_exit('<keyword>%s: No duplicates allowed', name)
    end

    list.each(all, function(ind)
      list.append(withindex, {
        pos = ind,
        name = name,
        spec = specs,
        args = {}
      })
    end)
  end)

  dict.each(self.keyword_arguments, function(name, specs)
    if specs.times_passed == 0 and specs.required then
      utils.print_and_exit('<keyword>%s: Required but not passed', name)
    end
  end)

  withindex = list.sort(withindex, function(a, b)
    return a.pos < b.pos
  end)

  for i = 1, #withindex do
    local current = withindex[i]
    local next_ = withindex[i + 1]
    local next_pos = next_ and next_.pos
    local current_pos = current.pos
    local current_name = current.spec.name
    local current_nargs = current.spec.nargs
    local current_args = current.spec.args
    local current_passed = #current_args

    if current_nargs == '?' and current_passed > 1 then
      utils.print_and_exit(
        '<keyword>%s: Expected 1 or 0 arguments, got %d',
        current_name, current_passed
      )
    elseif
        type(current_nargs) == 'number' and current_passed > current_nargs
    then
      utils.print_and_exit(
        '<keyword>%s: Expected %d arguments, got %d',
        current_name, current_nargs, current_passed
      )
    end

    if next_pos then
      list.extend(
        current_args,
        list.slice(args, current_pos + 1, next_pos - 1)
      )
    else
      list.extend(
        current_args,
        list.slice(args, current_pos + 1, n)
      )
    end
  end

  return withindex
end

---@return KeywordArgument[]
function Argparser:keyword_arguments_list()
  local names = list.sort(dict.keys(self.keyword_arguments))
  return list.map(names, function(name)
    return self.keyword_arguments[name]
  end)
end

function Argparser:print_help(maxwidth)
  print(self:create_help(maxwidth))
end

function Argparser:print_help_and_exit(maxwidth, msg)
  if msg then
    print(self:create_help(maxwidth) .. '\n' .. msg)
  else
    print(self:create_help(maxwidth))
  end
  os.exit(0)
end

function Argparser:create_inline_help()
  local final = { 'Usage:', self.filename }
  list.extend(
    final,
    list.map(self.positional_arguments, function(pos)
      return pos:create_inline_help()
    end),
    list.map(self:keyword_arguments_list(), function(kw)
      return kw:create_inline_help(true)
    end)
  )
  final = table.concat(final, " ")
  return final
end

function Argparser:create_help(maxwidth)
  local header = self:create_inline_help()
  local final = { header, self.description }

  if #self.positional_arguments > 0 then
    final[#final + 1] = ''
    final[#final + 1] = "Positional arguments:"
  end

  list.extend(final, list.map(
    self.positional_arguments,
    function(pos)
      return pos:create_help(maxwidth)
    end
  ))

  if #final > 2 then
    final[#final + 1] = ""
  end

  local kws = self:keyword_arguments_list()
  if #kws > 0 then
    final[#final + 1] = "Keyword arguments:"
  end

  list.extend(final, list.map(kws, function(kw)
    return kw:create_help(maxwidth)
  end))

  return table.concat(final, "\n")
end

---Parse positional arguments if any and return the rest
---@param positional_args string[]
---@return string[]
function Argparser:_parse_positional_arguments(positional_args)
  local n_positional = #self.positional_arguments
  if n_positional == 0 then
    return positional_args
  end

  local n_positional_args = #positional_args
  local rest_args = list.slice(
    positional_args,
    n_positional + 1, n_positional_args
  )
  local args = list.slice(positional_args, 1, n_positional) or {}
  list.each(self.positional_arguments, function(i, spec)
    spec.value = args[i]
    spec:parse()
  end, true)

  return rest_args or {}
end

---Parse keyword and positional arguments and return the rest
---@param args string[]
---@return string[]
function Argparser:_parse(args, maxwidth)
  args = args or self.args or arg
  local sep_pos = list.index1(args, "--")
  local positional = {}

  if sep_pos then
    positional = list.slice(args, sep_pos + 1, #args)
    args = list.slice(args, 1, sep_pos - 1)
  end

  local index = self:_find_keyword_arguments(args, maxwidth)
  local n = #index

  if #index == 0 then
    return self:_parse_positional_arguments(positional)
  else
    local first = index[1]
    if first.pos > 1 then
      list.lextend(
        positional,
        list.slice(args, 1, first.pos - 1)
      )
    end
  end

  if n > 1 then
    for i = 1, n - 1 do
      index[i].spec:parse()
    end
  end

  local last = index[n].spec
  local last_args = last.args
  local last_n = #last_args
  local nargs = last.nargs

  if nargs == "?" and last_n > 1 then
    last.args = { last_args[1] }
    list.extend(positional, list.slice(last_args, 2, last_n))
  elseif type(nargs) == 'number' and last_n > nargs then
    last.args = list.slice(last_args, 1, nargs)
    list.extend(positional, list.slice(last_args, nargs + 1, last_n))
  end

  last:parse()
  return self:_parse_positional_arguments(positional)
end

function Argparser:parse(args, maxwidth)
  local rest = self:_parse(args, maxwidth)
  local kwargs = {}
  local pos = {}

  for _, kw in pairs(self.keyword_arguments) do
    local name = kw.name
    name = name:gsub('-', '_')
    if kw.times_passed > 0 then
      kwargs[name] = kw.args
    elseif kw.default then
      kwargs[name] = totable(kw.default())
    end
  end

  for i = 1, #self.positional_arguments do
    local x = self.positional_arguments[i]
    local name = x.name

    if type(name) == 'string' then
      pos[name:gsub('-', '_')] = x.value
    end
  end

  self.parsed.arguments = rest
  self.parsed.keyword_arguments = kwargs
  self.parsed.positional_arguments = pos
  self.parsed.args = rest
  self.parsed.K = kwargs
  self.parsed.P = pos

  return self.parsed
end

return Argparser
