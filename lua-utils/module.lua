local pprint = require 'pprint'
local module = setmetatable({}, {type = 'module'})

function module.new(name)
    return setmetatable({}, {__tostring = pprint.dump, name = name, type = 'module'})
end

return module
