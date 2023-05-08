-- 2023/05/07

local M = {}

local is_windows = vim.fn.has('win32') > 0
local path_sep = '/'
if vim.fn.has('win32') > 0 then
  path_sep = '\\'
end

local np_pat1 = ('[^SEP]+SEP%.%.SEP?'):gsub('SEP', path_sep)
local np_pat2 = ('SEP+%.?SEP'):gsub('SEP', path_sep)

---@return string sep os-specific path separator
function M.sep()
  return path_sep
end

---@param filename string file path
---@return string basename file name segment of path
function M.basename(filename)
  local a, _ = filename:gsub('^.*[\\/](.+)[\\/]*', '%1')
  return a
end

---@param filename string file path
---@return string dirname parent directory of path
function M.dirname(filename)
  local d = filename:match('^(.*[\\/]).+$')
  if d ~= nil then
    d = d:match('^(.+)[\\/]+$') or d
  end
  return d
end

---@param filename string file path
---@return string filestem base name without file extension
function M.filestem(filename)
  local basename = filename:match('^.+[\\/](.+)$') or filename
  return basename:gsub('^(.+)%.[^%s]+$', '%1')
end

---@param filename string file path
---@return string? file extension if any
function M.fileext(filename)
  local basename = filename:match('^.+[\\/](.+)$') or filename
  return basename:match('^.+(%.[^%s]+)$') or nil
end

---@param filepath string file path
---@return string filepath file path with path separators for current os
function M.normcase(filepath)
  local p, _ = nil, nil
  if is_windows then
    p, _ = filepath:lower():gsub('/', '\\')
  else
    p, _ = filepath:gsub('\\', '/')
  end
  return p
end

---@param filepath string file path
---@return string filepath file path with ".." collapsed
function M.normpath(filepath)
  if is_windows then
    if filepath:match('^\\\\') then -- UNC
      return '\\\\' .. M.normpath(filepath:sub(3))
    end
    filepath = filepath:gsub('/', '\\')
  end

  local k
  repeat -- /./ -> /
    filepath, k = filepath:gsub(np_pat2, path_sep)
  until k == 0

  repeat -- A/../ -> (empty)
    filepath, k = filepath:gsub(np_pat1, '')
  until k == 0

  if filepath == '' then
    filepath = '.'
  end

  while true do
    local s = filepath:gsub('[\\/]+$', '')
    if s == filepath then
      break
    end
    filepath = s
  end

  if is_windows then
    filepath = filepath:gsub(':+$', ':\\')
  elseif filepath == '' then
    filepath = '/'
  end

  return filepath
end

---@param filepath string file path
---@return boolean is_abs if file path is an absolute path
function M.isabs(filepath)
  return filepath:match('^[\\/]') or filepath:match('^[a-zA-Z]:[\\/]')
end

---@param filepath string file path
---@param pwd string current directory
---@return string filepath absolute file path
function M.abspath(filepath, pwd)
  filepath = filepath:gsub('[\\/]+$', '')
  if not M.isabs(filepath) then
    filepath = pwd:gsub('[\\/]+$', '')
      .. M.sep()
      .. filepath:gsub('^[\\/]+', '')
  end
  return M.normpath(filepath)
end

---@param filepath string file path
---@param cwd string current directory
---@return string filepath canonical file path
function M.canonical(filepath, cwd)
  local normcased = M.normcase(filepath)

  if not M.isabs(normcased) then
    return M.abspath(normcased, cwd)
  end

  return normcased
end

---@vararg string file path segments
---@return string filepath file path joined using os-specific path separator
function M.join(...)
  local sep = M.sep()
  local joined = ''

  for i = 1, select('#', ...) do
    local el = select(i, ...):gsub('[\\/]+$', '')
    if el and #el > 0 then
      if #joined > 0 then
        joined = joined .. sep
      end
      joined = joined .. el
    end
  end

  return joined
end

return M
