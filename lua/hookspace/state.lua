local module = {}
module.name, _ = ...

local path_sep = vim.fn.has('win32') > 0 and '\\' or '/'

module.plugin_name = "hookspace"
module.plugin_datadir = vim.fn.stdpath("data") .. path_sep .. "hookspace"
module.data_dirname = ".hookspace"
module.metadata_filename = "workspace.json"
module.user_data_filename = "userdata.json"

module.verbose = 1

module.on_init = {}
module.on_open = {}
module.on_close = {}

module.current_rootdir = nil

return module
