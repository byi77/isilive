local _, addonTable = ...

addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))
addonTable._RosterInternal = addonTable._RosterInternal or {}
local RI = addonTable._RosterInternal
local UICommon = addonTable.UICommon or {}
local IsSecretValue = addonTable.Validators.IsSecretValue
local SetReadableText = type(UICommon.SetReadableText) == "function" and UICommon.SetReadableText
  or function(fontString, text)
    if type(fontString) == "table" and type(fontString.SetText) == "function" then
      fontString:SetText(tostring(text or ""))
      return true
    end
    return false
  end

local CreateFrame = rawget(_G, "CreateFrame")

local function Trace(msg)
  local logger = RI._rosterPanelLogger
  if logger then
    logger("RosterPanel: " .. msg)
  end
end

-- Tooltip imports.
local DisableFontStringWrapping = RI.DisableFontStringWrapping or function(_fs) end
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

-- Layout / state imports.
local LAYOUT_MODE_EXPANDED = RI.LAYOUT_MODE_EXPANDED or "expanded"
local LAYOUT_MODE_COMPACT_VERTICAL = RI.LAYOUT_MODE_COMPACT_VERTICAL or "compact_vertical"
local NormalizeLayoutMode = RI.NormalizeLayoutMode or function(mode)
  return mode or LAYOUT_MODE_EXPANDED
end
local IsCompactLayoutMode = RI.IsCompactLayoutMode or function(_mode)
  return false
end
local IsMainHorizontalLayoutMode = RI.IsMainHorizontalLayoutMode
  or RI.IsStackedModernLayoutMode
  or function(_mode)
    return false
  end
local IsCombatLockdownActive = RI.IsCombatLockdownActive or function()
  return false
end
local GetFrameHeightForLayoutMode = RI.GetFrameHeightForLayoutMode or function(_mode, minHeight)
  return minHeight
end
local UpdateCollapseState = RI.UpdateCollapseState or function(_ui, _mode, _frame) end
local CD_TRACKER_ROW_HEIGHT = RI.CD_TRACKER_ROW_HEIGHT or 20

-- Column position constants (defined in isiLive_roster_panel_chrome.lua).
local SPEC_COL_X = RI.SPEC_COL_X or 4
local NAME_COL_X = RI.NAME_COL_X or 93
local SERVER_COL_X = RI.SERVER_COL_X or 75
local KEY_COL_X = RI.KEY_COL_X or 216
local ILVL_COL_X = RI.ILVL_COL_X or 282
local RIO_COL_X = RI.RIO_COL_X or 318
local SPEC_COL_WIDTH = RI.SPEC_COL_WIDTH or 52
local NAME_COL_WIDTH = RI.NAME_COL_WIDTH or 122
local SERVER_COL_WIDTH = RI.SERVER_COL_WIDTH or 18
local KEY_COL_WIDTH = RI.KEY_COL_WIDTH or 62
local ILVL_COL_WIDTH = RI.ILVL_COL_WIDTH or 32
local RIO_COL_WIDTH = RI.RIO_COL_WIDTH or 84
local DPS_COL_X = RI.DPS_COL_X or (RIO_COL_X + RIO_COL_WIDTH + 2)
local DPS_COL_WIDTH = RI.DPS_COL_WIDTH or 40
local KICK_COL_X = RI.KICK_COL_X or (DPS_COL_X + DPS_COL_WIDTH + 4)
local KICK_COL_WIDTH = RI.KICK_COL_WIDTH or 32
local KICK_HOVER_WIDTH = KICK_COL_WIDTH
local ROLE_BUTTON_X = SPEC_COL_X + SPEC_COL_WIDTH + 4

-- Raid-target marker per role: 6 = Blue Square (Tank), 4 = Green Triangle (Healer).
-- Right-click clears via marker 0.
local ROLE_MARKER = { TANK = 6, HEALER = 4 }
local CLEAR_MARKER = 0

-- These settings are temporarily hidden from Blizzard Settings.
-- Keep the runtime behavior hard-forced until the controls are re-enabled.
local FORCE_SHOW_DPS_COLUMN = true

local function CreateMemberRow(mainFrame, index, rosterTooltip, getL)
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
      local target = addonTable.StringUtils.BuildQualifiedName(row.tooltipName, row.tooltipRealm)
      if target then
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
    altBg:SetColorTexture(unpack((UICommon.Colors and UICommon.Colors.ROW_ALT) or { 1, 1, 1, 0.03 }))
  end

  row.readyCheckBackground = row.hoverFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
  row.readyCheckBackground:SetAllPoints()
  row.readyCheckBackground:Hide()

  row.highlight = row.hoverFrame:CreateTexture(nil, "BACKGROUND")
  row.highlight:SetAllPoints()
  row.highlight:SetColorTexture(
    unpack((UICommon.Colors and UICommon.Colors.BLUE_ROW_HIGHLIGHT) or { 0.3, 0.65, 1, 0.08 })
  )
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
        row.getL,
        row.getDeathSummaryForPlayer
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
  -- Lift the secure button above the row's hoverFrame: both are siblings of
  -- mainFrame with default level; at equal strata + level, hit-test tie-break
  -- is unstable on 12.0+, and the hoverFrame's RightButton-only OnMouseUp
  -- silently swallows LeftButton clicks if it ever wins.
  row.roleButton:SetFrameLevel((mainFrame:GetFrameLevel() or 1) + 10)
  row.roleButton:RegisterForClicks("AnyUp", "AnyDown")
  row.roleButton.icon = row.roleButton:CreateTexture(nil, "ARTWORK")
  row.roleButton.icon:SetAllPoints()
  row.roleButton.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
  row.roleButton:SetScript("OnEnter", function(self)
    local tooltip = AnchorRosterHoverTooltip(rosterTooltip, self)
    if type(tooltip) == "table" and type(tooltip.SetText) == "function" then
      local L = type(getL) == "function" and getL() or {}
      local title = type(L.TOOLTIP_ROLE_MARKER_TITLE) == "string" and L.TOOLTIP_ROLE_MARKER_TITLE or "Role Marker"
      local hint = type(L.TOOLTIP_ROLE_MARKER_HINT) == "string" and L.TOOLTIP_ROLE_MARKER_HINT or "Click to mark unit"
      local tank = type(L.TOOLTIP_ROLE_MARKER_TANK) == "string" and L.TOOLTIP_ROLE_MARKER_TANK or "Tank: Blue Square"
      local healer = type(L.TOOLTIP_ROLE_MARKER_HEALER) == "string" and L.TOOLTIP_ROLE_MARKER_HEALER
        or "Healer: Green Triangle"
      tooltip:SetText(title, 1, 1, 1)
      if type(tooltip.AddLine) == "function" then
        tooltip:AddLine(hint, 1, 1, 1, true)
        tooltip:AddLine(tank, 0.2, 0.4, 1, true)
        tooltip:AddLine(healer, 0.2, 1, 0.2, true)
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

  if type(UICommon.ApplyLocaleFont) == "function" then
    UICommon.ApplyLocaleFont(row.spec)
    UICommon.ApplyLocaleFont(row.name)
    UICommon.ApplyLocaleFont(row.ilvl)
    UICommon.ApplyLocaleFont(row.key)
    UICommon.ApplyLocaleFont(row.rio)
    UICommon.ApplyLocaleFont(row.dps)
    UICommon.ApplyLocaleFont(row.kick)
    UICommon.ApplyLocaleFont(row.realm)
  end

  return row
end

local function IsEntryAtTargetDungeon(targetMapID, entry, info)
  local isAtDungeon = false

  if targetMapID and entry and entry.unit and addonTable.Validators.IsExistingUnit(entry.unit) then
    local mapApi = rawget(_G, "C_Map")
    local getBestMapForUnit = mapApi and mapApi.GetBestMapForUnit or nil
    if type(getBestMapForUnit) == "function" then
      local ok, playerMapID = pcall(getBestMapForUnit, entry.unit)
      if ok and not IsSecretValue(playerMapID) and tonumber(playerMapID) == tonumber(targetMapID) then
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

local function BuildRowDisplayData(state, entry, isReadyCheckActive, targetMapID, includeReadyCheckDecorations)
  local info = entry and entry.info or {}
  local shouldIncludeReadyCheckDecorations = includeReadyCheckDecorations == true

  local displayData = state.buildDisplayData(info, {
    unit = entry and entry.unit or nil,
    truncateName = state.truncateName,
    getShortSpecLabel = state.getShortSpecLabel,
    getLanguageFlagMarkup = state.getLanguageFlagMarkup,
    getDungeonShortCode = state.getDungeonShortCode,
    getRioDelta = state.getRioDelta,
    syncMarker = state.syncMarker,
    syncBadge = state.syncBadge,
    syncSummary = state.getPlayerSyncSummary and state.getPlayerSyncSummary(info.name, info.realm) or nil,
    deathSummary = state.getDeathSummaryForPlayer and state.getDeathSummaryForPlayer(info.name, info.realm) or nil,
    isReadyCheckActive = shouldIncludeReadyCheckDecorations and isReadyCheckActive or nil,
    getReadyCheckReadyUntil = shouldIncludeReadyCheckDecorations and state.getReadyCheckReadyUntil or nil,
    getReadyCheckDeclinedUntil = shouldIncludeReadyCheckDecorations and state.getReadyCheckDeclinedUntil or nil,
    getTime = shouldIncludeReadyCheckDecorations and state.getTime or nil,
    isAtDungeon = IsEntryAtTargetDungeon(targetMapID, entry, info),
  })

  local lfgFlags = addonTable.LFGFlags
  if type(lfgFlags) == "table" and type(lfgFlags.BuildRosterBonusMarkerBadge) == "function" then
    local bonusMarker = lfgFlags.BuildRosterBonusMarkerBadge(
      info.classToken or info.classFilename or info.classFileName or info.class,
      info.specID or info.specId or info.specializationID or info.specializationId
    )
    if type(bonusMarker) == "string" and bonusMarker ~= "" then
      displayData.rosterBonusMarker = bonusMarker
    end
  end

  return displayData
end

local function ApplyRowNameDisplay(row, displayData)
  if not row or not row.name or type(row.name.SetText) ~= "function" then
    return
  end
  local rosterBonusMarker = displayData.rosterBonusMarker
  if type(rosterBonusMarker) == "string" and rosterBonusMarker ~= "" then
    rosterBonusMarker = " " .. rosterBonusMarker
  else
    rosterBonusMarker = ""
  end

  SetReadableText(
    row.name,
    (displayData.readyCheckMarkup or "")
      .. " |c"
      .. displayData.colorHex
      .. displayData.displayName
      .. "|r"
      .. rosterBonusMarker
      .. displayData.atDungeonMarker
      .. displayData.addonMarker
  )
end

local function ApplyRowSpecDisplay(row, displayData)
  if not row or not row.spec or type(row.spec.SetText) ~= "function" then
    return
  end

  SetReadableText(row.spec, "|c" .. displayData.colorHex .. displayData.specText .. "|r")
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

local function HasReadyCheckHoldInRoster(state, roster)
  local buildOrderedRoster = type(state.buildOrderedRoster) == "function" and state.buildOrderedRoster or nil
  local getReadyCheckReadyUntil = type(state.getReadyCheckReadyUntil) == "function" and state.getReadyCheckReadyUntil
    or nil
  local getReadyCheckDeclinedUntil = type(state.getReadyCheckDeclinedUntil) == "function"
      and state.getReadyCheckDeclinedUntil
    or nil
  local getTime = type(state.getTime) == "function" and state.getTime or nil
  local now = type(getTime) == "function" and tonumber(getTime()) or nil
  if not now or not buildOrderedRoster then
    return false
  end

  for _, entry in ipairs(buildOrderedRoster(roster, state.rolePriority, state.unitPriority)) do
    local unit = entry and entry.unit or nil
    if type(unit) == "string" and unit ~= "" then
      local readyUntil = getReadyCheckReadyUntil and tonumber(getReadyCheckReadyUntil(unit)) or nil
      if readyUntil and readyUntil > now then
        return true
      end
      local declinedUntil = getReadyCheckDeclinedUntil and tonumber(getReadyCheckDeclinedUntil(unit)) or nil
      if declinedUntil and declinedUntil > now then
        return true
      end
    end
  end

  return false
end

local function SetKickCellText(cell, info, getL)
  if not cell then
    return
  end
  if type(info) ~= "table" or info.syncHasKick == false then
    SetReadableText(cell, "|cff666666-|r")
    return
  end
  if info.syncKickOnCooldown == true then
    local secs = math.ceil(info.syncKickRemain or 0)
    if secs > 0 then
      SetReadableText(cell, string.format("|cffff4040%ds|r", secs))
    else
      SetReadableText(cell, "|cff666666-|r")
    end
    return
  end
  if info.syncKickOnCooldown == false then
    local L = type(getL) == "function" and getL() or {}
    local readyText = type(L.SYNC_KICK_READY_SHORT) == "string" and L.SYNC_KICK_READY_SHORT or "OK"
    SetReadableText(cell, "|cff44ff44" .. readyText .. "|r")
    return
  end
  SetReadableText(cell, "|cff666666-|r")
end

local function ResolveReadyCheckActive(state)
  if type(state) ~= "table" then
    return false
  end

  local value = state.isReadyCheckActive
  if type(value) == "function" then
    local ok, result = pcall(value)
    return ok and result == true
  end

  return value == true
end

local RefreshReadyCheckStateImpl

local function RenderRosterImpl(state, roster)
  local memberCount = roster and #roster or 0
  if RI._rosterPanelLogger then
    Trace(string.format("rendering roster, member_count=%d", memberCount))
  end
  local memberRows = state.memberRows
  local mainFrame = state.mainFrame
  local shareKeysButton = state.shareKeysButton
  local rosterTooltip = state.rosterTooltip
  local setMainFrameHeightSafe = state.setMainFrameHeightSafe
  local minFrameHeight = state.minFrameHeight
  local raidNoticeLabel = state.raidNoticeLabel
  local buildOrderedRoster = state.buildOrderedRoster
  local rolePriority = state.rolePriority
  local unitPriority = state.unitPriority
  local resolveActiveKeyOwnerUnit = state.resolveActiveKeyOwnerUnit
  local isReadyCheckActive = ResolveReadyCheckActive(state)
  local resolveTargetMapID = state.resolveTargetMapID
  local getOwnedKeystoneSnapshot = type(state.getOwnedKeystoneSnapshot) == "function" and state.getOwnedKeystoneSnapshot
    or nil
  local getLanguageTooltipMarkup = state.getLanguageTooltipMarkup
  local getDungeonShortCode = state.getDungeonShortCode
  local getDungeonName = state.getDungeonName
  local getPlayerLastRunDps = state.getPlayerLastRunDps
  local getL = state.getL
  local isRaidGroup = state.isRaidGroup
  local applyKnownKeyToRosterEntry = state.applyKnownKeyToRosterEntry

  if state.uiRef then
    state.uiRef.memberRows = memberRows
  end
  local layoutMode = state.uiRef and state.uiRef.layoutMode or LAYOUT_MODE_EXPANDED
  local isCollapsed = IsCompactLayoutMode(layoutMode)

  local function ClearMemberRow(row)
    SetReadableText(row.spec, "")
    SetReadableText(row.name, "")
    SetReadableText(row.realm, "")
    SetReadableText(row.key, "")
    SetReadableText(row.ilvl, "")
    SetReadableText(row.rio, "")
    SetReadableText(row.dps, "")
    if row.kick then
      SetReadableText(row.kick, "")
    end
    row.unit = nil
    row.tooltipName = nil
    row.tooltipRealm = nil
    row.tooltipInfo = nil
    row.getDungeonShortCode = nil
    row.getDungeonName = nil
    row.getPlayerLastRunDps = nil
    row.getDeathSummaryForPlayer = nil
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
    -- Hide() is not protected, so a cleared row drops its marker even during
    -- combat lockdown. Leaving it shown would keep offering a click that still
    -- targets the member who just left the group.
    if row.roleButton then
      row.roleButton:Hide()
    end
  end

  -- If in a raid group, clear rows and skip roster render (H mode shows the tool buttons)
  if isRaidGroup and isRaidGroup() then
    for i = 1, #memberRows do
      local row = memberRows[i]
      if row then
        ClearMemberRow(row)
      end
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
    local isVertical = NormalizeLayoutMode(state.uiRef.layoutMode) == LAYOUT_MODE_COMPACT_VERTICAL
    local showMarkers = not isMainHorizontal
    for _, btn in ipairs(state.uiRef.tankButtons) do
      if showMarkers then
        btn:Show()
      else
        btn:Hide()
      end
    end
    if state.uiRef.tankHeader then
      if showMarkers and not isVertical then
        state.uiRef.tankHeader:Show()
      else
        state.uiRef.tankHeader:Hide()
      end
    end
  end

  -- Track which row slots get refilled by the re-render below; the legacy
  -- "clear everything first" pass caused the readyCheck background (a child
  -- of row.hoverFrame) to lose its ApplyRowReadyCheckDisplay-set visibility
  -- when the parent hoverFrame was hidden mid-render. Now we only clear
  -- the slots that orderedRoster does NOT touch (group shrink case).
  --
  -- memberRows is keyed sequentially (1..N) and only ever extended; the
  -- render loop always fills slots in order from index 1 upward. So instead
  -- of a touchedRowSlots set + pairs() cleanup pass, we can clear slots
  -- [index, #memberRows] once the render loop finishes.
  local index = 1
  local orderedRoster = buildOrderedRoster(roster, rolePriority, unitPriority)
  local activeKeyOwnerUnit = resolveActiveKeyOwnerUnit and resolveActiveKeyOwnerUnit() or nil
  local targetMapID = resolveTargetMapID and resolveTargetMapID() or nil
  local hasAnyKey = false
  local createdMemberRow = false

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
      row = CreateMemberRow(mainFrame, index, rosterTooltip, state.getL)
      memberRows[index] = row
      createdMemberRow = true
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

      -- Target by character name, never by unit token (12.0.5 secret-token
      -- regression). See CLAUDE.md "Role-marker click feature: target by
      -- character name".
      local target = addonTable.StringUtils.BuildSlashTargetName(info.name, info.realm)
      local marker = target and ROLE_MARKER[role]
      local macroText1 = marker and ("/target " .. target .. "\n/tm " .. marker .. "\n/targetlasttarget") or nil
      local macroText2 = marker and ("/target " .. target .. "\n/tm " .. CLEAR_MARKER .. "\n/targetlasttarget") or nil

      if not IsCombatLockdownActive() then
        if showButton and not isCollapsed then
          row.roleButton:Show()
          row.roleButton:SetAttribute("type1", "macro")
          row.roleButton:SetAttribute("type2", "macro")
          row.roleButton:SetAttribute("macrotext1", macroText1)
          row.roleButton:SetAttribute("macrotext2", macroText2)
        else
          row.roleButton:Hide()
        end
      elseif row.roleButton:GetAttribute("macrotext1") ~= macroText1 then
        -- Combat lockdown: SetAttribute is forbidden, so the button still holds
        -- the macro from the previous render. When the row has since changed
        -- occupant (death re-sorts rows, role swap, member leaves), that macro
        -- names somebody else and a click would target and mark the wrong
        -- player -- the v0.9.203 / v0.9.208 failure class.
        --
        -- Hide() is not protected, so it works in combat. Hiding the button is
        -- strictly better than offering a wrong one; the next out-of-combat
        -- render (PLAYER_REGEN_ENABLED runs ctx.updateUI) restores it with a
        -- correct macro.
        row.roleButton:Hide()
      end
    end

    local displayData = BuildRowDisplayData(state, entry, isReadyCheckActive, targetMapID, true)

    ApplyRowSpecDisplay(row, displayData)
    -- Skip displayData.roleIconMarkup since we render it as a secure button
    ApplyRowNameDisplay(row, displayData)
    ApplyRowReadyCheckDisplay(row, displayData)
    SetReadableText(row.realm, displayData.languageDisplay)
    if displayData.keyText ~= "-" and activeKeyOwnerUnit and entry.unit == activeKeyOwnerUnit then
      SetReadableText(row.key, "|cffff4040" .. displayData.keyText .. "|r")
    else
      SetReadableText(row.key, displayData.keyText)
    end
    SetReadableText(row.ilvl, displayData.ilvlText)
    SetReadableText(row.rio, displayData.rioText)
    local showDps = FORCE_SHOW_DPS_COLUMN
    if showDps then
      local dpsText = "-"
      if type(getPlayerLastRunDps) == "function" then
        dpsText = FormatCompactTooltipNumber(getPlayerLastRunDps(info.name, info.realm)) or "-"
      end
      if dpsText == "-" and info.syncDps and info.syncDps > 0 then
        dpsText = FormatCompactTooltipNumber(info.syncDps) or "-"
      end
      SetReadableText(row.dps, dpsText)
      row.dps:Show()
    else
      SetReadableText(row.dps, "")
      row.dps:Hide()
    end
    if row.kick then
      -- Refresh kick sync state from cache before rendering.
      if type(applyKnownKeyToRosterEntry) == "function" then
        applyKnownKeyToRosterEntry(info)
      end
      SetKickCellText(row.kick, info, state.getL)
    end
    row.unit = entry.unit
    row.tooltipName = info and info.name or nil
    row.tooltipRealm = info and info.realm or nil
    row.tooltipInfo = info
    row.getDungeonShortCode = getDungeonShortCode
    row.getDungeonName = getDungeonName
    row.getPlayerLastRunDps = getPlayerLastRunDps
    row.getDeathSummaryForPlayer = state.getDeathSummaryForPlayer
    row.getLanguageTooltipMarkup = getLanguageTooltipMarkup
    row.getL = getL
    if row.hoverFrame then
      row.hoverFrame.unit = entry.unit
      row.hoverFrame:Show()
      if isCollapsed then
        row.hoverFrame:Hide()
      end
    end
    index = index + 1
  end

  -- Clear only the slots that did NOT get refilled (group shrink, etc.).
  -- Slots that were re-rendered above already have correct visibility from
  -- ApplyRowReadyCheckDisplay; clearing them would re-trigger the parent-Hide
  -- that caused the readyCheck-hold background to flicker out after FINISHED.
  local lastSlot = #memberRows
  for slot = index, lastSlot do
    local staleRow = memberRows[slot]
    if staleRow then
      ClearMemberRow(staleRow)
    end
  end

  if not hasAnyKey and getOwnedKeystoneSnapshot then
    local ownKeyMapID, ownKeyLevel = getOwnedKeystoneSnapshot()
    hasAnyKey = tonumber(ownKeyMapID)
        and tonumber(ownKeyMapID) > 0
        and tonumber(ownKeyLevel)
        and tonumber(ownKeyLevel) > 0
      or false
  end

  if type(shareKeysButton.SetShareKeysAvailable) == "function" then
    shareKeysButton.SetShareKeysAvailable(hasAnyKey)
  else
    shareKeysButton:SetEnabled(hasAnyKey)
    shareKeysButton:SetAlpha(hasAnyKey and 1 or 0.45)
  end

  local cdTrackerExtra = IsMainHorizontalLayoutMode(layoutMode) and CD_TRACKER_ROW_HEIGHT or 0
  local desiredHeight = isCollapsed and GetFrameHeightForLayoutMode(layoutMode, minFrameHeight)
    or math.max(minFrameHeight, 45 + index * 16) + cdTrackerExtra

  if state.uiRef and (createdMemberRow or state.uiRef._isiLiveRenderedLayoutMode ~= layoutMode) then
    UpdateCollapseState(state.uiRef, layoutMode, mainFrame)
    state.uiRef._isiLiveRenderedLayoutMode = layoutMode
  end

  -- Creating roster rows can require a layout refresh, which also writes the
  -- mode's generic frame height. Keep the roster-derived height authoritative
  -- so the first five-player render matches every later render.
  setMainFrameHeightSafe(desiredHeight)
end

RefreshReadyCheckStateImpl = function(state, roster)
  local buildOrderedRoster = type(state.buildOrderedRoster) == "function" and state.buildOrderedRoster or nil
  if not buildOrderedRoster then
    return
  end
  local memberRows = state.memberRows or {}
  local orderedRoster = buildOrderedRoster(roster, state.rolePriority, state.unitPriority)
  local isReadyCheckActive = ResolveReadyCheckActive(state)
  local targetMapID = state.resolveTargetMapID and state.resolveTargetMapID() or nil

  local index = 1
  for _, entry in ipairs(orderedRoster) do
    if index > 5 then
      break
    end

    local row = memberRows[index]
    if row then
      local displayData = BuildRowDisplayData(state, entry, isReadyCheckActive, targetMapID, true)
      ApplyRowReadyCheckDisplay(row, displayData)
      ApplyRowSpecDisplay(row, displayData)
      ApplyRowNameDisplay(row, displayData)
    end

    index = index + 1
  end
end

RI.CreateMemberRow = CreateMemberRow
RI.IsEntryAtTargetDungeon = IsEntryAtTargetDungeon
RI.BuildRowDisplayData = BuildRowDisplayData
RI.ApplyRowNameDisplay = ApplyRowNameDisplay
RI.ApplyRowSpecDisplay = ApplyRowSpecDisplay
RI.ApplyRowReadyCheckDisplay = ApplyRowReadyCheckDisplay
RI.HasReadyCheckHoldInRoster = HasReadyCheckHoldInRoster
RI.SetKickCellText = SetKickCellText
RI.ResolveReadyCheckActive = ResolveReadyCheckActive
RI.RenderRosterImpl = RenderRosterImpl
RI.RefreshReadyCheckStateImpl = function(state, roster)
  return RefreshReadyCheckStateImpl(state, roster)
end
