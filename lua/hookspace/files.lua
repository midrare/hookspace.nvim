-- 2023/05/09

local module = {}

local function dirname(filename)
  local d = filename:match('^(.*[\\/]).+$')
  if d ~= nil then
    d = d:match('^(.+)[\\/]+$') or d
  end
  return d
end

local function read_file(filepath)
  local fd = vim.loop.fs_open(filepath, 'r', 438)
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

local function write_file(filepath, content)
  if content == nil then
    content = ''
  end

  local dirpath = dirname(filepath)
  if dirpath then
    vim.fn.mkdir(dirpath, 'p')
  end

  local fd = vim.loop.fs_open(filepath, 'w', 438)
  if not fd then
    return
  end

  vim.loop.fs_write(fd, content, -1)
  vim.loop.fs_close(fd)
end

local function keys_from_str(o)
  local new_obj = {}
  for k, v in pairs(o) do
    if type(v) == 'table' then
      v = keys_from_str(v)
    end
    if type(k) == 'string' then
      local n = tonumber(k)
      if n ~= nil then
        k = n
      end
    end
    new_obj[k] = v
  end
  return new_obj
end

local function keys_to_str(o)
  local new_obj = {}
  for k, v in pairs(o) do
    if type(v) == 'table' then
      v = keys_to_str(v)
    end
    if type(k) ~= 'string' then
      k = tostring(k)
    end
    new_obj[k] = v
  end
  return new_obj
end

local function read_json(filepath)
  local result = nil

  if vim.fn.filereadable(filepath) == 1 then
    local plaintext = read_file(filepath)
    if plaintext then
      local json_ok, json = pcall(vim.fn.json_decode, plaintext)
      if json_ok then
        result = keys_from_str(json)
      end
    end
  end

  return result
end

local function write_json(filepath, data)
  assert(type(filepath) == 'string', 'filepath must be of type string')
  local data_with_str_keys = keys_to_str(data)
  local plaintext = vim.fn.json_encode(data_with_str_keys or {}) or ''
  vim.fn.mkdir(dirname(filepath), 'p')
  write_file(filepath, plaintext)
end


---@param filepath string path to file
---@return nil|any data file contents
function module.read_file(filepath)
  return read_file(filepath)
end

---@param filepath string path to file
---@param content nil|any data to write
function module.write_file(filepath, content)
  write_file(filepath, content)
end

---@param filepath string path to json file
---@return nil|any data parsed file contents
function module.read_json(filepath)
  return read_json(filepath)
end

---@param filepath string path to json file
---@param data nil|any data to encode as json and write
function module.write_json(filepath, data)
  write_json(filepath, data)
end

return module
