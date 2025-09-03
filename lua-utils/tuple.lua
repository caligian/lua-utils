local tuple = {}

tuple.unpack = table.unpack or unpack

---Pack varargs into a list filling all the nils with false
---@param ... any
---@return any[]
function tuple.pack(...)
  local args = { ... }

  for i = 1, select("#", ...) do
    if args[i] == nil then
      args[i] = false
    end
  end

  return args
end

---Get size of varargs
---@param ... any
---@return number
function tuple.size(...)
  return select("#", ...)
end

tuple.length = tuple.size

function tuple.cdr(n, ...)
  return select(n, ...)
end

function tuple.nth(n, ...)
  local found = tuple.cdr(n, ...)
  return found
end

function tuple.first(...)
  return tuple.nth(1, ...)
end

function tuple.last(...)
  return select(-1, ...)
end

function tuple.slice(i, j, ...)
  local args = tuple.pack(select(i, ...))
  if #args == 0 then
    return {}
  else
    for a = j + 1, #args do
      args[a] = nil
    end
  end
  return args
end

return tuple
