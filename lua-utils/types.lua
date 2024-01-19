require "lua-utils.copy"

inspect = require "inspect"
inspect = inspect.inspect
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

  if k ~= nil then
    return mt[k]
  end

  return mt
end

--- Set metatable or metatable key
--- @param obj table
--- @param k any if v is nil then set k as metatable else retrieve key
--- @param v? any value to set
--- @return any
function mtset(...)
  local n = select("#", ...)
  local args = { ... }
  x = args[1]

  if n == 1 then
    error("need at least 2 params, got " .. n)
  elseif n == 2 then
    local mt = args[2]
    if type(mt) ~= "table" then
      return
    end

    return setmetatable(x, mt)
  end

  local mt = getmetatable(x) or {}
  mt[args[2]] = args[3]

  return setmetatable(x, mt)
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

--- Create a namespace. It is possible to set metatable keys and retrieve them. Supports tostring()
--- @return table
function namespace(name)
  local mod = {}
  local mt = { __tostring = dump, type = "namespace", name = name }

  function mt:__newindex(key, value)
    if mtkeys[key] then
      mt[key] = value
    else
      rawset(self, key, value)
    end
  end

  function mt:__index(key)
    if mtkeys[key] then
      return mt[key]
    end
  end

  function mod:get_module_name()
    return mtget(self, "name")
  end

  function mod:include_module(other)
    return dict.merge(mod, { other })
  end

  function mod:get_methods()
    return dict.filter(self, function(_, value)
      return is_callable(value)
    end)
  end

  function mod:get_method(fn)
    if not self[fn] then
      return nil, "invalid method name " .. dump(fn)
    end

    return function(...)
      return fn(self, ...)
    end
  end

  function mod:get_module()
    return self or mod
  end

  return setmetatable(mod, mt)
end

--- Is namespace?
--- @param x any
--- @return boolean,string?
function is_namespace(x)
  local ok = typeof(x) == "namespace"

  if not ok then
    return false, "expected namespace, got " .. dump(x)
  end

  return x
end

function is_class(self)
  local ok = typeof(self)

  if ok ~= "class" then
    return false, "expected class, got " .. dump(self)
  end

  return self
end

function is_instance(self)
  return mtget(self, "instance") and self
end

function is_literal(x)
  return is_string(x) or is_number(x) or is_boolean(x)
end

---

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

      if current_sig == "*" or current_sig == "any" then
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
        elseif sig_name == "class" or instance then
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
  local f = union(key)
  return function(x)
    return f(x)
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

--------------------------------------------------
class = namespace "class"

local non_class_attribs = {
  new = true,
  init = true,
  get_module_parent = true,
  get_module = true,
  get_module_name = true,
  is_a = true,
  include_module = true,
  get_methods = true,
  get_method = true,
  get_attribs = true,
  is_child_of = true,
  is_parent_of = true,
  super = true,
}

function class:get_attribs(exclude_callables)
  assert_is_a.class(self)

  return dict.filter(self, function(key, value)
    if exclude_callables and is_callable(value) then
      return false
    end
    return not non_class_attribs[key]
  end)
end

function class:get_module_parent()
  return mtget(self, "parent")
end

local check_type = function(x)
  return is_class(x) or is_instance(x)
end

function class:is_child_of(other)
  if not check_type(self) then
    return
  end

  local check_name = check_type(other) or is_string(other)
  if not check_name then
    return
  end

  check_name = not is_string(other) and other:get_module_name() or other
  local self_parent = self:get_module_parent()
  local self_parent_name

  if not self_parent then
    return
  else
    self_parent_name = self_parent:get_module_name()
  end

  while self_parent_name ~= check_name do
    self_parent = self_parent:get_module_parent()
    if not self_parent then
      return
    else
      self_parent_name = self_parent:get_module_name()
    end
  end

  return self
end

function class:is_parent_of(other)
  return class.is_child_of(other, self)
end

function class:is_a(other)
  local check = function(x)
    return check_type(x) or is_string(x)
  end

  if not check(other) then
    return
  elseif not is_string(other) then
    other = other:get_module_name()
  end

  local ok = self:get_module_name() == other
  if not ok then
    return self:is_child_of(other)
  end

  return self
end

function class:new(name, static, opts)
  opts = opts or {}
  local classmod = namespace(name)
  local classmodmt = mtget(classmod)
  local parent = opts.parent
  static = copy(static or {})
  classmodmt.static = static
  classmodmt.type = "class"
  classmodmt.parent = parent

  if static then
    assert_is_a.table(static)
  end
  local exclude = {
    get_super_method = true,
    super = true,
    new = true,
    init = true,
  }

  if static[1] then
    for i = 1, #static do
      static[static[i]] = true
    end
  end

  classmod.is_a = class.is_a
  classmod.is_child_of = class.is_child_of
  classmod.is_parent_of = class.is_parent_of
  classmodmt.module = classmod

  dict.merge2(classmod, class)

  if parent then
    assert_is_a.class(parent)
    classmodmt.parent = parent
  end

  function classmodmt:__newindex(key, value)
    if mtkeys[key] then
      classmodmt[key] = value
    else
      rawset(self, key, value)
    end
  end

  function classmodmt:__index(key)
    if class[key] then
      return class[key]
    end

    local parent = self:get_module_parent()
    if parent then
      return parent[key]
    end
  end

  function classmod:get_module()
    return mtget(self, "module")
  end

  function classmod:get_module_parent()
    return mtget(self, "parent")
  end

  function classmod:get_module_name()
    return mtget(self, "name")
  end

  function classmod:get_super_method()
    local parent = self:get_module_parent()

    while parent do
      local init = parent.init
      if init then
        return init
      end

      parent = parent:get_module_parent()
    end

    error('no init defined for ' .. dump(self))
  end

  function classmod:super(obj, ...)
    local super_fn = self:get_super_method()
    return super_fn(obj, ...)
  end

  local objmt = { type = name, __tostring = dump, instance = true, module = classmod }

  function objmt:__index(key)
    if key == 'super' or key == 'get_super_method' then
      return
    end

    local ok = classmod[key]
    if ok then
      return ok
    end

    local parent = self:get_module_parent()
    if parent then
      return parent[key]
    end
  end

  function objmt:__newindex(key, value)
    if mtkeys[key] then
      objmt[key] = value
    else
      rawset(self, key, value)
    end
  end

  function classmod:get_static_methods()
    return mtget(self, "static")
  end

  function classmod:new(...)
    local obj = mtset({}, objmt)

    dict.merge2(obj, classmod)
    local static = self:get_static_methods()

    for key, value in pairs(classmod) do
      if not static[key] and not exclude[key] then
        obj[key] = value
      end
    end

    function obj:get_module()
      return mtget(self, 'module')
    end

    function obj.get_module_parent()
      return classmod:get_module_parent()
    end

    function obj.get_module_name()
      return classmod:get_module_name()
    end

    local init = self.init
    if init then
      return init(obj, ...)
    else
      return self:super(obj, ...)
    end
  end

  classmodmt.__call = classmod.new

  return classmod
end

class.__call = class.new
