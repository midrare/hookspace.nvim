local M = {}

local sep = vim.fn.has("win32") > 0 and "\\" or "/"

M.plugin_name = "hookspace"
M.plugin_datadir = vim.fn.stdpath("data") .. sep .. "hookspace"
M.plugin_history = vim.fn.stdpath("data")
  .. sep
  .. "hookspace"
  .. sep
  .. "workspaces.json"

M.datadir_name = ".hookspace"
M.metafile_name = "workspace.json"
M.localid_name = ".identifier"

return M
