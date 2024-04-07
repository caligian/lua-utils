-- require 'lua-utils.core'
loadfile 'core.lua'()

types = {
	metaevents = {
		__call = true,
		__add = true,
		__sub = true,
		__eq = true,
		__ne = true,
		__le = true,
		__ge = true,
		__lt = true,
		__gt = true,
		__index = true,
		__newindex = true,
		__metatable = true,
	}
}
interfaces = {}

function interfaces.method(self)
	local t = type(self)
	if t == 'function' then 
		return true
	elseif type(self) ~= 'table' then
		return false
	end

	local mt = mtget(self)
	if mt then
		return interfaces.method(mt.__call)
	end

	return false
end

function is_a(x, y)
	if is_method(y) then
		if not y(x) then
			return false
		else
			return true
		end
	else
		local t_y = type(y)
		local t_x = type(x)

		if t_y == 'table' and t_x == 'table' then
			for key, value in pairs(y) do
				local opt, k
				local a = x[key]
				local b = value

				if type(key) == 'string' then
					if types.metaevents[key] then
						a = mtget(x)
						if not is_a(a[key], b) then
							return false
						end
					else
						opt, k = key:match '^(opt_)(.+)'
						k = k or key 
						a = x[k]
						if a ~= nil then
							if not opt and not is_a(a, b) then
								return false
							elseif not is_a(a, b) then
								return false
							end
						end
					end
				elseif not is_a(a, b) then
					return false
				end
			end
		else
			if t_y == 'string' then
				if y ~= t_x then
					return false
				end
			elseif t_y ~= t_x then
				return false
			end
		end

		return true
	end
end

function class(interface)
	local cls = {}
	function cls:new(...)
		local obj = {}
		for key, value in pairs(self) do
			obj[key] = value
		end
		if self.init then
			return self.init(obj, ...)
		end
		obj.is_a = types.is_a
		return obj, ...
	end
	return cls
end

function union(...)
	local _interfaces = {...}
	return function (x)
		for i=1, #_interfaces do
			if is_a(x, _interfaces[i]) then
				return true
			end
		end
		return false
	end
end

-- interfaces.A = {
--  	x = 'number',
--  	y = 'number', 
--  	opt_check = {'method'}
-- }
--
-- local A = class(A)
-- 
-- function A:init(x, y)
-- 	self.x = x
-- 	self.y = y 
-- 	return self
-- end
-- 
-- function A:check()
-- 	return (self.x + self.y) > 4
-- end
-- 
-- pp(A:new(1, 2))
-- pp(is_a(A:new(1, 2), interfaces.A))
-- pp(is_a(1, 'number'))
-- pp(is_a({x=1, y=2, check = {print}}, interfaces.A))
--
-- local spec = {
-- 	__call = { __call = interfaces.method},
-- }
-- 
-- local x = mtset({}, {
-- 	__call = mtset({}, {__call = print})
-- })
-- 
-- pp(is_a(x, spec))
