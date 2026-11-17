--- Eventtap controller handling modifier-click window move and resize.
--- High-frequency eventtap tracking throttled to 120Hz display refresh.
--- Seamlessly integrated with FancyZones: hold Shift during Alt-Drag to snap into zones!

local util = require("easymove.util")
local resizeMath = require("easymove.resize_math")
local log = require("easymove.log")

local Mover = {}
Mover.__index = Mover

-- 8ms in nanoseconds (~120 FPS frame rate limit)
local THROTTLE_TICKS = 8000000

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

local function notifyStageLight(win, frame)
  local sl = package.loaded["stagelight"]
  if sl and sl.onWindowMoved then
    pcall(sl.onWindowMoved, win, frame)
  end
end

local function fastSetFrame(win, frame)
  local ok
  if win._setFrame then
    ok = pcall(win._setFrame, win, frame)
  else
    ok = pcall(win.setFrame, win, frame, 0)
  end
  notifyStageLight(win, frame)
  return ok
end

--- Query FancyZones overlay if FancyZones is active.
local function getFancyZonesOverlay()
  local ok, fz = pcall(require, "fancyzones")
  if not ok or not fz or not fz.isRunning or not fz.isRunning() then return nil end
  if not fz.isSnappingEnabled or not fz.isSnappingEnabled() then return nil end
  local _, fzState = debug.getupvalue(fz.start, 1)
  if fzState and fzState.overlay then
    return fzState.overlay
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
    mode = nil,            -- "move" | "resize"
    win = nil,
    startPt = nil,
    initialFrame = nil,
    corner = nil,          -- "center", "l", "r", "t", "b", "tl", "tr", "bl", "br"
    lastFrameTicks = 0,
    lastAppliedFrame = nil,
    axApp = nil,
    wasEnhanced = nil,
    -- FancyZones bridge
    fzActive = false,
    fzTarget = nil,
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
    T.flagsChanged,
  }

  self.tap = hs.eventtap.new(events, function(e)
    return self:_handleEvent(e)
  end)

  if self.enabled then
    self.tap:start()
  end

  -- Watchdog timer to revive tap if macOS temporarily disables it
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
  if self.fzActive then
    local fzOverlay = getFancyZonesOverlay()
    if fzOverlay then fzOverlay:hide() end
    self.fzActive = false
    self.fzTarget = nil
  end

  -- Restore AXEnhancedUserInterface if we temporarily disabled it
  if self.axApp and self.wasEnhanced then
    local ax = self.axApp
    pcall(function() ax.AXEnhancedUserInterface = true end)
    self.axApp = nil
    self.wasEnhanced = nil
  end

  self.active = false
  self.mode = nil
  self.win = nil
  self.startPt = nil
  self.initialFrame = nil
  self.corner = nil
  self.lastFrameTicks = 0
  self.lastAppliedFrame = nil
  if self.hud then self.hud:hide() end
end

function Mover:_apply(pt, flags)
  if not (self.active and self.win and self.initialFrame and self.startPt) then return end

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
    local last = self.lastAppliedFrame
    if not last or last.x ~= newFrame.x or last.y ~= newFrame.y or last.w ~= newFrame.w or last.h ~= newFrame.h then
      self.lastAppliedFrame = newFrame
      fastSetFrame(self.win, newFrame)
      if self.hud then
        self.hud:update(self.mode, newFrame, pt, self.corner)
      end
    end
  end

  -- FancyZones integration during window move
  if self.mode == "move" and flags then
    local wantSnap = flags.shift == true
    local fzOverlay = getFancyZonesOverlay()
    if fzOverlay then
      if wantSnap then
        if not self.fzActive then
          fzOverlay:show()
          self.fzActive = true
        end
        self.fzTarget = fzOverlay:update(pt)
      else
        if self.fzActive then
          fzOverlay:hide()
          self.fzActive = false
          self.fzTarget = nil
        end
      end
    end
  end
end

function Mover:_handleEvent(e)
  local t = e:getType()
  local T = hs.eventtap.event.types
  local flags = e:getFlags()
  local pt = e:location()

  -- Shift key pressed/released mid-drag
  if t == T.flagsChanged and self.active and self.mode == "move" then
    local curPt = hs.mouse.absolutePosition()
    self:_apply(curPt, flags)
    return false
  end

  -- Check if button matches Move or Resize
  local isLeft = (t == T.leftMouseDown or t == T.leftMouseDragged or t == T.leftMouseUp)
  local isRight = (t == T.rightMouseDown or t == T.rightMouseDragged or t == T.rightMouseUp)
  local isDown = (t == T.leftMouseDown or t == T.rightMouseDown)
  local isDrag = (t == T.leftMouseDragged or t == T.rightMouseDragged)
  local isUp = (t == T.leftMouseUp or t == T.rightMouseUp)

  -- 1. Mouse Button Down: Check if modifier is held to initiate gesture
  if isDown then
    if not util.hasModifiers(flags, self.cfg.modifiers) then
      return false -- Modifier not held, let normal click through to apps & FancyZones
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

    -- Disable AXEnhancedUserInterface temporarily to prevent Chromium/Electron 200ms resize animations
    local app = win:application()
    local axApp = app and hs.axuielement.applicationElement(app)
    self.axApp = axApp
    self.wasEnhanced = nil
    if axApp then
      local ok, val = pcall(function() return axApp.AXEnhancedUserInterface end)
      if ok and val == true then
        self.wasEnhanced = true
        pcall(function() axApp.AXEnhancedUserInterface = false end)
      end
    end

    -- Fast raise window without heavy AppKit focus context switch
    if self.cfg.bringToFrontOnGrab then
      pcall(function() win:raise() end)
    end

    self.active = true
    self.mode = mode
    self.win = win
    self.startPt = { x = pt.x, y = pt.y }
    self.initialFrame = { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
    self.lastFrameTicks = hs.timer.absoluteTime()
    self.lastAppliedFrame = self.initialFrame
    self.fzActive = false
    self.fzTarget = nil

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

  -- 2. Mouse Dragged: Update window position or size smoothly (capped at 120 FPS)
  if isDrag and self.active and self.win then
    local now = hs.timer.absoluteTime()
    if (now - self.lastFrameTicks) >= THROTTLE_TICKS then
      self.lastFrameTicks = now
      self:_apply(pt, flags)
    end
    return true -- Consume drag
  end

  -- 3. Mouse Up: End interaction cleanly
  if isUp and self.active then
    -- Commit final coordinates
    self:_apply(pt, flags)

    local win = self.win
    local target = self.fzTarget
    local wasFZ = self.fzActive
    local finalFrame = self.lastAppliedFrame or (win and win:frame())
    self:_reset()

    if wasFZ and target and win then
      -- Snapped into FancyZones zone!
      local rect = { x = target.rect.x, y = target.rect.y, w = target.rect.w, h = target.rect.h }
      fastSetFrame(win, rect)
    elseif win and finalFrame then
      fastSetFrame(win, finalFrame)
    end

    return true -- Consume mouse-up
  end

  return false
end

return Mover
