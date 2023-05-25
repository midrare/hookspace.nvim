local M = {}

local arrays = require("hookspace.luamisc.arrays")
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

--- Get the directory of the currently open workspace
--- @return string? path to directory of open workspace or `nil`
function M.get_current_workspace()
  return workspaces.root_dir()
end

--- Get history of recently-accessed workspaces
--- @return record[] records containing workspace information
function M.read_history()
  return history.read_records()
end

--- Read metadata from a workspace
--- @param rootdir string path to workspace directory or `nil` for current workspace
--- @return workspace? metadata workspace info
function M.read_metadata(rootdir)
  return workspaces.read_metadata(rootdir)
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

local function _cmd_open(tbl)
  if tbl and tbl.fargs then
    for _, rootdir in ipairs(tbl.fargs) do
      if rootdir then
        M.open(rootdir)
        break
      end
    end
  end
end

local function _cmd_show_info(_)
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
end

local function _cmd_rename(tbl)
  local rootdir = workspaces.root_dir()
  if tbl and tbl.args and rootdir then
    local name = table.concat(tbl.args, " ")
    M.rename(rootdir, name)
  end
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

  vim.api.nvim_create_user_command("HookspaceList", function(_)
    local rootdirs = M.read_history()
    arrays.transform(rootdirs, function(o)
      return o.rootdir()
    end)
    print(vim.inspect(rootdirs))
  end, {
    desc = "list all workspaces in history",
    force = true,
    nargs = 0,
  })

  vim.api.nvim_create_user_command("HookspaceOpen", _cmd_open, {
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

  vim.api.nvim_create_user_command("HookspaceInfo", _cmd_show_info, {
    desc = "show workspace info",
    force = true,
    nargs = 0,
  })

  vim.api.nvim_create_user_command("HookspaceRename", _cmd_rename, {
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
