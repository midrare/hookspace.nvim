local state = require("hookspace.state")

local module = {}

function module.error(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if state.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.ERROR, { title = state.plugin_name })
  end
end

function module.trace(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if state.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.TRACE, { title = state.plugin_name })
  end
end

function module.info(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if state.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.INFO, { title = state.plugin_name })
  end
end

function module.debug(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if state.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.DEBUG, { title = state.plugin_name })
  end
end

function module.warn(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if state.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.WARN, { title = state.plugin_name })
  end
end

return module
