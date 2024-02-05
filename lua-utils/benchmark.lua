require "lua-utils.utils"
require "lua-utils.types"

local benchmark = ns()
local mt = { type = "benchmark" }

function mt:__newindex(name, fun)
  rawset(self, name, function(self, ...)
    local before = os.clock()
    fun(...)
    local now = os.clock()
    local elapsed = now - before
    self.elapsed = elapsed
    print("time elapsed to run " .. name .. ": " .. elapsed)
  end)
end

function benchmark:__call()
  return mtset({
    run = function(self, args)
      for i = 1, #args do
        local spec = args[i]
        local name, params = unpack(spec)
        self[name](self, unpack(params))
      end
    end,
  }, mt)
end

local bm = benchmark()

bm.create_thousand_classes = function()
  for i = 1, 100000 do
    local Vector = class("Vector", {})
    Vector.init = function(self, x, y)
      self.x = x
      self.y = y
      return self
    end
    local X = Vector(1, 2)
    Vector.sum = function(self)
      return self.x + self.y
    end
    local _ = X.sum
  end
end
bm.create_thousand_structs_with_validation = function()
  for i = 1, 100000 do
    local Vector = struct("Vector", { { "x", is_number }, { "y", is_number } })
    Vector.init = function(self, x, y)
      self.x = x
      self.y = y
      return self
    end
    local X = Vector(1, 2)
    Vector.sum = function(self)
      return self.x + self.y
    end
    local _ = Vector.sum
    -- Vector.sum(X)
  end
end

bm:run {
  { "create_thousand_structs_with_validation", {} },
  { "create_thousand_classes", {} },
}

-- bm.lpeg_template = template
-- bm.template = template_replace

-- local test = [[

-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}

-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}

-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}

-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}

-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}

-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}

-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}

-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}
-- {a} {b} {c} {d} {e} {f}
-- ]]

-- test = test:rep(10)

-- local args = {
--   a = 1,
--   b = 2,
--   c = 3,
--   d = 4,
--   e = 5,
--   f = 6
-- }

-- bm:run(
-- {'template', {test, args}},
-- {'lpeg_template', {test, args}}
-- )

return benchmark
