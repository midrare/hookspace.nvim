local modulename, _ = ...
local moduleroot = modulename:gsub("(.+)%..+", "%1")

local file = require(moduleroot .. ".file")
local paths = require(moduleroot .. ".path")
local sorting = require(moduleroot .. ".sorting")

local records_path = vim.fn.stdpath("data")
  .. paths.sep()
  .. "hookspace"
  .. paths.sep()
  .. "workspaces.json"

local module = {}

local function is_record_valid(r)
  return r.rootdir
    and type(r.rootdir) == "string"
    and (
      vim.fn.isdirectory(r.rootdir) == 1
      or vim.fn.filereadable(r.rootdir) == 1
    )
end

local function is_record_same(r1, r2)
  local c1 = paths.normpath(paths.normcase(r1.rootdir))
  local c2 = paths.normpath(paths.normcase(r2.rootdir))
  return r1.rootdir == r2.rootdir
    or c1 == r2.rootdir
    or r1.rootdir == c2
    or c1 == c2
end

local function is_record_has_path(r, path)
  local c = paths.normpath(paths.normcase(r.rootdir))
  return path == r.rootdir or path == r.rootdir or path == c or path == c
end

local function cmp_last_accessed(r1, r2)
  if r1.last_accessed < r2.last_accessed then
    return -1
  elseif r1.last_accessed > r2.last_accessed then
    return 1
  end
  return 0
end

local function read_records(cmp)
  cmp = cmp or cmp_last_accessed
  local entries = {}

  if vim.fn.filereadable(records_path) == 1 then
    entries = file.read_json(records_path) or {}
    sorting.filter(entries, is_record_valid)
    sorting.uniqify(entries, is_record_same)
    sorting.sort(entries, cmp)
  end

  return entries
end

local function write_records(records)
  sorting.uniqify(records, is_record_same)
  sorting.sort(records)
  file.write_json(records_path, records)
end

function module.get_records()
  return read_records()
end

---@return string[] rootdirs workspace root dirs
function module.get_paths()
  local records = read_records()
  sorting.transform(records, function(r)
    return r.rootdir
  end)
  return records
end

---@param path string workspace root dir
function module.delete(path)
  local records = read_records()
  sorting.filter(records, function(r)
    return not is_record_has_path(r, path)
  end)
  write_records(records)
end

---@param old_path string old workspace root dir
---@param new_path string new workspace root dir
function module.move(old_path, new_path)
  local records = read_records()
  sorting.filter(records, function(r)
    return is_record_has_path(r, old_path)
  end)

  local canonical = paths.normpath(paths.normcase(new_path))
  sorting.apply(records, function(r)
    r.rootdir = canonical
  end)

  write_records(records)
end

---@param path string workspace root dir
---@param name string new name for workspace
function module.rename(path, name)
  local records = read_records()
  sorting.filter(records, function(r)
    return is_record_has_path(r, path)
  end)
  sorting.apply(records, function(r)
    r.name = name
  end)

  write_records(records)
end

---@param path string workspace root dir
---@param timestamp integer last access timestamp
function module.update(path, timestamp)
  local records = read_records()
  sorting.filter(records, function(r)
    return is_record_has_path(r, path)
  end)

  if records and #records >= 1 then
    for _, record in ipairs(records) do
      record.last_accessed = timestamp
    end
  else
    local canonical = paths.normpath(paths.normcase(path))
    local record = { last_accessed = timestamp, rootdir = canonical }
    table.insert(records, record)
  end

  write_records(records)
end

return module
