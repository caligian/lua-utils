local _ = {}

---Convert `nil` to 'nil' or return type_name
---@param type_name? string
function _.type(type_name)
  type_name = type_name == nil and 'nil' or type_name
  type_name = (type(type_name) == 'string' and type_name) or type(type_name)

  return type_name
end

---Return boolean or falsey value returned by a function
---@param cond? boolean | (fun(...): boolean?)
---@return boolean
---@overload fun(cond?: boolean): boolean?
---@overload fun(cond: (fun(...): boolean), ...): boolean?
function _.cond(cond)
  if cond == nil then
    return false
  end

  local cond_type = type(cond)
  if cond_type == 'boolean' then
    return cond
  elseif cond_type == 'function' then
    return cond()
  else
    error('cond: Expected nil | boolean | (fun(): boolean?), got ' .. _.type(cond_type))
  end
end

---{variable}: Expected {expected_type}, got {gotten_type}
---@param variable string
---@param expected_type? string
---@param gotten_type? string
---@param throw? boolean
---@return string?
function _.expected(variable, expected_type, gotten_type, throw)
  expected_type = _.type(expected_type)
  gotten_type = _.type(gotten_type)
  local s = string.format('%s: Expected %s, got %s', variable, expected_type, gotten_type)

  if throw then
    error(s)
  else
    return s
  end
end

---Poor man's extend
---@param res table Flattened table
---@param tbls table All the other tables to be flattened
---@return table<number, any>
function _.flatten(res, tbls)
  local function flatten(tbl)
    for i = 1, #tbl do
      local v = tbl[i]
      if type(v) == 'table' then
        flatten(v)
      else
        res[#res + 1] = v
      end
    end
  end

  for i = 1, #tbls do
    flatten(tbls[i])
  end

  return res
end

---Merge tables
---@param res table Flattened table
---@param tbls table All the other tables to be merged
---@param force? boolean Force merge missing keys?
---@return table<string | number,any>
function _.merge(res, tbls, force)
  local function merge(tbl)
    for i, v in pairs(tbl) do
      if type(v) == 'table' then
        merge(v)
      elseif res[i] == nil then
        res[i] = v
      elseif force then
        res[i] = v
      end
    end
  end

  for i = 1, #tbls do
    merge(tbls[i])
  end

  return res
end

---Merge tables
---@param res table Flattened table
---@param tbls table All the other tables to be flattened
---@return table<string | number,any>
function _.mergef(res, tbls)
  return _.merge(res, tbls, true)
end

_.force_merge = _.mergef

---@class fix_index_return
---@field [1] number|boolean
---@field [2] string|boolean

---@param tbl_len_or_tbl table|number
---@param index number
---@param strict? boolean Raise error on invalid index
---@param fix_bounds? boolean If index exceeds table length, then stick to the last value while calculating index values. Overrides strict
---@return boolean, fix_index_return
function _.fix_index(tbl_len_or_tbl, index, strict, fix_bounds)
  local function index_err_msg(recomputed, fmt, ...)
    local prefix = recomputed and '<normalized>index' or 'index'
    return string.format('%s: %s', prefix, string.format(fmt, ...))
  end

  local function throw(i, limit)
    if i > limit then
      if fix_bounds then
        return true, { limit, false }
      end

      local msg = index_err_msg(false, 'expected index <= #tbl [%d], value is %s', limit, i)
      if strict then
        error(msg)
      else
        return false, { false, msg }
      end
    elseif index < 0 then
      if fix_bounds then
        return true, { 1, false }
      end

      local msg = index_err_msg(true, 'expected index > 0, value is %s', tostring(i))
      if strict then
        error(msg)
      else
        return false, { false, msg }
      end
    else
      return true, { i, false }
    end
  end

  local tbl_len
  if type(tbl_len_or_tbl) == 'number' then
    tbl_len = tbl_len_or_tbl
  else
    tbl_len = #tbl_len_or_tbl
  end

  index = index < 0 and (index + tbl_len) or index
  return throw(index, tbl_len)
end


return _
