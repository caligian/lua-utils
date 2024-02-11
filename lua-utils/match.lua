require "lua-utils.table"
require "lua-utils.copy"
require "lua-utils.form"
require "lua-utils.types.class"

--- @class case.rule
--- @field [1] any `==` for literals, tables will be compared recursively and method() will be used as type assertion
--- @field [2] method method to run when signature matches

--- @class case.var
--- @field name? string
--- @field test? method|table|boolean|any

--- @class case : ns
--- @field rules table<any,case.rule>
case = ns() --[[@as case]]

--- @class case.rules : ns
case.rules = ns() --[[@as case.rules]]

function case.var(name, test)
  if type(name) ~= "string" and type(name) ~= "number" then
    test = name
    name = nil
  end

  return setmetatable(
    { name = name, test = test },
    { type = "match.variable" }
  ) --[[@as case.var]]
end

--- @param x any
--- @return boolean
function case.is_var(x)
  return mtget(x --[[@as table]], "type")
    == "match.variable"
end

case.V = case.var

function case.test(obj, spec, opts)
  opts = opts or {}
  local eq = opts.eq
  local cond = opts.cond
  local match = opts.match
  local ass = opts.assert

  if is_method(spec) and (cond or match) then
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
      assert(
        is_string(y),
        "expected capture variable name (string), got "
          .. type(y)
      )
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

  local function cmp(x, y, k, _prefix)
    if not _prefix then
      _prefix = k
    else
      _prefix = _prefix .. "." .. k
    end

    if not is_nil(x) and pre_a then
      x = pre_a(x)
    end

    if pre_b then
      y = pre_b(y)
    end

    if is_nil(x) then
      if ass then
        error(_prefix .. ": expected value, got nil")
      elseif absolute then
        return false
      else
        State[key] = false
      end
    elseif case.is_var(y) then
      assert(
        match,
        ".match should be true for using match.variable"
      )

      y.name = y.name or k
      local test = y.test
      local name = y.name

      if is_nil(test) then
        Vars[name] = x
      elseif is_method(test) then
        local ok, msg = test(x)
        if ok then
          Vars[name] = x
        elseif ass then
          if msg then
            error(_prefix .. ": " .. msg)
          end
          error(
            _prefix .. ": callable failed for " .. dump(x)
          )
        else
          return false
        end
      elseif is_table(test) then
        if not is_table(x) then
          if ass then
            error(
              _prefix .. ": expected table, got " .. type(x)
            )
          else
            return false
          end
        else
          Vars[name] = {}
          queue:add {
            x,
            test,
            vars = Vars[name],
            _prefix = _prefix,
          }
        end
      else
        error "match.variable.test should be (function|table)?"
      end
    elseif is_table(y) and not is_method(y) then
      if not is_table(x) then
        if ass then
          error(
            _prefix .. ": expected table, got " .. type(x)
          )
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
          _prefix = _prefix,
          state = State--[[@as table]][k],
        }
      elseif match then
        queue:add { x, y, vars = Vars, _prefix = _prefix }
      else
        queue:add { x, y, _prefix = _prefix }
      end
    elseif (cond or match) and is_method(y) then
      local ok, msg = y(x)
      if ok then
        if not absolute then
          State[key] = true
        end
      elseif ass then
        if msg then
          error(_prefix .. ": " .. msg)
        end
        error(
          _prefix
            .. ": callable failed for "
            .. dump(obj_value)
        )
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
        error(
          _prefix
            .. ": unequal elements: \n"
            .. dump(x)
            .. "\n"
            .. dump(y)
        )
      elseif absolute then
        return false
      end
    elseif x ~= y then
      if ass then
        error(
          _prefix
            .. ": unequal elements: \n"
            .. dump(x)
            .. "\n"
            .. dump(y)
        )
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
      local obj_value = Obj[i]
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

function case.capture(a, b)
  opts = opts or {}
  opts.capture = true
  return case.test(a, b, opts)
end

--- @class case.rules
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

function case.rules.dict_of(value_spec)
  return function(x)
    if not is_table(x) then
      return false, "expected dict, got " .. dump(x)
    elseif #x == 0 then
      return false
    end
    local ok = dict.is_a(x, value_spec)
    return ok
  end
end

function case.rules.list_of(value_spec)
  return function(x)
    if not is_table(x) then
      return false, "expected list, got " .. dump(x)
    elseif #x == 0 then
      return false
    end
    local ok = list.is_a(x, value_spec)
    return ok
  end
end

function case.rules.re(...)
  local pats = { ... }

  return function(x)
    local ok, msg = is_string(x)
    if not ok then
      return ok, msg
    end

    return strmatch(x, unpack(pats))
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

function case:__call(specs)
  local mt = { type = "case", method = true }
  local obj = mtset({}, mt)
  obj.case = {}
  obj.rules = {}

  function obj:match(obj)
    if #self.case == 0 then
      error "no rules added yet"
    end

    local rules = self.case

    for i = 1, #rules do
      local rule = rules[i]
      local ok = self:match_rule(obj, rule)

      if ok then
        return ok
      end
    end
  end

  function obj:test_rule(obj, rule)
    if not is_table(rule) then
      rule = self.rules[rule]
      assert(
        not is_nil(rule),
        "invalid rule name given " .. dump(rule)
      )
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
  end

  function obj:match_rule(obj, rule)
    local ok = self:test_rule(obj, rule)
    if ok then
      return rule[2](ok)
    end
  end

  function obj:from_list(_specs)
    return self:add_rule(unpack(_specs))
  end

  function obj:add_rule(...)
    local args = { ... }

    local function add_rule(rule)
      assert(
        #rule == 2,
        "expected {<spec>, <callable>}, got " .. dump(rule)
      )
      form.method["rule[2]"](rule[2])

      local len = #self.case
      local name = rule.name or len + 1
      self.rules[name] = rule
      self.case[len + 1] = rule
    end

    for i = 1, #args do
      local rule = args[i]
      form.table.rule(rule)
      add_rule(rule)
    end

    return self
  end

  function obj:P(sig, callback)
    return self:add_rule(case.P(sig, callback))
  end

  function obj:C(sig, callback)
    return self:add_rule(case.C(sig, callback))
  end

  function obj:M(sig, callback)
    return self:add_rule(case.M(sig, callback))
  end

  function obj:L(sig, callback)
    return self:add_rule(case.L(sig, callback))
  end

  function mt:__call(obj)
    return obj:match(obj)
  end

  function mt:__newindex(spec, callback)
    self:add_rule {
      spec,
      callback,
      cond = true,
      absolute = true,
    }
  end

  --- @type case
  if is_table(specs) then
    ---@diagnostic disable-next-line: undefined-field
    obj:from_list(specs)
  end

  return obj
end

function is_multimethod(x)
  return typeof(x) == "multimethod"
end

function multimethod(specs)
  local mt = { type = "multimethod", method = true }
  local obj = mtset({}, mt)
  obj.case = case(specs)
  obj.f = {}
  local case_obj = obj.case

  local function conv(x)
    if is_method(x) then
      return { x }
    elseif not is_table(x) then
      return { x }
    else
      return x
    end
  end

  function obj:M(...)
    local sig = pack_tuple(...)
    return mtset({}, {
      __index = function(_, name)
        return function(callback)
          sig = list.mapi(sig, function(i, x)
            if not case.is_var(x) then
              if is_literal(x) then
                return case.var(i, function(obj)
                  local ok = x == obj
                  if not ok then
                    return nil,
                      "expected "
                        .. dump(x)
                        .. ", got "
                        .. dump(obj)
                  end
                  return obj
                end)
              end

              return case.var(i, x)
            end
            x.name = i
            return x
          end)

          case_obj:M(conv(sig), callback)
          self[name] = callback

          return obj
        end
      end,
    })
  end

  function obj:L(...)
    local sig = pack_tuple(...)
    return mtset({}, {
      __index = function(_, name)
        return function(callback)
          case_obj:L(sig, callback)
          self[name] = callback
          return obj
        end
      end,
    })
  end

  function obj:P(...)
    local sig = pack_tuple(...)
    return mtset({}, {
      __index = function(_, name)
        return function(callback)
          case_obj:P(sig, callback)
          self[name] = callback
          return obj
        end
      end,
    })
  end

  function mt:__index(rule_name)
    return case_obj.rules[rule_name]
  end

  function mt:__call(...)
    local args = pack_tuple(...)
    local all = case_obj.case

    for i = 1, #all do
      local rule = all[i]
      local ok = case_obj:test_rule(args, rule)
      local cb = rule[2]

      if ok then
        table.insert(ok, 1, self)
        return cb(unpack(ok))
      end
    end

    error("no signature matched for args\n" .. dump(args))
  end

  return obj
end

-- local mm = multimethod()
-- local V = case.V

-- local f = function(self, a, b, c)
--   return { opts = { a, b, c } }
-- end

-- local g = function(self, a, b)
--   return self:another_name(a, b)
-- end

-- mm:M(V "a", "b", V "c").another_name(f)
-- mm:M("A", "B").name(g)

-- mm:M(
--   { a = V "a", b = V "b", c = { d = is_number } },
--   1,
--   2,
--   "hello_world"
-- ).yet_another(function(_, opts, a, b, c)
--   return { opts = opts, a = a, b = b, c = c }
-- end)

-- pp(mm({ a = 1, b = 2, c = { d = 1 } }, 1, 2, "hello_world"))
-- pp(is_method(mm))
