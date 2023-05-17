local module = {}

local files = require('hookspace.luamisc.files')
local paths = require('hookspace.luamisc.paths')
local platform = require('hookspace.luamisc.platform')
local sha2 = require('hookspace.luamisc.sha2')
local history = require('hookspace.history')
local notify = require('hookspace.notify')
local state = require('hookspace.state')


local function _str_strip(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end


local function _random_string(len)
  local chars = "abcdefghijklmnopqrstuvwxyz"
    .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    .. "1234567890"
  local result = ""
  for _ = 1, len do
    local ch_idx = math.random(1, #chars)
    result = result .. chars:sub(ch_idx, 1)
  end
  return result
end

local function _get_machine_id()
  local mach_id = platform.machine_id()
  if mach_id then
    return mach_id
  end

  local file = state.plugin_datadir .. paths.sep() .. "machine_id.txt"
  mach_id = files.read_file(file)
  mach_id = mach_id and _str_strip(mach_id) or nil
  if mach_id then
    return mach_id
  end

  mach_id = _random_string(32)
  files.write_file(file, mach_id)

  return mach_id
end

local function _userdir_name()
  local mach_id = _get_machine_id()
  local user_dir = tostring(sha2.sha3_512(mach_id)):gsub("[^a-zA-Z0-9]", "")
  return user_dir .. ".user" -- suffix so gitignore can auto-detect
end

local function _workspace(rootdir)
  return {
    rootdir = rootdir,
    datadir = rootdir .. paths.sep() .. state.data_dirname,
    userdir = rootdir .. paths.sep() .. state.data_dirname .. paths.sep() .. _userdir_name(),
    metafile = rootdir .. paths.sep() .. state.data_dirname .. paths.sep() .. state.metadata_filename,
  }
end


---@param hooks string|hook|hook[]
---@param workspace workspace
local function run_hooks(hooks, workspace)
  assert(
    hooks == nil
      or type(hooks) == 'table'
      or type(hooks) == 'function'
      or type(hooks) == 'string',
    'hooks must be of type nil, table, function, or string'
  )
  assert(workspace, 'expected workspace')

  if type(hooks) == 'table' then
    for _, hook in ipairs(hooks) do
      run_hooks(hook, workspace)
    end
  elseif type(hooks) == 'function' then
    local status_ok, error_msg = pcall(hooks, workspace)
    if not status_ok then
      notify.error('Failed to run hook "' .. vim.inspect(hooks) .. '"')
      if error_msg then
        notify.trace(error_msg)
      end
    end
  elseif type(hooks) == 'string' then
    ---@diagnostic disable-next-line: param-type-mismatch
    local status_ok, error_msg = pcall(vim.cmd, hooks)
    if not status_ok then
      notify.error('Failed to run hook "' .. vim.inspect(hooks) .. '"')
      if error_msg then
        notify.trace(error_msg)
      end
    end
  elseif hooks == nil then
    -- ignore
  end
end

---@param rootdir string
---@param timestamp integer
local function init_workspace(rootdir, timestamp)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')

  local workspace = _workspace(rootdir)
  local metadata = {
    name = paths.basename(paths.normpath(rootdir)) or "Unnamed",
    created = timestamp,
  }

  files.write_json(workspace.metafile, metadata)
  files.write_file(workspace.datadir .. paths.sep() .. '.notags')
  files.write_file(workspace.datadir .. paths.sep() .. '.ignore', '*')
  files.write_file(workspace.datadir .. paths.sep() .. '.tokeignore', '*')
  files.write_file(workspace.datadir .. paths.sep() .. '.gitignore',
    table.concat({"*.user", "Session.vim", "PreSession.vim"}, "\n"))

  run_hooks(state.on_init, workspace)
  history.update(rootdir, timestamp)
end

---@param src string
---@param dest string
local function move_workspace(src, dest)
  assert(type(src) == 'string', 'source path must be of type string')
  assert(type(dest) == 'string', 'target path must be of type string')

  local datadir = src .. paths.sep() .. state.data_dirname
  if vim.fn.isdirectory(datadir) == 0 then
    notify.error('failed to move non-existent workspace "' .. datadir .. '"')
    return
  end

  vim.fn.mkdir(dest, 'p')
  if vim.fn.isdirectory(dest) == 0 then
    notify.error('failed to create target workspace "' .. dest .. '"')
    return
  end

  history.rename(src, dest)
end

---@param rootdir string
---@param timestamp integer
local function open_workspace(rootdir, timestamp)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  assert(not state.current_rootdir, 'another workspace is already open')

  local workspace = _workspace(rootdir)
  if vim.fn.isdirectory(workspace.datadir) <= 0 then
    notify.error('failed to open non-existent workspace "' .. workspace.datadir .. '"')
    return
  end

  run_hooks(state.on_open, workspace)
  state.current_rootdir = rootdir
  history.update(rootdir, timestamp)
end

---@param timestamp integer
local function close_workspace(timestamp)
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  assert(state.current_rootdir, 'cannot close non-open workspace')

  local workspace = _workspace(state.current_rootdir)

  run_hooks(state.on_close, workspace)
  history.update(state.current_rootdir, timestamp)
  state.current_rootdir = nil
end

---@param rootdir string path to workspace root dir
---@param timestamp integer epoch sec to record as last access time
function module.init(rootdir, timestamp)
  assert(type(rootdir) == 'string', 'type of workspace path must be string')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  local p = paths.canonical(rootdir)
  init_workspace(p, timestamp)
end

---@param src string path to old workspace root dir
---@param target string path to new workspace root dir
function module.move(src, target)
  assert(type(src) == 'string', 'source workspace path must be a string')
  assert(type(target) == 'string', 'target workspace path must be a string')
  local p1 = paths.canonical(src)
  local p2 = paths.canonical(target)
  move_workspace(p1, p2)
end

---@param rootdir string path to root of workspace
---@param timestamp integer epoch sec to record as last access time
function module.open(rootdir, timestamp)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  local p = paths.canonical(rootdir)
  open_workspace(p, timestamp)
end

---@param timestamp integer epoch sec to record as last access time
function module.close(timestamp)
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  close_workspace(timestamp)
end

---@return boolean is_open if a workspace is currently open or not
function module.is_open()
  return state.current_rootdir ~= nil
end

---@return string? dir root dir of currently open workspace
function module.get_current_root_dir()
  return state.current_rootdir
end

---@return string? dir data dir of currently open workspace
function module.get_current_data_dir()
  if state.current_rootdir ~= nil then
    return state.current_rootdir .. paths.sep() .. state.data_dirname
  end
  return nil
end

---@param rootdir string workspace root dir
---@return string datadir workspace data dir
function module.get_data_dir(rootdir)
  return rootdir .. paths.sep() .. state.data_dirname
end

---@param rootdir string path to root of workspace
---@return boolean is_workspace true if is root dir of a workspace
function module.is_workspace(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local datadir = rootdir .. paths.sep() .. state.data_dirname
  return vim.fn.isdirectory(datadir) == 1
end

---@param rootdir string path to root of workspace
---@return workspace? workspace info
function module.read_metadata(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.metadata_filename
  return files.read_json(p)
end

---@param rootdir string path to root of workspace
---@param metadata workspace workspace info
function module.write_metadata(rootdir, metadata)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.metadata_filename
  files.write_json(p, metadata)
end

return module
