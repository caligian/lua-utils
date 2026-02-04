require 'lua-utils.utils'
require 'lua-utils.string'

local class = require 'lua-utils.class'
local copy = require 'lua-utils.copy'

local process = {}
process.Popen = class 'Popen'

---@class Popen
---@field cmd string
---@field mode? string
---@field handle? userdata
---@field output string[] | string 
local Popen

---@overload fun(cmd: string, mode?: string) -> Popen
Popen = class 'Popen'

function Popen:initialize(cmd, mode)
  self.cmd = cmd
  self.mode = mode or 'r'
  self.handle = nil
  self.output = {}
  self.output_read = false
  self.started = false
  self.completed = false
end

---Start the process
function Popen:start()
  if self.started then
    return true
  end

  if self.completed then
    error('Process has closed')
  end

  self.handle = io.popen(self.cmd) --[[@as userdata]]
  if not self.handle then
    error(sprintf("Could not run command: %s", self.cmd))
  end

  self.started = true
  return true
end

---Read next line of output
function Popen:readline()
  if not self.started then
    error('Process has not started yet')
  end

  if self.output_read then
    return
  end

  --- @diagnostic disable-next-line
  local line = self.handle:read('*line')
  if line == nil then
    self.output_read = true
    return
  else
    self.output[#self.output+1] = line
    return line
  end
end

---Read all output
function Popen:readlines()
  if not self.started then
    error('Process has not started yet')
  end

  if self.output_read then
    return self.output
  end

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
  if not self.started then
    error('Process has not started yet')
  end

  if self.output_read then
    return self.output
  end

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
  if not self.started then
    error('Process has not started yet')
  end

  if not self.mode:match 'w' then
    error('Process is read-only')
  end

  self:write(s)
  return #s
end

---Stop the process
function Popen:close()
  if not self.started then
    error('Process has not started yet')
  end

  if self.handle ~= nil then
    --- @diagnostic disable-next-line
    self.handle:close()
    self.handle = nil
    self.started = false

    return true
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

---@class systemOpts
---@field stdout? boolean (default: false)
---@field capture? boolean (default: false)
---@field newlines? boolean (default: true)
---@field apply? (fun(lines: string | string[]): any)

---Run a system command and optionally capture output
---@param cmd string
---@param opts? systemOpts
function process.system(cmd, opts)
  opts = opts or {}
  local capture = opts.stdout or opts.capture
  local split = opts.newlines
  local apply = opts.apply

  if not capture then
    process.run(cmd)
  end

  local output = process.check_output(cmd)
  if split then
    output = string.split(output, '\n')
  end

  if apply then
    return apply(output)
  else
    return output
  end
end

---@param cmd string
---@param opts?
function process.systemlist(cmd, opts)
  opts = opts or {}
  opts = copy.copy(opts)
  opts.capture = true
  opts.newlines = true

  return system(cmd, opts)
end

---Import some functions to global spaces
function process:import()
  _G.process = process
  _G.system = process.system
  _G.systemlist = process.systemlist
  _G.Popen = process.Popen
end

return process
