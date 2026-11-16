--- Configuration defaults and normalization for EasyMove.

local M = {}

local MOD_ALIASES = {
  alt = "alt", option = "alt", opt = "alt", ["⌥"] = "alt",
  cmd = "cmd", command = "cmd", ["⌘"] = "cmd",
  ctrl = "ctrl", control = "ctrl", ["⌃"] = "ctrl",
  shift = "shift", ["⇧"] = "shift",
  fn = "fn",
}

function M.normalizeMods(mods)
  if type(mods) ~= "table" then return { "alt" } end
  local out = {}
  for _, m in ipairs(mods) do
    local key = string.lower(tostring(m))
    local canonical = MOD_ALIASES[key]
    if canonical then out[#out + 1] = canonical end
  end
  return #out > 0 and out or { "alt" }
end

function M.defaults()
  return {
    -- Modifier(s) to hold while clicking/dragging anywhere on a window.
    -- e.g. { "alt" } or { "cmd", "alt" } or { "ctrl" }
    modifiers = { "alt" },

    -- Mouse button mappings: "left", "right"
    moveButton = "left",
    resizeButton = "right",

    -- Minimum window dimensions allowed during resize
    minWidth = 160,
    minHeight = 100,

    -- Immediately raise the clicked window to the top level
    bringToFrontOnGrab = true,

    -- Visual feedback
    showHUD = true,          -- Frosted glass dimension pill (e.g. "1440 × 900")
    showCornerGlow = true,   -- Visual corner highlight showing the active resize corner

    -- List of bundle IDs to ignore
    excludedApps = {},

    -- Visual theme
    theme = {
      accent = "#0A84FF",     -- Apple System Blue
      hudBackground = { red = 0.08, green = 0.08, blue = 0.10, alpha = 0.88 },
      hudStroke = { red = 1.0, green = 1.0, blue = 1.0, alpha = 0.14 },
      hudText = { red = 0.98, green = 0.98, blue = 1.0, alpha = 1.0 },
      font = ".AppleSystemUIFont",
      fontSize = 13,
      cornerRadius = 8,
    },

    -- Menu bar item
    menubar = true,

    -- "debug", "info", "warning", "error"
    logLevel = "info",
  }
end

local function isArray(t)
  if type(t) ~= "table" then return false end
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n == #t
end

function M.merge(base, over)
  if type(over) ~= "table" then return base end
  local out = {}
  for k, v in pairs(base) do out[k] = v end
  for k, v in pairs(over) do
    if type(v) == "table" and type(out[k]) == "table" and not isArray(v) and not isArray(out[k]) then
      out[k] = M.merge(out[k], v)
    else
      out[k] = v
    end
  end
  return out
end

return M
