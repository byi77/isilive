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
local M2_RUN_ROW_RIGHT_MARGIN = RI.M2_RUN_ROW_RIGHT_MARGIN or 6
local FILL_MOTION_TOKEN = "normal"
local FILL_MOTION_FALLBACK_SECONDS = 0.2

-- Number text in the addon language's decimal format. Falls back to a plain
-- dot when UICommon is not loaded (standalone harness loads).
local function FormatPercentText(value)
  local format = type(UICommon.FormatDecimal) == "function" and UICommon.FormatDecimal or nil
  local text = format and format(value, 2) or string.format("%.2f", value)
  return (text or "") .. "%"
end

local PACE_TICK_WIDTH = 2
local PACE_TICK_HEIGHT = 10
local PACE_ON_TARGET_EPSILON = 0.05

-- Learned forces target for the next boss (see game/isiLive_forces_pace.lua).
-- Shown only when the setting is on and the value is a plain percentage.
-- Without the ForcesPace module the setting cannot be read: fail closed.
local function ResolveDisplayedPaceTarget(data)
  local target = type(data) == "table" and data.paceTarget or nil
  if type(target) ~= "number" or target ~= target or target < 0 or target > 100 then
    return nil
  end
  local pace = addonTable.ForcesPace
  if type(pace) ~= "table" or type(pace.IsEnabled) ~= "function" or pace.IsEnabled() ~= true then
    return nil
  end
  return target
end

-- Signed pace delta text with one decimal in the addon language. The delta is
-- rounded before its sign is decided, so -0.04 reads as on pace ("0,0%"),
-- never as "-0,0%". Returns the text and "ahead", "onpace" or "short".
local function FormatPaceDelta(delta)
  local rounded = tonumber(string.format("%.1f", delta)) or 0
  local magnitude = math.abs(rounded)
  if magnitude < PACE_ON_TARGET_EPSILON then
    magnitude = 0
  end
  local format = type(UICommon.FormatDecimal) == "function" and UICommon.FormatDecimal or nil
  local text = (format and format(magnitude, 1) or string.format("%.1f", magnitude)) .. "%"
  if magnitude == 0 then
    return text, "onpace"
  end
  if rounded > 0 then
    return "+" .. text, "ahead"
  end
  return "-" .. text, "short"
end

local function HidePaceTick(row)
  local tick = row and row.killTrackPaceTick
  if tick and type(tick.Hide) == "function" then
    tick:Hide()
  end
end

local function ShowPaceTick(row, barWidth, target)
  local tick = row.killTrackPaceTick
  if not tick then
    return
  end
  if barWidth <= 0 then
    tick:Hide()
    return
  end
  local x = math.floor(barWidth * target / 100 + 0.5)
  x = math.max(1, math.min(x, barWidth - 1))
  -- Re-anchor only when the position or the anchor frame moved; the row
  -- refreshes on every forces change while the target stays put.
  local container = row.killTrackBarContainer
  if tick._isiLivePaceX ~= x or tick._isiLivePaceAnchor ~= container then
    if type(tick.ClearAllPoints) == "function" then
      tick:ClearAllPoints()
    end
    tick:SetPoint("CENTER", container, "LEFT", x, 0)
    tick._isiLivePaceX = x
    tick._isiLivePaceAnchor = container
  end
  tick:Show()
end

local function BuildPercentPlaceholder()
  local separator = type(UICommon.GetDecimalSeparator) == "function" and UICommon.GetDecimalSeparator() or "."
  return "--" .. separator .. "--"
end

local function IsReducedMotionEnabled()
  return type(UICommon.IsReducedMotionEnabled) == "function" and UICommon.IsReducedMotionEnabled() == true
end

local function ResolveFillMotionSeconds()
  if type(UICommon.ResolveMotionDuration) == "function" then
    return UICommon.ResolveMotionDuration(FILL_MOTION_TOKEN)
  end
  return FILL_MOTION_FALLBACK_SECONDS
end

local function StopFillMotion(row)
  row._fillMotion = nil
  local container = row.killTrackBarContainer
  if container and type(container.SetScript) == "function" then
    container:SetScript("OnUpdate", nil)
  end
end

-- Moves the progress fill to `targetWidth`. A change of an already visible
-- fill eases out over the shared `normal` motion duration; the first width,
-- reduced motion, and containers without OnUpdate apply it directly. The
-- OnUpdate script only runs while a change is in flight.
local function ApplyFillWidth(row, targetWidth)
  local fill = row.killTrackBarFill
  local container = row.killTrackBarContainer
  local current = row._fillDisplayedWidth
  local canAnimate = current ~= nil
    and current ~= targetWidth
    and not IsReducedMotionEnabled()
    and container
    and type(container.SetScript) == "function"
  if not canAnimate then
    StopFillMotion(row)
    fill:SetWidth(targetWidth)
    row._fillDisplayedWidth = targetWidth
    return
  end

  local motion = { from = current, to = targetWidth, elapsed = 0, duration = ResolveFillMotionSeconds() }
  row._fillMotion = motion
  container:SetScript("OnUpdate", function(_, elapsed)
    motion.elapsed = motion.elapsed + (tonumber(elapsed) or 0)
    local progress = motion.duration > 0 and math.min(motion.elapsed / motion.duration, 1) or 1
    local eased = 1 - ((1 - progress) * (1 - progress))
    local width = math.max(1, motion.from + ((motion.to - motion.from) * eased))
    fill:SetWidth(width)
    row._fillDisplayedWidth = width
    if progress >= 1 then
      StopFillMotion(row)
    end
  end)
end

local function HideFill(row)
  StopFillMotion(row)
  row._fillDisplayedWidth = nil
  if row.killTrackBarFill then
    row.killTrackBarFill:Hide()
  end
end

-- One short fade on the fill when forces reach 100% during a run. Only a
-- crossing counts: a first render that already shows 100% stays quiet.
local function MaybeFlashForcesComplete(row, isComplete)
  local wasComplete = row._forcesComplete
  row._forcesComplete = isComplete
  if not isComplete or wasComplete ~= false then
    return
  end
  if type(UICommon.PlayAlphaTransition) == "function" then
    UICommon.PlayAlphaTransition(row.killTrackBarFill, "forcesComplete", {
      fromAlpha = 0.35,
      toAlpha = 1,
      duration = "slow",
    })
  end
end

local function CreateKillTrackRow(mainFrame)
  local row = CreateFrame("Frame", nil, mainFrame)
  row:SetHeight(CD_TRACKER_ROW_HEIGHT)
  row:SetPoint("BOTTOMLEFT", 10, KILLTRACK_ROW_BOTTOM_OFFSET)
  row:SetPoint("BOTTOMRIGHT", -M2_RUN_ROW_RIGHT_MARGIN, KILLTRACK_ROW_BOTTOM_OFFSET)

  local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
  box:SetHeight(CD_TRACKER_ROW_HEIGHT)
  box:SetPoint("LEFT", row, "LEFT", 0, 0)
  box:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  if type(UICommon.ApplyBackdrop) == "function" then
    UICommon.ApplyBackdrop(box, "CD_BOX")
  end
  box._isiLiveSurfaceRole = "run"
  row.runSurface = box

  local label = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("LEFT", box, "LEFT", 6, 0)
  label:SetWidth(84)
  label:SetJustifyH("LEFT")
  label:SetText("M+Killtracker") -- i18n-ok: brand name, kept across all locales
  local labelColor = UICommon.Colors and UICommon.Colors.TEXT_SECTION or { 0.64, 0.80, 0.96 }
  if type(label.SetTextColor) == "function" then
    label:SetTextColor(labelColor[1], labelColor[2], labelColor[3], labelColor[4] or 1)
  end
  row.killTrackLabel = label
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
  barContainer:SetHeight(10)

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

  -- Learned forces target for the next boss: a thin cool tick above the fill.
  local paceTick = barContainer:CreateTexture(nil, "OVERLAY")
  if type(paceTick.SetTexture) == "function" then
    paceTick:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(paceTick.SetVertexColor) == "function" then
    paceTick:SetVertexColor(unpack((UICommon.Colors and UICommon.Colors.MPLUS_TIMELINE_TICK) or { 0.9, 0.95, 1, 0.6 }))
  end
  if type(paceTick.SetWidth) == "function" then
    paceTick:SetWidth(PACE_TICK_WIDTH)
  end
  if type(paceTick.SetHeight) == "function" then
    paceTick:SetHeight(PACE_TICK_HEIGHT)
  end
  if type(paceTick.SetPoint) == "function" then
    paceTick:SetPoint("CENTER", barContainer, "LEFT", 0, 0)
  end
  paceTick:Hide()

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
      unpack((UICommon.Colors and UICommon.Colors.BLACK_OVERLAY_50) or { 0, 0, 0, 0.5 })
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
  pctText:SetText(BuildPercentPlaceholder())
  ApplyFontStringSize(pctText, CD_TRACKER_FONT_SIZE + 2)

  row.killTrackBarContainer = barContainer
  row.killTrackBarBg = barBg
  row.killTrackBarFill = barFill
  row.killTrackBarPull = barPull
  row.killTrackPaceTick = paceTick
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
  if type(MplusTimer) == "table" and type(MplusTimer.GetKeyLevel) == "function" then
    local keyLevel = tonumber(MplusTimer.GetKeyLevel())
    if not keyLevel or keyLevel <= 0 then
      return nil
    end
    return math.floor(keyLevel)
  end
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
  if type(deathWatch) == "table" and type(deathWatch.GetTotalDeathCount) == "function" then
    return tonumber(deathWatch.GetTotalDeathCount()) or 0
  end
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
    -- Calm blue while forces are open; green only once 100% is reached.
    local isComplete = pct >= 100
    local colors = UICommon.Colors or {}
    local fillColor = isComplete and (colors.SUCCESS_GREEN_BAR or { 0.2, 0.75, 0.35 })
      or (colors.MPLUS_FORCES_PROGRESS_FILL or { 0.26, 0.56, 0.9 })
    local textColor = isComplete and (colors.GREEN_HINT_TEXT or { 0.45, 0.85, 0.45 })
      or (colors.LIGHT_BLUE_LEVEL_TEXT or { 0.65, 0.85, 1.0 })
    local w = type(barContainer.GetWidth) == "function" and barContainer:GetWidth() or 0
    local fillTargetWidth = 0
    if barFill then
      local fw = math.floor(w * pct / 100 + 0.5)
      if fw > 0 then
        fillTargetWidth = fw
        ApplyFillWidth(row, fw)
        barFill:SetVertexColor(fillColor[1], fillColor[2], fillColor[3])
        barFill:Show()
        MaybeFlashForcesComplete(row, isComplete)
      else
        HideFill(row)
        row._forcesComplete = false
      end
    end
    local pullPct = (data.inCombat and type(data.pullPercent) == "number") and data.pullPercent or 0
    if barPull then
      if data.inCombat and pullPct > 0 and w > 0 then
        local pw = math.floor(w * pullPct / 100 + 0.5)
        -- Clamp against the target fill width, not the width currently on
        -- screen, so an easing fill cannot let the pull overlay overshoot.
        if fillTargetWidth + pw > w then
          pw = math.max(1, w - fillTargetWidth)
        end
        barPull:SetWidth(math.max(1, pw))
        barPull:Show()
      else
        barPull:Hide()
      end
    end
    if pctText then
      pctText:SetText(FormatPercentText(pct))
      if type(pctText.SetTextColor) == "function" then
        pctText:SetTextColor(textColor[1], textColor[2], textColor[3])
      end
    end
    local paceTarget = ResolveDisplayedPaceTarget(data)
    if paceTarget then
      ShowPaceTick(row, w, paceTarget)
    else
      HidePaceTick(row)
    end
    if pullText then
      if data.inCombat and pullPct > 0 then
        pullText:SetText("+" .. FormatPercentText(pullPct))
        if type(pullText.SetTextColor) == "function" then
          pullText:SetTextColor(
            unpack((UICommon.Colors and UICommon.Colors.LIGHT_BLUE_LEVEL_TEXT) or { 0.65, 0.85, 1.0 })
          )
        end
      elseif paceTarget then
        -- The live pull keeps priority; between pulls the slot shows how far
        -- the run is ahead of (or short of) the next boss's learned target.
        local deltaText, paceState = FormatPaceDelta(pct - paceTarget)
        pullText:SetText(deltaText)
        if type(pullText.SetTextColor) == "function" then
          local paceColor = paceState == "short" and (colors.TEXT_ALERT_DANGER or { 1, 0.14, 0.16 })
            or (colors.GREEN_HINT_TEXT or { 0.45, 0.85, 0.45 })
          pullText:SetTextColor(paceColor[1], paceColor[2], paceColor[3])
        end
      else
        pullText:SetText("")
      end
    end
  elseif targetInfo then
    HidePaceTick(row)
    if barContainer and type(barContainer.Hide) == "function" then
      barContainer:Hide()
    end
    if barBg and type(barBg.Hide) == "function" then
      barBg:Hide()
    end
    if barFill then
      row._forcesComplete = nil
      HideFill(row)
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
    HidePaceTick(row)
    if barContainer and type(barContainer.Show) == "function" then
      barContainer:Show()
    end
    if barBg and type(barBg.Show) == "function" then
      barBg:Show()
    end
    if barFill then
      row._forcesComplete = nil
      HideFill(row)
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
      pctText:SetText(BuildPercentPlaceholder())
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
