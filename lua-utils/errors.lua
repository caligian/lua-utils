loadfile 'core.lua'()

errors = {_meta = {type = 'class', name = 'errors'}}
errors.__index = errors

function errors:new(err, fmt, cond)
	local obj = {
		error = err,
		format = fmt,
		when = cond,
		_meta = {class = errors, type = 'instance', name = 'errors'},
	}
	setmetatable(obj, errors)
	return obj
end

local function dump_all(...)
	local args = {...}
	for i=1, #args do
		args[i] = dump(args[i])
	end
	return unpack(args)
end

function errors:sprintf(...)
	return dump {
		error = self.error,
		message = string.format(self.format, dump_all(...)),
	}
end

function errors:sprintln(...)
	return (dump {
		error = self.error,
		message = string.format(self.format, dump_all(...)),
	}) .. "\n"
end

function errors:assert(x, ...)
	if self.when and not self.when(x) then
		self:throw(x, ...)
	end
end

function errors:throw(...)
	error(self:sprintf(...), 3)
end

errors.__call = errors.throw

function errors.from_dict(mod, x)
	mod.errors = mod.errors or {}
	for key, value in pairs(x) do
		mod.errors[key] = errors:new(key, value)
	end
end
