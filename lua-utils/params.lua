require "lua-utils.table"
require "lua-utils.string"

--- @class check_args
--- > check_args.string.opts(opts or 'nil')
--- > check_args[union('table', 'string')].opts(opts or {})
--- > 
--- > local obj = {1, 2, 3}
--- > -- this will throw an error
--- > check_args(obj, 2, 3) {
--- >   {1, is_string, is_table},
--- >   is_number,
--- >   is_number,
--- > }
--- @overload fun(...:any): (fun(spec: any[]): boolean)
check_args = ns 'arg_checker' --[[@as check_args]]

local function equal(value, spec_value, display)
  local ok, msg =  is_a(value, spec_value)

  if not ok then
    msg = msg or 'expected ' .. dump(spec_value) .. ', got ' .. dump(value)
    msg = display .. ':' .. msg
    error(msg)
  end

  return true
end

--- Compare two items
--- @param obj any
--- @param spec any
--- @see is_a
--- @return any?
function check_args.compare(obj, spec, _prefix)
  if not is_table(obj) or not is_table(spec) then
    equal(obj, spec, _prefix or '<base>')
    return
  end

  local later = {}
  local prefix = _prefix or '<base>'
  local check = function (key, spec_value)
    local is_opt
    key = tostring(key)
    key, is_opt = key:gsub('^opt_', '')
    if is_opt == 0 then
      key, is_opt = key:gsub('%?$', '')
    end
    is_opt = is_opt ~= 0
    key = tonumber(key) or key
    local value = obj[key]
    local display = prefix .. '.' .. key

    if is_nil(value) and is_opt then
      return
    end

    if is_table(value) and is_table(spec_value) then
      later[#later+1] = {value, spec_value, prefix}
    elseif is_table(spec_value) then
      error(display .. ': expected table, got ' .. dump(value))
    else
      equal(value, spec_value, display)
    end
  end

  for key, value in pairs(spec) do
    check(key, value)
  end

  for i = 1, #later do
    check_args.compare(unpack(later[i]))
  end

  return obj
end

function check_args:__call(...)
  local objs = pack_tuple(...)

  return function (spec)
    if not is_table(spec) then
      error('expected a table as spec, got ' .. dump(spec))
    end

    for i = 1, #objs do
      local obj = objs[i]
      local obj_spec = spec[i]
      if not is_nil(obj_spec) then
        check_args.compare(obj, obj_spec, 'param<' .. i .. '>')
      end
    end

    return true
  end
end

function check_args:__index(spec)
  return mtset({}, {
    __index = function (_, display)
      return function (obj)
        return check_args.compare(obj, spec, display)
      end
    end
  })
end

--- alias for check_args()
--- @param ... any any parameters to check
--- @see check_args
--- @return fun(spec: any[]): boolean
function params(...)
  return check_args(...)
end
