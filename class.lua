--- Classes in lua
-- @classmod class
local dict = require "lua-utils.dict"
local types = require "lua-utils.types"
local utils = require "lua-utils.utils"
local array = require "lua-utils.array"

--------------------------------------------------------------------------------
local mt = {}
local class = setmetatable({}, mt)

--------------------------------------------------------------------------------
class.valid_mt_keys = {
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

--- Methods for comparing classes via common __eq, __ne methods
-- @table class.comparators
class.comparators = utils.copy(class.valid_mt_keys)
class.comparators.__tostring = nil
class.comparators.__tonumber = nil
class.comparators.__index = nil
class.comparators.__newindex = nil
class.comparators.__call = nil
class.comparators.__metatable = nil
class.comparators.__mode = nil

--- Compare classes by attributes. Tables will be deep compared
-- @static
-- @tparam class cls
-- @tparam class other
-- @treturn boolean
function class.comparators.eq(cls, other)
  for key, value in pairs(cls) do
    if not class[key] and not class.valid_mt_keys[key] and not other[key] then
      return false
    end
  end

  for key, value in pairs(other) do
    if not class[key] and not class.valid_mt_keys[key] then
      local cls_value = cls[key]
      local cls_value_t = types.typeof(cls_value)
      local value_t = types.typeof(value)

      if not cls_value then
        return false
      elseif cls_value_t ~= value_t then
        return false
      elseif
        cls_value_t == "table" and not dict.compare(cls_value, value, nil, true)
      then
        return false
      elseif cls_value ~= value then
        return false
      end
    end
  end

  return true
end

--- Compare classes by attributes. Tables will not be deep compared
-- @static
-- @tparam class cls
-- @tparam class other
-- @treturn boolean
function class.comparators.equal(cls, other)
  for key, value in pairs(cls) do
    if not other[key] then
      return false
    end
  end

  for key, value in pairs(other) do
    if not class[key] and not class.valid_mt_keys[key] then
      if not cls[key] then
        return false
      elseif cls[key] ~= value then
        return false
      end
    end
  end

  return true
end

--- Compare classes by name
-- @static
-- @tparam class cls
-- @tparam class other
-- @treturn boolean
function class.comparators.name(cls, other)
  return types.get_name(cls) == types.get_name(other)
end

--- Compare classes by name
-- @static
-- @tparam class cls
-- @tparam class other
-- @see class.comparators.name
function class.comparators.not_name(cls, other)
  return not class.comparators.name(cls, other)
end

--- Compare classes by attributes
-- @static
-- @tparam class cls
-- @tparam class other
-- @see class.comparators.eq
function class.comparators.not_eq(cls, other)
  return not class.comparators.eq(cls, other)
end

--- Compare classes by attributes
-- @static
-- @tparam class cls
-- @tparam class other
-- @see class.comparators.equal
function class.comparators.not_equal(cls, other)
  return not class.comparators.equal(cls, other)
end

--- Get class name
-- @static
-- @function class.get_name
-- @tparam class x
-- @treturn string
function class.get_name(x)
  if not types.is_class(x) then
    return
  end
  return types.get_name(x)
end

--- Is class1 instance of class2?
-- @static
-- @tparam instance inst
-- @tparam class cls
-- @treturn boolean
function class.is_instance_of(inst, cls)
  return class.is_instance(inst)
      and class.get_class(inst) == class.get_class(cls)
    or false
end

--- Get all ancestors of class
-- @static
-- @tparam class cls
-- @treturn array[ancestors]
function class.get_ancestors(cls)
  cls = class.get_class(cls)
  local ancestors = {}
  local ancestor = class.get_parent(cls)
  if not ancestor then
    return
  end
  ancestors[1] = ancestor
  local i = 2

  while ancestor do
    ancestor = class.get_parent(ancestor)
    if ancestor then
      ancestors[i] = ancestor
      i = i + 1
    end
  end

  return array.reverse(ancestors)
end

--- Is class1 parent of class2?
-- @static
-- @tparam class cls
-- @tparam class inst
-- @treturn boolean
function class.is_parent_of(cls, inst)
  cls = class.get_class(cls)
  inst = class.get_parent(inst)

  if not cls or not inst then
    return false
  end

  return cls == inst
end

--- Get class
-- @static
-- @tparam any x
-- @treturn ?class
function class.get_class(x)
  return types.get_class(x)
end

--- Get parent of a class
-- @static
-- @tparam any x
-- @treturn ?class
function class.get_parent(x)
  return utils.mtget(class.get_class(x), "parent")
end

--- Is x a class instance?
-- @static
-- @tparam any x
-- @treturn boolean
function class.is_instance(x)
  return class.is_class(utils.mtget(x))
end

--- Is class1 a parent/ancestor of class2?
-- @static
-- @tparam class x
-- @tparam class y
-- @treturn boolean
function class.is_ancestor_of(x, y)
  if not types.is_class(x) or not types.is_class(y) then
    return false
  end

  x = x:get_class()
  y = y:get_class()
  local parent = x
  local child_parent = class.get_parent(y)

  if not child_parent then
    return false
  elseif parent == child_parent then
    return true
  end

  while child_parent do
    if parent == child_parent then
      return true
    end
    child_parent = child_parent:get_parent()
  end

  return false
end

--- Get class methods
-- @static
-- @tparam class obj
-- @treturn dict of methods
function class.get_methods(obj)
  return dict.grep(obj, function(_, value)
    return types.is_callable(value)
  end)
end

--- Get class variables
-- @static
-- @tparam class obj
-- @treturn dict of variables
function class.get_vars(obj)
  return dict.grep(obj, function(_, value)
    return types.is_callable(value) ~= true
  end)
end

--- Get a specific class method
-- @static
-- @tparam class obj
-- @tparam any k method name
-- @treturn callable
function class.get_method(obj, k)
  local methods = class.get_methods(obj)
  if not methods then
    return
  end
  return methods[k]
end

--- Get a specific class variable
-- @static
-- @tparam class obj
-- @tparam any k variable name
-- @treturn any
function class.get_var(obj, k)
  local vars = class.get_vars(obj)
  if not vars then
    return
  end
  return vars[k]
end

--- Get a specific class attribute
-- @static
-- @tparam class obj
-- @tparam any k attribute name
-- @treturn any
function class.get_attrib(obj, k)
  return obj[k]
end

--- Get class attributes
-- @static
-- @tparam class obj
-- @treturn dict of attributes
function class.get_attribs(obj)
  local out = {}
  for key, value in pairs(obj) do
    out[key] = value
  end
  return out
end

--- Do both objects have the same instance variables excluding the common ones?
-- @static
-- @tparam class x class 1
-- @tparam class y class 2
-- @treturn boolean
function class.are_same_shape(x, y)
  local x_attribs = dict.grep(x:get_vars(), function(key, value)
    if not class[key] then
      return value
    end
  end)
  local y_attribs = dict.grep(y:get_vars(), function(key, value)
    if not class[key] then
      return value
    end
  end)

  return dict.compare(x_attribs, y_attribs, nil, true)
end

--- Include struct in a class
-- @static
-- @tparam class obj
-- @tparam dict t of attributes
-- @tparam dict opts optional options
-- @tparam any opts.attrib use this attribute while using method with that class
-- @treturn class
function class.include(obj, t, opts)
  assert(
    types.is_table(t) or types.is_class(t),
    "table expected, got " .. tostring(t)
  )

  opts = opts or {}

  dict.each(t, function(key, value)
    if not types.is_callable(value) then
      obj[key] = value
    elseif opts.attrib then
      obj[key] = function(self, ...)
        if class.is_instance(self) then
          return value(self[opts.attrib], ...)
        else
          return value(self, ...)
        end
      end
    elseif not opts.ignore_methods then
      obj[key] = value
    end
  end)

  return obj
end

--- Is class1 child of class2?
-- @static
-- @tparam class child
-- @tparam class parent
-- @treturn boolean
function class.is_child_of(child, parent)
  return class.get_parent(child) == class.get_class(parent)
end

--- Get the init method of the parent class. Instances do not have this method
-- @static
-- @usage
-- local grandparent = class 'grandparent'
-- function grandparent:init()
--   self.grandparent = true
-- end
--
-- local parent = class('parent', grandparent)
-- function parent:init()
--   parent:super()(self)
--   self.parent = true
-- end
--
-- local child = class('child', parent)
-- local a_child = child()
-- -- a_child.parent is true
-- -- a_child.grandparent is true
--
-- @tparam class obj
-- @treturn callable
function class.super(obj)
  local parent = obj:get_parent()
  if parent and parent.init then
    return parent.init
  end
end

--- Is x and y of the same class?
-- @static
-- @tparam class x
-- @tparam class y
-- @treturn boolean
function class.is_a(x, y)
  return x == y
    or class.get_class(x) == class.get_class(y)
    or class.is_ancestor_of(y, x)
    or false
end

--------------------------------------------------
--- Is x a class?
-- @static
-- @tparam any x
-- @treturn boolean
function class.is_class(x)
  return types.is_class(x)
end

--- Constructor to make a new class
-- @static
-- @usage
-- A = class 'A'
-- A = class.new 'A'
-- @tparam string name Name of the class
-- @tparam class parent base class
-- @tparam dict opts optional options
-- @tparam string opts.__eq comparator to use with class
-- @tparam table opts.include include attributes in this table
-- @tparam dict opts.defaults default class attributes
-- @treturn instance
function class.new(name, parent, opts)
  if parent then
    parent = class.get_class(parent)
  end

  opts = opts or {}
  local mt = { name = name, parent = parent, type = "class" }
  local cls = setmetatable(utils.copy(class), mt)
  mt.ref = tostring(cls):gsub("^[^:]+: ", "")
  local __eq = opts.__eq
  local include = opts.include
  local attrib = opts.attrib
  local defaults = opts.defaults

  if __eq then
    local eq, ne = class.comparators[__eq], class.comparators["not_" .. __eq]
    assert(eq, 'expected comparator with "==" op')
    assert(ne, 'expected comparator with "=~" op')
    cls.__eq = eq
    cls.__ne = ne
    mt.__eq = eq
    mt.__ne = ne
  end

  if include and attrib then
    class.include(cls, include, { attrib = attrib })
  elseif include then
    class.include(cls, include)
  end

  if defaults then
    dict.merge(cls, defaults)
  end

  function cls:__newindex(k, v)
    if class.valid_mt_keys[k] then
      mt[k] = v
    end
    rawset(self, k, v)
  end

  function cls:__index(k)
    if class[k] then
      return class[k]
    elseif mt[k] then
      return mt[k]
    else
      return parent and parent[k]
    end
  end

  function cls:__tostring()
    local ref = utils.mtget(class.get_class(self), "ref") or ""
    local cls_name = class.get_name(self)

    return cls_name and cls_name .. ": " .. ref or ref
  end

  function cls.new(...)
    local obj = setmetatable(utils.copy(cls), cls)
    obj.shape = nil
    obj.super = nil

    if obj.init then
      obj:init(...)
    else
      local parent_init = obj:super()
      if parent_init then
        parent_init(obj)
      end
    end

    return obj
  end

  mt.__index = cls.__index
  mt.__newindex = cls.__newindex
  mt.__tostring = cls.__tostring
  function mt:__call(...)
    return cls.new(...)
  end

  return cls
end

--- Treat class like a struct
-- @static
-- @tparam class name class name
-- @tparam class parent base class
-- @tparam[opt={}] dict opts optional options
-- @see class.new
-- @treturn instance
function class.shape(name, parent, opts)
  opts = opts or {}
  opts.__eq = opts.__eq or "eq"

  return class.new(name, parent, opts)
end

function mt:__call(name, parent, opts)
  return class.new(name, parent, opts)
end

function class:todict(f)
  if f then
    return f(self)
  end
  local out = {}

  dict.each(self, function(k, v)
    if not class[k] and not class.valid_mt_keys[k] then
      out[k] = v
    end
  end)

  return out
end

return class
