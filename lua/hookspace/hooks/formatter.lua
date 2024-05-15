local M = {}

local sep = vim.fn.has("win32") >= 1 and "\\" or "/"

local default_opts = {}
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

local old_fmts = nil

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
  local o1 = read_json(workspace.datadir() .. sep .. "formatter.json") or {}
  local o2 = read_json(workspace.localdir() .. sep .. "formatter.json") or {}

  old_fmts = {}
  local new_fmts = vim.tbl_deep_extend("force", {}, o1, o2)

  for name, value in pairs(new_fmts) do
    if name:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
      old_fmts = { [name] = vim.g['formatter_' .. name] or false }
      vim.g['formatter_' .. name] = value
    end
  end
end

---@diagnostic disable-next-line: unused-local
function M.on_close(workspace)
  if old_fmts then
    for name, value in pairs(old_fmts) do
      vim.g['formatter_' .. name] = value or nil
    end
  end

  old_fmts = nil
end

return M

