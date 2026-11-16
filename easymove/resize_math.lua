--- Pure geometry and quadrant calculations for window resizing.

local M = {}

--- Determine which corner/quadrant is being grabbed.
--- Returns "tl", "tr", "bl", or "br".
function M.quadrant(clickPt, initialFrame)
  local relX = (clickPt.x - initialFrame.x) / initialFrame.w
  local relY = (clickPt.y - initialFrame.y) / initialFrame.h

  local isLeft = relX < 0.5
  local isTop = relY < 0.5

  if isLeft and isTop then return "tl" end
  if not isLeft and isTop then return "tr" end
  if isLeft and not isTop then return "bl" end
  return "br"
end

--- Calculate the new window rect given the initial frame, drag delta (dx, dy),
--- grabbed corner, and minimum dimensions.
function M.calculateResize(initF, dx, dy, corner, minW, minH)
  local x, y, w, h = initF.x, initF.y, initF.w, initF.h

  if corner == "br" then
    -- Anchor: Top-Left (x, y stays fixed)
    w = math.max(initF.w + dx, minW)
    h = math.max(initF.h + dy, minH)

  elseif corner == "bl" then
    -- Anchor: Top-Right (x + w stays fixed)
    local rawW = initF.w - dx
    if rawW >= minW then
      w = rawW
      x = initF.x + dx
    else
      w = minW
      x = (initF.x + initF.w) - minW
    end
    h = math.max(initF.h + dy, minH)

  elseif corner == "tr" then
    -- Anchor: Bottom-Left (x, y + h stays fixed)
    w = math.max(initF.w + dx, minW)
    local rawH = initF.h - dy
    if rawH >= minH then
      h = rawH
      y = initF.y + dy
    else
      h = minH
      y = (initF.y + initF.h) - minH
    end

  elseif corner == "tl" then
    -- Anchor: Bottom-Right (x + w, y + h stays fixed)
    local rawW = initF.w - dx
    if rawW >= minW then
      w = rawW
      x = initF.x + dx
    else
      w = minW
      x = (initF.x + initF.w) - minW
    end

    local rawH = initF.h - dy
    if rawH >= minH then
      h = rawH
      y = initF.y + dy
    else
      h = minH
      y = (initF.y + initF.h) - minH
    end
  end

  return {
    x = math.floor(x + 0.5),
    y = math.floor(y + 0.5),
    w = math.floor(w + 0.5),
    h = math.floor(h + 0.5),
  }
end

--- Calculate the new window rect when moving by (dx, dy).
function M.calculateMove(initF, dx, dy)
  return {
    x = math.floor(initF.x + dx + 0.5),
    y = math.floor(initF.y + dy + 0.5),
    w = initF.w,
    h = initF.h,
  }
end

return M
