local M = {}

local arrays = require("hookspace.luamisc.arrays")
local files = require("hookspace.luamisc.files")
local paths = require("hookspace.luamisc.paths")
local strings = require("hookspace.luamisc.strings")
local tables = require("hookspace.luamisc.tables")
local history = require("hookspace.history")
local notify = require("hookspace.notify")
local consts = require("hookspace.consts")
local useropts = require("hookspace.useropts")

---@type workspace? currently open workspace
local current = nil

local function get_file_uid(filename)
  if vim.fn.filereadable(filename) <= 0 then
    return nil
  end
  local n = files.inode(filename)
    or files.file_id(filename)
    or files.modified(filename)
  return (n and strings.itoa(n)) or nil
end


--- calc file paths for metadata files in workspace
---@param rootdir string path to workspace root
---@return workspace table containing workspace info
local function get_workspace(rootdir)
  local rootdir = paths.canonical(rootdir)
  local localdir = nil

  local idfile = rootdir
    .. paths.sep()
    .. consts.datadir_name
    .. paths.sep()
    .. consts.localid_name

  local workpaths = {
    rootdir = function()
      return rootdir
    end,
    datadir = function()
      return rootdir .. paths.sep() .. consts.datadir_name
    end,
    metafile = function()
      return rootdir
        .. paths.sep()
        .. consts.datadir_name
        .. paths.sep()
        .. consts.metafile_name
    end,
    localdir = function()
      if localdir then
        return localdir
      end

      if vim.fn.filereadable(idfile) <= 0 then
        files.write_file(idfile)
      end

      local identifier = get_file_uid(idfile)
      if not identifier then
        return nil
      end

      localdir = consts.plugin_datadir
        .. paths.sep()
        .. "workspaces"
        .. paths.sep()
        .. identifier

      return localdir
    end,
  }

  return workpaths
end

local function update_ignorefile(ignorefile, lines)
  local data = files.read_file(ignorefile) or nil
  local lines_ = data and strings.lines(data) or {}

  arrays.extend(lines_, lines)
  arrays.uniqify(lines_)

  files.write_file(ignorefile, table.concat(lines_, "\n"))
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
    hooks = vim.tbl_extend("force", {}, hooks)
    arrays.canonicalize(hooks)
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

---@param rootdir string path to workspace root dir
---@param timestamp integer epoch sec to record as last access time
function M.init(rootdir, timestamp)
  assert(rootdir, "expected rootdir")
  assert(timestamp, "expected timestamp")
  local rootdir = paths.canonical(rootdir)
  local workpaths = get_workspace(rootdir)

  local meta = M.read_metadata(rootdir) or {}
  meta.name = meta.name or paths.basename(rootdir) or "Unnamed"
  meta.created = meta.created or timestamp
  files.write_json(workpaths.metafile(), meta)

  files.write_file(workpaths.datadir() .. paths.sep() .. ".notags")
  files.write_file(workpaths.datadir() .. paths.sep() .. ".ignore", "*")
  files.write_file(workpaths.datadir() .. paths.sep() .. ".tokeignore", "*")

  update_ignorefile(
    workpaths.datadir() .. paths.sep() .. ".gitignore",
    { "/.identifier" }
  )

  files.makedirs(workpaths.datadir())
  files.makedirs(workpaths.localdir())
  history.touch(rootdir, timestamp)
  run_hooks(useropts.on_init, workpaths)
end

---@param rootdir string path to root of workspace
---@param timestamp integer epoch sec to record as last access time
function M.open(rootdir, timestamp)
  assert(rootdir, "expected root dir")
  assert(timestamp, "expected timestamp")
  if current then
    M.close(timestamp)
  end

  rootdir = paths.canonical(rootdir)
  local workspace = get_workspace(rootdir)
  if vim.fn.isdirectory(workspace.datadir()) <= 0 then
    notify.error('No workspace to open at "' .. rootdir .. '"')
    return nil
  end

  tables.merge(files.read_json(workspace.metafile()) or {}, workspace)

  -- set current *before* running hooks!
  current = workspace

  files.makedirs(workspace.datadir())
  files.makedirs(workspace.localdir())
  history.touch(rootdir, timestamp)
  run_hooks(useropts.on_open, workspace)
end

---@param timestamp integer epoch sec to record as last access time
function M.close(timestamp)
  assert(timestamp, "expected timestamp")
  if not current then
    return
  end

  files.makedirs(current.datadir())
  files.makedirs(current.localdir())
  history.touch(current.rootdir(), timestamp)
  run_hooks(useropts.on_close, current)

  -- unset current only *after* running hooks!
  current = nil
end

---@return boolean is_open if a workspace is currently open or not
function M.is_open()
  return current ~= nil
end

---@return workspace? wksp current workspace if extant
function M.current()
  return current
end

---@return string? dir root dir of currently open workspace
function M.root_dir()
  if not current then
    return nil
  end
  return current.rootdir()
end

---@return string? datadir workspace data dir
function M.data_dir()
  if not current then
    return nil
  end
  return current.datadir()
end

---@return string? localdir workspace local dir
function M.local_dir()
  if not current then
    return nil
  end
  return current.localdir()
end

---@param rootdir string path to root of workspace
---@return boolean is_workspace true if is root dir of a workspace
function M.is_workspace(rootdir)
  assert(type(rootdir) == "string", "workspace path must be of type string")
  local info = get_workspace(rootdir)
  return vim.fn.isdirectory(info.datadir()) == 1
end

---@param rootdir? string path to root of workspace
---@return workspace? workspace info
function M.read_metadata(rootdir)
  local workspace = rootdir and get_workspace(rootdir) or current
  if not workspace then
    return nil
  end

  workspace = vim.deepcopy(workspace)
  tables.merge(files.read_json(workspace.metafile()) or {}, workspace)

  return workspace
end

---@param workspace? workspace workspace info
function M.write_metadata(workspace)
  local workspace = workspace or current
  assert(workspace, "expected root dir or already-opened root dir")
  local meta = files.read_json(workspace.metafile()) or {}
  meta.name = workspace.name or meta.name
  meta.created = workspace.created or meta.created
  files.write_json(workspace.metafile(), meta)
end

return M
