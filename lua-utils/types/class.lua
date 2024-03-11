require "lua-utils.types.utils"

--- Get the class module for object
--- @param x class x should be a class or an instance
--- @return class?
function get_class(x)
  if not is_table(x) then
    return
  elseif not is_class_object(x) then
    return
  elseif is_class(x) then
    return x
  elseif is_instance(x) then
    return mtget(x, "class")
  end
end

local function assert_get_class(x)
  local cls = get_class(x)
  if not cls then
    error("expected class or instance, got " .. dump(x))
  end
  return cls
end

local class_mt = { type = "class" }

function class_mt:__newindex(key, value)
  if package.metatable_events[key] then
    class_mt[key] = value
  else
    rawset(self, key, value)
  end
end

--- Create a class ns to create instances
--- @class class
--- @overload fun(...: any): class
class = setmetatable({}, class_mt)
class.get_class = get_class

--- Get the nearest .init() method for class. Throws an error when no init method is found
--- @param self class
--- @return function
function class:get_super_method()
  local _parent = self:get_class_parent()

  while _parent do
    local init = _parent.init
    if init then
      return init
    end

    _parent = _parent:get_class_parent()
  end

  error("no init defined for " .. dump(self))
end

function super(obj, ...)
  throw.obj(is_instance(obj))

  local cls = mtget(obj, 'class')
  local init = cls:get_super_method()
  if not init then
    return
  end

  return init(obj, ...)
end

function class:super(...)
  return super(self, ...)
end

function class:include(other)
  if not is_ns(other) and not is_class(other) then
    error('expected other to be a namespace or a class, got ' .. dump(other))
  end

  for key, value in pairs(other) do
    self[key] = value
  end

  return self
end

--- Get attributes w/o methods
--- @param exclude_methods? boolean
--- @return table<string,any>
function class:get_class_attribs(exclude_methods)
  local out = {}
  for key, value in pairs(self) do
    if not (exclude_methods and is_method(value) or self:is_static_method(key)) then
      out[key] = value
    end
  end

  return out
end

function class:get_class_attrib(name)
  local found = rawget(self, name)

  if not found then
    local p = self:get_class_parent()
    if p then
      return  p:get_class_attrib(name)
    end
  end

  return found
end

--- Get static methods for class
--- @param self class
--- @return table?
function class:get_static_methods()
  local methods = mtget(cls, "static")
  if not methods then
    return
  end

  local out = {}
  for name, _ in pairs(methods) do
    if is_string(name) then
      out[name] = cls[name]
    end
  end

  return out
end

--- Get instance methods
--- @param self class
--- @return table<any,function>
function class:get_instance_methods()
  local static_methods = mtget(cls, 'static')
  local out = {}

  for key, value in pairs(self) do
    local ok = is_method(value) and not static_methods[key] 
    if ok then out[key] = value end
  end

  return out
end

--- Is `name` a static method
--- @param name string method name
--- @return boolean
function class:is_static_method(name)
  return mtget(self, 'static')[name] and true or false
end

--- Is `name` an instance method
--- @param self class
--- @param name string
--- @return boolean
function class:is_instance_method(name)
  return not self:is_static_method(name) and self[name] and true or false
end

--- Get class name
--- @param self class
--- @return string?
function class:get_class_name()
  return mtget(self, "name")
end

--- Get class parent
--- @param self class
--- @return table?
function class:get_class_parent()
  return mtget(self, "parent")
end

--- Is other a child of self
--- @param self class
--- @param other class
--- @return class?
function class:is_child_of(other, opts)
  is_table.opt.assert(opts)
  opts = opts or {}
  local ass = opts.assert
  local dmp = opts.dump
  local ok, msg = is_class_object.dump(other)

  if not ok then
    if ass then
      error('other: ' .. msg)
    elseif dmp then
      return nil, msg
    else
      return
    end
  else
    other = get_class(other)
  end

  local function msg()
    return
      'expected subclass of ' 
      .. other:get_class_name()
      .. '\nvalue <class> ' 
      .. dump(self:get_class_name())
      .. ' '
      .. dump(self)
  end

  local self_parent = self:get_class_parent()
  if not self_parent then
    if ass then
      error(msg())
    elseif dmp then
      return nil, msg()
    end
    return
  end

  while self_parent ~= other do
    self_parent = self_parent:get_class_parent()
    if ass then
      error(msg())
    elseif dmp then
      return nil, msg()
    else
      return
    end
  end

  return self
end

--- Is other parent of self
--- @param self class
--- @param other class
--- @return class?
function class:is_parent_of(other, opts)
  return self:is_child_of(other, self, opts)
end

--- Check if other is a parent of self or self itself
--- @param self class
--- @param other class
--- @return class?, string?
function class:is_a(other, opts)
  is_table.opt.assert(opts)
  opts = opts or {}

  local ass = opts.assert
  local dmp = opts.dump

  local ok, msg = is_class_object.dump(other)
  if not ok then
    if ass then
      error(msg)
    elseif dmp then
      return nil, msg
    end
    return nil
  end

  if other == self then
    return other
  end

  local p = self:get_class_parent()
  local q = other:get_class_parent()
  if p and q and p == q then
    return true
  end

  return self:is_child_of(other, opts)
end

--------------------------------------------------
function class:__call(name, opts)
  throw.name(is_string(name))

  if opts then
    throw.opts(is_table(opts))
  end

  opts = opts or {}
  local static = copy(opts.static or {})
  local parent = opts.parent
  local include = opts.include
  local classmodmt = {}
  local classmod = mtset(copy.table(class)--[[@as table]], classmodmt)
  classmodmt.static = static
  classmodmt.parent = parent
  classmodmt.type = "class"
  classmodmt.name = name

  if static[1] then
    for i = 1, #static do
      static[static[i]] = true
    end
  end

  if include then
    throw.include(is_table(include))
    for key, value in pairs(include) do
      classmod[key] = value
    end
  end

  if parent then
    throw.parent(is_class_object(opts.parent))
    classmodmt.parent = get_class(opts.parent)
  end

  classmodmt.__index = class.get_class_attrib

  local objmt = {
    instance = true,
    type = name,
    class = classmod,
    parent = parent,
    static = static,
    __tostring = dump,
  }

  function objmt:__index(key)
    return self:get_class_attrib(key)
  end

  function objmt:__newindex(key, value)
    if package.is_valid_event(key) then
      objmt[key] = value
    else
      rawset(self, key, value)
    end
  end

  function classmodmt:__newindex(key, value)
    if package.is_valid_event(key) then
      classmodmt[key] = value
      if key ~= "__index" and key ~= "__newindex" then
        objmt[key] = value
      end
    else
      rawset(self, key, value)
    end
  end

  function classmodmt:__call(...)
    local obj = mtset({}, objmt)

    --- @cast obj class
    local static_methods = static

    --- @cast obj class
    for key, value in pairs(classmod) do
      if not static_methods[key] and (key ~= "init" and key ~= "super") then
        obj[key] = value
      end
    end

    ---@diagnostic disable-next-line: undefined-field
    local init = self.init
    if init then
      return init(obj, ...)
    else
      return obj:super(...)
    end
  end

  return classmod--[[@as class]]
end
