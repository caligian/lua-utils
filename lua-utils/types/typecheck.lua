require "lua-utils.types.utils"

local default_types = guards

function defguard(name, fn)
  return guards.create(name, fn)
end


--------------------------------------------------
local Union_mt = {type = 'union', method = true}
local Union = mtset({}, Union_mt)

function Union._match_else(value, spec)
  local ok = value == spec
  if not ok then
    return false, dump(spec)
  end
  return value
end

function Union._match_fun(value, spec)
  local ok, msg = spec(value)
  if not ok then
    return false, msg or "callable failed for " .. dump(value)
  end
  return value
end

function Union._match_table(value, spec)
  if value == spec then
    return value
  elseif not is_table(value) then
    return false, typeof(spec)
  elseif is_ns(spec) or is_class_object(spec) then
    local spec_name = is_class_object(spec) and spec:get_class_name() or spec:get_ns_name()
    local ok = spec:is_a(value)
    if not ok then
      return false, spec_name
    end
    return value
  end

  local spec_name = typeof(spec)
  local ok = spec_name == typeof(value) == spec_name
  if not ok then
    return false, spec_name
  end

  return value
end

function Union._match_string(value, spec)
  local found = guards.guards["is_" .. spec]
  if found then
    local ok = found(value)
    if not ok then
      return false, spec
    end
    return value
  end

  ok = typeof(value) == spec
  if not ok then
    return false, spec
  end

  return value
end

function Union.match(value, spec)
  if is_string(spec) then
    return Union._match_string(value, spec)
  elseif is_method(spec) then
    return Union._match_fun(value, spec)
  elseif is_table(spec) then
    return Union._match_table(value, spec)
  end
  return Union._match_else(value, spec)
end

local function is_union_of(value, ...)
  local failed = {}
  local check = { ... }

  for i = 1, #check do
    local ok, msg = Union.match(value, check[i])
    if not ok then
      if is_table(msg) then
        for i = j, #msg do
          failed[#failed + 1] = msg[j]
        end
      else
        failed[#failed + 1] = msg
      end
    else
      return true
    end
  end

  return failed
end

--- Return a function that checks Union of types ...
--- @param ... string|function|table
--- @return fun(x): boolean, string?
function Union_mt:__call(...)
  local args = pack(...)

  return setmetatable({}, {
    method = true,
    __call = function(self, obj, get_failed)
      local failed = is_union_of(obj, unpack(args))
      if failed == true then
        return true
      end

      local l = #failed
      if l == 0 then
        return true
      elseif get_failed then
        return false, failed
      end

      if l == 1 then
        return false, "expected " .. failed[1] .. ", got " .. dump(obj)
      end

      ---@diagnostic disable-next-line
      failed = join(failed, ", ")
      local msg = "expected any of " .. failed .. ", got " .. dump(obj)

      return false, msg
    end,
    type = 'union',
  })
end

--------------------------------------------------

--- Type checking ns
--- > form 1: is_a[<type_sig: function|string|table|object|any>](<obj>, assert_type?)
--- > form 2: is_a(<type_sig: function|string|table|object|any>, <obj>, assert_type?)
--- > is_a.string(1, true) -- will throw an error
--- > is_a[Union('string', 'number')](1) -- this will succeed
--- > is_a(<obj>, <spec>)
--- > is_a(1, function (x)
--- >   local ok = x > 2
--- >   if not ok then return false, 'expected more than 2, got ' .. dump(x) end
--- >   return x
--- > end, true) -- this will throw an error
--- @overload fun(obj: any, spec: any, assert_type?: boolean): nil
--
is_a = mtset({}, {
  __call = function(_, obj, expected, assert_type)
    if is_nil(obj) and is_nil(expected) then
      return true
    end

    if assert_type then
      assert(is_a[expected](obj))
    end

    return is_a[expected](obj)
  end,
  __index = function (_, key)
    local f = typeof(key) ~= 'union' and Union(key) or key
    return function(obj, ass)
      local ok, msg = f(obj)
      if not ok then
        if ass then
          error(msg)
        end
        return false, msg
      end
      return true
    end
  end
})

assert_is_a = mtset({}, {
	__index = function(_, key)
		return function(obj) 
			return is_a(obj, key, true)
		end
	end,
	__call = function(_, obj, expected)
		return is_a(obj, expected, true)
	end,
})

union = Union
