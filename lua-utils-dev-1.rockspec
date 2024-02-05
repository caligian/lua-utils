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
    ["lua-utils.match"] = "lua-utils/match.lua",
    ["lua-utils.types"] = "lua-utils/types/init.lua",
    ["lua-utils.types.utils"] = "lua-utils/types/utils.lua",
    ["lua-utils.types.class"] = "lua-utils/types/class.lua",
    ["lua-utils.types.typecheck"] = "lua-utils/types/typecheck.lua",
    ["lua-utils.types.ns"] = "lua-utils/types/ns.lua",
    ["lua-utils.form"] = "lua-utils/form.lua",
    ["lua-utils.function"] = "lua-utils/function.lua",
    ["lua-utils.argparser"] = "lua-utils/argparser.lua",
    ["lua-utils.lookup"] = "lua-utils/lookup.lua",
    ["lua-utils.copy"] = "lua-utils/copy.lua",
    ["lua-utils.table"] = "lua-utils/table.lua",
    ["lua-utils.Set"] = "lua-utils/Set.lua",
    ["lua-utils.string"] = "lua-utils/string.lua",
    ["lua-utils.template"] = "lua-utils/template.lua",
    ["lua-utils.utils"] = "lua-utils/utils.lua",
  },
}
