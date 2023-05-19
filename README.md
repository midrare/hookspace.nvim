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

 - `:HookspaceInit ~/hello_world` or `require("hookspace").init("~/hello_world")`
 - `:HookspaceOpen ~/hello_world` or `require("hookspace").open("~/hello_world")`
 - `:HookspaceClose` or `require("hookspace").close()`

Each workspace event (e.g. `init`, `open`, `close`) triggers an array of hooks in a well-defined order. Every event, aside from `init` (which creates `.hookspace` and populates it with some basic metadata files), does nothing by itself, but relies entirely on its hooks to do all of the work. These hooks are supplied by you when you call `hookspace.setup()`.

### Getting started
By default, hookspace does nothing. You need to add hooks for it to do something. Here's a minimal starter setup using the built-in hooks. This setup uses hooks to provide what you'd expect from a normal session manager: `cd` in/out of the workspace dir, and save/restore the associated sessions. Put this code in your `init.lua`.

```lua
local cwd = require('hookspace.hooks.cwd')
local session = require('hookspace.hooks.session')

-- NOTE the order of hooks is important!
require('hookspace').setup({
  on_init = {
  },
  on_open = {
    session.on_open,
    cwd.on_open,
  },
  on_close = {
    session.on_close,
    cwd.on_close,
  },
})
```

Optionally, you can load the telescope extension for a workspace picker.

```lua
require('telescope').load_extension("hookspace")
```

Now it's time to initialize your workspace. Run `:HookspaceInit ~/Projects/hello_world` to create the `.hookspace` subfolder and populate it with some basic workspace metadata files. You can initialize an existing folder as well as an empty folder. To open the workspace, run `:HookspaceOpen ~/Projects/hello_world`. (If you run `pwd`, you'll notice your working dir has changed. This was the work of the `cwd` hook you set up earlier.) When you're done working in your workspace, run `:HookspaceClose` to close it. If you quit Neovim without closing your workspace, it will close itself automatically.

### Writing hooks
A hook is a function with the signature: `function(workspace)`. `workspace` is an object providing metadata and file paths pertaining to the workspace.

The members of the `workspace` object you want to pay attention to are the following.

  - `workspace.rootdir()` is a `string` pointing to the root of the workspace. For example, `~/Projects/hello_world`.
  - `workspace.datadir()` is a `string` pointing to the `.hookspace` subdir. For example, `~/Projects/hello_world/.hookspace`. Files that are workspace-specific but not user-specific should go here. Any files put here should be safe to be checked into VCS. For safety, do not write hooks that read sensitive data or run arbitrary code from `$datadir`.
  - `workspace.localdir()` is a `string` pointing to the local workspace-specific data dir. For example, `$LOCALAPPDATA/nvim-data/hookspace/cgwjRTcWKp.wkspc`. Files that contain sensitive data or arbitrary code (including session data) should go here.

`$localdir` needs some explanation. `$localdir` is folder on your local machine, outside of the workspace. `$localdir` is not per-workspace, but per-instance. If you take a workspace and copy it, each of the two workspaces will have its own unique `$localdir` even though the two workspaces' content files and metadata files are identical. (Internally, `$localdir` is calculated from `FileID` on Windows and `inode` on NIX.) By storing its contents completely outside the workspace itself, `$localdir` prevents you from accidentially adding sensitive files to VCS. Also, a malicious repo can't pre-package a malware session or script in a `$localdir`. If you're writing a hook that makes use of sensitive data or can run arbitrary code, you consider using `$localdir`.

Let's walk through an example. This is the code for the built-in `cwd` hook. The `cwd` hook will `cd` to the workspace root dir when the workspace is opened, and `cd` back when the workspace is closed.

```lua
local old_cwd = nil

local function cwd_open(workspace)
    old_cwd = vim.fn.getcwd(-1, -1)
    vim.api.nvim_set_current_dir(workspace.rootdir())
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
