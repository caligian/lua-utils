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

function class:include(other)
  if not is_ns(other) or not is_class(other) then
    error('expected other to be a namespace or a class, got ' .. dump(other))
  end

  for key, value in pairs(other) do
    self[key] = value
  end

  return self
end

--- Use init method on and instance
--- @param self class
--- @param obj table
--- @param ... any
function class:super(obj, ...)
  local super_fn = self:get_super_method()
  return super_fn(obj, ...)
end

--- Get attributes w/o callables
--- @param exclude_callables? boolean
--- @return table<string,any>
function class:get_class_attribs(exclude_callables)
  assert(is_class_object(self))

  local out = {}
  for key, value in pairs(self) do
    if not (exclude_callables and is_method(value) or self:is_static_method(key)) then
      out[key] = value
    end
  end

  return out
end

function class:get_class_attrib(name)
  assert(is_class(self) or is_instance(self), dump(self))
  local found = rawget(self, name)

  if not found then
    local p = class.get_class_parent(self)
    if p then
      return class.get_class_attrib(p, name)
    end
  end

  return found
end

--- Get static methods for class
--- @param self class
--- @return table?
function class:get_static_methods()
  local cls = assert_get_class(self)
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

function class:get_instance_methods()
  assert(is_class_object(self))

  local cls = assert_get_class(self)
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
  return (mtget(assert_get_class(self), "static") or {})[name] and true or false
end

function class:is_instance_method(name)
  return not self:is_static_method(name) and self[name] and true or false
end

--- Get class name
--- @param self class
--- @return string?
function class:get_class_name()
  return mtget(assert_get_class(self), "name")
end

--- Get class parent
--- @param self class
--- @return table?
function class:get_class_parent()
  return mtget(assert_get_class(self), "parent")
end

--- Is other a child of self
--- @param self class
--- @param other class
--- @return class?
function class:is_child_of(other)
  other = assert_get_class(other)
  self = assert_get_class(self)

  local self_parent = self:get_class_parent()
  if not self_parent then
    return
  end

  while self_parent ~= other do
    self_parent = self_parent:get_class_parent()
    if not self_parent then
      return
    end
  end

  return self
end

--- Is other parent of self
--- @param self class
--- @param other class
--- @return class?
function class:is_parent_of(other)
  ---@diagnostic disable-next-line: param-type-mismatch
  return class.is_child_of(other, self)
end

--- Check if other is a parent of self or self itself
--- @param self class
--- @param other class
--- @return class?, string?
function class:is_a(other)
  if other == self then
    return other
  end

  other = get_class(other) --[[@as class]]
  if not other then
    return nil, "expected other as class|instance, got " .. dump(other)
  end

  self = get_class(self)
  if not self then
    return nil, "expected class|instance, got " .. dump(self)
  end

  if self:get_class_parent() == other:get_class_parent() then
    return other
  end

  return self:is_child_of(other) and other
end

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
  static.init = true
  static.super = true
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
    __tostring = dump,
  }

  function objmt:__index(key)
    if key == "super" then
      error("attempting to use .super() on instance: " .. dump(self))
    end
    return class.get_class_attrib(self, key)
  end

  function objmt:__newindex(key, value)
    if package:is_valid_event(key) then
      objmt[key] = value
    else
      rawset(self, key, value)
    end
  end

  function classmodmt:__newindex(key, value)
    if package:is_valid_event(key) then
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
    local static_methods = self:get_static_methods()

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
      return self:super(obj, ...)
    end
  end

  return classmod
end

-- local G = class "Grandpa"
-- G.g_a = 1
-- G.g_b = 2

-- function G:init(x, y)
--   self.g_x = x
--   self.g_y = y
--   return self
-- end

-- local P = class("Pa", { parent = G })
-- function P:init(x, y)
--   self.p_x = x
--   self.p_y = y
--   return P:super(self, x, y)
-- end
