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
--- > -- this will set the metatable
--- > mtset({}, {})
--- > 
--- > -- this will set this value
--- > mtset(obj, 'a', 'b')
--- @param ... any 
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

to_table = totable
to_string = tostring
to_number = tonumber

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

--- Check if a X is a nonempty list of elements
--- @param x any[] x should not have a metatable unless the latter is defined
--- @param list_like? boolean skip metatable check 
--- @return any[]|false
--- @return string? message failure message
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

  return x
end

--- Check if a X is a nonempty table that is not a list
--- @param x table x should not have a metatable unless the latter is defined
--- @param dict_like? boolean skip metatable check 
--- @return table|false
--- @return string? message failure message
function is_dict(x, dict_like)
  if not is_table(x) then
    return false, "expected table, got " .. dump(x)
  elseif not dict_like then
    local mt = getmetatable(x)
    if mt then
      if mt.type == "dict" then
        return x
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
    return x
  end
end

--- Define a namespace which is essentially a table with functions and other attributes
--- Contains several useful methods to query the properties of the namespace
--- You can also set metatable attributes directly via with the namespace table
--- Useful for skeleton classes
--- @class namespace
--- @overload fun(name?: string): namespace
namespace = {}
ns = namespace
local namespace_mt = { __tostring = dump, type = "namespace", module = namespace}
mtset(namespace, namespace_mt)

function namespace_mt:__call(name)
  local mt = copy(namespace_mt)
  mt.name = name
  return mtset(copy(namespace) --[[@as namespace]], mt)
end

function namespace_mt:__newindex(key, value)
  if mtkeys[key] then
    mtset(self, key, value)
  else
    rawset(self, key, value)
  end
end

function namespace_mt:__index(key)
  if mtkeys[key] then
    return mtget(self, key)
  end
end

--- Get module name if defined
--- @return string?
function namespace:get_module_name()
  return mtget(self, "name")
end

--- Include this table (basically merge the table)
--- @param other table
--- @return namespace
function namespace:include_module(other)
  return dict.merge(mod,  other)
end

--- Get all callables in a dict with their names
--- @return table<any,function>
function namespace:get_methods()
  return dict.filter(self, function(_, value)
    return is_callable(value)
  end)
end

--- Get method as a function or an instance method
--- @param name any
--- @param inst_method? boolean instance method as f(self, ...)
--- @return function?
--- @return string? message failure message
function namespace:get_method(name, inst_method)
  local f = self[name]
  if not f then
    return nil, "invalid method name " .. dump(fn)
  end

  assert(is_callable(f))

  if inst_method then
    return function (...)
      return f(self, ...)
    end
  end

  return function(...)
    return fn(self, ...)
  end
end

--- Return the reference of current module
--- @return namespace
function namespace:get_module()
  return mtget(self, 'module')
end

--- Default method for creating an object inheriting the namespace's attributes
--- @param init? function init callable to use
--- @return table
function namespace:create_instance(init, ...)
  local obj = copy(self)
  local mt = mtget(self)
  mt.type = obj:get_module_name()
  mt.__call = nil
  mt.name = nil
  mt.instance = true
  obj.create_instance = nii

  --- @cast obj namespace

  if init then
    return init(obj, ...)
  end
  
  return obj
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

is_ns = is_namespace

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
--- Type checking module
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
local is_a_mt = { type = "namespace", name = 'is_a' }
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
local assert_is_a_mt = { type = "namespace" }
mtset(assert_is_a, assert_is_a_mt)

function assert_is_a_mt:__index(key)
  return function (x)
    return is_a[key](x, true)
  end
end

function assert_is_a_mt:__call(obj, spec)
  return is_a[spec](obj, true)
end

--------------------------------------------------

--- Get table reference string. This will temporarily modify tables with custom __tostring methods
--- @param x table
--- @return string
function ref(x)
  if not is_table(x) then
    return 
  end

  local mt = getmetatable(x)
  if not mt then
    return tostring(x)
  end

  local tostring = rawget(mt, "__tostring")
  rawset(mt, "__tostring", nil)
  local id = tostring(x)
  rawset(mt, "__tostring", tostring)

  return id
end

--- Check if x and y point to the same object
--- @param x table
--- @param y table
--- @return boolean
function sameref(x, y)
  return ref(x) == ref(y)
end

--------------------------------------------------

--- Create a class module to create instances
--- @class class : namespace
--- @overload fun(name: string, static_methods: string[], opts: {parent?: class, include?: table}): class
class = namespace "class" --[[@as class]]

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

--- Get attributes w/o callables
--- @param exclude_callables? boolean
--- @return table<string,any>
function class:get_attribs(exclude_callables)
  return dict.filter(self, function(key, value)
    if exclude_callables and is_callable(value) then
      return false
    end
    return not non_class_attribs[key]
  end)
end

--- Get parent for instance/classmodule
--- @return table?
function class:get_module_parent()
  return mtget(self, "parent")
end

local check_type = function(x)
  return is_class(x) or is_instance(x)
end

--- Is Y a child of self
--- @param other class|string class or class name
--- @return class?
function class:is_child_of(other)
  if not check_type(self) then
    return
  end

  local check_name = check_type(other) or is_string(other)
  if not check_name then
    return
  end

  ---@diagnostic disable-next-line: param-type-mismatch
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

--- Is Y parent of self
--- @param other class|string class or class name
--- @return class?
function class:is_parent_of(other)
  ---@diagnostic disable-next-line: param-type-mismatch
  return class.is_child_of(other, self)
end

--- Check if Y is a parent of self or self itself
--- @param other class|string
function class:is_a(other)
  local check = function(x)
    return check_type(x) or is_string(x)
  end

  if not check(other) then
    return
  elseif not is_string(other) then
    ---@diagnostic disable-next-line: param-type-mismatch
    other = other:get_module_name()
  end

  local ok = self:get_module_name() == other
  if not ok then
    return self:is_child_of(other)
  end

  return self
end

function class:__call(name, static, opts)
  opts = opts or {}

  local classmod = namespace(name) --[[@as class]]
  local classmodmt = mtget(classmod)
  local parent = opts.parent
  local include = opts.include
  static = copy(static or {})
  classmodmt.static = static
  classmodmt.type = "class"
  classmodmt.parent = parent

  assert_is_a.table(static)

  local exclude = {
    get_static_methods = true,
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

  dict.merge(classmod, cls)

  if include then
    dict.merge(classmod, include)
  end

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

    local p = self:get_module_parent()
    if p then
      return p[key]
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

  ---@diagnostic disable-next-line: inject-field
  function classmod:get_super_method()
    local _parent = self:get_module_parent()

    while _parent do
      local init = _parent.init
      if init then
        return init
      end

      _parent = _parent:get_module_parent()
    end

    error('no init defined for ' .. dump(self))
  end

  ---@diagnostic disable-next-line: inject-field
  function classmod:super(obj, ...)
    local super_fn = self:get_super_method()
    return super_fn(obj, ...)
  end

  local objmt = { type = name, __tostring = dump, instance = true, module = classmod, static = static }

  function objmt:__index(key)
    if key == 'super' or key == 'get_super_method' then
      return
    end

    local ok = classmod[key]
    if ok then
      return ok
    end

    local _parent = self:get_module_parent()
    if _parent then
      return _parent[key]
    end
  end

  function objmt:__newindex(key, value)
    if mtkeys[key] then
      objmt[key] = value
    else
      rawset(self, key, value)
    end
  end

  ---@diagnostic disable-next-line: inject-field
  function classmod:get_static_methods()
    return mtget(self, "static")
  end

  function classmod:__call(...)
    local obj = mtset({}, objmt)
    local static_methods = self:get_static_methods()

    --- @cast obj class

    for key, value in pairs(classmod) do
      if not static_methods[key] and not exclude[key] then
        obj[key] = value
      end
    end

    function obj:get_module_name()
      return mtget(self, 'type')
    end

    ---@diagnostic disable-next-line: undefined-field
    local init = self.init

    if init then
      return init(obj, ...)
    else
      return self:super(obj, ...)
    end
  end

  return classmod
end
