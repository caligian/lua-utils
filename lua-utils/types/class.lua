require "lua-utils.types.utils"

--- @class class
--- @field name string
--- @field parent class
--- @field type string
--- @field static table<string,function>
class = {}

--- @class instance
--- @field class class
local instance = {}

--- Get the class module for object
--- @param x instance|class x should be a class or an instance
--- @return class?
function get_class(x)
  if is_class(x) then return x--[[@as class]] end
  return is_instance(x) and x.class or nil
end

class.get_class = get_class

function super(obj, ...)
  throw.obj(is_instance(obj))

  local init = obj.class.init
  if not init then
    return
  end

  return init(obj, ...)
end

function instance:super(...)
  return super(self, ...)
end

function instance:include(other)
  if not is_table(other) then
    return
  end

  for key, value in pairs(other) do
    self[key] = value
  end

  return self
end

--- Is other a child of self
--- @param self class
--- @param other class
--- @return class?
function instance:is_child_of(other, opts)
  is_table.opt.assert(opts)
  opts = opts or {}
  local ass = opts.assert
  local dmp = opts.dump
  local ok, msg = is_class_object.dump(other)

  if not ok then
    if ass then
      error("other: " .. msg)
    elseif dmp then
      return nil, msg
    else
      return
    end
  else
    other = get_class(other)
  end

  local function msg()
    return "expected subclass of "
      .. other:get_class_name()
      .. "\nvalue <class> "
      .. dump(self:get_class_name())
      .. " "
      .. dump(self)
  end

  local self_parent = self:get_parent()
  if not self_parent then
    if ass then
      error(msg())
    elseif dmp then
      return nil, msg()
    end
    return
  end

  while self_parent ~= other do
    self_parent = self_parent:get_parent()
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
function instance:is_parent_of(other, opts)
  return self:is_child_of(other, self, opts)
end

--- Check if other is a parent of self or self itself
--- @param self class
--- @param other class
--- @return class?, string?
function instance:is_a(other, opts)
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

  local p = self:get_parent()
  local q = other:get_parent()
  if p and q and p == q then
    return true
  end

  return self:is_child_of(other, opts)
end

--------------------------------------------------
function instance:__call(name, opts)
  throw.name(is_string(name))

  if opts then
    throw.opts(is_table(opts))
  end

  opts = opts or {}
  local static = copy(opts.static or {})
  local parent = opts.parent
  local include = opts.include
  local classmodmt = {}
  local classmod =
    mtset(copy.table(class)--[[@as table]], classmodmt)
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

  local objmt = { __tostring = dump }

  function objmt:__index(key)
    return self:get_class_attrib(key)
  end

  function objmt:__newindex(key, value)
    if table.is_valid_event(key) then
      objmt[key] = value
    else
      rawset(self, key, value)
    end
  end

  function classmodmt:__newindex(key, value)
    if table.is_valid_event(key) then
      classmodmt[key] = value
      if key ~= "__index" and key ~= "__newindex" then
        objmt[key] = value
      end
    else
      rawset(self, key, value)
    end
  end

  function classmodmt:__call(...)
    local obj = mtset({ class = classmod }, objmt)

    --- @cast obj class
    local static_methods = static

    --- @cast obj class
    for key, value in pairs(classmod) do
      if
        not static_methods[key]
        and (key ~= "init" and key ~= "super")
      then
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
