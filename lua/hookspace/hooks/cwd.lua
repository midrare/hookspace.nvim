local M = {}

local default_opts = {}
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

local old_cwd = nil

function M.setup(opts)
  ---@diagnostic disable-next-line: unused-local
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function M.on_open(workspace)
  old_cwd = vim.fn.getcwd(-1, -1)
  vim.api.nvim_set_current_dir(workspace.rootdir())
end

---@diagnostic disable-next-line: unused-local
function M.on_close(workspace)
  vim.api.nvim_set_current_dir(old_cwd or "~")
  old_cwd = nil
end

return M
