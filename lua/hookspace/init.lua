local M = {}

local os = require("os")
local arrays = require('hookspace.luamisc.arrays')
local paths = require('hookspace.luamisc.paths')
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
  return workspaces.get_root_dir()
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
      end
    end
  end, {
    desc = "initialize a new workspace",
    force = true,
    nargs = 1,
    complete = "file",
  })
  vim.api.nvim_create_user_command("HookspaceList", function(tbl)
    local rootdirs = M.read_history()
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
  vim.api.nvim_create_user_command("HookspaceClose", function(tbl)
    M.close()
  end, {
    desc = "close the currently open workspace",
    force = true,
    nargs = 0,
  })
  vim.api.nvim_create_user_command("HookspaceInfo", function(tbl)
    local current_workspace = workspaces.get_root_dir()
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
    local rootdir = workspaces.get_root_dir()
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
      M.close()
    end,
    desc = "automatically close hookspace when exiting app",
  })
end

return M
