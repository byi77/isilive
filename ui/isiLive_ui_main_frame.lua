local _, addonTable = ...

addonTable = addonTable or {}

addonTable.UI = addonTable.UI or {}

local UI = addonTable.UI
local createCloseButton =
  assert(addonTable.UICommon and addonTable.UICommon.CreateCloseButton, "isiLive: UICommon.CreateCloseButton missing")
local GetLocalizedText =
  assert(addonTable.UICommon and addonTable.UICommon.GetLocalizedText, "isiLive: UICommon.GetLocalizedText missing")
local ApplyBackdrop = addonTable.UICommon.ApplyBackdrop
local ApplyActionButtonVisual = addonTable.UICommon.ApplyActionButtonVisual
local ApplyStateIcon = addonTable.UICommon.ApplyStateIcon
local Colors = addonTable.UICommon.Colors
local UNLOCKED_ICON_ALPHA = 0.5

-- UI scale bounds and step; the same values as the "UI scale" settings slider
-- and the uiScale field in core/isiLive_db_schema.lua.
local UI_SCALE_MIN = 0.5
local UI_SCALE_MAX = 2.0
local UI_SCALE_STEP = 0.05
local UI_SCALE_DEFAULT = 1.0

-- Resize grip in the bottom-right corner. Kept subtle: faded until hovered or
-- dragged, tinted with the cool title-bar colour instead of Blizzard's grey.
-- 12 px flush in the corner fits the bottom padding of every layout: in M+
-- the killtracker row ends exactly at the grip's top edge, in M / H / V the
-- corner holds only frame chrome (checked with tools/wowsim in all four).
local RESIZE_GRIP_SIZE = 12
local RESIZE_GRIP_IDLE_ALPHA = 0.45
local RESIZE_GRIP_ACTIVE_ALPHA = 1
local RESIZE_GRIP_TEXTURE_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local RESIZE_GRIP_TEXTURE_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"
local RESIZE_GRIP_TEXTURE_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"

local function ClampUiScale(scale)
  if scale < UI_SCALE_MIN then
    return UI_SCALE_MIN
  end
  if scale > UI_SCALE_MAX then
    return UI_SCALE_MAX
  end
  return scale
end

-- Rounds to the slider step and clamps. The string round-trip drops the float
-- noise of steps * 0.05, so a stored 1.15 compares equal to the slider's 1.15.
local function RoundUiScale(scale)
  local steps = math.floor(scale / UI_SCALE_STEP + 0.5)
  return ClampUiScale(tonumber(string.format("%.2f", steps * UI_SCALE_STEP)))
end
UI.RoundUiScale = RoundUiScale

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
  -- A UICommon state-icon key gets the shared texture plus the cool title-bar
  -- tint; anything else is a plain texture path.
  if type(ApplyStateIcon) == "function" and ApplyStateIcon(icon, iconTexture) then
    local tint = Colors and Colors.TEXT_SECTION
    if type(tint) == "table" and type(icon.SetVertexColor) == "function" then
      icon:SetVertexColor(tint[1], tint[2], tint[3])
    end
  else
    icon:SetTexture(iconTexture)
  end
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
  button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -2)
  button:SetFrameStrata(frame:GetFrameStrata())
  button:SetFrameLevel(dragHandle:GetFrameLevel() + 3)
  button:EnableMouse(true)
  button:RegisterForClicks("LeftButtonUp")

  local tooltipTitle = GetLocalizedText("TOOLTIP_LOCK_MAIN_FRAME_POSITION", "Lock main frame position")
  local tooltipBody = GetLocalizedText("TOOLTIP_LOCK_MAIN_FRAME_POSITION_HINT", "Left-click to toggle.")

  if type(ApplyBackdrop) == "function" then
    ApplyBackdrop(button, "TITLE_BUTTON")
  end

  -- Lock symbol instead of the former "L" letter: full strength while the
  -- frame is locked, desaturated and faded while it can be dragged.
  local icon = button:CreateTexture(nil, "OVERLAY")
  icon:SetSize(14, 14)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  if type(ApplyStateIcon) == "function" then
    ApplyStateIcon(icon, "lock")
  end
  button.icon = icon

  local function UpdateVisual()
    local locked = type(getDragLocked) == "function" and getDragLocked() == true
    button._isLocked = locked
    if type(icon.SetDesaturated) == "function" then
      icon:SetDesaturated(not locked)
    end
    if type(icon.SetAlpha) == "function" then
      icon:SetAlpha(locked and 1 or UNLOCKED_ICON_ALPHA)
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
    -52,
    "settings",
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
        -- Out of combat only (the combat branch above returns first): the
        -- window fades in instead of popping up. Reduced motion skips it.
        local uiCommon = addonTable.UICommon
        if type(uiCommon) == "table" and type(uiCommon.PlayAlphaTransition) == "function" then
          uiCommon.PlayAlphaTransition(frame, "mainFrameEntrance", {
            fromAlpha = 0,
            toAlpha = 1,
            duration = "normal",
          })
        end
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

  return SetVisible, ToggleVisibility, GetPendingVisible
end

-- Rule 168: every roster render asks for the frame height. The comparison
-- reads the frame's live size instead of a cached Lua value, because other
-- paths write the size directly (layout-mode width in roster_layout /
-- roster_panel, the initial SetSize); a cache would miss those writes and
-- skip a needed resize. Width/height are in the frame's own (unscaled) units,
-- so SetScale does not disturb the comparison.
local SIZE_EPSILON = 0.01

local function IsCurrentSize(current, wanted)
  return type(current) == "number" and type(wanted) == "number" and math.abs(current - wanted) < SIZE_EPSILON
end

local function CreateHeightController(frame, isInCombat)
  local pendingHeight = nil
  local function SetHeightSafe(height)
    if isInCombat() then
      pendingHeight = height
      return
    end
    pendingHeight = nil
    if type(frame.GetHeight) == "function" and IsCurrentSize(frame:GetHeight(), height) then
      return
    end
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
    if type(frame.GetWidth) == "function" and IsCurrentSize(frame:GetWidth(), width) then
      return
    end
    frame:SetWidth(width)
  end
  local function GetPendingWidth()
    return pendingWidth
  end
  return SetWidthSafe, GetPendingWidth
end

-- Cursor x in the parent's units. GetCursorPosition reports screen pixels;
-- dividing by the parent's effective scale (UIParent in production) puts the
-- mouse travel into the same units as the frame's on-screen width.
local function GetCursorXInParentUnits(parent)
  local getCursorPosition = rawget(_G, "GetCursorPosition")
  if type(getCursorPosition) ~= "function" then
    return nil
  end
  local cursorX = tonumber((getCursorPosition()))
  local scaleSource = parent
  if type(scaleSource) ~= "table" or type(scaleSource.GetEffectiveScale) ~= "function" then
    scaleSource = rawget(_G, "UIParent")
  end
  if not cursorX or type(scaleSource) ~= "table" or type(scaleSource.GetEffectiveScale) ~= "function" then
    return nil
  end
  local effectiveScale = tonumber(scaleSource:GetEffectiveScale())
  if not effectiveScale or effectiveScale <= 0 then
    return nil
  end
  return cursorX / effectiveScale
end

local function SetGripStateTexture(button, setterName, getterName, path, tint)
  if type(button[setterName]) ~= "function" then
    return
  end
  button[setterName](button, path)
  local texture = type(button[getterName]) == "function" and button[getterName](button) or nil
  if tint and type(texture) == "table" and type(texture.SetVertexColor) == "function" then
    texture:SetVertexColor(tint[1], tint[2], tint[3])
  end
end

-- Resize grip (bottom-right corner). Dragging scales the whole window (the
-- layouts have fixed widths, so the grip changes db.uiScale, not width or
-- height): newScale = startScale * (startWidth + mouseTravel) / startWidth,
-- clamped to the slider range and applied live with SetScale. The first real
-- change re-anchors the frame to TOPLEFT so that corner stays put. Release
-- rounds to the slider step and hands the value to deps.commitScale, the only
-- place that writes SavedVariables. Double-click returns to 100 %.
--
-- The main frame is protected in combat (secure children): a drag never
-- starts during lockdown, a running drag ends on PLAYER_REGEN_DISABLED via
-- EndForCombat, and every mouse move re-checks lockdown before SetScale.
local function CreateResizeGrip(frame, deps)
  local button = CreateFrame("Button", nil, frame)
  button:SetSize(RESIZE_GRIP_SIZE, RESIZE_GRIP_SIZE)
  button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  if type(button.SetFrameStrata) == "function" then
    button:SetFrameStrata(frame:GetFrameStrata())
  end
  if type(button.SetFrameLevel) == "function" then
    button:SetFrameLevel(frame:GetFrameLevel() + 100)
  end
  button:EnableMouse(true)
  if type(button.RegisterForClicks) == "function" then
    button:RegisterForClicks("LeftButtonUp")
  end
  local tint = Colors and Colors.TEXT_SECTION
  SetGripStateTexture(button, "SetNormalTexture", "GetNormalTexture", RESIZE_GRIP_TEXTURE_UP, tint)
  SetGripStateTexture(button, "SetPushedTexture", "GetPushedTexture", RESIZE_GRIP_TEXTURE_DOWN, tint)
  SetGripStateTexture(button, "SetHighlightTexture", "GetHighlightTexture", RESIZE_GRIP_TEXTURE_HIGHLIGHT, nil)

  local session = nil
  local locked = false
  local hovered = false

  local function UpdateAlpha()
    if type(button.SetAlpha) == "function" then
      button:SetAlpha((session or hovered) and RESIZE_GRIP_ACTIVE_ALPHA or RESIZE_GRIP_IDLE_ALPHA)
    end
  end

  local function HideTooltip()
    local tooltip = rawget(_G, "GameTooltip")
    if not tooltip or type(tooltip.Hide) ~= "function" then
      return
    end
    if type(tooltip.IsOwned) == "function" and not tooltip:IsOwned(button) then
      return
    end
    tooltip:Hide()
  end

  -- Ends the drag; commits the rounded value when the scale changed.
  local function Finish()
    local current = session
    if not current then
      return false
    end
    session = nil
    button:SetScript("OnUpdate", nil)
    UpdateAlpha()
    if current.liveScale == current.startScale then
      return false
    end
    deps.commitScale(RoundUiScale(current.liveScale))
    return true
  end

  local function OnUpdate()
    local current = session
    if not current then
      button:SetScript("OnUpdate", nil)
      return
    end
    if deps.isInCombat() then
      -- Lockdown already active: no SetScale; the commit queues the value.
      Finish()
      return
    end
    local cursorX = GetCursorXInParentUnits(deps.parent)
    if not cursorX then
      return
    end
    local travel = cursorX - current.startCursorX
    local scale = ClampUiScale(current.startScale * (current.startWidth + travel) / current.startWidth)
    if scale == current.liveScale then
      return
    end
    if not current.anchored then
      if not deps.anchorTopLeft() then
        return
      end
      current.anchored = true
    end
    deps.setLiveScale(scale)
    current.liveScale = scale
  end

  local function Begin()
    if session or locked or deps.isInCombat() then
      return false
    end
    local startScale = type(frame.GetScale) == "function" and tonumber(frame:GetScale()) or nil
    local width = type(frame.GetWidth) == "function" and tonumber(frame:GetWidth()) or nil
    local cursorX = GetCursorXInParentUnits(deps.parent)
    if not (startScale and startScale > 0 and width and width > 0 and cursorX) then
      return false
    end
    session = {
      startScale = startScale,
      -- On-screen width in parent units, the same units as the mouse travel.
      startWidth = width * startScale,
      startCursorX = cursorX,
      liveScale = startScale,
      anchored = false,
    }
    HideTooltip()
    button:SetScript("OnUpdate", OnUpdate)
    UpdateAlpha()
    return true
  end

  local function ResetToDefault()
    Finish()
    if locked or deps.isInCombat() then
      return false
    end
    local current = type(frame.GetScale) == "function" and tonumber(frame:GetScale()) or nil
    if current ~= UI_SCALE_DEFAULT then
      deps.anchorTopLeft()
    end
    deps.commitScale(UI_SCALE_DEFAULT)
    return true
  end

  button:SetScript("OnMouseDown", function(_, mouseButton)
    if mouseButton == nil or mouseButton == "LeftButton" then
      Begin()
    end
  end)
  button:SetScript("OnMouseUp", function()
    Finish()
  end)
  button:SetScript("OnDoubleClick", function()
    ResetToDefault()
  end)
  button:SetScript("OnHide", function()
    hovered = false
    Finish()
  end)
  button:SetScript("OnEnter", function()
    hovered = true
    UpdateAlpha()
    if session then
      return
    end
    local tooltip = rawget(_G, "GameTooltip")
    if tooltip and type(tooltip.SetOwner) == "function" then
      -- Resolved per hover, so a language switch needs no rebuild.
      local title = GetLocalizedText("TOOLTIP_RESIZE_MAIN_FRAME", "Window size")
      local hint = GetLocalizedText("TOOLTIP_RESIZE_MAIN_FRAME_HINT", "Drag to resize. Double-click: 100%.")
      tooltip:SetOwner(button, "ANCHOR_RIGHT")
      tooltip:AddLine(title)
      tooltip:AddLine(hint, 0.8, 0.8, 0.8)
      tooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function()
    hovered = false
    UpdateAlpha()
    HideTooltip()
  end)
  UpdateAlpha()

  local grip = { button = button }

  -- The lock owns the grip: locked hides it and ends a running drag.
  function grip.SetLocked(isLocked)
    locked = isLocked == true
    if locked then
      Finish()
      button:Hide()
    else
      button:Show()
    end
  end

  function grip.EndForCombat()
    return Finish()
  end

  function grip.IsResizing()
    return session ~= nil
  end

  return grip
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
  local onScaleCommitted = type(opts.onScaleCommitted) == "function" and opts.onScaleCommitted or nil

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
  -- Created further down (needs ApplyScale); SetDragLocked reaches it here.
  local resizeGrip = nil

  local function NotifyPositionChanged()
    if type(positionChangedHandler) == "function" then
      positionChangedHandler()
    end
  end

  -- The main frame parents secure buttons (ready check, role markers, world
  -- markers), so the client treats it as protected during combat lockdown:
  -- StartMoving, Show/Hide, SetScale and re-anchoring from addon code raise
  -- ADDON_ACTION_BLOCKED there and do not run. Drag is skipped in combat;
  -- visibility, scale and position changes are queued for PLAYER_REGEN_ENABLED.
  local function BeginDrag()
    if dragLocked or isInCombat() then
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
    if resizeGrip then
      resizeGrip.SetLocked(dragLocked)
    end
  end

  local closeButton = createCloseButton(frame, {
    point = { "TOPRIGHT", frame, "TOPRIGHT", -8, -2 },
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
  frame._isiLiveTitleBarButtons = { closeButton, lockButton, settingsButton }

  SetDragLocked(dragLocked)

  local SetVisible, ToggleVisibility, GetPendingVisible =
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

  -- SetPoint offsets are measured in the frame's own scale, so changing the
  -- scale alone multiplies the on-screen distance from the anchor by the same
  -- factor: a window parked away from the screen centre jumps as soon as the
  -- UI-scale slider moves. Rescaling the stored offsets by oldScale/newScale
  -- keeps the frame where the user put it. The corrected offsets are persisted
  -- right away, so the next login restores the same spot.
  local pendingScale = nil
  local pendingResetPosition = false

  -- Sets the scale and rescales the anchor offsets so the anchor point stays
  -- put on screen. Returns true when the offsets were rewritten. Callers make
  -- sure combat lockdown is not active.
  local function SetScaleAroundAnchor(newScale)
    local oldScale = nil
    if type(frame.GetScale) == "function" then
      oldScale = tonumber(frame:GetScale())
    end
    local point, relativePoint, x, y
    if type(frame.GetPoint) == "function" then
      point, _, relativePoint, x, y = frame:GetPoint()
    end

    frame:SetScale(newScale)

    if not (oldScale and oldScale > 0 and type(point) == "string" and tonumber(x) and tonumber(y)) then
      return false
    end
    if oldScale == newScale then
      return false
    end

    local factor = oldScale / newScale
    frame:ClearAllPoints()
    frame:SetPoint(point, parent, relativePoint or point, x * factor, y * factor)
    return true
  end

  local function ApplyScale(scale)
    local newScale = tonumber(scale)
    if not newScale or newScale <= 0 or type(frame.SetScale) ~= "function" then
      return false
    end
    if isInCombat() then
      pendingScale = newScale
      return false
    end
    pendingScale = nil

    if SetScaleAroundAnchor(newScale) then
      SavePosition(frame)
      NotifyPositionChanged()
    end
    return true
  end

  -- Re-anchors the frame to TOPLEFT of the parent without moving it, so a
  -- later scale change grows and shrinks the window away from its top-left
  -- corner. GetLeft/GetTop are in the frame's own (scaled) units; the
  -- parent's edges are converted into them. Fails closed (false) when the
  -- geometry is not readable yet.
  local function AnchorTopLeft()
    if
      type(frame.GetLeft) ~= "function"
      or type(frame.GetTop) ~= "function"
      or type(frame.GetScale) ~= "function"
      or type(parent) ~= "table"
      or type(parent.GetTop) ~= "function"
    then
      return false
    end
    local left = tonumber(frame:GetLeft())
    local top = tonumber(frame:GetTop())
    local scale = tonumber(frame:GetScale())
    local parentTop = tonumber(parent:GetTop())
    local parentLeft = type(parent.GetLeft) == "function" and tonumber(parent:GetLeft()) or 0
    if not (left and top and scale and scale > 0 and parentTop and parentLeft) then
      return false
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", left - parentLeft / scale, top - parentTop / scale)
    return true
  end

  -- Final value of a grip drag or double-click: persisted once, applied via
  -- ApplyScale (which queues it during combat lockdown) and handed to the
  -- settings panel. SavePosition only reads the anchor and writes the DB, so
  -- it is safe in combat and keeps the TOPLEFT anchor of a live drag.
  local function CommitGripScale(scale)
    local db = rawget(_G, "IsiLiveDB")
    if type(db) == "table" then
      db.uiScale = scale
    end
    ApplyScale(scale)
    SavePosition(frame)
    NotifyPositionChanged()
    if onScaleCommitted then
      onScaleCommitted(scale)
    end
  end

  resizeGrip = CreateResizeGrip(frame, {
    parent = parent,
    isInCombat = isInCombat,
    isLocked = function()
      return dragLocked
    end,
    anchorTopLeft = AnchorTopLeft,
    setLiveScale = SetScaleAroundAnchor,
    commitScale = CommitGripScale,
  })
  resizeGrip.SetLocked(dragLocked)

  local function ResetPosition()
    if isInCombat() then
      pendingResetPosition = true
      return false
    end
    pendingResetPosition = false
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
    SavePosition(frame)
    NotifyPositionChanged()
    return true
  end

  -- Drained by PLAYER_REGEN_ENABLED: scale first, so a queued reset centres
  -- the frame at its final scale.
  local function ApplyPendingGeometry()
    if isInCombat() then
      return
    end
    if pendingScale then
      ApplyScale(pendingScale)
    end
    if pendingResetPosition then
      ResetPosition()
    end
  end

  -- Routed through SetVisible so a click in combat is queued for the
  -- PLAYER_REGEN_ENABLED drain instead of issuing a blocked Hide().
  closeButton:SetScript("OnClick", function()
    SetVisible(false)
  end)

  return {
    frame = frame,
    closeButton = closeButton,
    lockButton = lockButton,
    settingsButton = settingsButton,
    dragHandle = dragHandle,
    resizeGrip = resizeGrip.button,
    -- PLAYER_REGEN_DISABLED: ends a running grip drag before lockdown starts.
    EndResizeForCombat = resizeGrip.EndForCombat,
    IsResizing = resizeGrip.IsResizing,
    SetVisible = SetVisible,
    SetHeightSafe = SetHeightSafe,
    ToggleVisibility = ToggleVisibility,
    ApplyStoredPosition = ApplyStoredPosition,
    ApplyScale = ApplyScale,
    ResetPosition = ResetPosition,
    ApplyPendingGeometry = ApplyPendingGeometry,
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
