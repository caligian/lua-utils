require "lua-utils.types.utils"

local default_types = {}
for key, fun in pairs(_G) do
  if key:match "^is_" and key ~= "is_a" then
    default_types[key] = fun
  end
end

local union_mt = {type = 'union', method = true}
union = mtset({}, union_mt)

function union._match_else(value, spec)
  local ok = value == spec
  if not ok then
    return false, dump(spec)
  end

  return value
end

function union._match_fun(value, spec)
  local ok, msg = spec(value)
  if not ok then
    return false, msg or "callable failed for " .. dump(value)
  end

  return value
end

function union._match_table(value, spec)
  if value == spec then
    return value
  elseif is_method(spec) then
    local ok, failed = spec(value, true)
    if ok then
      return true
    end
    return false, failed
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

function union._match_string(value, spec)
  local found = default_types["is_" .. spec]
  if found then
    local ok = found(value)
    if not ok then
      return false, spec
    end
    return value
  elseif not is_table(value) then
    return false, spec
  end

  ok = typeof(value) == spec
  if not ok then
    return false, spec
  end

  return value
end

function union.match(value, spec)
  if is_string(spec) then
    return union._match_string(value, spec)
  elseif is_function(spec) then
    return union._match_fun(value, spec)
  elseif is_table(spec) then
    return union._match_table(value, spec)
  end
  return union._match_else(value, spec)
end

local function is_union_of(value, ...)
  local failed = {}
  local check = { ... }

  for i = 1, #check do
    local ok, msg = union.match(value, check[i])
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

--- Return a function that checks union of types ...
--- @param ... string|function|table
--- @return fun(x): boolean, string?
function union_mt:__call(...)
  local args = pack(...)

  return setmetatable({}, {
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
        return false, "expected " .. failed[1] .. ", got " .. dump(value)
      end

      ---@diagnostic disable-next-line
      failed = join(failed, ", ")
      local msg = "expected any of " .. failed .. ", got " .. dump(value)

      return false, msg
    end,
    type = "union",
  })
end

--------------------------------------------------

--- Type checking ns
--- > form 1: is_a[<type_sig: function|string|table|object|any>](<obj>, assert_type?)
--- > form 2: is_a(<type_sig: function|string|table|object|any>, <obj>, assert_type?)
--- > is_a.string(1, true) -- will throw an error
--- > is_a[union('string', 'number')](1) -- this will succeed
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
    local f = type(key) == 'union' and union(key) or key
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
