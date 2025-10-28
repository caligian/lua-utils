require "lua-utils.string"
local copy = require 'lua-utils.copy'
local list = require "lua-utils.list"
local dict = require 'lua-utils.dict'
local class = require 'lua-utils.class'
local types = require 'lua-utils.types'
local validate = require 'lua-utils.validate'
local sys = require 'system'

local function get_term_width(default)
  default = default or 50
  local nrow, ncol = sys.termsize()
  if nrow == nil then
    return default
  else
    return ncol
  end
end

local function print_exit(msg, ...)
  printf(msg, ...)
  os.exit(1)
end

---@class Argparser
---@field args string[]
---@field desc string
---@field summary string
---@field options table<string,Argparser.Keyword>
---@field required table<string,Argparser.Keyword>
---@field positional table<string,Argparser.Keyword>
---@field optional table<string,Argparser.Keyword>
---@overload fun(desc: string, short_desc: string): Argparser
local Argparser = class "Argparser"

---@class Argparser.Keyword
---@field name? string
---@field long? string
---@field short? string
---@field index? number
---@field post? function
---@field assert? function
---@field nargs? number|string
---@field help? string
---@field default? function
---@field args? any[]
---@field metavar? string
---@field required? boolean
---@field duplicate? boolean (default: true)
---@field times_passed number
---@overload fun(specs: table): Argparser.Keyword
Argparser.Keyword = class "Argparser.Keyword"

---@class Argparser.Positional
---@field name? string|number
---@field post? function
---@field assert? function
---@field help? string
---@field default? function
---@field value? any
---@field required? boolean
---@field metavar? string
---@overload fun(specs: table): Argparser.Positional
Argparser.Positional = class "Argparser.Positional"

function Argparser.Positional:initialize(specs)
  specs = copy(specs or {})

  validate {
    name = { types.union('string', 'number'), specs.name },
    opt_post = { 'callable', specs.post },
    opt_assert = { 'callable', specs.assert },
    opt_help = { 'string', specs.help },
    opt_default = { 'callable', specs.default },
    opt_required = { 'boolean', specs.required },
    opt_pos = { 'boolean', specs.pos },
    opt_metavar = { 'string', specs.metavar }
  }

  specs.help = specs.help or ""
  specs.metavar = specs.metavar or tostring(specs.name):upper()

  dict.merge(self, specs)
end

function Argparser.Positional:parse()
  if not self.required and self.value == nil then
    return self
  end

  local name = tostring(self.name)
  local value = self.value
  local claim = self.assert
  local post = self.post

  if post then
    self.value = post(value)
  end

  if claim then
    local ok, msg = claim(value)
    if not ok then
      print_exit('<positional>%s: %s', name, msg)
    end
  end

  return self
end

function Argparser.Keyword:initialize(specs)
  validate {
    opt_metavar = { "string", specs.metavar },
    opt_nargs = { types.union("string", "number"), specs.nargs },
    opt_short = { "string", specs.short },
    opt_long = { "string", specs.long },
    opt_index = { "number", specs.index },
    opt_post = { "callable", specs.post },
    opt_assert = { "callable", specs.assert },
    opt_help = { "string", specs.help },
    opt_args = { "table", specs.args },
    opt_default = { "callable", specs.default },
    opt_required = { "boolean", specs.required },
  }

  assert(
    specs.long or specs.short,
    sprintf(".long or .short expected in %s", specs)
  )

  specs = copy(specs)
  specs.name = specs.name or specs.long or specs.short
  specs.help = specs.help or ""
  specs.metavar = specs.metavar or specs.name:upper()
  specs.nargs = specs.nargs or 0
  specs.times_passed = 0
  specs.args = {}

  dict.merge(self, specs)
end

function Argparser.Keyword:assert_nargs()
  local name = self.name
  local args = self.args
  local nargs = self.nargs
  local passed = #args

  if types.number(nargs) then
    if nargs ~= passed then
      print_exit(
        '<keyword>%s: Expected %d, got %d arguments',
        name, nargs, passed
      )
    end
  elseif nargs == "?" then
    if passed ~= 0 or passed ~= 1 then
      print_exit(
        '<keyword>%s: Expected 1 or 0 arguments, got %d arguments',
        name, passed
      )
    end
  elseif nargs == "+" then
    if passed == 0 then
      print_exit(
        '<keyword>%s: Expected more than 1 argument, got %d arguments',
        name, passed
      )
    end
  end
end

function Argparser.Keyword:validate()
  local args = self.args
  local claim = self.assert

  if claim then
    list.each(args, function(x)
      local ok, msg = claim(x)
      if not ok then
        msg = '<keyword>' .. self.name .. ": " .. msg
        error(msg)
      end
    end)
  end
end

function Argparser.Keyword:parse(opts)
  opts = opts or {}
  local skip_nargs = opts.skip_nargs
  local skip_validation = opts.skip_validation
  local skip_post = opts.skip_post

  if not skip_nargs then
    self:assert_nargs()
  end

  if not skip_validation then
    self:validate()
  end

  if not skip_post and self.post then
    self.args = list.map(self.args, self.post)
  end

  return self
end

function Argparser:initialize(desc, short_desc)
  self.parsed = {}
  self.args = arg or {}
  self.header = desc
  self.summary = short_desc
  self.keyword_arguments = {}
  self.required = {}
  self.optional = {}
  self.positional_arguments = {}
  self.keyword_arguments = {}
  self:add_keyword_argument('h', 'help', {
    required = false,
    help = "show this help",
  })

  return self
end

function Argparser:add_keyword_argument(short_name, long_name, spec)
  spec = copy(spec or {})
  spec.short = short_name
  spec.long = long_name
  local arg = Argparser.Keyword(spec)
  self.keyword_arguments[arg.name] = arg

  return arg
end

Argparser.K = Argparser.add_keyword_argument

function Argparser:add_positional_argument(name, spec)
  spec = copy(spec or {})
  local pos = #self.positional_arguments + 1
  spec.index = pos
  spec.name = name or pos
  local arg = Argparser.Positional(spec)
  self.positional_arguments[pos] = arg

  return arg
end

Argparser.P = Argparser.add_positional_argument

function Argparser:_find_keyword_arguments(args)
  local findall = function(ls, x)
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
    local long_option = specs.long
    local short_option = specs.short
    local long = long_option and "--" .. long_option
    local short = short_option and "-" .. short_option
    local long_index = findall(args, long)
    local short_index = findall(args, short)
    local all = list.extend(long_index, short_index)
    specs.index = all
    specs.times_passed = #all

    if long_option == "help" and specs.times_passed > 0 then
      print(self:tostring())
      os.exit(0)
    end

    if specs.times_passed == 0 and specs.required then
      print_exit('<keyword>%s: Required but not passed', name)
    end

    if #all > 1 and not specs.duplicate then
      print_exit('<keyword>%s: No duplicates allowed', name)
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
      print_exit(
        '<keyword>%s: Expected 1 or 0 arguments, got %d',
        current_name, current_passed
      )
    elseif
        type(current_nargs) == 'number' and current_passed > current_nargs
    then
      print_exit(
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
function Argparser:_parse(args)
  args = args or self.args
  local sep_pos = list.index(args, "--")[1]
  local positional = {}

  if sep_pos then
    positional = list.slice(args, sep_pos + 1, #args)
    args = list.slice(args, 1, sep_pos - 1)
  end

  local index = self:_find_keyword_arguments(args)
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

local function wrap_lines(full_name, help, maxlen)
  maxlen = get_term_width(maxlen)
  local optlen = #full_name
  local totalhelp = { full_name }

  if optlen > maxlen then
    totalhelp[#totalhelp + 1] = "\n"
    totalhelp[#totalhelp + 1] = string.rep(" ", maxlen)
  else
    totalhelp[#totalhelp + 1] = string.rep(" ", maxlen - optlen)
  end

  local ctr = 0
  for value in string.gmatch(help, "[^%s]+") do
    if ctr > maxlen then
      ctr = 0
      totalhelp[#totalhelp + 1] = "\n" .. string.rep(" ", maxlen + 1)
    else
      ctr = ctr + #value
      totalhelp[#totalhelp + 1] = " "
    end

    totalhelp[#totalhelp + 1] = value
  end

  return list.join(totalhelp, "")
end

function Argparser.Positional:tostring(maxlen)
  local metavar, required, help, name
  help = self.help or ""
  metavar = self.metavar
  name = self.name
  required = self.required

  if required then
    metavar = "{" .. metavar .. "}"
  else
    metavar = "[" .. metavar .. "]"
  end

  name = name .. " " .. metavar

  return wrap_lines(name, help, maxlen)
end

function Argparser.Keyword:tostring(maxlen)
  local metavar, required, nargs, help, name
  help = self.help or ""
  metavar = self.metavar
  required = self.required
  nargs = tostring(self.nargs)
  short = self.short and "-" .. self.short
  long = self.long and "--" .. self.long
  name = (long and short) and short .. ", " .. long
      or short
      or long

  if nargs ~= "0" and nargs ~= "?" then
    if required then
      metavar = "{" .. metavar .. "}"
    else
      metavar = "[" .. metavar .. "]"
    end

    name = name .. " " .. metavar .. "<" .. nargs .. ">"
  elseif nargs == "?" then
    metavar = "[" .. metavar .. "]<1>"
    name = name .. " " .. metavar
  end

  return wrap_lines(name, help, maxlen)
end

function Argparser:tostring(maxlen)
  local header = self.header
  local summary = self.summary
  local scriptname
  do
    local str = debug.getinfo(2, "S").source:sub(2)
    scriptname = str:match "^.*/(.*).lua$" or str
  end

  local usage = {
    (scriptname .. ": " .. summary) or "",
    header or "",
    "",
  }

  local pos_set
  if #self.positional_arguments > 0 then
    list.append(usage, "Positional Arguments:")
    list.extend(
      usage,
      list.map(self.positional_arguments, function(x)
        return x:tostring(maxlen)
      end)
    )
    pos_set = true
  end

  if dict.size(self.keyword_arguments) > 0 then
    if pos_set then
      list.append(usage, "")
    end

    list.append(usage, "Keyword Arguments:")
    list.extend(
      usage,
      list.map(dict.values(self.keyword_arguments), function(x)
        return x:tostring(maxlen)
      end)
    )
  end

  return list.join(usage, "\n")
end

function Argparser:parse(args)
  local rest = self:_parse(args)
  local kwargs = {}
  local pos = {}

  for _, kw in pairs(self.keyword_arguments) do
    local name = kw.name
    name = name:gsub('-', '_')
    kwargs[name] = kw.args
  end

  for i=1, #self.positional_arguments do
    local x = self.positional_arguments[i]
    local name = x.name

    if type(name) == 'string' then
      pos[name:gsub('-', '_')] = x.value
    end
  end

  return rest, pos, kwargs
end

--
-- local s =
-- "1 2 3 4 --name 1 -a 2 --name 2 3 4 10 --b-name 4 5 6"
-- local parser = Argparser("Hello world", "!")
-- parser.args = string.split(s, " ")
--
-- parser:K('a', 'name', {
--   help = "please print something here or else i will die of not getting attention",
--   nargs = "*",
--   required = true,
--   duplicate = true,
-- })
--
-- parser:K('b', 'b-name', {
--   help = "please print something here or else i will die of not getting attention",
--   nargs = 1,
--   required = true,
--   post = tonumber,
--   duplicate = false
-- })
--
-- parser:P('x')
--
-- pp(parser:parse())
--
return Argparser
