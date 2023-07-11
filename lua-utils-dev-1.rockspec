package = "lua-utils"
version = "dev-1"

source = {
  url = "git+https://github.com/caligian/lua-utils.git",
}

description = {
  homepage = "https://github.com/caligian/lua-utils",
  license = 'MIT <http://opensource.org/licenses/MIT>',
}

dependencies = { 'lua >= 5.1' }

build = {
  type = "builtin",
  modules = {
    ["lua-utils.Set"] = "lua-utils/Set.lua",
    ["lua-utils.array"] = "lua-utils/array.lua",
    ["lua-utils.dict"] = "lua-utils/dict.lua",
    ["lua-utils.exception"] = "lua-utils/exception.lua",
    ["lua-utils"] = "lua-utils/init.lua",
    ['lua-utils.struct'] = 'lua-utils/struct.lua',
    ["lua-utils.multimethod"] = "lua-utils/multimethod.lua",
    ["lua-utils.str"] = "lua-utils/str.lua",
    ["lua-utils.utils"] = "lua-utils/utils.lua",
    ["lua-utils.param"] = "lua-utils/param.lua",
  },
}
