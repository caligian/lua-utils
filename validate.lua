--- Type validation utilities
local validate = {}
local Set = require "lua-utils.Set"
local types = require "lua-utils.types"
local dict = require "lua-utils.dict"
local array = require "lua-utils.array"
local str = require "lua-utils.str"
local valid_types = types.builtin
local class = require "lua-utils.class"

--------------------------------------------------------------------------------
local function is_a_message(expected, got)
  return sprintf("expected %s, got %s", expected, got)
end

local function test_class(param, spec, param_t)
  local ok, msg
  if not types.is_class(param) then
    ok = false
    msg = is_a_message("class", param_t)
  elseif spec == "class" then
    ok = true
  elseif types.is_string(spec) then
    local name = param:get_name()
    ok = name == spec
    msg = is_a_message(spec, name)
  elseif types.is_class(spec) then
    ok = param:is_a(spec)
    msg = is_a_message(spec:get_name(), param:get_name())
  end

  if not ok then return false, msg end
  return true
end

local function is_a(param, spec)
  if spec == "*" then return true end
  local spec_t = types.is_string(spec) and spec or types.typeof(spec)
  local param_t = types.typeof(param)

  if spec_t == "class" then
    return test_class(param, spec, param_t)
  elseif types.is_string(spec) then
    if valid_types[spec] then
      local same = param_t == spec_t
      if not same then return false, is_a_message(spec_t, param_t) end
    elseif param_t ~= "class" then
      return false, is_a_message("class", param_t)
    end
  elseif types.is_callable(spec) then
    local ok, msg = spec(param)
    if ok == nil then ok = false end
    return ok, msg or "callable failed " .. tostring(param)
  else
    local same = spec_t == param_t
    if not same then return false, is_a_message(spec_t, param_t) end
  end

  return true
end

--- Checks is_a relationships
-- @usage
-- --- Indexing with spec is also supported
-- -- true
-- validate.is_a.number(1)
-- validate.is_a(1, "number")
--
-- -- true
-- validate.is_a.class(class "A")
-- validate.is_a(class "A", "A")
--
-- @function validate.is_a
-- @param param param to be checked
-- @param spec type spec: string|class|any
-- @treturn boolean
validate.is_a = setmetatable({}, {
  __call = function(_, param, spec) return is_a(param, spec) end,
  __index = function(_, spec)
    return function(param) return is_a(param, spec) end
  end,
})

--- Returns a callable that checks the type. To be used with .validate
-- @param spec type specification
-- @treturn callable
function validate.is(spec)
  if types.typeof(spec) ~= "table" then spec = { spec } end

  return function(param)
    local msg = {}
    local msg_i = 0

    for i = 1, #spec do
      local tp = spec[i]
      local ok, err = is_a(param, tp)
      if not ok then
        msg[msg_i + 1] = err
        msg_i = msg_i + 1
      else
        return true
      end
    end

    return false, table.concat(msg, "\n")
  end
end

local function filter_optional(spec, param)
  dict.each(dict.copy(spec), function(key, value)
    local is_opt = str.match_any(tostring(key), "^opt_", "^%?")
    local new_key = key

    if is_opt then
      new_key = str.gsub(key, "^" .. is_opt, "")
      spec[key] = nil

      if param[new_key] ~= nil then spec[new_key] = value end
    end
  end)
end

local function get_common_keys(spec, param)
  filter_optional(spec, param)

  local t_name = spec.__name or "<spec>"
  local nonexistent = spec.__nonexistent
  if spec.__nonexistent == nil then extra = true end

  local ks_spec = Set(
    array.grep(
      dict.keys(spec),
      function(key, _) return not str.match_any(key, "__nonexistent", "__name") end
    )
  )
  local ks_param = Set(
    array.grep(
      dict.keys(param),
      function(key, _) return not str.match_any(key, "__nonexistent", "__name") end
    )
  )
  local missing = ks_spec - ks_param
  local extra = ks_param - ks_spec
  local common = ks_param ^ ks_spec

  if missing:len() > 0 then
    local msg =
      sprintf("%s: missing keys: %s", t_name, array.join(missing:items(), ","))
    error(msg)
  end

  if not nonexistent and extra:len() > 0 then
    local msg =
      sprintf("%s: extra keys: %s", t_name, array.join(extra:items(), ","))
    error(msg)
  end

  return common
end

local function validate_table(spec, param)
  get_common_keys(spec, param):each(function(k)
    local expected, got = spec[k], param[k]
    local t_name = spec.__name
    local nonexistent = spec.__nonexistent
    if nonexistent == nil then nonexistent = true end

    if types.typeof(expected) == "table" and types.typeof(got) == "table" then
      expected.__name = k
      expected.__nonexistent = nonexistent
      validate_table(expected, got)
    elseif types.typeof(expected) == "callable" then
      local ok, msg = expected(got)
      msg = msg or sprintf("%s.%s: callable failed", t_name, k)
      if not ok then error(msg) end
    else
      local ok, msg = is_a(got, expected)
      if not ok then error(sprintf("%s.%s: %s", t_name, k, msg)) end
    end
  end)
end

--- Validate parameters. Similar to vim.inspect.
-- @usage
--
-- -- syntax: {display = {spec, param}, ...}
--
-- -- rules:
-- -- * tables (not classes) will be recursed
-- -- * classes will be compared by name or <class>.is_a
-- -- * callable should return boolean, error_message or just boolean
-- -- * strings will be directly compared with either class name or .typeof(param)
-- -- * anything else will be compared by type
-- -- * optional keys should be prefixed with "opt_" or "?"
--
-- -- Nested tables supported. They should not be classes
-- -- b.c: expected string, got number
-- validate.validate {
--   dict = {
--     {
--       a = 'number',
--       b = {
--         c = 'string'
--       }
--     },
--     {
--       a = 1,
--       b = {
--         c = 2
--       }
--     }
--   }
-- }
--
-- --- Indexing is also supported
-- -- error thrown
-- validate.validate.number('number', 'a')
--
-- @function validate.validate
-- @param spec_with_param type specs for params. See usage
validate.validate = setmetatable({}, {
  __call = function(_, spec_with_param)
    dict.each(spec_with_param, function(key, value)
      local is_opt = str.match_any(key, "^opt_", "^%?")
      local new_key = key

      if is_opt then new_key = str.gsub(key, "^" .. is_opt, "") end

      local spec, param = unpack(value)
      if is_opt and param == nil then return end

      if types.is_string(spec) then
        local ok, msg = is_a(param, spec)
        if not ok then error(key .. ": " .. msg) end
      elseif types.is_callable(spec) then
        local ok, msg = spec(param)
        if not ok then error(key .. ": " .. (msg or "callable failed")) end
      elseif types.is_table(spec) then
        if not types.is_table(param) then
          error(key .. ": " .. "expected table, got " .. types.typeof(param))
        end
        spec.__name = spec.__name or key
        spec.__nonexistent = spec.__nonexistent == nil and true
          or spec.__nonexistent
        validate_table(spec, param)
      else
        local ok, msg = is_a(got, expected)
        if not ok then error(sprintf("%s: %s", key, msg)) end
      end
    end)
  end,

  __index = function(self, display)
    return function(spec, param) self { [display] = { spec, param } } end
  end,
})

function validate.union(...)
  return is(...)
end

function validate.globalize()
  for key, value in pairs(validate) do
    if key ~= 'globalize' then
      _G[key] = value
    end
  end
end

return validate
