local _, addonTable = ...

addonTable = addonTable or {}

local UI = {}
addonTable.UI = UI

function UI.CreateMainFrame(opts)
  opts = opts or {}
  local minHeight = tonumber(opts.minHeight) or 200
  local parent = opts.parent or UIParent
  local isInCombat = opts.isInCombat or function()
    return InCombatLockdown and InCombatLockdown()
  end
  local onShownInGroup = opts.onShownInGroup or function() end
  local onShownNoGroup = opts.onShownNoGroup or function() end

  local frame = CreateFrame("Frame", "isiLiveMainFrame", parent)
  frame:SetSize(700, minHeight)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton", "RightButton")
  frame:SetScript("OnDragStart", function(self)
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
    frame:StartMoving()
  end)
  dragHandle:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SavePosition(frame)
  end)

  local function SetVisible(visible)
    if isInCombat() then
      pendingVisible = visible and true or false
      return
    end
    pendingVisible = nil
    if visible then
      if not frame:IsShown() then
        frame:Show()
      end
    else
      if frame:IsShown() then
        frame:Hide()
      end
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

    SetVisible(true)
    if isInGroup then
      onShownInGroup()
    else
      onShownNoGroup()
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
