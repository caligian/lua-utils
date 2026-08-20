for builtin_type, _ in pairs(BUILTIN_TYPES) do
  defguard(
    builtin_type,
    function(x)
      if type(x) == builtin_type then
        return true
      else
        return false
      end
    end,
    function(x)
      return sprintf('Expected %s, got %s', builtin_type, x)
    end
  )
end

local list_guards = {
  'string',
  'number',
  'callable',
  'function',
  'userdata',
  'boolean',
}

for _, name in ipairs(list_guards) do
  defguard(
    string.format('%s[]', name),
    function(x)
      if not is_list(x) then
        return x
      end

      for i = 1, #x do
        if type(x[i]) ~= name then
          return false
        end
      end

      return true
    end,
    function(x)
      local msg = string.format('Expected %s[], got [%s] %s', name, type(x), dump(x))
      return msg
    end
  )
end

defguard('pairs', function(x)
  if not is_list(x) then
    return false
  else
    for i = 1, #x do
      if type(x[i]) ~= 'table' then
        return false
      elseif #x[i] ~= 2 then
        return false
      end
    end

    return true
  end
end, function(x)
  return string.format(
    'Expected {any, any}[], got [%s] %s',
    type(x),
    dump(x)
  )
end)

defguard('type', function(x)
  return is_type(x)
end, function(x)
  return sprintf('Expected type_table, got [%s] %s', type(x), x)
end)

defguard('callable', function(x)
  return callable(x)
end, function(x)
  return sprintf('Expected callable_table, got [%s] %s', type(x), x)
end)

defguard('union', function(x)
  return is_union(x)
end, function(x)
  return sprintf('Expected union, got [%s] %s', type(x), x)
end)

defguard('guard', function(x)
  return is_guard(x)
end, function(x)
  return sprintf('Expected guard, got [%s] %s', type(x), x)
end)

defguard('module', function(x)
  return is_module(x)
end, function(x)
  return sprintf('Expected module, got [%s] %s', type(x), x)
end)

defguard('object', function(x)
  return is_object(x)
end, function(x)
  return sprintf('Expected object, got [%s] %s', type(x), x)
end)

defguard('class', function(x)
  return is_class(x)
end, function(x)
  return sprintf('Expected class, got [%s] %s', type(x), x)
end)

defguard('pure_dict', function(x)
  return is_pure_dict(x)
end, function(x)
  return sprintf('Expected pure_dict, got [%s] %s', type(x), x)
end)

defguard('pure_list', function(x)
  return is_pure_list(x)
end, function(x)
  return sprintf('Expected pure_list, got [%s] %s', type(x), x)
end)

defguard('pure_table', function(x)
  return is_pure_table(x)
end, function(x)
  return sprintf('Expected pure_table, got [%s] %s', type(x), x)
end)

defguard('list', function(x)
  return is_list(x)
end, function(x)
  return sprintf('Expected list, got [%s] %s', type(x), x)
end)

defguard('dict', function(x)
  return is_dict(x)
end, function(x)
  return sprintf('Expected dict, got [%s] %s', type(x), x)
end)

defguard('list[]', function(x)
  if not is_list(x) then
    return false
  end

  for i = 1, #x do
    if not is_list(x[i]) then
      return false
    end
  end

  return true
end, function(x)
  return sprintf('Expected list[], got [%s] %s', type(x), x)
end)

defguard('dict[]', function(x)
  if not is_list(x) then
    return false
  end

  for i = 1, #x do
    if not is_dict(x[i]) then
      return false
    end
  end

  return true
end, function(x)
  return sprintf('Expected dict[], got [%s] %s', type(x), x)
end)

defguard(
  'defined',
  function(x)
    return x ~= nil
  end,
  function(_)
    return 'Expected non-nil, got nothing'
  end
)

defguard(
  'undefined',
  function(x)
    return x == nil
  end,
  function(_)
    return sprintf('Expected nil, got [%s] %s', type(x), x)
  end
)

GUARD.type_table = GUARD.type
GUARD.pdict = GUARD.pure_dict
GUARD.plist = GUARD.pure_list
GUARD.ptable = GUARD.pure_table
GUARD.fun = GUARD['function']
