# hookspace.nvim
**Hookspace defines your Neovim workspace entirely as a set of hooks. This makes workspaces endlessly flexible.**

## Install
In your `init.lua`  

```lua
-- see instructions for your specific plugin manager
require('packer').use 'midrare/hookspace.nvim'
```

## Usage
A workspace is a folder that contains a `.hookspace` subfolder. Typically, a workspace is the path to a project repo. You can do three things to a workspace: initialize it, open it, or close it.

 - `:HookspaceInit ~/hello_world`
 - `require("hookspace").init(...)`

 - `:HookspaceOpen ~/hello_world`
 - `require("hookspace").open(...)`

 - `:HookspaceClose`
 - `require("hookspace").close(...)`


Each workspace event (e.g. `init`, `open`, `close`) triggers an array of hooks in a well-defined order. Every event, aside from `init` (which creates `.hookspace` and populates it with some basic metadata files), does nothing by itself, but relies entirely on its hooks to do all of the work. These hooks are supplied by you when you call `hookspace.setup()`.

### Starter setup
By default, hookspace does nothing. You need to add hooks for it to do something. Here's a starter setup using the built-in hooks.

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

### Writing hooks
A hook is a function with the signature: `function(workspace)`. `workspace` is an object providing metadata and file paths pertaining to the workspace.

The members of the `workspace` object you want to pay attention to are the following.

  - `workspace.rootdir` is a `string` pointing to the root dir of the workspace. For example, `C:/Users/You/Projects/hello_world`.
  - `workspace.globaldir` is a `string` pointing to the global workspace-specific data dir. For example, `C:/Users/You/Projects/hello_world/.hookspace`.
    Files that are workspace-specific but not user-specific should go here. Any files put here should be safe to be checked into VCS.
  - `workspace.localdir` is a `string` pointing to the local workspace-specific data dir. For example, `C:/Users/You/AppData/Local/nvim-data/hookspace/4KTy9GOUMwRYNewT.wkspc/cgwjRTcWKp.inst`.
    Files that are workspace-specific and user-specific should go here. 

`localdir` needs some explanation. `localdir` is directory on your local machine associated not with a workspace, but with a specific workspace instance (i.e. workspace's directory). If you take a workspace and copy it, each of the two workspaces will have its own unique `localdir` even though the contents of the workspace and even the workspace metadata files are identical. (Internally, `localdir` is calculated from `FileID` Windows and `inode` on NIX.) By storing its contents completely outside the workspace itself, `localdir` also prevents you from accidentially adding sensitive files to VCS. Moreover, a malicious repo can't pre-package a malware session or script in a `localdir`. If you're writing a hook that makes use of sensitive data or can run arbitrary code, you should use `localdir` exclusively.

Let's walk through an example. This is the code for the built-in `cwd` hook. The `cwd` hook will `cd` to the workspace root dir when the workspace is opened, and `cd` back when the workspace is closed.

```lua
local old_cwd = nil

local function cwd_open(workspace)
    old_cwd = vim.fn.getcwd(-1, -1)
    vim.api.nvim_set_current_dir(workspace.rootdir)
end

local function cwd_close(workspace)
    vim.api.nvim_set_current_dir(old_cwd or '~')
    old_cwd = nil
end
```

Now we can register our hook by calling `setup()`.

```lua
require('hookspace').setup({
    on_init = {},
    on_open = {cwd_open},
    on_close = {cwd_close},
})
```

For more examples, look in `hookspace.hooks` to see the code for the built-in hooks.

*(Note: You might have noticed that there's a bundled utility module, `hookspace.luamisc`. Do not use anything from `hookspace.luamisc`. `luamisc` is part of the private implementation and is subject to sudden breaking changes.)*
