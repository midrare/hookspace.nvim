local module = {}

local arrays = require("hookspace.luamisc.arrays")
local files = require("hookspace.luamisc.files")
local paths = require("hookspace.luamisc.paths")

local records_path = vim.fn.stdpath("data")
  .. paths.sep()
  .. "hookspace"
  .. paths.sep()
  .. "workspaces.json"

local function is_record_valid(r)
  return r.rootdir
    and type(r.rootdir) == "string"
    and (
      vim.fn.isdirectory(r.rootdir) == 1
      or vim.fn.filereadable(r.rootdir) == 1
    )
end

local function get_last_accessed(r)
  return r and r.last_accessed or 0
end

local function is_record_has_path(r, path)
  local c = paths.normpath(paths.normcase(r.rootdir))
  return path == r.rootdir or path == r.rootdir or path == c or path == c
end

local function cmp_last_accessed(r1, r2)
  if not r1.last_accessed and not r2.last_accessed then
    return 0
  elseif
    (r1.last_accessed and not r2.last_accessed)
    or (r1.last_accessed < r2.last_accessed)
  then
    return -1
  elseif
    (not r1.last_accessed and r2.last_accessed)
    or (r1.last_accessed > r2.last_accessed)
  then
    return 1
  end
  return 0
end

local function _read_records()
  local records = {}

  if vim.fn.filereadable(records_path) == 1 then
    records = files.read_json(records_path) or records
    table.sort(records, function(a, b)
      return cmp_last_accessed(a, b) > 0
    end)
    arrays.filter(records, is_record_valid)
    arrays.uniqify(records, get_last_accessed)
  end

  return records
end

local function write_records(records)
  arrays.uniqify(records, get_last_accessed)
  table.sort(records, function(a, b)
    return cmp_last_accessed(a, b) > 0
  end)
  files.write_json(records_path, records)
end

---@return record[] records workspace access records
function module.read_records()
  return _read_records()
end

---@return string[] rootdirs workspace root dirs
function module.read_root_dirs()
  local records = _read_records()
  arrays.transform(records, function(r)
    return r.rootdir
  end)
  return records
end

---@param path string workspace root dir
function module.delete(path)
  local records = _read_records()
  arrays.filter(records, function(r)
    return not is_record_has_path(r, path)
  end)
  write_records(records)
end

---@param old_path string old workspace root dir
---@param new_path string new workspace root dir
function module.move(old_path, new_path)
  local records = _read_records()
  arrays.filter(records, function(r)
    return is_record_has_path(r, old_path)
  end)

  local canonical = paths.normpath(paths.normcase(new_path))
  arrays.apply(records, function(r)
    r.rootdir = canonical
  end)

  write_records(records)
end

---@param path string workspace root dir
---@param timestamp integer last access timestamp
function module.update(path, timestamp)
  local records = _read_records()

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
