require 'lua-utils.dump'

local dict = require('lua-utils.dict')
local types = require('lua-utils.types')
local is = require 'lua-utils.is'

---@overload fun(specs: table<string,table<any,any>>): nil
local validate = {}
setmetatable(validate, validate)

---@param key string
---@param prefix? string
---@return boolean, (string|number)?
function validate.is_opt_key(key, prefix)
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
    if prefix then
      errorf("%s['']: Key length is zero", prefix)
    else
      error("['']: Key length is zero")
    end
  end

  return ok, key
end

---@param x table
---@param key string|number
---@param prefix? string
function validate.value(x, key, prefix, specs)
  local is_opt
  prefix = prefix or '<root>'
  is_opt, key = validate.is_opt_key(key, prefix)
  local display = sprintf('%s.%s', prefix, tostring(key))
  local t_x = types.type(x)

  if is_opt and x == nil then
    return
  elseif x == specs then
    return
  end

  if is.string(specs) then
    if is.object(x) then
      local ok = x.__name == specs
      if not ok then
        errorf("%s: Expected %s[%s], got %s", display, specs, types.type(specs), x.__name)
      end
    elseif types[specs] then
      local ok, msg = types[specs](x)
      if not ok then
        errorf('%s: %s', display, msg)
      end
    else
      if t_x ~= specs then
        errorf('%s: Expected %s[%s], got %s', display, specs, types.type(specs), t_x)
      end
    end
  elseif is.fun(specs) then
    local ok, msg = specs(x)
    if not ok then
      msg = msg or sprintf('Assertion failed for %s', x)
      errorf('%s: %s', display, msg)
    end
  elseif is.object(specs) then
    local t_specs = x.__name
    if is.object(x) then
      local ok, _ = x:isa(specs)
      if not ok then
        errorf('%s: Expected %s, got %s', display, t_specs, t_x)
      end
    elseif t_specs == t_x then
      return
    else
      errorf("%s: Expected %s, got %s", display, t_specs, t_x)
    end
  else
    local t_specs = types.type(specs)
    local ok = t_x == t_specs
    if not ok then
      errorf('%s: Expected %s, got %s', display, t_specs, t_x)
    end
  end
end

function validate.table(x, spec, prefix)
  prefix = prefix or '<root>'
  dict.each(spec, function(spec_key, spec_value)
    local is_opt
    is_opt, spec_key = validate.is_opt_key(spec_key, prefix)
    local x_value = x[spec_key]
    local x_key = spec_key
    local prefixed = sprintf('%s.%s', prefix, spec_key)

    if is_opt and x_value == nil then
      return
    elseif x_value == nil then
      errorf('%s: Expected %s, got nothing', prefixed, types.type(x_value))
    elseif is.pure_table(spec_value) then
      if is.pure_table(x_value) then
        validate.table(x_value, spec_value, prefixed)
      else
        local t_x = types.type(x_value)
        errorf('%s: Expected pure_table, got %s', prefixed, t_x)
      end
    else
      validate.value(x_value, x_key, prefix, spec_value)
    end
  end)
end

function validate:__call(specs)
  for key, spec in pairs(specs) do
    local validator, obj = spec[1], spec[2]
    local is_opt
    is_opt, key = validate.is_opt_key(key)

    if is_opt and obj == nil then
      return true
    elseif is.pure_table(obj) and is.pure_table(validator) then
      validate.table(obj, validator, '<root>')
    else
      validate.value(obj, key, nil, validator)
    end
  end
end

function validate:__index(name)
  return function(obj, validator)
    validate { [name] = { validator, obj } }
  end
end

function validate:import()
  _G.validate = self
  _G.arguments = self
end

--- Throws an error correctly
-- validate.table(
--   {a=1, b=1, c = {1, 2, 3}},
--   {a='number', b = is.number, c = {2, '3', 4}}
-- )

return validate
