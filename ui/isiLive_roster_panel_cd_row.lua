local _, addonTable = ...
addonTable = addonTable or {}

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI

local ApplyFontStringSize = RI.ApplyFontStringSize
local AnchorRosterHoverTooltip = RI.AnchorRosterHoverTooltip
local FormatMplusTime = RI.FormatMplusTime
local HideRosterHoverTooltip = RI.HideRosterHoverTooltip
local SetFontStringTextColorSafe = RI.SetFontStringTextColorSafe

local CD_TRACKER_ROW_HEIGHT = RI.CD_TRACKER_ROW_HEIGHT or 20
local CD_TRACKER_ROW_BOTTOM_OFFSET = RI.CD_TRACKER_ROW_BOTTOM_OFFSET or 20
local CD_TRACKER_ICON_SIZE = 16
local CD_TRACKER_TEXT_GAP = 6
local CD_TRACKER_FONT_SIZE = 12
local MPLUS_TIMER_TEXT_WIDTH = 48
local M2_RUN_ROW_RIGHT_MARGIN = RI.M2_RUN_ROW_RIGHT_MARGIN or 6

-- Timeline along the bottom edge of the M+ timer box. It lives inside the
-- existing 20 px box, so the run-zone geometry stays untouched.
local TIMELINE_HEIGHT = 2
local TIMELINE_TICK_HEIGHT = 4
-- 1 px backdrop border plus 1 px air.
local TIMELINE_INSET = 2
-- +3 and +2 cutoffs as fractions of the time limit (see MplusTimer.StartTimer).
local TIMELINE_TICK_FRACTIONS = { 0.6, 0.8 }
local INACTIVE_GRADE_ALPHA = 0.5
local GRADE_ELEMENTS = {
  [3] = { badge = "mp3Icon", text = "mp3Text" },
  [2] = { badge = "mp2Icon", text = "mp2Text" },
  [1] = { badge = "mp1Icon", text = "mp1Text" },
}
-- Fail-closed fallbacks for harness loads without UICommon.Colors.
local FALLBACK_TIMELINE_COLORS = {
  MPLUS_TIMELINE_TRACK = { 0, 0, 0, 0.45 },
  MPLUS_TIMELINE_TICK = { 0.9, 0.95, 1, 0.6 },
  MPLUS_GRADE3_FILL = { 0.3, 0.85, 0.4, 0.9 },
  MPLUS_GRADE2_FILL = { 1, 0.82, 0.2, 0.9 },
  MPLUS_GRADE1_FILL = { 0.85, 0.88, 0.95, 0.85 },
  MPLUS_OVERTIME_FILL = { 1, 0.3, 0.3, 0.9 },
}
local GRADE_FILL_COLOR_KEYS = {
  [3] = "MPLUS_GRADE3_FILL",
  [2] = "MPLUS_GRADE2_FILL",
  [1] = "MPLUS_GRADE1_FILL",
  [0] = "MPLUS_OVERTIME_FILL",
}

local function BuildDeathSummaryTooltipLines(summaries)
  local lines = {}
  if type(summaries) ~= "table" then
    return lines
  end

  for _, entry in ipairs(summaries) do
    local name = type(entry) == "table" and entry.name or nil
    local count = type(entry) == "table" and tonumber(entry.count) or nil
    if type(name) == "string" and name ~= "" and count and count > 0 then
      lines[#lines + 1] = {
        name = name,
        count = math.floor(count),
      }
    end
  end

  table.sort(lines, function(a, b)
    local nameA = tostring(a.name or "")
    local nameB = tostring(b.name or "")
    if nameA ~= nameB then
      return nameA < nameB
    end
    return (tonumber(a.count) or 0) > (tonumber(b.count) or 0)
  end)

  return lines
end

local function GetDeathWatchSummaries()
  local deathWatch = addonTable.DeathWatch
  if type(deathWatch) ~= "table" or type(deathWatch.GetAllDeathSummaries) ~= "function" then
    return {}
  end
  return deathWatch.GetAllDeathSummaries()
end

local function BuildDeathTimeLostTooltipLine(deathTimeLost, L)
  local seconds = tonumber(deathTimeLost) or 0
  if seconds <= 0 then
    return nil
  end
  local fmt = type(L) == "table" and type(L.TOOLTIP_DEATH_TIME_LOST_FMT) == "string" and L.TOOLTIP_DEATH_TIME_LOST_FMT
    or "Time lost: +%ds"
  return string.format(fmt, seconds)
end

local function CreateMplusGradeBadge(parent, leftOffset, bgR, bgG, bgB, labelText)
  local badge = CreateFrame("Frame", nil, parent)
  badge:SetSize(20, 12)
  badge:SetPoint("LEFT", parent, "LEFT", leftOffset, 0)
  local bg = badge:CreateTexture(nil, "BACKGROUND")
  if type(bg.SetAllPoints) == "function" then
    bg:SetAllPoints(badge)
  end
  if type(bg.SetTexture) == "function" then
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(bg.SetVertexColor) == "function" then
    bg:SetVertexColor(bgR, bgG, bgB)
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
    label:SetText(labelText)
  end
  ApplyFontStringSize(label, CD_TRACKER_FONT_SIZE)
  return badge
end

local function CallIfPresent(target, method, ...)
  local fn = type(target) == "table" and target[method] or nil
  if type(fn) == "function" then
    return fn(target, ...)
  end
  return nil
end

local function ResolveTimelineColor(key)
  local common = addonTable.UICommon
  local colors = type(common) == "table" and common.Colors or nil
  local color = type(colors) == "table" and colors[key] or nil
  return type(color) == "table" and color or FALLBACK_TIMELINE_COLORS[key]
end

local function PaintTimelineTexture(texture, colorKey)
  local color = ResolveTimelineColor(colorKey)
  if type(color) == "table" then
    CallIfPresent(texture, "SetColorTexture", color[1], color[2], color[3], color[4] or 1)
  end
end

local function CreateMplusTimeline(box)
  if type(box) ~= "table" or type(box.CreateTexture) ~= "function" then
    return nil
  end

  local track = box:CreateTexture(nil, "ARTWORK")
  CallIfPresent(track, "SetPoint", "BOTTOMLEFT", box, "BOTTOMLEFT", TIMELINE_INSET, TIMELINE_INSET)
  CallIfPresent(track, "SetPoint", "BOTTOMRIGHT", box, "BOTTOMRIGHT", -TIMELINE_INSET, TIMELINE_INSET)
  CallIfPresent(track, "SetHeight", TIMELINE_HEIGHT)
  CallIfPresent(track, "Hide")

  local fill = box:CreateTexture(nil, "ARTWORK", nil, 1)
  CallIfPresent(fill, "SetPoint", "BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
  CallIfPresent(fill, "SetHeight", TIMELINE_HEIGHT)
  CallIfPresent(fill, "Hide")

  local ticks = {}
  for index = 1, #TIMELINE_TICK_FRACTIONS do
    local tick = box:CreateTexture(nil, "OVERLAY")
    CallIfPresent(tick, "SetSize", 1, TIMELINE_TICK_HEIGHT)
    CallIfPresent(tick, "Hide")
    ticks[index] = tick
  end

  return { track = track, fill = fill, ticks = ticks }
end

local function ReadPlainTimerNumber(value)
  local validators = addonTable.Validators
  if
    type(validators) == "table"
    and type(validators.IsSecretValue) == "function"
    and validators.IsSecretValue(value)
  then
    return nil
  end
  return type(value) == "number" and value or nil
end

-- Share of the time limit already spent, clamped to [0, 1]; nil when the
-- snapshot carries no usable timer or limit.
local function ResolveTimelineFraction(data)
  if type(data) ~= "table" then
    return nil
  end
  local timer = ReadPlainTimerNumber(data.timer)
  local limit = ReadPlainTimerNumber(data.timeLimit)
  if not timer or not limit or limit <= 0 or timer < 0 then
    return nil
  end
  return math.min(timer / limit, 1)
end

-- Highest chest grade that is still reachable: 3, 2 or 1, and 0 once the
-- +1 cutoff has passed.
local function ResolveActiveGrade(data)
  if (tonumber(data.timeRemaining3) or -1) >= 0 then
    return 3
  elseif (tonumber(data.timeRemaining2) or -1) >= 0 then
    return 2
  elseif (tonumber(data.timeRemaining1) or -1) >= 0 then
    return 1
  end
  return 0
end

local function HideMplusTimeline(timeline)
  if not timeline then
    return
  end
  CallIfPresent(timeline.track, "Hide")
  CallIfPresent(timeline.fill, "Hide")
  for _, tick in ipairs(timeline.ticks) do
    CallIfPresent(tick, "Hide")
  end
end

local function UpdateMplusTimeline(timeline, box, data, activeGrade)
  if not timeline then
    return
  end
  local fraction = ResolveTimelineFraction(data)
  local width = fraction and tonumber(CallIfPresent(box, "GetWidth")) or nil
  local innerWidth = width and (width - (TIMELINE_INSET * 2)) or 0
  if not fraction or innerWidth <= 0 then
    HideMplusTimeline(timeline)
    return
  end

  PaintTimelineTexture(timeline.track, "MPLUS_TIMELINE_TRACK")
  CallIfPresent(timeline.track, "Show")

  local fillWidth = math.floor((innerWidth * fraction) + 0.5)
  if fillWidth > 0 then
    CallIfPresent(timeline.fill, "SetWidth", fillWidth)
    PaintTimelineTexture(timeline.fill, GRADE_FILL_COLOR_KEYS[activeGrade] or "MPLUS_GRADE1_FILL")
    CallIfPresent(timeline.fill, "Show")
  else
    CallIfPresent(timeline.fill, "Hide")
  end

  for index, tick in ipairs(timeline.ticks) do
    local x = math.floor((innerWidth * TIMELINE_TICK_FRACTIONS[index]) + 0.5)
    CallIfPresent(tick, "ClearAllPoints")
    CallIfPresent(tick, "SetPoint", "BOTTOMLEFT", timeline.track, "BOTTOMLEFT", x, 0)
    PaintTimelineTexture(tick, "MPLUS_TIMELINE_TICK")
    CallIfPresent(tick, "Show")
  end
end

-- Keeps the reachable grade at full opacity and dims the others. In overtime
-- the red +1 overshoot stays emphasized. `activeGrade == nil` (no key)
-- restores every grade. A grade change after the first render briefly fades
-- the newly active time in; reduced motion skips that through UICommon.
local function ApplyGradeEmphasis(row, activeGrade)
  local emphasized = activeGrade == 0 and 1 or activeGrade
  for grade, elements in pairs(GRADE_ELEMENTS) do
    local alpha = (emphasized == nil or grade == emphasized) and 1 or INACTIVE_GRADE_ALPHA
    CallIfPresent(row[elements.badge], "SetAlpha", alpha)
    CallIfPresent(row[elements.text], "SetAlpha", alpha)
  end

  local previous = row._activeGrade
  row._activeGrade = activeGrade
  if emphasized == nil or previous == nil or previous == activeGrade then
    return
  end
  local common = addonTable.UICommon
  if type(common) == "table" and type(common.PlayAlphaTransition) == "function" then
    common.PlayAlphaTransition(row[GRADE_ELEMENTS[emphasized].text], "mplusGrade", {
      fromAlpha = 0.35,
      toAlpha = 1,
      duration = "slow",
    })
  end
end

-- Cooldown swipe over a BR/BL icon. The countdown numbers stay hidden because
-- the row already prints the remaining time next to the icon.
local function CreateIconCooldown(parent, icon)
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" or type(icon) ~= "table" then
    return nil
  end
  local cooldown = createFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
  if type(cooldown) ~= "table" then
    return nil
  end
  CallIfPresent(cooldown, "SetAllPoints", icon)
  CallIfPresent(cooldown, "SetDrawEdge", false)
  CallIfPresent(cooldown, "SetHideCountdownNumbers", true)
  return cooldown
end

-- Keeps the swipe in step with `remain` / `duration`. The swipe is only
-- restarted when the end time moves by more than half a second, so the
-- once-per-second refresh does not make it stutter.
local ICON_COOLDOWN_RESYNC_SECONDS = 0.5

local function UpdateIconCooldown(row, stateKey, cooldown, remain, duration)
  if not cooldown then
    return
  end
  remain = ReadPlainTimerNumber(remain)
  duration = ReadPlainTimerNumber(duration)
  local getTime = rawget(_G, "GetTime")
  local now = type(getTime) == "function" and ReadPlainTimerNumber(getTime()) or nil
  if not (remain and duration and now and remain > 0 and duration >= remain) then
    if row[stateKey] ~= nil then
      CallIfPresent(cooldown, "SetCooldown", 0, 0)
      row[stateKey] = nil
    end
    return
  end
  local endTime = now + remain
  local shownEnd = row[stateKey]
  if shownEnd == nil or math.abs(shownEnd - endTime) > ICON_COOLDOWN_RESYNC_SECONDS then
    CallIfPresent(cooldown, "SetCooldown", endTime - duration, duration)
    row[stateKey] = endTime
  end
end

local function CreateCdTrackerRow(mainFrame, opts)
  opts = opts or {}
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
    row:SetPoint("BOTTOMRIGHT", -M2_RUN_ROW_RIGHT_MARGIN, CD_TRACKER_ROW_BOTTOM_OFFSET)
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
  cdBox._isiLiveSurfaceRole = "run"
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

  row.bresCooldown = CreateIconCooldown(cdBox, row.bresIcon)
  row.lustCooldown = CreateIconCooldown(cdBox, row.lustIcon)

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
  mplusBox._isiLiveSurfaceRole = "run"
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

  row.mp3Icon = CreateMplusGradeBadge(mplusBox, 34, 0.15, 0.45, 0.15, "|cff44ff44+3|r")
  row.mp3Text = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mp3Text:SetPoint("LEFT", mplusBox, "LEFT", 58, 0)
  row.mp3Text:SetWidth(MPLUS_TIMER_TEXT_WIDTH)
  row.mp3Text:SetJustifyH("LEFT")
  row.mp3Text:SetText("--:--")
  ApplyFontStringSize(row.mp3Text, CD_TRACKER_FONT_SIZE)

  row.mp2Icon = CreateMplusGradeBadge(mplusBox, 102, 0.45, 0.38, 0.05, "|cffffd91a+2|r")
  row.mp2Text = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mp2Text:SetPoint("LEFT", mplusBox, "LEFT", 126, 0)
  row.mp2Text:SetWidth(MPLUS_TIMER_TEXT_WIDTH)
  row.mp2Text:SetJustifyH("LEFT")
  row.mp2Text:SetText("--:--")
  ApplyFontStringSize(row.mp2Text, CD_TRACKER_FONT_SIZE)

  row.mp1Icon = CreateMplusGradeBadge(mplusBox, 170, 0.3, 0.3, 0.3, "|cffdddddd+1|r")
  row.mp1Text = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mp1Text:SetPoint("LEFT", mplusBox, "LEFT", 194, 0)
  row.mp1Text:SetWidth(MPLUS_TIMER_TEXT_WIDTH)
  row.mp1Text:SetJustifyH("LEFT")
  row.mp1Text:SetText("--:--")
  ApplyFontStringSize(row.mp1Text, CD_TRACKER_FONT_SIZE)

  -- death icon + label
  row.mpDeathIcon = mplusBox:CreateTexture(nil, "OVERLAY")
  if type(row.mpDeathIcon.SetSize) == "function" then
    row.mpDeathIcon:SetSize(12, 12)
  end
  if type(row.mpDeathIcon.SetPoint) == "function" then
    row.mpDeathIcon:SetPoint("LEFT", mplusBox, "LEFT", 246, 0)
  end
  -- Skull-and-bones death icon instead of the raid-target skull, which the
  -- world-marker buttons right next to this row already use.
  if type(UICommon.ApplyStateIcon) == "function" then
    UICommon.ApplyStateIcon(row.mpDeathIcon, "death")
  elseif type(row.mpDeathIcon.SetTexture) == "function" then
    row.mpDeathIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
  end

  local deathHover = CreateFrame("Frame", nil, mplusBox)
  if type(deathHover.SetPoint) == "function" then
    deathHover:SetPoint("CENTER", row.mpDeathIcon, "CENTER", 0, 0)
  end
  if type(deathHover.SetSize) == "function" then
    deathHover:SetSize(18, 18)
  end
  if type(deathHover.EnableMouse) == "function" then
    deathHover:EnableMouse(true)
  end
  if type(deathHover.SetFrameLevel) == "function" and type(mplusBox.GetFrameLevel) == "function" then
    deathHover:SetFrameLevel((mplusBox:GetFrameLevel() or 1) + 5)
  end
  deathHover:SetScript("OnEnter", function(self)
    local tooltipFrame = opts.tooltipFrame
    local tooltip = type(AnchorRosterHoverTooltip) == "function" and AnchorRosterHoverTooltip(tooltipFrame, self) or nil
    if type(tooltip) ~= "table" or type(tooltip.SetText) ~= "function" then
      return
    end
    local L = type(opts.getL) == "function" and opts.getL() or {}
    local title = type(L.TOOLTIP_DEATH_BREAKDOWN_TITLE) == "string" and L.TOOLTIP_DEATH_BREAKDOWN_TITLE or "Deaths"
    tooltip:SetText(title, 1, 1, 1)
    if type(tooltip.AddLine) == "function" then
      local lines = BuildDeathSummaryTooltipLines(GetDeathWatchSummaries())
      if #lines > 0 then
        for _, line in ipairs(lines) do
          tooltip:AddLine(string.format("%s %d", line.name, line.count), 1, 0.38, 0.38)
        end
      else
        tooltip:AddLine("--", 0.65, 0.65, 0.65)
      end
      local timeLostLine = BuildDeathTimeLostTooltipLine(row._deathTimeLost, L)
      if timeLostLine then
        tooltip:AddLine(timeLostLine, 1, 0.38, 0.38)
      end
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
  end)
  deathHover:SetScript("OnLeave", function()
    if type(HideRosterHoverTooltip) == "function" then
      HideRosterHoverTooltip(opts.tooltipFrame)
    end
  end)
  row.mpDeathHover = deathHover

  row.mpDeathText = mplusBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.mpDeathText:SetPoint("LEFT", row.mpDeathIcon, "RIGHT", 4, 0)
  row.mpDeathText:SetJustifyH("LEFT")
  row.mpDeathText:SetText("")
  ApplyFontStringSize(row.mpDeathText, CD_TRACKER_FONT_SIZE)

  row.mpTimeline = CreateMplusTimeline(mplusBox)

  return row
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
      -- No charge left: the icon greys out until the next charge is back. A
      -- masked charge count is never compared; the icon then stays in color.
      local plainCharges = ReadPlainTimerNumber(bres.charges)
      CallIfPresent(row.bresIcon, "SetDesaturated", plainCharges ~= nil and plainCharges <= 0)
      UpdateIconCooldown(row, "_bresCooldownEnd", row.bresCooldown, remain, bres.cooldownDuration)
    else
      row.bresText:SetText("BR: --")
      CallIfPresent(row.bresIcon, "SetDesaturated", false)
      UpdateIconCooldown(row, "_bresCooldownEnd", row.bresCooldown, nil, nil)
    end
  end

  -- BL: always show icon + text; show countdown when active, "--" when inactive.
  -- Use the aura's own icon when lust is active (covers Heroism, Time Warp variants),
  -- fall back to the cached Bloodlust icon when inactive.
  do
    local lust = cdController and cdController.GetLustInfo()
    local lustRemain = lust and tonumber(lust.remain) or nil
    if lustRemain ~= nil then
      if lust.icon then
        row.lustIcon:SetTexture(lust.icon)
      elseif row._lustDefaultIcon then
        row.lustIcon:SetTexture(row._lustDefaultIcon)
      end
      if row._lustIconReady or lust.icon then
        row.lustIcon:Show()
      end
      local remain = math.max(0, lustRemain)
      local mins = math.floor(remain / 60)
      local secs = math.floor(remain % 60)
      row.lustText:SetText(string.format("%02d:%02d", mins, secs))
      UpdateIconCooldown(row, "_lustCooldownEnd", row.lustCooldown, remain, lust.duration)
    else
      if row._lustDefaultIcon then
        row.lustIcon:SetTexture(row._lustDefaultIcon)
      end
      if row._lustIconReady then
        row.lustIcon:Show()
      end
      row.lustText:SetText("BL: --")
      UpdateIconCooldown(row, "_lustCooldownEnd", row.lustCooldown, nil, nil)
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
        row._deathTimeLost = tonumber(data.deathTimeLost) or 0
        row.mpDeathText:SetText(string.format("|cffff6060%d|r", data.deaths))
      else
        row._deathTimeLost = 0
        row.mpDeathText:SetText("")
      end

      local activeGrade = ResolveActiveGrade(data)
      ApplyGradeEmphasis(row, activeGrade)
      UpdateMplusTimeline(row.mpTimeline, row.mplusBox, data, activeGrade)
    else
      -- no active key: show --:-- for all
      SetFontStringTextColorSafe(row.mp3Text, 0.4, 0.4, 0.5)
      row.mp3Text:SetText("--:--")
      SetFontStringTextColorSafe(row.mp2Text, 0.4, 0.4, 0.5)
      row.mp2Text:SetText("--:--")
      SetFontStringTextColorSafe(row.mp1Text, 0.4, 0.4, 0.5)
      row.mp1Text:SetText("--:--")
      SetFontStringTextColorSafe(row.mpDeathText, 0.4, 0.4, 0.5)
      row._deathTimeLost = 0
      row.mpDeathText:SetText("--")
      ApplyGradeEmphasis(row, nil)
      HideMplusTimeline(row.mpTimeline)
    end
  end
end

RI.CreateCdTrackerRow = CreateCdTrackerRow
RI.UpdateCdTrackerRow = UpdateCdTrackerRow
RI.BuildDeathSummaryTooltipLines = BuildDeathSummaryTooltipLines
RI.BuildDeathTimeLostTooltipLine = BuildDeathTimeLostTooltipLine
