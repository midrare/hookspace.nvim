-- TODO rename state module to useropts
local M = {}

local path_sep = vim.fn.has('win32') > 0 and '\\' or '/'

M.plugin_name = "hookspace"
M.plugin_datadir = vim.fn.stdpath("data") .. path_sep .. "hookspace"
M.data_dirname = ".hookspace"
M.metadata_filename = "workspace.json"

M.verbose = 1

M.on_init = {}
M.on_open = {}
M.on_close = {}

M.current_rootdir = nil

return M
