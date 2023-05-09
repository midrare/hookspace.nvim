local module = {}

local old_global_cwd = nil

function module.on_open(workspace, user_data)
  old_global_cwd = vim.fn.getcwd(-1, -1)
  vim.api.nvim_set_current_dir(workspace.rootdir)
end

function module.on_close(workspace, user_data)
  vim.api.nvim_set_current_dir(old_global_cwd or '~')
  old_global_cwd = nil
end

return module
