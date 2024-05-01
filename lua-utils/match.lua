require "lua-utils.types"

local switch_mt = {}
local switch = mtset({}, switch_mt)

function switch.capture(obj, spec, dst)
  dst = dst or {}

  for key, value in pairs(spec) do
    local obj_value = obj[key]
    if types.table(obj_value) and types.table(value) then
      switch.capture(obj_value, value, dst)
    elseif obj_value ~= nil then
      dst[value] = obj_value
    else
      return false
    end
  end

  return true
end

function switch_mt:__call(obj, specs)
  local function validate(out, where)
    for i, x in pairs(where) do
      local out_value = out[i]
      if out_value ~= nil then
        if types.method(x)  then
          if not x(out_value) then
            return false
          end
        elseif types.table(out_value) and types.table(x) then
          validate(out_value, x)
          return false
        end
      end
    end
    return true
  end

  local function run(_specs)
    for i = 1, #_specs do
      local spec = _specs[i]
      local m = spec.call
      local _switch = spec.match
      local where = spec.case
      local out = {}

      if
        switch.capture(obj, _switch, out)
        and validate(out, where or {})
      then
        if spec.call then
          return spec.call(out)
        end
        return out
      end
    end
  end

  if specs == nil then
    return run
  end

  return run(specs)
end

local obj = {
  1,
  2,
  3,
  4,
  {
    4,
    5,
    6,
  },
  a = 10,
}

pp(switch(obj) {
  {
    match = {
      "a",
      "b",
      "c",
      "d",
      {
        "e",
        "f",
        "g",
      },
      a = "A",
    },
    case = {a = types.number}
  },
})
