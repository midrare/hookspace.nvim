local module = {}

local default_opts = { filename = "env.json" }
local user_opts = vim.deepcopy(default_opts)

local old_env_names = nil
local old_env_values = nil

local sep = "/"
if vim.fn.has("win32") >= 1 then
  sep = "\\"
end

local function tbl_sub_all(tbl, pat, repl)
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      tbl[k] = v:gsub(pat, repl)
    elseif type(v) == "table" then
      tbl_sub_all(v, pat, repl)
    end
  end
end

local function is_var_name_sane(varname)
  return string.match(varname, "^[a-zA-Z0-9_\\-]*$")
end

function module.setup(opts)
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function module.on_open(workspace)
  old_env_names = {}
  old_env_values = {}

  local cfg_path = workspace.datadir .. sep .. user_opts.filename
  if vim.fn.filereadable(cfg_path) >= 1 then
    local plaintext = vim.fn.readfile(cfg_path, "B")
    if plaintext then
      local localenv = vim.fn.json_decode(plaintext)
      tbl_sub_all(localenv, "{rootdir}", workspace.rootdir)
      tbl_sub_all(localenv, "{datadir}", workspace.datadir)
      tbl_sub_all(localenv, "{userdir}", workspace.userdir)

      ---@diagnostic disable-next-line: param-type-mismatch
      for name, value in pairs(localenv) do
        if is_var_name_sane(name) then
          table.insert(old_env_names, name)
          old_env_values[name] = os.getenv(name)

          -- safer than interpolating the value directly
          vim.g.ORVQUZFPUA = name
          vim.g.ULSSYOZRYK = value
          vim.cmd("call setenv(g:ORVQUZFPUA, g:ULSSYOZRYK)")
          vim.g.ORVQUZFPUA = nil
          vim.g.ULSSYOZRYK = nil
        end
      end
    end
  end
  vim.api.nvim_set_current_dir(workspace.rootdir)
end

---@diagnostic disable-next-line: unused-local
function module.on_close(workspace)
  if old_env_names then
    for _, name in ipairs(old_env_names) do
      if is_var_name_sane(name) then
        local value = old_env_values[name]
        -- safer than interpolating the value directly
        vim.g.ORVQUZFPUA = name
        vim.g.ULSSYOZRYK = value
        if value ~= nil then
          vim.cmd("call setenv(g:ORVQUZFPUA, g:ULSSYOZRYK)")
        else
          vim.cmd("call setenv(g:ORVQUZFPUA, v:null)")
        end
        vim.g.ORVQUZFPUA = nil
        vim.g.ULSSYOZRYK = nil
      end
    end

    old_env_names = nil
    old_env_values = nil
  end
end

return module
