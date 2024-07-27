local M = {}

local default_opts = {}
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

local old_env = nil

local sep = vim.fn.has("win32") >= 1 and "\\" or "/"
local pathsep = vim.fn.has("win32") >= 1 and ";" or ":"

local function is_env_varname_ok(varname)
  return string.match(varname, "^[a-zA-Z_][a-zA-Z0-9_\\-]*$")
end


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

local function find_pattern(value, patterns, pos)
  local best = nil

  for _, p in ipairs(patterns) do
    local start, stop = value:find(p[1], pos)
    if start ~= nil and stop ~= nil then
      local m = {
        start = start,
        stop = stop,
        fulltext = value,
        text = value:sub(start, stop),
        pattern = p[1],
        replace = p[2],
      }
      if matchcmp(best, m) > 0 then
        best = m
      end
    end
  end

  return best
end


local function make_patterns(key, workspace)
  local patterns = {
    {
      "%${[Ee][Nn][Vv]:[%a_][%a%d_ ]-}", function(m)
        local name = m.text:match("%${[Ee][Nn][Vv]:(.*)}")
        return os.getenv(name) or ""
      end
    },
    { "%${[Rr][Oo][Oo][Tt][Dd][Ii][Rr]}", workspace.rootdir() },
    { "%${[Dd][Aa][Tt][Aa][Dd][Ii[Rr]}", workspace.datadir() },
    { "%${[Ll][Oo][Cc][Aa][Ll[Dd][Ii][Rr]}", workspace.localdir() },
  }

  if key:upper():match('PATH$') then
    table.insert(patterns, {
      "[:;]", function(m)
        local s = m.fulltext:sub(1, m.stop + 1)
        if s:match("^%a:[\\/]$") or s:match("[^%a]%a:[\\/]$") then
          return m.text
        end

        return pathsep
      end
    })
  end

  return patterns
end


local function replace_next(str, patterns, pos)
  local best = find_pattern(str, patterns, pos)
  if not best then
    return nil, #str + 1
  end

  local repstr = type(best.replace) == "function" and best.replace(best) or best.replace
  local newstr = str:sub(1, best.start - 1) .. repstr .. str:sub(best.stop + 1, #str)

  return newstr, best.start + #repstr
end


local function replace_templates(key, value, workspace)
  local patterns = make_patterns(key, workspace)

  -- only replace each pattern once (i.e. do not re-run on replaced string)
  local pos = 1
  while pos <= #value do
    value, pos = replace_next(value, patterns, pos)
  end

  return value
end


local function recursive_sub(tbl, workspace)
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      tbl[k] = replace_templates(k, tbl[k], workspace)
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

function M.setup(opts)
  ---@diagnostic disable-next-line: unused-local
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function M.on_open(workspace)
  old_env = {}

  local o1 = read_json(workspace.datadir() .. sep .. "environment.json") or {}
  local o2 = read_json(workspace.localdir() .. sep .. "environment.json") or {}

  local new_env = vim.tbl_deep_extend("force", {}, o1, o2)
  recursive_sub(new_env, workspace)

  for name, value in pairs(new_env) do
    if is_env_varname_ok(name) then
      old_env[name] = os.getenv(name) or false
      vim.fn.setenv(name, value or nil)
    end
  end
end

---@diagnostic disable-next-line: unused-local
function M.on_close(workspace)
  if old_env then
    for name, value in pairs(old_env) do
      if is_env_varname_ok(name) then
        vim.fn.setenv(name, value or nil)
      end
    end

    old_env = nil
  end
end

return M
