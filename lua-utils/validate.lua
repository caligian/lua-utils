local types = require('lua-utils.types')
local validate = {}
setmetatable(validate, validate)

---type validator
local function validate_table(x, spec, prefix)
  for key, validator in pairs(spec) do
    local name = key
    local is_opt = string.match(name, '^opt_') or string.match(name, '^[?]')
    name = name:gsub('^opt_', '')
    name = name:gsub('^[?]', '')
    name = name:match('^[0-9]+$') and tonumber(name) or name
    local value = x[name]

    if not (value == nil and is_opt) then
      local prefixed_key

      if prefix then
        prefixed_key = prefix .. '.' .. name
      else
        prefixed_key = name
      end

      if types.object(validator) or types.callable(validator) then
        types.assert(value, validator, prefixed_key)
      elseif type(validator) == 'table' then
        if type(value) == 'table' then
          validate_table(value, validator, prefixed_key)
        else
          error(sprintf('%s: expected table, got %s', value))
        end
      else
        types.assert(value, validator, prefixed_key)
      end
    end
  end
end

function validate:__call(specs)
  for key, spec in pairs(specs) do
    local name, validator, obj = key, spec[1], spec[2]
    local is_opt = string.match(key, '^opt_') or string.match(key, '^[?]')

    types.assert(
      validator,
      types.union(types.callable, types.string, types.table),
      name
    )

    if not (is_opt and obj == nil) then
      if types.string(validator) then
        local ok, msg = types.is(obj, validator)
        if not ok then
          msg = msg or 'assertion failed'
          msg = key .. ': ' .. msg
          error(msg)
        end
      elseif types.object(validator) or types.callable(validator) then
        types.assert(obj, validator, key)
      elseif types.table(validator) then
        local ok, msg = types.table(obj)
        if not ok then
          msg = key .. ': ' .. msg
          error(msg)
        else
          validate_table(obj, validator, key)
        end
      end
    end
  end
end

function validate:__index(name)
  return function(obj, validator)
    validate {[name] = {validator, obj}}
  end
end

return validate
