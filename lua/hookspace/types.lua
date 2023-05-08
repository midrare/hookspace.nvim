---@meta _

---@class HookspaceWorkspace
---@field datadir string where workspace-specific files are stored
---@field rootdir string root dir of workspace

---@alias HookspaceHook function(HookspaceWorkspace, HookspaceUserdata): nil|boolean
---@alias HookspaceUserData table<string|number, any>

---@class HookspaceOptions
---@field verbose integer from 0..
---@field on_create nil|HookspaceHook|HookspaceHook[]
---@field on_delete nil|HookspaceHook|HookspaceHook[]
---@field on_open nil|HookspaceHook|HookspaceHook[]
---@field on_close nil|HookspaceHook|HookspaceHook[]

---@class HookspaceRecord
---@field last_accessed integer timestamp of last access
---@field rootdir string path to workspace root
