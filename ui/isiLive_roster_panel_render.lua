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

-- Tooltip imports.
local DisableFontStringWrapping = RI.DisableFontStringWrapping or function(_fs) end
local HideRosterHoverTooltip = RI.HideRosterHoverTooltip or function(...)
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
-- Matches the 12 px language flag height in the realm column.
local ROLE_ICON_SIZE = 12
-- Centers the badge in the gap between the right-aligned spec text and the flag.
local ROLE_ICON_FLAG_GAP = (SERVER_COL_X - (SPEC_COL_X + SPEC_COL_WIDTH) - ROLE_ICON_SIZE) / 2
-- Mirrors the 4 px left inset every row starts at, so a full-width row tint
-- keeps the same gap on both sides.
local ROW_RIGHT_INSET = 4

-- Project role badges (tools/generate_role_badges.py), 32 px sources
-- downscaled so the 12 px icon stays sharp.
local ROLE_ICON_TEXTURE = {
  TANK = "Interface\\AddOns\\isiLive\\media\\role_tank",
  HEALER = "Interface\\AddOns\\isiLive\\media\\role_healer",
  DAMAGER = "Interface\\AddOns\\isiLive\\media\\role_dps",
}

-- Raid-target marker per role: 6 = Blue Square (Tank), 4 = Green Triangle (Healer).
-- Right-click on the Mark-T/H button clears via marker 0.
local ROLE_MARKER = { TANK = 6, HEALER = 4 }
local CLEAR_MARKER = 0

-- Mark-T/H macro, target by character name (see CLAUDE.md "Role-marker
-- click feature"). One block per marked player:
--   /cleartarget        -> a failed /targetexact leaves no target behind
--   /targetexact <name> -> exact match, no partial-name hit
--   /tm [exists] <n>    -> no-op when /targetexact found nobody
--   /targetlasttarget   -> restore the player's own target
-- The [exists] guard replaces the single-target /stopmacro [noexists]: a
-- missing tank must not stop the healer block. During combat lockdown the
-- button keeps the macro of the previous render, so a player who left the
-- group is simply not found instead of the current target getting marked.
-- markTargets: ordered list of { target = "<name[-realm]>", marker = n }.
-- Returns the mark macro (left click) and the clear macro (right click), or
-- nil, nil without targets.
local function BuildMarkRolesMacro(markTargets)
  if #markTargets == 0 then
    return nil, nil
  end
  local markLines, clearLines = {}, {}
  for _, entry in ipairs(markTargets) do
    for _, block in ipairs({ { markLines, entry.marker }, { clearLines, CLEAR_MARKER } }) do
      local lines = block[1]
      lines[#lines + 1] = "/cleartarget"
      lines[#lines + 1] = "/targetexact " .. entry.target
      lines[#lines + 1] = "/tm [exists] " .. tostring(block[2])
      lines[#lines + 1] = "/targetlasttarget"
    end
  end
  return table.concat(markLines, "\n"), table.concat(clearLines, "\n")
end

-- Writes the Mark-T/H secure macros. Out of combat only: SetAttribute on a
-- secure button is blocked during combat lockdown (ADDON_ACTION_BLOCKED), and
-- the out-of-combat re-render (PLAYER_REGEN_ENABLED runs ctx.updateUI)
-- rewrites a macro that went stale in combat.
local function UpdateMarkRolesButton(button, markTargets)
  if type(button) ~= "table" or type(button.SetAttribute) ~= "function" then
    return
  end
  if IsCombatLockdownActive() then
    return
  end
  local macroText1, macroText2 = BuildMarkRolesMacro(markTargets or {})
  -- Compare against what was actually written, so a macro that went stale
  -- during combat lockdown is still rewritten on the next render.
  if
    button._isiLiveMacroWritten ~= true
    or button._isiLiveMacroText1 ~= macroText1
    or button._isiLiveMacroText2 ~= macroText2
  then
    button:SetAttribute("type1", "macro")
    button:SetAttribute("type2", "macro")
    button:SetAttribute("macrotext1", macroText1)
    button:SetAttribute("macrotext2", macroText2)
    button._isiLiveMacroText1 = macroText1
    button._isiLiveMacroText2 = macroText2
    button._isiLiveMacroWritten = true
  end
end

-- These settings are temporarily hidden from Blizzard Settings.
-- Keep the runtime behavior hard-forced until the controls are re-enabled.
local FORCE_SHOW_DPS_COLUMN = true

local CLASS_ACCENT_WIDTH = 2
local READY_CHECK_HOLD_BAR_HEIGHT = 2
local READY_CHECK_HOLD_BAR_ALPHA = 0.9

local function CallIfPresent(target, methodName, ...)
  local method = type(target) == "table" and target[methodName] or nil
  if type(method) == "function" then
    return method(target, ...)
  end
  return nil
end

-- Shrinks the hold bar from full width to nothing, anchored on the left, via a
-- Scale animation: no OnUpdate runs while the countdown is visible. The bar is
-- hidden when the animation ends.
local function CreateHoldCountdownAnimation(bar)
  if type(bar) ~= "table" or type(bar.CreateAnimationGroup) ~= "function" then
    return nil
  end
  local group = bar:CreateAnimationGroup()
  local shrink = group:CreateAnimation("Scale")
  CallIfPresent(shrink, "SetOrigin", "LEFT", 0, 0)
  CallIfPresent(shrink, "SetScaleFrom", 1, 1)
  CallIfPresent(shrink, "SetScaleTo", 0, 1)
  CallIfPresent(group, "SetScript", "OnFinished", function()
    CallIfPresent(bar, "Hide")
  end)
  return { group = group, shrink = shrink }
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

  -- The status tint spans the whole row up to the frame edge, not just the
  -- hoverFrame: the hover/click area deliberately stops behind the kick column
  -- so the management buttons on the right stay clickable, but a tint ending
  -- mid-frame reads as a rendering glitch. Anchoring the right edge to
  -- mainFrame keeps it correct in every layout width.
  row.readyCheckBackground = row.hoverFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
  if type(row.readyCheckBackground.SetPoint) == "function" then
    row.readyCheckBackground:SetPoint("TOPLEFT", row.hoverFrame, "TOPLEFT", 0, 0)
    row.readyCheckBackground:SetPoint("BOTTOMLEFT", row.hoverFrame, "BOTTOMLEFT", 0, 0)
    row.readyCheckBackground:SetPoint("RIGHT", mainFrame, "RIGHT", -ROW_RIGHT_INSET, 0)
  else
    row.readyCheckBackground:SetAllPoints()
  end
  row.readyCheckBackground:Hide()

  row.highlight = row.hoverFrame:CreateTexture(nil, "BACKGROUND")
  row.highlight:SetAllPoints()
  row.highlight:SetColorTexture(
    unpack((UICommon.Colors and UICommon.Colors.BLUE_ROW_HIGHLIGHT) or { 0.3, 0.65, 1, 0.08 })
  )
  row.highlight:Hide()

  -- Class-colored accent strip on the row's left edge.
  row.classAccent = row.hoverFrame:CreateTexture(nil, "ARTWORK")
  CallIfPresent(row.classAccent, "SetPoint", "TOPLEFT", row.hoverFrame, "TOPLEFT", 0, 0)
  CallIfPresent(row.classAccent, "SetPoint", "BOTTOMLEFT", row.hoverFrame, "BOTTOMLEFT", 0, 0)
  CallIfPresent(row.classAccent, "SetWidth", CLASS_ACCENT_WIDTH)
  CallIfPresent(row.classAccent, "Hide")

  -- Countdown of the ready-check hold window along the row's bottom edge,
  -- spanning the same width as the ready-check tint.
  row.readyCheckHoldBar = row.hoverFrame:CreateTexture(nil, "ARTWORK")
  CallIfPresent(row.readyCheckHoldBar, "SetPoint", "BOTTOMLEFT", row.hoverFrame, "BOTTOMLEFT", 0, 0)
  CallIfPresent(row.readyCheckHoldBar, "SetPoint", "RIGHT", mainFrame, "RIGHT", -ROW_RIGHT_INSET, 0)
  CallIfPresent(row.readyCheckHoldBar, "SetHeight", READY_CHECK_HOLD_BAR_HEIGHT)
  CallIfPresent(row.readyCheckHoldBar, "Hide")
  row.readyCheckHoldAnimation = CreateHoldCountdownAnimation(row.readyCheckHoldBar)

  row.hoverFrame:SetScript("OnEnter", function()
    row.highlight:Show()
    if type(UICommon.PlayAlphaTransition) == "function" then
      UICommon.PlayAlphaTransition(row.highlight, "rowHover", { fromAlpha = 0, toAlpha = 1, duration = "fast" })
    end
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

  -- Display-only role icon (Tank / Healer / DPS). Marking moved to the
  -- Mark-T/H panel button, so the icon takes no mouse input and the row's
  -- hoverFrame (tooltip, right-click whisper) handles the whole row.
  row.roleIcon = CreateFrame("Frame", nil, mainFrame)
  row.roleIcon:SetSize(ROLE_ICON_SIZE, ROLE_ICON_SIZE)
  -- Above the row's hoverFrame so its row tint never covers the icon.
  row.roleIcon:SetFrameLevel((mainFrame:GetFrameLevel() or 1) + 10)
  if type(row.roleIcon.EnableMouse) == "function" then
    row.roleIcon:EnableMouse(false)
  end
  row.roleIcon.icon = row.roleIcon:CreateTexture(nil, "ARTWORK")
  row.roleIcon.icon:SetAllPoints()
  -- Smooth downscaling instead of snapping texels to the pixel grid.
  if type(row.roleIcon.icon.SetSnapToPixelGrid) == "function" then
    row.roleIcon.icon:SetSnapToPixelGrid(false)
    row.roleIcon.icon:SetTexelSnappingBias(0)
  end

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
  -- Mirror the language flag: same height, centered on its line, and
  -- horizontally centered between the spec text and the flag.
  row.roleIcon:SetPoint("RIGHT", row.realm, "LEFT", -ROLE_ICON_FLAG_GAP, 0)

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

-- The target is a challenge-mode map ID; a member stands in it only when its
-- party instance ID equals the instance ID behind that challenge map (rules
-- 193/194). The own row reads the live instance; other rows read the instance
-- ID a current isiLive client sent in the LOC "IN" suffix. The UiMapID
-- (C_Map.GetBestMapForUnit, legacy LOC field 2) is a different ID space and is
-- never compared, so members without a current isiLive client stay unmarked.
local function IsEntryAtTargetDungeon(targetMapID, entry, info)
  local validators = addonTable.Validators
  if IsSecretValue(targetMapID) or type(targetMapID) ~= "number" or targetMapID <= 0 then
    return false
  end

  if entry and entry.unit == "player" then
    return validators.IsPlayerInChallengeMapInstance(targetMapID) == true
  end

  local memberInstanceID = info and info.syncLocInstanceID
  if type(memberInstanceID) ~= "number" or memberInstanceID <= 0 then
    return false
  end
  local targetInstanceID = validators.ResolveChallengeMapInstanceID(targetMapID)
  return targetInstanceID ~= nil and memberInstanceID == targetInstanceID
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

-- Full text width, not the column-clamped one: GetUnboundedStringWidth when
-- the client has it, GetStringWidth as fallback.
local function MeasureUnboundedWidth(fontString)
  local measure = fontString.GetUnboundedStringWidth
  if type(measure) ~= "function" then
    measure = fontString.GetStringWidth
  end
  if type(measure) ~= "function" then
    return nil
  end
  local ok, width = pcall(measure, fontString)
  if not ok or IsSecretValue(width) or type(width) ~= "number" then
    return nil
  end
  return width
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

  local prefix = (displayData.readyCheckMarkup or "") .. " |c" .. displayData.colorHex
  local suffix = "|r" .. rosterBonusMarker .. displayData.atDungeonMarker .. displayData.addonMarker
  local displayName = displayData.displayName
  local fullText = prefix .. displayName .. suffix
  -- Re-renders of an unchanged row reuse the fitted text instead of measuring again.
  if row._isiLiveNameFullText == fullText and row._isiLiveNameFitText then
    SetReadableText(row.name, row._isiLiveNameFitText)
    return
  end

  SetReadableText(row.name, fullText)
  local fitText = fullText
  -- A long name plus its markers can overflow the column, and the FontString
  -- then clips the markers into "...". Shorten the name instead so the
  -- leader/sync/death markers stay visible.
  local width = MeasureUnboundedWidth(row.name)
  if not width then
    row._isiLiveNameFullText, row._isiLiveNameFitText = nil, nil
    return
  end
  if width > NAME_COL_WIDTH and type(displayName) == "string" then
    local chars = {}
    for char in displayName:gmatch("[\1-\127\194-\244][\128-\191]*") do
      chars[#chars + 1] = char
    end
    for count = #chars - 1, 1, -1 do
      fitText = prefix .. table.concat(chars, "", 1, count) .. suffix
      SetReadableText(row.name, fitText)
      width = MeasureUnboundedWidth(row.name)
      if not width or width <= NAME_COL_WIDTH then
        break
      end
    end
  end
  row._isiLiveNameFullText = fullText
  row._isiLiveNameFitText = fitText
end

local function ApplyRowSpecDisplay(row, displayData)
  if not row or not row.spec or type(row.spec.SetText) ~= "function" then
    return
  end

  SetReadableText(row.spec, "|c" .. displayData.colorHex .. displayData.specText .. "|r")
end

-- Offline members and ghost rows fade as a whole row so their values read as
-- history rather than live data. The name keeps more contrast than the data
-- columns because it is what identifies the row. The secure role button is
-- deliberately left alone (see ClearMemberRow).
local INACTIVE_ROW_DATA_ALPHA = 0.45
local INACTIVE_ROW_NAME_ALPHA = 0.75
local ROW_DATA_FIELDS = { "spec", "realm", "key", "ilvl", "rio", "dps", "kick" }

local function SetRowFieldAlpha(fontString, alpha)
  if type(fontString) == "table" and type(fontString.SetAlpha) == "function" then
    fontString:SetAlpha(alpha)
  end
end

local function ApplyRowActivityDisplay(row, displayData)
  if not row then
    return
  end
  local inactive = type(displayData) == "table" and displayData.isInactive == true
  for _, field in ipairs(ROW_DATA_FIELDS) do
    SetRowFieldAlpha(row[field], inactive and INACTIVE_ROW_DATA_ALPHA or 1)
  end
  SetRowFieldAlpha(row.name, inactive and INACTIVE_ROW_NAME_ALPHA or 1)
end

local function StopHoldCountdown(row)
  local animation = row.readyCheckHoldAnimation
  if animation then
    CallIfPresent(animation.group, "Stop")
  end
  CallIfPresent(row.readyCheckHoldBar, "Hide")
  row._readyCheckHoldUntil = nil
end

-- Countdown until the post-check tint clears. It starts full when a row first
-- shows a given hold window and shrinks to nothing exactly when the window
-- ends; later re-renders of the same window leave it running. This is a
-- countdown, not decoration, so reduced motion does not switch it off.
local function ApplyRowReadyCheckHoldBar(row, displayData)
  local bar = row and row.readyCheckHoldBar or nil
  if not bar then
    return
  end
  local holdUntil = type(displayData) == "table" and tonumber(displayData.readyCheckHoldUntil) or nil
  local remaining = type(displayData) == "table" and tonumber(displayData.readyCheckHoldRemaining) or nil
  local color = type(displayData) == "table" and displayData.readyCheckBackgroundColor or nil
  if not (holdUntil and remaining and remaining > 0 and type(color) == "table") then
    if row._readyCheckHoldUntil ~= nil then
      StopHoldCountdown(row)
    end
    return
  end
  if row._readyCheckHoldUntil == holdUntil then
    return
  end
  row._readyCheckHoldUntil = holdUntil
  CallIfPresent(bar, "SetColorTexture", color[1], color[2], color[3], READY_CHECK_HOLD_BAR_ALPHA)
  CallIfPresent(bar, "Show")
  local animation = row.readyCheckHoldAnimation
  if animation then
    CallIfPresent(animation.group, "Stop")
    CallIfPresent(animation.shrink, "SetDuration", remaining)
    CallIfPresent(animation.group, "Play")
  end
end

local function ApplyRowAccentDisplay(row, displayData)
  local accent = row and row.classAccent or nil
  if not accent then
    return
  end
  local color = type(displayData) == "table" and displayData.accentColor or nil
  if type(color) == "table" then
    CallIfPresent(accent, "SetColorTexture", color[1], color[2], color[3], 1)
    CallIfPresent(accent, "Show")
  else
    CallIfPresent(accent, "Hide")
  end
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
    -- A new status (or a tint appearing) fades in; re-renders of the same
    -- status stay still.
    local statusKey = table.concat(color, ",")
    if row._readyCheckStatusKey ~= statusKey and type(UICommon.PlayAlphaTransition) == "function" then
      UICommon.PlayAlphaTransition(background, "readyCheckTint", { fromAlpha = 0, toAlpha = 1, duration = "normal" })
    end
    row._readyCheckStatusKey = statusKey
  else
    background:Hide()
    row._readyCheckStatusKey = nil
  end
  ApplyRowReadyCheckHoldBar(row, displayData)
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
  local memberRows = state.memberRows
  local mainFrame = state.mainFrame
  local shareKeysButton = state.shareKeysButton
  local rosterTooltip = state.rosterTooltip
  local setMainFrameHeightSafe = state.setMainFrameHeightSafe
  local minFrameHeight = state.minFrameHeight
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
    ApplyRowActivityDisplay(row, nil)
    ApplyRowAccentDisplay(row, nil)
    StopHoldCountdown(row)
    row._readyCheckStatusKey = nil
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
    if row.roleIcon then
      row.roleIcon._roleVisible = false
      row.roleIcon:Hide()
    end
  end

  -- Rule 11: the main UI stays off in a raid, so a raid render only clears
  -- the rows and drops the Mark-T/H macro.
  if isRaidGroup and isRaidGroup() then
    for i = 1, #memberRows do
      local row = memberRows[i]
      if row then
        ClearMemberRow(row)
      end
    end
    UpdateMarkRolesButton(state.uiRef and state.uiRef.markRolesButton, nil)
    return
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
  -- First living tank / healer per role; the macro writes the tank block first.
  local markTargetByRole = {}

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
      createdMemberRow = true
    end

    if row.roleIcon then
      local role = info.role
      local icon = row.roleIcon.icon
      local texture = ROLE_ICON_TEXTURE[role]
      local showIcon = texture ~= nil

      if texture then
        icon:SetTexture(texture)
      end

      if info.isGhost then
        showIcon = false
      end

      -- Remembered for UpdateCollapseState, which re-shows the icon on a
      -- layout switch and must not reveal it for ghost / role-less rows.
      row.roleIcon._roleVisible = showIcon
      if showIcon and not isCollapsed then
        row.roleIcon:Show()
      else
        row.roleIcon:Hide()
      end
    end

    -- Mark-T/H: first living tank and first living healer, targeted by
    -- character name, never by unit token (12.0.5 secret-token regression).
    -- See CLAUDE.md "Role-marker click feature: target by character name".
    local marker = ROLE_MARKER[info.role]
    if marker and not info.isGhost and not markTargetByRole[info.role] then
      local target = addonTable.StringUtils.BuildSlashTargetName(info.name, info.realm)
      if target then
        markTargetByRole[info.role] = { target = target, marker = marker }
      end
    end

    local displayData = BuildRowDisplayData(state, entry, isReadyCheckActive, targetMapID, true)

    ApplyRowSpecDisplay(row, displayData)
    -- Skip displayData.roleIconMarkup since row.roleIcon renders the role
    ApplyRowNameDisplay(row, displayData)
    ApplyRowReadyCheckDisplay(row, displayData)
    ApplyRowActivityDisplay(row, displayData)
    ApplyRowAccentDisplay(row, displayData)
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

  local markTargets = {}
  markTargets[#markTargets + 1] = markTargetByRole.TANK
  markTargets[#markTargets + 1] = markTargetByRole.HEALER
  UpdateMarkRolesButton(state.uiRef and state.uiRef.markRolesButton, markTargets)

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
      ApplyRowActivityDisplay(row, displayData)
      ApplyRowAccentDisplay(row, displayData)
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
RI.ApplyRowActivityDisplay = ApplyRowActivityDisplay
RI.HasReadyCheckHoldInRoster = HasReadyCheckHoldInRoster
RI.SetKickCellText = SetKickCellText
RI.ResolveReadyCheckActive = ResolveReadyCheckActive
RI.RenderRosterImpl = RenderRosterImpl
RI.RefreshReadyCheckStateImpl = function(state, roster)
  return RefreshReadyCheckStateImpl(state, roster)
end
