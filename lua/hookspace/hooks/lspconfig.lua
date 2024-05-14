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

local default_opts = {}
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

local sep = vim.fn.has("win32") >= 1 and "\\" or "/"
local pathsep = vim.fn.has("win32") >= 1 and ";" or ":"

---@type table?
M.lsp_settings = nil

local function matchcmp(m1, m2)
  if m1 == nil and m2 ~= nil then
    return 1
  end
  if m1 ~= nil and m2 == nil then
    return -1
  end
  if m1 == nil and m2 == nil then
    return 0
  end

  if m1.start < m2.start or (m1.start <= m2.start
    and (m1.stop - m1.start) < (m2.stop - m2.start)) then
    return -1
  end

  if m2.start < m1.start or (m2.start <= m1.start
    and (m2.stop - m2.start) < (m1.stop - m1.start)) then
    return 1
  end

  return 0
end

local function replace_templates(s, workspace)
  local repls = {
    {
      "%${[Ee][Nn][Vv]:[%a_][%a%d_ ]-}", function(m)
        local name = m:match("%${[Ee][Nn][Vv]:(.*)}")
        return os.getenv(name) or ""
      end
    },
    { "%${[:;]+}", pathsep },
    { "%${[\\/]+}", sep },
    { "%${[Rr][Oo][Oo][Tt][Dd][Ii][Rr]}", workspace.rootdir() },
    { "%${[Dd][Aa][Tt][Aa][Dd][Ii[Rr]}", workspace.datadir() },
    { "%${[Ll][Oo][Cc][Aa][Ll[Dd][Ii][Rr]}", workspace.localdir() },
  }

  local init = 1
  while init <= #s do
    local best = nil

    for _, p in ipairs(repls) do
      local start, stop = s:find(p[1], init)
      if start ~= nil and stop ~= nil then
        local m = {
          start = start,
          stop = stop,
          pat = p[1],
          repl = p[2],
        }
        if matchcmp(best, m) > 0 then
          best = m
        end
      end
    end

    if not best then
      break
    end

    local repl = best.repl
    if type(repl) == "function" then
      repl = repl(s:sub(best.start, best.stop))
    end

    s = s:sub(1, best.start - 1) .. repl .. s:sub(best.stop + 1, #s)
    init = best.start + #repl
  end

  return s
end

local function recursive_sub(tbl, workspace)
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      tbl[k] = replace_templates(tbl[k], workspace)
    elseif type(v) == "table" then
      recursive_sub(v)
    end
  end
end

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
  local config = {}

  local o1 = read_json(workspace.datadir() .. sep .. "lspconfig.json") or {}
  local o2 = read_json(workspace.localdir() .. sep .. "lspconfig.json") or {}

  config = vim.tbl_deep_extend("force", config, o1, o2)
  recursive_sub(config, workspace)

  return config
end

function M.setup(opts)
  ---@diagnostic disable-next-line: unused-local
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function M.on_open(workspace)
  M.lsp_settings = read_configs(workspace)
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
    client.config.settings = vim.tbl_deep_extend("force", settings, lsp_config)
    client.notify("workspace/didChangeConfiguration", {
      settings = client.config.settings,
    })
  end
  return true
end

return M
