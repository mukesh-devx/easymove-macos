--- Utility functions for EasyMove.

local M = {}

--- Check if the given flags match the configured modifier list.
--- Extra modifiers (e.g. CapsLock or fn) are tolerated.
function M.hasModifiers(flags, requiredMods)
  if not flags or not requiredMods or #requiredMods == 0 then return false end
  for _, mod in ipairs(requiredMods) do
    if not flags[mod] then return false end
  end
  return true
end

function M.clamp(val, minVal, maxVal)
  if val < minVal then return minVal end
  if val > maxVal then return maxVal end
  return val
end

function M.round(val)
  return math.floor(val + 0.5)
end

function M.rectContains(r, pt)
  return pt.x >= r.x and pt.x <= (r.x + r.w) and pt.y >= r.y and pt.y <= (r.y + r.h)
end

return M
