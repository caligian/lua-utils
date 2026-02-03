require 'lua-utils.utils'
require 'lua-utils.string'

unpack = unpack or table.unpack

local M = {
	inspect = require 'lua-utils.inspect',
	list = require 'lua-utils.list',
	dict = require 'lua-utils.dict',
	class = require 'lua-utils.class',
	tuple = require 'lua-utils.tuple',
	types = require 'lua-utils.types',
	copy = require 'lua-utils.copy',
	validate = require 'lua-utils.validate',
	cmp = require 'lua-utils.cmp',
	multimethod = require 'lua-utils.multimethod',
	template = require 'lua-utils.template',
	err = require 'lua-utils.error',
	argparser = require 'lua-utils.argparser',
	path = require 'lua-utils.path_utils',
	process = require 'lua-utils.process',
}

function M:import()
  for key, value in pairs(self) do
    if key ~= 'import' then
      _G[key] = value
    end
  end
end

return M
