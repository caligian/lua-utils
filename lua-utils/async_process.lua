local class = require 'lua-utils.class'
local list = require 'lua-utils.list'
local dict = require 'lua-utils.dict'
local validate = require 'lua-utils.validate'
--local uv = require 'luv'
local uv = vim.uv



---@class AsyncProcessPipeOptions
---@field on_shutdown? function
---@field on_closing? function
---@field on_output? fun(pipe_type: string, text: string, output: string[])

---@class AsyncProcessPipe : AsyncProcessPipeOptions
---@field type string
---@field opened boolean
---@field handle userdata
---@field check? userdata
---@field output? string[]
---@overload fun(pipe_type: string, opts?: AsyncProcessPipeOptions)
local Pipe = class "AsyncProcessPipe"

function Pipe:is_closing()
  ---@diagnostic disable-next-line
  return self.handle:is_closing()
end

function Pipe:close()
  if not self.handle then
    return
  elseif not self:is_closing() then
    ---@diagnostic disable-next-line
    self.handle:close(self.on_closing)
    self.handle = nil
  end
end

function Pipe:shutdown()
  uv.shutdown(self.handle, function()
    if self.on_shutdown then self.on_shutdown() end
    self:close()
  end)
end

function Pipe:write(s)
  if self.type == 'stdin' then
    uv.write(self.handle, s)
  end
end

function Pipe:open()
  if self.opened then
    return
  else
    self.opened = true
  end

  uv.check_start(self.check, vim.schedule_wrap(function()
    if not self:is_closing() then
      return
    end

    uv.check_stop(self.check)
    self:shutdown()
  end))

  if self.type == 'stdin' then
    return
  end

  uv.read_start(self.handle, vim.schedule_wrap(function(err, text)
    print(err, text)
    if err then
      self:close()
      return
    elseif text then
      local len = self.output.length or 0
      self.output[len + 1] = text
      self.output.length = self.output.length + 1

      if self.on_output then
        local ok, _ = pcall(
          self.on_output,
          self.type, text, self.output
        )
        if not ok then self:close() end
      end
    end
  end))
end

function Pipe:initialize(pipe_type, opts)
  self.type = pipe_type
  self.check = uv.new_check()
  self.handle = uv.new_pipe()

  if self.type ~= 'stdin' then
    self.output = {}
  end

  dict.merge(self, opts)
end

---@class AsyncProcessOptions
---@field env? string[]
---@field uid? string
---@field gid? string
---@field verbatim? boolean
---@field detached? boolean
---@field hide? boolean
---@field mode? string 'rw' for read and write, 'r' for read-only and 'w' for write-only pipe
---@field on_exit function
---@field on_stdout function
---@field on_stderr function

---@class AsyncProcess : AsyncProcessOptions
---@field cmd string
---@field args string[]
---@field check userdata
---@field on_exit fun(code: number, signal: number)
---@field stdin? AsyncProcessPipe
---@field stdout? AsyncProcessPipe
---@field stderr? AsyncProcessPipe
---@field finished? boolean
---@field exit_code? number
---@field exit_signal? number
---@field handle? userdata
---@field started boolean
---@field pid? number
local AsyncProcess = class 'AsyncProcess'
local process_opts = {
  'args', 'stdio', 'env',
  'uid', 'gid', 'verbatim',
  'detached', 'hide'
}

function AsyncProcess:initialize(cmd, args, opts)
  self.cmd = cmd
  self.args = args or {}
  self.stdio = {}
  self.check = uv.new_check()
  self.started = false
  opts = opts or {}

  dict.merge(self, opts)

  local mode = self.mode

  if mode:match 'w' then
    self.stdin = Pipe('stdin')
    self.stdio[1] = self.stdin.handle
  end

  if mode:match 'r' then
    self.stdout = Pipe('stdout', { on_output = self.on_stdout })
    self.stderr = Pipe('stderr', { on_output = self.on_stderr })
    self.stdio[2] = self.stdout.handle
    self.stdio[3] = self.stderr.handle
  end

  local on_exit = self.on_exit
  self.on_exit = function(code, signal)
    self.exit_code = code
    self.exit_signal = signal

    if on_exit then
      on_exit(code, signal)
    end
  end
end

function AsyncProcess:is_closing()
  ---@diagnostic disable-next-line
  if self.handle:is_closing() then
    return true
  end
end

function AsyncProcess:close()
  if not self:is_closing() then
    ---@diagnostic disable-next-line
    self.handle:close()
  end
end

function AsyncProcess:kill()
  if self.handle then
    uv.kill(self.pid)
  end
end

function AsyncProcess:shutdown()
  local close_pipe = function(pipe)
    if pipe then pipe:close() end
  end

  uv.shutdown(function()
    close_pipe(self.stdin)
    close_pipe(self.stdout)
    close_pipe(self.stderr)
    self:close()
  end)
end

function AsyncProcess:start()
  if self.started then
    return
  else
    self.started = true
  end

  local open_pipe = function(pipe)
    if pipe then pipe:open() end
  end

  open_pipe(self.stdin)
  open_pipe(self.stdout)
  open_pipe(self.stderr)

  uv.check_start(self.check, function()
    if not self:is_closing() then
      for _, pipe in pairs(self.stdio) do
        if uv.is_closing(pipe) then
          uv.shutdown(self.check)
          self:shutdown()
        end
      end
    else
      uv.check_stop(self.check)
      self:shutdown()
    end
  end)

  local opts = {}
  for _, o in pairs(process_opts) do
    opts[o] = self[o]
  end

  opts.args = self.args
  opts.stdio = self.stdio
  local handle, pid = uv.spawn(self.cmd, opts, function (code, signal)
    printf('exiting with code %d and signal %d', code, signal)
    uv.check_stop(self.check)
    self.on_exit(code, signal)
  end)
  self.handle = handle
  self.pid = pid

  if not handle then
    error("Could not start process")
  end
end

proc = AsyncProcess('ls', {'-l'}, {
  mode = 'r'
})

proc:start()
proc:close()
pp(proc.stdout.output)
