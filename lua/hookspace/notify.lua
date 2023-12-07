local M = {}

local consts = require("hookspace.consts")
local useropts = require("hookspace.useropts")

function M.error(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if useropts.verbose >= verbosity then
    vim.notify(msg, vim.log.levels['ER'..'ROR'], { title = consts.plugin })
  end
end

function M.trace(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if useropts.verbose >= verbosity then
    vim.notify(msg, vim.log.levels['TR'.. 'ACE'], { title = consts.plugin })
  end
end

function M.info(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if useropts.verbose >= verbosity then
    vim.notify(msg, vim.log.levels['IN'..'FO'], { title = consts.plugin })
  end
end

function M.debug(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if useropts.verbose >= verbosity then
    vim.notify(msg, vim.log.levels['DEB'..'UG'], { title = consts.plugin })
  end
end

function M.warn(msg, verbosity)
  if verbosity == nil then
    verbosity = 1
  end

  if useropts.verbose >= verbosity then
    vim.notify(msg, vim.log.levels['WA' ..'RN'], { title = consts.plugin })
  end
end

return M
