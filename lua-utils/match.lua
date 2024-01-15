require "lua-utils.table"
require "lua-utils.copy"

case = namespace()
case.rules = namespace()

function case.var(name, test)
  if type(name) ~= "string" and type(name) ~= "number" then
    test = name
    name = nil
  end

  return setmetatable({ name = name, test = test }, { type = "match.variable" })
end

--- @param x any
--- @return boolean
function case.is_var(x)
  return mtget(x --[[@as table]], "type") == "match.variable"
end

case.V = case.var

function case.test(obj, spec, opts)
  opts = opts or {}
  local eq = opts.eq
  local cond = opts.cond
  local match = opts.match
  local ass = opts.assert

  if is_function(spec) and (cond or match) then
    local ok, msg = spec(obj)
    if not ok then
      if ass then
        if msg then
          error(msg)
        else
          error("callable failed for " .. dump(obj))
        end
      else
        return false, msg
      end
    else
      return obj
    end
  elseif is_table(obj) and not is_table(spec) then
    return false
  elseif not is_table(obj) then
    if is_table(spec) then
      return false
    elseif eq then
      if eq(obj, spec) then
        return obj
      else
        return false
      end
    elseif obj ~= spec then
      return false
    else
      return obj
    end
  end

  local pre_a = opts.pre_a
  local pre_b = opts.pre_b
  local absolute = opts.absolute
  local same_size = opts.same_size
  local capture = opts.capture

  if ass then
    absolute = true
    match = false
    capture = false
    cond = true
  end

  if capture then
    function pre_b(y)
      if is_table(y) then
        return y
      end
      assert(is_string(y), "expected capture variable name (string), got " .. type(y))
      return case.var(y)
    end

    match = true
  end

  if match then
    absolute = true
    cond = false
  end

  if same_size and size(obj) ~= size(spec) then
    return false
  end

  local vars = match and {}
  local Vars = vars
  local Obj = obj
  local Spec = spec

  local queue = {
    add = function(self, item)
      self[#self + 1] = item
    end,
    pop = function(self)
      local item = self[#self]
      self[#self] = nil

      return item
    end,
  }

  local state = not absolute and {}
  local State = state
  local prefix = ""

  local function cmp(x, y, k, prefix)
    if not prefix then
      prefix = k
    else
      prefix = prefix .. "." .. k
    end

    if not is_nil(x) and pre_a then
      x = pre_a(x)
    end

    if pre_b then
      y = pre_b(y)
    end

    if is_nil(x) then
      if ass then
        error(prefix .. ": expected value, got nil")
      elseif absolute then
        return false
      else
        State[key] = false
      end
    elseif case.is_var(y) then
      assert(match, ".match should be true for using match.variable")

      y.name = y.name or k
      local test = y.test
      local name = y.name

      if is_nil(test) then
        Vars[name] = x
      elseif is_table(test) then
        if not is_table(x) then
          if ass then
            error(prefix .. ": expected table, got " .. type(x))
          else
            return false
          end
        else
          Vars[name] = {}
          queue:add { x, test, vars = Vars[name], prefix = prefix }
        end
      elseif is_function(test) then
        local ok, msg = test(x)
        if ok then
          Vars[name] = x
        elseif ass then
          if msg then
            error(prefix .. ": " .. msg)
          end
          error(prefix .. ": callable failed for " .. dump(x))
        else
          return false
        end
      else
        error "match.variable.test should be (function|table)?"
      end
    elseif is_table(y) then
      if not is_table(x) then
        if ass then
          error(prefix .. ": expected table, got " .. type(x))
        elseif absolute then
          return false
        else
          State[key] = false
        end
      elseif not absolute then
        State[k] = {}
        queue:add {
          x,
          y,
          prefix = prefix,
          state = State--[[@as table]][k],
        }
      elseif match then
        queue:add { x, y, vars = Vars, prefix = prefix }
      else
        queue:add { x, y, prefix = prefix }
      end
    elseif (cond or match) and is_function(y) then
      local ok, msg = y(x)
      if ok then
        if not absolute then
          State[key] = true
        end
      elseif ass then
        if msg then
          error(prefix .. ": " .. msg)
        end
        error(prefix .. ": callable failed for " .. dump(obj_value))
      elseif absolute then
        return false
      else
        State[key] = false
      end
    elseif eq then
      if eq(x, y) then
        if not absolute then
          State[key] = true
        end
      elseif ass then
        error(prefix .. ": unequal elements: \n" .. dump(x) .. "\n" .. dump(y))
      elseif absolute then
        return false
      end
    elseif x ~= y then
      if ass then
        error(prefix .. ": unequal elements: \n" .. dump(x) .. "\n" .. dump(y))
      elseif absolute then
        return false
      else
        State[key] = false
      end
    elseif not absolute then
      State[key] = true
    end

    return true
  end

  while Obj and Spec do
    if same_size and size(Obj) ~= size(Spec) then
      return false
    end

    for i, validator in pairs(Spec) do
      local key = i
      local obj_value

      obj_value = Obj[i]

      if not cmp(obj_value, validator, i, prefix) then
        return false
      end
    end

    local next_items = queue:pop()
    if next_items then
      Obj, Spec = next_items[1], next_items[2]
      prefix = next_items.prefix

      if match then
        Vars = next_items.vars or Vars
      end

      if not absolute then
        State = next_items.state or State
      end
    else
      Obj = nil
      Spec = nil
    end
  end

  if match then
    return vars
  elseif case and absolute then
    return obj
  else
    return state
  end
end

function case.match(a, b, opts)
  opts = copy(opts or {})
  opts.match = true

  return case.test(a, b, opts)
end

function case.cond(a, b, opts)
  opts = copy(opts or {})
  opts.cond = true

  return case.test(a, b, opts)
end

function case.eq(a, b, opts)
  opts = copy(opts or {})
  opts.absolute = true

  return case.test(a, b, opts)
end

function case.compare(a, b, opts)
  opts = copy(opts or {})
  opts.absolute = false
  opts.match = false
  opts.cond = false

  return case.test(a, b, opts)
end

function case.unpack(a, b)
  opts = opts or {}
  opts.capture = true
  return case.test(a, b, opts)
end

local Eq = case.rules

function Eq.literal(spec)
  return function(obj)
    return obj == spec
  end
end

function Eq.table(spec)
  return function(obj)
    return dict.eq(obj, spec, true)
  end
end

function Eq.list(spec)
  return function(obj)
    return list.eq(obj, spec, true)
  end
end

function Eq.has(ks)
  return function(obj)
    if not is_table(obj) then
      return false
    end

    return size(dict.fetch(obj, ks)) > 0
  end
end

function Eq.pred_any(preds)
  return function(obj)
    return list.some(preds, function(f)
      return f(obj)
    end)
  end
end

function Eq.pred(preds)
  return function(obj)
    return list.all(preds, function(f)
      return f(obj)
    end)
  end
end

function Eq.is_a(spec)
  return is_a[spec]
end

function Eq.lt(spec)
  assert_is_a.number(spec)

  return function(x)
    if is_table(x) or is_string(x) then
      return size(x) > spec
    elseif not is_number(x) then
      error("expected number, got " .. tostring(x))
    end

    return x < spec
  end
end

function Eq.le(spec)
  assert_is_a.number(spec)

  return function(x)
    if is_table(x) or is_string(x) then
      return size(x) <= spec
    elseif not is_number(x) then
      error("expected number, got " .. tostring(x))
    end

    return x <= spec
  end
end

function Eq.ge(spec)
  assert_is_a.number(spec)

  return function(x)
    if is_table(x) or is_string(x) then
      return size(x) >= spec
    elseif not is_number(x) then
      error("expected number, got " .. tostring(x))
    end

    return x >= spec
  end
end

function Eq.eq(spec)
  assert_is_a.number(spec)

  return function(x)
    if is_table(x) or is_string(x) then
      return size(x) == spec
    elseif not is_number(x) then
      error("expected number, got " .. tostring(x))
    end

    return x == spec
  end
end

function Eq.ne(spec)
  assert_is_a.number(spec)

  return function(x)
    if is_table(x) or is_string(x) then
      return size(x) ~= spec
    elseif not is_number(x) then
      error("expected number, got " .. tostring(x))
    end

    return x ~= spec
  end
end

function Eq.gt(spec)
  assert_is_a.number(spec)

  return function(x)
    if is_table(x) or is_string(x) then
      return size(x) > spec
    elseif not is_number(x) then
      error("expected number, got " .. tostring(x))
    end

    return x > spec
  end
end

function case.rules.list_of(value_spec)
  return function(x)
    if #x == 0 then
      return false
    end
    local ok = list.is_a(x, value_spec)

    return ok
  end
end

function case.rules.dict_of(value_spec, key_spec)
  return function(x)
    if is_empty(x) then
      return false
    end
    return dict.is_a(x, value_spec, key_spec)
  end
end

function case.M(spec, callback)
  return { spec, callback, match = true }
end

function case.L(spec, callback)
  return { spec, callback, cond = false, match = false }
end

function case.C(spec, callback)
  return { spec, callback, capture = true }
end

function case.P(spec, callback)
  return { spec, callback, cond = true }
end

function case.R(callback, ...)
  local args = { ... }

  for i = 1, #args do
    args[i] = totable(args[i])
    args[i][2] = callback
  end

  return mtset(args, { type = "case.range" })
end

local function case_call(specs)
  local case_obj = mtset({
    {},
    rules = {},

    match = function(self, obj)
      if #self[1] == 0 then
        error "no rules added yet"
      end

      local rules = self[1]

      for i = 1, #rules do
        local rule = rules[i]
        local ok = self:match_rule(obj, rule)

        if ok then
          return ok
        end
      end
    end,

    test_rule = function(self, obj, rule)
      if not is_table(rule) then
        rule = self.rules[rule]
        assert(not is_nil(rule), "invalid rule name given " .. dump(rule))
      end

      local spec = rule[1]
      local callback = rule[2]

      if callback == nil then
        error("callback missing: " .. dump(obj))
      end

      if spec == nil then
        error("spec missing: " .. dump(obj))
      end

      local opts = {
        absolute = true,
        cond = defined(rule.cond, not match and true),
        match = rule.match,
        capture = rule.capture,
      }

      local ok = case.test(obj, spec, opts)
      ok = ok and ok == true and obj or ok

      return ok
    end,

    match_rule = function(self, obj, rule)
      local ok = self:test_rule(obj, rule)

      if ok then
        return rule[2](ok)
      end
    end,

    add_any = function(self, f, ...)
      local rules = case.R(f, ...)

      for i = 1, #rules do
        local rule = rules[i]

        if rule.name then
          self.rules[rule.name] = rule
        end

        self[1][#self[1] + 1] = rule
      end

      return self
    end,

    from_list = function(self, specs)
      return self:add(unpack(specs))
    end,

    add = function(self, ...)
      local args = { ... }

      local function add_rule(rule)
        assert(#rule == 2, "expected {<spec>, <callable>}, got " .. dump(rule))
        assert_is_a.callable(rule[2])

        local len = #self[1]
        local name = rule.name or len + 1
        self.rules[name] = rule
        self[1][len + 1] = rule
      end

      for i = 1, #args do
        local rule = args[i]

        assert_is_a.table(rule)

        if typeof(rule) == "case.range" then
          list.each(rule, add_rule)
        else
          add_rule(rule, i)
        end
      end

      return self
    end,
  }, {
    type = "case.rules",
  })

  if is_table(specs) then
    case_obj:from_list(specs)
  end

  return case_obj
end

function case:__call(specs)
  return case_call(specs)
end

function is_multimethod(x)
  return typeof(x) == "multimethod"
end

function multimethod(specs)
  local rules = case(specs)
  local obj = namespace()
  local mt = mtget(obj)

  mt.type = "multimethod"

  function obj:literal_add(sig, callback)
    rules:add { sig, callback, absolute = true, match = false, cond = false }
    return obj
  end

  function obj:capture_add(sig, callback)
    rules:add { sig, callback, capture = true }
    return obj
  end

  function obj:match_add(sig, callback)
    rules:add { sig, callback, match = true }
    return obj
  end

  function obj:add(sig, callback)
    rules:add { sig, callback, cond = true }
    return obj
  end

  obj.L = obj.literal_add
  obj.M = obj.match_add
  obj.C = obj.capture_add
  obj.P = obj.add

  function mt:__newindex(sig, callback)
    rules:add { sig, callback, cond = true }
    return callback
  end

  function mt:__index(rule_name)
    return rules.rules[rule_name]
  end

  function mt:__call(...)
    local args = pack_tuple(...)

    for i = 1, #rules[1] do
      local rule = rules[1][i]
      local ok = rules:test_rule(args, rule)
      local cb = rule[2]

      if ok then
        return cb(unpack(ok))
      end
    end

    error("no signature matched for args\n" .. dump(args))
  end

  return obj
end

--[[
run_spec = multimethod()

run_spec[case.rules.list_of 'number'] = function (x)
  return 'fuckin list'
end
--]]
