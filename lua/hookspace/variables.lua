local M = {}

local sep = vim.fn.has("win32") >= 1 and "\\" or "/"
local pathsep = vim.fn.has("win32") >= 1 and ";" or ":"


---@class pattern
---@field pattern string lua pattern to search for
---@field replace string|function replacement data

---@class match
---@field start integer start index of match
---@field stop integer stop index of match
---@field srcstr string original string
---@field matched string matched string
---@field pattern string search pattern
---@field replace string replacement string




---Which match starts closer to 0 and is longer?
---@param m1 nil|match first match
---@param m2 nil|match second match
---@return integer favor negative (m1 better), positive (m2 better), or zero
local function matchcmp(m1, m2)
  if m1 == nil and m2 ~= nil then
    return 1
  end
  if m1 ~= nil and m2 == nil then
    return -1
  end
  if m1 == nil and m2 == nil then
    return 0
  end

  assert(m1 ~= nil, 'logic error. should never trigger')
  assert(m2 ~= nil, 'logic error. should never trigger')

  if m1.start < m2.start or (m1.start <= m2.start
    and (m1.stop - m1.start) < (m2.stop - m2.start)) then
    return -1
  end

  if m2.start < m1.start or (m2.start <= m1.start
    and (m2.stop - m2.start) < (m1.stop - m1.start)) then
    return 1
  end

  return 0
end


---@param workspace workspace
---@param fix_pathsep boolean?
---@return pattern[] patterns
local function make_patterns(workspace, fix_pathsep)
  local pattern_and_replace = {
    {
      pattern = "{[Ee][Nn][Vv]:[%a_][%a%d_ ]-}",
      replace = function(match)
        local name = match:match("{[Ee][Nn][Vv]:(.*)}")
        return os.getenv(name) or ""
      end
    }, {
      pattern = "{[Rr][Oo][Oo][Tt][Dd][Ii][Rr]}",
      replace = workspace.rootdir()
    }, {
      pattern = "{[Dd][Aa][Tt][Aa][Dd][Ii][Rr]}",
      replace = workspace.datadir()
    }, {
      pattern = "{[Ll][Oo][Cc][Aa][Ll][Dd][Ii][Rr]}",
      replace = workspace.localdir()
    },
  }

  if fix_pathsep == true then
    -- UNIX: "/bin;/usr/bin" -> "/bin:/usr/bin"
    -- WIN32: "C:/bin:C:/ProgramData/bin" -> "C:/bin;C:/ProgramData/bin"
    table.insert(pattern_and_replace, {
      pattern = "[:;]",
      replace = function(match)
        local s = match.src:sub(1, match.stop + 1)
        if s:match("^%a:[\\/]$") or s:match("[^%a]%a:[\\/]$") then
          return match.matched
        end

        return pathsep
      end
    })
  end

  return pattern_and_replace
end


--- Find next instance of any of patterns in string
---@param value string search in
---@param patterns pattern[] patterns to find
---@param pos integer? index in string to start at
---@return match? match match found, if any
local function find_next(value, patterns, pos)
  local best = nil
  for _, p in ipairs(patterns) do
    local m = { pattern = p.pattern, replace = p.replace }
    m.start, m.stop = value:find(m.pattern, pos)
    if m.start ~= nil and m.stop ~= nil and matchcmp(best, m) > 0 then
      best = m
    end
  end

  return best
end



--- Replace next instance of any of the given patterns
---@param value string value to search in
---@param patterns pattern[] patterns to look for
---@param pos integer? index in value string at which to start
---@return string value, integer pos new value with next instance replaced
local function replace_next(value, patterns, pos)
  local best = find_next(value, patterns, pos)
  if not best then
    return value, #value + 1
  end

  local repstr = type(best.replace) == "function" and best.replace(best) or best.replace
  local newstr = value:sub(1, best.start - 1) .. repstr .. value:sub(best.stop + 1, #value)

  return newstr, best.start + #repstr
end


---@param value string string to search and replace within
---@param patterns pattern[] patterns to find and replace
---@return string value new value with all instances replaced
local function replace_all(value, patterns)
  -- only replace each pattern once (i.e. do not re-run on replaced string)
  local pos = 1
  while pos <= #value do
    value, pos = replace_next(value, patterns, pos)
  end

  return value
end


---@param o any
---@param workspace workspace
---@param fix_pathsep boolean?
local function replace_all_recursive(o, workspace, fix_pathsep)
  if type(o) == "string" then
    local patterns = make_patterns(workspace, fix_pathsep)
    o = replace_all(o, patterns)

    if fix_pathsep then
      o = o:gsub("[\\/]+", sep)
    end
  elseif type(o) == "table" then
    for k, _ in pairs(o) do
      fix_pathsep = false
      if type(k) == "string" and k:upper():match('PATH$') then
        fix_pathsep = true
      end

      o[k] = replace_all_recursive(o[k], workspace,fix_pathsep)
    end
  end

  return o
end


--- Replace all instances of `{datdir}` etc. with actual values
---@param value any will be mutated in-place
---@param workspace workspace workspace to draw replacement values from
---@return any value value with all placeholders replaced
function M.replace_workspace_variables(value, workspace)
  return replace_all_recursive(value, workspace)
end


return M
