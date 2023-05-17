local modulename, _ = ...
local moduleroot = modulename:gsub('(.+)%..+', '%1')

local files = require(moduleroot .. '.luamisc.files')
local paths = require(moduleroot .. '.luamisc.paths')
local history = require(moduleroot .. '.history')
local notify = require(moduleroot .. '.notify')
local state = require(moduleroot .. '.state')

local module = {}

---@param hooks string|hook|hook[]
---@param workspace workspace
---@param userdata userdata
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
---@param userdata userdata
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

  files.write_json(metafile, {
    name = paths.basename(paths.normpath(rootdir)),
    created = timestamp,
  })
  if vim.fn.filereadable(metafile) == 0 then
    error('failed to write workspace metadata file "' .. metafile .. '"')
    return
  end

  files.write_json(userdatafile, userdata)
  if vim.fn.filereadable(userdatafile) == 0 then
    error('failed to write workspace user data file "' .. userdatafile .. '"')
    return
  end

  files.write_file(datadir .. paths.sep() .. '.notags')
  files.write_file(datadir .. paths.sep() .. '.ignore', '*')
  files.write_file(datadir .. paths.sep() .. '.gitignore',
    'session\n'
    .. 'Session.vim\n'
    .. 'PreSession.vim\n'
    .. 'userdata.json\n'
    .. 'trailblazer\n')

  run_hooks(state.on_init, { rootdir = rootdir, datadir = datadir }, userdata)

  files.write_json(userdatafile, userdata)
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
    not state.current_rootdir,
    'cannot open workspace when one is already open'
  )

  local datadir = rootdir .. paths.sep() .. state.data_dirname
  local meta_file = datadir .. paths.sep() .. state.metadata_filename
  local user_file = datadir .. paths.sep() .. state.user_data_filename

  if vim.fn.isdirectory(datadir) == 0 then
    error('failed to open non-existent workspace "' .. datadir .. '"')
    return
  end

  local user_data = files.read_json(user_file) or {}
  run_hooks(state.on_open, {
    rootdir = rootdir,
    datadir = datadir,
  }, user_data)
  files.write_json(user_file, user_data)
  state.current_rootdir = rootdir
  history.update(rootdir, timestamp)
end

---@param timestamp integer
local function close_workspace(timestamp)
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  assert(
    state.current_rootdir,
    'cannot close workspace when one is not already open'
  )

  local datadir = state.current_rootdir
    .. paths.sep()
    .. state.data_dirname
  local metafile = datadir .. paths.sep() .. state.metadata_filename
  local userdatafile = datadir .. paths.sep() .. state.user_data_filename

  local user_data = files.read_json(userdatafile) or {}
  run_hooks(state.on_close, {
    rootdir = state.current_rootdir,
    datadir = datadir,
  }, user_data)
  files.write_json(userdatafile, user_data)
  history.update(state.current_rootdir, timestamp)
  state.current_rootdir = nil
end

---@param rootdir string path to workspace root dir
---@param user_data? userdata initial user data
---@param timestamp integer epoch sec to record as last access time
function module.init(rootdir, user_data, timestamp)
  assert(type(rootdir) == 'string', 'type of workspace path must be string')
  assert(type(user_data) == 'table', 'type of user data must be table')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  local p = paths.canonical(rootdir)
  init_workspace(p, user_data, timestamp)
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

---@param rootdir string workspace root dir path
---@return userdata userdata user data
function module.read_user_data(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.user_data_filename
  return files.read_json(p) or {}
end

---@param rootdir string workspace root dir path
---@param user_data userdata user data
function module.write_user_data(rootdir, user_data)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.user_data_filename
  files.write_json(p, user_data)
end

return module
