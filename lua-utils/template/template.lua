require 'lua-utils.string'
require 'lua-utils.utils'
local dict = require 'lua-utils.dict'
local class = require 'lua-utils.class'
local validate = require 'lua-utils.validate'
local placeholder = require 'lua-utils.template.placeholder'

---Simple string interpolation with python-like curly braces
---@class template
---@field string string
---@field placeholders? table<string,any>
---@field utils table<string,function>
---@overload fun(s: string, placeholders?: table)
local template = class 'template'
template.utils = placeholder

function template:initialize(s, placeholders)
  self.string = s
  self.placeholders = placeholders or {}
end

---Add a new placeholder definition
---@param name string
---@param replacement string
function template:add_placeholder(name, replacement)
  self.placeholders[name] = replacement
end

---Add new placeholders in a dict
---@param placeholders table<string,any>
function template:add_placeholders(placeholders)
  dict.force_merge(self.placeholders, placeholders)
end

---Add new placeholder(s)
---@overload fun(name: string, replacement: string)
---@overload fun(placeholders: table<string,any>)
function template:P(...)
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
function template:parse()
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

---Substitute placeholders in a template string directly
---Usage: ("before {placeholder} after"):template {placeholder = "value"}
---@param s string
---@param replacements table<string, string>
function string.template(s, replacements)
  local templ = template(s, replacements)
  return templ:parse()
end

return template
