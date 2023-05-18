---@meta _

---@class workspace
---@field rootdir string root dir of workspace
---@field datadir string where global workspace-specific files are stored
---@field localdir string where local workspace-specific data files are be stored

---@alias hook fun(workspace: workspace): nil|boolean

---@class useropts
---@field verbose integer from 0..
---@field on_init nil|hook|hook[]
---@field on_open nil|hook|hook[]
---@field on_close nil|hook|hook[]

---@class record
---@field name string workspace display name
---@field last_accessed integer timestamp of last access
---@field rootdir string path to workspace root dir
---@field datadir string path to workspace data dir
