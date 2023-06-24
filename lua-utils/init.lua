array = require 'lua-utils.array'
class = require 'lua-utils.class'
dict = require 'lua-utils.dict'
exception = require 'lua-utils.exception'
fn = require 'lua-utils.fn'
multimethod = require 'lua-utils.multimethod'
param = require 'lua-utils.param'
pprint = require 'lua-utils.pprint'
Set = require 'lua-utils.Set'
str = require 'lua-utils.str'
types = require 'lua-utils.types'
utils = require 'lua-utils.utils'

local function makeglobal(t)
  for key, value in pairs(t) do _G[key] = value end
end

makeglobal(types)
makeglobal(utils)
makeglobal(fn)
makeglobal(pprint)
makeglobal(param)

deepcopy = array.deepcopy
copy = array.copy
