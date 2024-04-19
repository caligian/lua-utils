package = "lua-utils"
version = "dev-1"

source = {
  url = "git+https://github.com/caligian/lua-utils.git",
}

description = {
  homepage = "https://github.com/caligian/lua-utils",
  license = "MIT <http://opensource.org/licenses/MIT>",
}

dependencies = { "lua >= 5.1", "lpeg" }

build = {
  type = "builtin",
  modules = {
    ["lua-utils"] = "lua-utils/init.lua",
    ['lua-utils.list'] = 'lua-utils/list.lua',
    ['lua-utils.dict'] = 'lua-utils/dict.lua',
    ['lua-utils.table'] = 'lua-utils/table.lua',
    ["lua-utils.function"] = "lua-utils/function.lua",
    ["lua-utils.copy"] = "lua-utils/copy.lua",
    ["lua-utils.Set"] = "lua-utils/Set.lua",
    ["lua-utils.string"] = "lua-utils/string.lua",
    ["lua-utils.template"] = "lua-utils/template.lua",
    ["lua-utils.core"] = "lua-utils/core.lua",
    ["lua-utils.argparser"] = "lua-utils/argparser.lua",
    ["lua-utils.errors"] = "lua-utils/errors.lua",
  },
}
