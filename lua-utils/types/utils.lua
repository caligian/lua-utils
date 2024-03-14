require "lua-utils.copy"

inspect = require "inspect"
inspect = inspect.inspect

--- Dump object
--- @param x any
--- @return string
function dump(x)
  if type(x) == "string" or type(x) == "number" then
    return x
  end
  return inspect(x)
end

function dumpx(x, ws_n, mem, mem_id, v_mem, v_mem_id)
  mem = mem or setmetatable({}, {__mode = 'kv'})
  v_mem = v_mem or setmetatable({}, {__mode = 'kv'})
  mem_id = mem_id or 0
  v_mem_id = v_mem_id or 0

  if mem[x] then
    return mem[x]
  end

  mem[x] = "<" .. tostring(mem_id) .. ">"
  ws_n = ws_n or 0
  local ws = string.rep(' ', ws_n)
  local item_ws = string.rep(' ', ws_n+2)
  local later = {}
  local laterx = {}
  local ks = {}
  local vs = {}
  local key_name = function (k)
    return type(k) ~= 'string' and tostring(k) or k
  end
  local value_name = function (v)
    local id = "<" .. tostring(mem_id) .. ">"
    return id
  end
  local function ref(v)
    if v_mem[v] then
      return v_mem[v]
    end

    local t = type(v)
    if t ~= 'string' and t~= 'boolean' and t ~= 'number' then
      local name
      local r = tostring(v)
      name, _ = string.match(r, '^([^:]+): ')
      v_mem[v] = name ..":" .. v_mem_id .. ""
      v_mem_id = v_mem_id + 1

      return v_mem[v]
    end

    return tostring(v)
  end
  local s = {value_name(x), "{"}
  local i = 3
  local push = function (...)
    for _, y in ipairs {...} do
      s[i] = y
      i = i + 1
    end
  end

  for a, v in pairs(x) do
    if type(a) == 'string' and a:match('^__') then
      laterx[#laterx+1] = a
    elseif type(v) == 'table' then
      if not mem[v] then
        later[#later+1] = a
      else
        ks[#ks+1] = a
        vs[#vs+1] = mem[v]
      end
    elseif mem[v] then
      vs[#vs+1] = mem[v]
      ks[#ks+1] = a
    else
      vs[#vs+1] = v_mem[v] or v
      ks[#ks+1] = a
    end
  end

  for i = 1, #ks do
    ks[i] = key_name(ks[i])
    vs[i] = vs[i]
  end

  for i=1, #laterx do
    local k = laterx[i]
    local v = x[k]
    ks[#ks+1] = key_name(k)
    vs[#vs+1] = v
  end

  for i=1, #later do
    local k = later[i]
    local v = x[k]
    ks[#ks+1] = key_name(k)
    vs[#vs+1] = v
  end

  if #ks == 0 then
    return "{}"
  else
    push("\n")
  end

  local sprintf = string.format

  for i = 1, #ks do
    local key = ks[i]
    local value = vs[i]
    local fmt = "%s%s: %s\n"

    if mem[value] then
      push(sprintf(fmt, item_ws, key, mem[value]))
    elseif type(value) == 'table' then
      local msg = dumpx(value, ws_n+2, mem, mem_id+1, v_mem, v_mem_id)
      push(sprintf(fmt, item_ws, key, msg))
      mem[value] = tostring(value) 
      mem_id = mem_id + 1
    else
      push(sprintf(fmt, item_ws, key, ref(value)))
    end
  end

  push(ws, "}")

  return table.concat(s, "")
end

function ppx(x)
  print(dumpx(x))
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
table.metaevents = mtkeys

--- Is event a valid metatable event?
--- @param event string
--- @return boolean
function table.is_valid_event(event)
  return table.metaevents[event] and true or false
end

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

do
  local mt = {}
  --- Throw error if test fails like assert but with a name
  --- > throw.variable_name(is_table(1)) -- variable_name: expected table, got "1"
  --- @class throw
  --- @overload fun(name: string, test: boolean, msg?: string)
  throw = setmetatable({}, mt)

  function mt:__call(name, test, msg)
    if not test then
      name = type(name) == "string" and name or dump(name)
      error(
        dump(name) .. ": " .. debug.traceback(msg or "", 3)
      )
    end
  end

  function mt:__index(name)
    return function(obj, msg)
      return throw(name, obj, msg)
    end
  end
end

--- User defined guards
--- @class guards
--- @overload fun(name: string, fn: function): function
guards = {}
do
  guards = {
    --- Contains all the guards created hashed by string
    guards = {} --[[@as table<string,function>]],

    get = function(name)
      throw.name(
        type(name) == "string",
        "expected string, got " .. dump(name)
      )

      local exists = self.guards[name]
        or self.guards["is_" .. name]
      if exists then
        return exists
      end

      local Gfn = _G["is_" .. name]
      if not Gfn then
        return
      end

      self.guards[name] = Gfn
      self.guards["is_" .. name] = Gfn

      return self.guards[name], name
    end,

    create = function(name, fn, message)
      if type(name) == "table" then
        local opts = name
        fn = opts.guard
        message = opts.message
        name = opts.name
      end

      if name then
        name = name:gsub("^is_", "")
      end

      throw.fn(
        type(fn) == "function" or mtget(fn, "method"),
        "expected method, got " .. dump(fn)
      )

      local checker = {
        test = fn,
        dump = function(x)
          if not fn(x) then
            local mt = mtget(x)

            if mt then
              local has_tp = mt.type or "table"
              local ismethod = mt.method
              local isinst = mt.instance
              local msg
              message = message or "guard failed"

              if isinst then
                msg = string.format(
                  "%s\nvalue: <%s: instance> %s",
                  message,
                  has_tp,
                  dump(x)
                )
              elseif ismethod then
                msg = string.format(
                  "%s\nvalue: <method> %s",
                  message,
                  dump(x)
                )
              else
                msg = string.format(
                  "%s\nvalue: <%s> %s",
                  message,
                  has_tp,
                  dump(x)
                )
              end

              return false, msg
            end

            local msg = string.format(
              "%s\nvalue: <%s> %s",
              message or "guard failed",
              type(x),
              dump(x),
              x
            )
            return false, msg
          end

          return true
        end,
      }

      function checker.assert(x)
        assert(checker.dump(x))
        return true
      end

      checker.opt = {
        dump = function(x)
          if x == nil then
            return true
          end
          return checker.dump(x)
        end,
        assert = function(x)
          if x == nil then
            return true
          end
          return checker.assert(x)
        end,
      }

      mtset(checker, {
        __call = function(_, obj, opts)
          opts = opts or {}
          if opts.opt and obj == nil then
            return true
          elseif opts.dump then
            if opts.assert then
              return assert(checker.dump(obj))
            else
              return checker.dump(obj)
            end
          elseif opts.assert then
            return assert(checker.dump(obj))
          else
            return fn(obj)
          end
        end,
        __index = function(_, prefix)
          return function(obj, opts)
            return checker(obj, opts)
          end
        end,
        method = true,
      })

      if name then
        guards.guards[name] = checker
        guards.guards["is_" .. name] = checker
        guards.guards[checker] = checker
        _G["is_" .. name] = checker
      end

      return checker
    end,
  }

  local mt = {}

  local function mkbuiltin(tp, fn)
    guards.create(tp, fn or function(x)
      return type(x) == tp
    end, string.format("expected type %s", tp))
  end

  local builtin = {
    "table",
    "string",
    "number",
    "userdata",
    "function",
    "thread",
    "boolean",
  }

  for i = 1, #builtin do
    mkbuiltin(builtin[i])
  end

  local maker = mtset({}, {
    __newindex = function(_, name, fn)
      local message = name:gsub("^is_", "")
      mkbuiltin(name, fn)
    end,
  })

  function maker.is_nil(x)
    return x == nil
  end

  function maker.empty(x)
    local x_type = type(x)

    if x_type == "string" then
      return #x == 0
    elseif x_type ~= "table" then
      return false
    end

    return size(x) == 0
  end

  function maker.ns(x)
    return typeof(x) == "ns"
  end

  function maker.class(x)
    return typeof(x) == "class"
  end

  function maker.instance(x)
    if not is_table(x) then
      return false
    end

    local mt = mtget(x) or {}
    if mt.instance and mt.class and is_class(mt.class) then
      return true
    end

    return false
  end

  function maker.class_object(x)
    if is_class(x) or is_instance(x) then
      return true
    end
    return false
  end

  function maker.method(x)
    local is_f = is_function
    local is_t = is_table

    local function recursive_check(x)
      if is_f(x) then
        return true
      elseif not is_t(x) then
        return false
      end

      local mt = mtget(x) or {}
      if
        mt.__call
        and x.type == "method"
        and recursive_check(mt.__call)
      then
        return true
      end

      return false
    end

    return recursive_check(x)
  end

  function maker.list(x)
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

  function maker.dict(x)
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

  function maker.instance(self)
    return is_table(self) and is_class(self.class)
  end

  function maker.literal(x)
    return (is_string(x) or is_number(x) or is_boolean(x))
      or false
  end
end

--------------------------------------------------
--- Return type based on lua type or <metatable>.type
--- @param x any
--- @return string?
function typeof(x)
  local x_type = type(x)

  if type(x) == "table" then
    if x.type then
      return x.type
    end
    return "table"
  end

  return x_type
end

--- Check if x and y point to the same object
--- @param x table
--- @param y table
--- @return boolean
function sameref(x, y)
  return ref(x) == ref(y)
end

function tolist(x, force)
  if force then
    return { x }
  elseif is_method(x) or not is_table(x) then
    return { x }
  else
    return x
  end
end

base = {
  type = 'class',
  name = 'base',
  init = function (self, ...)
    return self, ...
  end,
}
base.__index = base
base.__tostring = dumpx

function base.new(cls, ...)
  local obj = {type = 'instance', name = cls.name, class = cls}
  cls.__index = cls
  setmetatable(obj, cls)

  if cls.init then
    return cls.init(obj, ...)
  end

  return obj, ...
end
base.__call = base.new

function base.is_parent_of(cls, inst)
  if not is_class_object(cls) or not is_class_object(inst) then
    return false
  end

  if is_instance(cls) then
    cls = cls.class
  end

  if is_instance(inst) then
    inst = inst.class
  end

  if cls == inst.class then
    return true
  end

  return base.is_parent_of(cls, inst.class)
end

function base.is_child_of(cls, inst)
  return base.is_parent_of(inst, cls)
end

function base.is_a(cls, inst, opts)
  opts = opts or {}
  local d = opts.dump
  local a = opts.assert
  local ok = cls == inst or cls == mtget(inst) or cls:is_parent_of(inst)

  if not ok then
    if d or a then
      local msg = string.format('expected %s, got %s', cls.name, dump(inst))  
      if d then
        return false, msg
      end
      assert(msg)
    else
      return false
    end
  else
    return true
  end
end

function class(cls)
  cls = cls or {}
  is_table.assert(cls)
  local init = cls.init
  cls.__index = cls
  cls.__tostring = dumpx
  cls.class = cls.class or base
  setmetatable(cls, cls.class)

  return cls
end

local A = class {name = 'A'}
local B = class {name = 'B', class = A, init = function (obj, ...)
  obj.args = {...}
  return obj
end}
local C = class {name = 'C', class = B}
print(C.init(C, 1, 23):is_child_of(B))
