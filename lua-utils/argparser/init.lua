local parser = require 'lua-utils.argparser.parser'
parser.KeywordArgument = require 'lua-utils.argparser.keyword_argument'
parser.PositionalArgument = require 'lua-utils.argparser.positional_argument'
parser.utils = require 'lua-utils.argparser.utils'

function parser:import()
  _G.ArgumentParser = self
end

return parser
