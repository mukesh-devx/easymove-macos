--- EasyMove for macOS (Hammerspoon)
---
--- Move and resize any window from ANYWHERE inside its body.
--- No more hunting for tiny 2-pixel borders on 4K/27-inch displays.
---
--- Usage in ~/.hammerspoon/init.lua:
---
---   local em = require("easymove")
---   em.start()
---
--- Public API:
---   em.start(config)            start with optional overrides
---   em.stop()                   tear down
---   em.setEnabled(bool)         toggle functionality
---   em.isEnabled()              current toggle state
---   em.isRunning()              whether module is running

local config = require("easymove.config")
local log = require("easymove.log")
local permissions = require("easymove.permissions")
local HUD = require("easymove.hud")
local Mover = require("easymove.mover")
local Menubar = require("easymove.menubar")

local M = { version = "1.0.0" }

local SETTING_ENABLED = "easymove.enabled"

local state = {}

function M.isRunning()
  return state.running == true
end

function M.start(userConfig)
  if state.running then M.stop() end

  local cfg = config.merge(config.defaults(), userConfig or {})
  cfg.modifiers = config.normalizeMods(cfg.modifiers)
  log.setLevel(cfg.logLevel)

  local hud = HUD.new(cfg)
  local mover = Mover.new(cfg, hud)

  local savedEnabled = hs.settings.get(SETTING_ENABLED)
  if savedEnabled == false then
    mover:setEnabled(false)
  end

  state = {
    running = true,
    cfg = cfg,
    hud = hud,
    mover = mover,
  }

  -- Menu bar integration
  if cfg.menubar then
    state.menubar = Menubar.new({
      cfg = cfg,
      isEnabled = function() return mover:isEnabled() end,
      setEnabled = M.setEnabled,
      reload = hs.reload,
    })
  end

  -- Spaces & Screen changes: ensure HUD does not leave orphaned canvases
  state.screenWatcher = hs.screen.watcher.new(function()
    if state.hud then state.hud:hide() end
  end)
  state.screenWatcher:start()

  local hasSpaces, spaces = pcall(require, "hs.spaces")
  if hasSpaces and spaces and spaces.watcher then
    state.spaceWatcher = spaces.watcher.new(function()
      if state.hud then state.hud:hide() end
    end)
    state.spaceWatcher:start()
  end

  -- Start event tap once Accessibility is granted
  permissions.ensure(function()
    mover:start()
    log.i("EasyMove", M.version, "started. Ready to move/resize windows.")
  end)

  return M
end

function M.stop()
  if not state.running then return end
  permissions.cancel()
  if state.screenWatcher then state.screenWatcher:stop() end
  if state.spaceWatcher then state.spaceWatcher:stop() end
  if state.mover then state.mover:stop() end
  if state.hud then state.hud:destroy() end
  if state.menubar then state.menubar:delete() end
  state = {}
  log.i("EasyMove stopped")
end

function M.setEnabled(flag)
  if not state.mover then return end
  flag = flag and true or false
  state.mover:setEnabled(flag)
  hs.settings.set(SETTING_ENABLED, flag)
  if state.menubar then state.menubar:refresh() end
  hs.alert.show(flag and "EasyMove enabled" or "EasyMove disabled", 1.2)
end

function M.isEnabled()
  return state.mover ~= nil and state.mover:isEnabled()
end

return M
