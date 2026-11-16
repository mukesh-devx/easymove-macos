--- Accessibility permission handling.

local log = require("easymove.log")

local M = {}

local pollTimer = nil

function M.hasAccessibility()
  return hs.accessibilityState() == true
end

function M.ensure(onGranted)
  if M.hasAccessibility() then
    onGranted()
    return
  end

  hs.accessibilityState(true) -- Trigger macOS prompt
  log.w("Accessibility permission required. Please allow Hammerspoon in System Settings.")

  if pollTimer then pollTimer:stop() end
  pollTimer = hs.timer.doEvery(1.0, function()
    if M.hasAccessibility() then
      pollTimer:stop()
      pollTimer = nil
      log.i("Accessibility permission granted.")
      onGranted()
    end
  end)
end

function M.cancel()
  if pollTimer then
    pollTimer:stop()
    pollTimer = nil
  end
end

return M
