local modulename, _ = ...
local os = require('os')

local history = require(modulename .. '.history')
local state = require(modulename .. '.state')
local paths = require(modulename .. '.path')
local notify = require(modulename .. '.notify')
local workspaces = require(modulename .. '.workspace')

local M = {}

--- Check if a workspace is currently open
-- @return `true` if a workspace is open
function M.is_open()
  return workspaces.is_open()
end

--- Open a workspace
-- Any currently open workspace will be closed.
-- @param path directory of the workspace to open
function M.open(path)
  if not path or not workspaces.contains_workspace(path) then
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
function M.close()
  if workspaces.is_open() then
    workspaces.close(os.time())
  end
end

--- Create a new workspace at the given path
-- If present, an already-extant workspace will be overwrittten.
-- @param path directory of workspace
-- @param user_data initial value of user data (optional)
function M.create(path, user_data)
  assert(type(path) == 'string', 'workspace path must be of type string')
  user_data = user_data or {}
  workspaces.create(path, user_data, os.time())
end

--- Delete a workspace from the given directory
-- @param path directory containing workspace
function M.delete(path)
  assert(type(path) == 'string', 'workspace path must be of type string')
  workspaces.delete(path)
end

--- Move a workspace from one directory to another
-- @param src current workspace directory
-- @param target new workspace directory
function M.move(src, target)
  workspaces.move(src, target)
end

--- Get the directory of the currently open workspace
-- @return path to directory of open workspace or `nil`
function M.get_current_workspace()
  return workspaces.get_current_root_dirpath()
end

--- Get history of recently-accessed workspaces
-- @return `table` containing workspace information
function M.get_history(sort_by)
  return history.get_entries(sort_by)
end

--- Get only still-valid history entries
-- @return `table` containing workspace information
function M.get_valid_history(sort_by)
  return history.get_valid_entries(sort_by)
end

--- Read metadata from a workspace
-- @param workspace path to workspace directory or `nil` for current workspace
-- @return metadata of workspace
function M.read_metadata(workspace)
  if not workspace and not state.current_root_dirpath then
    notify.error(
      'Cannot read metadata; no workspace specified '
        .. 'and no workspace is currently open.',
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
-- @param workspace path to workspace directory or `nil` for current workspace
-- @param metadata the metadata to write
function M.write_metadata(workspace, metadata)
  if not workspace and not state.current_root_dirpath then
    notify.error(
      'Cannot read metadata; no workspace specified '
        .. 'and no workspace is currently open.',
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
-- @param workspace path to workspace directory or `nil` for current workspace
-- @return user data of the workspace
function M.read_user_data(workspace)
  if not workspace and not state.current_root_dirpath then
    notify.error(
      'Cannot read user data; no workspace specified '
        .. 'and no workspace is currently open.',
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
-- @param workspace path to workspace directory or `nil` for current workspace
-- @param user_data the user data to write
function M.write_user_data(workspace, user_data)
  if not workspace and not state.current_root_dirpath then
    notify.error(
      'Cannot write user data; no workspace specified '
        .. 'and no workspace is currently open.',
      1
    )
    return {}
  end

  local root = state.current_root_dirpath
  if workspace then
    root = paths.canonical(workspace)
  end

  workspaces.write_user_data(root, user_data)
end

--- Check if the directory contains a workspace
-- @param path directory to check
-- @return `true` if a workspace is found
function M.contains_workspace(path)
  return type(path) == 'string' and workspaces.contains_workspace(path)
end

local function _history_complete(arg_lead, cmd_line, cursor_pos)
  local canonical_lead = paths.canonical(arg_lead)
  local filepaths = {}

  -- insert from history
  for _, v in ipairs(history.get_entries()) do
    local canonical_historical_filepath = paths.canonical(v.rootdir)
    vim.notify(canonical_historical_filepath .. ' vs ' .. canonical_lead)
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

--- Show telescope picker for history items
-- @param options for telescope
function M.picker(opts)
  local actions = require('telescope.actions')
  local actions_state = require('telescope.actions.state')
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config')

  opts = opts or {}

  local function to_display(entry)
    local hls = {}
    local display = entry.metadata.name
    if not display and entry.rootdir then
      display = paths.basename(entry.rootdir)
    end

    if entry.rootdir then
      local hl_start = #display + 1
      table.insert(hls, { { hl_start, hl_start + #entry.rootdir }, 'Comment' })
      display = display .. ' ' .. entry.rootdir
    end

    return display, hls
  end

  pickers
    .new(opts, {
      prompt_title = opts.title or state.plugin_name,
      finder = finders.new_table({
        results = history.get_valid_entries(),
        entry_maker = function(entry)
          if
            not entry
            or not entry.rootdir
            or vim.fn.isdirectory(entry.rootdir) < 1
          then
            return nil
          end
          local metadata = workspaces.read_metadata(entry.rootdir) or {}
          return {
            value = entry.rootdir,
            metadata = metadata,
            display = to_display,
            ordinal = metadata.name
              or paths.basename(entry.rootdir)
              or tostring(entry.last_accessed or 0),
            rootdir = entry.rootdir,
          }
        end,
      }),
      sorter = conf.values.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        map('i', '<c-space>', actions.to_fuzzy_refine)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = actions_state.get_selected_entry()
          if selection and selection.rootdir then
            if workspaces.is_open() then
              workspaces.close(os.time())
            end
            workspaces.open(selection.rootdir, os.time())
          end
        end)
        return true
      end,
    })
    :find()
end

function M.setup(opts)
  if opts.verbose ~= nil and type(opts.verbose) == 'number' then
    state.verbose = opts.verbose
  end

  state.on_create = opts.on_create or state.on_create
  state.on_delete = opts.on_delete or state.on_delete
  state.on_open = opts.on_open or state.on_open
  state.on_close = opts.on_close or state.on_close

  vim.api.nvim_create_user_command('HookspaceCreate', function(tbl)
    if tbl and tbl.fargs then
      for _, rootdir in ipairs(tbl.fargs) do
        M.create(rootdir)
      end
    end
  end, {
    desc = 'create a new workspace',
    force = true,
    nargs = 1,
    complete = 'file',
  })
  vim.api.nvim_create_user_command('HookspaceDelete', function(tbl)
    if tbl and tbl.fargs then
      for _, rootdir in ipairs(tbl.fargs) do
        M.delete(rootdir)
      end
    end
  end, {
    desc = 'delete a workspace',
    force = true,
    nargs = 1,
    complete = _history_complete,
  })
  vim.api.nvim_create_user_command('HookspaceList', function(tbl)
    local simplified = {}
    for _, v in pairs(history.get_entries()) do
      table.insert(simplified, v.rootdir)
    end
    print(vim.inspect(simplified))
  end, {
    desc = 'list all workspaces in history',
    force = true,
    nargs = 0,
  })
  vim.api.nvim_create_user_command('HookspaceOpen', function(tbl)
    if tbl and tbl.fargs then
      for _, rootdir in ipairs(tbl.fargs) do
        M.open(rootdir)
        break
      end
    end
  end, {
    desc = 'open a workspace',
    force = true,
    nargs = 1,
    complete = 'file',
  })
  vim.api.nvim_create_user_command('HookspaceClose', function(tbl)
    M.close()
  end, {
    desc = 'close the currently open workspace',
    force = true,
    nargs = 0,
  })
  vim.api.nvim_create_user_command('HookspaceInfo', function(tbl)
    local current_workspace = workspaces.get_current_root_dirpath()
    if current_workspace then
      local metadata = workspaces.read_metadata(current_workspace)
      local info = vim.tbl_deep_extend('keep', {
        path = current_workspace,
      }, metadata)
      for k, v in pairs(info) do
        if k:match('^__') then
          info[k] = nil
        end
      end
      print('Current workspace: ' .. vim.inspect(info))
    else
      print('No workspace is loaded')
    end
  end, {
    desc = 'show workspace info',
    force = true,
    nargs = 0,
  })
  vim.api.nvim_create_user_command('HookspaceRename', function(tbl)
    local rootdir = workspaces.get_current_root_dirpath()
    if tbl and tbl.args and rootdir then
      local metadata = workspaces.read_metadata(rootdir)
      metadata.name = vim.fn.trim(tbl.args)
      workspaces.write_metadata(rootdir, metadata)
    end
  end, {
    desc = 'rename workspace',
    force = true,
    nargs = 1,
  })
  vim.api.nvim_create_user_command('HookspacePicker', function(tbl)
    M.picker()
  end, {
    desc = 'show workspace picker',
    force = true,
  })

  vim.api.nvim_create_augroup('hookspace', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
    group = 'hookspace',
    callback = function(tbl)
      M.close()
    end,
    desc = 'automatically close hookspace when exiting app',
  })
end

return M
