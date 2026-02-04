local dict = require('lua-utils.dict')
local types = require('lua-utils.types')
local validate = {}

setmetatable(validate, validate)

local function validate_value(k, specs, obj) 
  local opt = k:match('^opt_') or k:match('^%?')
  k = (opt and k:gsub('^opt_', ''):gsub('^%?', '')) or k

  if opt and obj == nil then
    return
  elseif obj == specs then
    return
  end

  local throw = function (name, msg)
    return errorf('%s: %s', name, msg)
  end

  if types.object(specs) then
    if types.object(obj) then
      local ok, msg = obj:isa(specs)
      if not ok then
	msg = prefix .. '.' .. k .. ': ' .. msg
	error(msg)
      end
    else
      local msg = 'Expected ' .. specs.__name .. ', got ' .. dump(obj)
      throw(k, msg)
    end
  elseif types.fun(specs) then
    local ok, msg = specs(obj)
    if not ok then
      throw(k, msg)
    end
  elseif types.string(specs) then
    if types.object(obj) then
      local ok = obj.__name == specs
      if not ok then
	local msg = 'Expected (object) ' .. specs .. ', got ' .. obj.__name
	throw(k, msg)
      end
    elseif types[specs] then
      local ok, msg = types[specs](obj)
      if not ok then
	throw(k, msg)
      end
    else
      local t = types.type(obj)
      local ok = t == specs
      if not ok then
	local msg = 'Expected ' .. specs .. ', got ' .. t
	throw(k, msg)
      end
    end
  else
    local obj_t = types.type(obj)
    local spec_t = types.type(specs)
    local ok = obj_t == spec_t

    if not ok then
      local msg = 'Expected ' .. spec_t .. ', got ' .. obj_t
      throw(k, msg)
    end
  end
end

local function validate_table(prefix, specs, obj)
  prefix = prefix or ''
  if types.pure_table(specs) then
    local ok, msg = types.table(obj)
    if not ok then
      error(prefix .. ': ' .. msg)
    end

    for k, v in pairs(specs) do
      local is_opt = string.match(k, '^opt_') or string.match(k, '^[?]')
      k = k:gsub('^opt_', ''):gsub('^%?', '')
      local spec = v
      local value = obj[k]
      local p = prefix .. '.' .. k

      if is_opt and value == nil then
	return
      elseif types.pure_table(spec) then
	validate_table(p, spec, value)
      else
	validate_value(p, spec, value)
      end
    end
  else
    validate_value(prefix, specs, obj)
  end
end

function validate:__call(specs)
  for key, spec in pairs(specs) do
    local validator, obj = spec[1], spec[2]
    local is_opt = string.match(key, '^opt_') or string.match(key, '^[?]')
    key = key:gsub('^opt_', ''):gsub('^%?', '')

    if is_opt and value == nil then
      return true
    end

    validate_table(key, validator, obj)
  end
end

function validate:__index(name)
  return function(obj, validator)
    validate { [name] = { validator, obj } }
  end
end

function validate:import()
  _G.validate = self
end

return validate
