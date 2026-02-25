local _, addonTable = ...

addonTable = addonTable or {}

local UI = {}
addonTable.UI = UI
local createRedCloseButton = assert(
  addonTable.UICommon and addonTable.UICommon.CreateRedCloseButton,
  "isiLive: UICommon.CreateRedCloseButton missing"
)

local function SavePosition(target)
  if not IsiLiveDB then
    IsiLiveDB = {}
  end
  local point, _, relativePoint, x, y = target:GetPoint()
  IsiLiveDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function CreateDragHandle(frame)
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
  return dragHandle
end

local function CreateVisibilityController(frame, onShownInGroup, onShownNoGroup)
  local function SetVisible(visible)
    if visible then
      if not frame:IsShown() then
        frame:Show()
        return true
      end
      return false
    end

    if frame:IsShown() then
      frame:Hide()
      return true
    end
    return false
  end

  local function ToggleVisibility(isInGroup)
    if frame:IsShown() then
      SetVisible(false)
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

  return SetVisible, ToggleVisibility
end

local function CreateHeightController(frame, isInCombat)
  local pendingHeight = nil
  local function SetHeightSafe(height)
    if isInCombat() then
      pendingHeight = height
      return
    end
    pendingHeight = nil
    frame:SetHeight(height)
  end
  local function GetPendingHeight()
    return pendingHeight
  end
  return SetHeightSafe, GetPendingHeight
end

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
    self:StartMoving()
  end)
  frame:Hide()

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self)
  end)

  local dragHandle = CreateDragHandle(frame)

  local closeButton = createRedCloseButton(frame, {
    point = { "TOPRIGHT", frame, "TOPRIGHT", -2, -2 },
    frameLevel = dragHandle:GetFrameLevel() + 2,
  })

  local SetVisible, ToggleVisibility = CreateVisibilityController(frame, onShownInGroup, onShownNoGroup)
  local SetHeightSafe, GetPendingHeight = CreateHeightController(frame, isInCombat)

  local function ApplyStoredPosition(pos)
    if not pos then
      return
    end
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, parent, pos.relativePoint, pos.x, pos.y)
  end

  closeButton:SetScript("OnClick", function()
    SetVisible(false)
  end)

  return {
    frame = frame,
    closeButton = closeButton,
    SetVisible = SetVisible,
    SetHeightSafe = SetHeightSafe,
    ToggleVisibility = ToggleVisibility,
    ApplyStoredPosition = ApplyStoredPosition,
    GetPendingHeight = GetPendingHeight,
  }
end
