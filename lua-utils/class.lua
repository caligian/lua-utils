local list = require 'lua-utils.list'
local copy = require 'lua-utils.copy'
require 'lua-utils.utils'

---@class class
---@field __attributes table<string,boolean> All class attributes set
---@field __methods table<string,boolean> All class methods set
---@field __metamethods table<string,boolean> All class metamatehods set
---@field __metaattributes table<string,boolean> All class metaattributes (variables starting with '__')
---@field __object boolean Always true for classes and instances
---@field __instance boolean Always true for instances and false otherwise
---@field __inherits? class class to inherit from
---@field __name string class name

---@class instance : class
---@field __class class Underlying class

---@alias object class | instance

---Create classes and instances
---@overload fun(name: string, inherits?: table, ...: any): class
local class = {}

setmetatable(class, class)

---Is table an object
---@param obj table
---@return boolean, string?
function class.is_object(obj)
  if type(obj) ~= 'table' then
    return false, ('expected table, got ' .. dump(obj))
  elseif not obj.__object then
    return false, ('expected object, got ' .. dump(obj))
  else
    return true
  end
end

---Is table an instance
---@param obj table
---@return boolean, string?
function class.is_instance(obj)
  if type(obj) ~= 'table' then
    return false, ('expected table, got ' .. dump(obj))
  elseif not obj.__object then
    return false, ('expected object, got ' .. dump(obj))
  elseif not obj.__instance then
    return false, ('expected instance, got class: ' .. dump(obj))
  else
    return true
  end
end

---Is table an class?
---@param obj table
---@return boolean, string?
function class.is_class(obj)
  if type(obj) ~= 'table' then
    return false, ('expected table, got ' .. dump(obj))
  elseif not obj.__object then
    return false, ('expected object, got ' .. dump(obj))
  elseif obj.__instance then
    return false, ('expected class, got instance: ' .. dump(obj))
  else
    return true
  end
end

---Does object inherit class?
---@param obj object
---@param cls object
---@return boolean
function class.inherits(obj, cls)
  assert(class.is_object(obj))
  assert(class.is_object(cls))

  cls = cls.__instance and cls.__class or cls
  obj = obj.__instance and obj.__class or obj

  if obj == cls then
    return true
  end

  local parent = obj.__inherits
  while true do
    if not parent then
      return false
    elseif parent == cls then
      return true
    else
      parent = parent.__inherits
    end
  end
end

---Is class parent of obj?
---@param cls object
---@param obj object
---@return boolean
function class.is_parent_of(cls, obj)
  return class.inherits(cls, obj)
end

---Is class child of obj?
---@param obj object
---@param cls object
---@return boolean
function class.is_child_of(obj, cls)
  return class.inherits(obj, cls)
end

---Clone object
---@param x object
---@param deep? boolean deep clone object?
---@return object
function class.copy(x, deep)
  return copy(x, deep)
end

---Get object or its descendant's initialize
---@param obj object
---@param ... any additional args
function class.super(obj, ...)
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
function class.methods(x)
  local res = {}
  for key, _ in pairs(x.__methods) do
    res[key] = x[key]
  end

  return res
end

---Get object attributes which are not methods
---@param x object
---@return table<string,any>
function class.attributes(x)
  local res = {}
  for key, _ in pairs(x.__attributes) do
    res[key] = x[key]
  end

  return res
end

---Get object attribute which is not a method
---@param x object
---@param attrib string
---@return any
function class.attribute(x, attrib)
  local value = x.__attributes[attrib]
  return ifelse(value, x[attrib])
end

---Get object method
---@param x object
---@param method string
---@return function | table
function class.method(x, method)
  local value = x.__methods[method]
  return ifelse(value, x[method])
end

---Get object metamethods
---@param x object
---@return table<string,function | table>
function class.metamethods(x)
  local res = {}
  for key, _ in pairs(x.__metamethods) do
    res[key] = x[key]
  end
  return res
end

---Get object metaattributes
---@param x object
---@return table<string,any>
function class.metaattributes(x)
  local res = {}
  for key, _ in pairs(x.__metaattributes) do
    res[key] = x[key]
  end
  return res
end

---Merge attributes and methods from table
---@param x object
---@param from table
---@return table
function class.include(x, from)
  for key, value in pairs(from) do
    if x[key] == nil then x[key] = value end
  end

  return x
end

---Create a new class
---@param name string
---@param inherits? table
---@return table
function class.new(name, inherits)
  return class(name, inherits)
end

---Get object's class or return the object if it is a class
---@param x object
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
---@param x object
---@param key string
---@param value any
function class.set(x, key, value)
  if class.is_object(value) or not callable(value) then
    if tostring(key):match '^__' then
      x.__metaattributes[key] = true
    else
      x.__attributes[key] = true
    end
  else
    if tostring(key):match '^__' then
      x.__metamethods[key] = true
    else
      x.__methods[key] = true
    end
  end

  rawset(x, key, value)
end

---Create a partial instance method with the object as the first argument
---@param x object
---@param method string
---@return function?
function class.create_instance_method(x, method)
  if not x[method] then
    return nil
  else
    return function(...)
      return x[method](x, ...)
    end
  end
end

---Create an instance of the object
---@param cls class
---@param defaults table<string,any>
---@param ... any initialize arguments
---@return instance
function class.create_instance(cls, defaults, ...)
  cls = class.get_class(cls)
  local obj = {
    __metaattributes = cls.__metaattributes,
    __metamethods = cls.__attributes,
    __attributes = cls.__attributes,
    __methods = cls.__attributes,
  }
  setmetatable(obj, obj)
  obj.__newindex = class.set
  obj.__object = true
  obj.__name = cls.__name
  obj.__inherits = cls.__inherits
  obj.__instance = true
  obj.__class = cls
  obj.__index = cls

  if defaults then
    for key, value in pairs(defaults) do
      obj[key] = value
    end
  end

  if cls.initialize then
    cls.initialize(obj, ...)
  else
    class.super(obj, ...)
  end

  return obj
end

---Get object parents
---@param obj object
---@return class[]?
function class.get_parents(obj)
  assert(class.is_object(obj))

  obj = class.get_class(obj)
  local parents = {}

  if not obj.__inherits then
    return
  else
    parents[#parents + 1] = obj.__inherits
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

function class:__call(name, inherits, defaults)
  if inherits and inherits.__instance then
    inherits = inherits.__class
  end

  local cls = {
    __attributes = {},
    __methods = {},
    __metaattributes = { __metaattributes = true, __metamethods = true },
    __metamethods = {},
  }

  setmetatable(cls, cls)

  cls.__newindex = class.set
  cls.__object = true
  cls.__instance = false
  cls.__name = name
  cls.__inherits = inherits
  cls.__index = inherits

  if inherits then
    for key, _ in pairs(inherits.__attributes) do
      cls.__attributes[key] = true
    end

    for key, _ in pairs(inherits.__methods) do
      cls.__methods[key] = true
    end

    for key, _ in pairs(inherits.__metaattributes) do
      cls.__metaattributes[key] = true
    end

    for key, _ in pairs(inherits.__metamethods) do
      cls.__metamethods[key] = true
    end
  end

  function cls:new(...)
    return class.create_instance(cls, defaults, ...)
  end

  cls.__call = cls.new

  if defaults then
    for key, value in pairs(defaults) do
      class.set(cls, key, value)
    end
  end

  setmetatable(cls, cls)
  return cls
end

class.class = class.get_class
class.isa = class.inherits
class.parents = class.get_parents

return class
