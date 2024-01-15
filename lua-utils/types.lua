inspect = require "inspect"
dump = inspect

--- @alias kv_pair { [1]: string|number, [2]: any }
--- @alias kv_pairs kv_pair[]

--- Valid lua metatable keys
--- @enum
mtkeys = {
  __unm = true,
  __eq = true,
  __ne = true,
  __ge = true,
  __gt = true,
  __le = true,
  __lt = true,
  __add = true,
  __sub = true,
  __mul = true,
  __div = true,
  __mod = true,
  __pow = true,
  __tostring = true,
  __tonumber = true,
  __index = true,
  __newindex = true,
  __call = true,
  __metatable = true,
  __mode = true,
}

--- Get metatable or metatable key
--- @param obj table
--- @param k? any a key. If not given then return metatable
--- @return any value metatable or value
function mtget(obj, k)
  if type(obj) ~= "table" then
    return
  end

  local mt = getmetatable(obj)
  if not mt then
    return
  end

  if k then
    return mt[k]
  end
  return mt
end

--- Set metatable or metatable key
--- @param obj table
--- @param k any if v is nil then set k as metatable else retrieve key
--- @param v? any value to set
--- @return any
function mtset(obj, k, v)
  if v == nil then
    return setmetatable(obj, k)
  end

  local mt = getmetatable(obj) or {}
  mt[k] = v

  return setmetatable(obj, mt)
end

--- @param x any
--- @param force? bool forcefully wrap the elem in a table?
--- @return table
function totable(x, force)
  if force then
    return { x }
  elseif type(x) == "table" then
    return x
  else
    return { x }
  end
end

--- Return type based on lua type or <metatable>.type
--- @param x any
--- @return string?
function typeof(x)
  local x_type = type(x)

  if x_type ~= "table" then
    return x_type
  elseif is_list(x) then
    return "list"
  end

  local x_mt = getmetatable(x)
  if not x_mt then
    return "table"
  elseif not x_mt.type then
    return "table"
  else
    return x_mt.type
  end
end

--- Is x a string?
--- @param x any
--- @return boolean,string?
function is_string(x)
  local ok = type(x) == "string"
  local msg = "expected string, got " .. dump(x)

  if not ok then
    return false, msg
  end

  return true
end

--- Is x a table?
--- @param x any
--- @return boolean,string?
function is_table(x)
  local ok = type(x) == "table"

  if not ok then
    local msg = "expected table, got " .. dump(x)
    return false, msg
  end

  return true
end

--- Is x a function?
--- @param x any
--- @return boolean,string?
function is_function(x)
  local ok = type(x) == "function"
  local msg = "expected function, got " .. dump(x)

  if not ok then
    return false, msg
  end

  return true
end

--- Is x a userdata?
--- @param x any
--- @return boolean,string?
function is_userdata(x)
  local ok = type(x) == "userdata"

  if not ok then
    local msg = "expected userdata, got " .. dump(x)
    return false, msg
  end

  return true
end

--- Is x a thread?
--- @param x any
--- @return boolean,string?
function is_thread(x)
  local ok = type(x) == "thread"
  local msg = "expected thread, got " .. dump(x)

  if not ok then
    return false, msg
  end

  return true
end

--- Is x a boolean?
--- @param x any
--- @return boolean,string?
function is_boolean(x)
  local ok = type(x) == "boolean"

  if not ok then
    local msg = "expected boolean, got " .. dump(x)
    return false, msg
  end

  return true
end

--- Is x a number?
--- @param x any
--- @return boolean,string?
function is_number(x)
  local ok = type(x) == "number"

  if not ok then
    local msg = "expected number, got " .. dump(x)
    return false, msg
  end

  return true
end

--- Is x a function (__call is nonnil or x is a function)?
--- @param x any
--- @return boolean,string?
function is_callable(x)
  local tp = type(x)

  if tp == "function" then
    return true
  elseif tp ~= "table" then
    return false, "expected table|function, got " .. dump(tp)
  end

  local mt = getmetatable(x)
  if not mt then
    return false, "metatable missing"
  end

  local ok = mt.__call ~= nil
  if not ok then
    return false, "__call metamethod missing"
  end

  return true
end

--- Is x nil
--- @param x any
--- @return boolean
function is_nil(x)
  return x == nil
end

--- Is empty?
--- @param x string|list
--- @return boolean
function is_empty(x)
  local x_type = type(x)

  if x_type == "string" then
    return #x == 0
  elseif x_type ~= "table" then
    return false
  end

  return size(x) == 0
end

--- Return length of string|non-lists
--- @param t string|table
--- @return integer?
function size(t)
  local t_type = type(t)

  if t_type == "string" then
    return #t
  elseif t_type ~= "table" then
    return
  end

  local n = 0
  for _, _ in pairs(t) do
    n = n + 1
  end

  return n
end

function is_dict(x, dict_like)
  if not is_table(x) then
    return false, "expected table, got " .. dump(x)
  end

  local mt = not dict_like and getmetatable(x)
  if mt and mt.type ~= "dict" then
    return false, "expected dict, got " .. dump(x)
  end

  local len = size(x)
  if len == 0 then
    return false, "expected list, got empty table"
  end

  local ok = len ~= #x
  if not ok then
    return false, "expected dict, got list " .. dump(x)
  end

  return true
end

function is_list(x, list_like)
  if not is_table(x) then
    return false, "expected table, got " .. dump(x)
  end

  local mt = not list_like and getmetatable(x)
  if mt and mt.type ~= "list" then
    return false, "expected list, got " .. dump(x)
  end

  local len = size(x)
  if len == 0 then
    return false, "expected list, got empty table"
  end

  local ok = len == #x
  if not ok then
    return false, "expected list, got dict"
  end

  return true
end

--- @
function is_dict(x, skip_mtcheck)
  if not is_table(x) then
    return false, "expected table, got " .. dump(x)
  elseif not skip_mtcheck then
    local mt = getmetatable(x)
    if mt then
      if mt.type == "dict" then
        return true
      elseif mt.type ~= nil then
        return false, "expected dict, got " .. dump(x)
      end
    end
  end

  local len = size(x)
  if len == 0 then
    return false, "expected dict, got empty table"
  elseif len == #x then
    return false, "expected dict, got list " .. dump(x)
  else
    return true
  end
end

--- Is namespace?
--- @param x any
--- @return boolean,string?
function is_namespace(x)
  local ok = typeof(x) == "namespace"

  if not ok then
    return false
  end

  return true
end

function is_instance(x, name)
  local mt = getmetatable(x)

  if not mt then
    return false, "expected table with metatable, got " .. dump(x)
  end

  if not mt.type and not mt.class then
    return false, "expected class instance, got " .. dump(x)
  elseif name then
    if mt.type ~= name then
      return false, "expected class instance of type " .. name .. ", got " .. dump(x)
    end
  end

  return true
end

function is_literal(x)
  return is_string(x) or is_number(x) or is_boolean(x)
end

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

      if current_sig == "list" then
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
        else
          return sig_name == x_type
        end
      elseif is_function(current_sig) then
        local ok, msg = current_sig(x)
        if not ok then
          failed[#failed + 1] = msg
        end
      elseif sig_type == "string" then
        local opt = string.match(current_sig, "^opt^")
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
local is_a_mt = { type = "namespace" }
is_a = {}
is_a_mt.__index = is_a_mt
setmetatable(is_a, is_a_mt)

function is_a_mt:__index(key)
  if key == "*" or key == "any" then
    return function()
      return true
    end
  end

  if is_function(key) then
    return key
  end

  local key_type = not is_string(key) and typeof(key) or key
  local _, times = key_type:gsub("%?$", "")
  local optional = times > 0

  local Gfun = _G["is_" .. key]
    or function(x)
      local x_type = typeof(x)
      if x_type == nil and optional then
        return true
      elseif x_type ~= key then
        return false, ("expected " .. key_type .. ", got " .. x_type)
      end

      return x
    end

  if not rawget(self, key) then
    rawset(self, key, Gfun)
  end

  return Gfun
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
local assert_is_a_mt = { type = "namespace" }
assert_is_a = {}
setmetatable(assert_is_a, assert_is_a_mt)

--- Usage
--- @param key string|fun(x): boolean,string
--- @return function validator throws an error when validation fails
function assert_is_a_mt:__index(key)
  if is_function(key) then
    return function(x)
      assert(key(x))
      return x
    end
  end

  local key_type = not is_string(key) and typeof(key) or key
  local Gfun = _G["is_" .. key]
    or function(x)
      local x_type = typeof(x)
      if x_type ~= key then
        return false, ("expected " .. key_type .. ", got " .. x_type)
      end

      return x
    end

  local fun = function(x)
    assert(Gfun(x))
    return x
  end

  if not rawget(self, key) then
    rawset(self, key, fun)
  end

  return fun
end

function assert_is_a_mt:__call(obj, expected)
  if is_nil(obj) and is_nil(expected) then
    return true
  end

  return assert_is_a[expected](obj)
end

--------------------------------------------------
function ref(x)
  if is_nil(x) then
    return x
  end

  if not is_table(x) then
    if is_literal(x) then
      return x
    else
      return is_string(x)
    end
  end

  local mt = getmetatable(x)
  if not mt then
    return is_string(x)
  end

  local tostring = rawget(mt, "__tostring")
  rawset(mt, "__tostring", nil)
  local id = tostring(x)
  rawset(mt, "__tostring", tostring)

  return id
end

function sameref(x, y)
  return ref(x) == ref(y)
end

asserttype = assert_is_a

--------------------------------------------------
function class(name, static)
  static = static or {}

  if static[1] then
    for i = 1, #static do
      static[static[i]] = true
      static[i] = nil
    end
  end

  if not is_string(name) then
    error("expected string, got " .. type(name))
  end

  local mod = {}
  local modmt = { type = "classmod", __tostring = dump }
  local classmt = { type = name, __tostring = dump }

  setmetatable(mod, modmt)

  function modmt:__call(...)
    local obj = mtset({}, classmt)
    static = static or {}

    for key, value in pairs(self) do
      if not static[key] then
        obj[key] = value
      end
    end

    local init = rawget(mod, "init")
    if init then
      return init(obj, ...)
    end

    return obj
  end

  function modmt:__newindex(key, value)
    if mtkeys[key] then
      modmt[key] = value
      classmt[key] = value
    else
      rawset(self, key, value)
    end
  end

  modmt.__index = modmt
  classmt.__index = classmt

  function mod.is_a(self)
    if not is_table(self) then
      return false
    end

    local mt = getmetatable(self)
    if not mt then
      return false
    elseif not mt.type then
      return false
    elseif mt.type ~= name then
      return false
    end

    return true
  end

  function mod.assert_is_a(self)
    if not mod.is_a(self) then
      error("expected " .. name .. ", got " .. dump(self))
    end

    return self
  end

  function mod:include(other)
    if not is_table(other) then
      return
    end

    for key, value in pairs(other) do
      self[key] = value
    end

    return self
  end

  function mod.get_classmod()
    return mod
  end

  function mod.get_module_name()
    return name
  end

  function mod:get_methods()
    return dict.filter(self, function(_, value)
      return is_callable(value)
    end)
  end

  function mod:create_instance_method(fn)
    assert_is_a(fn, union('string', 'callable'))

    if is_string(fn) then
      return self:get_method(fn)
    end

    return function(...)
      return fn(self, ...)
    end
  end

  function mod:get_method(fun)
    local ok = self[fun]

    if not ok then
      return nil, 'invalid method name: ' .. dump(fun)
    else
      return ok
    end
  end

  return mod
end
