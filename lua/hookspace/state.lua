local modulename, _ = ...
local moduleroot = modulename:gsub('(.+)%..+', '%1')

local paths = require(moduleroot .. '.path')

local M = {}

M.plugin_name = 'hookspace'
M.plugin_datadir = vim.fn.stdpath('data') .. paths.sep() .. 'hookspace'
M.data_dirname = '.hookspace'
M.metadata_filename = 'workspace.json'
M.user_data_filename = 'userdata.json'

M.verbose = 1

M.on_create = {}
M.on_delete = {}
M.on_open = {}
M.on_close = {}

M.current_root_dirpath = nil

return M
