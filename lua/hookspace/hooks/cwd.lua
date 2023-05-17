local module = {}

local default_opts = {}
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

local old_global_cwd = nil

function module.setup(opts)
  ---@diagnostic disable-next-line: unused-local
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function module.on_open(workspace)
  old_global_cwd = vim.fn.getcwd(-1, -1)
  vim.api.nvim_set_current_dir(workspace.rootdir)
end

---@diagnostic disable-next-line: unused-local
function module.on_close(workspace)
  vim.api.nvim_set_current_dir(old_global_cwd or "~")
  old_global_cwd = nil
end

return module
