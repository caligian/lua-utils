require "lua-utils.types"

class = namespace "class"
local classmt = mtget(class)
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
}

function is_instance(x)
  local ok, msg = is_table(x)
  if not ok then
    return false, msg
  end

  local mt = mtget(x)
  if not mt then
    return false, 'missing metatable ' .. dump(x)
  elseif not is_string(x) then
    return false, 'not a type ' .. dump(x)
  elseif not x.get_module then
    return false, 'invalid class without module ' .. dump(x)
  end

  return x
end

function is_class(self)
  local ok, msg = is_namespace(self)

  if not ok then
    return false, msg
  elseif not self.is_child_of then
    return false, "namespace is not a class " .. dump(self)
  elseif is_instance(self) then
    return false, 'expected class, got instance ' .. dump(self)
  end

  return true
end

function instanceof(A, B)
  if not is_class(A) then
    return false, "expected class, got " .. dump(A)
  end

  if not is_class(B) then
    return false, "expected class, got " .. dump(B)
  end

  local A_mod, B_mod = A:get_module(), B:get_module()
  if A_mod == B_mod then
    return true
  elseif B:is_parent_of(A) then
    return true
  end

  return false, string.format("expected child of %s, got %s", B:get_name(), dump(A))
end

function class.get_attribs(self, exclude_callables)
  assert_is_a.class(self)

  return dict.filter(self, function(key, value)
    if exclude_callables and is_callable(value) then
      return false
    end
    return not non_class_attribs[key]
  end)
end

function class.get_module_parent(self)
  return mtget(self, "parent")
end

function class.is_child_of(self, other)
  local ok, msg

  ok, msg = is_class(self)
  if not ok then
    return false, msg
  end

  ok, msg = is_class(other)
  if not ok then
    return false, msg
  end

  local other_mod = other.get_module()
  local self_parent = self:get_module_parent()

  if self_parent == other_mod then
    return self
  elseif not self_parent then
    return nil, "no parent defined for " .. dump(self)
  end

  while self_parent ~= other_mod do
    self_parent = self_parent:get_module_parent()
    if not self_parent then
      return nil, "no parent defined for " .. dump(self)
    end
  end

  return self
end

function class.is_parent_of(self, other)
  return class.is_child_of(other, self)
end

function class.is_a(self, other)
  if is_nil(other) then
    return is_class(self)
  end

  local ok, msg = is_class(self)
  if not ok then
    return false, msg
  end

  return class.is_child_of(other, self)
end

function class:new(name, static, opts)
  opts = opts or {}
  local classmod = namespace(name)
  local classmodmt = mtget(classmod)
  local parent = opts.parent

  dict.merge2(classmod, class)

  classmod.is_a = class.is_a
  classmod.is_child_of = class.is_child_of
  classmod.is_parent_of = class.is_parent_of

  if parent then
    assert_is_a.class(parent)
    classmodmt.parent = parent
  end

  function classmod:get_module()
    return self or classmod
  end

  function classmod:get_module_parent()
    return mtget(self, "parent") or parent
  end

  function classmod:super(...)
    local parent = self:get_module_parent()

    if not parent then
      return self
    elseif parent.init then
      return parent.init(self, ...)
    end

    local init
    local gp

    while not init do
      gp = parent:get_module_parent()

      if not gp then
        error("no .init() defined for " .. dump(self))
      end

      init = gp.init
    end

    return init(self, ...)
  end

  function classmod:new(...)
    local obj = mtset(copy(self), classmodmt)
    local init = self.init

    if init then
      return init(self, ...)
    else
      return self:super(...)
    end
  end

  classmod.__call = classmod.new
  classmodmt.parent = parent

  return classmod
end

--[[
local grand_parent = class:new "grand_parent"
function grand_parent:init(...)
  return self
end

local parent = class:new("parent", {}, { parent = grand_parent })
local child = class:new("hello", {}, { parent = parent })
local obj = child
obj.name = 'laude'
parent.name = 'bhungi'
grand_parent.name = 'madarchod'
local gp = grand_parent()
gp.a = 1
--]]


