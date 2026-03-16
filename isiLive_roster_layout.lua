local _, addonTable = ...

addonTable = addonTable or {}

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI

-- Layout Konstanten
local LAYOUT_MODE_EXPANDED = "expanded"
local LAYOUT_MODE_COMPACT_VERTICAL = "compact_vertical"
local LAYOUT_MODE_COMPACT_HORIZONTAL = "compact_horizontal"
local FULL_FRAME_WIDTH = 755
local MINI_FRAME_WIDTH = 220
local MINI_HORIZONTAL_FRAME_WIDTH = 212
local MANAGEMENT_COLUMN_X = -145
local MANAGEMENT_COLUMN_X_MINI = -70
local HELPER_COLUMN_X = -111
local HELPER_COLUMN_X_MINI = -37
local MINI_HORIZONTAL_FRAME_HEIGHT = 94
local MINI_HORIZONTAL_MANAGEMENT_ROW_Y = -28
local MINI_HORIZONTAL_HELPER_ROW_Y = -64
local MINI_HORIZONTAL_MANAGEMENT_BTN_WIDTH = 60
local MINI_HORIZONTAL_MANAGEMENT_BTN_HEIGHT = 22
local MINI_HORIZONTAL_MANAGEMENT_BTN_GAP = 6
local HELPER_BUTTON_SIZE = 18
local MINI_HORIZONTAL_HELPER_BUTTON_SIZE = HELPER_BUTTON_SIZE
local MINI_HORIZONTAL_HELPER_GAP = 2
local DEFAULT_MIN_FRAME_HEIGHT = 236

local SYSTEM_OPTION_TOGGLE_LEFT_MARGIN = 10
local SYSTEM_OPTION_TOGGLE_BOTTOM_OFFSET = 24
local SYSTEM_OPTION_TOGGLE_GAP = 18

RI.LAYOUT_MODE_EXPANDED = LAYOUT_MODE_EXPANDED
RI.LAYOUT_MODE_COMPACT_VERTICAL = LAYOUT_MODE_COMPACT_VERTICAL
RI.LAYOUT_MODE_COMPACT_HORIZONTAL = LAYOUT_MODE_COMPACT_HORIZONTAL
RI.FULL_FRAME_WIDTH = FULL_FRAME_WIDTH
RI.MINI_FRAME_WIDTH = MINI_FRAME_WIDTH
RI.MINI_HORIZONTAL_FRAME_WIDTH = MINI_HORIZONTAL_FRAME_WIDTH
RI.MINI_HORIZONTAL_FRAME_HEIGHT = MINI_HORIZONTAL_FRAME_HEIGHT
RI.DEFAULT_MIN_FRAME_HEIGHT = DEFAULT_MIN_FRAME_HEIGHT
RI.MINI_HORIZONTAL_MANAGEMENT_ROW_Y = MINI_HORIZONTAL_MANAGEMENT_ROW_Y
RI.MINI_HORIZONTAL_HELPER_ROW_Y = MINI_HORIZONTAL_HELPER_ROW_Y
RI.MINI_HORIZONTAL_MANAGEMENT_BTN_WIDTH = MINI_HORIZONTAL_MANAGEMENT_BTN_WIDTH
RI.MINI_HORIZONTAL_MANAGEMENT_BTN_HEIGHT = MINI_HORIZONTAL_MANAGEMENT_BTN_HEIGHT
RI.MINI_HORIZONTAL_MANAGEMENT_BTN_GAP = MINI_HORIZONTAL_MANAGEMENT_BTN_GAP
RI.HELPER_BUTTON_SIZE = HELPER_BUTTON_SIZE
RI.MINI_HORIZONTAL_HELPER_BUTTON_SIZE = MINI_HORIZONTAL_HELPER_BUTTON_SIZE
RI.MINI_HORIZONTAL_HELPER_GAP = MINI_HORIZONTAL_HELPER_GAP
RI.MANAGEMENT_COLUMN_X = MANAGEMENT_COLUMN_X
RI.MANAGEMENT_COLUMN_X_MINI = MANAGEMENT_COLUMN_X_MINI
RI.HELPER_COLUMN_X = HELPER_COLUMN_X
RI.HELPER_COLUMN_X_MINI = HELPER_COLUMN_X_MINI
RI.SYSTEM_OPTION_TOGGLE_LEFT_MARGIN = SYSTEM_OPTION_TOGGLE_LEFT_MARGIN
RI.SYSTEM_OPTION_TOGGLE_BOTTOM_OFFSET = SYSTEM_OPTION_TOGGLE_BOTTOM_OFFSET
RI.SYSTEM_OPTION_TOGGLE_GAP = SYSTEM_OPTION_TOGGLE_GAP

-- Descriptor pro Layout-Modus: Breite und Label für den Mode-Button
local LAYOUT_MODE_CONFIG = {
  [LAYOUT_MODE_EXPANDED] = { width = FULL_FRAME_WIDTH, label = "M" },
  [LAYOUT_MODE_COMPACT_VERTICAL] = { width = MINI_FRAME_WIDTH, label = "V" },
  [LAYOUT_MODE_COMPACT_HORIZONTAL] = { width = MINI_HORIZONTAL_FRAME_WIDTH, label = "H" },
}
RI.LAYOUT_MODE_CONFIG = LAYOUT_MODE_CONFIG

-- Sichtbarkeitsregeln pro Layout-Modus: { ui-Key, M, V, H }
-- M = EXPANDED, V = COMPACT_VERTICAL, H = COMPACT_HORIZONTAL
local UI_VISIBILITY_RULES = {
  { "title", true, false, false },
  { "headerSepLeft", true, false, false },
  { "headerSepRight", true, false, false },
  { "versionLine", true, false, false },
  { "specHeader", true, false, false },
  { "nameHeader", true, false, false },
  { "ilvlHeader", true, false, false },
  { "serverHeader", true, false, false },
  { "keyHeader", true, false, false },
  { "rioHeader", true, false, false },
  { "dpsHeader", true, false, false },
  { "statusLine", true, false, false },
  { "mplusManagementHeader", true, false, false },
  { "shareKeysButton", true, true, false },
  { "refreshButton", true, true, false },
  { "leadOptionsHeader", true, true, false },
  { "tankHeader", true, true, false },
}
RI.UI_VISIBILITY_RULES = UI_VISIBILITY_RULES

local function IsCombatLockdownActive()
  return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end
RI.IsCombatLockdownActive = IsCombatLockdownActive

local function NormalizeLayoutMode(layoutMode)
  if layoutMode == LAYOUT_MODE_COMPACT_VERTICAL then
    return LAYOUT_MODE_COMPACT_VERTICAL
  end
  if layoutMode == LAYOUT_MODE_COMPACT_HORIZONTAL then
    return LAYOUT_MODE_COMPACT_HORIZONTAL
  end
  return LAYOUT_MODE_EXPANDED
end
RI.NormalizeLayoutMode = NormalizeLayoutMode

local function IsCompactLayoutMode(layoutMode)
  return NormalizeLayoutMode(layoutMode) ~= LAYOUT_MODE_EXPANDED
end
RI.IsCompactLayoutMode = IsCompactLayoutMode

local function IsHorizontalCompactLayoutMode(layoutMode)
  return NormalizeLayoutMode(layoutMode) == LAYOUT_MODE_COMPACT_HORIZONTAL
end
RI.IsHorizontalCompactLayoutMode = IsHorizontalCompactLayoutMode

local function GetFrameWidthForLayoutMode(layoutMode)
  local cfg = LAYOUT_MODE_CONFIG[NormalizeLayoutMode(layoutMode)]
  return cfg and cfg.width or FULL_FRAME_WIDTH
end
RI.GetFrameWidthForLayoutMode = GetFrameWidthForLayoutMode

local function GetFrameHeightForLayoutMode(layoutMode, minFrameHeight)
  if NormalizeLayoutMode(layoutMode) == LAYOUT_MODE_COMPACT_HORIZONTAL then
    return MINI_HORIZONTAL_FRAME_HEIGHT
  end
  return tonumber(minFrameHeight) or DEFAULT_MIN_FRAME_HEIGHT
end
RI.GetFrameHeightForLayoutMode = GetFrameHeightForLayoutMode

local DisableFontStringWrapping = RI.DisableFontStringWrapping or function(_fs) end

-- CVar helpers

local function ResolveGetCVar()
  local cvarAPI = rawget(_G, "C_CVar")
  if type(cvarAPI) == "table" and type(cvarAPI.GetCVar) == "function" then
    return cvarAPI.GetCVar
  end
  if type(_G.GetCVar) == "function" then
    return _G.GetCVar
  end
  return nil
end

local function ResolveSetCVar()
  local cvarAPI = rawget(_G, "C_CVar")
  if type(cvarAPI) == "table" and type(cvarAPI.SetCVar) == "function" then
    return cvarAPI.SetCVar
  end
  if type(_G.SetCVar) == "function" then
    return _G.SetCVar
  end
  return nil
end

local function ReadCVarEnabled(cvarName)
  if type(cvarName) ~= "string" or cvarName == "" then
    return false
  end
  local getCVar = ResolveGetCVar()
  if not getCVar then
    return false
  end
  local ok, value = pcall(getCVar, cvarName)
  if not ok then
    return false
  end
  return tostring(value or "") == "1"
end

local function WriteCVarEnabled(cvarName, enabled)
  if type(cvarName) ~= "string" or cvarName == "" then
    return false
  end
  local setCVar = ResolveSetCVar()
  if not setCVar then
    return false
  end
  local ok = pcall(setCVar, cvarName, enabled and "1" or "0")
  return ok
end

local function RefreshSystemOptionToggle(button)
  if type(button) ~= "table" or type(button._cvarName) ~= "string" then
    return false
  end
  local enabled = ReadCVarEnabled(button._cvarName)
  if button.SetChecked then
    button:SetChecked(enabled)
  end
  return enabled
end

local function CreateSystemOptionToggle(mainFrame, cvarName)
  local button = CreateFrame("CheckButton", nil, mainFrame, "UICheckButtonTemplate")
  button:SetSize(18, 18)
  button._cvarName = cvarName

  local label = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("LEFT", button, "RIGHT", 4, 0)
  label:SetJustifyH("LEFT")
  DisableFontStringWrapping(label)
  button.label = label

  button:SetScript("OnClick", function(self)
    local enabled = self.GetChecked and self:GetChecked() or false
    WriteCVarEnabled(self._cvarName, enabled)
    RefreshSystemOptionToggle(self)
  end)

  RefreshSystemOptionToggle(button)
  return button
end

local function LayoutSystemOptionToggles(ui)
  if type(ui) ~= "table" then
    return
  end

  local advancedCombatLoggingToggle = ui.advancedCombatLoggingToggle
  local damageMeterResetToggle = ui.damageMeterResetToggle

  if advancedCombatLoggingToggle and advancedCombatLoggingToggle.SetPoint then
    if advancedCombatLoggingToggle.ClearAllPoints then
      advancedCombatLoggingToggle:ClearAllPoints()
    end
    advancedCombatLoggingToggle:SetPoint(
      "BOTTOMLEFT",
      SYSTEM_OPTION_TOGGLE_LEFT_MARGIN,
      SYSTEM_OPTION_TOGGLE_BOTTOM_OFFSET
    )
  end

  if damageMeterResetToggle and damageMeterResetToggle.SetPoint then
    if damageMeterResetToggle.ClearAllPoints then
      damageMeterResetToggle:ClearAllPoints()
    end
    damageMeterResetToggle:SetPoint(
      "LEFT",
      advancedCombatLoggingToggle and advancedCombatLoggingToggle.label or nil,
      "RIGHT",
      SYSTEM_OPTION_TOGGLE_GAP,
      0
    )
  end
end

local function CreateSystemOptionToggles(mainFrame)
  local ui = {
    advancedCombatLoggingToggle = CreateSystemOptionToggle(mainFrame, "advancedCombatLogging"),
    damageMeterResetToggle = CreateSystemOptionToggle(mainFrame, "damageMeterResetOnNewInstance"),
  }

  LayoutSystemOptionToggles(ui)
  return ui
end
RI.CreateSystemOptionToggles = CreateSystemOptionToggles
RI.LayoutSystemOptionToggles = LayoutSystemOptionToggles

local function RefreshSystemOptionToggles(ui)
  if type(ui) ~= "table" then
    return
  end
  RefreshSystemOptionToggle(ui.advancedCombatLoggingToggle)
  RefreshSystemOptionToggle(ui.damageMeterResetToggle)
end
RI.RefreshSystemOptionToggles = RefreshSystemOptionToggles

local function AttachSystemOptionToggleWatcher(mainFrame, ui)
  local watcher = CreateFrame("Frame", nil, mainFrame)
  local elapsedSinceRefresh = 0

  watcher:SetScript("OnUpdate", function(_, elapsed)
    local isShown = true
    if type(mainFrame) == "table" and type(mainFrame.IsShown) == "function" then
      isShown = mainFrame:IsShown()
    end
    if not isShown then
      elapsedSinceRefresh = 0
      return
    end

    elapsedSinceRefresh = elapsedSinceRefresh + (tonumber(elapsed) or 0)
    if elapsedSinceRefresh < 5 then
      return
    end

    elapsedSinceRefresh = 0
    RefreshSystemOptionToggles(ui)
  end)

  ui.systemOptionWatcher = watcher
end
RI.AttachSystemOptionToggleWatcher = AttachSystemOptionToggleWatcher

-- Shared small utility also used by UpdateCollapseState
local function SetFlatButtonText(btn, text)
  if type(btn) == "table" and btn._flatLabel and btn._flatLabel.SetText then
    btn._flatLabel:SetText(tostring(text or ""))
  end
  if type(btn) == "table" and type(btn.SetText) == "function" then
    btn:SetText(tostring(text or ""))
  end
end
RI.SetFlatButtonText = SetFlatButtonText

local function GetHorizontalHelperButtonX(markerIndex)
  local helperRowWidth = (8 * MINI_HORIZONTAL_HELPER_BUTTON_SIZE) + (7 * MINI_HORIZONTAL_HELPER_GAP)
  local leftInset = math.floor((MINI_HORIZONTAL_FRAME_WIDTH - helperRowWidth) / 2)
  local rightEdge = leftInset
    + MINI_HORIZONTAL_HELPER_BUTTON_SIZE
    + ((markerIndex - 1) * (MINI_HORIZONTAL_HELPER_BUTTON_SIZE + MINI_HORIZONTAL_HELPER_GAP))
  return rightEdge - MINI_HORIZONTAL_FRAME_WIDTH
end
RI.GetHorizontalHelperButtonX = GetHorizontalHelperButtonX

local function UpdateColumnPositions(ui, layoutMode)
  layoutMode = NormalizeLayoutMode(layoutMode)
  local isCollapsed = IsCompactLayoutMode(layoutMode)
  local isHorizontal = IsHorizontalCompactLayoutMode(layoutMode)
  local tankX = isCollapsed and HELPER_COLUMN_X_MINI or HELPER_COLUMN_X
  local leadX = isCollapsed and MANAGEMENT_COLUMN_X_MINI or MANAGEMENT_COLUMN_X
  local managementButtons = ui.managementButtons or {}

  if ui.tankButtons then
    for _, btn in ipairs(ui.tankButtons) do
      if isHorizontal then
        local markerIndex = tonumber(btn._markerIndex) or 1
        local x = GetHorizontalHelperButtonX(markerIndex)
        btn:SetPoint("TOPRIGHT", x, MINI_HORIZONTAL_HELPER_ROW_Y)
      else
        local y = tonumber(btn._verticalY) or 0
        btn:SetPoint("TOPRIGHT", tankX, y)
      end
    end
  end

  if ui.tankHeader then
    if isHorizontal then
      ui.tankHeader:SetPoint("TOPRIGHT", -10, -34)
    elseif ui.tankHeader.GetPoint then
      local _, _, _, _, y = ui.tankHeader:GetPoint()
      local headerXOffset = isCollapsed and 30 or 18
      ui.tankHeader:SetPoint("TOPRIGHT", tankX + headerXOffset, y or 0)
    end
  end

  -- In H-Modus: alle Management-Buttons nebeneinander (rechts nach links)
  -- In M/V-Modus: jeder Button an seiner vertikalen Position in der Spalte
  for index, btn in ipairs(managementButtons) do
    if btn and btn.GetPoint then
      if isHorizontal then
        local x = -(10 + (index - 1) * (MINI_HORIZONTAL_MANAGEMENT_BTN_WIDTH + MINI_HORIZONTAL_MANAGEMENT_BTN_GAP))
        btn:SetPoint("TOPRIGHT", x, MINI_HORIZONTAL_MANAGEMENT_ROW_Y)
      else
        local y = tonumber(btn._verticalY) or 0
        btn:SetPoint("TOPRIGHT", leadX, y)
      end
    end
  end

  for _, btn in ipairs(ui.columnButtons or {}) do
    if btn and btn.GetPoint then
      local y = tonumber(btn._verticalY) or 0
      btn:SetPoint("TOPRIGHT", leadX, y)
    end
  end

  if ui.leadOptionsHeader and ui.leadOptionsHeader.GetPoint then
    if isHorizontal then
      ui.leadOptionsHeader:SetPoint("TOPRIGHT", -10, -34)
    else
      local _, _, _, _, y = ui.leadOptionsHeader:GetPoint()
      ui.leadOptionsHeader:SetPoint("TOPRIGHT", leadX, y)
    end
  end
end

local function UpdateCollapseState(ui, layoutMode, mainFrame)
  layoutMode = NormalizeLayoutMode(layoutMode or (ui and ui.layoutMode))
  local isCollapsed = IsCompactLayoutMode(layoutMode)
  local isHorizontal = IsHorizontalCompactLayoutMode(layoutMode)

  if type(ui) == "table" then
    ui.layoutMode = layoutMode
    ui.isCollapsed = isCollapsed
  end

  if mainFrame.SetWidth then
    mainFrame:SetWidth(GetFrameWidthForLayoutMode(layoutMode))
  end
  if type(ui) == "table" and type(ui.setMainFrameHeightSafe) == "function" then
    ui.setMainFrameHeightSafe(GetFrameHeightForLayoutMode(layoutMode, ui.minFrameHeight))
  end

  -- Mode-Buttons: aktiver Modus gold hervorheben, inaktive grau
  for _, btn in ipairs(ui.modeButtons or {}) do
    local isActive = btn._modeTarget == layoutMode
    if btn.label and btn.label.SetTextColor then
      if isActive then
        btn.label:SetTextColor(1, 0.85, 0)
      else
        btn.label:SetTextColor(0.5, 0.5, 0.5)
      end
    end
  end

  -- Management-Buttons in H-Modus verkleinern und Kurztext setzen
  for _, btn in ipairs(ui.managementButtons or {}) do
    if btn and btn.SetSize then
      if isHorizontal then
        btn:SetSize(MINI_HORIZONTAL_MANAGEMENT_BTN_WIDTH, MINI_HORIZONTAL_MANAGEMENT_BTN_HEIGHT)
        if btn._hModeText then
          SetFlatButtonText(btn, btn._hModeText)
        end
      else
        btn:SetSize(120, 24)
        if btn._fullText then
          SetFlatButtonText(btn, btn._fullText)
        end
      end
    end
  end

  UpdateColumnPositions(ui, layoutMode)

  local function SetVisible(obj, show)
    if obj and obj.SetShown then
      obj:SetShown(show)
    elseif obj and show and obj.Show then
      obj:Show()
    elseif obj and not show and obj.Hide then
      obj:Hide()
    end
  end

  -- Sichtbarkeit nach deklarativer Tabelle: Spalten 2/3/4 = M/V/H
  local modeCol = isHorizontal and 4 or (isCollapsed and 3 or 2)
  for _, rule in ipairs(UI_VISIBILITY_RULES) do
    SetVisible(ui[rule[1]], rule[modeCol])
  end

  local show = not isCollapsed
  if ui.advancedCombatLoggingToggle then
    SetVisible(ui.advancedCombatLoggingToggle, show)
    SetVisible(ui.advancedCombatLoggingToggle.label, show)
  end
  if ui.damageMeterResetToggle then
    SetVisible(ui.damageMeterResetToggle, show)
    SetVisible(ui.damageMeterResetToggle.label, show)
  end

  if ui.memberRows then
    for _, row in pairs(ui.memberRows) do
      SetVisible(row.spec, show)
      SetVisible(row.name, show)
      SetVisible(row.ilvl, show)
      SetVisible(row.key, show)
      SetVisible(row.rio, show)
      SetVisible(row.dps, show)
      SetVisible(row.realm, show)
      if row.roleButton and not IsCombatLockdownActive() then
        SetVisible(row.roleButton, show and row.unit ~= nil)
      end
      if row.hoverFrame and row.hoverFrame.EnableMouse then
        row.hoverFrame:EnableMouse(show)
      end
    end
  end
end
RI.UpdateCollapseState = UpdateCollapseState

local function NotifyCollapseChanged(ui, isCollapsed)
  if type(ui) == "table" and type(ui.onCollapseChanged) == "function" then
    ui.onCollapseChanged(isCollapsed and true or false)
  end
end
RI.NotifyCollapseChanged = NotifyCollapseChanged

-- Erstellt einen der drei statischen Mode-Buttons [M][V][H].
-- _modeTarget und _collapseLayoutMode identifizieren den Button für Tests.
-- Aktiv/Inaktiv-Zustand wird per Textfarbe in UpdateCollapseState gesetzt.
local function CreateModeButton(mainFrame, xOffset, modeLabel, modeTarget, onClick)
  local btn = CreateFrame("Button", nil, mainFrame)
  btn:SetSize(20, 20)
  btn:SetPoint("TOPRIGHT", xOffset, -2)
  -- DragHandle liegt auf mainFrame:GetFrameLevel() + 100; Button muss darüber liegen.
  if btn.SetFrameLevel and mainFrame.GetFrameLevel then
    btn:SetFrameLevel(mainFrame:GetFrameLevel() + 102)
  end
  if btn.SetHighlightTexture then
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
  end
  if type(btn.CreateFontString) == "function" then
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", 0, 0)
    if label.GetFont and label.SetFont then
      local fontPath, fontSize, fontFlags = label:GetFont()
      if fontPath and fontSize then
        label:SetFont(fontPath, math.max(fontSize + 2, 10), fontFlags)
      end
    end
    if label.SetTextColor then
      label:SetTextColor(0.5, 0.5, 0.5) -- startet grau; UpdateCollapseState hebt aktiven hervor
    end
    if label.SetShadowOffset then
      label:SetShadowOffset(1, -1)
    end
    if label.SetText then
      label:SetText(modeLabel)
    end
    btn.label = label
  end
  btn._modeTarget = modeTarget
  btn._modeLabel = modeLabel
  btn._collapseButtonLabel = modeLabel -- statisch; für Test-Kompatibilität
  btn._collapseLayoutMode = modeTarget -- für FindFrameByProperty in Tests
  btn:SetScript("OnClick", onClick)
  return btn
end
RI.CreateModeButton = CreateModeButton
