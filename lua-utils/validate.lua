require 'lua-utils.dump'

local list = require 'lua-utils.list'
local dict = require('lua-utils.dict')
local types = require('lua-utils.types')
local is = require 'lua-utils.is'
local union = types.union

---@overload fun(specs: table<string,table<any,any>>): nil
local validate = {}
setmetatable(validate, validate)

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
  errorf(prefix .. ': ' .. msg)
end

---@param x any
---@param y any
---@param prefix? string (default: <root>)
---@return boolean?
local function check(x, y, prefix)
  prefix = prefix or '<root>'
  if is.pure_table(x) and is.pure_table(y) then
    dict.each(y, function(y_key, y_value)
      local is_opt
      is_opt, y_key = is_opt_key(y_key, prefix)
      local x_value = x[y_key]
      local prefix_key = y_key

      if is.number(y_key) then
        prefix_key = sprintf('[%d]', y_key)
        prefix_key = prefix .. prefix_key
      else
        prefix_key = prefix .. '.' .. y_key
      end

      if is_opt and undefined(x_value) then
        return
      else
        check(x_value, y_value, prefix_key)
      end
    end)
  elseif callable(y) and not is.object(y) then
    local ok, msg = y(x)
    if not ok then
      msg = msg or sprintf('%s: Assertion failure', y)
      throw(prefix, msg)
    end
  else
    local ok, msg = types.is(x, y)
    if not ok then
      throw(prefix, msg)
    end
  end
end

function validate:__call(specs)
  dict.each(specs, function (key, spec)
    local validator, obj = spec[1], spec[2]
    local is_opt
    is_opt, key = is_opt_key(key)

    if is_opt and obj == nil then
      return true
    else
      check(obj, validator, key)
    end
  end)
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

return validate
