--[[                  How to use this hook
------------------------------------------------------------------

Put your lsp settings in $localdir/lspconfig.json. When you
set up your LSP servers, call the handler provided by the hook.

  require("lspconfig")[server_name].setup(conf)({
    capabilities = vim.lsp.protocol.make_client_capabilities(),
    on_init = function(client, init_ret)
      require("hookspace.hooks.lspconfig").server_init(client, init_ret)
      return true
    end
  })

------------------------------------------------------------------ ]]

local M = {}

local variables = require("hookspace.variables")


local default_opts = {}
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

local sep = vim.fn.has("win32") >= 1 and "\\" or "/"
local pathsep = vim.fn.has("win32") >= 1 and ";" or ":"

---@type table?
local lsp_settings = nil


local function read_file(filename)
  local fd = vim.loop.fs_open(filename, "r", 438)
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

local function read_configs(workspace)
  local o1 = read_json(workspace.datadir() .. sep .. "lspconfig.json") or {}
  local o2 = read_json(workspace.localdir() .. sep .. "lspconfig.json") or {}
  local config = vim.tbl_deep_extend("force", o1, o2)

  variables.replace_workspace_variables(config, workspace)

  return config
end

function M.setup(opts)
  ---@diagnostic disable-next-line: unused-local
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function M.on_open(workspace)
  lsp_settings = read_configs(workspace)
end

---@diagnostic disable-next-line: unused-local
function M.on_close(workspace)
  lsp_settings = nil
end

function M.lsp_settings()
  return vim.tbl_deep_extend("force", {}, lsp_settings or {})
end

return M
