require 'lua-utils.string'
local path = require 'path'

path.fs = require 'path.fs'
path.info = require 'path.info'
path.env = require 'path.env'

---Similar to fs.glob but returns a list instead
---@param pattern string
---@return string[]
function path.glob(pattern)
  local files = {}

  for filename, _ in path.fs.glob(pattern) do
    files[#files + 1] = filename
  end

  return files
end

---Split path by system separator string
---@param filename string
---@return string[]
function path.split(filename)
  local sep = path.root()
  local ps = {}

  if sep == '\\' then
    ps = filename:gsub("\\+", "\\"):split('\\+')
  else
    ps = filename:gsub("/+", "/"):split("/")
  end

  return ps
end

---Return the extension of filename
---@param filename string
---@return string?
function path.extension(filename)
  for i = #filename, 1, -1 do
    local c = filename:sub(i, i)
    if c == '.' then
      return filename:sub(i + 1, #filename)
    end
  end
end

---Remove the extension and return the file basename
---@param filename string
---@return string?
function path.no_extension(filename)
  local ext = path.extension(filename)
  if ext then
    local name = path.basename(filename)
    return (name:gsub('[.]' .. ext, ''))
  else
    return path.basename(filename)
  end
end

---@class ls_context
---@field parent string
---@field path string
---@field extension string
---@field type string
---@field basename string

---@class ls_options
---@field depth? number (default: -1) When depth is a negative number, go all the way
---@field stop_when? fun(context: ls_context): boolean Stop when the condition is true and return everything collected till then
---@field map? fun(context: ls_context) Apply this function to matched files and use the returning value
---@field include? string (default: .*) Include only these files in the result
---@field include_dir? string (default: .*) Include only these directories while traversing

---List files recursively
---@param dirname string
---@param opts ls_options
---@return string[]
function path.ls(dirname, opts)
  local function create_context(filename, filetype)
    return {
      path = filename,
      parent = path.dirname(filename),
      extension = path.extension(filename),
      basename = path.basename(filename),
      type = filetype
    }
  end

  local function list_files(d, _opts)
    _opts = _opts or {}
    local required_depth = _opts.depth
    local current_depth = _opts.current_depth
    local result = _opts.result
    local stop_when = _opts.stop_when
    local include = _opts.include
    local include_dir = _opts.include_dir
    local map = _opts.map

    if current_depth == required_depth then
      return
    end

    include = include or '.*'
    include_dir = include_dir or '.*'
    local next_dirs = {}

    for filename, filetype in path.fs.dir(d) do
      if filetype == 'dir' and filename:match(include_dir) then
        next_dirs[#next_dirs + 1] = filename
      elseif stop_when and stop_when(create_context(filename, filetype)) then
        result[#result + 1] = filename
        return
      elseif filename:match(include) then
        result[#result + 1] = map(create_context(filename, filetype))
      end
    end

    for i = 1, #next_dirs do
      result[#result+1] = next_dirs[i]
      list_files(next_dirs[i], {
        include = include,
        depth = required_depth,
        current_depth = current_depth + 1,
        result = result,
        stop_when = stop_when,
        map = map,
        include_dir = include_dir
      })
    end
  end

  opts = opts or {}
  dirname = path.abspath(dirname)
  local depth = opts.depth or 1
  local stop_when = opts.stop_when
  local include = opts.include
  local result = {}
  local map = opts.map or function(x)
    return x.path
  end
  local include_dir = opts.include_dir

  list_files(
    dirname,
    {
      depth = depth,
      current_depth = 0,
      result = result,
      stop_when = stop_when,
      map = map,
      include = include,
      include_dir = include_dir
    }
  )

  return result
end

---Find the directory containing the marker files.
---Traverse backwards into parent directories if markers files are not present
---@param dirname string starting directory
---@param markers string | string[] Marker files, for example, `.git`
---@param depth? number (default: 3) Maximum depth to traverse backwards to
---@return string?
function path.search_parents(dirname, markers, depth, _current_depth)
  dirname = path.abs(dirname)
  _current_depth = _current_depth or 0
  depth = depth or 3
  markers = type(markers) == 'string' and { markers } or markers

  if dirname == '/' then
    return
  elseif _current_depth == depth then
    return
  end

  for i = 1, #markers do
    local check_filename = path(dirname, markers[i])
    if path.exists(check_filename) then
      return dirname
    end
  end

  return path.search_parents(
    path.dirname(dirname), markers,
    depth, _current_depth + 1
  )
end

---List files of a particular type
---@param dirname string
---@param filetype string required filetype
function path.ls_type(dirname, filetype)
  dirname = path.abspath(dirname)
  local res = {}

  for filename, ft in path.fs.dir(dirname) do
    if ft == filetype then
      res[#res + 1] = filename
    end
  end

  return res
end

---List directories
---@param dirname string
---@return string[]
function path.ls_dir(dirname)
  return path.ls_type(dirname, 'dir')
end

---List files
---@param dirname string
---@return string[]
function path.ls_file(dirname)
  return path.ls_type(dirname, 'file')
end

---List links
---@param dirname string
---@return string[]
function path.ls_link(dirname)
  return path.ls_type(dirname, 'link')
end

---List mounting points
---@param dirname string
---@return string[]
function path.ls_mount(dirname)
  return path.ls_type(dirname, 'mount')
end

---Find the directory containing the marker files
---Traverse forwards into children directories if markers files are not present
---@param dirname string starting directory
---@param markers string | string[] Marker files, for example, `.git`
---@param depth? number (default: 3) Maximum depth to traverse backwards to
---@return string?
function path.search_children(dirname, markers, depth, _current_depth)
  ---@cast markers string[]
  markers = type(markers) == 'string' and { markers } or markers
  dirname = path.abspath(dirname)
  depth = depth or 3
  _current_depth = _current_depth or 0
  local next_dirs = {}

  if _current_depth == depth then
    return
  end

  for filename, filetype in path.fs.dir(dirname) do
    local basename = path.basename(filename)
    for i = 1, #markers do
      if basename == markers[i] then
        return dirname
      elseif filetype == 'dir' then
        next_dirs[#next_dirs + 1] = filename
      end
    end
  end

  for i = 1, #next_dirs do
    local found = path.search_children(
      next_dirs[i], markers,
      depth, _current_depth + 1
    )
    if found then
      return found
    end
  end
end

---Check if directory is a git directory
---@param dirname string
---@return string?
function path.is_git_dir(dirname)
  dirname = path.abspath(dirname)
  local check = path(dirname, '.git')
  if path.is_dir(check) then
    return dirname
  end
end

---Find all git directories in directory
---@param dirname string
---@return string[]
function path.git_dirs(dirname, depth)
  local res = {}
  depth = depth or 4

  local function find(d, current_depth)
    current_depth = current_depth or 0
    if current_depth == depth then
      return
    elseif path.is_git_dir(d) then
      res[#res + 1] = d
    else
      local next_dirs = path.ls_dir(d)
      for i = 1, #next_dirs do
        find(next_dirs[i], current_depth + 1)
      end
    end
  end

  find(path.abspath(dirname), 0)
  return res
end

path.abspath = path.abs
path.no_ext = path.no_extension
path.ext = path.extension
path.cd = path.fs.chdir
path.chdir = path.fs.chdir
path.fs.cd = path.cd
path.dirname = path.parent
path.basename = path.name
path.is_dir = path.isdir
path.is_file = path.isfile
path.is_link = path.islink
path.is_mount = path.ismount
path.fs.is_dir = path.isdir
path.fs.is_file = path.isfile
path.fs.is_link = path.islink
path.fs.is_mount = path.ismount
path.fs.is_git_dir = path.is_git_dir
path.fs.search_parents = path.search_parents
path.fs.search_children = path.search_children
path.fs.searchf = path.fs.search_children
path.fs.searchb = path.fs.search_parents
path.searchf = path.fs.searchf
path.searchb = path.fs.searchb
path.fs.ls_dir = path.ls_dir
path.fs.ls_file = path.ls_file
path.fs.ls_mount = path.ls_mount
path.fs.ls_link = path.ls_link
path.fs.ls = path.ls
path.getcwd = path.cwd
path.fs.rm_r = path.fs.removedirs
path.fs.rm = path.fs.remove
path.fs.cp = path.fs.copy
path.fs.ln = path.fs.symlink

return path
