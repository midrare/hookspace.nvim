local M = {}

local variables = require("hookspace.variables")


local default_opts = {}
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

local sep = vim.fn.has("win32") >= 1 and "\\" or "/"
local old_env = nil

local function is_env_varname_ok(varname)
  return string.match(varname, "^[a-zA-Z_][a-zA-Z0-9_\\-]*$")
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

function M.setup(opts)
  ---@diagnostic disable-next-line: unused-local
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function M.on_open(workspace)
  old_env = {}

  local o1 = read_json(workspace.datadir() .. sep .. "environment.json") or {}
  local o2 = read_json(workspace.localdir() .. sep .. "environment.json") or {}

  local new_env = vim.tbl_deep_extend("force", {}, o1, o2)
  variables.replace_workspace_variables(new_env, workspace)

  for name, value in pairs(new_env) do
    if is_env_varname_ok(name) then
      old_env[name] = os.getenv(name) or false
      vim.fn.setenv(name, value or nil)
    else
      vim.notify(
        'Ignoring illegal environment variable name "' .. name '".',
        vim.log.WARN
      )
    end
  end
end

---@diagnostic disable-next-line: unused-local
function M.on_close(workspace)
  if old_env then
    for name, value in pairs(old_env) do
      if is_env_varname_ok(name) then
        vim.fn.setenv(name, value or nil)
      else
        vim.notify(
          'Ignoring illegal environment variable name "' .. name '".',
          vim.log.WARN
        )
      end
    end

    old_env = nil
  end
end

return M
