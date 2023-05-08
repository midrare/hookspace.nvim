# hookspace.nvim
**Hookspace defines your Neovim workspace entirely as a set of hooks. This makes workspaces endlessly flexible.**

## Install
In your `init.lua`  

```lua
-- see instructions for your specific plugin manager
require('packer').use 'midrare/hookspace.nvim'
```

## Usage
The concept is simple: every workspace event (e.g. `init`, `open`, `close`) is triggers an array of hooks. Every event, aside from `init`, does nothing by itself, but relies entirely on its hooks to do all of the work. These hooks are supplied by you when you call `hookspace.setup(...)`, with one array of hooks for each event. Upon an event being activated, its list of hooks are run in the order they were provided in.

```lua
-- example that changes cwd to workspace root dir and back
local old_cwd = nil

local function cwd_open(workspace, userdata)
    old_cwd = vim.fn.getcwd(-1, -1)
    vim.api.nvim_set_current_dir(workspace.rootdir)
end

local function cwd_close(workspace, userdata)
    vim.api.nvim_set_current_dir(old_cwd or '~')
    old_cwd = nil
end

require('hookspace').setup({
    on_init = {},
    on_open = {cwd_open},
    on_close = {cwd_close},
})
```

### Workspace events
Workspace events can be triggered either through the ex commands or the Lua functions.

 - `:HookspaceInit ~/hello_world`
 - `:HookspaceOpen ~/hello_world`
 - `:HookspaceClose`

 - `require("hookspace").init(...)`
 - `require("hookspace").open(...)`
 - `require("hookspace").close(...)`

### Writing hooks
Every hook has the same signature: `function(workspace, userdata)`, where `workspace` is a table of workspace metadata and `userdata` is a table of user-defined data stored with the workspace as a convenience.

### Starter setup
By default, Hookspace does nothing. You need to configure it with hooks for it to do something. Here is an starter setup using the built-in hooks.

```lua
local cwd_hooks = require('hookspace.hooks.cwd')
local env_hooks = require('hookspace.hooks.environment')
local session_hooks = require('hookspace.hooks.session')

-- NOTE the order of hooks is important!
require('hookspace').setup({
  on_init = {
  },
  on_open = {
    env_hooks and env_hooks.on_open,
    session_hooks and session_hooks.on_open,
    cwd_hooks and cwd_hooks.on_open,
  },
  on_close = {
    session_hooks and session_hooks.on_close,
    cwd_hooks and cwd_hooks.on_close,
    env_hooks and env_hooks.on_close,
  },
})
```
