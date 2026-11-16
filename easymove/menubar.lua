--- Native menu bar item for EasyMove.

local M = {}
M.__index = M

local function drawIcon(enabled)
  -- 18x18 template canvas for standard macOS menu bar item
  local c = hs.canvas.new({ x = 0, y = 0, w = 18, h = 18 })
  if not c then return nil end

  local strokeW = 1.4
  local strokeCol = { white = 0.0, alpha = 1.0 } -- Black template tints automatically

  -- Outer bounding box
  c[1] = {
    type = "rectangle",
    action = "stroke",
    strokeColor = strokeCol,
    strokeWidth = strokeW,
    roundedRectRadii = { xRadius = 3, yRadius = 3 },
    frame = { x = 2, y = 2, w = 14, h = 14 },
  }

  if enabled then
    -- Inner resize arrow glyph
    c[2] = {
      type = "segments",
      action = "stroke",
      strokeColor = strokeCol,
      strokeWidth = strokeW,
      coordinates = {
        { x = 9, y = 13 },
        { x = 13, y = 13 },
        { x = 13, y = 9 },
      },
    }
    c[3] = {
      type = "segments",
      action = "stroke",
      strokeColor = strokeCol,
      strokeWidth = strokeW,
      coordinates = {
        { x = 13, y = 13 },
        { x = 7, y = 7 },
      },
    }
  else
    -- Diagonal slash for disabled state
    c[2] = {
      type = "segments",
      action = "stroke",
      strokeColor = strokeCol,
      strokeWidth = strokeW,
      coordinates = {
        { x = 3, y = 3 },
        { x = 15, y = 15 },
      },
    }
  end

  local img = c:imageFromCanvas()
  c:delete()
  if img then img:template(true) end
  return img
end

function M.new(handlers)
  local self = setmetatable({
    handlers = handlers,
    item = hs.menubar.new(),
  }, M)
  self:refresh()
  return self
end

function M:refresh()
  if not self.item then return end
  local isEnabled = self.handlers.isEnabled()
  self.item:setIcon(drawIcon(isEnabled))
  self.item:setTooltip(isEnabled and "EasyMove: Active" or "EasyMove: Disabled")

  local modsStr = table.concat(self.handlers.cfg.modifiers, " + "):upper()

  self.item:setMenu({
    {
      title = "EasyMove",
      disabled = true,
    },
    {
      title = string.format("Hold %s to drag/resize anywhere", modsStr),
      disabled = true,
    },
    { title = "-" },
    {
      title = isEnabled and "✓ Enabled" or "Enable EasyMove",
      fn = function()
        self.handlers.setEnabled(not isEnabled)
        self:refresh()
      end,
    },
    { title = "-" },
    {
      title = "Reload Hammerspoon",
      fn = self.handlers.reload or hs.reload,
    },
  })
end

function M:delete()
  if self.item then
    self.item:delete()
    self.item = nil
  end
end

return M
