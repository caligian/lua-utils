require "lua-utils.string"
require "lua-utils.table"
require "lua-utils.form"

local function get_script_name()
  return debug.getinfo(2, "S").source:sub(2):match "^.+/([^$]+)$"
end

--- @class Argparser
--- @field args string[]
--- @field desc string
--- @field summary string
--- @field options table<string,Argparser.Option>
--- @field required table<string,Argparser.Option>
--- @field positional table<string,Argparser.Option>
--- @field optional table<string,Argparser.Option>
--- @overload fun(string, string): Argparser
local Argparser = class "Argparser"

--- @class Argparser.Option
--- @field name? string
--- @field long? string
--- @field short? string
--- @field index? number
--- @field post? function
--- @field assert? function
--- @field nargs? number|string
--- @field help? string
--- @field default? function
--- @field args? any[]
--- @field metavar? string
--- @field required? boolean
--- @overload fun(table): Argparser.Option
Argparser.Option = class "Argparser.Option"

--- @class Argparser.Positional
--- @field name? string|number
--- @field post? function
--- @field assert? function
--- @field help? string
--- @field default? function
--- @field args? any[]
--- @field required? boolean
--- @field metavar? string
--- @overload fun(table): Argparser.Positional
Argparser.Positional = class "Argparser.Positional"

function Argparser.Positional:init(specs)
  form[{
    ["name?"] = union("string", "number"),
    ["post?"] = "callable",
    ["assert?"] = "callable",
    ["help?"] = union("string", "table"),
    ["args?"] = "table",
    ["default?"] = "callable",
    ["required?"] = "boolean",
    ["positional?"] = "boolean",
    ["metavar?"] = "string",
  }].options(specs)

  assert(specs.name, ".name missing in " .. dump(specs))

  specs.help = specs.help or ""
  specs.metavar = specs.metavar or specs.name:upper()

  return dict.merge(self, specs)
end

function Argparser.Option:init(specs)
  form[{
    ["metavar?"] = "string",
    ["nargs?"] = union("string", "number"),
    ["name?"] = "string",
    ["short?"] = "string",
    ["long?"] = "string",
    ["index?"] = "number",
    ["post?"] = "callable",
    ["assert?"] = "callable",
    ["help?"] = union("string", "table"),
    ["args?"] = "table",
    ["default?"] = "callable",
    ["required?"] = "boolean",
  }].options(specs)

  assert(specs.long or specs.short, ".long or .short missing in " .. dump(specs))

  specs.name = specs.name or specs.long or specs.short
  specs.help = specs.help or ""
  specs.nargs = specs.nargs or 0
  specs.metavar = specs.nargs ~= 0 and (specs.metavar or specs.name:upper()) or ""

  return dict.merge(self, specs)
end

function Argparser:init(desc)
  self.parsed = {}
  self.args = arg or {}
  self.summary = desc
  self.options = {}
  self.required = {}
  self.optional = {}
  self.positional = {}
  self.options = {}

  self:on_optional {
    long = "help",
    short = "h",
    required = false,
    help = "show this help",
  }

  return self
end

function Argparser:on_positional(switch)
  switch = Argparser.Positional(switch)
  self.positional[#self.positional + 1] = switch
  return self
end

function Argparser:on_optional(switch)
  switch = Argparser.Option(switch)
  switch.required = false
  self.optional[switch.name] = switch
  self.options[switch.name] = switch
  return self
end

function Argparser:on_required(switch)
  switch = Argparser.Option(switch)
  self.required[switch.name] = switch
  self.options[switch.name] = switch
  return self
end

function Argparser:on(switch)
  if switch.positional then
    return self:on_positional(switch)
  elseif switch.required then
    return self:on_required(switch)
  else
    return self:on_optional(switch)
  end
end

local function findall(ls, x)
  local out = {}

  for i = 1, #ls do
    if ls[i] == x then
      out[#out + 1] = i
    end
  end

  return out
end

function Argparser:_findindex(args)
  args = args or self.args
  local withindex = {}

  dict.each(self.options, function(name, opt)
    local long_option = opt.long
    local short_option = opt.short
    local long = long_option and "--" .. long_option
    local short = short_option and "-" .. short_option
    local long_index = findall(args, long)
    local short_index = findall(args, short)

    if short_option == "h" and #short_index > 0 then
      print(self:gen_header())
      os.exit(0)
    elseif long_option == "help" and #long_index > 0 then
      print(self:gen_help())
      os.exit(0)
    end

    local all = list.extend(long_index, short_index)
    opt.index = all

    list.each(all, function(x)
      list.append(withindex, { x, name })
    end)
  end)

  return list.sort(withindex, function(a, b)
    return a[1] < b[1]
  end)
end

local function validateargs(switch)
  local name = switch.name
  local args = switch.args
  local nargs = switch.nargs
  local claim = switch.assert
  local post = switch.post
  local passed = #args

  if is_number(nargs) then
    if nargs ~= passed then
      error(name .. ": " .. "expected " .. nargs .. ", got " .. passed)
    end
  elseif nargs == "?" then
    if passed ~= 0 or passed ~= 1 then
      error(name .. ": " .. "expected 1 or 0 args, got " .. passed)
    end
  elseif nargs == "+" then
    if passed == 0 then
      error(name .. ": " .. "expected more than 0 args, got " .. passed)
    end
  end

  if post then
    switch.args = list.map(switch.args, post)
  end

  if claim then
    list.each(switch.args, function(x)
      local ok, msg = claim(x)
      if not ok then
        msg = switch.name .. ": " .. msg
        error(msg)
      end
    end)
  end

  return switch
end

function Argparser:parse(args)
  args = args or self.args
  local till_sep = list.find_value(args, "--")
  local index = self:_findindex(args)
  local last, first, head, tail, after_sep
  head = {}
  tail = {}
  local parsed = {}
  local pos = {}

  if till_sep then
    after_sep = list.sub(args, till_sep + 1, -1)
    args = list.sub(args, 1, till_sep - 1)
  else
    after_sep = {}
  end

  self.args = args

  for i = 1, #index do
    local from, till = index[i], index[i + 1]
    local passed

    if i == 1 then
      first = from[2]
    end

    if not till then
      passed = list.sub(args, from[1] + 1, #args)
      last = from[2]
    else
      passed = list.sub(args, from[1] + 1, till[1] - 1)
    end

    if passed then
      local use = self.options[from[2]]
      use.args = use.args or {}
      use.args = list.extend(use.args, passed)
    end
  end

  last = self.options[last]
  local name = last.name
  local givenargs = last.args
  local nargs = last.nargs
  local passed = #givenargs

  if nargs == "?" then
    if passed ~= 0 and passed ~= 1 then
      error(name .. ": expected 1 or 0 args, got " .. passed)
    elseif passed > nargs then
      tail = list.sub(givenargs --[[@as list]], 2, -1)
      last.args = {
        givenargs--[[@as list]][1],
      }
    end
  elseif nargs == "+" then
    if passed == 0 then
      error(name .. ": expected at least 1 arg, got " .. passed)
    end
  elseif is_number(nargs) then
    if nargs > passed then
      error(name .. ": expected " .. nargs .. ", got " .. passed)
    else
      tail = list.sub(givenargs--[[@as list]], nargs + 1, -1)
      ---@diagnostic disable-next-line
      last.args = list.sub(givenargs, 1, nargs)
    end
  end

  first = self.options[first]
  if first ~= last then
    if first.index[1] ~= 1 then
      ---@diagnostic disable-next-line: cast-local-type
      head = list.sub(args --[[@as list]], 1, first.index[1] - 1)
    end
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  local positional = list.extend(head, tail, after_sep)
  for i = 1, #positional do
    if not self.positional[i] then
      pos[i] = positional[i]
    end
  end

  list.eachi(self.positional, function(i, opt)
    local out = args[i]

    if opt.required and out == nil then
      error(opt.name .. ": missing positional arg " .. i)
    end

    local claim = opt.assert
    local post = opt.post
    local x = positional[i]

    if post then
      x = post(x)
    end

    if claim then
      local ok, msg = claim(x)

      if not ok then
        if msg then
          msg = opt.name .. ": " .. msg
        else
          msg = opt.name .. ": validation failure"
        end

        error(msg)
      end
    end

    pos[i] = x
    parsed[opt.name:gsub('-', '_')] = x
  end)

  dict.each(self.options, function(_name, switch)
    if switch.args then
      validateargs(switch)
      parsed[_name:gsub("-", "_")] = switch.args
    end
  end)

  return pos, parsed
end

--[[

-a                   Print your bloody arse over and here and then eat shit.
--another-flag    

-x STR[+]            this is the description for this option. It will wrap
--long-name STR[+]   wrap when the description is beyond 60 characters

--]]

function Argparser.Positional:gen_header(metavar_only)
  local metavar, required
  metavar = self.metavar
  required = self.required
  local name = self.name

  if metavar_only then
    if required then
      metavar = "{" .. metavar .. "}"
    else
      metavar = "[" .. metavar .. "]"
    end
  elseif required then
    metavar = "{" .. metavar .. "}"
    metavar = name .. " " .. metavar
  else
    metavar = "[" .. metavar .. "]"
    metavar = name .. " " .. metavar
  end

  return metavar, self.help, #metavar
end

function Argparser.Option:gen_header(use_long_also)
  local metavar, required, nargs, name, short, long
  metavar = self.metavar
  required = self.required
  nargs = tostring(self.nargs)
  short = self.short and "-" .. self.short
  long = self.long and "--" .. self.long

  if not use_long_also then
    if short then
      name = short
    else
      name = long
    end
  elseif short and long then
    name = short .. ", " .. long
  else
    name = long
  end

  if nargs ~= "0" and nargs ~= "?" then
    if required then
      metavar = "{" .. metavar .. "=" .. nargs .. "}"
    else
      metavar = "[" .. metavar .. "=" .. nargs .. "]"
    end
  elseif nargs == "?" then
    metavar = "[" .. metavar .. ":?]"
  end

  name = name .. " " .. metavar
  return name, self.help or "", #name
end

--------------------------------------------------
local function get_max(xs)
  local max_len = -1

  for i = 1, #xs do
    local l = xs[i][3]
    if max_len < l then
      max_len = l
    end
  end

  return max_len
end

--- @param prefix string
--- @param desc string
--- @param max? number
local function nlwrap(prefix, desc, max, suffix_nl)
  max = max + 2
  local nl = "\n"
  local ws = " "
  local d = 80
  local too_big = max > d and true or false
  local ws_prefix = string.rep(ws, max)
  local first_ws_prefix = string.rep(ws, max - #prefix)
  local result = {
    prefix,
    too_big and nl or "",
    first_ws_prefix,
  }
  local result_len = 3
  local ctr = #prefix + list.reduce(result, 0, function(x, acc)
    return acc + #x
  end)

  local push = function(x, l)
    result[result_len + 1] = x
    result_len = result_len + 1
    ctr = ctr + (l or #x)
  end

  local function should_break(l)
    if ctr + l > d then
      return true
    end
    return false
  end

  local function wrap_words(x)
    for match in string.gmatch(x, "[^%s]+") do
      local l = #match
      if should_break(l) then
        ctr = 0
        push(nl, 1)
        push(ws_prefix, r)
      end
      push(match, l)
      push(ws, 1)
    end
  end

  desc = totable(desc)
  for i = 1, #desc do
    wrap_words(desc[i])
  end

  if suffix_nl then
    push(nl, 1)
  end

  return join(result, "")
end

local function gen_help_options(parser, maxlen)
  local options = values(parser.options)
  local options_parsed = list.map(options, function(x)
    return { x:gen_header(true) }
  end)
  local max_opt_len = get_max(options_parsed)
  local parsed = list.map(options_parsed, function(state)
    return nlwrap(state[1], state[2], max_opt_len, true)
  end)
  return join(parsed, "\n")
end

local function gen_help_positional(parser, maxlen)
  local positional = values(parser.positional)
  local positional_parsed = list.map(positional, function(x)
    return { x:gen_header(true) }
  end)
  local max_opt_len = get_max(positional_parsed)
  local parsed = list.map(positional_parsed, function(state)
    return nlwrap(state[1], state[2], max_opt_len)
  end)

  return join(parsed, "\n")
end

local function gen_header(parser)
  local positional = values(parser.positional)
  local positional_parsed = list.map(positional, function(x)
    return { x:gen_header(true) }
  end)
  local options = values(parser.options)
  local options_parsed = list.map(options, function(x)
    return { x:gen_header(false) }
  end)
  local script = get_script_name()
  local get_name = function(x)
    return x[1]
  end
  local all_switches = list.map(list.extend(positional_parsed, options_parsed), get_name)

  return nlwrap(script, all_switches, #script)
end

Argparser.gen_header = gen_header

function Argparser:gen_help()
  return join({
    gen_header(self),
    self.summary,
    "",
    "Positional Arguments",
    gen_help_positional(self),
    "",
    "Keyword arguments",
    gen_help_options(self),
  }, "\n")
end

--------------------------------------------------
local s = "1 2 3 4 --name 1 -a 2 --name 2 3 4 10 --b-name 1 2 3 4 5 -b -1 -- extra args"
local parser = Argparser("Hello world", "!")
parser.args = strsplit(s, " ")

parser
  :on({
    short = "a",
    long = "name",
    help = "please print something here or else i will die of not getting attention",
    nargs = "*",
  })
  :on({
    required = true,
    short = "b",
    long = "b-name",
    post = tonumber,
    nargs = 1,
    help = "please print something here or else i will die of not getting attention",
  })
  :on({
    positional = true,
    name = "X",
    post = tonumber,
    help = "this is X",
    required = true,
  })
  :on {
    positional = true,
    name = "Y",
    post = tonumber,
    help = "this is Y",
    required = true,
  }

pp(parser:parse())
-- handle args after --
-- truncate the args till -- and store extra
-- add extra to head args
