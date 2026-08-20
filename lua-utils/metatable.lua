local inspect = require 'inspect'

if not package.NIL then
  ---Nil placeholder for type signature matching
  package.NIL = {}
end

if not NIL then
  NIL = package.NIL
end

---@alias Filter (fun(value: any): boolean)|(fun(key: any, value: any): boolean)
---@alias Mapper (fun(value: any): any)|(fun(key: any, value: any): any)
---@alias Callback fun(value: any)|fun(key: any, value: any)

---@class type_table
---@field __type string

---@class callable_table : type_table
---@field __callable boolean

---@class class : callable_table
---@field __attributes table<string,boolean> All class attributes set
---@field __methods table<string,boolean> All class methods set
---@field __metamethods table<string,boolean> All class metamatehods set
---@field __metaattributes table<string,boolean> All class metaattributes (variables starting with '__')
---@field __name string class name
---@field __class? class Parent class

---@class instance : class
---@field __instance boolean
---@field new nil

---@class module : type_table
---@field __name string

---@alias callable callable_table | function
---@alias condition fun(x: any, ...): boolean, string?
---@alias pcallable condition|(fun(x: any, ...): boolean, any)
---@alias object class | instance

---@class guard.opts
---@field assert? boolean
---@field dump? boolean
---@field prefix? string
---@field optional? boolean
---@field opt? boolean

---@class union.opts : guard.opts
---@field optional? boolean
---@field opt? boolean

---@class guard : callable_table
---@field name string
---@field guard callable|guard
---@field make_err_msg callable
---@field format string
---@field as_function fun(self: guard): (fun(x: any, opts?: guard.opts): boolean, string?)
---@overload fun(x: any, opts?: guard.opts): boolean, string?

---@class union : callable_table
---@field signature (string|union)[]
---@field type_name string
---@overload fun(x: any, opts?: union.opts): boolean, string?

---@alias guard.valid_type string|guard|union|object

if not GUARD then
  ---Contains all the guard functions created by defguard()
  ---@type table<string,guard>
  GUARD = {}
end

if not BUILTIN_TYPES then
  ---Contains all the builtin lua types
  ---@type table<string,boolean>
  BUILTIN_TYPES = {
    string = true,
    number = true,
    ['function'] = true,
    table = true,
    userdata = true,
    thread = true,
    boolean = true,
  }
end

---@param msg string
---@param prefix? string
---@return string
function msg_with_prefix(msg, prefix)
  msg = prefix and (prefix .. ': ' .. msg) or msg
  return msg
end

---@param x any
---@return boolean
function is_nil(x)
  if x == NIL or x == nil then
    return true
  else
    return false
  end
end

---If x is nil or package.NIL, return nil else return x
---@param x any
---@return any
function as_value(x)
  if x == nil or x == NIL then
    return
  else
    return x
  end
end

---@param x any
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_builtin_type(x, err_msg, prefix)
  x = as_value(x)
  local x_type = type(x)
  local typed = x_type == 'table' and x.__type

  if typed and err_msg then
    local msg = string.format('Expected a builtin type, got a typed table: %s', inspect(x))
    msg = msg_with_prefix(msg, prefix)
    return false, msg
  elseif typed then
    return false, nil
  else
    return true, nil
  end
end

---@param name string
---@param child? table Optional table to turn into type value
---@return table
function deftype(name, child)
  assert(type(name) == 'string', 'No type name provided')

  child = as_value(child)
  if not child then
    return { __type = name }
  else
    child.__type = name
    return child
  end
end

---Similar to python's callable()
---@param x any
---@param err_msg? boolean
---@return boolean, string?
---@overload fun(x: any): boolean, nil
---@overload fun(x: any, err_msg: boolean, prefix?: string): boolean, string
function callable(x, err_msg, prefix)
  x = as_value(x)
  local type_ = type(x)

  if type_ == 'function' then
    return true, nil
  elseif type_ ~= 'table' then
    if err_msg then
      local msg = 'Expected with table with __call metamethod'
      msg = msg_with_prefix(msg, prefix)
      return false, msg
    else
      return false, nil
    end
  elseif x.__type == 'callable' then
    return true, nil
  end

  local mt = getmetatable(x)
  local call = mt and rawget(mt, '__call')

  if not mt then
    if err_msg then
      return false, msg_with_prefix('Expected table with metamethod')
    else
      return false, nil
    end
  elseif call then
    return callable(call, err_msg)
  else
    return false, "No __call metamethod defined"
  end
end

---@param fn callable
---@param pass_self? boolean
---@return table
function defcallable(fn, pass_self)
  assert(callable(fn, true))

  local cb = bless()
  cb.__callable = true
  cb.__type = 'callable'
  cb.__call = pass_self and function(self, ...)
    return fn(self, ...)
  end or fn

  ---@type callable_table
  return cb
end

---@param x table
---@return boolean
function hasmetatable(x)
  return getmetatable(x) ~= nil
end

has_mt = hasmetatable
has_metatable = has_mt
get_metatable = getmetatable
get_mt = get_metatable
set_metatable = setmetatable
set_mt = setmetatable

---@param x table
---@param check? string
---@return (string|boolean)?
function table.type(x, check)
  if check then
    return x.__type == check
  else
    return x.__type
  end
end

---@param tbl callable
---@param pass_self? boolean
---@return function
function as_function(tbl, pass_self)
  if tbl == NIL then
    tbl = nil
  end

  local fn = nil
  if type(tbl) == 'function' then
    fn = tbl
  elseif callable(tbl) then
    if pass_self then
      fn = function(...)
        return tbl(...)
      end
    else
      fn = function(...)
        fn = rawget(tbl, '__call')
        return fn(...)
      end
    end
  else
    errorf("Expected function|callable_table, got %s", type(tbl))
  end

  ---@type function
  return fn
end

---@param x any
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_type(x, err_msg, prefix)
  if x == NIL then
    x = nil
  end

  local x_type = type(x)
  if x_type == 'table' and x.__type then
    return true, nil
  end

  if err_msg then
    local msg = sprintf('Expected {__type = STRING, ...}, got %s', x_type)
    msg = msg_with_prefix(msg, prefix)
    return false, msg
  end

  return false
end

---@param x any
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_object(x, err_msg, prefix)
  x = as_value(x)
  local ok, msg = is_type(x, err_msg, prefix)

  if not ok then
    return false, msg
  end

  ok = x.__type == 'class'
  if ok then
    return true, nil
  end

  if err_msg then
    msg = sprintf('Expected class, got table: %s', x)
    msg = msg_with_prefix(msg, prefix)
    return false, msg
  end

  return false, nil
end

---@param x any
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_instance(x, err_msg, prefix)
  if x == NIL then
    x = nil
  end

  local ok, msg = is_object(x, err_msg, prefix)
  if not ok then
    return false, msg
  end

  if x.__instance then
    return true
  elseif err_msg then
    msg = sprintf('Expected instance, got class: %s', x)
    msg = msg_with_prefix(msg, prefix)
    return false, msg
  end

  return false, nil
end

---@param x any
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_class(x, err_msg, prefix)
  x = as_value(x)
  local ok, msg = is_object(x, err_msg, prefix)

  if not ok then
    return false, msg
  elseif is_instance(x) then
    if err_msg then
      msg = sprintf('Expected class, got instance: %s', x)
      msg = msg_with_prefix(msg, prefix)
      return false, msg
    end

    return false, nil
  end

  return true, nil
end

---@param child (instance|class)?
---@return class?
function classof(child)
  child = as_value(child)
  if is_instance(child) then
    ---@type instance
    return child.__class
  elseif not is_class(child) then
    errorf("Expected class|instance, got %s", child)
  end

  return child
end

---Get the parent class of an object
---@param child instance|class
---@return class?
function parentof(child)
  assert(is_object(child, true))
  child = classof(child)
  return child.__class
end

---Check if child has a parent
---@param child class|instance
---@return boolean
function has_parent(child)
  return parentof(child) ~= nil
end

---@param child instance
---@param ... class
---@return boolean
function instanceof(child, ...)
  local ok, msg = is_instance(child, true)

  if not ok then
    errorf('child: %s', msg)
  end

  local parents = { ... }
  local child_parent = child.__class

  ---@param parent class
  ---@return boolean
  local function is_parent_of(parent)
    if not parent then
      return false
    end

    local parent_cls = is_instance(parent) and classof(parent) or parent
    if child_parent == parent_cls then
      return true
    elseif parent.__class then
      return is_parent_of(parent.__class)
    else
      return false
    end
  end

  local function assert_parent_is_obj(parent, i)
    local _ok, _msg = is_object(parent, true)
    if not _ok then
      errorf('parents[%d]: %s', i, _msg)
    else
      return parent
    end
  end

  for i = 1, #parents do
    local parent = assert_parent_is_obj(parents[i], i)
    if is_parent_of(parent) then
      return true
    end
  end

  return false
end

---@param child instance
---@param parents object[]
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function inherits(child, parents, err_msg, prefix)
  parents = not is_pure_list(parents) and { parents } or parents
  if instanceof(child, unpack(parents)) then
    return true, nil
  end

  if err_msg then
    local names = foreach(parents, { map = class_name })
    names = table.concat(names, "|")
    local msg = sprintf("Expected any of classes %s, got %s", names, child.__name)
    msg = msg_with_prefix(msg, prefix)
    return false, msg
  end

  return false, nil
end

---@class foreach.opts
---@field keep? Filter Filter using this function
---@field map? Mapper Apply this function when when() and keep()
---@field when? Filter Apply opts.map|opts.each only when this condition matches
---@field exit? Filter Break loop and return if until() returns true
---@field filter? Filter (alias for keep)
---@field each? Callback Cannot be used with opts.map
---@field index? boolean Pass index/key
---@field iterator? (fun(x: table): any, any) (default: pairs)
---@field skip_nil? boolean (default: true)

---Very similar to cl-loop
---@param x table
---@param opts? foreach.opts
---@return table?
function foreach(x, opts)
  if not opts then
    return x
  end

  local function keep_with_index(_, _)
    return true
  end

  local function keep(_)
    return true
  end

  local function map_with_index(_, v)
    return v
  end

  local function map(v)
    return v
  end

  local function each_with_index(_, _)
  end

  local function each(_)
  end

  opts = opts or {}
  local skip_nil = opts.skip_nil
  local index = opts.index
  local _keep, _map, _when, _until, _each
  _each = opts.each
  _map = opts.map
  local has_each = _each ~= nil
  local res = not has_each and {} or nil

  if _each and _map then
    errorf("Cannot pass both opts.each and opts.map")
  end

  if index then
    _keep = opts.keep or opts.filter or keep_with_index
    _map = _map or map_with_index
    _when = opts.when or keep_with_index
    _until = opts.exit or function(_, _)
      return false
    end
    _each = _each or each_with_index
  else
    _keep = opts.keep or opts.filter or keep
    _map = _map or map
    _when = opts.when or keep
    _until = opts.exit or function(_, _)
      return false
    end
    _each = _each or each
  end

  for key, value in pairs(x) do
    ::next::

    if skip_nil and is_nil(value) then
      goto next
    else
      value = as_value(value)
    end

    if index then
      if _until(key, value) then
        if _each then
          return
        else
          return res
        end
      elseif _when(key, value) and _keep(key, value) then
        if _each then
          _each(key, value)
        else
          res[key] = _map(key, value)
        end
      end
    elseif _until(value) then
      if _each then
        return
      else
        return res
      end
    elseif _when(value) and _keep(value) then
      if _each then
        _each(value)
      else
        res[key] = _map(value)
      end
    end
  end

  return res
end

---@param x any[]|string
---@return any[]|string
function reverse(x)
  local res = {}
  if type(x) == 'string' then
    for i = #x, 1, -1 do
      res[#res + 1] = string.sub(x, i, i)
    end
    return table.concat(res, "")
  end

  for i = #x, 1, -1 do
    res[#res + 1] = x[i]
  end

  return res
end

---@param x type_table
---@return string?
function typeof(x)
  if type(x) == 'table' then
    return x.__type
  end
end

---@param x class
---@param fullname? boolean (default: true)
---@return string
function class_name(x, fullname)
  assert(is_object(x, true))

  fullname = fullname == nil and true or fullname
  local name = x.__name

  if not x.__class or not fullname then
    return name
  end

  local names = { name }
  local parent = x.__class

  while parent do
    names[#names + 1] = parent.__name
    parent = parent.__class
  end

  return table.concat(reverse(names), ".")
end

---@param x module
---@return string?
function module_name(x)
  if not is_module(x) then
    return
  end

  return x.__name
end

---@param x table
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_table(x, err_msg, prefix)
  x = as_value(x)
  if type(x) == 'table' then
    return true, nil
  elseif err_msg then
    local msg = sprintf('Expected table, got [%s] %s', type(x), x)
    msg = prefix and (prefix .. ': ' .. msg) or msg
    return false, msg
  else
    return false
  end
end

---@param x table
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_pure_table(x, err_msg, prefix)
  x = as_value(x)
  if type(x) == 'table' and not x.__type then
    return true, nil
  elseif err_msg then
    local msg = sprintf('Expected pure_table, got [%s] %s', type(x), x)
    msg = prefix and (prefix .. ': ' .. msg) or msg
    return false, msg
  else
    return false
  end
end

---@param tbl any[]
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_dict(tbl, err_msg, prefix)
  local ok, msg = is_table(tbl, err_msg, prefix)
  if not ok then
    return false, msg
  end

  local len = #tbl
  local len1 = 0

  for _, _ in pairs(tbl) do
    len1 = len1 + 1
  end

  if len1 == len then
    if err_msg then
      msg = sprintf('Expected dict, got [list] %s', type(tbl), tbl)
      msg = prefix and (prefix .. ': ' .. msg) or msg
      return false, msg
    else
      return false
    end
  end

  return true
end

---@param tbl any[]
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_list(tbl, err_msg, prefix)
  local ok, msg = is_table(tbl, err_msg, prefix)
  if not ok then
    return false, msg
  end

  local len = #tbl
  local len1 = 0

  for _, _ in pairs(tbl) do
    len1 = len1 + 1
  end

  if len1 ~= len then
    if err_msg then
      msg = sprintf('Expected list, got [dict] %s', tbl)
      msg = prefix and (prefix .. ': ' .. msg) or msg
      return false, msg
    else
      return false
    end
  end

  return true
end

---@param tbl any[]
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_pure_list(tbl, err_msg, prefix)
  local ok, msg = is_pure_table(tbl, true, prefix)
  if not ok then
    return false, msg
  elseif not is_list(tbl) then
    if err_msg then
      msg = sprintf('Expected pure_list, got [pure_dict] %s', tbl)
      msg = prefix and (prefix .. ': ' .. msg) or msg
      return false, msg
    else
      return false, nil
    end
  end

  return true
end

---@param tbl any[]
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_pure_dict(tbl, err_msg, prefix)
  local ok, msg = is_pure_table(tbl, true, prefix)
  if not ok then
    return false, msg
  elseif not is_dict(tbl) then
    if err_msg then
      msg = sprintf('Expected pure_dict, got [pure_list] %s', tbl)
      msg = prefix and (prefix .. ': ' .. msg) or msg
      return false, msg
    else
      return false, nil
    end
  end

  return true
end

---@param child class
---@param ... class
---@return boolean
function is_subclass(child, ...)
  if not is_class(child) then
    errorf("child: Expected class, got %s", type(child))
  end

  for i, parent in ipairs({ ... }) do
    ok, msg = is_class(parent, true)
    if not ok then
      errorf('...[%d]: %s', i, msg)
    elseif instanceof(child, parent) then
      return true
    end
  end

  return false
end

---Return unique items in a list
---@param x any[]
---@return any[]
function unique(x)
  local lookup = {}
  for i = 1, #x do
    lookup[x[i]] = true
  end

  local res = {}
  for key, _ in pairs(lookup) do
    res[#res + 1] = key
  end

  return res
end

---@param name string
---@param defaults? table<string|number,any>
---@return table
function defmodule(name, defaults)
  local mod = {}
  mod.__type = 'module'
  mod.__name = name
  mod.__index = rawget

  for key, value in pairs(defaults or {}) do
    mod[key] = value
  end

  setmetatable(mod, mod)
  return mod
end

module = defmodule

---@param x any
---@param err_msg? boolean
---@param prefix? string
---@return boolean, string?
function is_module(x, err_msg, prefix)
  if is_type(x) and x.__type == 'module' then
    return true, nil
  elseif not err_msg then
    return false, nil
  end

  local msg = string.format('Expected module, got [%s] %s', type(x), inspect(x))
  msg = msg_with_prefix(msg, prefix)
  return false, msg
end

---@param tbl? table|callable
---@param mt? table|callable
---@param typename? string
---@return table
---@overload fun(tbl: table): table
---@overload fun(tbl: callable): table
---@overload fun(tbl: table, mt: callable): table
---@overload fun(tbl: table, mt: table): table
---@overload fun(tbl: table, mt: type_table): table
---@overload fun(tbl: table, mt: table?, typename: string): table
function bless(tbl, mt, typename)
  local function mt_set_self(x)
    x.__index = x
    setmetatable(x, x)
    return x
  end

  local tbl_given = tbl ~= nil
  local mt_given = mt ~= nil
  local mt_callable = mt_given and type(tbl) == 'function'
  local tbl_callable = tbl_given and type(mt) == 'function'

  if mt_callable and tbl_callable then
    error('tbl and mt cannot be both functions')
  elseif tbl_callable and not mt_given then
    local f = tbl
    tbl = { __call = f, __type = typename }
    return mt_set_self(tbl)
  elseif not tbl_given and not tbl_given then
    tbl = {}
    mt = tbl
  elseif tbl_callable then
    local f = tbl
    mt.__call = f
    tbl = {}
  elseif mt_callable then
    local f = mt
    mt = tbl
    mt.__call = f
  end

  if not mt then
    mt = tbl
  end

  if not mt.__index then
    mt.__index = rawget
  end

  if not mt.__newindex then
    mt.__newindex = rawset
  end

  ---@type table|type_table
  return setmetatable(tbl, mt)
end

---@param tbl table
---@return table
function refself(tbl)
  tbl.__index = tbl.__index or rawget
  setmetatable(tbl, tbl)
  return tbl
end

is_plist = is_pure_list
is_pdict = is_pure_dict
is_ptable = is_pure_table

require 'lua-utils.guard'
require 'lua-utils.dump'
require 'lua-utils.union'
require 'lua-utils.guards'
require 'lua-utils.is'
require 'lua-utils.multimethod'
require 'lua-utils.class'
