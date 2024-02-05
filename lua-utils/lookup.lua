require "lua-utils.utils"

local function parse_keys(ks)
  if not is_table(ks) then
    return { ks }
  end

  return ks
end

local function traverse_till_key(x, ks, makepath)
  ks = parse_keys(ks)
  local v = x
  local k

  for i = 1, #ks - 1 do
    k = ks[i]

    if is_nil(v[k]) then
      if makepath then
        v[k] = {}
      else
        return nil, v, i
      end
    end

    if is_table(v[k]) then
      v = v[k]
    else
      return nil, v, i
    end
  end

  local last_key = ks[#ks]
  if makepath and v[last_key] == nil then
    v[last_key] = {}
  end

  return v[last_key], v
end

local function lookup_apply(x, ks, makepath, callback, orelse)
  local found, last_found, last_index = traverse_till_key(x, ks, makepath)

  if found ~= nil then
    return callback(found, last_found, ks[#ks])
  elseif orelse then
    return orelse(last_found, last_index)
  end
end

local function update(x, ks, makepath, default, f, islist)
  default = default or function()
    return nil
  end

  local function remove_value(last_found, key)
    if islist then
      if not is_number(key) or key > #last_found or key < 1 then
        return
      end

      table.remove(last_found, key)
    end

    last_found[key] = nil
  end

  local function set_value(last_found, key, new_value)
    if islist then
      local len = #last_found
      if not is_number(key) or key > len + 1 or key < 0 then
        return
      end
    end

    if new_value == nil then
      remove_value(last_found, key)
    else
      last_found[key] = new_value
    end
  end

  return lookup_apply(x, ks, makepath, function(found, last_found, key)
    set_value(last_found, key, f(found))
    return found
  end, function(last_found, last_index)
    if islist then
      if not is_number(ks[last_index]) then
        return
      elseif ks[last_index] < #last_found then
        return
      end
    end

    if last_index ~= #ks then
      return
    end

    set_value(last_found, ks[last_index], default())

    return def
  end)
end

local function unset(x, ks, islist)
  local f = function()
    return nil
  end
  return update(x, ks, false, f, f, islist)
end

local function set(x, ks, value, islist)
  local f = function()
    return value
  end
  return update(x, ks, true, f, f, islist)
end

function list.remove(x, ks)
  return unset(x, ks, true)
end

function dict.update(x, ks, f, default)
  return update(x, ks, default, f)
end

function dict.unset(x, ks)
  return unset(x, ks)
end

function dict.set(x, ks, value)
  return set(x, ks, value)
end

function list.update(x, ks, f, default)
  return update(x, ks, default, f, true)
end

function list.set(x, ks, value)
  return set(x, ks, value, true)
end

function dict.from_keys(x, ks)
  local vals = {}

  for i = 1, #ks do
    local k = ks[i]
    local v = x[k]

    if v ~= nil then
      vals[k] = v
    end
  end

  return vals
end

dict.get = traverse_till_key
list.get = traverse_till_key
dict.has = dict.get
list.has = list.get
list.nth = list.has

--- Fetch a list of keys
--- @param x list
--- @param ks any
--- @return list
function list.fetch(x, ks)
  local out = {}

  for i = 1, #ks do
    out[i] = list.get(x, ks[i])
  end

  return out
end

--- Fetch a list of keys
--- @param x table
--- @param ks any
--- @return list|table
function dict.fetch(x, ks)
  local out = {}

  for i = 1, #ks do
    out[i] = dict.get(x, ks[i])
  end

  return out
end

function list.has_some_index(x, ks)
  for i = 1, #ks do
    if not is_number(ks[i]) then
      return false
    end

    if list.get(x, ks[i]) then
      return true
    end
  end

  return false
end

function list.has_index(x, ks)
  for i = 1, #ks do
    if not is_number(ks[i]) then
      return false
    end

    if not list.get(x, ks[i]) then
      return false
    end
  end

  return true
end

function dict.has_some_keys(x, ks)
  for i = 1, #ks do
    if dict.get(x, ks[i]) then
      return true
    end
  end

  return false
end

function dict.has_keys(x, ks)
  for i = 1, #ks do
    if not dict.get(x, ks[i]) then
      return false
    end
  end

  return true
end
