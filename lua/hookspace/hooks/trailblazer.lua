local M = {}

local default_opts = {}
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

function M.setup(opts)
  ---@diagnostic disable-next-line: unused-local
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function M.on_open(workspace)
  local is_ok, trailblazer = pcall(require, "trailblazer")
  if is_ok and trailblazer then
    pcall(
      trailblazer.load_trailblazer_state_from_file,
      workspace.localdir .. "/trailblazer"
    )
  end
end

function M.on_close(workspace)
  local is_ok, trailblazer = pcall(require, "trailblazer")
  if is_ok and trailblazer then
    trailblazer.save_trailblazer_state_to_file(
      workspace.localdir .. "/trailblazer"
    )
  end
end

return M
