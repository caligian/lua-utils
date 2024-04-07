-- require "lua-utils._meta.types.utils"
loadfile 'guards.lua'()

local function get_class(x)
	is_class_object.assert(x)
  if is_instance(x) then
    return x._meta.class
  elseif is_class(x) then
    return x
  end
end

local base = {
	_meta = {
		type = 'class',
		name = "base",
	},
	init = function(self, ...)
    return self, ...
  end,
}

base.__index = base
base.__tostring = dump

function base.new(cls, ...)
  local obj = {_meta = { type = "instance", name = cls.name, class = cls }}
  cls.__index = cls
  setmetatable(obj, cls)

  if cls.init then
    local _obj = cls.init(obj, ...)
    return _obj or obj
  end

  return obj, ...
end

base.__call = base.new

function base.is_parent_of(cls, inst)
  if
    not is_class_object(cls) or not is_class_object(inst)
  then
    return false
  end

  cls = get_class(cls)
  inst = get_class(inst)

  if cls == inst then
    return true
  end

  return base.is_parent_of(cls, inst._meta.class)
end

function base.get_class(cls)
	if not is_class_object(cls) then
		return
	elseif is_instance(cls) then
		return cls._meta.class
	else
		return cls
	end
end

function base.is_child_of(cls, inst)
  return base.is_parent_of(inst, cls)
end

function base.is_a(cls, inst)
  local _inst = inst
  cls = get_class(cls)
  inst = get_class(inst)

  if cls == inst then
    return true
  elseif cls:is_parent_of(inst) then
    return true
  end

  return false
end

function localclass(name, opts)
	is_string.assert(name)
	is_table.assert(opts)

	opts = opts or {}
	local cls = {_meta = {}}
	local parent = opts.parent or opts.class or base
	local global = opts.global
	local init = parent.init or base.init
  cls.__index = cls
  cls.__tostring = dump
  cls._meta = cls._meta or {}
  cls._meta.type = 'class'
  cls._meta.name = name
  cls._meta.class = parent
  cls.init = init
  setmetatable(cls, cls._meta.class)

  if global then
    cls._meta.global = true
		_G[name] = cls
  end

	return cls
end

function class(name)
  return class(name, {global = true})
end
