local copy = require 'lua-utils.copy'


---@overload fun(...: string|guard|union|object): union
union = bless { __type = 'callable', __callable = true }

---@alias union.valid_type string|union|guard|object

---@return string
function union:make_type_string()
  local function flatten(sigs, res)
    res = res or {}
    for i = 1, #sigs do
      local sig = sigs[i]
      local sig_type = type(sig)

      if sig_type == 'table' and not sig.__type then
        flatten(sig, res)
      elseif is_union(sig) then
        flatten(sig.signature, res)
      elseif is_guard(sig) then
        res[#res + 1] = sig.name
      elseif is_object(sig) then
        res[#res + 1] = class_name(sig)
      elseif sig_type == 'string' then
        if not GUARD[sig] then
          errorf("%s does not exist in _G.GUARD", sig)
        else
          res[#res + 1] = GUARD[sig].name
        end
      else
        errorf("signature[%d]: Expected string|union|guard|object, got %s", i, sig_type)
      end
    end

    return res
  end

  local sigs = self.signature
  local display = unique(flatten(sigs, {}))
  display = table.concat(display, "|")

  return display
end

---@param x any
---@return string
function union:make_err_msg(x)
  return sprintf('Expected %s, got %s', self.type_name, x)
end

---@param x any
---@return boolean
function union:check(x)
  if x == NIL then
    x = nil
  end

  local is_obj = is_object(x)
  for i = 1, #self.signature do
    local check = self.signature[i]
    if is_union(check) then
      local ok = union.check(check, x)
      if ok then return true end
    elseif is_guard(check) then
      if check(x) then return true end
    elseif is_object(check) and is_obj then
      if instanceof(x, check) then return true end
    elseif type(check) == 'string' then
      if not GUARD[check] then
        errorf("GUARD.%s does not exist", check)
      elseif GUARD[check](x) then
        return true
      end
    else
      errorf("self.signature[%d]: Expected union|guard|string|object, got %s", i, check)
    end
  end

  return false
end

---@param ... union.valid_type
---@return union
function union.new(...)
  local tup_len = select('#', ...)
  local sig = { ... }

  if #sig ~= tup_len then
    error("Signature specification cannot contain nil")
  end

  ---@type union
  ---@overload fun(x: any, opts?: union.opts): boolean, string?
  local obj = bless()
  obj.__index = rawget
  obj.__callable = true
  obj.__type = 'union'
  obj.signature = { ... }
  obj.type_name = union.make_type_string(obj)
  obj.new = nil
  obj.__call = function(_, x, opts)
    local prefix = opts.prefix
    local assert_ = opts.assert
    local opt = opts.optional or opts.opt

    if opt and x == nil or x == NIL then
      return true
    elseif union.check(_, x) then
      return true, nil
    end

    local msg = sprintf('Expected %s, got [%s] %s', _.type_name, type(x), x)
    msg = prefix and sprintf('%s: %s', prefix, msg) or msg
    if assert_ then error(msg) end

    return false, msg
  end

  return obj ---@type union
end

---@return fun(x: any, assert_: boolean, prefix?: string): boolean, string?
function union:as_function()
  return function(x, assert_, prefix)
    if self:check(x) then
      return true, nil
    end

    local msg = self:make_type_string()
    msg = prefix and sprintf('%s: %s', prefix, msg) or msg
    if assert_ then errorf(msg) end

    return false, msg
  end
end

---@param ... string|guard|union|object
---@return union
function union:__call(...)
  return union.new(...)
end

---Is union object
---@param x any
---@return boolean, string?
function is_union(x)
  local ok = type(x) == 'table'
  if not ok then
    return false, sprintf('Expected union object, got %s', x)
  elseif x.__type == 'union' and x.__call then
    return true, nil
  else
    return false, sprintf('Expected union object, got %s', x)
  end
end

function optional(...)
  local check = union(...)
  return function(x, opts)
    opts = copy(opts)
    opts.optional = true
    return check(x, opts)
  end
end
