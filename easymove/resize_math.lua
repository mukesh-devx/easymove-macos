--- Pure geometry and quadrant calculations for window resizing.
--- Supports natural 9-region smart resizing (center, 4 edges, 4 corners).

local M = {}

--- Determine which region/anchor is being grabbed.
--- Returns "center", "l", "r", "t", "b", "tl", "tr", "bl", or "br".
function M.quadrant(clickPt, initialFrame)
  local relX = (clickPt.x - initialFrame.x) / initialFrame.w
  local relY = (clickPt.y - initialFrame.y) / initialFrame.h

  -- Outer 25% boundary zones
  local isFarLeft = relX < 0.25
  local isFarRight = relX > 0.75
  local isFarTop = relY < 0.25
  local isFarBottom = relY > 0.75

  -- 4 Corners (Explicit corner grabbing)
  if isFarLeft and isFarTop then return "tl" end
  if isFarRight and isFarTop then return "tr" end
  if isFarLeft and isFarBottom then return "bl" end
  if isFarRight and isFarBottom then return "br" end

  -- 4 Edges
  if isFarLeft then return "l" end
  if isFarRight then return "r" end
  if isFarTop then return "t" end
  if isFarBottom then return "b" end

  -- Center zone (middle 50%): Natural KDE/BTT style resize (drag right/down expands)
  return "center"
end

--- Calculate the new window rect given the initial frame, drag delta (dx, dy),
--- grabbed region, and minimum dimensions.
function M.calculateResize(initF, dx, dy, corner, minW, minH)
  local x, y, w, h = initF.x, initF.y, initF.w, initF.h

  if corner == "center" or corner == "br" then
    -- Anchor: Top-Left (x, y fixed; drag right/down expands)
    w = math.max(initF.w + dx, minW)
    h = math.max(initF.h + dy, minH)

  elseif corner == "r" then
    -- Anchor: Left edge (x, y, h fixed; width resizes right)
    w = math.max(initF.w + dx, minW)

  elseif corner == "b" then
    -- Anchor: Top edge (x, y, w fixed; height resizes down)
    h = math.max(initF.h + dy, minH)

  elseif corner == "l" then
    -- Anchor: Right edge (x + w, y, h fixed)
    local rawW = initF.w - dx
    if rawW >= minW then
      w = rawW
      x = initF.x + dx
    else
      w = minW
      x = (initF.x + initF.w) - minW
    end

  elseif corner == "t" then
    -- Anchor: Bottom edge (x, y + h, w fixed)
    local rawH = initF.h - dy
    if rawH >= minH then
      h = rawH
      y = initF.y + dy
    else
      h = minH
      y = (initF.y + initF.h) - minH
    end

  elseif corner == "bl" then
    -- Anchor: Top-Right (x + w, y fixed)
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
    -- Anchor: Bottom-Left (x, y + h fixed)
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
    -- Anchor: Bottom-Right (x + w, y + h fixed)
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
