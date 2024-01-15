local function _copy_list(x)
  local queue = {}
  local result = {}
  local tmp = result
  local X = x
  local cache = {}

  while true do
    for i = 1, #X do
      local v = X[i]

      if type(v) == "table" and not cache[v] then
        cache[v] = true
        local v_mt = getmetatable(v)

        if v_mt then
          tmp[i] = setmetatable(v, v_mt)
        else
          tmp[i] = {}
        end

        queue[#queue + 1] = i
      else
        tmp[i] = X[i]
      end
    end

    local next_i = queue[#queue]
    if next_i then
      queue[#queue] = nil
      X = X[next_i]
      tmp = tmp[next_i]
    else
      return result
    end
  end
end

local function _copy_table(x)
  local queue = {}
  local result = {}
  local cache = {}
  local tmp = result
  local X = x

  while true do
    for i, v in pairs(X) do
      if type(v) == "table" and not cache[v] then
        cache[v] = true
        local v_mt = getmetatable(v)

        if v_mt then
          tmp[i] = setmetatable(v, v_mt)
        else
          tmp[i] = {}
        end

        queue[#queue + 1] = i
      else
        tmp[i] = X[i]
      end
    end

    local next_i = queue[#queue]
    if next_i then
      queue[#queue] = nil
      X = X[next_i]
      tmp = tmp[next_i]
    else
      return result
    end
  end
end

function copy(x, islist)
  if type(x) ~= "table" then
    return x
  end

  if islist then
    local result = {}

    for i = 1, #x do
      result[i] = x[i]
    end

    return result
  end

  local result = {}
  for key, value in pairs(x) do
    result[key] = value
  end

  return result
end

function deepcopy(x, islist)
  if type(x) ~= "table" then
    return x
  end

  if islist then
    return _copy_list(x)
  end

  return _copy_table(x)
end

clone = deepcopy
