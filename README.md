# hookspace.nvim
**Hookspace defines your Neovim workspace entirely as a set of hooks. This makes workspaces endlessly flexible.**

## Install
In your `init.lua`  

```lua
-- see instructions for your specific plugin manager
require('packer').use 'midrare/hookspace.nvim'
```

## Usage
No hooks are registered by default. Here is an example setup using the built-in hooks.

```lua
local cwd_hooks = require('hookspace.hooks.cwd')
local env_hooks = require('hookspace.hooks.environment')
local session_hooks = require('hookspace.hooks.session')

-- NOTE the order of hooks is important!
require('hookspace').setup({
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

### Commands

 - `:HookspaceInit ~/hello_world`
 - `:HookspaceOpen ~/hello_world`
 - `:HookspaceClose`
 - `:HookspaceList`
 - `:HookspaceInfo`
