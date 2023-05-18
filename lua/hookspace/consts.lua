local M = {}

local sep = vim.fn.has("win32") > 0 and "\\" or "/"

M.plugin = "hookspace"
M.datadir = vim.fn.stdpath("data") .. sep .. "hookspace"
M.historyfile = vim.fn.stdpath("data") .. sep .. "hookspace" .. sep .. "workspaces.json"

M.subdir = ".hookspace"
M.metafile = "workspace.json"

return M
