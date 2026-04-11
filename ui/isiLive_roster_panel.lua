local _, addonTable = ...

addonTable = addonTable or {}

local RosterPanel = {}
addonTable.RosterPanel = RosterPanel

-- Imports from _RosterInternal (set by roster_tooltip.lua and roster_layout.lua).
-- Load-order dependency: isiLive_roster_tooltip.lua and isiLive_roster_layout.lua
-- must appear before this file in isiLive.toc (currently lines 49-50 vs 53).
-- All imports below carry hardcoded fallbacks so a load-order mistake fails
-- gracefully rather than with a nil-dereference crash.
local RI = addonTable._RosterInternal or {}
local ContextHelpers = addonTable.ContextHelpers or {}

local function GetDB()
  return rawget(_G, "IsiLiveDB")
end

-- Tooltip imports
local DisableFontStringWrapping = RI.DisableFontStringWrapping or function(_fs) end
local CreateRosterHoverTooltip = RI.CreateRosterHoverTooltip or function(...)
  local _ = ...
  return nil
end
local HideRosterHoverTooltip = RI.HideRosterHoverTooltip or function(...)
  local _ = ...
end
local AnchorRosterHoverTooltip = RI.AnchorRosterHoverTooltip or function(...)
  local _ = ...
end
local FormatCompactTooltipNumber = RI.FormatCompactTooltipNumber or function(n)
  return tostring(n or 0)
end
local ShowRosterNameFallbackTooltip = RI.ShowRosterNameFallbackTooltip or function(...)
  local _ = ...
end
local ShowRosterInfoTooltip = RI.ShowRosterInfoTooltip or function(...)
  local _ = ...
end

-- Layout imports
local LAYOUT_MODE_EXPANDED = RI.LAYOUT_MODE_EXPANDED or "expanded"
local LAYOUT_MODE_COMPACT_VERTICAL = RI.LAYOUT_MODE_COMPACT_VERTICAL or "compact_vertical"
local LAYOUT_MODE_COMPACT_HORIZONTAL = RI.LAYOUT_MODE_COMPACT_HORIZONTAL or "compact_horizontal"
local LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL = RI.LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL or "compact_main_horizontal"
local DEFAULT_LAYOUT_MODE_LAST_USED = "last_used"
local LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL_LEGACY = "compact_horizontal_2"
local FULL_FRAME_WIDTH = RI.FULL_FRAME_WIDTH or 755
local HELPER_BUTTON_SIZE = RI.HELPER_BUTTON_SIZE or 18
local HELPER_COLUMN_X = RI.HELPER_COLUMN_X or -111
local DEFAULT_MIN_FRAME_HEIGHT = RI.DEFAULT_MIN_FRAME_HEIGHT or 236
local IsCombatLockdownActive = RI.IsCombatLockdownActive or function()
  return false
end
local NormalizeLayoutMode = RI.NormalizeLayoutMode
  or function(mode)
    if mode == LAYOUT_MODE_COMPACT_VERTICAL then
      return LAYOUT_MODE_COMPACT_VERTICAL
    end
    if mode == LAYOUT_MODE_COMPACT_HORIZONTAL then
      return LAYOUT_MODE_COMPACT_HORIZONTAL
    end
    if mode == LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL or mode == LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL_LEGACY then
      return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
    end
    return LAYOUT_MODE_EXPANDED
  end
local function ResolveConfiguredDefaultOpenLayoutMode()
  local db = GetDB()
  if type(db) ~= "table" then
    return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end

  local layoutMode = db.rosterDefaultLayoutMode
  if layoutMode == nil or layoutMode == false or layoutMode == "" then
    return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end

  if layoutMode == DEFAULT_LAYOUT_MODE_LAST_USED then
    return DEFAULT_LAYOUT_MODE_LAST_USED
  end

  if layoutMode == LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL_LEGACY then
    return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  end

  if
    layoutMode == LAYOUT_MODE_EXPANDED
    or layoutMode == LAYOUT_MODE_COMPACT_VERTICAL
    or layoutMode == LAYOUT_MODE_COMPACT_HORIZONTAL
    or layoutMode == LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
  then
    return layoutMode
  end

  return LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
end
local IsCompactLayoutMode = RI.IsCompactLayoutMode or function(_mode)
  return false
end
local IsHorizontalCompactLayoutMode = RI.IsHorizontalCompactLayoutMode or function(_mode)
  return false
end
local IsMainHorizontalLayoutMode = RI.IsMainHorizontalLayoutMode
  or RI.IsStackedModernLayoutMode
  or function(_mode)
    return false
  end
local GetFrameHeightForLayoutMode = RI.GetFrameHeightForLayoutMode
local CD_TRACKER_ROW_HEIGHT = RI.CD_TRACKER_ROW_HEIGHT or 20
local CD_TRACKER_ROW_BOTTOM_OFFSET = RI.CD_TRACKER_ROW_BOTTOM_OFFSET or 20
local KILLTRACK_ROW_BOTTOM_OFFSET = 12
local CD_TRACKER_ICON_SIZE = 16
local CD_TRACKER_TEXT_GAP = 6
local CD_TRACKER_FONT_SIZE = 12
local CreateSystemOptionToggles = RI.CreateSystemOptionToggles
local RefreshSystemOptionToggles = RI.RefreshSystemOptionToggles
local LayoutSystemOptionToggles = RI.LayoutSystemOptionToggles
local AttachSystemOptionToggleWatcher = RI.AttachSystemOptionToggleWatcher
local SetFlatButtonText = RI.SetFlatButtonText or function(_btn, _text) end
local UpdateCollapseState = RI.UpdateCollapseState
local NotifyCollapseChanged = RI.NotifyCollapseChanged
local NotifyLayoutChanged = RI.NotifyLayoutChanged or function(_ui, _layoutMode) end
local CreateModeButton = RI.CreateModeButton

-- Column position constants
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
local KICK_COL_WIDTH = 58
local KICK_HOVER_WIDTH = 58
local ROLE_BUTTON_X = SPEC_COL_X + SPEC_COL_WIDTH + 4

-- These settings are temporarily hidden from Blizzard Settings.
-- Keep the runtime behavior hard-forced until the controls are re-enabled.
local FORCE_SHOW_DPS_COLUMN = true
local FORCE_MARKERS_LEADER_ONLY = false

local function RequireFunction(value, name)
  return addonTable.Validators.RequireFunction(value, name, "RosterPanel")
end

local function SendPartyChatMessage(message)
  if type(message) ~= "string" or message == "" then
    return false
  end

  local sendChatMessage = rawget(_G, "SendChatMessage")
  if type(sendChatMessage) ~= "function" then
    local chatInfo = rawget(_G, "C_ChatInfo")
    sendChatMessage = type(chatInfo) == "table" and chatInfo.SendChatMessage or nil
  end
  if type(sendChatMessage) == "function" then
    local ok = pcall(sendChatMessage, message, "PARTY")
    if ok then
      return true
    end
  end

  return false
end

local function BuildKeystoneLinkText(shortCode, keyLevel)
  local level = math.floor(tonumber(keyLevel) or 0)
  return string.format("%s +%d", tostring(shortCode or "?"), level)
end

local function BuildOwnKeyAnnounceLine(opts)
  local roster = opts.getRoster()
  local playerInfo = roster and roster.player
  if type(playerInfo) ~= "table" then
    return nil
  end
  local keyMapID = tonumber(playerInfo.keyMapID)
  local keyLevel = tonumber(playerInfo.keyLevel)
  if not keyMapID or keyMapID <= 0 or not keyLevel or keyLevel <= 0 then
    return nil
  end

  local keyLink = ContextHelpers.BuildKeystoneChatLink(keyMapID, keyLevel)
  if not keyLink then
    local short = opts.getDungeonShortCode(keyMapID)
    keyLink = BuildKeystoneLinkText(short, keyLevel)
  end

  local L = opts.getL()
  local announcePrefix = tostring(L.ANNOUNCE_PREFIX or "PartyKeys:"):gsub("%s+", "")
  return string.format("[isiLive] %s %s", announcePrefix, keyLink)
end

local function ApplyFontStringSize(fontString, size)
  if fontString == nil then
    return
  end
  if type(fontString.GetFont) ~= "function" or type(fontString.SetFont) ~= "function" then
    return
  end

  local fontPath, _, fontFlags = fontString:GetFont()
  if type(fontPath) ~= "string" or fontPath == "" then
    return
  end

  fontString:SetFont(fontPath, size, fontFlags)
end

local function CreateCdTrackerRow(mainFrame)
  local UICommon = addonTable.UICommon or {}
  local row = CreateFrame("Frame", nil, mainFrame)
  if type(row.CreateTexture) ~= "function" or type(row.CreateFontString) ~= "function" then
    return nil
  end
  if type(row.SetHeight) == "function" then
    row:SetHeight(CD_TRACKER_ROW_HEIGHT)
  end
  if type(row.SetPoint) == "function" then
    row:SetPoint("BOTTOMLEFT", 10, CD_TRACKER_ROW_BOTTOM_OFFSET)
    row:SetPoint("BOTTOMRIGHT", -10, CD_TRACKER_ROW_BOTTOM_OFFSET)
  end

  -- BR/BL box: left-aligned, framed together
  local cdBox = CreateFrame("Frame", nil, row, "BackdropTemplate")
  if type(cdBox.SetHeight) == "function" then
    cdBox:SetHeight(CD_TRACKER_ROW_HEIGHT)
  end
  if type(cdBox.SetPoint) == "function" then
    cdBox:SetPoint("LEFT", row, "LEFT", 0, 0)
  end
  if type(cdBox.SetWidth) == "function" then
    cdBox:SetWidth(170)
  end
  if type(UICommon.ApplyBackdrop) == "function" then
    UICommon.ApplyBackdrop(cdBox, "CD_BOX")
  end
  row.cdBox = cdBox

  -- BR icon + text inside cdBox
  row.bresIcon = cdBox:CreateTexture(nil, "OVERLAY")
  if type(row.bresIcon.SetSize) == "function" then
    row.bresIcon:SetSize(CD_TRACKER_ICON_SIZE, CD_TRACKER_ICON_SIZE)
  end
  if type(row.bresIcon.SetPoint) == "function" then
    row.bresIcon:SetPoint("LEFT", cdBox, "LEFT", 6, 0)
  end
  if type(row.bresIcon.SetTexCoord) == "function" then
    row.bresIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  row.bresIcon:Hide()

  row.bresText = cdBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.bresText:SetPoint("LEFT", row.bresIcon, "RIGHT", CD_TRACKER_TEXT_GAP, 0)
  row.bresText:SetJustifyH("LEFT")
  row.bresText:SetText("")
  ApplyFontStringSize(row.bresText, CD_TRACKER_FONT_SIZE)

  row.lustIcon = cdBox:CreateTexture(nil, "OVERLAY")
  if type(row.lustIcon.SetSize) == "function" then
    row.lustIcon:SetSize(CD_TRACKER_ICON_SIZE, CD_TRACKER_ICON_SIZE)
  end
  if type(row.lustIcon.SetPoint) == "function" then
    row.lustIcon:SetPoint("LEFT", row.bresText, "RIGHT", 12, 0)
  end
  if type(row.lustIcon.SetTexCoord) == "function" then
    row.lustIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  row.lustIcon:Hide()

  row.lustText = cdBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.lustText:SetPoint("LEFT", row.lustIcon, "RIGHT", CD_TRACKER_TEXT_GAP, 0)
  row.lustText:SetJustifyH("LEFT")
  row.lustText:SetText("")
  ApplyFontStringSize(row.lustText, CD_TRACKER_FONT_SIZE)

  -- Cache spell icons once at creation time to avoid repeated API calls on every refresh.
  local C_Spell_ref = rawget(_G, "C_Spell")
  if type(C_Spell_ref) == "table" and type(C_Spell_ref.GetSpellTexture) == "function" then
    local ok, tex = pcall(C_Spell_ref.GetSpellTexture, 20484)
    if ok and tex then
      row.bresIcon:SetTexture(tex)
      row._bresIconReady = true
    end
    ok, tex = pcall(C_Spell_ref.GetSpellTexture, 2825)
    if ok and tex then
      row.lustIcon:SetTexture(tex)
      row._lustDefaultIcon = tex
      row._lustIconReady = true
    end
  end

  -- M+ timer box: right of cdBox, framed with blue accent
  local mplusBox = CreateFrame("Frame", nil, row, "BackdropTemplate")
  if type(mplusBox.SetHeight) == "function" then
    mplusBox:SetHeight(CD_TRACKER_ROW_HEIGHT)
  end
  if type(mplusBox.SetPoint) == "function" then
    mplusBox:SetPoint("LEFT", cdBox, "RIGHT", 6, 0)
    mplusBox:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  end
  if type(UICommon.ApplyBackdrop) == "function" then
    UICommon.ApplyBackdrop(mplusBox, "MPLUS_BOX")
  end
  mplusBox:Hide()
  row.mplusBox = mplusBox

  -- M+ label + stopwatch icon badge
  do
    local badge = CreateFrame("Frame", nil, mplusBox)
    badge:SetSize(16, 12)
    badge:SetPoint("LEFT", mplusBox, "LEFT", 6, 0)
    local label = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if type(label.SetPoint) == "function" then
      label:SetPoint("LEFT", badge, "LEFT", 0, 0)
    end
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("LEFT")
    end
    if type(label.SetJustifyV) == "function" then
      label:SetJustifyV("MIDDLE")
    end
    if type(label.SetText) == "function" then
      label:SetText("|cffffd700M+|r")
    end
    ApplyFontStringSize(label, CD_TRACKER_FONT_SIZE)
    row.mplusLabel = badge
  end

  -- +3 badge icon (16x12 colored frame with "+3" label) + timer text
  do
    local badge = CreateFrame("Frame", nil, mplusBox)
    badge:SetSize(16, 12)
    badge:SetPoint("LEFT", mplusBox, "LEFT", 32, 0)
    local bg = badge:CreateTexture(nil, "BACKGROUND")
    if type(bg.SetAllPoints) == "function" then
      bg:SetAllPoints(badge)
    end
    if type(bg.SetTexture) == "function" then
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    if type(bg.SetVertexColor) == "function" then
      bg:SetVertexColor(0.15, 0.45, 0.15)
    end
    local label = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if type(label.SetAllPoints) == "function" then
      label:SetAllPoints(badge)
    end
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("CENTER")
    end
    if type(label.SetJustifyV) == "function" then
      label:SetJustifyV("MIDDLE")
    end
    if type(label.SetText) == "function" then
      label:SetText("|cff44ff44+3|r")
    end
    ApplyFontStringSize(label, CD_TRACKER_FONT_SIZE)
    row.mp3Icon = badge
  end

  row.mp3Text = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mp3Text:SetPoint("LEFT", mplusBox, "LEFT", 50, 0)
  row.mp3Text:SetWidth(36)
  row.mp3Text:SetJustifyH("LEFT")
  row.mp3Text:SetText("--:--")
  ApplyFontStringSize(row.mp3Text, CD_TRACKER_FONT_SIZE)

  -- +2 badge icon (16x12 colored frame with "+2" label) + timer text
  do
    local badge = CreateFrame("Frame", nil, mplusBox)
    badge:SetSize(16, 12)
    badge:SetPoint("LEFT", mplusBox, "LEFT", 90, 0)
    local bg = badge:CreateTexture(nil, "BACKGROUND")
    if type(bg.SetAllPoints) == "function" then
      bg:SetAllPoints(badge)
    end
    if type(bg.SetTexture) == "function" then
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    if type(bg.SetVertexColor) == "function" then
      bg:SetVertexColor(0.45, 0.38, 0.05)
    end
    local label = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if type(label.SetAllPoints) == "function" then
      label:SetAllPoints(badge)
    end
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("CENTER")
    end
    if type(label.SetJustifyV) == "function" then
      label:SetJustifyV("MIDDLE")
    end
    if type(label.SetText) == "function" then
      label:SetText("|cffffd91a+2|r")
    end
    ApplyFontStringSize(label, CD_TRACKER_FONT_SIZE)
    row.mp2Icon = badge
  end

  row.mp2Text = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mp2Text:SetPoint("LEFT", mplusBox, "LEFT", 108, 0)
  row.mp2Text:SetWidth(36)
  row.mp2Text:SetJustifyH("LEFT")
  row.mp2Text:SetText("--:--")
  ApplyFontStringSize(row.mp2Text, CD_TRACKER_FONT_SIZE)

  -- +1 badge icon (16x12 colored frame with "+1" label) + timer text
  do
    local badge = CreateFrame("Frame", nil, mplusBox)
    badge:SetSize(16, 12)
    badge:SetPoint("LEFT", mplusBox, "LEFT", 148, 0)
    local bg = badge:CreateTexture(nil, "BACKGROUND")
    if type(bg.SetAllPoints) == "function" then
      bg:SetAllPoints(badge)
    end
    if type(bg.SetTexture) == "function" then
      bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    if type(bg.SetVertexColor) == "function" then
      bg:SetVertexColor(0.3, 0.3, 0.3)
    end
    local label = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if type(label.SetAllPoints) == "function" then
      label:SetAllPoints(badge)
    end
    if type(label.SetJustifyH) == "function" then
      label:SetJustifyH("CENTER")
    end
    if type(label.SetJustifyV) == "function" then
      label:SetJustifyV("MIDDLE")
    end
    if type(label.SetText) == "function" then
      label:SetText("|cffdddddd+1|r")
    end
    ApplyFontStringSize(label, CD_TRACKER_FONT_SIZE)
    row.mp1Icon = badge
  end

  row.mp1Text = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mp1Text:SetPoint("LEFT", mplusBox, "LEFT", 166, 0)
  row.mp1Text:SetWidth(36)
  row.mp1Text:SetJustifyH("LEFT")
  row.mp1Text:SetText("--:--")
  ApplyFontStringSize(row.mp1Text, CD_TRACKER_FONT_SIZE)

  -- death icon + label
  row.mpDeathIcon = mplusBox:CreateTexture(nil, "OVERLAY")
  if type(row.mpDeathIcon.SetSize) == "function" then
    row.mpDeathIcon:SetSize(12, 12)
  end
  if type(row.mpDeathIcon.SetPoint) == "function" then
    row.mpDeathIcon:SetPoint("LEFT", mplusBox, "LEFT", 206, 0)
  end
  if type(row.mpDeathIcon.SetTexture) == "function" then
    row.mpDeathIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
  end

  row.mpDeathText = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mpDeathText:SetPoint("LEFT", row.mpDeathIcon, "RIGHT", 4, 0)
  row.mpDeathText:SetJustifyH("LEFT")
  row.mpDeathText:SetText("")
  ApplyFontStringSize(row.mpDeathText, CD_TRACKER_FONT_SIZE)

  return row
end

local function FormatMplusTime(seconds)
  local abs = math.abs(seconds)
  local m = math.floor(abs / 60)
  local s = math.floor(abs % 60)
  return string.format("%d:%02d", m, s)
end

local function SetFontStringTextColorSafe(fontString, r, g, b)
  if fontString and type(fontString.SetTextColor) == "function" then
    fontString:SetTextColor(r, g, b)
  end
end

local function UpdateCdTrackerRow(row, cdController)
  if not row then
    return
  end

  -- BRes: always show icon + text; if spell unavailable show "--"
  do
    if row._bresIconReady then
      row.bresIcon:Show()
    end
    local bres = cdController and cdController.GetBResInfo()
    if bres then
      local charges = bres.charges or 0
      local maxCharges = bres.maxCharges or 0
      local remain = bres.cooldownRemain or 0
      if remain > 0 then
        local mins = math.floor(remain / 60)
        local secs = math.floor(remain % 60)
        row.bresText:SetText(string.format("%d/%d  %d:%02d", charges, maxCharges, mins, secs))
      else
        row.bresText:SetText(string.format("%d/%d", charges, maxCharges))
      end
    else
      row.bresText:SetText("BR: --")
    end
  end

  -- BL: always show icon + text; show countdown when active, "--" when inactive.
  -- Use the aura's own icon when lust is active (covers Heroism, Time Warp variants),
  -- fall back to the cached Bloodlust icon when inactive.
  do
    local lust = cdController and cdController.GetLustInfo()
    if lust and lust.remain and lust.remain > 0 then
      if lust.icon then
        row.lustIcon:SetTexture(lust.icon)
      end
      if row._lustIconReady or lust.icon then
        row.lustIcon:Show()
      end
      local mins = math.floor(lust.remain / 60)
      local secs = math.floor(lust.remain % 60)
      row.lustText:SetText(string.format("BL: %d:%02d", mins, secs))
    else
      if row._lustDefaultIcon then
        row.lustIcon:SetTexture(row._lustDefaultIcon)
      end
      if row._lustIconReady then
        row.lustIcon:Show()
      end
      row.lustText:SetText("BL: --")
    end
  end

  -- M+ timer box
  if row.mplusBox then
    local MplusTimer = addonTable.MplusTimer
    local data = type(MplusTimer) == "table"
        and type(MplusTimer.GetTimerData) == "function"
        and MplusTimer.GetTimerData()
      or nil

    row.mplusBox:Show()

    if data and (data.running or data.completed) then
      -- +3
      if data.timeRemaining3 >= 0 then
        SetFontStringTextColorSafe(row.mp3Text, 0.4, 1.0, 0.4)
        row.mp3Text:SetText(FormatMplusTime(data.timeRemaining3))
      else
        SetFontStringTextColorSafe(row.mp3Text, 0.5, 0.5, 0.5)
        row.mp3Text:SetText("--:--")
      end

      -- +2
      if data.timeRemaining2 >= 0 then
        SetFontStringTextColorSafe(row.mp2Text, 1.0, 0.85, 0.1)
        row.mp2Text:SetText(FormatMplusTime(data.timeRemaining2))
      else
        SetFontStringTextColorSafe(row.mp2Text, 0.5, 0.5, 0.5)
        row.mp2Text:SetText("--:--")
      end

      -- +1: white when time remains, red when exceeded
      if data.timeRemaining1 >= 0 then
        SetFontStringTextColorSafe(row.mp1Text, 1.0, 1.0, 1.0)
        row.mp1Text:SetText(FormatMplusTime(data.timeRemaining1))
      else
        SetFontStringTextColorSafe(row.mp1Text, 1.0, 0.2, 0.2)
        row.mp1Text:SetText("-" .. FormatMplusTime(data.timeRemaining1))
      end

      -- Tode
      if data.deaths and data.deaths > 0 then
        local deathStr
        if data.deathTimeLost and data.deathTimeLost > 0 then
          deathStr = string.format("|cffff6060%d (+%ds)|r", data.deaths, data.deathTimeLost)
        else
          deathStr = string.format("|cffff6060%d|r", data.deaths)
        end
        row.mpDeathText:SetText(deathStr)
      else
        row.mpDeathText:SetText("")
      end
    else
      -- no active key: show --:-- for all
      SetFontStringTextColorSafe(row.mp3Text, 0.4, 0.4, 0.5)
      row.mp3Text:SetText("--:--")
      SetFontStringTextColorSafe(row.mp2Text, 0.4, 0.4, 0.5)
      row.mp2Text:SetText("--:--")
      SetFontStringTextColorSafe(row.mp1Text, 0.4, 0.4, 0.5)
      row.mp1Text:SetText("--:--")
      SetFontStringTextColorSafe(row.mpDeathText, 0.4, 0.4, 0.5)
      row.mpDeathText:SetText("--")
    end
  end
end

local function CreateKillTrackRow(mainFrame)
  local UICommon = addonTable.UICommon or {}
  local row = CreateFrame("Frame", nil, mainFrame)
  row:SetHeight(CD_TRACKER_ROW_HEIGHT)
  row:SetPoint("BOTTOMLEFT", 10, KILLTRACK_ROW_BOTTOM_OFFSET)
  row:SetPoint("BOTTOMRIGHT", -10, KILLTRACK_ROW_BOTTOM_OFFSET)

  local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
  box:SetHeight(CD_TRACKER_ROW_HEIGHT)
  box:SetPoint("LEFT", row, "LEFT", 0, 0)
  box:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  if type(UICommon.ApplyBackdrop) == "function" then
    UICommon.ApplyBackdrop(box, "CD_BOX")
  end

  local label = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("LEFT", box, "LEFT", 6, 0)
  label:SetWidth(84)
  label:SetJustifyH("LEFT")
  label:SetText("|cff888888M+Killtracker|r")
  ApplyFontStringSize(label, CD_TRACKER_FONT_SIZE)

  local pullText = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pullText:SetPoint("RIGHT", box, "RIGHT", -66, 0)
  pullText:SetWidth(54)
  pullText:SetJustifyH("RIGHT")
  pullText:SetText("")
  ApplyFontStringSize(pullText, CD_TRACKER_FONT_SIZE)

  local barContainer = CreateFrame("Frame", nil, box)
  barContainer:SetPoint("LEFT", box, "LEFT", 94, 0)
  barContainer:SetPoint("RIGHT", box, "RIGHT", -122, 0)
  barContainer:SetHeight(8)

  local barBg = barContainer:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints(barContainer)
  barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  if type(barBg.SetVertexColor) == "function" then
    barBg:SetVertexColor(0.12, 0.12, 0.12)
  end

  local barFill = barContainer:CreateTexture(nil, "ARTWORK")
  if type(barFill.SetPoint) == "function" then
    barFill:SetPoint("TOPLEFT", barContainer, "TOPLEFT", 0, 0)
    barFill:SetPoint("BOTTOMLEFT", barContainer, "BOTTOMLEFT", 0, 0)
  end
  if type(barFill.SetWidth) == "function" then
    barFill:SetWidth(1)
  end
  if type(barFill.SetTexture) == "function" then
    barFill:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(barFill.SetVertexColor) == "function" then
    barFill:SetVertexColor(0.2, 0.75, 0.35)
  end
  barFill:Hide()

  local barPull = barContainer:CreateTexture(nil, "ARTWORK")
  if type(barPull.SetPoint) == "function" then
    barPull:SetPoint("TOPLEFT", barFill, "TOPRIGHT", 0, 0)
    barPull:SetPoint("BOTTOMLEFT", barFill, "BOTTOMRIGHT", 0, 0)
  end
  if type(barPull.SetWidth) == "function" then
    barPull:SetWidth(1)
  end
  if type(barPull.SetTexture) == "function" then
    barPull:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(barPull.SetVertexColor) == "function" then
    barPull:SetVertexColor(0.4, 0.7, 1.0, 0.7)
  end
  barPull:Hide()

  local pctText = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pctText:SetPoint("RIGHT", box, "RIGHT", -6, 0)
  pctText:SetWidth(58)
  pctText:SetJustifyH("RIGHT")
  pctText:SetText("--,--")
  ApplyFontStringSize(pctText, CD_TRACKER_FONT_SIZE)

  row.killTrackBarContainer = barContainer
  row.killTrackBarFill = barFill
  row.killTrackBarPull = barPull
  row.killTrackPctText = pctText
  row.killTrackPullText = pullText
  return row
end

local function UpdateKillTrackRow(row)
  if not row then
    return
  end

  local KillTrack = addonTable.KillTrack
  local data = type(KillTrack) == "table" and type(KillTrack.GetData) == "function" and KillTrack.GetData() or nil

  local barContainer = row.killTrackBarContainer
  local barFill = row.killTrackBarFill
  local barPull = row.killTrackBarPull
  local pctText = row.killTrackPctText
  local pullText = row.killTrackPullText

  if data and data.active then
    local pct = math.max(0, math.min(data.percent, 100))
    local r, g, b
    if pct < 80 then
      r, g, b = 0.2, 0.75, 0.35
    elseif pct < 95 then
      r, g, b = 0.9, 0.75, 0.1
    else
      r, g, b = 0.9, 0.3, 0.15
    end
    local w = type(barContainer.GetWidth) == "function" and barContainer:GetWidth() or 0
    if barFill then
      local fw = math.floor(w * pct / 100 + 0.5)
      if fw > 0 then
        barFill:SetWidth(fw)
        barFill:SetVertexColor(r, g, b)
        barFill:Show()
      else
        barFill:Hide()
      end
    end
    local pullPct = (data.inCombat and type(data.pullPercent) == "number") and data.pullPercent or 0
    if barPull then
      if data.inCombat and pullPct > 0 and w > 0 then
        local pw = math.floor(w * pullPct / 100 + 0.5)
        local fw = barFill and (type(barFill.GetWidth) == "function" and barFill:GetWidth() or 0) or 0
        if fw + pw > w then
          pw = math.max(1, w - fw)
        end
        barPull:SetWidth(math.max(1, pw))
        barPull:Show()
      else
        barPull:Hide()
      end
    end
    if pctText then
      pctText:SetText(string.format("%.2f%%", pct):gsub("%.", ","))
      if type(pctText.SetTextColor) == "function" then
        pctText:SetTextColor(r, g, b)
      end
    end
    if pullText then
      if data.inCombat and pullPct > 0 then
        pullText:SetText("+" .. string.format("%.2f%%", pullPct):gsub("%.", ","))
        if type(pullText.SetTextColor) == "function" then
          pullText:SetTextColor(0.6, 0.85, 1.0)
        end
      else
        pullText:SetText("")
      end
    end
  else
    if barFill then
      barFill:Hide()
    end
    if barPull then
      barPull:Hide()
    end
    if pctText then
      pctText:SetText("--,--")
      if type(pctText.SetTextColor) == "function" then
        pctText:SetTextColor(0.4, 0.4, 0.5)
      end
    end
    if pullText then
      pullText:SetText("")
    end
  end
end

local function CreateStatusLine(mainFrame)
  local statusLine = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statusLine:SetPoint("BOTTOMLEFT", 10, 6)
  statusLine:SetJustifyH("LEFT")
  statusLine:SetText("")
  return statusLine
end

local function CreateMemberRow(mainFrame, index, rosterTooltip)
  local yOffset = -52 - (index - 1) * 16
  local row = {}

  row.hoverFrame = CreateFrame("Frame", nil, mainFrame)
  row.hoverFrame:SetPoint("TOPLEFT", 4, yOffset + 2)
  -- Hover/background area now extends through the Kick column.
  -- Management buttons stay further right and remain outside this area.
  row.hoverFrame:SetWidth(KICK_COL_X + KICK_HOVER_WIDTH - 4)
  row.hoverFrame:SetHeight(16)
  if row.hoverFrame.EnableMouse then
    row.hoverFrame:EnableMouse(true)
  end

  row.hoverFrame:SetScript("OnMouseUp", function(_, button)
    if not row.unit then
      return
    end

    if button == "RightButton" then
      local name = row.tooltipName
      if name then
        local target = (row.tooltipRealm and row.tooltipRealm ~= "") and (name .. "-" .. row.tooltipRealm) or name
        local openChat = rawget(_G, "ChatFrame_OpenChat")
        if type(openChat) == "function" then
          pcall(openChat, "/w " .. target .. " ")
        end
      end
    end
  end)

  if index % 2 == 0 then
    local altBg = row.hoverFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
    altBg:SetAllPoints()
    altBg:SetColorTexture(1, 1, 1, 0.03)
  end

  row.readyCheckBackground = row.hoverFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
  row.readyCheckBackground:SetAllPoints()
  row.readyCheckBackground:Hide()

  row.highlight = row.hoverFrame:CreateTexture(nil, "BACKGROUND")
  row.highlight:SetAllPoints()
  row.highlight:SetColorTexture(0.3, 0.65, 1, 0.08)
  row.highlight:Hide()

  row.hoverFrame:SetScript("OnEnter", function()
    row.highlight:Show()
    if
      not ShowRosterInfoTooltip(
        rosterTooltip,
        row.hoverFrame,
        row.unit,
        row.tooltipInfo,
        row.getDungeonShortCode,
        row.getDungeonName,
        row.getPlayerLastRunDps,
        row.getLanguageTooltipMarkup,
        row.getL
      )
    then
      ShowRosterNameFallbackTooltip(rosterTooltip, row.hoverFrame, row.tooltipName, row.tooltipRealm)
    end
  end)
  row.hoverFrame:SetScript("OnLeave", function()
    row.highlight:Hide()
    HideRosterHoverTooltip(rosterTooltip)
  end)

  row.roleButton = CreateFrame("Button", nil, mainFrame, "SecureActionButtonTemplate")
  row.roleButton:SetSize(14, 14)
  row.roleButton:SetPoint("TOPLEFT", ROLE_BUTTON_X, yOffset - 1)
  row.roleButton:RegisterForClicks("AnyUp", "AnyDown")
  row.roleButton.icon = row.roleButton:CreateTexture(nil, "ARTWORK")
  row.roleButton.icon:SetAllPoints()
  row.roleButton.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
  row.roleButton:SetScript("OnEnter", function(self)
    local tooltip = AnchorRosterHoverTooltip(rosterTooltip, self)
    if type(tooltip) == "table" and type(tooltip.SetText) == "function" then
      tooltip:SetText("Role Marker", 1, 1, 1)
      if type(tooltip.AddLine) == "function" then
        tooltip:AddLine("Click to mark unit", 1, 1, 1, true)
        tooltip:AddLine("Tank: Blue Square", 0.2, 0.4, 1, true)
        tooltip:AddLine("Healer: Green Triangle", 0.2, 1, 0.2, true)
      end
      tooltip:Show()
    end
  end)
  row.roleButton:SetScript("OnLeave", function()
    HideRosterHoverTooltip(rosterTooltip)
  end)

  row.spec = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.spec:SetPoint("TOPLEFT", SPEC_COL_X, yOffset)
  row.spec:SetJustifyH("RIGHT")
  row.spec:SetWidth(SPEC_COL_WIDTH)
  DisableFontStringWrapping(row.spec)

  row.name = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("TOPLEFT", NAME_COL_X, yOffset)
  row.name:SetJustifyH("LEFT")
  row.name:SetWidth(NAME_COL_WIDTH)
  DisableFontStringWrapping(row.name)

  row.ilvl = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.ilvl:SetPoint("TOPLEFT", ILVL_COL_X, yOffset)
  row.ilvl:SetWidth(ILVL_COL_WIDTH)
  row.ilvl:SetJustifyH("RIGHT")
  DisableFontStringWrapping(row.ilvl)

  row.key = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.key:SetPoint("TOPLEFT", KEY_COL_X, yOffset)
  row.key:SetWidth(KEY_COL_WIDTH)
  row.key:SetJustifyH("RIGHT")
  DisableFontStringWrapping(row.key)

  row.rio = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.rio:SetPoint("TOPLEFT", RIO_COL_X, yOffset)
  row.rio:SetWidth(RIO_COL_WIDTH)
  row.rio:SetJustifyH("RIGHT")
  DisableFontStringWrapping(row.rio)

  row.dps = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.dps:SetPoint("TOPLEFT", DPS_COL_X, yOffset)
  row.dps:SetWidth(DPS_COL_WIDTH)
  row.dps:SetJustifyH("RIGHT")
  DisableFontStringWrapping(row.dps)

  row.kick = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.kick:SetPoint("TOPLEFT", KICK_COL_X, yOffset)
  row.kick:SetWidth(KICK_COL_WIDTH)
  row.kick:SetJustifyH("RIGHT")
  DisableFontStringWrapping(row.kick)

  row.realm = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.realm:SetPoint("TOPLEFT", SERVER_COL_X, yOffset)
  row.realm:SetWidth(SERVER_COL_WIDTH)
  row.realm:SetJustifyH("LEFT")
  DisableFontStringWrapping(row.realm)

  return row
end

local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}

local function CreateFlatButton(parent, width, height)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width, height)
  local UICommon = addonTable and addonTable.UICommon
  if type(UICommon) == "table" and type(UICommon.ApplyBackdrop) == "function" then
    UICommon.ApplyBackdrop(button, "FLAT_BUTTON")
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

local function AttachControllerAccessors(controller, deps)
  function controller.GetRefreshButton()
    return deps.refreshButton
  end

  function controller.GetCountdownCancelButton()
    return deps.countdownCancelButton
  end

  function controller.GetStatusLine()
    return deps.statusLine
  end

  function controller.SetCountdownCancelText(text)
    SetFlatButtonText(deps.countdownCancelButton, tostring(text or ""))
  end

  function controller.TriggerShareKeysCooldown()
    local btn = deps.shareKeysButton
    if btn and type(btn.TriggerRemoteCooldown) == "function" then
      btn.TriggerRemoteCooldown()
    end
  end
end

local function CreatePanelHeaders(mainFrame)
  local specHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  specHeader:SetPoint("TOPLEFT", SPEC_COL_X, -34)
  specHeader:SetWidth(SPEC_COL_WIDTH)
  specHeader:SetJustifyH("RIGHT")

  local nameHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nameHeader:SetPoint("TOPLEFT", NAME_COL_X, -34)
  nameHeader:SetWidth(NAME_COL_WIDTH)
  nameHeader:SetJustifyH("LEFT")

  local ilvlHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  ilvlHeader:SetPoint("TOPLEFT", ILVL_COL_X, -34)
  ilvlHeader:SetWidth(ILVL_COL_WIDTH)
  ilvlHeader:SetJustifyH("RIGHT")

  local serverHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  serverHeader:SetPoint("TOPLEFT", SERVER_COL_X, -34)
  serverHeader:SetWidth(SERVER_COL_WIDTH)
  serverHeader:SetJustifyH("LEFT")

  local keyHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  keyHeader:SetPoint("TOPLEFT", KEY_COL_X, -34)
  keyHeader:SetWidth(KEY_COL_WIDTH)
  keyHeader:SetJustifyH("RIGHT")
  if keyHeader.SetWordWrap then
    keyHeader:SetWordWrap(false)
  end
  if keyHeader.SetNonSpaceWrap then
    keyHeader:SetNonSpaceWrap(false)
  end
  if keyHeader.SetMaxLines then
    keyHeader:SetMaxLines(1)
  end

  local rioHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rioHeader:SetPoint("TOPLEFT", RIO_COL_X, -34)
  rioHeader:SetWidth(RIO_COL_WIDTH)
  rioHeader:SetJustifyH("RIGHT")
  if rioHeader.SetWordWrap then
    rioHeader:SetWordWrap(false)
  end
  if rioHeader.SetNonSpaceWrap then
    rioHeader:SetNonSpaceWrap(false)
  end
  if rioHeader.SetMaxLines then
    rioHeader:SetMaxLines(1)
  end

  local dpsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  dpsHeader:SetPoint("TOPLEFT", DPS_COL_X, -34)
  dpsHeader:SetWidth(DPS_COL_WIDTH)
  dpsHeader:SetJustifyH("RIGHT")
  if dpsHeader.SetWordWrap then
    dpsHeader:SetWordWrap(false)
  end
  if dpsHeader.SetNonSpaceWrap then
    dpsHeader:SetNonSpaceWrap(false)
  end
  if dpsHeader.SetMaxLines then
    dpsHeader:SetMaxLines(1)
  end

  local kickHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  kickHeader:SetPoint("TOPLEFT", KICK_COL_X, -34)
  kickHeader:SetWidth(KICK_COL_WIDTH)
  kickHeader:SetJustifyH("RIGHT")

  local leadOptionsHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  leadOptionsHeader:SetPoint("TOPRIGHT", -10, -34)
  leadOptionsHeader:SetWidth(120)
  leadOptionsHeader:SetJustifyH("CENTER")

  local mplusManagementHeader = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mplusManagementHeader:SetPoint("TOPRIGHT", -3, -34)
  mplusManagementHeader:SetWidth(110)
  mplusManagementHeader:SetJustifyH("CENTER")

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
      guide:SetColorTexture(0.2, 0.8, 1, 0.28)
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
  clickHintFallback
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

    if type(tooltip.SetText) == "function" then
      tooltip:SetText(titleText, 1, 1, 1)
    end
    if type(tooltip.AddLine) == "function" then
      if type(descriptionText) == "string" and descriptionText ~= "" then
        tooltip:AddLine(descriptionText, 1, 1, 1, true)
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

local function CreateShareKeysButton(mainFrame, deps)
  local button = CreateFlatButton(mainFrame, 120, 24)
  button:SetPoint("TOPRIGHT", -10, -150)
  button._verticalY = -150
  local lastShareKeysClickAt = nil
  local countdownTicker = nil
  local debounceSeconds = tonumber(deps.shareKeysDebounceSeconds) or 0
  if debounceSeconds < 0 then
    debounceSeconds = 0
  end

  local function UpdateShareKeysButton(cooldownEnd)
    local now = type(deps.getTime) == "function" and tonumber(deps.getTime()) or 0
    local remaining = math.ceil(cooldownEnd - now)
    if remaining > 0 then
      button:SetEnabled(false)
      button:SetAlpha(0.5)
      local label = button._baseText or button._fullText or ""
      button._baseText = label
      local cooldownText = string.format("%s (%ds)", label, remaining)
      button._fullText = cooldownText
      SetFlatButtonText(button, cooldownText)
    else
      button:SetEnabled(true)
      button:SetAlpha(1.0)
      if button._baseText then
        button._fullText = button._baseText
        button._baseText = nil
      end
      SetFlatButtonText(button, button._fullText or "")
      if countdownTicker then
        countdownTicker:Cancel()
        countdownTicker = nil
      end
    end
  end

  local function StartCooldownDisplay(cooldownEnd)
    if countdownTicker then
      countdownTicker:Cancel()
      countdownTicker = nil
    end
    local C_Timer_ref = rawget(_G, "C_Timer")
    if not C_Timer_ref or type(C_Timer_ref.NewTicker) ~= "function" then
      return
    end
    countdownTicker = C_Timer_ref.NewTicker(1.0, function()
      UpdateShareKeysButton(cooldownEnd)
    end, debounceSeconds)
    UpdateShareKeysButton(cooldownEnd)
  end

  function button.TriggerRemoteCooldown()
    local now = type(deps.getTime) == "function" and tonumber(deps.getTime()) or nil
    if not now or debounceSeconds <= 0 then
      return
    end
    if lastShareKeysClickAt and (now - lastShareKeysClickAt) < debounceSeconds then
      return
    end
    lastShareKeysClickAt = now
    StartCooldownDisplay(now + debounceSeconds)
  end

  button:SetScript("OnClick", function()
    local now = type(deps.getTime) == "function" and tonumber(deps.getTime()) or nil
    if now and debounceSeconds > 0 and lastShareKeysClickAt and (now - lastShareKeysClickAt) < debounceSeconds then
      return
    end
    if now then
      lastShareKeysClickAt = now
      StartCooldownDisplay(now + debounceSeconds)
    end

    -- Post own key directly, then trigger all other isiLive group members to post theirs
    local ownLine = BuildOwnKeyAnnounceLine({
      getL = deps.getL,
      getRoster = deps.getRoster,
      getDungeonShortCode = deps.getDungeonShortCode,
    })
    if ownLine then
      if deps.isInGroup() then
        if not SendPartyChatMessage(ownLine) then
          print(ownLine)
        end
      else
        print(ownLine)
      end
    end
    if deps.isInGroup() and type(deps.sendShareKeysRequest) == "function" then
      deps.sendShareKeysRequest()
    end
  end)
  AttachPanelButtonTooltip(deps.tooltipFrame, button, deps.getL, "BTN_SHARE_KEYS", "TOOLTIP_ANNOUNCE_KEYS", nil)
  return button
end

local function CreatePanelButtons(mainFrame, deps)
  local getL = deps.getL
  local isPlayerLeader = deps.isPlayerLeader

  local readyCheckButton = CreateFlatButton(mainFrame, 120, 24)
  readyCheckButton:SetPoint("TOPRIGHT", -10, -60)
  readyCheckButton._verticalY = -60
  readyCheckButton:SetScript("OnClick", function()
    if not isPlayerLeader() then
      return
    end
    local doReadyCheck = _G.DoReadyCheck
    if type(doReadyCheck) == "function" then
      pcall(doReadyCheck)
    end
  end)
  AttachPanelButtonTooltip(deps.tooltipFrame, readyCheckButton, getL, "BTN_READYCHECK", "TOOLTIP_READY", isPlayerLeader)

  local countdownButton = CreateFlatButton(mainFrame, 120, 24)
  countdownButton:SetPoint("TOPRIGHT", -10, -90)
  countdownButton._verticalY = -90
  countdownButton:SetScript("OnClick", function()
    if not isPlayerLeader() then
      return
    end

    local partyInfo = rawget(_G, "C_PartyInfo")
    local doCountdown = partyInfo and partyInfo.DoCountdown or nil
    if type(doCountdown) == "function" then
      pcall(doCountdown, 10)
    end
  end)
  AttachPanelButtonTooltip(deps.tooltipFrame, countdownButton, getL, "BTN_COUNTDOWN10", "TOOLTIP_CD10", isPlayerLeader)

  local refreshButton = CreateFlatButton(mainFrame, 120, 24)
  refreshButton:SetPoint("TOPRIGHT", -10, -180)
  refreshButton._verticalY = -180
  AttachPanelButtonTooltip(deps.tooltipFrame, refreshButton, getL, "BTN_REFRESH", "TOOLTIP_REFRESH", nil)

  local shareKeysButton = CreateShareKeysButton(mainFrame, deps)

  local countdownCancelButton = CreateFlatButton(mainFrame, 120, 24)
  countdownCancelButton:SetPoint("TOPRIGHT", -10, -120)
  countdownCancelButton._verticalY = -120
  AttachPanelButtonTooltip(
    deps.tooltipFrame,
    countdownCancelButton,
    getL,
    "BTN_COUNTDOWN_CANCEL",
    "TOOLTIP_CD_CANCEL",
    isPlayerLeader
  )

  return {
    readyCheckButton = readyCheckButton,
    countdownButton = countdownButton,
    refreshButton = refreshButton,
    shareKeysButton = shareKeysButton,
    countdownCancelButton = countdownCancelButton,
  }
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

    if btn.SetNormalTexture then
      btn:SetNormalTexture(marker.icon)
    end
    if btn.SetAttribute then
      btn:SetAttribute("type1", "worldmarker") -- Left click: setzen
      btn:SetAttribute("marker1", marker.id)
      btn:SetAttribute("action1", "set")
      btn:SetAttribute("type2", "worldmarker") -- Right click: remove
      btn:SetAttribute("marker2", marker.id)
      btn:SetAttribute("action2", "clear")
    end
    if btn.RegisterForClicks then
      btn:RegisterForClicks("AnyUp", "AnyDown")
    end

    btn:SetScript("OnEnter", function(self)
      local tooltip = AnchorRosterHoverTooltip(tooltipFrame, self)
      if type(tooltip) == "table" and type(tooltip.SetText) == "function" then
        tooltip:SetText("World Marker: " .. marker.name, 1, 1, 1)
        if type(tooltip.AddLine) == "function" then
          tooltip:AddLine("Left-Click: Place", 0, 1, 0)
          tooltip:AddLine("Right-Click: Clear", 1, 0.2, 0.2)
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

local function ConstructPanelUI(mainFrame, uiDeps)
  local isRaidGroupFn = uiDeps.isRaidGroup

  -- Background for visibility
  do
    local uiCommon = addonTable and addonTable.UICommon
    if type(uiCommon) == "table" and type(uiCommon.ApplyBackdrop) == "function" then
      uiCommon.ApplyBackdrop(mainFrame, "MAIN_FRAME")
    end
  end
  if mainFrame.SetWidth then
    mainFrame:SetWidth(FULL_FRAME_WIDTH)
  end

  -- All three title elements share the same Y so they sit on one horizontal line.
  local TITLE_Y = -10

  local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 10, TITLE_Y)
  title:SetJustifyH("LEFT")
  title:SetTextColor(1, 0.85, 0)
  title:SetShadowOffset(1, -1)
  if type(title.SetShadowColor) == "function" then
    title:SetShadowColor(0, 0, 0, 0.8)
  end
  ApplyFontStringSize(title, 14)

  local titleVersion = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleVersion:SetPoint("LEFT", title, "RIGHT", 5, 0)
  titleVersion:SetTextColor(0.55, 0.75, 1.0)
  if type(titleVersion.SetShadowOffset) == "function" then
    titleVersion:SetShadowOffset(1, -1)
  end
  if type(titleVersion.SetShadowColor) == "function" then
    titleVersion:SetShadowColor(0, 0, 0, 0.9)
  end
  ApplyFontStringSize(titleVersion, 14)

  local titleHint = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleHint:SetPoint("LEFT", titleVersion, "RIGHT", 6, 0)
  titleHint:SetTextColor(0.45, 0.85, 0.45)
  if type(titleHint.SetShadowOffset) == "function" then
    titleHint:SetShadowOffset(1, -1)
  end
  if type(titleHint.SetShadowColor) == "function" then
    titleHint:SetShadowColor(0, 0, 0, 0.9)
  end
  ApplyFontStringSize(titleHint, 14)

  local headers = CreatePanelHeaders(mainFrame)
  local m2ColumnGuides = CreateM2ColumnGuides(mainFrame)
  local panelTooltip = CreateRosterHoverTooltip(mainFrame)
  local getL = type(uiDeps.getL) == "function" and uiDeps.getL or function()
    return {}
  end
  local L = getL()
  local buttonDeps = {}
  for key, value in pairs(uiDeps) do
    buttonDeps[key] = value
  end
  buttonDeps.tooltipFrame = panelTooltip
  local buttons = CreatePanelButtons(mainFrame, buttonDeps)
  local rosterTooltip = CreateRosterHoverTooltip(mainFrame)
  local tankButtons, tankHeader = CreateTankHelperButtons(mainFrame, panelTooltip, uiDeps.getL)

  local cdTrackerRow = CreateCdTrackerRow(mainFrame)
  local killTrackRow = CreateKillTrackRow(mainFrame)
  local statusLine = CreateStatusLine(mainFrame)
  local optionToggles = CreateSystemOptionToggles(mainFrame)
  local raidNoticeLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  raidNoticeLabel:SetPoint("TOP", 0, -100)
  local frameWidth = type(mainFrame.GetWidth) == "function" and mainFrame:GetWidth() or 400
  raidNoticeLabel:SetWidth(frameWidth - 16)
  raidNoticeLabel:SetJustifyH("CENTER")
  raidNoticeLabel:SetTextColor(1, 0.5, 0)
  raidNoticeLabel:SetWordWrap(true)
  raidNoticeLabel:Hide()

  local ui = {
    panelTooltip = panelTooltip,
    rosterTooltip = rosterTooltip,
    title = title,
    cdTrackerRow = cdTrackerRow,
    killTrackRow = killTrackRow,
    statusLine = statusLine,
    titleVersion = titleVersion,
    titleHint = titleHint,
    raidNoticeLabel = raidNoticeLabel,
    m2ColumnGuides = m2ColumnGuides,
    showRosterColumnGuides = uiDeps.showRosterColumnGuides,
    tankButtons = tankButtons,
    tankHeader = tankHeader,
    setMainFrameHeightSafe = uiDeps.setMainFrameHeightSafe,
    setMainFrameWidthSafe = uiDeps.setMainFrameWidthSafe,
    minFrameHeight = uiDeps.minFrameHeight,
    isPlayerLeader = uiDeps.isPlayerLeader,
    forceMarkersLeaderOnly = FORCE_MARKERS_LEADER_ONLY,
  }
  for k, v in pairs(headers) do
    ui[k] = v
  end
  for k, v in pairs(buttons) do
    ui[k] = v
  end
  for k, v in pairs(optionToggles) do
    ui[k] = v
  end

  ui.managementButtons = {
    ui.readyCheckButton,
    ui.countdownButton,
    ui.countdownCancelButton,
  }
  -- Buttons die immer am leadX verankert bleiben (nicht in H-Modus sichtbar)
  ui.columnButtons = {
    ui.shareKeysButton,
    ui.refreshButton,
  }
  ui.toolbarButtons = {
    ui.readyCheckButton,
    ui.countdownButton,
    ui.countdownCancelButton,
    ui.shareKeysButton,
    ui.refreshButton,
  }

  -- Drei statische Mode-Buttons [M2][H][V] von links nach rechts oben-rechts.
  -- Jeder Button setzt den Modus direkt; aktiver Modus wird gold hervorgehoben.
  ui.layoutMode = LAYOUT_MODE_EXPANDED
  ui.isCollapsed = false
  ui.modeButtons = {}
  local modeButtonDefs = {
    {
      xOffset = -88,
      label = "M2",
      target = LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL,
      width = 24,
      descriptionKey = "MODE_LAYOUT_M2",
      descriptionFallback = L.MODE_LAYOUT_M2 or "Main horizontal layout.",
    },
    {
      xOffset = -64,
      label = "H",
      target = LAYOUT_MODE_COMPACT_HORIZONTAL,
      descriptionKey = "MODE_LAYOUT_H",
      descriptionFallback = L.MODE_LAYOUT_H or "Compact horizontal layout.",
    },
    {
      xOffset = -44,
      label = "V",
      target = LAYOUT_MODE_COMPACT_VERTICAL,
      descriptionKey = "MODE_LAYOUT_V",
      descriptionFallback = L.MODE_LAYOUT_V or "Compact vertical layout.",
    },
  }
  for _, def in ipairs(modeButtonDefs) do
    local target = def.target
    local function ApplyRequestedLayoutMode()
      if isRaidGroupFn() and target ~= LAYOUT_MODE_COMPACT_HORIZONTAL then
        return
      end
      ui.layoutMode = target
      local db = GetDB()
      if db then
        db.rosterLayoutMode = target
      end
      UpdateCollapseState(ui, target, mainFrame)
      NotifyCollapseChanged(ui, ui.isCollapsed)
      NotifyLayoutChanged(ui, ui.layoutMode)
    end
    local btn = CreateModeButton(mainFrame, def.xOffset, def.label, target, function()
      ApplyRequestedLayoutMode()
    end, def.width)
    AttachModeButtonTooltip(
      panelTooltip,
      btn,
      getL,
      def.label,
      def.descriptionKey,
      def.descriptionFallback,
      "TOOLTIP_LAYOUT_SWITCH",
      L.TOOLTIP_LAYOUT_SWITCH or "Click to switch layout."
    )
    table.insert(ui.modeButtons, btn)
  end
  UpdateCollapseState(ui, LAYOUT_MODE_EXPANDED, mainFrame)

  AttachSystemOptionToggleWatcher(mainFrame, ui)
  return ui
end

local function IsEntryAtTargetDungeon(targetMapID, entry, info)
  local isAtDungeon = false

  if targetMapID and entry and entry.unit then
    local mapApi = rawget(_G, "C_Map")
    local getBestMapForUnit = mapApi and mapApi.GetBestMapForUnit or nil
    if type(getBestMapForUnit) == "function" then
      local ok, playerMapID = pcall(getBestMapForUnit, entry.unit)
      if ok and playerMapID and tonumber(playerMapID) == tonumber(targetMapID) then
        isAtDungeon = true
      end
    end
  end

  if not isAtDungeon and targetMapID and info and info.syncLocMapID then
    if tonumber(info.syncLocMapID) == tonumber(targetMapID) then
      isAtDungeon = true
    end
  end

  return isAtDungeon
end

local function BuildRowDisplayData(state, entry, isReadyCheckActive, targetMapID)
  local info = entry and entry.info or {}

  return state.buildDisplayData(info, {
    unit = entry and entry.unit or nil,
    truncateName = state.truncateName,
    getShortSpecLabel = state.getShortSpecLabel,
    getLanguageFlagMarkup = state.getLanguageFlagMarkup,
    getDungeonShortCode = state.getDungeonShortCode,
    getRioDelta = state.getRioDelta,
    syncMarker = state.syncMarker,
    syncBadge = state.syncBadge,
    syncSummary = state.getPlayerSyncSummary and state.getPlayerSyncSummary(info.name, info.realm) or nil,
    isReadyCheckActive = isReadyCheckActive,
    getReadyCheckReadyUntil = state.getReadyCheckReadyUntil,
    getReadyCheckDeclinedUntil = state.getReadyCheckDeclinedUntil,
    getTime = state.getTime,
    isAtDungeon = IsEntryAtTargetDungeon(targetMapID, entry, info),
  })
end

local function ApplyRowNameDisplay(row, displayData)
  if not row or not row.name or type(row.name.SetText) ~= "function" then
    return
  end

  row.name:SetText(
    (displayData.readyCheckMarkup or "")
      .. " |c"
      .. displayData.colorHex
      .. displayData.displayName
      .. "|r"
      .. displayData.atDungeonMarker
      .. displayData.addonMarker
  )
end

local function ApplyRowSpecDisplay(row, displayData)
  if not row or not row.spec or type(row.spec.SetText) ~= "function" then
    return
  end

  row.spec:SetText("|c" .. displayData.colorHex .. displayData.specText .. "|r")
end

local function ApplyRowReadyCheckDisplay(row, displayData)
  local background = row and row.readyCheckBackground or nil
  local color = displayData and displayData.readyCheckBackgroundColor or nil
  if not background then
    return
  end

  if type(color) == "table" and #color >= 4 then
    background:SetColorTexture(color[1], color[2], color[3], color[4])
    background:Show()
  else
    background:Hide()
  end
end

local function SetKickCellText(cell, info)
  if not cell then
    return
  end
  if type(info) ~= "table" or info.syncHasKick == false then
    cell:SetText("|cff666666-|r")
    return
  end
  if info.syncKickOnCooldown == true then
    local secs = math.ceil(info.syncKickRemain or 0)
    if secs > 0 then
      cell:SetText(string.format("|cffff4040%ds|r", secs))
    else
      cell:SetText("|cff666666-|r")
    end
    return
  end
  if info.syncKickOnCooldown == false then
    cell:SetText("|cff44ff44ready|r")
    return
  end
  cell:SetText("|cff666666-|r")
end

local function RenderRosterImpl(state, roster)
  local memberRows = state.memberRows
  local mainFrame = state.mainFrame
  local shareKeysButton = state.shareKeysButton
  local rosterTooltip = state.rosterTooltip
  local setMainFrameHeightSafe = state.setMainFrameHeightSafe
  local minFrameHeight = state.minFrameHeight
  local raidNoticeLabel = state.raidNoticeLabel

  if state.uiRef then
    state.uiRef.memberRows = memberRows
  end
  local layoutMode = state.uiRef and state.uiRef.layoutMode or LAYOUT_MODE_EXPANDED
  local isCollapsed = IsCompactLayoutMode(layoutMode)

  local function ClearMemberRow(row)
    row.spec:SetText("")
    row.name:SetText("")
    row.realm:SetText("")
    row.key:SetText("")
    row.ilvl:SetText("")
    row.rio:SetText("")
    row.dps:SetText("")
    if row.kick then
      row.kick:SetText("")
    end
    row.unit = nil
    row.tooltipName = nil
    row.tooltipRealm = nil
    row.tooltipInfo = nil
    row.getDungeonShortCode = nil
    row.getDungeonName = nil
    row.getPlayerLastRunDps = nil
    row.getLanguageTooltipMarkup = nil
    row.getL = nil
    if row.hoverFrame then
      HideRosterHoverTooltip(rosterTooltip)
      row.hoverFrame.unit = nil
      row.hoverFrame:Hide()
    end
    if row.readyCheckBackground then
      row.readyCheckBackground:Hide()
    end
    if row.roleButton and not IsCombatLockdownActive() then
      row.roleButton:Hide()
    end
  end

  -- If in a raid group, clear rows and skip roster render (H mode shows the tool buttons)
  if state.isRaidGroup and state.isRaidGroup() then
    for _, row in pairs(memberRows) do
      ClearMemberRow(row)
    end
    if raidNoticeLabel then
      raidNoticeLabel:Hide()
    end
    return
  end

  -- Normal case: hide notice, show rows
  if raidNoticeLabel then
    raidNoticeLabel:Hide()
  end

  -- Temporarily hidden in Settings: keep the DPS/Deaths/Kicks columns hard-enabled in runtime.
  local showDpsColumn = FORCE_SHOW_DPS_COLUMN
  if state.uiRef then
    local function setHeaderVisible(key, visible)
      local h = state.uiRef[key]
      if h then
        if visible then
          h:Show()
        else
          h:Hide()
        end
      end
    end
    setHeaderVisible("dpsHeader", showDpsColumn)
    setHeaderVisible("kickHeader", showDpsColumn)
  end

  if state.uiRef and state.uiRef.tankButtons and not IsCombatLockdownActive() then
    local isMainHorizontal = IsMainHorizontalLayoutMode(state.uiRef.layoutMode)
    local showMarkers = not isMainHorizontal
    for _, btn in ipairs(state.uiRef.tankButtons) do
      if showMarkers then
        btn:Show()
      else
        btn:Hide()
      end
    end
    if state.uiRef.tankHeader then
      if showMarkers then
        state.uiRef.tankHeader:Show()
      else
        state.uiRef.tankHeader:Hide()
      end
    end
  end

  for _, row in pairs(memberRows) do
    ClearMemberRow(row)
  end

  local index = 1
  local orderedRoster = state.buildOrderedRoster(roster, state.rolePriority, state.unitPriority)
  local activeKeyOwnerUnit = state.resolveActiveKeyOwnerUnit()
  local isReadyCheckActive = state.isReadyCheckActive and state.isReadyCheckActive() or false
  local targetMapID = state.resolveTargetMapID and state.resolveTargetMapID() or nil
  local hasAnyKey = false

  for _, entry in ipairs(orderedRoster) do
    if index > 5 then
      break
    end

    local info = entry.info
    if info.keyLevel and tonumber(info.keyLevel) > 0 then
      hasAnyKey = true
    end

    local row = memberRows[index]
    if not row then
      row = CreateMemberRow(mainFrame, index, rosterTooltip)
      memberRows[index] = row
    end

    if row.roleButton then
      local role = info.role
      local icon = row.roleButton.icon
      local showButton = false

      if role == "TANK" then
        icon:SetTexCoord(0, 19 / 64, 22 / 64, 41 / 64)
        showButton = true
      elseif role == "HEALER" then
        icon:SetTexCoord(20 / 64, 39 / 64, 1 / 64, 20 / 64)
        showButton = true
      elseif role == "DAMAGER" then
        icon:SetTexCoord(20 / 64, 39 / 64, 22 / 64, 41 / 64)
        showButton = true
      end

      if info.isGhost then
        showButton = false
      end

      if not IsCombatLockdownActive() then
        if showButton and not isCollapsed then
          row.roleButton:Show()
          row.roleButton:SetAttribute("type1", "macro")
          row.roleButton:SetAttribute("type2", "macro")
          if role == "TANK" then
            -- Blue Square = 6
            row.roleButton:SetAttribute("macrotext1", "/target " .. entry.unit .. "\n/tm 6\n/targetlasttarget")
            row.roleButton:SetAttribute("macrotext2", "/target " .. entry.unit .. "\n/tm 0\n/targetlasttarget")
          elseif role == "HEALER" then
            -- Green Triangle = 4
            row.roleButton:SetAttribute("macrotext1", "/target " .. entry.unit .. "\n/tm 4\n/targetlasttarget")
            row.roleButton:SetAttribute("macrotext2", "/target " .. entry.unit .. "\n/tm 0\n/targetlasttarget")
          else
            row.roleButton:SetAttribute("macrotext1", nil)
            row.roleButton:SetAttribute("macrotext2", nil)
          end
        else
          row.roleButton:Hide()
        end
      end
    end

    local displayData = BuildRowDisplayData(state, entry, isReadyCheckActive, targetMapID)

    ApplyRowReadyCheckDisplay(row, displayData)
    ApplyRowSpecDisplay(row, displayData)
    -- Skip displayData.roleIconMarkup since we render it as a secure button
    ApplyRowNameDisplay(row, displayData)
    row.realm:SetText(displayData.languageDisplay)
    if displayData.keyText ~= "-" and activeKeyOwnerUnit and entry.unit == activeKeyOwnerUnit then
      row.key:SetText("|cffff4040" .. displayData.keyText .. "|r")
    else
      row.key:SetText(displayData.keyText)
    end
    row.ilvl:SetText(displayData.ilvlText)
    row.rio:SetText(displayData.rioText)
    local showDps = FORCE_SHOW_DPS_COLUMN
    if showDps then
      local dpsText = "-"
      if type(state.getPlayerLastRunDps) == "function" then
        dpsText = FormatCompactTooltipNumber(state.getPlayerLastRunDps(info.name, info.realm)) or "-"
      end
      if dpsText == "-" and info.syncDps and info.syncDps > 0 then
        dpsText = FormatCompactTooltipNumber(info.syncDps) or "-"
      end
      row.dps:SetText(dpsText)
      row.dps:Show()
    else
      row.dps:SetText("")
      row.dps:Hide()
    end
    if row.kick then
      -- Refresh kick sync state from cache before rendering.
      if type(state.applyKnownKeyToRosterEntry) == "function" then
        state.applyKnownKeyToRosterEntry(info)
      end
      SetKickCellText(row.kick, info)
    end
    row.unit = entry.unit
    row.tooltipName = info and info.name or nil
    row.tooltipRealm = info and info.realm or nil
    row.tooltipInfo = info
    row.getDungeonShortCode = state.getDungeonShortCode
    row.getDungeonName = state.getDungeonName
    row.getPlayerLastRunDps = state.getPlayerLastRunDps
    row.getLanguageTooltipMarkup = state.getLanguageTooltipMarkup
    row.getL = state.getL
    if row.hoverFrame then
      row.hoverFrame.unit = entry.unit
      row.hoverFrame:Show()
      if isCollapsed then
        row.hoverFrame:Hide()
      end
    end
    index = index + 1
  end

  shareKeysButton:SetEnabled(hasAnyKey)
  shareKeysButton:SetAlpha(hasAnyKey and 1 or 0.45)

  local cdTrackerExtra = IsMainHorizontalLayoutMode(layoutMode) and CD_TRACKER_ROW_HEIGHT or 0
  local desiredHeight = isCollapsed and GetFrameHeightForLayoutMode(layoutMode, minFrameHeight)
    or math.max(minFrameHeight, 45 + index * 16) + cdTrackerExtra
  setMainFrameHeightSafe(desiredHeight)

  if state.uiRef then
    UpdateCollapseState(state.uiRef, layoutMode, mainFrame)
  end
end

local function RefreshReadyCheckStateImpl(state, roster)
  local memberRows = state.memberRows or {}
  local orderedRoster = state.buildOrderedRoster(roster, state.rolePriority, state.unitPriority)
  local isReadyCheckActive = state.isReadyCheckActive and state.isReadyCheckActive() or false
  local targetMapID = state.resolveTargetMapID and state.resolveTargetMapID() or nil

  local index = 1
  for _, entry in ipairs(orderedRoster) do
    if index > 5 then
      break
    end

    local row = memberRows[index]
    if row then
      local displayData = BuildRowDisplayData(state, entry, isReadyCheckActive, targetMapID)
      ApplyRowReadyCheckDisplay(row, displayData)
      ApplyRowSpecDisplay(row, displayData)
      ApplyRowNameDisplay(row, displayData)
    end

    index = index + 1
  end
end

function RosterPanel.CreateController(opts)
  opts = opts or {}

  local mainFrame = assert(opts.mainFrame, "isiLive: RosterPanel requires mainFrame")
  local getL = RequireFunction(opts.getL, "getL")
  local isPlayerLeader = RequireFunction(opts.isPlayerLeader, "isPlayerLeader")
  local getAddonVersionText = RequireFunction(opts.getAddonVersionText, "getAddonVersionText")
  local updateStatusLine = RequireFunction(opts.updateStatusLine, "updateStatusLine")
  local setMainFrameHeightSafe = RequireFunction(opts.setMainFrameHeightSafe, "setMainFrameHeightSafe")
  local setMainFrameWidthSafe = RequireFunction(opts.setMainFrameWidthSafe, "setMainFrameWidthSafe")
  local minFrameHeight = tonumber(opts.minFrameHeight) or DEFAULT_MIN_FRAME_HEIGHT

  local buildOrderedRoster = RequireFunction(opts.buildOrderedRoster, "buildOrderedRoster")
  local buildDisplayData = RequireFunction(opts.buildDisplayData, "buildDisplayData")
  local truncateName = RequireFunction(opts.truncateName, "truncateName")
  local getShortSpecLabel = RequireFunction(opts.getShortSpecLabel, "getShortSpecLabel")
  local getLanguageFlagMarkup = RequireFunction(opts.getLanguageFlagMarkup, "getLanguageFlagMarkup")
  local getLanguageTooltipMarkup = type(opts.getLanguageTooltipMarkup) == "function" and opts.getLanguageTooltipMarkup
    or nil
  if not getLanguageTooltipMarkup then
    local localeModule = addonTable and addonTable.Locale
    if type(localeModule) == "table" and type(localeModule.GetLanguageTooltipMarkup) == "function" then
      local locale = rawget(_G, "GetLocale") and GetLocale() or nil
      getLanguageTooltipMarkup = function(languageTag)
        return localeModule.GetLanguageTooltipMarkup(languageTag, locale)
      end
    else
      getLanguageTooltipMarkup = function(languageTag)
        return getLanguageFlagMarkup(languageTag)
      end
    end
  end
  local getDungeonShortCode = RequireFunction(opts.getDungeonShortCode, "getDungeonShortCode")
  local getDungeonName = type(opts.getDungeonName) == "function" and opts.getDungeonName or nil
  local getRioDelta = type(opts.getRioDelta) == "function" and opts.getRioDelta or nil
  local getPlayerSyncSummary = type(opts.getPlayerSyncSummary) == "function" and opts.getPlayerSyncSummary or nil
  local resolveActiveKeyOwnerUnit = RequireFunction(opts.resolveActiveKeyOwnerUnit, "resolveActiveKeyOwnerUnit")
  local getRoster = RequireFunction(opts.getRoster, "getRoster")
  local isReadyCheckActive = type(opts.isReadyCheckActive) == "function" and opts.isReadyCheckActive or nil
  local getReadyCheckReadyUntil = type(opts.getReadyCheckReadyUntil) == "function" and opts.getReadyCheckReadyUntil
    or nil
  local getReadyCheckDeclinedUntil = type(opts.getReadyCheckDeclinedUntil) == "function"
      and opts.getReadyCheckDeclinedUntil
    or nil
  local resolveTargetMapID = type(opts.resolveTargetMapID) == "function" and opts.resolveTargetMapID or nil
  local isInGroup = RequireFunction(opts.isInGroup, "isInGroup")
  local isRaidGroup = type(opts.isRaidGroup) == "function" and opts.isRaidGroup or function()
    return false
  end
  local rolePriority = assert(opts.rolePriority, "isiLive: RosterPanel requires rolePriority")
  local unitPriority = assert(opts.unitPriority, "isiLive: RosterPanel requires unitPriority")
  local syncMarker = tostring(opts.syncMarker or "")
  local syncBadge = tostring(opts.syncBadge or "")
  local applyKnownKeyToRosterEntry = type(opts.applyKnownKeyToRosterEntry) == "function"
      and opts.applyKnownKeyToRosterEntry
    or nil
  local getTime = type(opts.getTime) == "function" and opts.getTime
    or function()
      if type(GetTime) == "function" then
        return GetTime()
      end
      return nil
    end
  local shareKeysDebounceSeconds = tonumber(opts.shareKeysDebounceSeconds) or 1
  if shareKeysDebounceSeconds < 0 then
    shareKeysDebounceSeconds = 0
  end
  local sendShareKeysRequest = type(opts.sendShareKeysRequest) == "function" and opts.sendShareKeysRequest or nil
  local getPlayerLastRunDps = type(opts.getPlayerLastRunDps) == "function" and opts.getPlayerLastRunDps or nil
  local showRosterColumnGuides = type(opts.showRosterColumnGuides) == "function" and opts.showRosterColumnGuides
    or function()
      return false
    end

  local ui = ConstructPanelUI(mainFrame, {
    getL = getL,
    isPlayerLeader = isPlayerLeader,
    getAddonVersionText = getAddonVersionText,
    updateStatusLine = updateStatusLine,
    setMainFrameHeightSafe = setMainFrameHeightSafe,
    setMainFrameWidthSafe = setMainFrameWidthSafe,
    minFrameHeight = minFrameHeight,
    getRoster = getRoster,
    buildOrderedRoster = buildOrderedRoster,
    rolePriority = rolePriority,
    unitPriority = unitPriority,
    getDungeonShortCode = getDungeonShortCode,
    applyKnownKeyToRosterEntry = applyKnownKeyToRosterEntry,
    isInGroup = isInGroup,
    getTime = getTime,
    shareKeysDebounceSeconds = shareKeysDebounceSeconds,
    sendShareKeysRequest = sendShareKeysRequest,
    isRaidGroup = isRaidGroup,
    showRosterColumnGuides = showRosterColumnGuides,
  })

  local readyCheckButton = ui.readyCheckButton
  local countdownButton = ui.countdownButton
  local refreshButton = ui.refreshButton
  local shareKeysButton = ui.shareKeysButton
  local countdownCancelButton = ui.countdownCancelButton

  local memberRows = {}
  local cdController = nil
  local cdTrackerNeedsVisibleRescan = true

  local function IsMainFrameShown()
    return type(mainFrame.IsShown) == "function" and mainFrame:IsShown() == true
  end

  local function MarkCdTrackerDirty()
    cdTrackerNeedsVisibleRescan = true
  end

  local function MaybeRescanCdTrackerForVisibleRender()
    if not cdController or type(cdController.Scan) ~= "function" then
      return
    end
    if not IsMainFrameShown() then
      MarkCdTrackerDirty()
      return
    end
    if cdTrackerNeedsVisibleRescan then
      cdController.Scan()
      cdTrackerNeedsVisibleRescan = false
    end
  end

  local controller = {}

  function controller.ApplyLocalization()
    local L = getL()
    local titleName = tostring(L.TITLE or "isiLive")
    local addonVer = rawget(_G, "C_AddOns")
        and type(C_AddOns.GetAddOnMetadata) == "function"
        and C_AddOns.GetAddOnMetadata("isiLive", "Version")
      or nil
    local titleVer = addonVer and ("v" .. addonVer) or ""
    ui.title:SetText(titleName)
    if ui.titleVersion then
      ui.titleVersion:SetText(titleVer)
    end
    if ui.titleHint then
      ui.titleHint:SetText(tostring(L.TITLE_HINT or ""))
    end
    ui.specHeader:SetText(L.COL_SPEC)
    ui.nameHeader:SetText(L.COL_NAME)
    ui.serverHeader:SetText(L.COL_LANGUAGE)
    ui.keyHeader:SetText(L.COL_KEY)
    ui.ilvlHeader:SetText(L.COL_ILVL)
    ui.rioHeader:SetText(L.COL_RIO)
    ui.dpsHeader:SetText(L.COL_DPS)
    if ui.kickHeader then
      ui.kickHeader:SetText("Kick")
    end
    ui.leadOptionsHeader:SetText(L.LEAD_OPTIONS)
    ui.mplusManagementHeader:SetText(L.MPLUS_MANAGEMENT)
    readyCheckButton._fullText = L.BTN_READYCHECK
    readyCheckButton._hModeText = L.BTN_READYCHECK_SHORT
    countdownButton._fullText = L.BTN_COUNTDOWN10
    countdownButton._hModeText = L.BTN_COUNTDOWN10_SHORT
    countdownCancelButton._fullText = L.BTN_COUNTDOWN_CANCEL
    countdownCancelButton._hModeText = L.BTN_COUNTDOWN_CANCEL_SHORT
    shareKeysButton._fullText = L.BTN_SHARE_KEYS
    refreshButton._fullText = L.BTN_REFRESH
    local isH = IsHorizontalCompactLayoutMode(ui and ui.layoutMode)
    SetFlatButtonText(readyCheckButton, isH and readyCheckButton._hModeText or readyCheckButton._fullText)
    SetFlatButtonText(countdownButton, isH and countdownButton._hModeText or countdownButton._fullText)
    SetFlatButtonText(
      countdownCancelButton,
      isH and countdownCancelButton._hModeText or countdownCancelButton._fullText
    )
    SetFlatButtonText(refreshButton, refreshButton._fullText)
    SetFlatButtonText(shareKeysButton, shareKeysButton._fullText)
    ui.advancedCombatLoggingToggle.label:SetText(L.OPT_ADVANCED_COMBAT_LOGGING)
    ui.damageMeterResetToggle.label:SetText(L.OPT_DAMAGE_METER_RESET)
    LayoutSystemOptionToggles(ui)
    RefreshSystemOptionToggles(ui)
  end

  function controller.IsCollapsed()
    return ui.isCollapsed
  end

  function controller.GetLayoutMode()
    return ui.layoutMode
  end

  function controller.RestoreSavedState()
    local savedLayoutMode = ResolveConfiguredDefaultOpenLayoutMode()
    if savedLayoutMode == DEFAULT_LAYOUT_MODE_LAST_USED then
      local db = GetDB()
      local lastUsedLayoutMode = type(db) == "table" and db.rosterLayoutMode or nil
      if lastUsedLayoutMode == nil or lastUsedLayoutMode == false or lastUsedLayoutMode == "" then
        savedLayoutMode = LAYOUT_MODE_COMPACT_MAIN_HORIZONTAL
      else
        savedLayoutMode = lastUsedLayoutMode
      end
    end
    local db = GetDB()
    if savedLayoutMode == nil then
      savedLayoutMode = db and db.rosterLayoutMode or nil
    end
    if savedLayoutMode == nil and db and db.rosterCollapsed ~= nil then
      savedLayoutMode = db.rosterCollapsed and LAYOUT_MODE_COMPACT_VERTICAL or LAYOUT_MODE_EXPANDED
    end
    if savedLayoutMode ~= nil then
      ui.layoutMode = NormalizeLayoutMode(savedLayoutMode)
      UpdateCollapseState(ui, ui.layoutMode, mainFrame)
      NotifyCollapseChanged(ui, ui.isCollapsed)
      NotifyLayoutChanged(ui, ui.layoutMode)
    end
  end

  function controller.RefreshLayoutState()
    if type(ui) == "table" then
      UpdateCollapseState(ui, ui.layoutMode, mainFrame)
    end
  end

  function controller.SetCollapseChangedHandler(handler)
    ui.onCollapseChanged = type(handler) == "function" and handler or nil
  end

  function controller.SetLayoutChangedHandler(handler)
    ui.onLayoutChanged = type(handler) == "function" and handler or nil
  end

  function controller.UpdateLeaderButtons()
    local enabled = isPlayerLeader()
    readyCheckButton:SetEnabled(enabled)
    countdownButton:SetEnabled(enabled)
    countdownCancelButton:SetEnabled(enabled)
    readyCheckButton:SetAlpha(enabled and 1 or 0.45)
    countdownButton:SetAlpha(enabled and 1 or 0.45)
    countdownCancelButton:SetAlpha(enabled and 1 or 0.45)
    RefreshSystemOptionToggles(ui)
    updateStatusLine()
  end

  function controller.RenderRoster(roster)
    MaybeRescanCdTrackerForVisibleRender()
    RenderRosterImpl({
      memberRows = memberRows,
      mainFrame = mainFrame,
      shareKeysButton = shareKeysButton,
      rosterTooltip = ui.rosterTooltip,
      setMainFrameHeightSafe = setMainFrameHeightSafe,
      minFrameHeight = minFrameHeight,
      buildOrderedRoster = buildOrderedRoster,
      rolePriority = rolePriority,
      unitPriority = unitPriority,
      resolveActiveKeyOwnerUnit = resolveActiveKeyOwnerUnit,
      isReadyCheckActive = isReadyCheckActive,
      resolveTargetMapID = resolveTargetMapID,
      buildDisplayData = buildDisplayData,
      truncateName = truncateName,
      getShortSpecLabel = getShortSpecLabel,
      getLanguageFlagMarkup = getLanguageFlagMarkup,
      getLanguageTooltipMarkup = getLanguageTooltipMarkup,
      getDungeonShortCode = getDungeonShortCode,
      getDungeonName = getDungeonName,
      getRioDelta = getRioDelta,
      syncMarker = syncMarker,
      syncBadge = syncBadge,
      getPlayerSyncSummary = getPlayerSyncSummary,
      getPlayerLastRunDps = getPlayerLastRunDps,
      getReadyCheckReadyUntil = getReadyCheckReadyUntil,
      getReadyCheckDeclinedUntil = getReadyCheckDeclinedUntil,
      getTime = getTime,
      getL = getL,
      isRaidGroup = isRaidGroup,
      raidNoticeLabel = ui.raidNoticeLabel,
      uiRef = ui,
      applyKnownKeyToRosterEntry = applyKnownKeyToRosterEntry,
    }, roster)
    RefreshSystemOptionToggles(ui)
    UpdateCdTrackerRow(ui.cdTrackerRow, cdController)
    UpdateKillTrackRow(ui.killTrackRow)
  end

  function controller.RefreshReadyCheckState(roster)
    RefreshReadyCheckStateImpl({
      memberRows = memberRows,
      buildOrderedRoster = buildOrderedRoster,
      rolePriority = rolePriority,
      unitPriority = unitPriority,
      isReadyCheckActive = isReadyCheckActive,
      resolveTargetMapID = resolveTargetMapID,
      buildDisplayData = buildDisplayData,
      truncateName = truncateName,
      getShortSpecLabel = getShortSpecLabel,
      getLanguageFlagMarkup = getLanguageFlagMarkup,
      getDungeonShortCode = getDungeonShortCode,
      getDungeonName = getDungeonName,
      getRioDelta = getRioDelta,
      syncMarker = syncMarker,
      syncBadge = syncBadge,
      getPlayerSyncSummary = getPlayerSyncSummary,
      getReadyCheckReadyUntil = getReadyCheckReadyUntil,
      getReadyCheckDeclinedUntil = getReadyCheckDeclinedUntil,
      getTime = getTime,
    }, roster or getRoster())
  end

  function controller.RefreshSystemOptionToggles()
    RefreshSystemOptionToggles(ui)
  end

  function controller.RefreshKickColumn()
    for _, row in pairs(memberRows) do
      if row.kick and row.tooltipInfo then
        local info = row.tooltipInfo
        if type(applyKnownKeyToRosterEntry) == "function" then
          applyKnownKeyToRosterEntry(info)
        end
        SetKickCellText(row.kick, info)
      end
    end
  end

  function controller.SetCdController(ctrl)
    cdController = ctrl
    MarkCdTrackerDirty()
  end

  function controller.RefreshCdTracker()
    cdTrackerNeedsVisibleRescan = false
    UpdateCdTrackerRow(ui.cdTrackerRow, cdController)
  end

  function controller.RefreshKillTrackRow()
    UpdateKillTrackRow(ui.killTrackRow)
  end

  function controller.MarkCdTrackerDirty()
    MarkCdTrackerDirty()
  end

  AttachControllerAccessors(controller, {
    refreshButton = refreshButton,
    countdownCancelButton = countdownCancelButton,
    statusLine = ui.statusLine,
    shareKeysButton = shareKeysButton,
  })

  return controller
end
