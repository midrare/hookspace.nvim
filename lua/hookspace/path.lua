-- 2022/10/30

local M = {}

local is_windows = vim.fn.has('win32') > 0
local path_sep = '/'
if vim.fn.has('win32') > 0 then
  path_sep = '\\'
end

local np_pat1 = ('[^SEP]+SEP%.%.SEP?'):gsub('SEP', path_sep)
local np_pat2 = ('SEP+%.?SEP'):gsub('SEP', path_sep)

function M.sep()
  return path_sep
end

function M.basename(filename)
  return filename:gsub('^.*[\\/](.+)[\\/]*', '%1')
end

local function dirname(filename)
  local d = filename:match('^(.*[\\/]).+$')
  if d ~= nil then
    d = d:match('^(.+)[\\/]+$') or d
  end
  return d
end

function M.dirname(filename)
  return dirname(filename)
end

function M.filestem(filename)
  local basename = filename:match('^.+[\\/](.+)$') or filename
  return basename:gsub('^(.+)%.[^%s]+$', '%1')
end

function M.fileext(filename)
  local basename = filename:match('^.+[\\/](.+)$') or filename
  return basename:match('^.+(%.[^%s]+)$') or ''
end

function M.normcase(filepath)
  if is_windows then
    return filepath:lower():gsub('/', '\\')
  else
    return filepath:gsub('\\', '/')
  end
end

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

function M.isabs(filepath)
  return filepath:match('^[\\/]') or filepath:match('^[a-zA-Z]:[\\/]')
end

function M.abspath(filepath, pwd)
  filepath = filepath:gsub('[\\/]+$', '')
  if not M.isabs(filepath) then
    filepath = pwd:gsub('[\\/]+$', '')
      .. M.sep()
      .. filepath:gsub('^[\\/]+', '')
  end
  return M.normpath(filepath)
end

function M.canonical(filepath, cwd)
  local normcased = M.normcase(filepath)

  if not M.isabs(normcased) then
    return M.abspath(normcased, cwd)
  end

  return normcased
end

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
