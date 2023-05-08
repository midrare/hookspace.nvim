local modulename, _ = ...
local moduleroot = modulename:gsub('(.+)%..+', '%1')

local file = require(moduleroot .. '.file')
local notify = require(moduleroot .. '.notify')
local paths = require(moduleroot .. '.path')

local listings_filepath = vim.fn.stdpath('data')
  .. paths.sep()
  .. 'hookspace'
  .. paths.sep()
  .. 'workspaces.json'

local M = {}

local function cmp_attr_alnum(a, b, attrname)
  for i = 1, math.max(#a[attrname], #b[attrname]) do
    if i > #a[attrname] then
      return -1
    elseif i > #b[attrname] then
      return 1
    end

    local a_ch = a[attrname]:ascii(i)
    local b_ch = b[attrname]:ascii(i)

    if a_ch < b_ch then
      return -1
    elseif a_ch > b_ch then
      return 1
    end
  end

  return 0
end

local function cmp_most_recently_accessed(a, b)
  if a.last_accessed > b.last_accessed then
    return -1
  elseif a.last_accessed < b.last_accessed then
    return 1
  end

  return 0
end

local function sorted_entries(items, sort_by, reverse)
  local results = {}
  local cmp = cmp_most_recently_accessed

  for _, item in ipairs(items) do
    table.insert(results, item)
  end

  if sort_by == 'accessed' then
    cmp = cmp_most_recently_accessed
  elseif sort_by == 'path' then
    cmp = function(a, b)
      return cmp_attr_alnum(a, b('rootdir'))
    end
  elseif sort_by ~= nil then
    notify.error('Unrecognized sort option "' .. vim.inspect(sort_by) .. '".')
  end

  for i = 1, #results - 1 do
    local a = results[i]
    local b = results[i + 1]
    local cmp_result = cmp(a, b)

    if (not reverse and cmp_result > 0) or (reverse and cmp_result < 0) then
      results[i] = b
      results[i + 1] = a
    end
  end

  return results
end

local function validated_entries(entries)
  local results = {}

  for _, e in ipairs(entries) do
    if not e.rootdir or type(e.rootdir) ~= 'string' then
      -- skip invalid entry
    else
      table.insert(results, e)
    end
  end

  return results
end

local function uniqified_entries(entries)
  local results = {}

  for _, e1 in ipairs(entries) do
    local c1 = paths.normpath(paths.normcase(e1.rootdir))
    local found = false

    for _, e2 in ipairs(results) do
      local c2 = paths.normpath(paths.normcase(e2.rootdir))

      if
        e1.rootdir == e2.rootdir
        or c1 == e2.rootdir
        or e1.rootdir == c2
        or c1 == c2
      then
        e2.last_accessed = math.max(e1.last_accessed, e2.last_accessed)
        found = true
        break
      end
    end

    if not found then
      table.insert(results, e1)
    end
  end

  return results
end

local function find_entries_by_path(entries, path)
  local results = {}
  local c1 = paths.normpath(paths.normcase(path))

  for _, e2 in pairs(entries) do
    local c2 = paths.normpath(paths.normcase(e2.rootdir))
    if path == e2.rootdir or c1 == e2.rootdir or path == c2 or c1 == c2 then
      table.insert(results, e2)
    end
  end

  return results
end

local function delete_entries_by_path(entries, path)
  local results = {}
  local c1 = paths.normpath(paths.normcase(path))

  for i, e2 in pairs(entries) do
    local c2 = paths.normpath(paths.normcase(e2.rootdir))
    if path == e2.rootdir or c1 == e2.rootdir or path == c2 or c1 == c2 then
      entries[i] = nil
      table.insert(results, e2)
    end
  end

  return results
end

local function read_entries(sort_by)
  local results = {}

  if vim.fn.filereadable(listings_filepath) == 1 then
    local obj = file.read_json(listings_filepath)
    results = validated_entries(obj or {})
    results = uniqified_entries(results)
    results = sorted_entries(results, sort_by)
  end

  return results
end

local function write_entries(entries)
  entries = uniqified_entries(entries)
  entries = sorted_entries(entries)
  file.write_json(listings_filepath, entries)
end

function M.get_entries(sort_by)
  return read_entries(sort_by)
end

function M.get_valid_entries(sort_by)
  local entries = read_entries(sort_by)
  local results = {}
  for _, e in ipairs(entries) do
    if
      vim.fn.isdirectory(e.rootdir) == 1
      or vim.fn.filereadable(e.rootdir) == 1
    then
      table.insert(results, e)
    end
  end
  return results
end

function M.get_paths(sort_by)
  local entries = read_entries(sort_by)
  local results = {}
  for _, e in ipairs(entries) do
    table.insert(results, e.rootdir)
  end
  return results
end

function M.delete(path)
  local entries = read_entries()
  delete_entries_by_path(entries, path)

  write_entries(entries)
end

function M.move(old_path, new_path)
  local entries = read_entries()
  local matches = find_entries_by_path(entries, old_path)
  local canonical = paths.normpath(paths.normcase(new_path))

  for _, entry in pairs(matches) do
    entry.rootdir = canonical
  end

  write_entries(entries)
end

function M.rename(path, name)
  local entries = read_entries()
  local matches = find_entries_by_path(entries, path)

  for _, entry in pairs(matches) do
    entry.name = name
  end

  write_entries(entries)
end

function M.update(path, timestamp)
  local entries = read_entries()
  local matches = find_entries_by_path(entries, path)
  local canonical = paths.normpath(paths.normcase(path))

  if matches and #matches >= 1 then
    for _, entry in ipairs(matches) do
      entry.last_accessed = timestamp
    end
  else
    local entry = {
      last_accessed = timestamp,
      rootdir = canonical,
    }
    table.insert(entries, entry)
  end

  write_entries(entries)
end

return M
