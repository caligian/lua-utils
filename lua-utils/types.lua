require "lua-utils.core"

types = {
  builtin = {
    number = true,
    userdata = true,
    string = true,
    ["function"] = true,
    thread = true,
    boolean = true,
    table = true,
  },
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
    __mod = true,
    __pow = true,
    __div = true,
    __mul = true,
    __concat = true,
  },
}

for key, value in pairs(types.builtin) do
  types[key] = function(x, dmp)
    local ok = type(x) == key
    if dmp and not ok then
      return false,
        ("expected " .. key .. " got " .. dump(x))
    elseif not ok then
      return false
    end
    return true
  end
end

function types.method(self, dmp)
  local t = type(self)
  if t == "function" then
    return true
  elseif type(self) ~= "table" then
    if dmp then
      return false,
        "expected table with __call|function, got " .. dump(
          self
        )
    end
  end

  local mt = mtget(self)
  if mt then
    return types.method(mt.__call)
  end

  if dmp then
    return false, "expected method, got " .. dump(self)
  end

  return false
end

function types.not_empty(x, dmp)
  if not types.table(x) then
    return false
  end
  local ok = size(x) ~= 0
  if not ok and dmp then
    return false,
      "expected non-empty table, got " .. dump(x)
  elseif not ok then
    return false
  end
  return true
end

function types.empty(x, dmp)
  if not types.table(x) then
    return false
  end
  local ok = size(x) == 0
  if not ok and dmp then
    return false, "expected empty table, got " .. dump(x)
  elseif not ok then
    return false
  end
  return true
end

function types.list(x, dmp)
  if not types.table(x) then
    return false
  end
  local ok = size(x) == #x
  if not ok and dmp then
    return false, "expected list, got " .. dump(x)
  elseif not ok then
    return false
  end
  return true
end

function types.dict(x, dmp)
  if not types.table(x) then
    return false
  end
  local ok = size(x) ~= #x
  if not ok and dmp then
    return false, "expected dict, got " .. dump(x)
  elseif not ok then
    return false
  end
  return true
end

local function cmp_other(x, y, dmp)
  if x == y then
    return true
  end

  local ok, msg
  if types.method(y) then
    if dmp then
      return y(x, true)
    else
      return y(x)
    end
  end

  ok = x == y
  if not ok then
    if dmp then
      return false, dump { expected = true }
    else
      return false
    end
  else
    return true
  end
end

local function get(a, key)
  local X
  local opt, k
  local is_m = types.metaevents[key]
  X = is_m and mtget(a, key) or a[key]

  if X == nil and is_m then
    return
  end

  if types.string(key) then
    if not X then
      opt, k = key:match "^(opt_)(.+)"
      k = k or key
      X = a[k]
    end

    if X == nil then
      if opt then
        return nil, "skip"
      else
        return
      end
    end
  end

  return X
end

local function next(a, b, dest, dmp)
  if a == b then
    return { ok = true }
  end

  local A_t = types.table(a)
  local B_t = types.table(b) and not types.method(b)

  if not A_t and not B_t then
    local ok, msg
    if dmp then
      ok, msg = cmp_other(a, b, true)
    else
      ok = cmp_other(a, b)
    end

    if not ok then
      return {
        ok = false,
        msg = msg and prefix .. ": " .. msg,
      }
    else
      return { ok = true }
    end
  elseif not B_t or not A_t then
    return { ok = false }
  else
    local ok, msg = cmp_other(a, b, dmp)
    return { ok = ok, msg = msg and prefix .. ": " .. msg }
  end

  return { table = true }
end

local function cmp_table(x, spec, prefix, dmp)
  prefix = prefix or "<base>"

  if not types.table(x) then
    local ok, msg = cmp_other(x, spec, dmp)
    if not ok and msg then
      msg = prefix .. ": " .. msg
    end
    return { ok = ok, msg = msg }
  end

  for key, Y in pairs(spec) do
    local X, skip = get(x, key)
    local k = prefix .. "." .. tostring(key)

    if not skip then
      if X == nil then
        return {
          ok = false,
          msg = dmp and k .. ": " .. "expected non-nil",
        }
      end

      local ok = next(X, Y, k)
      if ok.table then
        ok = cmp_table(X, Y, k, dmp)
        if not ok.ok then
          return ok
        end
      elseif not ok.ok then
        return ok
      end
    end
  end

  return { ok = true }
end

function types.is_a(x, y, dmp)
  local res

  if type(y) == "table" and not types.method(y) then
    res = cmp_table(x, y, nil, dmp)
  else
    local ok, msg = cmp_other(x, y, dmp)
    res = { ok = ok, msg = msg }
  end

  if not res.ok then
    if dmp then
      local msg = res.msg
        or "validation failed for " .. dump(x)
      return false, msg
    else
      return false
    end
  else
    return true
  end
end

is_a = mtset({
  assert = function(x, y)
    assert(types.is_a(x, y, true))
    return true
  end,
  dump = function(x, y)
    return types.is_a(x, y, true)
  end,
}, {
  __index = function(self, y)
    return function(x, msg)
      return self(x, y, msg)
    end
  end,
  __call = function(self, x, y, dmp)
    if y == nil then
      return self.match(x)
    else
      return types.is_a(x, y, dmp)
    end
  end,
})

function is_a.match(specs)
  for key, value in pairs(specs) do
    local eq, format, _assert
    compare = value.compare
    format = value.format
    with = value.with
    opt = value.opt

    if with == nil then
      error(dump(key) .. ".with: expected non-nil value")
    end

    if not opt and compare == nil then
      error(dump(key) .. ".compare: expected non-nil value")
    end

    local ok, msg = types.is_a(compare, with, true)
    if not ok then
      msg = dump(key) .. ": " .. msg
      error(msg)
    end
  end
end

class = {}
class.__index = class

function class:implements(...)
  local args = { ... }
  for i = 1, #args do
    if types.is_a(self, args[i]) then
      return args[i]
    end
  end
  return false
end

function class:include(...)
  local args = { ... }
  for i = 1, #args do
    for key, value in pairs(args[i]) do
      if self[key] == nil then
        self[key] = value
      end
    end
  end
  return self
end

class.is_a = class.implements

function class:new(cls)
  if types.string(cls) then
    _G[cls] = {}
    cls = _G[cls]
  else
    cls = cls or {}
  end

  for key, value in pairs(class) do
    cls[key] = value
  end

  cls.__index = cls

  function cls:new(...)
    local obj = mtset({}, cls)
    for key, value in pairs(self) do
      obj[key] = value
    end
    if self.init then
      return self.init(obj, ...)
    end
    return obj, ...
  end

  mtset(cls, class)

  return cls
end

function implements(x, ...)
  local _types = { ... }
  for i = 1, #_types do
    if types.is_a(x, _types[i]) then
      return true
    end
  end
  return false
end

function union(...)
  local _types = { ... }
  return function(x)
    local fail = {}
    for i = 1, #_types do
      local ok, msg = types.is_a(x, _types[i], true)
      if ok then
        return true
      elseif msg then
        fail[#fail + 1] = msg
      end
    end
    return false, table.concat(fail, "\n")
  end
end

function types.gen_guard(name, spec)
  if types.table(name) then
    spec = name
    name = nil
  end
  local mt = {}
  local g = {}
  local opt_mt = {}
  g.opt = {}

  mtset(g, mt)
  mtset(g.opt, opt_mt)

  function g.dump(x)
    local ok, msg = is_a(x, spec, true)
    if ok then
      return true
    end
    return false, msg
  end

  function g.assert(x)
    assert(g.dump(x))
    return true
  end

  function mt:__call(x, dmp)
    return is_a(x, spec, dmp)
  end

  function opt_mt:__call(x, dmp)
    if x == nil then
      return true
    end
    return is_a(x, spec, dmp)
  end

  function g.opt.dump(x)
    if x == nil then
      return true
    end
    return g.dump(x)
  end

  function g.opt.assert(x)
    local ok, msg = g.opt.dump(x)
    if ok then
      return true
    end
    error(msg)
  end

  if name then
    _G["is_" .. name] = g
  end

  return g
end

for key, value in pairs(types) do
  if
    key ~= "builtin"
    and key ~= "metaevents"
    and key ~= "gen_guard"
    and key ~= "define"
    and key ~= "is_a"
  then
    types.gen_guard(key, value)
  end
end

function types.define(...)
  local args = { ... }
  local TYPE

  local function merge(args, start)
    start = start or 1
    for i = start, #args do
      for key, value in pairs(args[i]) do
        if TYPE[key] == nil then
          TYPE[key] = value
        end
      end
    end
  end

  if types.string(args[1]) then
    TYPE = args[2]
    types[args[1]] = TYPE
    merge(args, 3)
  else
    TYPE = args[1]
    merge(args, 2)
  end

  return TYPE
end

function defmulti(mod)
  local mt = {}
  local mod = mod or mtset({}, mt)

  function mod:match(...)
    local params = { ... }

    for key, value in pairs(mod) do
      if key ~= "match" and key ~= "default" then
        if is_a(totable(value.when), params) then
          return value(...)
        end
      end
    end

    if mod.default then
      return mod.default(mod, ...)
    end
  end

  function mt:__newindex(key, value)
    mtset(value, {
      __call = function(_, ...)
        return value.call(self, ...)
      end,
    })
    rawset(self, key, value)
  end

  mt.__call = mod.match
  return mod
end

function optional(...)
  local args = { ... }
  return function(x)
    if x == nil then
      return true
    end
    return union(unpack(args))(x)
  end
end

-- local mm = defmulti()
-- mm.strings = {
-- 	when = 'a',
-- 	call = function(self, ...)
-- 		pp{1, 'ehlll', ...}
-- 	end
-- }
--
-- mm.numbers = {
-- 	when = {{1, 2, 3, -4}},
-- 	call = function(self, ...)
-- 		pp(self.strings)
-- 		return mm.strings
-- 	end
-- }
--
-- mm {1, 2, 3, -4}
--
-- types.A = {
--  	x = types.number,
--  	y = types.number,
-- }
--
-- types.B = {
-- 	a = types.number,
-- 	b = 1.1,
-- }
--
-- types.define('C', {}, types.A, types.B)
--
-- types.object = {
-- 	is_a = types.method,
-- }
--
-- types.class = {
-- 	new = types.method,
-- }
--
-- --
-- local A = class:new()
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
-- --
-- local spec = {
-- 	1, types.method,
-- 	__call = { __call = types.method},
-- }
--
-- local x = mtset({1, print}, {
-- 	__call = mtset({}, {__call = print})
-- })
--
-- local a = A:new()
-- a.x = 1
-- a.y = 2
-- pp(a:implements(A, types.A))
-- pp(is_a(a, types.object))
