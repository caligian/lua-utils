-- local is = require 'lua-utils.is'
local types = require 'lua-utils.types'
local validate = require 'lua-utils.validate'

---@overload fun(cond: boolean, fmt: string, ...): boolean
warn = bless({}, {
  ---@param cond any
  ---@param fmt string
  ---@param ... any
  ---@return true
  __call = function (_, cond, fmt, ...)
    if not cond then
      error(sprintf(fmt, ...))
    else
      return true
    end
  end,
})

---Throw error when type does not match. Does not support recursive table matching
---@overload fun(x: any, is_type: any, prefix?: string|number): boolean
warn.is = bless({}, {
  ---@param x any
  ---@param is_type string|table|(fun(x: any): boolean, string?)
  ---@param prefix? string
  ---@return boolean
  __call = function (_, x, is_type, prefix)
    prefix = prefix or '<root>'
    local ok, msg = types.is(x, is_type)

    if not ok then
      msg = sprintf('%s: %s', prefix, msg) or sprintf('%s: Assertion failure with %s for %s [%s]', prefix, is_type, typeof(x))
      error(msg)
    else
      return true
    end
  end,
  __index = function (self, prefix)
    return function (x, is_type)
      return self(x, is_type, prefix)
    end
  end,
})

---Throw error when type does not match and also recursively check tables
---@overload fun(prefix: string|number, x: any, is_type: any): boolean
warn.match = bless({}, {
  __call = function (_, prefix, x, is_type)
    validate[prefix](is_type, x)
    return true
  end,
  __index = function (self, prefix)
    return function (x, is_type)
      return self(prefix, x, is_type)
    end
  end
})

return warn
