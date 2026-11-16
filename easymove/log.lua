--- Scoped logger for EasyMove.

local M = {}

local LEVELS = { debug = 1, info = 2, warning = 3, error = 4 }
local currentLevel = LEVELS.info

function M.setLevel(level)
  currentLevel = LEVELS[level] or LEVELS.info
end

local function log(minLvl, tag, ...)
  if currentLevel <= minLvl then
    local parts = { "[EasyMove]" }
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring(select(i, ...))
    end
    print(table.concat(parts, " "))
  end
end

function M.d(...) log(LEVELS.debug, "DEBUG", ...) end
function M.i(...) log(LEVELS.info, "INFO", ...) end
function M.w(...) log(LEVELS.warning, "WARN", ...) end
function M.e(...) log(LEVELS.error, "ERROR", ...) end

return M
