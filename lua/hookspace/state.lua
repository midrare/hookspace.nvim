local modulename, _ = ...
local moduleroot = modulename:gsub("(.+)%..+", "%1")

local paths = require(moduleroot .. ".paths")

local module = {}

module.plugin_name = "hookspace"
module.plugin_datadir = vim.fn.stdpath("data") .. paths.sep() .. "hookspace"
module.data_dirname = ".hookspace"
module.metadata_filename = "workspace.json"
module.user_data_filename = "userdata.json"

module.verbose = 1

module.on_init = {}
module.on_open = {}
module.on_close = {}

module.current_rootdir = nil

return module
