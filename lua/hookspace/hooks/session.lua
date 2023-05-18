local modulename, _ = ...
local M = {}

local default_opts = {}
---@diagnostic disable-next-line: unused-local
local user_opts = vim.deepcopy(default_opts)

local _ = nil
local bufdel = {}
_, bufdel.closebuffers = pcall(require, "close_buffers")
_, bufdel.bufdelete = pcall(require, "bufdelete")

local path_sep = "/"
if vim.fn.has("win32") > 0 then
  path_sep = "\\"
end

local function get_dirname(filename)
  local d = filename:match("^(.*[\\/]).+$")
  if d ~= nil then
    d = d:match("^(.+)[\\/]+$") or d
  end
  return d
end

local function write_session(filepath)
  local old_sessionoptions = vim.api.nvim_get_option("sessionoptions")
  vim.cmd([[set sessionoptions-=blank]])
  vim.cmd([[set sessionoptions-=options]])
  vim.cmd([[set sessionoptions+=tabpages]])

  vim.fn.mkdir(get_dirname(filepath), "p")
  local tmp_filepath = filepath .. vim.fn.getpid() .. ".tmp~"
  local status_ok, error_msg =
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(tmp_filepath))
  if status_ok then
    vim.fn.delete(filepath)
    vim.fn.rename(tmp_filepath, filepath)
  else
    vim.notify(
      'Failed to generate session file "' .. tmp_filepath .. '".',
      vim.log.levels.ERROR,
      { title = modulename }
    )
    if error_msg then
      vim.notify(error_msg, vim.log.levels.TRACE, { title = modulename })
    end
  end

  vim.fn.delete(tmp_filepath)
  vim.api.nvim_set_option("sessionoptions", old_sessionoptions)
end

local function close_buffer(bufnr)
  if bufdel.closebuffers then
    pcall(bufdel.closebuffers.delete, { type = bufnr })
  elseif bufdel.bufdelete then
    pcall(bufdel.bufdelete.bufdelete, bufnr, true)
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, "silent! bd! " .. bufnr)
  end
end

function M.setup(opts)
  ---@diagnostic disable-next-line: unused-local
  user_opts = vim.tbl_deep_extend("force", default_opts, opts)
end

function M.on_open(workspace)
  local session = workspace.localdir .. path_sep .. "Session.vim"
  local before = workspace.localdir .. path_sep .. "Before.vim"

  vim.fn.delete(before)
  write_session(before)

  vim.cmd("silent! %bdelete!")
  vim.cmd("silent! tabonly!")
  vim.cmd("silent! only!")
  vim.cmd("silent! enew!")

  if vim.fn.filereadable(session) >= 1 then
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, "silent! source " .. vim.fn.fnameescape(session))

    -- close buffers with non-existant files
    ---@diagnostic disable-next-line: param-type-mismatch
    for bufno = 1, vim.fn.bufnr("$") do
      if vim.fn.buflisted(bufno) == 1 then
        local p = vim.fn.expand("#" .. bufno .. ":p")
        if vim.fn.filereadable(p) <= 0 then
          close_buffer(bufno)
        end
      end
    end
  end
end

function M.on_close(workspace)
  local session = workspace.localdir .. path_sep .. "Session.vim"
  local before = workspace.localdir .. path_sep .. "Before.vim"

  write_session(session)

  vim.cmd("silent! %bdelete!")
  vim.cmd("silent! tabonly!")
  vim.cmd("silent! only!")
  vim.cmd("silent! enew!")

  if vim.fn.exists(":Alpha") then
    vim.cmd("silent! Alpha")
  elseif vim.fn.exists(":Dashboard") then
    vim.cmd("silent! Dashboard")
  elseif vim.fn.exists(":Startify") then
    vim.cmd("silent! Startify")
  elseif vim.fn.exists(":Startup") then
    vim.cmd("silent! Startup display")
  end

  if vim.fn.filereadable(before) >= 1 then
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, "silent! source " .. vim.fn.fnameescape(before))
    vim.fn.delete(before)
  end
end

return M
