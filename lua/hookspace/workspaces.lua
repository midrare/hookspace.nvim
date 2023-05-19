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

---@type workspace?
local current = nil

local function get_file_uid(filename)
  if vim.fn.filereadable(filename) <= 0 then
    return nil
  end
  local n = files.inode(filename)
    or files.file_id(filename)
    or files.created(filename)
    or files.modified(filename)
  return (n and strings.itoa(n)) or nil
end

local function get_workspace_paths(rootdir, create)
  create = create ~= false
  rootdir = paths.canonical(rootdir)
  local stamp = rootdir
    .. paths.sep()
    .. consts.subdir
    .. paths.sep()
    .. ".instance"

  if create and vim.fn.filereadable(stamp) <= 0 then
    files.write_file(stamp)
  end

  local master = {
    rootdir = rootdir,
    datadir = rootdir
      .. paths.sep()
      .. consts.subdir,
    localdir = nil,
    metafile = rootdir
      .. paths.sep()
      .. consts.subdir
      .. paths.sep()
      .. consts.metafile,
  }

  local workpaths = {
    rootdir = function()
      return master.rootdir
    end,
    datadir = function()
      return master.datadir
    end,
    metafile = function()
      return master.metafile
    end,
    localdir = function()
      if master.localdir then
        return master.localdir
      end
      local instance = get_file_uid(stamp)
      if not instance then
        return nil
      end
      master.localdir = consts.datadir .. paths.sep() .. instance .. ".wkspc"
      return master.localdir
    end
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
  rootdir = paths.canonical(rootdir)

  local workpaths = get_workspace_paths(rootdir, true)

  local metadata = M.read_metadata(rootdir) or {}
  metadata.name = metadata.name or paths.basename(rootdir) or "Unnamed"
  metadata.created = metadata.created or timestamp

  files.write_json(workpaths.metafile(), metadata)
  files.write_file(workpaths.datadir() .. paths.sep() .. ".notags")
  files.write_file(workpaths.datadir() .. paths.sep() .. ".ignore", "*")
  files.write_file(workpaths.datadir() .. paths.sep() .. ".tokeignore", "*")

  update_ignorefile(
    workpaths.datadir() .. paths.sep() .. ".gitignore",
    {"/.instance"}
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
  assert(not current, "another workspace is already open")

  rootdir = paths.canonical(rootdir)
  local workspace = get_workspace_paths(rootdir)
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
  assert(current, "cannot close non-open workspace")

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
  local info = get_workspace_paths(rootdir)
  return vim.fn.isdirectory(info.datadir()) == 1
end

---@param rootdir? string path to root of workspace
---@return workspace? workspace info
function M.read_metadata(rootdir)
  local workspace = rootdir and get_workspace_paths(rootdir) or current
  if not workspace then
    return nil
  end

  workspace = vim.deepcopy(workspace)
  tables.merge(files.read_json(workspace.metafile()) or {}, workspace)

  return workspace
end

---@param workspace? workspace workspace info
function M.write_metadata(workspace)
  workspace = workspace or current
  assert(workspace, "expected root dir or already-opened root dir")
  local meta = { name = workspace.name, created = workspace.created }
  files.write_json(workspace.metafile(), meta)
end

return M
