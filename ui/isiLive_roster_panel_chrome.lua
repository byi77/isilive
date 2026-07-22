local _, addonTable = ...
addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI

local AnchorRosterHoverTooltip = RI.AnchorRosterHoverTooltip or function(...)
  local _ = ...
end
local HideRosterHoverTooltip = RI.HideRosterHoverTooltip or function(...)
  local _ = ...
end
local HELPER_BUTTON_SIZE = RI.HELPER_BUTTON_SIZE or 18
local HELPER_COLUMN_X = RI.HELPER_COLUMN_X or -111

local UICommon = addonTable.UICommon or {}
local Colors = UICommon.Colors or {}
local MeasureFontStringWidthSafe = UICommon.MeasureFontStringWidthSafe

-- Column position constants. Shared with isiLive_roster_panel.lua via RI so
-- both the header row creation here and the member row rendering there stay
-- in sync without duplicating literals.
local SPEC_COL_X = 4
local NAME_COL_X = 93
local SERVER_COL_X = 75
local KEY_COL_X = 216
local ILVL_COL_X = 282
local RIO_COL_X = 318
local SPEC_COL_WIDTH = 52
local NAME_COL_WIDTH = 122
local SERVER_COL_WIDTH = 18
local KEY_COL_WIDTH = 62
local ILVL_COL_WIDTH = 32
-- Leave enough room for long positive RIO deltas like (+999)9999 without clipping.
local RIO_COL_WIDTH = 70
local DPS_COL_X = RIO_COL_X + RIO_COL_WIDTH + 2
local DPS_COL_WIDTH = 40
local KICK_COL_X = DPS_COL_X + DPS_COL_WIDTH + 4
local KICK_COL_WIDTH = 40
local HEADER_MIN_FONT_SIZE = 8
local HEADER_WIDTH_PADDING = 2

RI.SPEC_COL_X = SPEC_COL_X
RI.NAME_COL_X = NAME_COL_X
RI.SERVER_COL_X = SERVER_COL_X
RI.KEY_COL_X = KEY_COL_X
RI.ILVL_COL_X = ILVL_COL_X
RI.RIO_COL_X = RIO_COL_X
RI.DPS_COL_X = DPS_COL_X
RI.KICK_COL_X = KICK_COL_X
RI.SPEC_COL_WIDTH = SPEC_COL_WIDTH
RI.NAME_COL_WIDTH = NAME_COL_WIDTH
RI.SERVER_COL_WIDTH = SERVER_COL_WIDTH
RI.KEY_COL_WIDTH = KEY_COL_WIDTH
RI.ILVL_COL_WIDTH = ILVL_COL_WIDTH
RI.RIO_COL_WIDTH = RIO_COL_WIDTH
RI.DPS_COL_WIDTH = DPS_COL_WIDTH
RI.KICK_COL_WIDTH = KICK_COL_WIDTH

local function ConfigureSingleLineFontString(fontString)
  if type(fontString) ~= "table" then
    return
  end
  if type(fontString.SetWordWrap) == "function" then
    fontString:SetWordWrap(false)
  end
  if type(fontString.SetNonSpaceWrap) == "function" then
    fontString:SetNonSpaceWrap(false)
  end
  if type(fontString.SetMaxLines) == "function" then
    fontString:SetMaxLines(1)
  end
end

local function CaptureOriginalFont(fontString)
  if
    type(fontString) ~= "table"
    or type(fontString.GetFont) ~= "function"
    or type(fontString.SetFont) ~= "function"
  then
    return nil
  end
  if fontString._isiLiveHeaderOriginalFont then
    return fontString._isiLiveHeaderOriginalFont
  end

  local fontPath, fontSize, fontFlags = fontString:GetFont()
  if type(fontPath) ~= "string" or fontPath == "" or type(fontSize) ~= "number" then
    return nil
  end

  fontString._isiLiveHeaderOriginalFont = {
    path = fontPath,
    size = fontSize,
    flags = fontFlags,
  }
  return fontString._isiLiveHeaderOriginalFont
end

local function GetHeaderWidth(fontString)
  if type(fontString) ~= "table" then
    return 0
  end
  if type(fontString.GetWidth) == "function" then
    return tonumber(fontString:GetWidth()) or 0
  end
  return tonumber(fontString._isiLiveHeaderWidth) or 0
end

local function FitHeaderFontString(fontString)
  if
    type(fontString) ~= "table"
    or type(fontString.GetFont) ~= "function"
    or type(fontString.SetFont) ~= "function"
    or type(fontString.GetStringWidth) ~= "function"
  then
    return
  end

  local width = GetHeaderWidth(fontString) - HEADER_WIDTH_PADDING
  if width <= 0 then
    return
  end

  local fontPath, fontSize, fontFlags = fontString:GetFont()
  if type(fontPath) ~= "string" or fontPath == "" or type(fontSize) ~= "number" then
    return
  end

  local nextSize = fontSize
  while nextSize > HEADER_MIN_FONT_SIZE do
    local stringWidth = type(MeasureFontStringWidthSafe) == "function" and MeasureFontStringWidthSafe(fontString) or nil
    if not stringWidth or stringWidth <= width then
      break
    end
    nextSize = nextSize - 1
    fontString:SetFont(fontPath, nextSize, fontFlags)
  end
end

local function SetPanelHeaderText(fontString, text)
  if type(fontString) ~= "table" then
    return
  end

  ConfigureSingleLineFontString(fontString)
  local originalFont = CaptureOriginalFont(fontString)
  if originalFont then
    fontString:SetFont(originalFont.path, originalFont.size, originalFont.flags)
  end

  local common = addonTable and addonTable.UICommon
  if type(common) == "table" and type(common.ApplyLocaleFont) == "function" then
    common.ApplyLocaleFont(fontString)
  end

  if type(fontString.SetText) == "function" then
    fontString:SetText(tostring(text or ""))
  end
  FitHeaderFontString(fontString)
end

local function CreateFlatButton(parent, width, height, template)
  local button = CreateFrame("Button", nil, parent, template or "BackdropTemplate")
  button:SetSize(width, height)
  local common = addonTable and addonTable.UICommon
  if type(common) == "table" and type(common.ApplyBackdrop) == "function" then
    common.ApplyBackdrop(button, "FLAT_BUTTON")
  end
  if type(button.EnableMouse) == "function" then
    button:EnableMouse(true)
  end
  if type(button.RegisterForClicks) == "function" then
    button:RegisterForClicks("LeftButtonUp")
  end

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if type(label.SetPoint) == "function" then
    label:SetPoint("CENTER", 0, 0)
  end
  local tn = Colors.TEXT_NORMAL or { 0.85, 0.85, 0.9 }
  if type(label.SetTextColor) == "function" then
    label:SetTextColor(tn[1], tn[2], tn[3], 1)
  end
  button._flatLabel = label

  local function ApplyDefaultVisual(self)
    if type(self.SetBackdropColor) == "function" then
      local bgSec = Colors.BG_SECONDARY or { 0.12, 0.12, 0.18, 0.7 }
      self:SetBackdropColor(bgSec[1], bgSec[2], bgSec[3], bgSec[4])
    end
    if type(self.SetBackdropBorderColor) == "function" then
      local ab = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
      self:SetBackdropBorderColor(ab[1], ab[2], ab[3], 0.45)
    end
  end

  local function ApplyHoverVisual(self)
    if type(self.SetBackdropColor) == "function" then
      self:SetBackdropColor(0.18, 0.18, 0.26, 0.8)
    end
    if type(self.SetBackdropBorderColor) == "function" then
      local ab = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
      self:SetBackdropBorderColor(ab[1], ab[2], ab[3], 0.6)
    end
  end

  local function ApplyPressedVisual(self)
    if type(self.SetBackdropColor) == "function" then
      self:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
    end
    if type(self.SetBackdropBorderColor) == "function" then
      local ab = Colors.ACCENT_BLUE or { 0.3, 0.65, 1 }
      self:SetBackdropBorderColor(ab[1], ab[2], ab[3], 0.9)
    end
  end

  if type(button.HookScript) == "function" then
    button:HookScript("OnEnter", function(self)
      ApplyHoverVisual(self)
    end)
    button:HookScript("OnLeave", function(self)
      ApplyDefaultVisual(self)
    end)
    button:HookScript("OnMouseDown", function(self)
      ApplyPressedVisual(self)
    end)
    button:HookScript("OnMouseUp", function(self)
      local isMouseOver = type(self.IsMouseOver) == "function" and self:IsMouseOver()
      if isMouseOver then
        ApplyHoverVisual(self)
      else
        ApplyDefaultVisual(self)
      end
    end)
  end

  ApplyDefaultVisual(button)

  return button
end

local function CreatePanelHeaders(mainFrame)
  local specHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  specHeader:SetPoint("TOPLEFT", SPEC_COL_X, -34)
  specHeader:SetWidth(SPEC_COL_WIDTH)
  specHeader._isiLiveHeaderWidth = SPEC_COL_WIDTH
  specHeader:SetJustifyH("RIGHT")
  ConfigureSingleLineFontString(specHeader)

  local nameHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nameHeader:SetPoint("TOPLEFT", NAME_COL_X, -34)
  nameHeader:SetWidth(NAME_COL_WIDTH)
  nameHeader._isiLiveHeaderWidth = NAME_COL_WIDTH
  nameHeader:SetJustifyH("LEFT")
  ConfigureSingleLineFontString(nameHeader)

  local ilvlHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ilvlHeader:SetPoint("TOPLEFT", ILVL_COL_X, -34)
  ilvlHeader:SetWidth(ILVL_COL_WIDTH)
  ilvlHeader._isiLiveHeaderWidth = ILVL_COL_WIDTH
  ilvlHeader:SetJustifyH("RIGHT")
  ConfigureSingleLineFontString(ilvlHeader)

  local serverHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  serverHeader:SetPoint("TOPLEFT", SERVER_COL_X, -34)
  serverHeader:SetWidth(SERVER_COL_WIDTH)
  serverHeader._isiLiveHeaderWidth = SERVER_COL_WIDTH
  serverHeader:SetJustifyH("LEFT")
  ConfigureSingleLineFontString(serverHeader)

  local keyHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  keyHeader:SetPoint("TOPLEFT", KEY_COL_X, -34)
  keyHeader:SetWidth(KEY_COL_WIDTH)
  keyHeader._isiLiveHeaderWidth = KEY_COL_WIDTH
  keyHeader:SetJustifyH("RIGHT")
  ConfigureSingleLineFontString(keyHeader)

  local rioHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rioHeader:SetPoint("TOPLEFT", RIO_COL_X, -34)
  rioHeader:SetWidth(RIO_COL_WIDTH)
  rioHeader._isiLiveHeaderWidth = RIO_COL_WIDTH
  rioHeader:SetJustifyH("RIGHT")
  ConfigureSingleLineFontString(rioHeader)

  local dpsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  dpsHeader:SetPoint("TOPLEFT", DPS_COL_X, -34)
  dpsHeader:SetWidth(DPS_COL_WIDTH)
  dpsHeader._isiLiveHeaderWidth = DPS_COL_WIDTH
  dpsHeader:SetJustifyH("RIGHT")
  ConfigureSingleLineFontString(dpsHeader)

  local kickHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  kickHeader:SetPoint("TOPLEFT", KICK_COL_X, -34)
  kickHeader:SetWidth(KICK_COL_WIDTH)
  kickHeader._isiLiveHeaderWidth = KICK_COL_WIDTH
  kickHeader:SetJustifyH("RIGHT")
  ConfigureSingleLineFontString(kickHeader)

  local leadOptionsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  leadOptionsHeader:SetPoint("TOPRIGHT", -10, -34)
  leadOptionsHeader:SetWidth(120)
  leadOptionsHeader:SetJustifyH("CENTER")

  local mplusManagementHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mplusManagementHeader:SetPoint("TOPRIGHT", -3, -34)
  mplusManagementHeader:SetWidth(110)
  mplusManagementHeader:SetJustifyH("CENTER")
  ConfigureSingleLineFontString(mplusManagementHeader)

  local headerSepLeft = mainFrame:CreateTexture(nil, "ARTWORK")
  headerSepLeft:SetHeight(1)
  headerSepLeft:SetPoint("TOPLEFT", 8, -48)
  headerSepLeft:SetPoint("TOPRIGHT", mainFrame, "TOP", 0, -48)
  if type(headerSepLeft.SetTexture) == "function" then
    headerSepLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(headerSepLeft.SetGradient) == "function" then
    headerSepLeft:SetGradient(
      "HORIZONTAL",
      { r = 0.5, g = 0.5, b = 0.7, a = 0 },
      { r = 0.5, g = 0.5, b = 0.7, a = 0.3 }
    )
  end

  local headerSepRight = mainFrame:CreateTexture(nil, "ARTWORK")
  headerSepRight:SetHeight(1)
  headerSepRight:SetPoint("TOPLEFT", mainFrame, "TOP", 0, -48)
  headerSepRight:SetPoint("TOPRIGHT", 0, -48)
  if type(headerSepRight.SetTexture) == "function" then
    headerSepRight:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(headerSepRight.SetGradient) == "function" then
    headerSepRight:SetGradient(
      "HORIZONTAL",
      { r = 0.5, g = 0.5, b = 0.7, a = 0.3 },
      { r = 0.5, g = 0.5, b = 0.7, a = 0 }
    )
  end

  return {
    specHeader = specHeader,
    nameHeader = nameHeader,
    ilvlHeader = ilvlHeader,
    serverHeader = serverHeader,
    keyHeader = keyHeader,
    rioHeader = rioHeader,
    dpsHeader = dpsHeader,
    kickHeader = kickHeader,
    leadOptionsHeader = leadOptionsHeader,
    mplusManagementHeader = mplusManagementHeader,
    headerSepLeft = headerSepLeft,
    headerSepRight = headerSepRight,
  }
end

local function CreateM2ColumnGuides(mainFrame)
  local guideDefs = {
    { key = "spec", x = SPEC_COL_X + SPEC_COL_WIDTH },
    { key = "name", x = NAME_COL_X + NAME_COL_WIDTH },
    { key = "server", x = SERVER_COL_X + SERVER_COL_WIDTH },
    { key = "key", x = KEY_COL_X + KEY_COL_WIDTH },
    { key = "ilvl", x = ILVL_COL_X + ILVL_COL_WIDTH },
    { key = "rio", x = RIO_COL_X + RIO_COL_WIDTH },
    { key = "dps", x = DPS_COL_X + DPS_COL_WIDTH },
  }

  local guides = {}
  for _, def in ipairs(guideDefs) do
    local guide = mainFrame:CreateTexture(nil, "OVERLAY")
    guide._m2ColumnGuide = true
    guide._guideKey = def.key
    guide._guideX = def.x
    if guide.SetWidth then
      guide:SetWidth(1)
    elseif guide.SetSize then
      guide:SetSize(1, 1)
    end
    if guide.SetColorTexture then
      guide:SetColorTexture(unpack((UICommon.Colors and UICommon.Colors.CYAN_GUIDE_LINE) or { 0.2, 0.8, 1, 0.28 }))
    elseif guide.SetTexture then
      guide:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    if guide.SetPoint then
      guide:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", def.x, -30)
      guide:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", def.x, 20)
    end
    if guide.Hide then
      guide:Hide()
    end
    table.insert(guides, guide)
  end

  return guides
end

local function AttachPanelButtonTooltip(tooltipFrame, button, getL, titleKey, descriptionKey, isPlayerLeader)
  button:SetScript("OnEnter", function(self)
    local tooltip = AnchorRosterHoverTooltip(tooltipFrame, self)
    if type(tooltip) ~= "table" then
      return
    end

    local L = getL()
    if type(tooltip.SetText) == "function" then
      tooltip:SetText(L[titleKey], 1, 1, 1)
    end
    if type(tooltip.AddLine) == "function" then
      tooltip:AddLine(L[descriptionKey], 1, 1, 1, true)
      if isPlayerLeader and not isPlayerLeader() then
        tooltip:AddLine(L.TOOLTIP_LEAD_REQUIRED, 1, 0.2, 0.2, true)
      end
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function()
    HideRosterHoverTooltip(tooltipFrame)
  end)
end

local function AttachModeButtonTooltip(
  tooltipFrame,
  button,
  getL,
  titleText,
  descriptionKey,
  descriptionFallback,
  clickHintKey,
  clickHintFallback,
  getLockReason
)
  button:SetScript("OnEnter", function(self)
    local tooltip = AnchorRosterHoverTooltip(tooltipFrame, self)
    if type(tooltip) ~= "table" then
      return
    end

    local L = type(getL) == "function" and getL() or {}
    local descriptionText = type(descriptionKey) == "string" and L[descriptionKey] or nil
    if type(descriptionText) ~= "string" or descriptionText == "" then
      descriptionText = descriptionFallback
    end
    local clickHintText = type(clickHintKey) == "string" and L[clickHintKey] or nil
    if type(clickHintText) ~= "string" or clickHintText == "" then
      clickHintText = clickHintFallback
    end
    -- Optional runtime-evaluated lock notice (used to explain why a layout
    -- button silently no-ops, e.g. M+ / V while the player is in a raid).
    local lockReason = type(getLockReason) == "function" and getLockReason() or nil

    if type(tooltip.SetText) == "function" then
      tooltip:SetText(titleText, 1, 1, 1)
    end
    if type(tooltip.AddLine) == "function" then
      if type(descriptionText) == "string" and descriptionText ~= "" then
        tooltip:AddLine(descriptionText, 1, 1, 1, true)
      end
      if type(lockReason) == "string" and lockReason ~= "" then
        tooltip:AddLine(lockReason, 1, 0.5, 0.3, true)
      end
      if type(clickHintText) == "string" and clickHintText ~= "" then
        tooltip:AddLine(clickHintText, 0.8, 0.8, 0.8, true)
      end
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function()
    HideRosterHoverTooltip(tooltipFrame)
  end)
end

local function CreateTankHelperButtons(mainFrame, tooltipFrame, getL)
  local markers = {
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", id = 1, name = "Square (Blue)" },
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", id = 2, name = "Triangle (Green)" },
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", id = 3, name = "Diamond (Purple)" },
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", id = 4, name = "Cross (Red)" },
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", id = 5, name = "Star (Yellow)" },
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", id = 6, name = "Circle (Orange)" },
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", id = 7, name = "Moon (Silver)" },
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", id = 8, name = "Skull (White)" },
  }

  local buttons = {}
  local startY = -60
  local size = HELPER_BUTTON_SIZE
  local gap = 2

  -- Position: right of the DPS column, directly left of M+Travel.
  -- M+Marker and M+Management are swapped compared to the old layout.
  local xPos = HELPER_COLUMN_X

  for i, marker in ipairs(markers) do
    local btn = CreateFrame("Button", nil, mainFrame, "SecureActionButtonTemplate")
    btn:SetSize(size, size)
    btn._verticalY = startY - ((i - 1) * (size + gap))
    btn:SetPoint("TOPRIGHT", xPos, btn._verticalY)
    btn._markerIndex = i
    if btn.SetFrameLevel and mainFrame.GetFrameLevel then
      btn:SetFrameLevel((mainFrame:GetFrameLevel() or 1) + 10)
    end

    if btn.SetNormalTexture then
      btn:SetNormalTexture(marker.icon)
    end
    if btn.SetAttribute then
      btn:SetAttribute("type", "worldmarker")
      btn:SetAttribute("marker", marker.id)
      btn:SetAttribute("type1", "worldmarker") -- Left click: set
      btn:SetAttribute("marker1", marker.id)
      btn:SetAttribute("action1", "set")
      btn:SetAttribute("type2", "worldmarker") -- Right click: clear
      btn:SetAttribute("marker2", marker.id)
      btn:SetAttribute("action2", "clear")
    end
    if btn.SetMouseClickEnabled then
      btn:SetMouseClickEnabled(true)
    end
    if btn.RegisterForClicks then
      btn:RegisterForClicks("AnyUp", "AnyDown")
    end

    btn:SetScript("OnEnter", function(self)
      local tooltip = AnchorRosterHoverTooltip(tooltipFrame, self)
      if type(tooltip) == "table" and type(tooltip.SetText) == "function" then
        local L = type(getL) == "function" and getL() or {}
        local titleFmt = type(L.TOOLTIP_WORLDMARKER_TITLE_FMT) == "string" and L.TOOLTIP_WORLDMARKER_TITLE_FMT
          or "World Marker: %s"
        local lclick = type(L.TOOLTIP_WORLDMARKER_LCLICK) == "string" and L.TOOLTIP_WORLDMARKER_LCLICK
          or "Left-Click: Place"
        local rclick = type(L.TOOLTIP_WORLDMARKER_RCLICK) == "string" and L.TOOLTIP_WORLDMARKER_RCLICK
          or "Right-Click: Clear"
        tooltip:SetText(string.format(titleFmt, marker.name), 1, 1, 1)
        if type(tooltip.AddLine) == "function" then
          tooltip:AddLine(lclick, 0, 1, 0)
          tooltip:AddLine(rclick, 1, 0.2, 0.2)
        end
        tooltip:Show()
      end
    end)
    btn:SetScript("OnLeave", function()
      HideRosterHoverTooltip(tooltipFrame)
    end)

    table.insert(buttons, btn)
  end

  local header = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  header:SetPoint("TOPRIGHT", xPos + 18, -34)
  header:SetWidth(60)
  header:SetJustifyH("CENTER")
  local L = getL()
  header:SetText(L.TANK_HELPER_HEADER or "Tank Helper")

  return buttons, header
end

RI.CreateFlatButton = CreateFlatButton
RI.CreatePanelHeaders = CreatePanelHeaders
RI.SetPanelHeaderText = SetPanelHeaderText
RI.CreateM2ColumnGuides = CreateM2ColumnGuides
RI.AttachPanelButtonTooltip = AttachPanelButtonTooltip
RI.AttachModeButtonTooltip = AttachModeButtonTooltip
RI.CreateTankHelperButtons = CreateTankHelperButtons
