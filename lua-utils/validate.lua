require 'lua-utils.utils'

---@alias validate.valid_type guard.valid_type

---@class validate.pair
---@field [1] validate.valid_type
---@field [2]? any
---@field type? validate.valid_type
---@field value? any

---@alias validate.spec table<string,validate.pair>

---@type table
local validate = defmodule('validate')

---@param key string
---@param prefix? string
---@return boolean, (string|number)?
local function is_opt_key(key, prefix)
  prefix = prefix or '<root>'
  if type(key) == 'number' then
    return false, key
  end

  local ok = (key:match('^%?') or key:match('%?$') or key:match('^opt_')) ~= nil
  if not ok then
    return false, key
  end

  key = key:gsub('%?', ''):gsub('^opt_', '')
  if #key == 0 then
    errorf("%s: ['']: key length is zero", prefix)
  end

  return ok, key
end

local function throw(prefix, msg)
  errorf('%s: %s', prefix, msg)
end

---@param x any
local function should_recurse(x, prefix)
  if not is_pure_table(x) then
    throw(prefix, sprintf('Expected pure_table, got [%s] %s', type(x), x))
  end
end

---@param opt boolean
---@param key string
---@param value any
---@param spec validate.valid_type
---@param prefix? string
local function check(opt, key, value, spec, prefix)
  if is_pure_table(spec) then
    should_recurse(value, prefix)

    for spec_key, spec_value in pairs(spec) do
      ::next::
      spec_opt, spec_key = is_opt_key(spec_key)
      local v = value[spec_key]

      if v == nil and spec_opt then
        goto next
      end

      if type(spec_key) == 'number' then
        check(
          spec_opt, spec_key, v, spec_value,
          prefix .. '[' .. tostring(spec_key) .. ']'
        )
      else
        check(
          spec_opt, spec_key, v, spec_value,
          prefix .. '.' .. key
        )
      end
    end
  elseif opt and value == nil then
    return true, nil
  else
    local ok, msg = is(value, spec, { prefix = prefix, assert = true })
    if not ok then error(msg) end
  end
end

function validate:__call(specs)
  for key, spec in pairs(specs) do
    local validator, obj = spec[1] or spec.type, spec[2] or spec.value
    local is_opt
    is_opt, key = is_opt_key(key)

    if is_opt and obj == nil then
      return true
    else
      check(is_opt, key, obj, validator, key)
    end
  end

  return true
end

function validate:__index(name)
  return function(obj, validator)
    validate { [name] = { type = validator, value = obj } }
  end
end

-- validate {
--   display = {type = {{'number'}}, value = {{'a'}}}
-- }

return validate
