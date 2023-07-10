array = require 'lua-array'
dict = require 'lua-dict'
exception = require 'lua-exception'
fn = require 'lua-fn'
multimethod = require 'lua-multimethod'
param = require 'lua-param'
pprint = require 'lua-pprint'
Set = require 'lua-Set'
require 'lua-str'
types = require 'lua-types'
utils = require 'lua-utils'
struct = require 'lua-struct'

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
