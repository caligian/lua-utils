require "lua-utils.string"
local copy = require 'lua-utils.copy'
local dict = require 'lua-utils.dict'
local class = require 'lua-utils.class'
local types = require 'lua-utils.types'
local validate = require 'lua-utils.validate'
local utils = require 'lua-utils.argparser.utils'

---@class PositionalArgument
---@field name? string|number
---@field post? function
---@field assert? function
---@field help? string
---@field default? function
---@field value? any
---@field required? boolean
---@field metavar? string
---@field index? number
---@overload fun(specs: table): PositionalArgument
PositionalArgument = class "PositionalArgument"

function PositionalArgument:initialize(name, specs)
  specs = copy(specs or {})

  validate {
    name = { types.union('string', 'number'), name },
    opt_post = { 'callable', specs.post },
    opt_assert = { 'callable', specs.assert },
    help = { 'string', specs.help },
    opt_default = { 'callable', specs.default },
    opt_required = { 'boolean', specs.required },
    opt_pos = { 'boolean', specs.pos },
    opt_metavar = { 'string', specs.metavar }
  }

  specs.name = name
  specs.help = specs.help or ""
  specs.metavar = specs.metavar or tostring(specs.name):upper()

  dict.merge(self, specs)
end

function PositionalArgument:validate()
  if self.assert then
    local ok, msg = self.assert(self.value)
    if not ok then
      utils.print_and_exit('<positional>%s: %s', self.name, msg)
    end
  end

  return true
end

function PositionalArgument:parse(opts)
  opts = opts or {}
  local skip_validation = opts.skip_validation
  local skip_post = opts.skip_post

  if not self.required and self.value == nil then
    return self
  end

  if self.post and not skip_post then
    self.value = self.post(self.value)
  end

  if self.assert and not skip_validation then
    self:validate()
  end

  return self
end

function PositionalArgument:create_inline_help()
  if self.required then
    return self.name
  else
    return sprintf('%s?', self.name)
  end
end

function PositionalArgument:create_help(maxwidth)
  return utils.create_help(self.name, self.help, maxwidth)
end

return PositionalArgument
