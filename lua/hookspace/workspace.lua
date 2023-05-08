local modulename, _ = ...
local moduleroot = modulename:gsub('(.+)%..+', '%1')

local file = require(moduleroot .. '.file')
local history = require(moduleroot .. '.history')
local notify = require(moduleroot .. '.notify')
local paths = require(moduleroot .. '.path')
local state = require(moduleroot .. '.state')

local M = {}

---@param hooks string|HookspaceHook|HookspaceHook[]
---@param workspace HookspaceWorkspace
---@param userdata HookspaceUserData
local function run_hooks(hooks, workspace, userdata)
  assert(
    hooks == nil
      or type(hooks) == 'table'
      or type(hooks) == 'function'
      or type(hooks) == 'string',
    'hooks must be of type nil, table, function, or string'
  )
  assert(type(workspace) == 'table', 'workspace metadata must be of type table')
  assert(type(userdata) == 'table', 'user data must be of type table')

  if type(hooks) == 'table' then
    for _, hook in ipairs(hooks) do
      run_hooks(hook, workspace, userdata)
    end
  elseif type(hooks) == 'function' then
    local status_ok, error_msg = pcall(hooks, workspace, userdata)
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
---@param userdata HookspaceUserData
---@param timestamp integer
local function init_workspace(rootdir, userdata, timestamp)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  assert(type(userdata) == 'table', 'user data must be of type table')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')

  local datadir = rootdir .. paths.sep() .. state.data_dirname
  local metafile = datadir .. paths.sep() .. state.metadata_filename
  local userdatafile = datadir .. paths.sep() .. state.user_data_filename

  vim.fn.mkdir(datadir, 'p')
  if vim.fn.isdirectory(datadir) == 0 then
    error('failed to create workspace data directory "' .. datadir .. '"')
    return
  end

  file.write_json(metafile, {
    name = paths.basename(paths.normpath(rootdir)),
    created = timestamp,
  })
  if vim.fn.filereadable(metafile) == 0 then
    error('failed to write workspace metadata file "' .. metafile .. '"')
    return
  end

  file.write_json(userdatafile, userdata)
  if vim.fn.filereadable(userdatafile) == 0 then
    error('failed to write workspace user data file "' .. userdatafile .. '"')
    return
  end

  file.write_file(datadir .. paths.sep() .. '.notags')
  file.write_file(datadir .. paths.sep() .. '.ignore', '*')
  file.write_file(datadir .. paths.sep() .. '.gitignore',
    'session\n'
    .. 'Session.vim\n'
    .. 'PreSession.vim\n'
    .. 'userdata.json\n'
    .. 'trailblazer\n')

  run_hooks(state.on_init, {
    rootdir = rootdir,
    datadir = datadir,
  }, userdata)
  file.write_json(userdatafile, userdata)
  history.update(rootdir, timestamp)
end

---@param src_rootdir string
---@param target_rootdir string
local function move_workspace(src_rootdir, target_rootdir)
  assert(type(src_rootdir) == 'string', 'source path must be of type string')
  assert(type(target_rootdir) == 'string', 'target path must be of type string')

  local src_datadir = src_rootdir .. paths.sep() .. state.data_dirname
  local target_datadir = target_rootdir .. paths.sep() .. state.data_dirname

  if vim.fn.isdirectory(src_datadir) == 0 then
    error(
      'failed to move non-existent workspace root dir"' .. src_datadir .. '"'
    )
    return
  end

  vim.fn.mkdir(target_rootdir, 'p')
  if vim.fn.isdirectory(target_rootdir) == 0 then
    error(
      'failed to create target workspace root dir "' .. target_rootdir .. '"'
    )
    return
  end

  if
    target_datadir
    and not target_datadir:match('^[\\/]+$')
    and not target_datadir:match('^[%a]:[\\/]+$')
  then
    vim.fn.delete(target_datadir, 'rf')
  end
  vim.fn.rename(src_datadir, target_datadir)
  history.rename(src_rootdir, target_rootdir)
end

---@param rootdir string
---@param timestamp integer
local function open_workspace(rootdir, timestamp)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  assert(
    not state.current_root_dirpath,
    'cannot open workspace when one is already open'
  )

  local datadir = rootdir .. paths.sep() .. state.data_dirname
  local metafile = datadir .. paths.sep() .. state.metadata_filename
  local userdatafile = datadir .. paths.sep() .. state.user_data_filename

  if vim.fn.isdirectory(datadir) == 0 then
    error('failed to open non-existent workspace "' .. datadir .. '"')
    return
  end

  local user_data = file.read_json(userdatafile) or {}
  run_hooks(state.on_open, {
    rootdir = rootdir,
    datadir = datadir,
  }, user_data)
  file.write_json(userdatafile, user_data)
  state.current_root_dirpath = rootdir
  history.update(rootdir, timestamp)
end

---@param timestamp integer
local function close_workspace(timestamp)
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  assert(
    state.current_root_dirpath,
    'cannot close workspace when one is not already open'
  )

  local datadir = state.current_root_dirpath
    .. paths.sep()
    .. state.data_dirname
  local metafile = datadir .. paths.sep() .. state.metadata_filename
  local userdatafile = datadir .. paths.sep() .. state.user_data_filename

  local user_data = file.read_json(userdatafile) or {}
  run_hooks(state.on_close, {
    rootdir = state.current_root_dirpath,
    datadir = datadir,
  }, user_data)
  file.write_json(userdatafile, user_data)
  history.update(state.current_root_dirpath, timestamp)
  state.current_root_dirpath = nil
end

---@param rootdir string path to workspace root dir
---@param user_data? HookspaceUserData initial user data
---@param timestamp integer epoch sec to record as last access time
function M.init(rootdir, user_data, timestamp)
  assert(type(rootdir) == 'string', 'type of workspace path must be string')
  assert(type(user_data) == 'table', 'type of user data must be table')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  local p = paths.canonical(rootdir)
  init_workspace(p, user_data, timestamp)
end

---@param src string path to old workspace root dir
---@param target string path to new workspace root dir
function M.move(src, target)
  assert(type(src) == 'string', 'source workspace path must be a string')
  assert(type(target) == 'string', 'target workspace path must be a string')
  local p1 = paths.canonical(src)
  local p2 = paths.canonical(target)
  move_workspace(p1, p2)
end

---@param rootdir string path to root of workspace
---@param timestamp integer epoch sec to record as last access time
function M.open(rootdir, timestamp)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  local p = paths.canonical(rootdir)
  open_workspace(p, timestamp)
end

---@param timestamp integer epoch sec to record as last access time
function M.close(timestamp)
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  close_workspace(timestamp)
end

---@return boolean is_open if a workspace is currently open or not
function M.is_open()
  return state.current_root_dirpath ~= nil
end

---@return string? dir root dir of currently open workspace
function M.get_current_root_dir()
  return state.current_root_dirpath
end

---@return string? dir data dir of currently open workspace
function M.get_current_data_dir()
  if state.current_root_dirpath ~= nil then
    return state.current_root_dirpath .. paths.sep() .. state.data_dirname
  end
  return nil
end

---@param rootdir string workspace root dir
---@return string datadir workspace data dir
function M.get_datadir(rootdir)
  return rootdir .. paths.sep() .. state.data_dirname
end

---@param rootdir string path to root of workspace
---@return boolean is_workspace true if is root dir of a workspace
function M.is_workspace(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local datadir = rootdir .. paths.sep() .. state.data_dirname
  return vim.fn.isdirectory(datadir) == 1
end

---@param rootdir string path to root of workspace
---@return HookspaceWorkspace? workspace info
function M.read_metadata(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.metadata_filename
  return file.read_json(p)
end

---@param rootdir string path to root of workspace
---@param metadata HookspaceWorkspace workspace info
function M.write_metadata(rootdir, metadata)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.metadata_filename
  file.write_json(p, metadata)
end

---@param rootdir string workspace root dir path
---@return HookspaceUserData userdata user data
function M.read_user_data(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.user_data_filename
  return file.read_json(p) or {}
end

---@param rootdir string workspace root dir path
---@param user_data HookspaceUserData user data
function M.write_user_data(rootdir, user_data)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.user_data_filename
  file.write_json(p, user_data)
end

return M
