local M = {}

local arrays = require("hookspace.luamisc.arrays")
local files = require("hookspace.luamisc.files")
local paths = require("hookspace.luamisc.paths")

local consts = require("hookspace.consts")

local function is_record_valid(record)
  return record.rootdir
    and type(record.rootdir) == "string"
    and (
      vim.fn.isdirectory(record.rootdir) == 1
      or vim.fn.filereadable(record.rootdir) == 1
    )
end

local function get_last_accessed(record)
  return record and record.last_accessed or 0
end

local function is_record_has_path(record, rootdir)
  local c = paths.canonical(record.rootdir)
  return rootdir == record.rootdir
    or rootdir == record.rootdir
    or rootdir == c
    or rootdir == c
end

local function cmp_last_accessed(rec1, rec2)
  if not rec1.last_accessed and not rec2.last_accessed then
    return 0
  elseif
    (rec1.last_accessed and not rec2.last_accessed)
    or (rec1.last_accessed < rec2.last_accessed)
  then
    return -1
  elseif
    (not rec1.last_accessed and rec2.last_accessed)
    or (rec1.last_accessed > rec2.last_accessed)
  then
    return 1
  end
  return 0
end

local function _read_records()
  local records = {}

  if vim.fn.filereadable(consts.historyfile) == 1 then
    records = files.read_json(consts.historyfile) or records
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
  files.write_json(consts.historyfile, records)
end

---@return record[] records workspace access records
function M.read_records()
  return _read_records()
end

---@return string[] rootdirs workspace root dirs
function M.read_root_dirs()
  local records = _read_records()
  arrays.transform(records, function(r)
    return r.rootdir
  end)
  return records
end

---@param rootdir string workspace root dir
function M.delete(rootdir)
  local records = _read_records()
  arrays.filter(records, function(r)
    return not is_record_has_path(r, rootdir)
  end)
  write_records(records)
end

---@param src string old workspace root dir
---@param dest string new workspace root dir
function M.move(src, dest)
  local records = _read_records()
  arrays.filter(records, function(r)
    return is_record_has_path(r, src)
  end)

  local canonical = paths.canonical(dest)
  arrays.apply(records, function(r)
    r.rootdir = canonical
  end)

  write_records(records)
end

---@param rootdir string workspace root dir
---@param timestamp integer last access timestamp
function M.update(rootdir, timestamp)
  local records = _read_records()

  local is_found = false
  for _, record in ipairs(records) do
    if is_record_has_path(record, rootdir) then
      record.last_accessed = timestamp
      is_found = true
    end
  end

  if not is_found then
    local canonical = paths.normpath(paths.normcase(rootdir))
    local record = { last_accessed = timestamp, rootdir = canonical }
    table.insert(records, record)
  end

  write_records(records)
end

return M
