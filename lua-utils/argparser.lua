--- @class Argparser.Positional
--- @field name string|number
--- @field post function
--- @field assert function
--- @field help string
--- @field default function
--- @field arg any
--- @field type string
--- @field required boolean

--- @class Argparser.Option
--- @field name string
--- @field long string
--- @field short string
--- @field index number
--- @field post function
--- @field assert function
--- @field nargs number|string
--- @field help string
--- @field default function
--- @field args any[]
--- @field type string
--- @field required boolean
--- @field pos boolean is switch positional?

--- @class Argparser
--- @field args string[]
--- @field desc string
--- @field summary string
--- @field options table<string,Argparser.Option>
--- @field required table<string,Argparser.Option>
--- @field positional table<string,Argparser.Option>
--- @field optional table<string,Argparser.Option>

--- @type Argparser
--- @overload fun(string, string): Argparser
local Argparser = class "Argparser"
Argparser.Option = class "Argparser.Option"
Argparser.Positional = class "Argparser.Positional"

--- @type Argparser.Option
--- @overload fun(table): Argparser.Option
local Option = Argparser.Option

--- @type Argparser.Positional
--- @overload fun(table): Argparser.Positional
local Positional = Argparser.Positional

function Positional:init(specs)
  params {
    specs = {
      {
        ["name?"] = union("string", "number"),
        ["post?"] = "callable",
        ["assert?"] = "callable",
        ["help?"] = "string",
        ["args?"] = "table",
        ["default?"] = "callable",
        ["type?"] = "string",
        ["required?"] = "boolean",
        ["pos?"] = "boolean",
        ["metavar?"] = "string",
      },
      specs,
    },
  }

  specs.type = specs.type or "string"
  specs.help = specs.help or ""
  specs.metavar = specs.metavar or specs.type:upper()

  return dict.merge(self, { specs })
end

function Option:init(specs)
  params {
    specs = {
      {
        ["metavar?"] = "string",
        ["nargs?"] = union("string", "number"),
        ["name?"] = "string",
        ["short?"] = "string",
        ["long?"] = "string",
        ["index?"] = "number",
        ["post?"] = "callable",
        ["assert?"] = "callable",
        ["help?"] = "string",
        ["args?"] = "table",
        ["default?"] = "callable",
        ["type?"] = "string",
        ["required?"] = "boolean",
        ["pos?"] = "boolean",
      },
      specs,
    },
  }

  specs.name = specs.name or specs.long
  specs.type = specs.type or "string"
  specs.help = specs.help or ""
  specs.metavar = specs.metavar or specs.type:upper()
  specs.nargs = specs.nargs or 0

  return dict.merge(self, { specs })
end

function Argparser:init(desc, short_desc)
  self.parsed = {}
  self.args = arg or {}
  self.header = desc
  self.summary = short_desc
  self.options = {}
  self.required = {}
  self.optional = {}
  self.positional = {}
  self.options = {}

  return self
end

function Argparser:on_positional(switch)
  switch = Argparser.Positional(switch)
  self.positional[#self.positional + 1] = switch

  return switch
end

function Argparser:on_optional(switch)
  switch = Argparser.Option(switch)
  switch.required = false
  self.optional[switch.name] = switch
  self.options[switch.name] = switch

  return switch
end

function Argparser:on_required(switch)
  switch = Argparser.Option(switch)
  self.required[switch.name] = switch
  self.options[switch.name] = switch

  return switch
end

function Argparser:on(switch)
  if switch.pos then
    self:on_positional(switch)
  elseif switch.required then
    self:on_required(switch)
  else
    self:on_optional(switch)
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
    local all = list.extend(long_index, { short_index })
    opt.index = all

    list.each(all, function(x)
      list.append(withindex, { { x, name } })
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
  local index = self:_findindex(args)
  local last, first

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
      use.args = list.extend(use.args, { passed })
    end
  end

  last = self.options[last]
  local name = last.name
  local givenargs = last.args
  local nargs = last.nargs
  local passed = #givenargs
  local tail

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
      tail = list.sub(givenargs --[[@as list]], nargs + 1, -1)
      last.args = list.sub(givenargs --[[@as list]], 1, nargs)
    end
  end

  first = self.options[first]
  local head = {}

  if first ~= last then
    if first.index[1] ~= 1 then
      ---@diagnostic disable-next-line: cast-local-type
      head = list.sub(args --[[@as list]], 1, first.index[1] - 1)
    end
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  local positional = list.extend(head, { { tail } })
  for i = 1, #positional do
    if not self.positional[i] then
      self.positional[i] = Argparser.Positional { name = i }
    end
  end

  list.eachi(self.positional, function(i, opt)
    local out = args[i]

    if opt.required and out == nil then
      error(opt.name .. ": missing positional arg " .. i)
    end

    local claim = opt.assert
    local post = opt.post
    opt.arg = positional[i]

    if post then
      opt.arg = post(opt.arg)
    end

    if claim then
      local ok, msg = claim(opt.arg)

      if not ok then
        if msg then
          msg = opt.name .. ": " .. msg
        else
          msg = opt.name .. ": validation failure"
        end

        error(msg)
      end
    end
  end)

  local parsed = {}
  local pos = {}

  dict.each(self.required, function(_name, switch)
    validateargs(switch)
    parsed[_name:gsub("-", "_")] = switch.args
  end)

  dict.each(self.optional, function(_, switch)
    validateargs(switch)
    parsed[name:gsub("-", "_")] = switch.args
  end)

  list.eachi(self.positional, function(i, switch)
    name = switch.name
    if is_number(name) then
      pos[name] = switch.arg
    else
      pos[name:gsub("-", "_")] = switch.arg
    end

    if not pos[i] then
      pos[i] = switch.arg
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

local function wrap_lines(full_name, help)
  local maxlen = 30
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

  return join(totalhelp, "")
end

function Argparser.Option:tostring()
  local metavar, long, short, required, nargs, help, name
  help = self.help or ""
  metavar = self.metavar or "STR"
  long = self.long
  short = self.short
  required = self.required
  nargs = tostring(self.nargs)
  short = short and "-" .. short
  long = long and "--" .. long
  name = (long and short) and short .. ", " .. long or short or long

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

  return wrap_lines(name, help)
end

function Argparser.Positional:tostring()
  --- similar to above algo
end

function Argparser:tostring()
  local header = self.header
  local summary = self.summary
  local scriptname
  do
    local str = debug.getinfo(2, "S").source:sub(2)
    scriptname = str:match "^.*/(.*).lua$" or str
  end

  local usage = {
    scriptname .. ": " .. summary or "",
    header or "",
    "",
  }

  if #self.positional > 0 then
    list.append(usage, { "Positional arguments:" })

    local names = list.map(self.positional, function(opt)
      return {
        opt.name,
        opt.type,
        opt.required or false,
        opt.help or "",
      }
    end)
    names = list.sort(names, function(a, b)
      return #a[1] < #b[1]
    end)
    local longest = names[#names]
    local longestlen = #longest

    list.each(names, function(name)
      local _name, _type, _required, _help = unpack(name)
      local fmt = "%-" .. longestlen .. "s"

      if _required then
        fmt = fmt .. sprintf(" %-10s", sprintf(" {%s}:", _type))
      else
        fmt = fmt .. sprintf(" %-10s", sprintf(" [%s]:", _type))
      end

      fmt = fmt .. " " .. _help
      fmt = sprintf(fmt, _name)

      list.append(usage, { fmt })
    end)

    print(concat(usage, "\n"))
  end
end

local s = "1 2 3 4 --name 1 -a 2 --name 2 3 4 10 --b-name 1 2 3 4 5 -b -1"
local parser = Argparser("Hello world", "!")
parser.args = strsplit(s, " ")

parser:on {
  short = "a",
  long = "name",
  help = "please print something here or else i will die of not getting attention",
  nargs = "*",
}

parser:on {
  required = false,
  short = "b",
  long = "b-name",
  post = tonumber,
  nargs = 1,
}

parser:on {
  pos = true,
  name = "X",
  post = tonumber,
  help = "this is X",
  type = "number",
  required = true,
}

parser:on {
  pos = true,
  name = "Y",
  post = tonumber,
  help = "this is Y",
  type = "number",
  required = true,
}

-- pp(parser:parse())
-- print(parser.optional["b-name"]:tostring())
