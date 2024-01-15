require "lua-utils.table"
require "lua-utils.Set"

local function _claim(x, y, levelname)
  if x == nil and levelname:match "%?$" then
    return true
  end

  levelname = levelname or "<base>"
  if is_function(y) or is_string(y) then
    local ok, msg
    y = is_string(y) and union(y) or y
    ok, msg = y(x)

    if not ok then
      msg = msg or ""
      msg = levelname .. (#msg > 0 and (": " .. msg) or ": callable failed for " .. dump(x))
      error(msg)
    else
      return
    end
  end

  if not is_table(y) then
    error(levelname .. ": expected table|string|function for spec, got " .. y)
  end

  local ykeys = keys(y)
  levelname = y.__name or levelname
  local extra = y.__extra
  y.__name = nil
  y.__extra = nil

  local function resolve(X)
    X = is_string(X) and X:match "%?$" and X:sub(1, #X - 1) or X
    return tonumber(X) or X
  end

  local optional = list.filter(ykeys, function(X)
    return (tostring(X):match "^opt_") or (tostring(X):match "%?$") or (X == "__extra" or X == "__name")
  end, resolve)

  optional = Set(optional)
  ykeys = Set(list.map(ykeys, resolve))
  local xkeys = Set(keys(x))
  local required = ykeys - optional
  local extraks = xkeys - ykeys
  local missing = (required - xkeys)
    / function(key)
      if x[key] == nil and optional[key] or key == "__name" then
        return false
      end

      return true
    end

  if not extra then
    if size(extraks) > 0 then
      error(levelname .. ": found extra keys: " .. join(keys(extraks), ","))
    end
  end

  if size(missing) > 0 then
    error(levelname .. ": missing keys: " .. join(keys(missing), ","))
  end

  for key, value in pairs(y) do
    local k = resolve(key)
    local a, b = x[k], value

    if a == nil and optional[k] then
    elseif is_table(a) and is_table(b) then
      b.__name = levelname .. "." .. key
      _claim(a, b)
    elseif is_table(b) then
      error(levelname .. "." .. key .. ": expected table, got " .. dump(a))
    else
      asserttype(b, union("string", "function"))

      b = is_string(b) and union(b) or b
      local ok, msg = b(a)

      if not ok then
        msg = msg or ""
        msg = levelname .. "." .. key .. (#msg > 0 and (": " .. msg) or ": callable failed")
        error(msg)
      end
    end
  end
end

function params(specs)
  for key, value in pairs(specs) do
    assert_is_a(value, function(x)
      return is_list(x) and #x <= 2, "expected at least 1 item long list, got " .. dump(x)
    end)

    local spec = value[1]
    local x = value[2]
    local name = key

    _claim(x, spec, name)
  end
end
