require "lua-utils.table"
require "lua-utils.string"
require "lua-utils.types"

--- @class form
--- > form.string.opts(opts or 'nil')
--- > form[union('table', 'string')].opts(opts or {})
--- >
--- > local obj = {1, 2, 3}
--- > -- this will throw an error
--- > form(obj, 2, 3) {
--- >   {1, is_string, is_table},
--- >   is_number,
--- >   is_number,
--- > }
--- @overload fun(...:any): (fun(spec: any[]): boolean)
form = ns "form" --[[@as form]]

local function equal(value, spec_value, display)
  if is_method(spec_value) then
    local ok, msg = spec_value(value)
    if not ok then
      msg = display .. ': '  .. (msg or 'callable failed for ' .. dump(value)) 
      error(msg)
    end
    return true
  end

  local ok, msg = is_a(value, spec_value)
  if not ok then
    msg = msg or "expected " .. dump(spec_value) .. ", got " .. dump(value)
    msg = display .. ": " .. msg
    error(msg)
  end
  return true
end


--- Compare two items
--- @param obj any
--- @param spec any
--- @see is_a
--- @return any?
function form.compare(obj, spec, _prefix)
  _prefix = _prefix or '<base>'

  if is_method(spec) or not is_table(spec) then
    return equal(obj, spec, _prefix)
  end

  local later = {}
  local prefix = _prefix or "<base>"
  local check = function(key, spec_value)
    local is_opt
    key = tostring(key)
    key, is_opt = key:gsub("^opt_", "")
    if is_opt == 0 then
      key, is_opt = key:gsub("%?$", "")
    end
    is_opt = is_opt ~= 0
    key = tonumber(key) or key
    local value = obj[key]
    local display = prefix .. "." .. key
    if is_nil(value) and is_opt then
      return
    elseif is_method(spec_value) then
      local ok, msg = spec_value(value)
      if not ok then
        error(display .. ': ' .. msg)
      end
      return
    end

    if is_table(value) and is_table(spec_value) then
      later[#later + 1] = { value, spec_value, prefix }
    elseif is_table(spec_value) then
      error(display .. ": expected table, got " .. dump(value))
    else
      equal(value, spec_value, display)
    end
  end

  for key, value in pairs(spec) do
    check(key, value)
  end

  for i = 1, #later do
    form.compare(unpack(later[i]))
  end

  return obj
end

function form:__call(...)
  local objs = pack_tuple(...)

  return function(spec)
    if is_method(spec) or not is_table(spec) then
      spec = {spec}
    end

    for i = 1, #objs do
      local obj = objs[i]
      local obj_spec = spec[i]
      if not is_nil(obj_spec) then
        form.compare(obj, obj_spec, "param<" .. i .. ">")
      end
    end

    return true
  end
end

function form:__index(spec)
  return mtset({}, {
    __index = function(_, display)
      return function(obj)
        return form.compare(obj, spec, display)
      end
    end,
  })
end

--- alias for form()
--- @param ... any any parameters to check
--- @see form
--- @return fun(spec: any[]): boolean
function params(...)
  return form(...)
end

