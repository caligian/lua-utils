local copy_mt = {}
local copy_deep_mt = {}
copy = setmetatable({}, copy_mt)
copy.deep = setmetatable({}, copy_deep_mt)
deepcopy = copy.deep
clone = deepcopy

local function weak_table()
  return setmetatable({}, {__mode = 'k'})
end

--- Copy metatable of table
--- @param x table
--- @return table?
function copy.metatable(x)
  if type(x) ~= 'table' then
    return
  end

  local mt = getmetatable(x)
  if not mt then
    return
  end

  local out = {}
  for key, value in pairs(mt) do
    out[key] = value
  end

  return out
end

--- Copy table
--- @param x table
--- @param cp_mt? boolean copy metatable?
--- @return table?
function copy.table(x, cp_mt)
  if type(x) ~= 'table' then
    return
  end

  local out = {}
  if cp_mt then
    local mt = copy.metatable(x)
    if mt then
      setmetatable(out, mt)
    end
  end

  for key, value in pairs(x)  do
    out[key] = value
  end

  return out
end

--- Copy table as list
--- @param x table
--- @param cp_mt? boolean copy metatable?
--- @return table?
function copy.list(x, cp_mt)
  if type(x) ~= 'table' then
    return
  end

  local out = {}
  if cp_mt then
    local mt = copy.metatable(x)
    if mt then
      setmetatable(out, mt)
    end
  end

  for i = 1, #x do
    out[i] = x[i]
  end

  return out
end

local function deep_copy_table(x, cp_mt, queue, cache, res, depth, current_depth, f)
  if not x then
    return
  end

  depth = depth or false
  current_depth = current_depth or 1
  if depth and depth < current_depth then
    return
  end

  local n = 1

  for i,v  in pairs(x) do
    if type(v) == 'table' then
      local cached = cache[v]
      if not cached then
        res[i] = {}
        cache[v] = res[i]
        queue[n] = {
          v,
          cp_mt,
          queue,
          cache,
          res[i],
          depth,
          current_depth+1,
          f,
        }
        n = n + 1
      else
        res[i] = cached
      end
    elseif f then
      res[i] = f(v)
    else
      res[i] = v
    end
  end

  if cp_mt then
    local mt = copy.metatable(x)
    setmetatable(res, mt)
  end

  local len = #queue
  local next = queue[len]
  queue[len] = nil

  if not next then
    return
  end

  deep_copy_table(unpack(next))
end

local function deep_copy_list(x, cp_mt, queue, cache, res, depth, current_depth, f)
  if not x then
    return
  end

  depth = depth or false
  current_depth = current_depth or 1
  if depth and depth < current_depth then
    return
  end

  local n = 1

  for i = 1, #x do
    local v = x[i]

    if type(v) == 'table' then
      local cached = cache[v]
      if not cached then
        res[i] = {}
        cache[v] = res[i]
        queue[n] = {
          v,
          cp_mt,
          queue,
          cache,
          res[i],
          depth,
          current_depth+1,
          f,
        }
        n = n + 1
      else
        res[i] = cached
      end
    elseif f then
      res[i] = f(v)
    else
      res[i] = v
    end
  end

  if cp_mt then
    local mt = copy.metatable(x)
    setmetatable(res, mt)
  end

  local len = #queue
  local next = queue[len]
  queue[len] = nil

  if not next then
    return
  end

  deep_copy_list(unpack(next))
end

--- Deep copy table
--- @param x table
--- @param opts {depth?: number, map?: (fun(x:any):any), metatable?: boolean}
--- @return table?
function copy.deep.table(x, opts)
  opts = opts or {}
  local queue = {}
  local cache = weak_table()
  local result = {}
  deep_copy_table(x, opts.metatable, queue, cache, result, opts.depth, 1, opts.map)

  return result
end

--- Deep copy table as list
--- @param x any[]
--- @param opts {depth?: number, map?: (fun(x:any):any), metatable?: boolean}
--- @return any[]?
function copy.deep.list(x, opts)
  opts = opts or {}
  local queue = {}
  local cache = weak_table()
  local result = {}
  deep_copy_list(x, opts.metatable, queue, cache, result, opts.depth, 1, opts.map)

  return result
end

function copy_mt:__call(x, opts)
  opts = opts or {}
  if opts.deep then
    if opts.list then
      return copy.deep.list(x, opts)
    else
      return copy.deep.table(x, opts)
    end
  elseif opts.list then
    return copy.list(x, opts)
  end

  return copy.table(x, opts)
end

function copy_deep_mt:__call(x, opts)
  opts = opts or {}
  if opts.list then
    return copy.deep.list(x, opts)
  else
    return copy.deep.table(x, opts)
  end
end
