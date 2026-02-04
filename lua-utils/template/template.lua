require 'lua-utils.string'
require 'lua-utils.utils'
local dict = require 'lua-utils.dict'
local class = require 'lua-utils.class'
local validate = require 'lua-utils.validate'
local placeholder = require 'lua-utils.template.placeholder'

---Simple string interpolation with python-like curly braces
---@class Template
---@field string string
---@field placeholders? table<string,any>
---@field utils table<string,function>
---@overload fun(s: string, placeholders?: table)
local Template = class 'Template'
Template.utils = placeholder

function Template:initialize(s, placeholders)
  self.string = s
  self.placeholders = placeholders or {}
end

---Add a new placeholder definition
---@param name string
---@param replacement string
function Template:add_placeholder(name, replacement)
  self.placeholders[name] = replacement
end

---Add new placeholders in a dict
---@param placeholders table<string,any>
function Template:add_placeholders(placeholders)
  dict.force_merge(self.placeholders, placeholders)
end

---Add new placeholder(s)
---@overload fun(name: string, replacement: string)
---@overload fun(placeholders: table<string,any>)
function Template:P(...)
  local args = {...}
  if #args == 2 then
    self:add_placeholder(unpack(args))
  else
    validate.placeholders(args[1], 'table')
    self:add_placeholders(args[1])
  end
end

---Parse the string and substitute placeholders with their values
---@return string
function Template:parse()
  placeholders = placeholders or {}
  placeholders = dict.merge(placeholders, self.placeholders)
  local s = self.string
  local res = placeholder.next(s, 1)

  if not res.next then
    return res.string
  end

  local final = {}
  local final_l = 0
  local push = function (x)
    final[final_l+1] = x
    final_l = final_l + 1
  end

  while res.next do
    local before = res.before
    local p = res.placeholder
    local replacement = placeholders[p]

    if replacement == nil then
      errorf('%s: Placeholder is undefined', p)
    end

    push(before)
    push(replacement)

    res = placeholder.next(s, res.next)
  end

  return table.concat(final, "")
end

---Import template into global space
function Template:import()
  _G.Template = self
end

return Template
