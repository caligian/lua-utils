local copy = require 'lua-utils.copy'

---Type checking guards
---If opts is string, then opts will be converted to {prefix = opts}
---Usage:
---> is[TYPE](x, opts)
---> is(x, TYPE, opts)
---@overload fun(x: any, type: guard.valid_type, opts?: guard.opts|string): boolean, string?
is = defcallable(
  function(self, x, tp, opts)
    if type(opts) == 'string' then
      opts = { prefix = opts }
    end

    local tp_type = type(tp)
    if tp_type == 'string' then
      if is[tp] then
        return is[tp](x, opts)
      elseif GUARD[tp] then
        is[tp] = GUARD[tp]
        return GUARD[tp](x, opts)
      else
        errorf("Unknown type provided: %s", tp)
      end
    elseif is_union(tp) then
      return tp(x, opts)
    elseif is_guard(tp) then
      return tp(x, opts)
    end

    opts = opts or {}
    local prefix = opts.prefix
    local ok, msg = is_object(tp, true)

    if not ok then
      errorf("Expected string|guard|union|object, got [%s] %s", type(tp), tp)
    end

    if opts.assert or opts.dump then
      ok, msg = is_object(x, true)
      if ok then
        ok, msg = inherits(x, { tp }, true)
        if not ok then
          msg = prefix and (prefix .. ': ' .. msg) or msg
          if opts.assert then
            errorf(msg)
          else
            return false, msg
          end
        end
      end
    elseif not is_object(x) then
      return false, nil
    elseif not instanceof(x, tp) then
      return false, nil
    end

    return true
  end
)

function is:__index(key)
  return function(x, opts)
    local f = rawget(is, '__call')
    return f(is, x, key, opts)
  end
end

is.module = GUARD.module
is.number = GUARD.number
is.string = GUARD.string
is.table = GUARD.table
is.userdata = GUARD.userdata
is.thread = GUARD.thread
is.callable = GUARD.callable
is.class = GUARD.class
is.instance = GUARD.instance
is.object = GUARD.object
is.type = GUARD.type
is.type_table = GUARD.type
is.dict = GUARD.pure_dict
is.list = GUARD.pure_list
is.pdict = GUARD.pure_dict
is.plist = GUARD.pure_list
is.ptable = GUARD.pure_table
is.pure_dict = GUARD.pure_dict
is.pure_list = GUARD.pure_list
is.pure_table = GUARD.pure_table
is.guard = GUARD.guard
is.union = GUARD.union
is.fun = GUARD.fun
is.pairs = GUARD.pairs
is.defined = GUARD.defined
is.undefined = GUARD.undefined
is['function'] = is.fun

---Similar to is() but assert type
---Usage:
---> assert_is[TYPE](x, opts)
---> assert_is(x, TYPE, opts)
---@overload fun(x: any, type: guard.valid_type, opts?: guard.opts|string): boolean, string?
assert_is = defcallable(function(_, x, tp, opts)
  if type(opts) == 'string' then
    opts = { prefix = opts }
  end

  opts = opts or {}
  opts = copy.copy(opts)
  opts.assert = true

  return is(x, tp, opts)
end)

function assert_is:__index(key)
  return function(x, opts)
    local f = rawget(assert_is, '__call')
    return f(assert_is, x, key, opts)
  end
end

---Similar to assert_is() but assert type when x ~= nil
---Usage:
---> opt_assert_is[TYPE](x, opts)
---> opt_assert_is(x, TYPE, opts)
---@overload fun(x: any, type: guard.valid_type, opts?: guard.opts|string): boolean, string?
opt_assert_is = defcallable(function(_, x, tp, opts)
  if type(opts) == 'string' then
    opts = { prefix = opts }
  end

  opts = opts or {}
  opts = copy.copy(opts)
  opts.assert = true
  opts.optional = true

  return is(x, tp, opts)
end)

function opt_assert_is:__index(key)
  return function(x, opts)
    local f = rawget(opt_assert_is, '__call')
    return f(opt_assert_is, x, key, opts)
  end
end

---Similar to is() but set optional = true by default in opts
---Usage:
---> opt_is[TYPE](x, opts)
---> opt_is(x, TYPE, opts)
---@overload fun(x: any, type: guard.valid_type, opts?: guard.opts|string): boolean, string?
opt_is = defcallable(function(_, x, tp, opts)
  if type(opts) == 'string' then
    opts = { prefix = opts }
  end

  opts = opts or {}
  opts = copy.copy(opts)
  opts.optional = true

  return is(x, tp, opts)
end)

function opt_is:__index(key)
  return function(x, opts)
    local f = rawget(opt_is, '__call')
    return f(opt_is, x, key, opts)
  end
end
