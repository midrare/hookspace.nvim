local M = {}

local arrays = require("hookspace.luamisc.arrays")
local files = require("hookspace.luamisc.files")
local paths = require("hookspace.luamisc.paths")
local strings = require("hookspace.luamisc.strings")
local history = require("hookspace.history")
local notify = require("hookspace.notify")
local consts = require("hookspace.consts")
local useropts = require("hookspace.useropts")

local current_rootdir = nil
local workspace_id_len = 16

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

local function set_lazy_attrs(tbl, attrs)
  return setmetatable(tbl, {
    __index = function(e, key)
      local raw = rawget(e, key)
      if raw ~= nil then
        return raw
      end

      local f = rawget(attrs, key)
      if f then
        local value = f(e)
        rawset(e, key, value)
        return value
      end

      return nil
    end,
  })
end

local function get_workspace_paths(rootdir, create)
  create = create ~= false
  local stamp = rootdir
    .. paths.sep()
    .. consts.subdir
    .. paths.sep()
    .. ".instance"

  if create and vim.fn.filereadable(stamp) <= 0 then
    files.write_file(stamp)
  end

  local workpaths = {
    rootdir = rootdir,
    globaldir = rootdir .. paths.sep() .. consts.subdir,
    localdir = nil,
    metafile = rootdir
      .. paths.sep()
      .. consts.subdir
      .. paths.sep()
      .. consts.metafile,
  }

  set_lazy_attrs(workpaths, {
    localdir = function()
      local instance = get_file_uid(stamp)
      if not instance then
        return nil
      end
      return consts.datadir
        .. paths.sep()
        .. instance .. ".wkspc"
    end
  })

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

  files.write_json(workpaths.metafile, metadata)
  files.write_file(workpaths.globaldir .. paths.sep() .. ".notags")
  files.write_file(workpaths.globaldir .. paths.sep() .. ".ignore", "*")
  files.write_file(workpaths.globaldir .. paths.sep() .. ".tokeignore", "*")

  update_ignorefile(
    workpaths.globaldir .. paths.sep() .. ".gitignore",
    {".instance"}
  )

  files.makedirs(workpaths.globaldir)
  files.makedirs(workpaths.localdir)
  run_hooks(useropts.on_init, workpaths)
  history.update_timestamp(rootdir, timestamp)
end

---@param rootdir string path to root of workspace
---@param timestamp integer epoch sec to record as last access time
function M.open(rootdir, timestamp)
  assert(rootdir, "expected root dir")
  assert(timestamp, "expected timestamp")
  assert(not current_rootdir, "another workspace is already open")

  rootdir = paths.canonical(rootdir)
  local workpaths = get_workspace_paths(rootdir)
  if vim.fn.isdirectory(workpaths.globaldir) <= 0 then
    notify.error('Failed to open non-existent "' .. rootdir .. '"')
    return nil
  end

  files.makedirs(workpaths.globaldir)
  files.makedirs(workpaths.localdir)
  run_hooks(useropts.on_open, workpaths)
  current_rootdir = rootdir
  history.update_timestamp(rootdir, timestamp)
end

---@param timestamp integer epoch sec to record as last access time
function M.close(timestamp)
  assert(timestamp, "expected timestamp")
  assert(current_rootdir, "cannot close non-open workspace")

  local workpaths = get_workspace_paths(current_rootdir)

  files.makedirs(workpaths.globaldir)
  files.makedirs(workpaths.localdir)
  run_hooks(useropts.on_close, workpaths)
  history.update_timestamp(current_rootdir, timestamp)
  current_rootdir = nil
end

---@return boolean is_open if a workspace is currently open or not
function M.is_open()
  return current_rootdir ~= nil
end

---@return string? dir root dir of currently open workspace
function M.root_dir()
  return current_rootdir
end

---@param rootdir? string workspace root dir
---@return string? globaldir workspace global dir
function M.global_dir(rootdir)
  rootdir = rootdir or current_rootdir
  if not rootdir then
    return nil
  end
  return get_workspace_paths(rootdir).globaldir
end

function M.local_dir(rootdir)
  rootdir = rootdir or current_rootdir
  if not rootdir then
    return nil
  end
  return get_workspace_paths(rootdir).localdir
end

---@param rootdir string path to root of workspace
---@return boolean is_workspace true if is root dir of a workspace
function M.is_workspace(rootdir)
  assert(type(rootdir) == "string", "workspace path must be of type string")
  local info = get_workspace_paths(rootdir)
  return vim.fn.isdirectory(info.globaldir) == 1
end

---@param rootdir? string path to root of workspace
---@param create? boolean false if missing values should not be generated
---@return workspace? workspace info
function M.read_metadata(rootdir, create)
  create = create ~= false
  rootdir = rootdir or current_rootdir
  if not rootdir then
    return nil
  end

  local workpaths = get_workspace_paths(rootdir, create)
  local meta = files.read_json(workpaths.metafile) or {}
  if create and not meta.id then
    meta.id = strings.random(workspace_id_len)
    files.write_json(workpaths.metafile, meta)
  end

  return meta
end

---@param rootdir? string path to root of workspace
---@param metadata workspace workspace info
function M.write_metadata(rootdir, metadata)
  rootdir = rootdir or current_rootdir
  assert(rootdir, "expected root dir or already-opened root dir")
  local info = get_workspace_paths(rootdir)
  files.write_json(info.metafile, metadata)
end

return M
