require 'lua-utils.string'
local class = require 'lua-utils.class'
local process = {}
process.Popen = class 'Popen'

---@class Popen
---@field cmd string
---@field mode string
---@field handle? userdata
---@field output string[] | string 
---@overload fun(cmd: string, mode?: string) -> Popen
local Popen = process.Popen

function Popen:initialize(cmd, mode)
  self.cmd = cmd
  self.mode = mode or 'r'
  self.handle = nil
  self.output = {}
end

---Start the process
function Popen:start()
  self.handle = io.popen(self.cmd) --[[@as userdata]]
  if not self.handle then
    error(sprintf("Could not run command: %s", self.cmd))
  end

  return true
end

---Read next line of output
function Popen:readline()
  --- @diagnostic disable-next-line
  local line = self.handle:read('*line')
  if line == nil then
    return
  else
    self.output[#self.output+1] = line
    return line
  end
end

---Read all output
function Popen:readlines()
  while true do
    if self:readline() == nil then
      return self.output
    end
  end
end

---Read all output and optionally split lines
---@param split? string
---@return string[] | string
function Popen:read(split)
  --- @diagnostic disable-next-line
  self.output = self.handle:read('*all')
  if split then
    self.output = self.output:split(split)
  end
  return self.output
end

---Write text to stdin of the file handle
---@param s string
---@return number
function Popen:write(s)
  if not self.mode:match 'w' then
    error('Process is read-only')
  end

  self:write(s)
  return #s
end

---Stop the process
function Popen:close()
  if self.handle ~= nil then
    --- @diagnostic disable-next-line
    self.handle:close()
    self.handle = nil
  end
end

process.run = os.execute

---@param cmd string
---@param f? fun(lines: string) -> any
---@return any
function process.check_output(cmd, f)
  f = f or function (lines)
    return lines
  end
  fh = io.popen(cmd, 'r')

  if fh == nil then
    error(sprintf("Could not run command: %s", cmd))
  end

  local lines = fh:read('*all')
  local res = f(lines)
  fh:close()

  return res
end

process.with_open = process.check_output

return process
