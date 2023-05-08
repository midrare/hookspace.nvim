local M = {}

local old_env_names = nil
local old_env_values = nil

local sep = '/'
if vim.fn.has('win32') >= 1 then
  sep = '\\'
end

local function tbl_sub_all(tbl, pat, repl)
  for k, v in pairs(tbl) do
    if type(v) == 'string' then
      tbl[k] = v:gsub(pat, repl)
    elseif type(v) == 'table' then
      tbl_sub_all(v, pat, repl)
    end
  end
end

function M.on_open(workspace, user_data)
  old_env_names = {}
  old_env_values = {}

  local cfg_path = workspace.datadir .. sep .. 'environment.json'
  if vim.fn.filereadable(cfg_path) >= 1 then
    local plaintext = vim.fn.readfile(cfg_path, 'B')
    if plaintext then
      local localenv = vim.fn.json_decode(plaintext)
      tbl_sub_all(localenv, '{rootdir}', workspace.rootdir)
      tbl_sub_all(localenv, '{datadir}', workspace.datadir)

      ---@diagnostic disable-next-line: param-type-mismatch
      for name, value in pairs(localenv) do
        table.insert(old_env_names, name)
        old_env_values[name] = os.getenv(name)

        -- XXX Hacky, but safer than interpolating using the value directly
        vim.g.ULSSYOZRYK = value
        vim.cmd('let $' .. name .. ' = g:ULSSYOZRYK')
        vim.g.ULSSYOZRYK = nil
      end
    end
  end
  vim.api.nvim_set_current_dir(workspace.rootdir)
end

function M.on_close(workspace, user_data)
  if old_env_names then
    for _, name in ipairs(old_env_names) do
      local value = old_env_values[name]
      if value ~= nil then
        -- XXX Hacky, but safer than interpolating using the value directly
        vim.g.ULSSYOZRYK = value
        vim.cmd('let $' .. name .. ' = g:ULSSYOZRYK')
        vim.g.ULSSYOZRYK = nil
      else
        vim.cmd('unlet $' .. name)
      end
    end

    old_env_names = nil
    old_env_values = nil
  end
end

return M
