--[[                  How to use this hook
------------------------------------------------------------------

All this hook does is look in $localdir/lspconfig.json and
and assign the resultant object to M.lsp_config.

When you set up your LSP servers, call the handler provided by the
hook. The handler takes the loaded config object and merges it
with the existing config, then notifies the lsp server that the config
has changed.

  require("lspconfig")[server_name].setup(conf)({
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    on_init = function(client, init_ret)
      require("hookspace.hooks.lspconfig").server_init(client, init_ret)
      return true
    end
  })

------------------------------------------------------------------ ]]

local M = {}

local default_opts = { use_global = false, use_local = true }
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

---@type table?
M.lsp_settings = nil

local function read_file(filename)
  local fd = vim.loop.fs_open(filename, 'r', 438)
  if not fd then
    return nil
  end

  local stat = vim.loop.fs_fstat(fd)
  if not stat then
    return nil
  end

  local data = vim.loop.fs_read(fd, stat.size, 0)
  vim.loop.fs_close(fd)

  return data
end

local function read_json(filename)
  if vim.fn.filereadable(filename) <= 0 then
    return nil
  end

  local plaintext = read_file(filename)
  if not plaintext then
    return nil
  end

  local is_ok, o = pcall(vim.fn.json_decode, plaintext)
  if not is_ok or not o then
    return nil
  end

  return o
end

local function recursive_sub(tbl, pat, repl)
  for k, v in pairs(tbl) do
    if type(v) == 'string' then
      tbl[k] = v:gsub(pat, repl)
    elseif type(v) == 'table' then
      recursive_sub(v, pat, repl)
    end
  end
end

local function replace_templates(o, workspace)
  recursive_sub(o, '{rootdir}', workspace.rootdir())
  recursive_sub(o, '{globaldir}', workspace.globaldir())
  recursive_sub(o, '{localdir}', workspace.localdir())
end

local function read_configs(filename, workspace)
  local config = {}

  local globalfile = workspace.globaldir() .. '/' .. filename
  local localfile = workspace.localdir() .. '/' .. filename

  if user_opts.use_global then
    local o = read_json(globalfile) or {}
    replace_templates(o, workspace)
    vim.tbl_deep_extend("force", config, o)
  end

  if user_opts.use_local then
    local o = read_json(localfile) or {}
    replace_templates(o, workspace)
    vim.tbl_deep_extend("force", config, o)
  end

  return config
end

function M.setup(opts)
  ---@diagnostic disable-next-line: unused-local
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function M.on_open(workspace)
  M.lsp_settings = read_configs("lspsettings.json", workspace)
end

---@diagnostic disable-next-line: unused-local
function M.on_close(workspace)
  M.lsp_settings = nil
end

---@diagnostic disable-next-line: unused-local
function M.server_init(client, init_ret)
  local lsp_config = M.lsp_settings
  if lsp_config then
    local settings = client.config.settings
    client.config.settings =
      vim.tbl_deep_extend('force', settings, lsp_config)
    client.notify('workspace/didChangeConfiguration', {
      settings = client.config.settings,
    })
  end
  return true
end

return M
