local hookspace = require("hookspace")
local consts = require("hookspace.consts")
local useropts = require("hookspace.useropts")
local workspaces = require("hookspace.workspaces")

local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local conf = require("telescope.config")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local telescope = require("telescope")

local default_opts = {}
local global_opts = vim.tbl_deep_extend("force", {}, default_opts)

local function basename(filename)
  local bname, _ = filename:gsub("^.*[\\/](.+)[\\/]*", "%1")
  if not bname or #bname <= 0 then
    return nil
  end
  return bname
end

local function to_display(entry)
  local hls = {}
  local display = entry.metadata.name
  if not display and entry.rootdir then
    display = basename(entry.rootdir)
  end

  if entry.rootdir then
    local hl_start = #display + 1
    table.insert(hls, { { hl_start, hl_start + #entry.rootdir }, "Comment" })
    display = display .. " " .. entry.rootdir
  end

  return display, hls
end

local function to_entry(record)
  if
    not record
    or not record.rootdir
    or vim.fn.isdirectory(record.rootdir) < 1
  then
    return nil
  end
  local meta = workspaces.read_metadata(record.rootdir) or {}
  return {
    value = record.rootdir,
    metadata = meta,
    display = to_display,
    ordinal = meta and meta.name or basename(record.rootdir),
    rootdir = record.rootdir,
  }
end

local function open_picker(opts)
  pickers
    .new(opts, {
      prompt_title = opts.title or consts.plugin,
      finder = finders.new_table({
        results = hookspace.history(),
        entry_maker = to_entry,
      }),
      sorter = conf.values.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, map)
        map("i", "<c-space>", actions.to_fuzzy_refine)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = actions_state.get_selected_entry()
          if selection and selection.rootdir then
            if workspaces.is_open() then
              workspaces.close(os.time())
            end
            workspaces.open(selection.rootdir, os.time())
          end
        end)
        return true
      end,
    })
    :find()
end

return telescope.register_extension({
  setup = function(cfg)
    global_opts = vim.tbl_deep_extend("force", default_opts, cfg)
  end,
  exports = {
    hookspace = function(opts)
      opts = vim.tbl_deep_extend("force", global_opts, opts)
      open_picker(opts)
    end,
  },
})
