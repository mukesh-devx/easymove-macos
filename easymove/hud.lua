--- Apple-style HUD overlay providing live feedback during window move and resize.

local HUD = {}
HUD.__index = HUD

local function parseHexColor(hex, alpha)
  hex = hex:gsub("#", "")
  local r = tonumber(hex:sub(1, 2), 16) / 255
  local g = tonumber(hex:sub(3, 4), 16) / 255
  local b = tonumber(hex:sub(5, 6), 16) / 255
  return { red = r, green = g, blue = b, alpha = alpha or 1.0 }
end

function HUD.new(cfg)
  local self = setmetatable({
    cfg = cfg,
    pillCanvas = nil,
    cornerCanvas = nil,
    visible = false,
    cornerVisible = false,
    lastText = nil,
    lastPillX = nil,
    lastPillY = nil,
    lastCornerX = nil,
    lastCornerY = nil,
  }, HUD)
  self:_initCanvases()
  return self
end

function HUD:_initCanvases()
  local pal = self.cfg.theme
  local accentColor = parseHexColor(pal.accent, 1.0)

  -- 1. Dimension Pill Canvas (Floats near cursor or above window)
  local pill = hs.canvas.new({ x = 0, y = 0, w = 140, h = 34 })
  pill:level(hs.canvas.windowLevels.overlay)
  pill:behavior({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })

  pill:replaceElements({
    -- Pill background with soft drop shadow and frosted border
    {
      id = "bg",
      type = "rectangle",
      action = "strokeAndFill",
      fillColor = pal.hudBackground,
      strokeColor = pal.hudStroke,
      strokeWidth = 1,
      roundedRectRadii = { xRadius = pal.cornerRadius, yRadius = pal.cornerRadius },
      frame = { x = 0, y = 0, w = "100%", h = "100%" },
    },
    -- Text icon / mode badge
    {
      id = "mode",
      type = "text",
      text = "⤡",
      textFont = pal.font,
      textSize = 14,
      textColor = accentColor,
      textAlignment = "left",
      frame = { x = 12, y = 8, w = 20, h = 20 },
    },
    -- Dimension text
    {
      id = "text",
      type = "text",
      text = "1920 × 1080",
      textFont = pal.font,
      textSize = pal.fontSize,
      textColor = pal.hudText,
      textAlignment = "center",
      frame = { x = 24, y = 8, w = 104, h = 20 },
    },
  })
  self.pillCanvas = pill

  -- 2. Corner Indicator Canvas (Glow bracket on the active corner during resize)
  local corner = hs.canvas.new({ x = 0, y = 0, w = 24, h = 24 })
  corner:level(hs.canvas.windowLevels.overlay)
  corner:behavior({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
  corner:replaceElements({
    {
      id = "dot",
      type = "circle",
      action = "fill",
      fillColor = accentColor,
      center = { x = 12, y = 12 },
      radius = 6,
    },
    {
      id = "ring",
      type = "circle",
      action = "stroke",
      strokeColor = { red = 1, green = 1, blue = 1, alpha = 0.8 },
      strokeWidth = 1.5,
      center = { x = 12, y = 12 },
      radius = 9,
    },
  })
  self.cornerCanvas = corner
end

--- Show or update the HUD during active move/resize.
function HUD:update(mode, frame, pt, corner)
  if not self.cfg.showHUD then return end

  local text, symbol
  if mode == "resize" then
    text = string.format("%d × %d", frame.w, frame.h)
    symbol = "⤡"
  else
    text = string.format("%d, %d", frame.x, frame.y)
    symbol = "✥"
  end

  if text ~= self.lastText then
    self.lastText = text
    self.pillCanvas:elementAttribute(2, "text", symbol)
    self.pillCanvas:elementAttribute(3, "text", text)
  end

  -- Calculate pill position (floats 24pt above cursor)
  local pillW, pillH = 136, 32
  local pillX = math.floor(pt.x - (pillW / 2) + 0.5)
  local pillY = math.floor(pt.y - pillH - 24 + 0.5)

  if pillX ~= self.lastPillX or pillY ~= self.lastPillY then
    self.lastPillX, self.lastPillY = pillX, pillY
    self.pillCanvas:topLeft({ x = pillX, y = pillY })
  end

  if not self.visible then
    self.pillCanvas:show(0.05)
    self.pillCanvas:bringToFront(true)
    self.visible = true
  end

  -- Update corner indicator for resize
  if mode == "resize" and corner and self.cfg.showCornerGlow then
    local cx, cy
    if corner == "tl" then
      cx, cy = frame.x - 12, frame.y - 12
    elseif corner == "tr" then
      cx, cy = frame.x + frame.w - 12, frame.y - 12
    elseif corner == "bl" then
      cx, cy = frame.x - 12, frame.y + frame.h - 12
    elseif corner == "l" then
      cx, cy = frame.x - 12, frame.y + (frame.h / 2) - 12
    elseif corner == "r" then
      cx, cy = frame.x + frame.w - 12, frame.y + (frame.h / 2) - 12
    elseif corner == "t" then
      cx, cy = frame.x + (frame.w / 2) - 12, frame.y - 12
    elseif corner == "b" then
      cx, cy = frame.x + (frame.w / 2) - 12, frame.y + frame.h - 12
    else
      -- "br" or "center"
      cx, cy = frame.x + frame.w - 12, frame.y + frame.h - 12
    end

    if cx ~= self.lastCornerX or cy ~= self.lastCornerY then
      self.lastCornerX, self.lastCornerY = cx, cy
      self.cornerCanvas:topLeft({ x = cx, y = cy })
    end

    if not self.cornerVisible then
      self.cornerCanvas:show(0.05)
      self.cornerCanvas:bringToFront(true)
      self.cornerVisible = true
    end
  else
    if self.cornerVisible then
      self.cornerCanvas:hide(0.08)
      self.cornerVisible = false
      self.lastCornerX = nil
      self.lastCornerY = nil
    end
  end
end

function HUD:hide()
  if self.visible then
    self.pillCanvas:hide(0.08)
    self.visible = false
    self.lastText = nil
    self.lastPillX = nil
    self.lastPillY = nil
  end
  if self.cornerVisible then
    self.cornerCanvas:hide(0.08)
    self.cornerVisible = false
    self.lastCornerX = nil
    self.lastCornerY = nil
  end
end

function HUD:destroy()
  if self.pillCanvas then self.pillCanvas:delete(); self.pillCanvas = nil end
  if self.cornerCanvas then self.cornerCanvas:delete(); self.cornerCanvas = nil end
  self.visible = false
  self.cornerVisible = false
end

return HUD
