local _, addonTable = ...

addonTable = addonTable or {}

local UI = {}
addonTable.UI = UI

function UI.CreateMainFrame(opts)
  opts = opts or {}
  local minHeight = tonumber(opts.minHeight) or 212
  local parent = opts.parent or UIParent
  local isInCombat = opts.isInCombat or function()
    return InCombatLockdown and InCombatLockdown()
  end
  local onShownInGroup = opts.onShownInGroup or function() end
  local onShownNoGroup = opts.onShownNoGroup or function() end

  local frame = CreateFrame("Frame", "isiLiveMainFrame", parent, "BackdropTemplate")
  frame:SetSize(780, minHeight)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if isInCombat() then
      return
    end
    self:StartMoving()
  end)
  frame:Hide()

  local pendingVisible = nil
  local pendingHeight = nil

  local function SavePosition(target)
    if not IsiLiveDB then
      IsiLiveDB = {}
    end
    local point, _, relativePoint, x, y = target:GetPoint()
    IsiLiveDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
  end

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if isInCombat() then
      return
    end
    SavePosition(self)
  end)

  local dragHandle = CreateFrame("Frame", nil, frame)
  dragHandle:SetPoint("TOPLEFT", 0, 0)
  dragHandle:SetPoint("TOPRIGHT", 0, 0)
  dragHandle:SetHeight(26)
  dragHandle:SetFrameStrata(frame:GetFrameStrata())
  dragHandle:SetFrameLevel(frame:GetFrameLevel() + 100)
  dragHandle:EnableMouse(true)
  dragHandle:RegisterForDrag("LeftButton")
  dragHandle:SetScript("OnDragStart", function()
    if isInCombat() then
      return
    end
    frame:StartMoving()
  end)
  dragHandle:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    if isInCombat() then
      return
    end
    SavePosition(frame)
  end)

  local function SetVisible(visible)
    if visible then
      if isInCombat() then
        pendingVisible = true
        return false
      end
      pendingVisible = nil
      if not frame:IsShown() then
        frame:Show()
        return true
      end
      return false
    else
      -- Closing must always be possible, even during combat.
      pendingVisible = nil
      if frame:IsShown() then
        frame:Hide()
        return true
      end
      return false
    end
  end

  local function SetHeightSafe(height)
    if isInCombat() then
      pendingHeight = height
      return
    end
    pendingHeight = nil
    frame:SetHeight(height)
  end

  local function ToggleVisibility(isInGroup)
    if frame:IsShown() then
      SetVisible(false)
      return
    end

    -- Hotkey open is intentionally blocked during combat.
    if isInCombat() then
      pendingVisible = nil
      return
    end

    local didShow = SetVisible(true)
    if didShow then
      if isInGroup then
        onShownInGroup()
      else
        onShownNoGroup()
      end
    end
  end

  local function ApplyStoredPosition(pos)
    if not pos then
      return
    end
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, parent, pos.relativePoint, pos.x, pos.y)
  end

  return {
    frame = frame,
    SetVisible = SetVisible,
    SetHeightSafe = SetHeightSafe,
    ToggleVisibility = ToggleVisibility,
    ApplyStoredPosition = ApplyStoredPosition,
    GetPendingVisible = function()
      return pendingVisible
    end,
    GetPendingHeight = function()
      return pendingHeight
    end,
  }
end
