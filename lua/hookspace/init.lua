local M = {}

local pl = require("plenary")

local arrays = require("hookspace.luamisc.arrays")
local paths = require("hookspace.luamisc.paths")
local tables = require("hookspace.luamisc.tables")

local history = require("hookspace.history")
local useropts = require("hookspace.useropts")
local notify = require("hookspace.notify")
local workspaces = require("hookspace.workspaces")

local default_opts = vim.deepcopy(useropts)

--- Check if a workspace is currently open
--- @return boolean is_open if a workspace is open
function M.is_open()
  return workspaces.is_open()
end

--- Open a workspace
--- Any currently open workspace will be closed.
--- @param path string directory of the workspace to open
function M.open(path)
  if not path or not workspaces.is_workspace(path) then
    notify.error('Cannot open non-existent workspace at "' .. path .. '".')
    return false
  end
  workspaces.open(path, os.time())
  return true
end

--- Close the currently open workspace, if open.
function M.close()
  workspaces.close(os.time())
end

--- Create a new workspace at the given path
--- If present, an already-extant workspace will be overwrittten.
--- @param path string directory of workspace
function M.init(path)
  assert(type(path) == "string", "workspace path must be of type string")
  workspaces.init(path, os.time())
end

--- Get history of recently-accessed workspaces
--- @return record[] records containing workspace information
function M.history()
  return history.read_records()
end

--- Get workspace info
--- @param rootdir? string path to workspace or default for current
--- @return workspace? wksp workspace info
function M.info(rootdir)
  if not rootdir then
    return workspaces.current()
  end
  return workspaces.read_metadata(rootdir)
end


--- Copy config files from workspace to local dir
---@param rootdir? string path to workspace or default for current
function M.install(rootdir)
  local meta = workspaces.read_metadata(rootdir)
  if meta.datadir() and vim.fn.isdirectory(meta.datadir()) > 0 then
    local files = pl.scandir.scan_dir(meta.datadir(), {
      hidden = false,
      add_dirs = false,
      respect_gitignore = false,
      silent = true,
    })

    for _, filename in ipairs(files) do
      local relname = paths.relpath(filename, meta.datadir())
      vim.loop.fs_copyfile(filename, meta.localdir() .. "/" .. relname)
    end
  end
end

--- Check if the directory contains a workspace
--- @param path string directory to check
--- @return boolean is_found if a workspace is found
function M.is_workspace(path)
  return type(path) == "string" and workspaces.is_workspace(path)
end

---@param rootdir? string nil for currently-open workspace
---@param name string new workspace name
function M.rename(rootdir, name)
  name = name and vim.fn.trim(name)
  if not name or #name <= 0 then
    notify.error("Expected new workspace name to be provided.")
    return
  end

  local workspace = workspaces.read_metadata(rootdir)
  if not workspace then
    notify.error("Workspace not found.")
    return
  end

  workspace.name = name
  workspaces.write_metadata(workspace)
end

local function init_commands()
  vim.api.nvim_create_user_command("HookspaceInit", function(tbl)
    if tbl and tbl.fargs then
      for _, rootdir in ipairs(tbl.fargs) do
        M.init(rootdir)
        break
      end
    end
  end, {
    desc = "initialize a new workspace",
    force = true,
    nargs = 1,
    complete = "file",
  })

  vim.api.nvim_create_user_command("HookspaceInstall", function(tbl)
    local rootdirs = {}

    local rootdir = workspaces.root_dir()
    if rootdir then
      table.insert(rootdirs, rootdir)
    end

    if tbl and tbl.fargs then
      vim.list_extend(rootdirs, tbl.fargs)
    end

    for _, rootdir in ipairs(rootdirs) do
      M.install(rootdir)
    end
  end, {
    desc = "copy config files from repo into local dir",
    force = true,
    nargs = "*",
    complete = "file",
  })

  vim.api.nvim_create_user_command("HookspaceList", function(_)
    local rootdirs = M.history()
    arrays.transform(rootdirs, function(o)
      return o.rootdir()
    end)
    print(vim.inspect(rootdirs))
  end, {
    desc = "list all workspaces in history",
    force = true,
    nargs = 0,
  })

  vim.api.nvim_create_user_command("HookspaceOpen", function(tbl)
    if tbl and tbl.fargs then
      for _, rootdir in ipairs(tbl.fargs) do
        if rootdir then
          M.open(rootdir)
          break
        end
      end
    end
  end, {
    desc = "open a workspace",
    force = true,
    nargs = 1,
    complete = "file",
  })

  vim.api.nvim_create_user_command("HookspaceClose", function(_)
    M.close()
  end, {
    desc = "close a workspace",
    force = true,
    nargs = 0,
  })

  vim.api.nvim_create_user_command("HookspaceInfo", function(_)
    local rootdir = workspaces.root_dir()
    if not rootdir then
      print("No workspace open")
      return
    end

    local metadata = workspaces.read_metadata(rootdir)
    tables.transform(metadata, function(val)
      if type(val) == "function" then
        val = val()
      end
      return val
    end)
    print(vim.inspect(metadata))
  end, {
    desc = "show workspace info",
    force = true,
    nargs = 0,
  })

  vim.api.nvim_create_user_command("HookspaceRename", function(tbl)
    local rootdir = workspaces.root_dir()
    if tbl and tbl.args and rootdir then
      local name = table.concat(tbl.args, " ")
      M.rename(rootdir, name)
    end
  end, {
    desc = "rename workspace",
    force = true,
    nargs = 1,
  })
end

local function init_autocmds()
  vim.api.nvim_create_augroup("hookspace", { clear = true })

  vim.api.nvim_create_autocmd({ "VimEnter" }, {
    group = "hookspace",
    once = true,
    desc = "open hookspace workspace from cwd",
    callback = function()
      if useropts.autoload and vim.fn.argc() <= 0 then
        local cwd = vim.loop.cwd()
        if cwd and workspaces.is_workspace(cwd) then
          M.open(cwd)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = "hookspace",
    callback = function(_)
      M.close()
    end,
    desc = "automatically close hookspace when exiting app",
  })
end

--- Prepare hookspace for use
---@param opts useropts options
function M.setup(opts)
  if opts.verbose ~= nil and type(opts.verbose) == "number" then
    useropts.verbose = opts.verbose
  end

  tables.overwrite(default_opts, useropts)
  tables.merge(opts, useropts)

  init_commands()
  init_autocmds()
end

return M
