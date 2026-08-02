local _, addonTable = ...

addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))
addonTable.UI = addonTable.UI or {}

local UI = addonTable.UI
local createRedCloseButton = assert(
  addonTable.UICommon and addonTable.UICommon.CreateRedCloseButton,
  "isiLive: UICommon.CreateRedCloseButton missing"
)
local GetLocalizedText =
  assert(addonTable.UICommon and addonTable.UICommon.GetLocalizedText, "isiLive: UICommon.GetLocalizedText missing")
local ApplyBackdrop = addonTable.UICommon.ApplyBackdrop
local ApplyActionButtonVisual = addonTable.UICommon.ApplyActionButtonVisual
local Colors = addonTable.UICommon.Colors

local function SavePosition(target)
  -- SavedVariables are restored by Blizzard before ADDON_LOADED and the main
  -- frame is :Hide()d until then, so this only ever runs once IsiLiveDB is a
  -- real table. Lazy-allocating IsiLiveDB here would race the SavedVariables
  -- restore and wipe other settings.
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return
  end
  local point, _, relativePoint, x, y = target:GetPoint()
  db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function ClampMovableFrameToScreen(frame)
  if type(frame) ~= "table" then
    return
  end
  if type(frame.SetClampedToScreen) == "function" then
    frame:SetClampedToScreen(true)
  end
  if type(frame.SetClampRectInsets) == "function" then
    frame:SetClampRectInsets(0, 0, 0, 0)
  end
end

local function CreateDragHandle(frame, isDragLocked, beginDrag, endDrag)
  local dragHandle = CreateFrame("Frame", nil, frame)
  dragHandle._grips = {}
  dragHandle._gripVisible = true
  dragHandle:SetPoint("TOPLEFT", 0, 0)
  dragHandle:SetPoint("TOPRIGHT", 0, 0)
  dragHandle:SetHeight(26)
  dragHandle:SetFrameStrata(frame:GetFrameStrata())
  dragHandle:SetFrameLevel(frame:GetFrameLevel() + 100)
  dragHandle:EnableMouse(true)
  dragHandle:RegisterForDrag("LeftButton")
  dragHandle:SetScript("OnDragStart", function()
    if type(isDragLocked) == "function" and isDragLocked() then
      return
    end
    if type(beginDrag) == "function" then
      beginDrag()
      return
    end
    frame:StartMoving()
  end)
  dragHandle:SetScript("OnDragStop", function()
    if type(endDrag) == "function" then
      endDrag()
      return
    end
    frame:StopMovingOrSizing()
    SavePosition(frame)
  end)

  function dragHandle:SetGripVisible(visible)
    self._gripVisible = visible ~= false
    for _, grip in ipairs(self._grips or {}) do
      if self._gripVisible then
        if type(grip.Show) == "function" then
          grip:Show()
        end
      else
        if type(grip.Hide) == "function" then
          grip:Hide()
        end
      end
    end
  end

  return dragHandle
end

local function CreateTitleBarIconButton(
  frame,
  dragHandle,
  xOffset,
  iconTexture,
  tooltipTitleKey,
  tooltipBodyKey,
  tooltipTitle,
  tooltipBody,
  onClick
)
  local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
  button:SetSize(20, 20)
  button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", xOffset, -2)
  button:SetFrameStrata(frame:GetFrameStrata())
  button:SetFrameLevel(dragHandle:GetFrameLevel() + 3)
  button:EnableMouse(true)
  button:RegisterForClicks("LeftButtonUp")

  if type(ApplyBackdrop) == "function" then
    ApplyBackdrop(button, "TITLE_BUTTON")
  end

  local icon = button:CreateTexture(nil, "OVERLAY")
  icon:SetSize(14, 14)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  icon:SetTexture(iconTexture)
  button.icon = icon

  local resolvedTooltipTitle = GetLocalizedText(tooltipTitleKey, tooltipTitle)
  local resolvedTooltipBody = GetLocalizedText(tooltipBodyKey, tooltipBody)

  button:SetScript("OnEnter", function()
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.SetOwner) == "function" then
      tooltip:SetOwner(button, "ANCHOR_LEFT")
      tooltip:AddLine(resolvedTooltipTitle)
      tooltip:AddLine(resolvedTooltipBody, 0.8, 0.8, 0.8)
      tooltip:Show()
    end
    if type(button.SetBackdropColor) == "function" then
      if type(ApplyActionButtonVisual) == "function" then
        ApplyActionButtonVisual(button, "title", "hover")
      end
    end
  end)
  button:SetScript("OnLeave", function()
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
    if type(button.SetBackdropColor) == "function" then
      if type(ApplyActionButtonVisual) == "function" then
        ApplyActionButtonVisual(button, "title", "default")
      end
    end
  end)
  button:SetScript("OnClick", function(self, mouseButton)
    if type(onClick) == "function" then
      onClick(self, mouseButton)
    end
  end)

  return button
end

local function CreateDragLockButton(frame, dragHandle, getDragLocked, setDragLocked)
  local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
  button:SetSize(20, 20)
  button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -2)
  button:SetFrameStrata(frame:GetFrameStrata())
  button:SetFrameLevel(dragHandle:GetFrameLevel() + 3)
  button:EnableMouse(true)
  button:RegisterForClicks("LeftButtonUp")

  local tooltipTitle = GetLocalizedText("TOOLTIP_LOCK_MAIN_FRAME_POSITION", "Lock main frame position")
  local tooltipBody = GetLocalizedText("TOOLTIP_LOCK_MAIN_FRAME_POSITION_HINT", "Left-click to toggle.")

  if type(ApplyBackdrop) == "function" then
    ApplyBackdrop(button, "TITLE_BUTTON")
  end

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  label:SetPoint("CENTER", button, "CENTER", 0, -1)
  label:SetText("L")

  local function UpdateVisual()
    local locked = type(getDragLocked) == "function" and getDragLocked() == true
    button._isLocked = locked
    if locked then
      label:SetTextColor(unpack(Colors.GOLD_MAINFRAME_LABEL))
    else
      label:SetTextColor(unpack(Colors.LIGHT_BLUE_MAINFRAME_LABEL))
    end
  end

  button:SetScript("OnEnter", function()
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.SetOwner) == "function" then
      tooltip:SetOwner(button, "ANCHOR_LEFT")
      tooltip:AddLine(tooltipTitle)
      tooltip:AddLine(tooltipBody, 0.8, 0.8, 0.8)
      tooltip:Show()
    end
    if type(button.SetBackdropColor) == "function" then
      if type(ApplyActionButtonVisual) == "function" then
        ApplyActionButtonVisual(button, "title", "hover")
      end
    end
  end)
  button:SetScript("OnLeave", function()
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
    if type(button.SetBackdropColor) == "function" then
      if type(ApplyActionButtonVisual) == "function" then
        ApplyActionButtonVisual(button, "title", "default")
      end
    end
  end)
  button:SetScript("OnClick", function()
    if type(setDragLocked) ~= "function" then
      return
    end
    local nextLocked = not (type(getDragLocked) == "function" and getDragLocked() == true)
    local db = rawget(_G, "IsiLiveDB")
    if type(db) == "table" then
      db.lockMainFramePosition = nextLocked
    end
    setDragLocked(nextLocked)
  end)

  button.UpdateVisual = UpdateVisual
  UpdateVisual()

  return button
end

local function CreateSettingsButton(frame, dragHandle, onOpenSettings)
  return CreateTitleBarIconButton(
    frame,
    dragHandle,
    -46,
    "Interface\\Icons\\INV_Misc_Gear_01",
    "TOOLTIP_OPEN_ISILIVE_SETTINGS",
    "TOOLTIP_OPEN_ISILIVE_SETTINGS_HINT",
    "Open isiLive settings",
    "Left-click to open the settings panel.",
    onOpenSettings
  )
end

local function CreateVisibilityController(frame, onShownInGroup, onShownNoGroup, isInCombat, isRaidGroup)
  local pendingVisible = nil

  local function SetVisible(visible)
    if visible and isRaidGroup and isRaidGroup() then
      return false
    end
    if isInCombat and isInCombat() then
      pendingVisible = visible and true or false
      return false
    end
    pendingVisible = nil

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
    if isRaidGroup and isRaidGroup() then
      if frame:IsShown() then
        SetVisible(false)
      end
      return
    end

    if isInCombat and isInCombat() then
      local wantVisible = not frame:IsShown()
      pendingVisible = wantVisible
      return
    end

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

  local function GetPendingVisible()
    return pendingVisible
  end

  local function ClearPendingVisible()
    pendingVisible = nil
  end

  return SetVisible, ToggleVisibility, GetPendingVisible, ClearPendingVisible
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

local function CreateWidthController(frame, isInCombat)
  local pendingWidth = nil
  local function SetWidthSafe(width)
    if isInCombat() then
      pendingWidth = width
      return
    end
    pendingWidth = nil
    frame:SetWidth(width)
  end
  local function GetPendingWidth()
    return pendingWidth
  end
  return SetWidthSafe, GetPendingWidth
end

function UI.CreateMainFrame(opts)
  opts = opts or {}
  local minHeight = tonumber(opts.minHeight) or 236
  local parent = opts.parent or UIParent
  local isInCombat = opts.isInCombat
    or function()
      local inCombatFn = rawget(_G, "InCombatLockdown")
      return type(inCombatFn) == "function" and inCombatFn() == true
    end
  local isRaidGroup = opts.isRaidGroup or function()
    return false
  end
  local isDragLocked = opts.isDragLocked or function()
    return true
  end
  local onShownInGroup = opts.onShownInGroup or function() end
  local onShownNoGroup = opts.onShownNoGroup or function() end
  local onOpenSettings = opts.onOpenSettings or function() end

  local frame = CreateFrame("Frame", "isiLiveMainFrame", parent, "BackdropTemplate")
  frame:SetSize(755, minHeight)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  ClampMovableFrameToScreen(frame)
  frame:EnableMouse(true)
  frame:Hide()

  local dragLocked = isDragLocked() == true
  local dragActive = false
  local lockButton = nil
  local positionChangedHandler = nil

  local function NotifyPositionChanged()
    if type(positionChangedHandler) == "function" then
      positionChangedHandler()
    end
  end

  local function BeginDrag()
    if dragLocked then
      return
    end
    dragActive = true
    frame:StartMoving()
  end

  local function EndDrag()
    if not dragActive then
      return
    end
    dragActive = false
    frame:StopMovingOrSizing()
    SavePosition(frame)
    NotifyPositionChanged()
  end

  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function()
    if dragLocked then
      return
    end
    BeginDrag()
  end)
  frame:SetScript("OnDragStop", function()
    EndDrag()
  end)

  local dragHandle = CreateDragHandle(frame, function()
    return dragLocked
  end, BeginDrag, EndDrag)

  local function SetDragLocked(locked)
    dragLocked = locked == true
    frame:SetMovable(not dragLocked)
    if frame.RegisterForDrag and frame.UnregisterForDrag then
      if dragLocked then
        frame:UnregisterForDrag("LeftButton")
      else
        frame:RegisterForDrag("LeftButton")
      end
    end
    if dragHandle and type(dragHandle.EnableMouse) == "function" then
      dragHandle:EnableMouse(not dragLocked)
    end
    if dragHandle and dragHandle.RegisterForDrag and dragHandle.UnregisterForDrag then
      if dragLocked then
        dragHandle:UnregisterForDrag("LeftButton")
      else
        dragHandle:RegisterForDrag("LeftButton")
      end
    end
    if dragLocked and dragActive then
      dragActive = false
      frame:StopMovingOrSizing()
      SavePosition(frame)
      NotifyPositionChanged()
    end
    if lockButton and type(lockButton.UpdateVisual) == "function" then
      lockButton:UpdateVisual()
    end
  end

  local closeButton = createRedCloseButton(frame, {
    point = { "TOPRIGHT", frame, "TOPRIGHT", -2, -2 },
    frameLevel = dragHandle:GetFrameLevel() + 2,
    tooltipTitleKey = "TOOLTIP_HIDE_ISILIVE",
    tooltipBodyKey = "TOOLTIP_HIDE_ISILIVE_HINT",
    tooltipTitle = "Hide isiLive",
    tooltipBody = "Press CTRL+F9 to re-open",
  })

  lockButton = CreateDragLockButton(frame, dragHandle, function()
    return dragLocked
  end, SetDragLocked)
  local settingsButton = CreateSettingsButton(frame, dragHandle, onOpenSettings)

  SetDragLocked(dragLocked)

  local SetVisible, ToggleVisibility, GetPendingVisible, ClearPendingVisible =
    CreateVisibilityController(frame, onShownInGroup, onShownNoGroup, isInCombat, isRaidGroup)
  local SetHeightSafe, GetPendingHeight = CreateHeightController(frame, isInCombat)
  local SetWidthSafe, GetPendingWidth = CreateWidthController(frame, isInCombat)

  local function ApplyStoredPosition(pos)
    if not pos then
      return
    end
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, parent, pos.relativePoint, pos.x, pos.y)
    NotifyPositionChanged()
  end

  local function ResetPosition()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
    SavePosition(frame)
    NotifyPositionChanged()
  end

  closeButton:SetScript("OnClick", function()
    frame:Hide()
    ClearPendingVisible()
  end)

  return {
    frame = frame,
    closeButton = closeButton,
    lockButton = lockButton,
    settingsButton = settingsButton,
    dragHandle = dragHandle,
    SetVisible = SetVisible,
    SetHeightSafe = SetHeightSafe,
    ToggleVisibility = ToggleVisibility,
    ApplyStoredPosition = ApplyStoredPosition,
    ResetPosition = ResetPosition,
    GetPendingHeight = GetPendingHeight,
    GetPendingVisible = GetPendingVisible,
    SetWidthSafe = SetWidthSafe,
    GetPendingWidth = GetPendingWidth,
    SetDragLocked = SetDragLocked,
    SetPositionChangedHandler = function(handler)
      positionChangedHandler = type(handler) == "function" and handler or nil
    end,
    GetDragLocked = function()
      return dragLocked
    end,
    SetDragGripVisible = function(visible)
      if dragHandle and type(dragHandle.SetGripVisible) == "function" then
        dragHandle:SetGripVisible(visible)
      end
    end,
  }
end
