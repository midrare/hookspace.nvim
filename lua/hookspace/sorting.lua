-- 2023/05/07

local modulename, _ = ...
local moduleroot = modulename:gsub("(.+)%..+", "%1")

local module = {}

---@alias Comparator function(any, any): integer

local function cloned(o)
  local o2 = o

  if type(o) == "table" then
    o2 = {}
    for k, v in pairs(o) do
      o2[k] = cloned(v)
    end
  end

  return o2
end

local function cmp_default(a, b)
  if a == b then
    return 0
  elseif a < b then
    return -1
  elseif a > b then
    return 1
  end
  return 0
end

local function pred_default(a)
  if a then
    return true
  end
  return false
end

---@param items any[] objects to compare
---@param cmp? Comparator how to compare items
---@param reverse? boolean order results greatest to smallest
module.sort = function(items, cmp, reverse)
  cmp = cmp or cmp_default
  for i = 1, #items - 1 do
    local a = items[i]
    local b = items[i + 1]
    local cmp_result = cmp(a, b)

    if (not reverse and cmp_result > 0) or (reverse and cmp_result < 0) then
      items[i] = b
      items[i + 1] = a
    end
  end
end


---@param items any[] objects to compare
---@param cmp? Comparator how to compare items
---@param reverse? boolean order results greatest to smallest
---@return any[] sorted a sorted clone of items
module.sorted = function(items, cmp, reverse)
  local results = cloned(items)
  module.sort(results, cmp, reverse)
  return results
end


---@param items any[] items to extract from
---@param pred? function(any): boolean true if should extract
---@param invert? boolean switch behavior of predicate
---@return any[] items all items satisfying the predicate
module.extract = function(items, pred, invert)
  pred = pred or pred_default
  invert = invert or false
  local results = {}
  local base = 1
  for i, item in ipairs(items) do
    items[i] = nil
    local is_match = pred(item)
    if (not invert and is_match) or (invert and not is_match) then
      table.insert(results, item)
    else
      items[base] = item
      base = base + 1
    end
  end
  return results
end


---@param items any[] items to filter
---@param pred? function(any): boolean true if should keep
---@param invert? boolean switch behavior of predicate
module.filter = function(items, pred, invert)
  invert = invert or false
  module.extract(items, pred, not invert)
end


---@param items any[] items to filter
---@param pred? function(o: any): boolean true if should keep
---@param invert? boolean switch behavior of predicate
module.filtered = function(items, pred, invert)
  local results = cloned(items)
  module.filter(results, pred, invert)
  return results
end


---@param items any[] items to uniqify
---@param cmp? function(a: any, b: any): boolean|integer true or 0 if same
module.uniqify = function(items, cmp)
  local b = 1
  for i1, e1 in ipairs(items) do
    items[i1] = nil

    local is_unique = true

    if i1 > 1 then
      for i2 = 1, i1 - 1 do
        local e2 = items[i2]
        local is_same = not cmp and e1 == e2

        if cmp then
          local ret = cmp(e1, e2)
          is_same = ret == 0 or (type(ret) ~= "number" and ret)
        end

        if is_same then
          is_unique = false
          break
        end
      end
    end

    if is_unique then
      items[b] = e1
      b = b + 1
    end
  end
end

---@param items any[] items to uniqify
---@param cmp? function(a: any, b: any): boolean|integer true or 0 if same
module.uniqified = function(items, cmp)
  local results = cloned(items)
  module.uniqify(results, cmp)
  return results
end

---@param items any[] items to transform
---@param f function(a: any): any transformation to apply
module.transform = function(items, f)
  for k, v in pairs(items) do
    items[k] = f(v)
  end
end

---@param items any[] items to transform
---@param f function(a: any): any transformation to apply
module.transformed = function(items, f)
  local results = cloned(items)
  module.transform(results, f)
  return results
end

---@param items any[] items to mutate
---@param f function(a: any) mutating function to apply
module.apply = function(items, f)
  for _, v in pairs(items) do
    f(v)
  end
end

---@param items any[] items to mutate
---@param f function(a: any) mutating function to apply
module.applied = function(items, f)
  local results = cloned(items)
  module.apply(results, f)
  return results
end

return module
