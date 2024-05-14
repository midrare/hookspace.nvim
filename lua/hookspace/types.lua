---@meta _

---@class workspace
---@field name string display name for workspace
---@field created integer creation timestamp in epoch secs
---@field instance fun(): string instance id
---@field rootdir fun(): string root dir of workspace
---@field localdir fun(): string where local workspace-specific files are be stored
---@field datadir fun(): string path to ".hookspace" subdir
---@field metafile fun(): string path to metadata file

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
