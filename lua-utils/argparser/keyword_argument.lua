require "lua-utils.string"
local copy = require 'lua-utils.copy'
local list = require "lua-utils.list"
local dict = require 'lua-utils.dict'
local class = require 'lua-utils.class'
local types = require 'lua-utils.types'
local validate = require 'lua-utils.validate'
local utils = require 'lua-utils.argparser.utils'

local KeywordArgument = class 'KeywordArgument'

---@class KeywordArgument
---@field name? string
---@field long_name? string
---@field short_name? string
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
---@overload fun(specs: table): KeywordArgument
KeywordArgument = class "KeywordArgument"

function KeywordArgument:initialize(short_name, long_name, specs)
  specs = specs or {}
  specs = copy(specs)
  dict.set_unless(specs, {'nargs'}, 0)
  dict.set_unless(specs, {'required'}, false)
  dict.set_unless(specs, {'duplicate'}, false)
  dict.set_unless(specs, {'metavar'}, 'ARGUMENT')

  validate {
    opt_metavar = { "string", specs.metavar },
    opt_nargs = { types.union("string", "number"), specs.nargs },
    opt_short_name = { "string", short_name },
    opt_long_name = { "string", long_name },
    opt_index = { "number", specs.index },
    opt_post = { "callable", specs.post },
    opt_assert = { "callable", specs.assert },
    help = { "string", specs.help },
    opt_args = { "table", specs.args },
    opt_default = { "callable", specs.default },
    opt_required = { "boolean", specs.required },
  }

  assert(
    long_name or short_name,
    sprintf(".long or .short expected in %s", specs)
  )

  specs.short_name = short_name
  specs.long_name = long_name
  specs.name = specs.name or long_name or short_name
  specs.help = specs.help or ""
  specs.metavar = specs.metavar or specs.name:upper()
  specs.nargs = specs.nargs or 0
  specs.times_passed = 0
  specs.args = specs.args or {}

  dict.merge(self, specs, true)
end

function KeywordArgument:assert_nargs()
  return utils.assert_nargs(self.name, self.args, self.nargs)
end


function KeywordArgument:assert()
  return utils.assert(self.name, self.args, self.assert)
end

KeywordArgument.validate = KeywordArgument.assert

function KeywordArgument:parse(opts)
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

function KeywordArgument:create_inline_help(header)
  local short = self.short_name
  local long = self.long_name
  local name = self.name
  local metavar = utils.format_metavar(self.metavar, self.nargs)

  if header then
    local show

    if short then
      name = '-' .. short
    elseif long then
      name = '--' .. long
    end

    if not self.required then
      name = name .. '?'
    end

    if #metavar == 0 then
      show = name
    else
      show = name .. ' ' .. metavar
    end

    return show
  end

  if not self.required then
    short = short and short .. '?'
    long = long and long .. '?'
  end

  if #metavar > 0 then
    if short and long then
      return sprintf('-%s, --%s %s', short, long, metavar)
    elseif short then
      return sprintf('-%s %s', short, metavar)
    else
      return sprintf('--%s %s', long, metavar)
    end
  else
    if short and long then
      return sprintf('-%s, --%s', short, long)
    elseif short then
      return '-' .. short
    else
      return '--' .. long
    end
  end
end


function KeywordArgument:create_help(maxwidth)
  if not self.help or #self.help == 0 then
    return self:create_inline_help()
  else
    return utils.create_help(
      self:create_inline_help(false),
      self.help,
      maxwidth
    )
  end
end

return KeywordArgument
