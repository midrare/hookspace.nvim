local modulename, _ = ...
local moduleroot = modulename:gsub("(.+)%..+", "%1")

local file = require(moduleroot .. ".files")
local paths = require(moduleroot .. ".paths")
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

local function read_records(cmp, reverse)
  if cmp == nil then
    cmp = cmp_last_accessed
    reverse = true
  end

  local records = {}

  if vim.fn.filereadable(records_path) == 1 then
    records = file.read_json(records_path) or {}
    sorting.sort(records, cmp, reverse)
    sorting.filter(records, is_record_valid)
    sorting.uniqify(records, is_record_same)
  end

  return records
end

local function write_records(records)
  sorting.uniqify(records, is_record_same)
  sorting.sort(records, cmp_last_accessed, true)
  file.write_json(records_path, records)
end

---@return HookspaceRecord[] records workspace access records
function module.read_records()
  return read_records()
end

---@return string[] rootdirs workspace root dirs
function module.read_root_dirs()
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
---@param timestamp integer last access timestamp
function module.update(path, timestamp)
  local records = read_records()

  local is_found = false
  for _, record in ipairs(records) do
    if is_record_has_path(record, path) then
      record.last_accessed = timestamp
      is_found = true
    end
  end

  if not is_found then
    local canonical = paths.normpath(paths.normcase(path))
    local record = { last_accessed = timestamp, rootdir = canonical }
    table.insert(records, record)
  end

  write_records(records)
end

return module
