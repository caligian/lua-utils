require 'lua-utils.types'

errors = class:new()
types.error = {
  throw = types.method,
  is = types.method,
  message = types.string
}

function errors:init(msg, parent)
  if parent then
    is_a.assert(parent, types.error)
  end

  self.message = msg
  self.parent = parent
  return self
end

function errors:__tostring(context)
  local parent_errors = {}

  local function recursive_convert(x)
    if x.parent then
      parent_errors[#parent_errors+1] = x.parent.message
      recursive_convert(x.parent)
    end
  end

  recursive_convert(self)

  return dump {
    message = self.message,
    context = context,
    parent = parent_errors,
  }
end

function errors:assert(cond, context)
  if cond then
    return true
  else
    self:throw(context)
  end
end

function errors:throw(context)
  error(self:__tostring(context), 3)
end

function errors:is(p)
  if not self.parent then
    return
  elseif self.parent == p then
    return true
  elseif p == self then
    return true
  end

  return self.parent:is(p)
end

function errors.from_dict(specs)
  local new = {}
  for key, value in pairs(specs) do
    new[key] = errors(unpack(tolist(value)))
  end
  return new
end
