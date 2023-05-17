local M = {}

local sep = vim.fn.has('win32') > 0 and '\\' or '/'

M.plugin = "hookspace"
M.plugin_dir = vim.fn.stdpath("data") .. sep .. "hookspace"

M.workspace_dirname = ".hookspace"
M.metadata_filename = "workspace.json"

return M
