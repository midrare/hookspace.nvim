local modulename, _ = ...
local os = require("os")

local history = require(modulename .. ".history")
local state = require(modulename .. ".state")
local paths = require(modulename .. ".path")
local notify = require(modulename .. ".notify")
local sorting = require(modulename .. ".sorting")
local workspaces = require(modulename .. ".workspace")

local module = {}

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

--- Close the currently open workspace, if extant.
function module.close()
  if workspaces.is_open() then
    workspaces.close(os.time())
  end
end

--- Create a new workspace at the given path
--- If present, an already-extant workspace will be overwrittten.
--- @param path string directory of workspace
--- @param userdata? HookspaceUserData initial value of user data (optional)
function module.init(path, userdata)
  assert(type(path) == "string", "workspace path must be of type string")
  userdata = userdata or {}
  workspaces.init(path, userdata, os.time())
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
--- @return HookspaceRecord[] records containing workspace information
function module.read_history()
  local results = history.read_records()
  sorting.filter(results, function(r)
    return workspaces.is_workspace(r.rootdir)
  end)
  sorting.transform(results, function(r)
    local o = workspaces.read_metadata(r.rootdir)
    o.datadir = workspaces.get_data_dir(r.rootdir)
    o = vim.tbl_deep_extend("force", r, o)
    return o
  end)
  return results
end

--- Read metadata from a workspace
--- @param workspace string path to workspace directory or `nil` for current workspace
--- @return HookspaceWorkspace metadata workspace info
function module.read_metadata(workspace)
  if not workspace and not state.current_root_dirpath then
    notify.error(
      "Cannot read metadata; no workspace specified "
        .. "and no workspace is currently open.",
      1
    )
    return {}
  end

  local root = state.current_root_dirpath
  if workspace then
    root = paths.canonical(workspace)
  end

  return workspaces.read_metadata(root)
end

--- Write metadata for a workspace
--- @param workspace string path to workspace directory or `nil` for current workspace
--- @param metadata HookspaceWorkspace the metadata to write
function module.write_metadata(workspace, metadata)
  if not workspace and not state.current_root_dirpath then
    notify.error(
      "Cannot read metadata; no workspace specified "
        .. "and no workspace is currently open.",
      1
    )
    return {}
  end

  local root = state.current_root_dirpath
  if workspace then
    root = paths.canonical(workspace)
  end

  workspaces.write_metadata(root, metadata)
end

--- Read user data a workspace
--- @param workspace? string path to workspace directory or `nil` for current workspace
--- @return HookspaceUserData userdata user data of the workspace
function module.read_user_data(workspace)
  if not workspace and not state.current_root_dirpath then
    notify.error(
      "Cannot read user data; no workspace specified "
        .. "and no workspace is currently open.",
      1
    )
    return {}
  end

  local root = state.current_root_dirpath
  if workspace then
    root = paths.canonical(workspace)
  end

  return workspaces.read_user_data(root)
end

--- Write user data for a workspace
--- @param workspace? HookspaceWorkspace path to workspace directory or `nil` for current workspace
--- @param userdata HookspaceUserData the user data to write
function module.write_user_data(workspace, userdata)
  if not workspace and not state.current_root_dirpath then
    notify.error(
      "Cannot write user data; no workspace specified "
        .. "and no workspace is currently open.",
      1
    )
    return {}
  end

  local root = state.current_root_dirpath
  if workspace then
    root = paths.canonical(workspace)
  end

  workspaces.write_user_data(root, userdata)
end

--- Check if the directory contains a workspace
--- @param path string directory to check
--- @return boolean is_found if a workspace is found
function module.contains_workspace(path)
  return type(path) == "string" and workspaces.contains_workspace(path)
end

local function _history_complete(arg_lead, cmd_line, cursor_pos)
  local canonical_lead = paths.canonical(arg_lead)
  local filepaths = {}

  -- insert from history
  for _, v in ipairs(history.get_entries()) do
    local canonical_historical_filepath = paths.canonical(v.rootdir)
    vim.notify(canonical_historical_filepath .. " vs " .. canonical_lead)
    if vim.startswith(canonical_historical_filepath, canonical_lead) then
      table.insert(filepaths, v.rootdir)
    end
  end

  -- -- insert from filesystem
  -- if arg_lead and arg_lead:gsub("%s*", "") ~= "" then
  --   local glob = arg_lead:gsub("[\\/]+$", "") .. paths.sep() .. "*"
  --   for _, p in ipairs(vim.fn.glob(glob, false, true)) do
  --     table.insert(filepaths, p)
  --   end
  -- end

  return filepaths
end

--- Prepare hookspace for use
---@param opts HookspaceOptions options
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
    local simplified = {}
    for _, v in pairs(module.read_history()) do
      table.insert(simplified, v.rootdir)
    end
    print(vim.inspect(simplified))
  end, {
    desc = "list all workspaces in history",
    force = true,
    nargs = 0,
  })
  vim.api.nvim_create_user_command("HookspaceOpen", function(tbl)
    if tbl and tbl.fargs then
      for _, rootdir in ipairs(tbl.fargs) do
        module.open(rootdir)
        break
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
      for k, v in pairs(info) do
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
