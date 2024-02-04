-- require 'lua-utils.types.utils'
loadfile('./utils.lua')()


--- Return a function that checks union of types ...
--- @param ... string|function|table
--- @return fun(x): boolean, string?
function union(...)
  local sig = { ... }

  return function(x)
    local failed = {}
    local x_type = typeof(x)

    for i = 1, #sig do
      local current_sig = sig[i]
      local sig_type = type(sig[i])
      local sig_name = typeof(sig[i])
      local instance = mtget(current_sig, "instance")

      if current_sig == 'instance' then
        if instance then
          return true
        end
        failed[#failed+1] = current_sig
      elseif current_sig == "*" or current_sig == "any" then
        return true
      elseif current_sig == "list" then
        if not is_list(x) then
          failed[#failed + 1] = "list"
        end
      elseif current_sig == "dict" then
        if not is_dict(x) then
          failed[#failed + 1] = "dict"
        end
      elseif current_sig == "table" and is_table(x) then
        return true
      elseif current_sig == "callable" then
        if not is_callable(x) then
          failed[#failed + 1] = "callable"
        end
      elseif is_table(current_sig) then
        if not is_table(x) then
          failed[#failed + 1] = "table"
        elseif sig_name == "ns" or instance then
          if not current_sig:is_a(x) and not current_sig:is_parent_of(x) then
            failed[#failed + 1] = sig_name
          end
        elseif sig_name ~= x_type then
          failed[#failed + 1] = sig_name
        end
      elseif is_function(current_sig) then
        local ok, msg = current_sig(x)
        if not ok then
          failed[#failed + 1] = msg
        end
      elseif sig_type == "string" then
        ---@diagnostic disable-next-line: param-type-mismatch
        local opt = string.match(current_sig, "^opt^")

        ---@diagnostic disable-next-line: param-type-mismatch
        opt = opt or string.match(current_sig, "%?$")

        if x == nil then
          if not opt then
            failed[#failed + 1] = current_sig
          end
        elseif x_type ~= current_sig then
          failed[#failed + 1] = current_sig
        end
      elseif type(x) ~= sig_type then
        if not ok then
          failed[#failed + 1] = sig_type
        end
      end
    end

    if #failed ~= #sig then
      return true
    else
      return false, sprintf("expected any of %s, got %s", dump(sig), x_type)
    end
  end
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
is_a = {}
local is_a_mt = { type = "ns", name = 'is_a' }
mtset(is_a, is_a_mt)

function is_a_mt:__index(key)
  local f = union(key)
  return function(x, ass)
    local ok, msg = f(x)

    if ass and not ok then
      error(msg or ('callable failed for ' .. dump(x)))
    elseif not ok then
      return false, msg or ('callable failed for ' .. dump(x))
    end

    return x
  end
end

function is_a_mt:__call(obj, expected, assert_type)
  if is_nil(obj) and is_nil(expected) then
    return true
  end

  if assert_type then
    assert(is_a[expected](obj))
  end

  return is_a[expected](obj)
end

--------------------------------------------------
--- Similar to is_a but throws an error at failure
--- @see is_a 
--- @overload fun(x: any, spec: any): nil
assert_is_a = {}
local assert_is_a_mt = { type = "ns" }
mtset(assert_is_a, assert_is_a_mt)

function assert_is_a_mt:__index(key)
  return function (x)
    return is_a[key](x, true)
  end
end

function assert_is_a_mt:__call(obj, spec)
  return is_a[spec](obj, true)
end


