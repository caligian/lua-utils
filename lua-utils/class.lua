local list = require 'lua-utils.list'

---@generic T

---Create classes and instances
---@overload fun(name: string, inherits?: class, defaults?: table<string|number,any>): table
class = bless {
  __type = 'callable',
  __name = 'class'
}
class.__index = class
class.is_object = is_object
class.is_class = is_class
class.is_instance = is_instance
class.inherits = inherits
class.instanceof = instanceof
class.get_name = class_name

---Get object or its descendant's initialize
---@param obj instance
---@param ... any additional args
function class.initialize(obj, ...)
  local function find_init(x)
    if x.__instance then
      x = x.__class
    end

    if x.initialize then
      return x.initialize
    elseif not x.__inherits then
      return
    end

    x = x.__inherits
    if x.initialize then
      return x.initialize
    else
      return find_init(x)
    end
  end

  local init = find_init(obj)
  if init then init(obj, ...) end
end

---Get object methods
---@param x object
---@return table<string,function | table>
function class.get_methods(x)
  local res = {}
  for key, _ in pairs(x.__methods) do
    res[key] = x[key]
  end
  return res
end

---Get object attributes which are not methods
---@param x object
---@return table<string,any>
function class.get_attributes(x)
  local res = {}
  for key, _ in pairs(x.__attributes) do
    res[key] = x[key]
  end
  return res
end

---Get object attribute which is not a method
---@param x table
---@param attrib string
---@return any
function class.get_attribute(x, attrib)
  if x.__attributes[attrib] then
    return x[attrib]
  end
end

---Get object method
---@param x table
---@param method string
---@return function?
function class.get_method(x, method)
  local fn = x.__methods[method]
  if fn then
    return x[method]
  end
end

---Get object metamethods
---@param x table
---@return table<string,function | table>
function class.get_metamethods(x)
  local res = {}
  for key, _ in pairs(x.__metamethods) do
    res[key] = x[key]
  end
  return res
end

---Get object metaattributes
---@param x table
---@return table<string,any>
function class.get_metaattributes(x)
  local res = {}
  for key, _ in pairs(x.__metaattributes) do
    res[key] = x[key]
  end
  return res
end

---Merge attributes and methods from table
---@param x table
---@param from table
---@return table
function class.include(x, from)
  for key, value in pairs(from) do
    if x[key] == nil then x[key] = value end
  end

  return x
end

---Get object's class or return the object if it is a class
---@param x table
---@return table?
function class.get_class(x)
  if not class.is_object(x) then
    return nil
  elseif x.__instance then
    return x.__class
  else
    return x
  end
end

---Set object attribute
---@param x table
---@param key string
---@param value any
function class.set(x, key, value)
  local is_meta = key:match '^__'
  local is_method = callable(value)
  local is_metamethod = is_meta and is_method
  local is_metaattrib = is_meta and not is_method
  local is_attrib = not is_method

  rawset(x, key, value)
  local store

  if is_metamethod then
    store = x.__metamethods
  elseif is_metaattrib then
    store = x.__metaattributes
  elseif is_attrib then
    store = x.__attributes
  elseif is_method then
    store = x.__methods
  end

  store[key] = true
  return x
end

---Create a partial instance method with the object as the first argument
---@param x table
---@param method string
---@return function?
function class.make_instance_method(x, method)
  if not x[method] then
    return nil
  else
    return function(...)
      return x[method](x, ...)
    end
  end
end

---Get object parents
---@param obj table
---@return table[]?
function class.get_parents(obj)
  assert(class.is_object(obj))

  obj = class.get_class(obj)
  local parents = {}

  if not obj.__class then
    return
  else
    parents[#parents + 1] = obj.__class
  end

  local parent = parents[1]
  while parent do
    parent = parent.__inherits
    if not parent then
      break
    else
      parents[#parents + 1] = parent
    end
  end

  parents = list.reverse(parents)
  return parents
end

---Create an instance of the object
---@param cls table
---@param ... any initialize arguments
---@return instance
function class.make_instance(cls, ...)
  cls = class.get_class(cls) or cls
  local obj = {
    __attributes = {},
    __methods = {},
    __metamethods = {},
    __metaattributes = {
      __metaattributes = true,
      __metamethods = true,
      __attributes = true,
      __methods = true,
    },
  }

  setmetatable(obj, cls)

  for key, value in pairs(cls) do
    obj[key] = value
  end

  obj.__call = nil
  obj.__instance = true
  obj.__class = cls
  obj.__index = cls

  if cls.initialize then
    cls.initialize(obj, ...)
  else
    class.initialize(obj, ...)
  end

  return obj
end

---@param name string
---@param parent class
---@param defaults? table<string|number,any>
---@return class
function class.make_class(name, parent, defaults)
  is.string(name, { assert = true, prefix = 'name' })
  is.class(parent, { assert = true, opt = true, prefix = 'parent' })
  is.table(defaults, { assert = true, opt = true, prefix = 'defaults' })

  local function copy_attribs(attrib, cls, p)
    local parent_attribs = p[attrib]
    for key, value in pairs(parent_attribs) do
      rawset(cls[attrib], key, value)
    end
  end

  local skip = {
    __metaattributes = true,
    __metamethods = true,
    __attributes = true,
    __methods = true,
  }

  local cls = {
    __attributes = {},
    __methods = {},
    __metamethods = {},
    __metaattributes = {
      __metaattributes = true,
      __metamethods = true,
      __attributes = true,
      __methods = true,
    },
  }

  cls = cls

  if parent then
    class.set(cls, '__class', parent)

    for key, value in pairs(parent) do
      if not skip[key] then
        class.set(cls, key, value)
      end
    end

    copy_attribs('__attributes', cls, parent)
    copy_attribs('__methods', cls, parent)
    copy_attribs('__metaattributes', cls, parent)
    copy_attribs('__metamethods', cls, parent)
  end

  class.set(cls, '__name', name)
  class.set(cls, '__type', 'class')
  class.set(cls, '__call', class.make_instance)

  if not cls.__index then
    cls.__index = rawget
  end

  if not cls.__newindex then
    cls.__newindex = class.set
  end

  if cls.__class then
    setmetatable(cls, cls.__class)
  else
    setmetatable(cls, cls)
  end

  return cls
end

---@param name string
---@param parent? class
---@param defaults? table<string|number,any>
---@return table
function class.new(name, parent, defaults)
  return class(name, parent, defaults)
end

---@param name string
---@param parent class
---@param defaults? table<string|number,any>
---@return table
function class:__call(name, parent, defaults)
  return class.make_class(name, parent, defaults)
end


-- ---@class X : X.class : instance
-- ---@class Y : Y.class : instance
--
-- ---@class X.class : class
-- ---@field a number
-- ---@field b number
-- ---@overload fun(...): X
-- local X = class 'X'
--
-- X.a = 1
-- X.b = 2
--
-- function X:print()
-- end
--
-- ---@class Y.class : X.class
-- ---@field c number
-- ---@overload fun(...): Y
-- local Y = class('Y', X)
-- local y = Y()
-- y:print()
--
defclass = class.new
