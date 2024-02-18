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
function package.is_valid_event(event)
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
      if not fn then
        fn, name = checker.get(name)
      else
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
              message,
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
              assert(checker.dump(obj))
            else
              return checker.dump(obj)
            end
          elseif opts.assert then
            assert(checker.dump(obj))
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

      guards.guards[name] = checker
      guards.guards["is_" .. name] = checker
      guards.guards[checker] = checker
      _G["is_" .. name] = checker

      return self
    end,
  }

  local mt = {
    type = "ns",
    __newindex = function(self, name, fn)
      local create = rawget(self, "create")
      return create(self, name, fn)
    end,
    __call = function(self, ...)
      return self:create(...)
    end,
    guards = guards.guards,
  }

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
    return is_class(x) or is_instance(x) or false
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
        and mt.method
        and recursive_check(mt.__call)
      then
        return true
      end

      return false
    end

    return recursive_check(x)
  end

  function maker.list(x, list_like)
    if not is_table(x) then
      return false
    end

    local mt = not list_like and getmetatable(x)
    if mt and mt.type ~= "list" then
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

  function maker.dict(x, dict_like)
    if not is_table(x) then
      return false
    elseif not dict_like then
      local mt = getmetatable(x)
      if mt then
        if mt.type == "dict" then
          return true
        elseif mt.type ~= nil then
          return false
        end
      end
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
    local mt = mtget(self)
    if not mt then
      return false
    end

    return mt.instance and is_class(mt.class)
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
  if x_type ~= "table" then
    return x_type
  elseif is_method(x) then
    return "method"
  elseif is_list(x) then
    return "list"
  elseif is_dict(x) then
    return "dict"
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

--- @alias defn.fn (fun(self:table, ...:any): any)
--- @alias defn.return {[1]: defn.fn, is_a?: function[], apply?: function}

--- @class defn.form
--- @field [1] number
--- @field [2] defn.fn
--- @field is_a? function[]
--- @field apply? function

--- Define a non-variadic method with function signatures bound to parameter lengths
--- This is less powerful but much faster than multimethod() which only works on parameter signatures
--- @param ... defn.form
--- @return table<number, defn.return>
function defn(...)
  local mt = { method = true }
  local mod = setmetatable({}, mt)
  local sigs = { ... }

  for i = 1, #sigs do
    local sig = sigs[i]
    --- @cast sig defn.form

    if not is_table(sig) then
      error(
        i
          .. ": expected {number, method}, got "
          .. dump(sig)
      )
    end

    local n, fn, isa = tuple.unpack(sig)
    isa = sig.is_a
    if
      not (
        is_number(n)
        and is_method(fn)
        and is_table.opt.assert(isa)
      )
    then
      error(
        i
          .. ": expected {number, method, is_a = [constraint[]]}, got "
          .. dump(sig)
      )
    end

    if isa then
      for j = 1, #isa do
        if not is_method(isa[j]) then
          error(
            i
              .. "."
              .. j
              .. "<is_a>: "
              .. "expected method, got "
              .. dump(isa[j])
          )
        end
      end
    end

    mod[n] = {
      fn,
      is_a = sig.is_a,
      apply = function(...)
        return fn(mod, ...)
      end,
    }--[[@as defn.return]]
  end

  function mt:__call(...)
    local params = tuple.pack(...)
    local n = #params
    local def = mod[n]

    if not def then
      error(
        string.format(
          "invalid method signature\n<%d>: %s",
          n,
          dump(params)
        )
      )
    end

    isa = def.is_a
    def = def[1]

    if isa then
      for i = 1, #isa do
        local checker = isa[i]
        if guards.guards[checker] then
          local ok, msg = checker.dump(params[i])
          if not ok then
            error(i .. ": " .. msg)
          end
        else
          local ok, msg = checker(params[i])
          if not ok then
            if msg then
              error(i .. ": " .. msg)
            else
              error(
                i
                  .. ": type validation failed for "
                  .. dump(params[i])
              )
            end
          end
        end
      end
    end

    return def(mod, ...)
  end

  return mod--[[@as table<number, defn.return>]]
end
