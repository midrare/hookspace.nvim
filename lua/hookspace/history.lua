local M = {}

local arrays = require("hookspace.luamisc.arrays")
local files = require("hookspace.luamisc.files")
local paths = require("hookspace.luamisc.paths")

local consts = require("hookspace.consts")

local function is_record_valid(record)
  if not record.rootdir or type(record.rootdir) ~= "string" then
    return false
  end

  local datadir = record.rootdir .. "/" .. consts.datadir_name
  return vim.fn.isdirectory(datadir) > 0 or vim.fn.filereadable(datadir) > 0
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

local function read_records()
  local records = {}

  if vim.fn.filereadable(consts.plugin_history) == 1 then
    records = files.read_json(consts.plugin_history) or records
    table.sort(records, function(a, b)
      return cmp_last_accessed(a, b) > 0
    end)
    arrays.filter(records, is_record_valid)
    arrays.uniqify(records, function(r) return r.rootdir end)
  end

  return records
end

local function write(records)
  arrays.uniqify(records, function(r) return r.rootdir end)
  table.sort(records, function(a, b)
    return cmp_last_accessed(a, b) > 0
  end)
  files.write_json(consts.plugin_history, records)
end

---@return record[] records workspace access records
function M.read_records()
  return read_records()
end

---@return string[] rootdirs workspace root dirs
function M.read_root_dirs()
  local records = read_records()
  arrays.transform(records, function(r)
    return r.rootdir
  end)
  return records
end

---@param rootdir string workspace root dir
function M.delete(rootdir)
  local records = read_records()
  arrays.filter(records, function(r)
    return not is_record_has_path(r, rootdir)
  end)
  write(records)
end

---@param src string old workspace root dir
---@param dest string new workspace root dir
function M.move(src, dest)
  local records = read_records()
  arrays.filter(records, function(r)
    return is_record_has_path(r, src)
  end)

  local canonical = paths.canonical(dest)
  arrays.apply(records, function(r)
    r.rootdir = canonical
  end)

  write(records)
end

---@param rootdir string workspace root dir
---@param timestamp integer last access timestamp
function M.touch(rootdir, timestamp)
  local records = read_records()

  local is_found = false
  for _, record in ipairs(records) do
    if is_record_has_path(record, rootdir) then
      record.last_accessed = timestamp
      is_found = true
    end
  end

  if not is_found then
    local canonical = paths.normpath(rootdir)
    local record = { last_accessed = timestamp, rootdir = canonical }
    table.insert(records, record)
  end

  write(records)
end

return M
