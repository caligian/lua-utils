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
	Multimethod = require 'lua-utils.multimethod',
	Template = require 'lua-utils.template',
	err = require 'lua-utils.error',
	ArgumentParser = require 'lua-utils.argparser',
	path = require 'lua-utils.path_utils',
	process = require 'lua-utils.process',
}

function M:import()
	for key, value in pairs(self) do
		_G[key] = value
    if self.types.table(value) then
      if value.import then
        value:import()
      end
    end
	end
end

return M
