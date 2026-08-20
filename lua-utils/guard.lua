---@param name string
---@param cond callable_table | fun(x: any): boolean
---@param make_err_msg? fun(x: any): string
---@param format string? (default: Expected %s?, got %s) where the first %s is substituted by guard.name if it is not provided
---@return table
function defguard(name, cond, make_err_msg, format)
  local ok, msg = callable(make_err_msg, true)
  if not ok then
    error(msg)
  end

  local g = bless()
  g.__callable = true
  g.__type = 'guard'
  g.name = name
  g.guard = cond
  g.format = format or 'Expected %s, got %s'
  g.make_err_msg = make_err_msg or function(obj)
    return sprintf(g.format, g.name, type(obj))
  end

  function g:as_function()
    return function(obj, opts)
      return self:__call(obj, opts)
    end
  end

  ---If opts is string, then {prefix = opts}
  ---@param obj any
  ---@param opts? guard.opts|string
  ---@return boolean, string?
  function g:__call(obj, opts)
    if type(opts) == 'string' then
      opts = { prefix = opts }
    end

    obj = as_value(obj)
    opts = opts or {}
    local assert_ = opts.assert
    local prefix = opts.prefix
    local should_dump = opts.dump
    local opt = opts.optional or opts.opt

    if opt and obj == nil then
      return true
    end

    if self.guard(obj) then
      return true, nil
    end

    if assert_ or should_dump then
      local err_msg = self.make_err_msg(obj)
      err_msg = msg_with_prefix(err_msg, prefix)

      if assert_ then
        error(err_msg)
      else
        return false, err_msg
      end
    end

    return false, nil
  end

  ---@type guard
  GUARD[name] = g
  return g
end

---@param x any
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_guard(x, err_msg, prefix)
  local ok = type(x) == 'table' and x.__type == 'guard'
  if ok then
    return true, nil
  elseif not err_msg then
    return false, nil
  end

  local msg = sprintf('Expected guard, got [%s] %s', type(x), x)
  msg = msg_with_prefix(msg, prefix)
  return false, msg
end

---Check if a mt_ field exists
---@param x table
---@return boolean
function mt_exists(x)
  return get_metatable(x) ~= nil
end

---Get a mt_ or mt_ field
---@param x table
---@return table?
---@overload fun(x: table, ks: (string|number)[]): table<string|number,any>
---@overload fun(x: table, key: string|number): any
---@overload fun(x: table): table?
function mt_get(x, ...)
  local args = { ... }
  local args_len = #args

  if args_len == 1 then
    if type(args[1]) == 'table' then
      return mt_get_keys(x, args[1])
    else
      return mt_get_key(x, args[1])
    end
  else
    return get_metatable(x)
  end
end

---Get a mt_ or mt_ field
---@param x table
---@param key string|number
---@return table?
function mt_get_key(x, key)
  local mt = getmetatable(x)
  if mt then
    return mt[key]
  end
end

---@param x table
---@param ks (string|number)[]
---@return table<string,any>?
function mt_get_keys(x, ks)
  local mt = getmetatable(x)
  if mt == nil then
    return nil
  end

  local res = {}
  for _, k in pairs(ks) do
    res[k] = x[k]
  end

  return res
end

---Set a mt_ or mt_ field
---@param x table
---@param ... any
---@return table
---@overload fun(x: table, key: string|number, value: any): table
---@overload fun(x: table, mt_: table): table
function mt_set(x, ...)
  local args_len = select('#', ...)
  if args_len == 2 then
    return mt_set_key(x, ...)
  elseif args_len == 1 then
    local mt = { ... }
    mt = mt[1]
    ---@type table
    return setmetatable(x, mt)
  else
    error('Expected 1 <= args_len <= 2 arguments, got ' .. tostring(args_len))
  end
end

---Set a mt_ or mt_ field
---@param x table
---@param key string
---@param value any
---@return table
function mt_set_key(x, key, value)
  local mt = mt_get(x) or {}
  mt[key] = value
  return setmetatable(x, mt)
end

---@param x table
---@param keys_and_values table<string,any>
---@return table
function mt_set_keys(x, keys_and_values)
  local mt = getmetatable(x) or {}
  for key, value in pairs(keys_and_values) do
    mt[key] = value
  end
  return setmetatable(x, mt)
end

---@param x table
---@param parent table
---@return boolean
function mt_is_parent(x, parent)
  local mt = getmetatable(x)
  if not mt then
    return false
  elseif x == mt then
    return false
  elseif mt == parent then
    return true
  elseif parent then
    return mt_is_parent(mt, parent)
  else
    return false
  end
end

---@param x table
---@param child table
---@return boolean
function mt_is_child(x, child)
  return mt_is_parent(child, x)
end

---Is y is a subset of x?
---@param x table
---@param y table
---@return boolean
function mt_includes(x, y)
  for key, _ in pairs(y) do
    if x[key] == nil then
      return false
    end
  end

  return true
end

---Check if object points to itself
---@param x table
---@return boolean
function mt_self(x)
  assert(
    type(x) == 'table',
    sprintf('Expected table, got %s', type(x))
  )
  return getmetatable(x) == x
end
