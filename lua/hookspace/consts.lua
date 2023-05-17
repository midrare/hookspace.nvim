local M = {}

local sep = vim.fn.has('win32') > 0 and '\\' or '/'

M.plugin = "hookspace"
M.plugindir = vim.fn.stdpath("data") .. sep .. "hookspace"

M.data_dirname = ".hookspace"
M.metadata_filename = "workspace.json"

return M
