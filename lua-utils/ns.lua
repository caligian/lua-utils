loadfile 'guards.lua'()

local base = {
	_meta = {
		type = 'ns',
		name = "base",
	},
}

base.__index = base
base.__tostring = dump

function base.is_parent_of(cls, inst)
	if not is_ns(inst) then
		return false
	end

	if cls == inst then
		return true
	end

  return base.is_parent_of(cls, inst._meta.ns)
end

function base.is_child_of(cls, inst)
  return base.is_parent_of(inst, cls)
end

function base.is_a(cls, inst)
	return base.is_parent_of(cls, inst)
end

function ns(name, opts)
	opts = opts or {}
	local cls = {_meta = {}}
	local parent = opts.parent or opts.ns or base
	local global = opts.global
	local init = parent.init or base.init
  cls.__index = cls
  cls.__tostring = dump
  cls._meta = cls._meta or {}
  cls._meta.type = 'ns'
  cls._meta.name = name
  cls._meta.ns = parent
  cls.init = init
  setmetatable(cls, cls._meta.ns)

  if global then
    cls._meta.global = true
		_G[name] = cls
  end

	return cls
end
