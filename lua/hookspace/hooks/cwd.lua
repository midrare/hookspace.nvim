local module = {}

local default_opts = {}
local user_opts = vim.tbl_deep_extend("force", {}, default_opts)

local old_global_cwd = nil

function module.setup(opts)
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function module.on_open(workspace, user_data)
  old_global_cwd = vim.fn.getcwd(-1, -1)
  vim.api.nvim_set_current_dir(workspace.rootdir)
end

function module.on_close(workspace, user_data)
  vim.api.nvim_set_current_dir(old_global_cwd or '~')
  old_global_cwd = nil
end

return module
