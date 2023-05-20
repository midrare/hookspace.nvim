local M = {}

---@type boolean
M.autoload = false

---@type nil|hook|hook[]
M.on_init = {}

---@type nil|hook|hook[]
M.on_open = {}

---@type nil|hook|hook[]
M.on_close = {}

---@type integer
M.verbose = 1

return M
