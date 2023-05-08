local modulename, _ = ...
local moduleroot = modulename:gsub('(.+)%..+', '%1')

local file = require(moduleroot .. '.file')
local history = require(moduleroot .. '.history')
local notify = require(moduleroot .. '.notify')
local paths = require(moduleroot .. '.path')
local state = require(moduleroot .. '.state')

local M = {}

local function run_hooks(hooks, ws_meta, user_data)
  assert(
    hooks == nil
      or type(hooks) == 'table'
      or type(hooks) == 'function'
      or type(hooks) == 'string',
    'hooks must be of type nil, table, function, or string'
  )
  assert(type(ws_meta) == 'table', 'workspace metadata must be of type table')
  assert(type(user_data) == 'table', 'user data must be of type table')

  if type(hooks) == 'table' then
    for _, hook in ipairs(hooks) do
      run_hooks(hook, ws_meta, user_data)
    end
  elseif type(hooks) == 'function' then
    local status_ok, error_msg = pcall(hooks, ws_meta, user_data)
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

local function create_workspace(rootdir, user_data, timestamp)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  assert(type(user_data) == 'table', 'user data must be of type table')
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

  file.write_json(userdatafile, user_data)
  if vim.fn.filereadable(userdatafile) == 0 then
    error('failed to write workspace user data file "' .. userdatafile .. '"')
    return
  end

  file.write_file(datadir .. paths.sep() .. '.notags')
  file.write_file(datadir .. paths.sep() .. '.ignore', '*')
  file.write_file(datadir .. paths.sep() .. '.gitignore',
    'Session.vim\n'
    .. 'session.vim\n'
    .. 'PreSession.vim\n'
    .. 'presession.vim\n'
    .. 'userdata.json\n'
    .. 'trailblazer\n')

  run_hooks(state.on_create, {
    rootdir = rootdir,
    datadir = datadir,
  }, user_data)
  file.write_json(userdatafile, user_data)
  history.update(rootdir, timestamp)
end

local function delete_workspace(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')

  local datadir = rootdir .. paths.sep() .. state.data_dirname
  local metafile = datadir .. paths.sep() .. state.metadata_filename
  local userdatafile = datadir .. paths.sep() .. state.user_data_filename

  if vim.fn.isdirectory(datadir) == 0 then
    error('cannot delete non-existent workspace "' .. datadir .. '"')
    return
  end

  local user_data = file.read_json(userdatafile) or {}
  run_hooks(state.on_delete, {
    rootdir = rootdir,
    datadir = datadir,
  }, user_data)
  history.delete(rootdir)
  if
    datadir
    and not datadir:match('^[\\/]+$')
    and not datadir:match('^[%a]:[\\/]+$')
  then
    vim.fn.delete(datadir, 'rf')
  end
end

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

function M.create(rootdir, user_data, timestamp)
  assert(type(rootdir) == 'string', 'type of workspace path must be string')
  assert(type(user_data) == 'table', 'type of user data must be table')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  local p = paths.canonical(rootdir)
  create_workspace(p, user_data, timestamp)
end

function M.delete(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = paths.canonical(rootdir)
  delete_workspace(p)
end

function M.move(src, target)
  assert(type(src) == 'string', 'source workspace path must be a string')
  assert(type(target) == 'string', 'target workspace path must be a string')
  local p1 = paths.canonical(src)
  local p2 = paths.canonical(target)
  move_workspace(p1, p2)
end

function M.open(rootdir, timestamp)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  local p = paths.canonical(rootdir)
  open_workspace(p, timestamp)
end

function M.close(timestamp)
  assert(type(timestamp) == 'number', 'timestamp must be of type number')
  close_workspace(timestamp)
end

function M.is_open()
  return state.current_root_dirpath ~= nil
end

function M.get_current_root_dirpath()
  return state.current_root_dirpath
end

function M.get_current_data_dir()
  if state.current_root_dirpath ~= nil then
    return state.current_root_dirpath .. paths.sep() .. state.data_dirname
  end
  return nil
end

function M.contains_workspace(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local datadir = rootdir .. paths.sep() .. state.data_dirname
  return vim.fn.isdirectory(datadir) == 1
end

function M.read_metadata(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.metadata_filename
  return file.read_json(p)
end

function M.write_metadata(rootdir, metadata)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.metadata_filename
  file.write_json(p, metadata)
end

function M.read_user_data(rootdir)
  assert(type(rootdir) == 'string', 'workspace path must be of type string')
  local p = rootdir
    .. paths.sep()
    .. state.data_dirname
    .. paths.sep()
    .. state.user_data_filename
  return file.read_json(p)
end

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
