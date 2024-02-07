require "lua-utils.copy"

inspect = require "inspect"
inspect = inspect.inspect

--- @alias method function|table

--- Dump object
--- @param x any
--- @return string
function dump(x)
  if type(x) == 'string' or type(x) == 'number' then
    return x
  end
  return inspect(x)
end

--- Valid lua metatable keys
--- @enum
local mtkeys = {
  __unm = true,
  __eq = true,
  __ne = true,
  __ge = true,
  __gt = true,
  __le = true,
  __lt = true,
  __add = true,
  __sub = true,
  __mul = true,
  __div = true,
  __mod = true,
  __pow = true,
  __tostring = true,
  __tonumber = true,
  __index = true,
  __newindex = true,
  __call = true,
  __metatable = true,
  __mode = true,
}

--- All valid metatable events
package.metatable_events = mtkeys

--- Is event a valid metatable event?
--- @param event string
--- @return boolean
function package:is_valid_event(event)
  return package.metatable_events[event] and true or false
end

is_valid_event = package.is_valid_event

--- Get metatable or metatable key
--- @param obj table
--- @param k? any a key. If not given then return metatable
--- @return any value metatable or value
function mtget(obj, k)
  if type(obj) ~= "table" then
    return
  end

  local mt = getmetatable(obj)
  if not mt then
    return
  end

  if k ~= nil then
    return mt[k]
  end

  return mt
end

--- Set metatable or metatable key
--- > -- this will set the metatable
--- > mtset({}, {})
--- >
--- > -- this will set this value
--- > mtset(obj, 'a', 'b')
--- @overload fun(x:table, mt:table): table
--- @overload fun(x: table, key:any, value:any): table
function mtset(...)
  local n = select("#", ...)
  local args = { ... }
  x = args[1]

  if n == 1 then
    error("need at least 2 params, got " .. n)
  elseif n == 2 then
    local mt = args[2]
    if type(mt) ~= "table" then
      return
    end

    return setmetatable(x, mt)
  end

  local mt = getmetatable(x) or {}
  mt[args[2]] = args[3]

  return setmetatable(x, mt)
end

--- @param x any
--- @param force? bool forcefully wrap the elem in a table?
--- @return table
function totable(x, force)
  if force then
    return { x }
  elseif type(x) == "table" then
    return x
  else
    return { x }
  end
end

to_table = totable
to_string = tostring
to_number = tonumber

--- Return type based on lua type or <metatable>.type
--- @param x any
--- @return string?
function typeof(x)
  local x_type = type(x)

  if x_type ~= "table" then
    return x_type
  elseif is_list(x) then
    return "list"
  end

  local x_mt = getmetatable(x)
  if not x_mt then
    return "table"
  elseif not x_mt.type then
    return "table"
  else
    return x_mt.type
  end
end

--- Is x a string?
--- @param x any
--- @return boolean,string?
function is_string(x)
  local ok = type(x) == "string"
  local msg = "expected string, got " .. dump(x)

  if not ok then
    return false, msg
  end

  return true
end

--- Is x a table?
--- @param x any
--- @return boolean,string?
function is_table(x)
  local ok = type(x) == "table"

  if not ok then
    local msg = "expected table, got " .. dump(x)
    return false, msg
  end

  return true
end

--- Is x a function?
--- @param x any
--- @return boolean,string?
function is_function(x)
  local ok = type(x) == "function"
  local msg = "expected function, got " .. dump(x)

  if not ok then
    return false, msg
  end

  return true
end

--- Is x a userdata?
--- @param x any
--- @return boolean,string?
function is_userdata(x)
  local ok = type(x) == "userdata"

  if not ok then
    local msg = "expected userdata, got " .. dump(x)
    return false, msg
  end

  return true
end

--- Is x a thread?
--- @param x any
--- @return boolean,string?
function is_thread(x)
  local ok = type(x) == "thread"
  local msg = "expected thread, got " .. dump(x)

  if not ok then
    return false, msg
  end

  return true
end

--- Is x a boolean?
--- @param x any
--- @return boolean,string?
function is_boolean(x)
  local ok = type(x) == "boolean"

  if not ok then
    local msg = "expected boolean, got " .. dump(x)
    return false, msg
  end

  return true
end

--- Is x a number?
--- @param x any
--- @return boolean,string?
function is_number(x)
  local ok = type(x) == "number"

  if not ok then
    local msg = "expected number, got " .. dump(x)
    return false, msg
  end

  return true
end

--- Is x a function (__call is nonnil or x is a function)?
--- @param x any
--- @return boolean,string?
function is_callable(x)
  local tp = type(x)

  if tp == "function" then
    return true
  elseif tp ~= "table" then
    return false, "expected table|function, got " .. dump(tp)
  end

  local mt = getmetatable(x)
  if not mt then
    return false, "metatable missing"
  end

  local ok = mt.__call ~= nil
  if not ok then
    return false, "__call metamethod missing"
  end

  return true
end

--- Is x nil
--- @param x any
--- @return boolean
function is_nil(x)
  return x == nil
end

--- Is empty?
--- @param x string|list
--- @return boolean
function is_empty(x)
  local x_type = type(x)

  if x_type == "string" then
    return #x == 0
  elseif x_type ~= "table" then
    return false
  end

  return size(x) == 0
end

--- Return length of string|non-lists
--- @param t string|table
--- @return integer?
function size(t)
  local t_type = type(t)

  if t_type == "string" then
    return #t
  elseif t_type ~= "table" then
    return
  end

  local n = 0
  for _, _ in pairs(t) do
    n = n + 1
  end

  return n
end

--- Check if a X is a nonempty list of elements
--- @param x any[] x should not have a metatable unless the latter is defined
--- @param list_like? boolean skip metatable check
--- @return any[]|false
--- @return string? message failure message
function is_list(x, list_like)
  if not is_table(x) then
    return false, "expected table, got " .. dump(x)
  end

  local mt = not list_like and getmetatable(x)
  if mt and mt.type ~= "list" then
    return false, "expected list, got " .. dump(x)
  end

  local len = size(x)
  if len == 0 then
    return false, "expected list, got empty table"
  end

  local ok = len == #x
  if not ok then
    return false, "expected list, got dict"
  end

  return x
end

--- Check if a X is a nonempty table that is not a list
--- @param x table x should not have a metatable unless the latter is defined
--- @param dict_like? boolean skip metatable check
--- @return table|false
--- @return string? message failure message
function is_dict(x, dict_like)
  if not is_table(x) then
    return false, "expected table, got " .. dump(x)
  elseif not dict_like then
    local mt = getmetatable(x)
    if mt then
      if mt.type == "dict" then
        return x
      elseif mt.type ~= nil then
        return false, "expected dict, got " .. dump(x)
      end
    end
  end

  local len = size(x)
  if len == 0 then
    return false, "expected dict, got empty table"
  elseif len == #x then
    return false, "expected dict, got list " .. dump(x)
  else
    return x
  end
end

--- Check if self is an instance
--- @param self table
--- @return table? self self
--- @return string? message error message
function is_instance(self)
  local inst, msg = mtget(self, instance)

  if not inst then
    return nil, msg or ("expected object, got " .. dump(self))
  end

  return self
end

--- Check if x is an literal
--- Literals as in string, number and boolean
--- @param x string|number|boolean
--- @return (string|number|boolean)?
function is_literal(x)
  return (is_string(x) or is_number(x) or is_boolean(x)) and x
end

--- Get table reference string. This will temporarily modify tables with custom __tostring methods
--- @param x table
--- @return string
function ref(x)
  if not is_table(x) then
    return
  end

  local mt = getmetatable(x)
  if not mt then
    return tostring(x)
  end

  local tostring = rawget(mt, "__tostring")
  rawset(mt, "__tostring", nil)
  local id = tostring(x)
  rawset(mt, "__tostring", tostring)

  return id
end

--- Check if x and y point to the same object
--- @param x table
--- @param y table
--- @return boolean
function sameref(x, y)
  return ref(x) == ref(y)
end

local throw_mt = {}
--- Throw error if test fails like assert but with a name
--- > throw.variable_name(is_table(1)) -- variable_name: expected table, got "1"
--- @overload fun(name: string, test: boolean, msg?: string)
throw = setmetatable({}, throw_mt)

function throw_mt:__call(name, test, msg)
  if not test then
    name = type(name) == "string" and name or dump(name)
    error(dump(name) .. ": " .. debug.traceback(msg or "", 3))
  end
end

function throw_mt:__index(name)
  return function(obj, msg)
    return throw(name, obj, msg)
  end
end

--- Is ns?
--- @param x any
--- @return boolean,string?
function is_ns(x)
  local ok = typeof(x) == "ns"

  if not ok then
    return false, "expected ns, got " .. dump(x)
  end

  return x
end

function is_class(x)
  local ok = typeof(x) == "class"
  if not ok then
    return nil, "expected class, got " .. dump(x)
  end
  return x
end

function is_instance(x)
  local mt = mtget(x)
  local fail = not mt or not mt.type or not mt.class or not mt.instance or not is_class(mt.class)

  if fail then
    return nil, "expected instance, got " .. dump(x)
  end

  return x
end

function is_class_object(x)
  local ok = is_class(x) or is_instance(x) and x
  if not ok then
    return nil, "expected class or instance, got " .. dump(x)
  end
  return x
end

--- Check if args are a function or method (table with mt.__call and mt.method = true)
--- @overload fun(mod: table, f: string): function?, string?
--- @overload fun(obj: table|function): (table|function)?, string?
function is_method(...)
  local is_f = is_function
  local is_t = is_table

  local function recursive_check(x)
    if is_f(x) then
      return x
    elseif not is_t(x) then
      return nil, 'expected table or function, got ' .. dump(x)
    end

    local mt = mtget(x) or {}
    if mt.__call and mt.method and recursive_check(mt.__call) then
      return x
    end

    return nil, 'expected table with mt.method and mt.__call<method|function>, got ' .. dump(x)
  end

  local args = {...}
  local nargs = #args

  if nargs == 1 then
    return recursive_check(args[1])
  elseif nargs ~= 2 then
    return nil, 'expected <function>|<table>, <field>, got ' .. dump(args)
  end

  return recursive_check(unpack(args))
end

--- Define a method object. This is useful for differentiating instances and types from methods
--- @overload fun(fn: method): table
--- @overload fun(mod: table, fn: method): table
function defn(...)
  local args = {...}
  local nargs = #args

  local function create(f, obj)
    local mt = {method = true}
    obj = mtset(obj or {}, mt)

    function mt:__call(...)
      return f(...)
    end

    return obj
  end

  if nargs == 1 then
    local f = args[1]
    assert(is_method(f))

    return create(f)
  elseif nargs == 2 then
    local m = args[1]
    local f = args[2]

    assert(is_table(m))
    assert(is_method(f))

    return create(f, m)
  end

  error('expected table with at least 1 value, got ' .. dump(args))
end

