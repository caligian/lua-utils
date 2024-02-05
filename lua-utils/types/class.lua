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

local class_mt = { type = "class" }

function class_mt:__newindex(key, value)
  if package.metatable_events[key] then
    class_mt[key] = value
  else
    rawset(self, key, function(cls_or_inst, ...)
      throw.cls_or_instance(is_class_object(cls_or_inst))
      return value(get_class(cls_or_inst), ...)
    end)
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
function class:get_attribs(exclude_callables)
  return dict.filter(self, function(key, value)
    if exclude_callables and is_callable(value) then
      return false
    end
    return not non_class_attribs[key]
  end)
end

--- Get static methods for class
--- @param self class
--- @return table?
function class:get_static_methods()
  local methods = mtget(self, "static")
  if not methods then
    return
  end

  local out = {}
  for name, _ in pairs(methods) do
    out[name] = self[name]
  end

  return out
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
function class:is_child_of(other)
  other = get_class(other) --[[@as class]]

  if not other then
    return
  end

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
--- @return class?
function class:is_a(other)
  if other == self then
    return other
  end

  other = get_class(other) --[[@as class]]
  if not other then
    return
  end

  self = get_class(self)
  if not self then
    return
  end

  if self:get_class_parent() == other:get_class_parent() then
    return other
  end

  return self:is_child_of(other) and other
end

function class:__call(name, opts)
  throw.name(is_string(name))

  if static then
    throw.static(is_table(static))
  end

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

  function classmodmt:__index(key)
    local p = self:get_class_parent()
    if p then
      return p[key]
    end
  end

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
    return self:get_class()[key]
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
      objmt[key] = value
    else
      rawset(self, key, value)
    end
  end

  function classmodmt:__call(...)
    local obj = mtset({}, objmt)
    local static_methods = self:get_static_methods()

    --- @cast obj class

    for key, value in pairs(classmod) do
      if not static_methods[key] and key ~= "init" and key ~= "super" then
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
