local modulename, _ = ...
local moduleroot = modulename:gsub("(.+)%..+", "%1")

local paths = require(moduleroot .. ".paths")
local hookspace = require("hookspace")
local state = require("hookspace.state")
local workspaces = require("hookspace.workspace")

local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local conf = require("telescope.config")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local telescope = require("telescope")

local default_opts = {}
local global_opts = vim.tbl_deep_extend("force", {}, default_opts)

local function to_display(entry)
  local hls = {}
  local display = entry.metadata.name
  if not display and entry.rootdir then
    display = paths.basename(entry.rootdir)
  end

  if entry.rootdir then
    local hl_start = #display + 1
    table.insert(hls, { { hl_start, hl_start + #entry.rootdir }, "Comment" })
    display = display .. " " .. entry.rootdir
  end

  return display, hls
end

local function open_picker(opts)
  pickers
    .new(opts, {
      prompt_title = opts.title or state.plugin_name,
      finder = finders.new_table({
        results = hookspace.read_history(),
        entry_maker = function(entry)
          if
            not entry
            or not entry.rootdir
            or vim.fn.isdirectory(entry.rootdir) < 1
          then
            return nil
          end
          local metadata = workspaces.read_metadata(entry.rootdir) or {}
          return {
            value = entry.rootdir,
            metadata = metadata,
            display = to_display,
            ordinal = metadata.name
              or paths.basename(entry.rootdir)
              or tostring(entry.last_accessed or 0),
            rootdir = entry.rootdir,
          }
        end,
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
