require "lua-utils.utils"

local benchmark = namespace()
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

-- local bm = benchmark()
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


