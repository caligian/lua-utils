local class = require 'lua-utils.class'
local exception = require 'lua-utils.exception'
local types = require 'lua-utils.types'

local Success = class('Success')
local Failure = class('Failure')
local UnwrapError = exception("UnwrapError")

function Success:initialize(value)
  self.value = value
end

function Success:ok()
  if types.is(self.value, "exception") then
    return false
  else
    return true
  end
end

function Success:not_ok()
  return not self:ok()
end

function Success:unwrap(opts)
  opts = opts or {}
  local pcall_ = opts.pcall

  if self:ok() then
    return self.value
  elseif pcall_ then
    return UnwrapError()
  end
end

local value = Success(1)

