local M = {}

local old_global_cwd = nil

function M.on_open(workspace_info, user_data)
  old_global_cwd = vim.fn.getcwd(-1, -1)
  vim.api.nvim_set_current_dir(workspace_info.rootdir)
end

function M.on_close(workspace_info, user_data)
  if old_global_cwd then
    vim.api.nvim_set_current_dir(old_global_cwd)
    old_global_cwd = nil
  end
end

return M
