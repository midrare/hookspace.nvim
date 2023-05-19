local M = {}

local default_opts = { filename = "env.json", global = false }
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

local env_filename = "env.json"
local old_env = nil

local sep = vim.fn.has("win32") >= 1 and "\\" or "/"

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

local function read_env_file(workspace, filename)
  local plaintext = vim.fn.readfile(filename, "B")
  if not plaintext then
    return nil
  end
  local env = vim.fn.json_decode(plaintext)
  tbl_sub_all(env, "{rootdir}", workspace.rootdir())
  tbl_sub_all(env, "{globaldir}", workspace.globaldir())
  tbl_sub_all(env, "{localdir}", workspace.localdir())
  return env
end

function M.setup(opts)
  ---@diagnostic disable-next-line: unused-local
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function M.on_open(workspace)
  old_env = {}

  local global_file = workspace.globaldir() .. sep .. env_filename
  local local_file = workspace.localdir() .. sep .. env_filename

  if vim.fn.filereadable(global_file) >= 1 then
    local global_env = {}
    if user_opts.global then
      global_env = read_env_file(workspace, global_file) or {}
    end

    local local_env = read_env_file(workspace, local_file) or {}
    local new_env = vim.tbl_deep_extend("force", global_env, local_env)

    for name, value in pairs(new_env) do
      if is_var_name_sane(name) then
        old_env[name] = os.getenv(name) or false
        vim.fn.setenv(name, value or nil)
      end
    end
  end
end

---@diagnostic disable-next-line: unused-local
function M.on_close(workspace)
  if old_env then
    for name, value in pairs(old_env) do
      if is_var_name_sane(name) then
        vim.fn.setenv(name, value or nil)
      end
    end

    old_env = nil
  end
end

return M
