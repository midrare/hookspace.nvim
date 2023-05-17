local module = {}

local os = require("os")
local arrays = require('hookspace.luamisc.arrays')
local paths = require('hookspace.luamisc.paths')
local history = require("hookspace.history")
local state = require("hookspace.state")
local notify = require("hookspace.notify")
local workspaces = require("hookspace.workspaces")


--- Check if a workspace is currently open
--- @return boolean is_open if a workspace is open
function module.is_open()
  return workspaces.is_open()
end

--- Open a workspace
--- Any currently open workspace will be closed.
--- @param path string directory of the workspace to open
function module.open(path)
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
function module.close()
  if workspaces.is_open() then
    workspaces.close(os.time())
  end
end

--- Create a new workspace at the given path
--- If present, an already-extant workspace will be overwrittten.
--- @param path string directory of workspace
function module.init(path)
  assert(type(path) == "string", "workspace path must be of type string")
  workspaces.init(path, os.time())
end


--- Move a workspace from one directory to another
--- @param src string current workspace directory
--- @param target string new workspace directory
function module.move(src, target)
  workspaces.move(src, target)
end

--- Get the directory of the currently open workspace
--- @return string? path to directory of open workspace or `nil`
function module.get_current_workspace()
  return workspaces.get_current_root_dir()
end

--- Get history of recently-accessed workspaces
--- @return record[] records containing workspace information
function module.read_history()
  return history.read_records()
end

--- Read metadata from a workspace
--- @param rootdir string path to workspace directory or `nil` for current workspace
--- @return workspace? metadata workspace info
function module.read_metadata(rootdir)
  rootdir = rootdir or state.current_rootdir
  rootdir = paths.canonical(rootdir)
  return workspaces.read_metadata(rootdir)
end

--- Write metadata for a workspace
--- @param rootdir string path to workspace directory or `nil` for current workspace
--- @param workspace workspace the metadata to write
function module.write_metadata(rootdir, workspace)
  rootdir = rootdir or state.current_rootdir
  rootdir = paths.canonical(rootdir)
  workspaces.write_metadata(rootdir, workspace)
end

--- Check if the directory contains a workspace
--- @param path string directory to check
--- @return boolean is_found if a workspace is found
function module.is_workspace(path)
  return type(path) == "string" and workspaces.is_workspace(path)
end


--- Prepare hookspace for use
---@param opts useropts options
function module.setup(opts)
  if opts.verbose ~= nil and type(opts.verbose) == "number" then
    state.verbose = opts.verbose
  end

  state.on_init = opts.on_init or state.on_init
  state.on_open = opts.on_open or state.on_open
  state.on_close = opts.on_close or state.on_close

  vim.api.nvim_create_user_command("HookspaceInit", function(tbl)
    if tbl and tbl.fargs then
      for _, rootdir in ipairs(tbl.fargs) do
        module.init(rootdir)
      end
    end
  end, {
    desc = "initialize a new workspace",
    force = true,
    nargs = 1,
    complete = "file",
  })
  vim.api.nvim_create_user_command("HookspaceList", function(tbl)
    local rootdirs = module.read_history()
    arrays.transform(rootdirs, function(o) return o.rootdir end)
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
          module.open(rootdir)
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
  vim.api.nvim_create_user_command("HookspaceClose", function(tbl)
    module.close()
  end, {
    desc = "close the currently open workspace",
    force = true,
    nargs = 0,
  })
  vim.api.nvim_create_user_command("HookspaceInfo", function(tbl)
    local current_workspace = workspaces.get_current_root_dir()
    if current_workspace then
      local metadata = workspaces.read_metadata(current_workspace)
      local info = vim.tbl_deep_extend("keep", {
        path = current_workspace,
      }, metadata)
      for k, _ in pairs(info) do
        if k:match("^__") then
          info[k] = nil
        end
      end
      print("Current workspace: " .. vim.inspect(info))
    else
      print("No workspace is loaded")
    end
  end, {
    desc = "show workspace info",
    force = true,
    nargs = 0,
  })
  vim.api.nvim_create_user_command("HookspaceRename", function(tbl)
    local rootdir = workspaces.get_current_root_dir()
    if tbl and tbl.args and rootdir then
      local metadata = workspaces.read_metadata(rootdir)
      metadata.name = vim.fn.trim(tbl.args)
      workspaces.write_metadata(rootdir, metadata)
    end
  end, {
    desc = "rename workspace",
    force = true,
    nargs = 1,
  })
  vim.api.nvim_create_augroup("hookspace", { clear = true })
  vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
    group = "hookspace",
    callback = function(tbl)
      module.close()
    end,
    desc = "automatically close hookspace when exiting app",
  })
end

return module
