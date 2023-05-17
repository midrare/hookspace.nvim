local M = {}

local consts = require("hookspace.consts")
local useropts = require("hookspace.useropts")

function M.error(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if useropts.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.ERROR, { title = consts.plugin })
  end
end

function M.trace(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if useropts.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.TRACE, { title = consts.plugin })
  end
end

function M.info(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if useropts.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.INFO, { title = consts.plugin })
  end
end

function M.debug(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if useropts.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.DEBUG, { title = consts.plugin })
  end
end

function M.warn(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if useropts.verbose >= verbosity then
    vim.notify(msg, vim.log.levels.WARN, { title = consts.plugin })
  end
end

return M
