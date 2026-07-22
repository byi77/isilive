local _, addonTable = ...
addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI

local ApplyFontStringSize = RI.ApplyFontStringSize
local SetReadableText = addonTable.UICommon
    and type(addonTable.UICommon.SetReadableText) == "function"
    and addonTable.UICommon.SetReadableText
  or function(fontString, text)
    if type(fontString) == "table" and type(fontString.SetText) == "function" then
      fontString:SetText(tostring(text or ""))
      return true
    end
    return false
  end
local UICommon = addonTable.UICommon or {}
local CD_TRACKER_ROW_HEIGHT = RI.CD_TRACKER_ROW_HEIGHT or 20

local KILLTRACK_ROW_BOTTOM_OFFSET = 12
local CD_TRACKER_FONT_SIZE = 12
local ACTIVE_DUNGEON_FONT_SIZE = 11
local PREKEY_LEVEL_WIDTH = 42
local ACTIVE_DUNGEON_RIGHT_OFFSET = 122
local ACTIVE_DUNGEON_LABEL_WIDTH = 146
local DEATH_MARKER_ICON = " |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:10:10:0:0|t"

local function CreateKillTrackRow(mainFrame)
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
  label:SetText("|cff888888M+Killtracker|r") -- i18n-ok: brand name, kept across all locales
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
    barBg:SetVertexColor(unpack((UICommon.Colors and UICommon.Colors.DARK_GRAY_BAR_BG) or { 0.12, 0.12, 0.12 }))
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
    barFill:SetVertexColor(unpack((UICommon.Colors and UICommon.Colors.SUCCESS_GREEN_BAR) or { 0.2, 0.75, 0.35 }))
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
    barPull:SetVertexColor(unpack((UICommon.Colors and UICommon.Colors.BLUE_PULL_BAR) or { 0.4, 0.7, 1.0, 0.7 }))
  end
  barPull:Hide()

  local targetText = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  targetText:SetPoint("LEFT", box, "LEFT", 94, 0)
  targetText:SetPoint("RIGHT", box, "RIGHT", -(PREKEY_LEVEL_WIDTH + 10), 0)
  targetText:SetJustifyH("RIGHT")
  SetReadableText(targetText, "")
  ApplyFontStringSize(targetText, CD_TRACKER_FONT_SIZE)

  local targetLevelText = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  targetLevelText:SetPoint("RIGHT", box, "RIGHT", -6, 0)
  targetLevelText:SetWidth(PREKEY_LEVEL_WIDTH)
  targetLevelText:SetJustifyH("RIGHT")
  targetLevelText:SetText("")
  ApplyFontStringSize(targetLevelText, CD_TRACKER_FONT_SIZE)

  local activeDungeonOverlay = CreateFrame("Frame", nil, box)
  activeDungeonOverlay:SetPoint("LEFT", box, "LEFT", 98, 0)
  activeDungeonOverlay:SetPoint("RIGHT", box, "RIGHT", -ACTIVE_DUNGEON_RIGHT_OFFSET, 0)
  activeDungeonOverlay:SetHeight(CD_TRACKER_ROW_HEIGHT)
  if type(activeDungeonOverlay.SetFrameLevel) == "function" then
    local baseLevel = type(barContainer.GetFrameLevel) == "function" and tonumber(barContainer:GetFrameLevel()) or nil
    activeDungeonOverlay:SetFrameLevel((baseLevel or 1) + 5)
  end

  local activeDungeonBackdrop = activeDungeonOverlay:CreateTexture(nil, "ARTWORK")
  if type(activeDungeonBackdrop.SetPoint) == "function" then
    activeDungeonBackdrop:SetPoint("LEFT", activeDungeonOverlay, "LEFT", -3, 0)
  end
  if type(activeDungeonBackdrop.SetWidth) == "function" then
    activeDungeonBackdrop:SetWidth(ACTIVE_DUNGEON_LABEL_WIDTH)
  end
  if type(activeDungeonBackdrop.SetHeight) == "function" then
    activeDungeonBackdrop:SetHeight(CD_TRACKER_ROW_HEIGHT - 4)
  end
  if type(activeDungeonBackdrop.SetTexture) == "function" then
    activeDungeonBackdrop:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(activeDungeonBackdrop.SetVertexColor) == "function" then
    activeDungeonBackdrop:SetVertexColor(
      unpack((UICommon.Colors and UICommon.Colors.NEAR_BLACK_BACKDROP) or { 0.02, 0.02, 0.02, 0.5 })
    )
  end
  if type(activeDungeonBackdrop.Hide) == "function" then
    activeDungeonBackdrop:Hide()
  end

  local activeDungeonText = activeDungeonOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  activeDungeonText:SetPoint("LEFT", activeDungeonOverlay, "LEFT", 2, 0)
  activeDungeonText:SetPoint("RIGHT", activeDungeonOverlay, "RIGHT", 0, 0)
  activeDungeonText:SetJustifyH("LEFT")
  if type(activeDungeonText.SetJustifyV) == "function" then
    activeDungeonText:SetJustifyV("MIDDLE")
  end
  if type(activeDungeonText.SetDrawLayer) == "function" then
    activeDungeonText:SetDrawLayer("OVERLAY", 7)
  end
  if type(activeDungeonText.SetAlpha) == "function" then
    activeDungeonText:SetAlpha(0.92)
  end
  SetReadableText(activeDungeonText, "")
  ApplyFontStringSize(activeDungeonText, ACTIVE_DUNGEON_FONT_SIZE)

  local pctText = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pctText:SetPoint("RIGHT", box, "RIGHT", -6, 0)
  pctText:SetWidth(58)
  pctText:SetJustifyH("RIGHT")
  pctText:SetText("--,--")
  ApplyFontStringSize(pctText, CD_TRACKER_FONT_SIZE)

  row.killTrackBarContainer = barContainer
  row.killTrackBarBg = barBg
  row.killTrackBarFill = barFill
  row.killTrackBarPull = barPull
  row.killTrackTargetText = targetText
  row.killTrackTargetLevelText = targetLevelText
  row.killTrackActiveDungeonOverlay = activeDungeonOverlay
  row.killTrackActiveDungeonBackdrop = activeDungeonBackdrop
  row.killTrackActiveDungeonText = activeDungeonText
  row.killTrackPctText = pctText
  row.killTrackPullText = pullText
  return row
end

local function ResolveTargetDungeonNameFromInfo(info)
  if type(info) ~= "table" or type(info.name) ~= "string" then
    return nil
  end
  local name = string.match(info.name, "^%s*(.-)%s*$")
  if name == "" then
    return nil
  end
  return name
end

local function ResolvePreKeyTargetInfo(deps, data)
  if data and data.active then
    return nil
  end
  if type(deps) ~= "table" or type(deps.getTargetDungeonInfo) ~= "function" then
    return nil
  end
  if type(deps.isInChallengeMode) == "function" and deps.isInChallengeMode() == true then
    return nil
  end

  local info = deps.getTargetDungeonInfo()
  local name = ResolveTargetDungeonNameFromInfo(info)
  local level = type(info) == "table" and tonumber(info.level) or nil
  if not name then
    return nil
  end
  if level and level <= 0 then
    level = nil
  end
  return {
    name = name,
    level = level and math.floor(level) or nil,
  }
end

local function ResolveActiveKeyLevel()
  local MplusTimer = addonTable.MplusTimer
  local timerData = type(MplusTimer) == "table"
      and type(MplusTimer.GetTimerData) == "function"
      and MplusTimer.GetTimerData()
    or nil
  local level = type(timerData) == "table" and tonumber(timerData.keyLevel) or nil
  if not level or level <= 0 then
    return nil
  end
  return math.floor(level)
end

local function ResolveTotalDeathCount()
  local deathWatch = addonTable.DeathWatch
  if type(deathWatch) ~= "table" or type(deathWatch.GetAllDeathSummaries) ~= "function" then
    return 0
  end
  local summaries = deathWatch.GetAllDeathSummaries()
  if type(summaries) ~= "table" then
    return 0
  end
  local total = 0
  for _, entry in ipairs(summaries) do
    if type(entry) == "table" then
      local count = tonumber(entry.count)
      if count and count > 0 then
        total = total + math.floor(count)
      end
    end
  end
  return total
end

local function AppendDeathCountToActiveDungeonName(activeDungeonName)
  if type(activeDungeonName) ~= "string" or activeDungeonName == "" then
    return activeDungeonName
  end
  local deathCount = ResolveTotalDeathCount()
  if deathCount <= 0 then
    return activeDungeonName
  end
  return activeDungeonName .. DEATH_MARKER_ICON .. "|cffff6060" .. tostring(deathCount) .. "|r"
end

local function UpdateKillTrackRow(row, deps)
  if not row then
    return
  end

  local KillTrack = addonTable.KillTrack
  local data = type(KillTrack) == "table" and type(KillTrack.GetData) == "function" and KillTrack.GetData() or nil
  local targetInfo = ResolvePreKeyTargetInfo(deps, data)

  local barContainer = row.killTrackBarContainer
  local barBg = row.killTrackBarBg
  local barFill = row.killTrackBarFill
  local barPull = row.killTrackBarPull
  local targetText = row.killTrackTargetText
  local targetLevelText = row.killTrackTargetLevelText
  local activeDungeonBackdrop = row.killTrackActiveDungeonBackdrop
  local activeDungeonText = row.killTrackActiveDungeonText
  local pctText = row.killTrackPctText
  local pullText = row.killTrackPullText

  local function SetActiveDungeonContext(text)
    if not activeDungeonText then
      return
    end
    SetReadableText(activeDungeonText, text or "")
    if text and text ~= "" then
      if activeDungeonBackdrop and type(activeDungeonBackdrop.Show) == "function" then
        activeDungeonBackdrop:Show()
      end
      if type(activeDungeonText.SetJustifyH) == "function" then
        activeDungeonText:SetJustifyH("LEFT")
      end
      if type(activeDungeonText.SetTextColor) == "function" then
        activeDungeonText:SetTextColor(unpack((UICommon.Colors and UICommon.Colors.WHITE_RGB) or { 1.0, 1.0, 1.0 }))
      end
      if type(activeDungeonText.SetAlpha) == "function" then
        activeDungeonText:SetAlpha(1.0)
      end
    elseif activeDungeonBackdrop and type(activeDungeonBackdrop.Hide) == "function" then
      activeDungeonBackdrop:Hide()
    end
  end

  if data and data.active then
    if barContainer and type(barContainer.Show) == "function" then
      barContainer:Show()
    end
    if barBg and type(barBg.Show) == "function" then
      barBg:Show()
    end
    if targetText then
      SetReadableText(targetText, "")
    end
    if targetLevelText then
      targetLevelText:SetText("")
    end
    local activeInfo = type(deps) == "table"
        and type(deps.getTargetDungeonInfo) == "function"
        and deps.getTargetDungeonInfo()
      or nil
    local activeDungeonName = ResolveTargetDungeonNameFromInfo(activeInfo)
    local activeKeyLevel = activeDungeonName and ResolveActiveKeyLevel() or nil
    if activeDungeonName and activeKeyLevel then
      activeDungeonName = activeDungeonName .. " +" .. tostring(activeKeyLevel)
    end
    activeDungeonName = AppendDeathCountToActiveDungeonName(activeDungeonName)
    SetActiveDungeonContext(activeDungeonName)
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
          pullText:SetTextColor(
            unpack((UICommon.Colors and UICommon.Colors.LIGHT_BLUE_PULL_TEXT) or { 0.6, 0.85, 1.0 })
          )
        end
      else
        pullText:SetText("")
      end
    end
  elseif targetInfo then
    if barContainer and type(barContainer.Hide) == "function" then
      barContainer:Hide()
    end
    if barBg and type(barBg.Hide) == "function" then
      barBg:Hide()
    end
    if barFill then
      barFill:Hide()
    end
    if barPull then
      barPull:Hide()
    end
    if targetText then
      SetReadableText(targetText, targetInfo.name)
      if type(targetText.SetJustifyH) == "function" then
        targetText:SetJustifyH("RIGHT")
      end
      if type(targetText.SetTextColor) == "function" then
        targetText:SetTextColor(unpack((UICommon.Colors and UICommon.Colors.GOLD_TARGET_TEXT) or { 1.0, 0.84, 0.35 }))
      end
    end
    if targetLevelText then
      targetLevelText:SetText(targetInfo.level and ("+" .. tostring(targetInfo.level)) or "")
      if type(targetLevelText.SetJustifyH) == "function" then
        targetLevelText:SetJustifyH("RIGHT")
      end
      if type(targetLevelText.SetTextColor) == "function" then
        targetLevelText:SetTextColor(
          unpack((UICommon.Colors and UICommon.Colors.LIGHT_BLUE_LEVEL_TEXT) or { 0.65, 0.85, 1.0 })
        )
      end
    end
    SetActiveDungeonContext(nil)
    if pctText then
      pctText:SetText("")
      if type(pctText.SetTextColor) == "function" then
        pctText:SetTextColor(unpack((UICommon.Colors and UICommon.Colors.MUTED_GOLD_PCT_TEXT) or { 0.9, 0.82, 0.45 }))
      end
    end
    if pullText then
      pullText:SetText("")
    end
  else
    if barContainer and type(barContainer.Show) == "function" then
      barContainer:Show()
    end
    if barBg and type(barBg.Show) == "function" then
      barBg:Show()
    end
    if barFill then
      barFill:Hide()
    end
    if barPull then
      barPull:Hide()
    end
    if targetText then
      SetReadableText(targetText, "")
    end
    if targetLevelText then
      targetLevelText:SetText("")
    end
    SetActiveDungeonContext(nil)
    if pctText then
      pctText:SetText("--,--")
      if type(pctText.SetTextColor) == "function" then
        pctText:SetTextColor(unpack((UICommon.Colors and UICommon.Colors.GRAY_MUTED_PCT) or { 0.4, 0.4, 0.5 }))
      end
    end
    if pullText then
      pullText:SetText("")
    end
  end
end

RI.CreateKillTrackRow = CreateKillTrackRow
RI.UpdateKillTrackRow = UpdateKillTrackRow
