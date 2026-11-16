--- Eventtap controller handling modifier-click window move and resize.

local util = require("easymove.util")
local resizeMath = require("easymove.resize_math")
local log = require("easymove.log")

local Mover = {}
Mover.__index = Mover

local function isSnappableWindow(win, excluded)
  if not win then return false end
  local okStd, std = pcall(win.isStandard, win)
  if not okStd or not std then return false end
  if win:isFullScreen() or win:isMinimized() then return false end
  local app = win:application()
  if app and excluded[app:bundleID() or ""] then return false end
  return true
end

--- Find top-most standard window containing `pt`.
local function windowUnderPoint(pt, excluded)
  local front = hs.window.frontmostWindow()
  if front and isSnappableWindow(front, excluded) and util.rectContains(front:frame(), pt) then
    return front
  end
  for _, w in ipairs(hs.window.orderedWindows()) do
    if isSnappableWindow(w, excluded) and util.rectContains(w:frame(), pt) then
      return w
    end
  end
  return nil
end

function Mover.new(cfg, hud)
  local self = setmetatable({
    cfg = cfg,
    hud = hud,
    enabled = true,
    tap = nil,
    watchdog = nil,
    excluded = {},
    -- Gesture State
    active = false,
    mode = nil,        -- "move" | "resize"
    win = nil,
    startPt = nil,
    initialFrame = nil,
    corner = nil,      -- "tl" | "tr" | "bl" | "br"
  }, Mover)

  self:updateExcluded(cfg.excludedApps)
  return self
end

function Mover:updateExcluded(list)
  self.excluded = {}
  for _, id in ipairs(list or {}) do
    self.excluded[id] = true
  end
end

function Mover:start()
  if self.tap then return true end

  local T = hs.eventtap.event.types
  local events = {
    T.leftMouseDown, T.leftMouseDragged, T.leftMouseUp,
    T.rightMouseDown, T.rightMouseDragged, T.rightMouseUp,
  }

  self.tap = hs.eventtap.new(events, function(e)
    return self:_handleEvent(e)
  end)

  if self.enabled then
    self.tap:start()
  end

  -- Watchdog timer to revive tap if macOS disables it
  self.watchdog = hs.timer.doEvery(4.0, function()
    if self.enabled and self.tap and not self.tap:isEnabled() then
      log.w("eventtap was disabled by macOS; restarting")
      self.tap:start()
    end
  end)

  return self.tap:isEnabled()
end

function Mover:stop()
  self:_reset()
  if self.watchdog then self.watchdog:stop(); self.watchdog = nil end
  if self.tap then self.tap:stop(); self.tap = nil end
  if self.hud then self.hud:hide() end
end

function Mover:setEnabled(flag)
  self.enabled = flag and true or false
  if self.tap then
    if self.enabled then
      if not self.tap:isEnabled() then self.tap:start() end
    else
      self:_reset()
      if self.tap:isEnabled() then self.tap:stop() end
    end
  end
end

function Mover:isEnabled()
  return self.enabled
end

function Mover:_reset()
  self.active = false
  self.mode = nil
  self.win = nil
  self.startPt = nil
  self.initialFrame = nil
  self.corner = nil
  if self.hud then self.hud:hide() end
end

function Mover:_handleEvent(e)
  local t = e:getType()
  local T = hs.eventtap.event.types
  local flags = e:getFlags()
  local pt = e:location()

  -- Check if button matches Move or Resize
  local isLeft = (t == T.leftMouseDown or t == T.leftMouseDragged or t == T.leftMouseUp)
  local isRight = (t == T.rightMouseDown or t == T.rightMouseDragged or t == T.rightMouseUp)
  local isDown = (t == T.leftMouseDown or t == T.rightMouseDown)
  local isDrag = (t == T.leftMouseDragged or t == T.rightMouseDragged)
  local isUp = (t == T.leftMouseUp or t == T.rightMouseUp)

  -- 1. Mouse Button Down: Check if modifier is held to initiate gesture
  if isDown then
    if not util.hasModifiers(flags, self.cfg.modifiers) then
      return false -- Modifier not held, let normal click through
    end

    local mode
    if isLeft and self.cfg.moveButton == "left" then
      mode = "move"
    elseif isRight and self.cfg.resizeButton == "right" then
      mode = "resize"
    elseif isLeft and self.cfg.resizeButton == "left" then
      mode = "resize"
    elseif isRight and self.cfg.moveButton == "right" then
      mode = "move"
    end

    if not mode then return false end

    local win = windowUnderPoint(pt, self.excluded)
    if not win then return false end

    local frame = win:frame()
    if not frame then return false end

    if self.cfg.bringToFrontOnGrab then
      pcall(function() win:focus() end)
    end

    self.active = true
    self.mode = mode
    self.win = win
    self.startPt = { x = pt.x, y = pt.y }
    self.initialFrame = { x = frame.x, y = frame.y, w = frame.w, h = frame.h }

    if mode == "resize" then
      self.corner = resizeMath.quadrant(pt, self.initialFrame)
    else
      self.corner = nil
    end

    if self.hud then
      self.hud:update(mode, self.initialFrame, pt, self.corner)
    end

    return true -- Consume mouse-down so the target app doesn't click or select
  end

  -- 2. Mouse Dragged: Update window position or size 1:1
  if isDrag and self.active and self.win then
    local dx = pt.x - self.startPt.x
    local dy = pt.y - self.startPt.y
    local newFrame

    if self.mode == "move" then
      newFrame = resizeMath.calculateMove(self.initialFrame, dx, dy)
    elseif self.mode == "resize" then
      newFrame = resizeMath.calculateResize(
        self.initialFrame, dx, dy, self.corner,
        self.cfg.minWidth, self.cfg.minHeight
      )
    end

    if newFrame then
      pcall(function() self.win:setFrame(newFrame, 0) end)
      if self.hud then
        self.hud:update(self.mode, newFrame, pt, self.corner)
      end
    end

    return true -- Consume drag
  end

  -- 3. Mouse Up: End interaction cleanly
  if isUp and self.active then
    local win = self.win
    local finalFrame = self.win and self.win:frame()
    self:_reset()

    -- Safety pass: ensure window committed the final dimensions
    if win and finalFrame then
      hs.timer.doAfter(0.05, function()
        pcall(function() win:setFrame(finalFrame, 0) end)
      end)
    end

    return true -- Consume mouse-up so it doesn't trigger context menu or click
  end

  return false
end

return Mover
