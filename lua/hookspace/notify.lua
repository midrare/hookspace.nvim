local modulename, _ = ...
local moduleroot = modulename:gsub('(.+)%..+', '%1')

local state = require(moduleroot .. '.state')

local M = {}

function M.error(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if state.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.ERROR, { title = state.plugin_name })
  end
end

function M.trace(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if state.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.TRACE, { title = state.plugin_name })
  end
end

function M.info(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if state.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.INFO, { title = state.plugin_name })
  end
end

function M.debug(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if state.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.DEBUG, { title = state.plugin_name })
  end
end

function M.warn(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if state.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.WARN, { title = state.plugin_name })
  end
end

return M
