local M = {}

local arrays = require("hookspace.luamisc.arrays")
local files = require("hookspace.luamisc.files")
local paths = require("hookspace.luamisc.paths")
local platform = require("hookspace.luamisc.platform")
local sha2 = require("hookspace.luamisc.sha2")
local history = require("hookspace.history")
local notify = require("hookspace.notify")
local consts = require("hookspace.consts")
local useropts = require("hookspace.useropts")

local current_rootdir = nil
local machine_id_len = 32
local workspace_id_len = 32

local function _to_lines(s)
  local lines = {}

  while s and #s > 0 do
    local eol, _ = s:find("\n", 1, true)
    local line = eol and s:sub(1, eol) or s
    s = eol and s:sub(eol + 1) or ""

    line = line:gsub("[%s\r\n]+$", "")
    table.insert(lines, line)
  end

  return lines
end

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

  local file = consts.plugin_dir .. paths.sep() .. "machine_id.txt"
  mach_id = files.read_file(file)
  mach_id = mach_id and _str_strip(mach_id) or nil
  if mach_id then
    return mach_id
  end

  mach_id = _random_string(machine_id_len)
  files.write_file(file, mach_id)

  return mach_id
end

local function _userdir_name()
  local mach_id = _get_machine_id()
  local user_dir = tostring(sha2.md5(mach_id)):gsub("[^a-zA-Z0-9]", "")
  return user_dir .. ".user" -- suffix so gitignore can auto-detect
end

local function _workspace_paths(rootdir)
  return {
    rootdir = rootdir,
    datadir = rootdir .. paths.sep() .. consts.workspace_dirname,
    userdir = rootdir
      .. paths.sep()
      .. consts.workspace_dirname
      .. paths.sep()
      .. _userdir_name(),
    metafile = rootdir
      .. paths.sep()
      .. consts.workspace_dirname
      .. paths.sep()
      .. consts.metadata_filename,
  }
end

---@param hooks string|hook|hook[]
---@param workspace workspace
local function run_hooks(hooks, workspace)
  assert(
    hooks == nil
      or type(hooks) == "table"
      or type(hooks) == "function"
      or type(hooks) == "string",
    "hooks must be of type nil, table, function, or string"
  )
  assert(workspace, "expected workspace")

  if type(hooks) == "table" then
    for _, hook in ipairs(hooks) do
      run_hooks(hook, workspace)
    end
  elseif type(hooks) == "function" then
    local status_ok, error_msg = pcall(hooks, workspace)
    if not status_ok then
      notify.error('Failed to run hook "' .. vim.inspect(hooks) .. '"')
      if error_msg then
        notify.trace(error_msg)
      end
    end
  elseif type(hooks) == "string" then
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

local function update_ignorefile(ignorefile, lines)
  local data = files.read_file(ignorefile) or nil
  local lines_ = data and _to_lines(data) or {}

  arrays.extend(lines_, lines)
  arrays.uniqify(lines_)

  files.write_file(ignorefile, table.concat(lines_, "\n"))
end

---@param rootdir string path to workspace root dir
---@param timestamp integer epoch sec to record as last access time
function M.init(rootdir, timestamp)
  assert(rootdir, "expected rootdir")
  assert(timestamp, "expected timestamp")
  rootdir = paths.canonical(rootdir)

  local workpaths = _workspace_paths(rootdir)

  local metadata = M.read_metadata(rootdir) or {}
  metadata.name = metadata.name
    or paths.basename(paths.normpath(rootdir))
    or "Unnamed"
  metadata.created = metadata.created or timestamp
  metadata.id = _random_string(workspace_id_len)

  files.write_json(workpaths.metafile, metadata)
  files.write_file(workpaths.datadir .. paths.sep() .. ".notags")
  files.write_file(workpaths.datadir .. paths.sep() .. ".ignore", "*")
  files.write_file(workpaths.datadir .. paths.sep() .. ".tokeignore", "*")

  update_ignorefile(
    workpaths.datadir .. paths.sep() .. ".gitignore",
    { "/*.user", "/Session.vim", "/Before.vim" }
  )

  files.makedirs(workpaths.datadir)
  files.makedirs(workpaths.userdir)
  run_hooks(useropts.on_init, workpaths)
  history.update(rootdir, timestamp)
end

---@param rootdir string path to root of workspace
---@param timestamp integer epoch sec to record as last access time
function M.open(rootdir, timestamp)
  assert(rootdir, "expected root dir")
  assert(timestamp, "expected timestamp")
  assert(not current_rootdir, "another workspace is already open")

  rootdir = paths.canonical(rootdir)
  local workpaths = _workspace_paths(rootdir)
  if vim.fn.isdirectory(workpaths.datadir) <= 0 then
    notify.error(
      'failed to open non-existent workspace "' .. workpaths.datadir .. '"'
    )
    return
  end

  files.makedirs(workpaths.datadir)
  files.makedirs(workpaths.userdir)
  run_hooks(useropts.on_open, workpaths)
  current_rootdir = rootdir
  history.update(rootdir, timestamp)
end

---@param timestamp integer epoch sec to record as last access time
function M.close(timestamp)
  assert(timestamp, "expected timestamp")
  assert(current_rootdir, "cannot close non-open workspace")

  local workpaths = _workspace_paths(current_rootdir)

  files.makedirs(workpaths.datadir)
  files.makedirs(workpaths.userdir)
  run_hooks(useropts.on_close, workpaths)
  history.update(current_rootdir, timestamp)
  current_rootdir = nil
end

---@return boolean is_open if a workspace is currently open or not
function M.is_open()
  return current_rootdir ~= nil
end

---@return string? dir root dir of currently open workspace
function M.get_root_dir()
  return current_rootdir
end

---@param rootdir? string workspace root dir
---@return string? datadir workspace data dir
function M.get_data_dir(rootdir)
  rootdir = rootdir or current_rootdir
  if not rootdir then
    return nil
  end
  return _workspace_paths(rootdir).datadir
end

---@param rootdir string path to root of workspace
---@return boolean is_workspace true if is root dir of a workspace
function M.is_workspace(rootdir)
  assert(type(rootdir) == "string", "workspace path must be of type string")
  local workpaths = _workspace_paths(rootdir)
  return vim.fn.isdirectory(workpaths.datadir) == 1
end

---@param rootdir? string path to root of workspace
---@return workspace? workspace info
function M.read_metadata(rootdir)
  rootdir = rootdir or current_rootdir
  if not rootdir then
    return nil
  end
  local workpaths = _workspace_paths(rootdir)
  return files.read_json(workpaths.metafile)
end

---@param rootdir? string path to root of workspace
---@param metadata workspace workspace info
function M.write_metadata(rootdir, metadata)
  rootdir = rootdir or current_rootdir
  assert(rootdir, "expected root dir or already-opened root dir")
  local workpaths = _workspace_paths(rootdir)
  files.write_json(workpaths.metafile, metadata)
end

return M
