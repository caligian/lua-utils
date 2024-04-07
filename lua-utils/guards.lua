loadfile 'errors.lua'()

types = {
	_meta = {
		type = 'ns',
		name = 'types',
	},
	guards = {},
	types = {
		userdata = true,
		number = true,
		table = true,
		string = true,
		thread = true,
		boolean = true,
		['function'] = true,
	},
	custom = {
		method = true,
		class = true,
		instance = true,
		ns = true,
		callable = true,
		list = true,
		dict = true,
	},
}

local function gen_error(type_name, cond)
	return errors:new(
	'invalid_type',
	string.format('expected type %s, got %%s', type_name),
	cond)
end

local function gen_guard(type_name, cond, _global)
	local opt_mt = {}
	local mt = {}
	local g = setmetatable({ opt = setmetatable({}, opt_mt) }, mt)
	g._meta = {type = 'method', name = 'is_' .. type_name}
	cond = cond or function(x) return typeof(x) == type_name end
	local err = gen_error(type_name, cond)

	function mt:__call(x)
		return cond(x)
	end

	function opt_mt:__call(x)
		if x ~= nil then
			return mt(x)
		end
		return true
	end

	function g.assert(x)
		err:assert(x)
		return true
	end

	function g.dump(x)
		local ok, msg = g(x)
		if not ok then
			return err:sprintln(x)
		end
		return true
	end

	function g.opt.dump(x)
		if x ~= nil then
			return g.dump(x)
		end
		return true
	end

	function g.opt.assert(x)
		if x ~= nil then
			return g.assert(x)
		end
		return true
	end

	if _global then
		local n = 'is_' .. type_name
		_G[n] = g
		types.guards[n] = g
		types.guards[type_name] = g
	end

	return g
end

function types.new_guard(name, opts)
	opts = opts or {}
	return gen_guard(name, opts.when, opts.global)
end

function types.new_guards(guards)
	local out = {}
	local opts = guards.opts
	for name, value in pairs(guards) do
		if name ~= 'opts' then
			out[name] = types.new_guard(name, value)
		end
	end
	return out
end

types.gen_guards = setmetatable({}, {
	__newindex = function(self, name, fn)
		types.new_guard(name, {global = true, when = fn})
	end,
})

function types.gen_guards.is_nil(x)
	return x == nil
end

function types.gen_guards.empty(x)
	local x_type = type(x)

	if x_type == "string" then
		return #x == 0
	elseif x_type ~= "table" then
		return false
	end

	return size(x) == 0
end

function types.gen_guards.not_empty(x)
	return not is_empty(x)
end

function types.gen_guards.ns(x)
	return typeof(x) == "ns"
end

function types.gen_guards.class(x)
	return typeof(x) == "class"
end

function types.gen_guards.instance(x)
	return typeof(x) == 'instance'
end

function types.gen_guards.class_object(x)
	local tp = typeof(x)
	return tp == 'class' or tp == 'instance'
end

function types.gen_guards.method(x)
	local tp = typeof(x)
	return tp == 'method' or tp == 'function'
end

function types.gen_guards.list(x)
	if not is_table(x) then
		return false
	end

	local len = size(x)
	if len == 0 then
		return false
	end

	local ok = len == #x
	if not ok then
		return false
	end

	return true
end

function types.gen_guards.dict(x)
	if not is_table(x) then
		return false
	end

	local len = size(x)
	if len == 0 then
		return false
	elseif len == #x then
		return false
	else
		return true
	end
end

function types.gen_guards.typedef(self)
	local tp = typeof(self)
	return tp == 'class' or tp == 'instance' or tp == 'ns'
end

function types.gen_guards.instance(self)
	return typeof(self) == 'instance'
end

function types.gen_guards.literal(x)
	local tp = typeof(self)
	return tp == 'string' or tp == 'number' or tp == 'boolean'  or false
end

for key, _ in pairs(types.types) do
	gen_guard(key, nil, true)
end

function types.is_union_of(x, args, fail)
	fail = fail and {length = 0}
	for _, value in ipairs(args) do
		if value == '*' then
			return true
		elseif value == 'method' then
			if is_method(x) then
				return true
			end
		elseif value == 'typedef' then
			if is_typedef(x) then
				return true
			end
		elseif value == 'list' then
			if is_list(x) then
				return true
			end
		elseif value == 'dict' then
			if is_dict(x) then
				return true
			end
		elseif types.types[value] then
			local tp = type(x)
			if tp == value then
				return true
			end
		elseif x == value then
			return true
		else
			local tp = typeof(x)
			local value_tp = typeof(value)
			if value_tp == 'string' then
				local g = _G['is_' .. value]
				if g then
					if g(x) then
						return true
					end
				elseif tp == value then
					return true
				end
			elseif value_tp == 'function' or value_tp == 'method' then
				if value(x) then
					return true
				end
			elseif type(value) == 'table' then 
				if value._meta then
					if value.is_a then
						if value:is_a(x) then
							return true
						end
					elseif value._meta.type == tp then
						return true
					end
				elseif tp == 'table' then
					return true
				end
			end

			if fail then
				fail[fail.length+1] = tostring(value)
				fail.length = fail.length + 1
			end
		end

		return false, fail
	end
end

union = mtset({
	_meta = {type = 'method', name = 'union'},
	dump = function(x, ...)
		local ok, msg = types.is_union_of(x, {...}, true)
		msg.length = nil
		if not ok then
			return dump {
				error = 'invalid_type',
				message = ('expected any of %s, got %s'):format(dump(msg), dump(x)),
			}
		end
	end,
}, {
	__call = function(_, x, ...)
		return types.is_union_of(x, {...})
	end
})

union.assert = function(x, ...)
	local ok, msg = union.dump(x, ...)
	if not ok then
		error(msg)
	end
end

union.opt = setmetatable({}, {
	__call = function(_, x, ...)
		if x ~= nil then
			return union(x, ...)
		end
		return true
	end,
})

function union.opt.dump(x, ...)
	if x ~= nil then
		return union.dump(x, ...)
	end
	return true
end

function union.opt.assert(x, ...)
	if x ~= nil then
		return union.assert(x, ...)
	end
	return true
end

is_a = mtset({
	_meta = {type = 'method', name = 'is_a'},
}, {
	__call = function(_, x, ...)
		return union(x, ...)
	end,
	__index = function(_, g)
		local e = rawget(_, g)
		if not e and types.guards[g] then
			_[g] = types.guards[g]
		end
		return rawget(_, g)
	end,
})

function implements(x, ...)
	local ys = {...}

	local function impl(obj, spec)
		for key, value in pairs(spec) do
			local key_type = type(key)
			local new
			local opt, new = key_type == 'string' and key:match '^(opt_)([^$]+)'
			new = new or key
			local found = obj[new]

			if found ~= nil then
				if type(value) == 'table' and not value._meta then
					if type(found) ~= 'table' then
						return false
					else
						return impl(found, value)
					end
				elseif not is_a(found, value) then
					return false
				end
			elseif not opt then
				return false
			end
		end

		return true
	end

	for i=1, #ys do
		if impl(x, ys[i]) then
			return ys[i]
		end
	end

	return false
end
