local M = {}

local arrays = require("hookspace.luamisc.arrays")
local paths = require("hookspace.luamisc.paths")
local history = require("hookspace.history")
local useropts = require("hookspace.useropts")
local notify = require("hookspace.notify")
local workspaces = require("hookspace.workspaces")

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
  if workspaces.is_open() then
    workspaces.close(os.time())
  end
  workspaces.open(path, os.time())
  return true
end

--- Close the currently open workspace, if open.
function M.close()
  if workspaces.is_open() then
    workspaces.close(os.time())
  end
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
  rootdir = rootdir and paths.canonical(rootdir) or nil
  return workspaces.read_metadata(rootdir)
end

--- Write metadata for a workspace
--- @param rootdir string path to workspace directory or `nil` for current workspace
--- @param workspace workspace the metadata to write
function M.write_metadata(rootdir, workspace)
  rootdir = rootdir and paths.canonical(rootdir) or nil
  workspaces.write_metadata(rootdir, workspace)
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

  local metadata = workspaces.read_metadata(rootdir)
  if not metadata then
    notify.error("Workspace not found.")
    return
  end

  metadata.name = name
  workspaces.write_metadata(rootdir, metadata)
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
  print(vim.inspect(metadata))
end

local function _cmd_rename(tbl)
  local rootdir = workspaces.root_dir()
  if tbl and tbl.args and rootdir then
    local name = table.concat(tbl.args, " ")
    M.rename(rootdir, name)
  end
end

--- Prepare hookspace for use
---@param opts useropts options
function M.setup(opts)
  if opts.verbose ~= nil and type(opts.verbose) == "number" then
    useropts.verbose = opts.verbose
  end

  useropts.on_init = opts.on_init or useropts.on_init
  useropts.on_open = opts.on_open or useropts.on_open
  useropts.on_close = opts.on_close or useropts.on_close

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
      return o.rootdir
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
    desc = "close the currently open workspace",
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

  vim.api.nvim_create_augroup("hookspace", { clear = true })
  vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = "hookspace",
    callback = function(_)
      M.close()
    end,
    desc = "automatically close hookspace when exiting app",
  })
end

return M
