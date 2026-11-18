local _, addonTable = ...
addonTable = addonTable or {}

-- Same Lua 5.1 / 5.4 bridge as isiLive_roster_panel_kill_row.lua.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI
local UICommon = addonTable.UICommon or {}

---@type fun(fontString: table?, size: number)
local function ApplyFontStringSize(fontString, size)
  local apply = RI.ApplyFontStringSize
  if type(apply) == "function" then
    apply(fontString, size)
  end
end
local FormatMplusTime = RI.FormatMplusTime
  or function(seconds)
    local abs = math.abs(seconds)
    return string.format("%d:%02d", math.floor(abs / 60), math.floor(abs % 60))
  end

-- Text helpers are shared by isiLive_roster_panel_kill_row.lua, which loads
-- after this file; they are read at call time.
local function LocalizedText(key, fallback)
  local localized = RI.KillRowLocalizedText
  if type(localized) == "function" then
    return localized(key, fallback)
  end
  return fallback
end

local function SetReadableText(fontString, text)
  local setText = RI.KillRowSetReadableText
  if type(setText) == "function" then
    return setText(fontString, text)
  end
  if type(fontString) == "table" and type(fontString.SetText) == "function" then
    fontString:SetText(tostring(text or ""))
  end
end

-- Time pace badge: a coloured pill at the right end of the forces bar that
-- says in one word whether the key makes it, plus the margin without a sign.
local TIME_PACE_FONT_SIZE = 12
local TIME_PACE_RIGHT_INSET = 2
local TIME_PACE_BADGE_HEIGHT = 16
local TIME_PACE_BADGE_PAD = 4

local TIME_PACE_FORMATS = {
  ontime = { key = "TIME_PACE_ONTIME_FMT", fallback = "ON TIME %s" },
  tight = { key = "TIME_PACE_TIGHT_FMT", fallback = "CLOSE %s" },
  late = { key = "TIME_PACE_LATE_FMT", fallback = "TOO SLOW %s" },
}

-- Forecast minus time limit as badge text and state. The margin is shown in
-- whole seconds without a sign; the word carries the direction. The state
-- ("ontime", "tight" or "late") comes from TimePace.ClassifyDelta, so the
-- [TIMEPACE] trace logs the same verdict the badge shows.
local function FormatTimeDelta(pace, delta, verdict)
  local seconds = math.floor(math.abs(delta) + 0.5)
  -- The module's verdict holds between checkpoints (C3); a status without
  -- one (demo data) is classified directly.
  local state = TIME_PACE_FORMATS[verdict] and verdict or pace.ClassifyDelta(delta)
  local format = TIME_PACE_FORMATS[state]
  return string.format(LocalizedText(format.key, format.fallback), FormatMplusTime(seconds)), state
end

-- Time pace of the run (see game/isiLive_time_pace.lua) as badge text, its
-- state ("ontime", "tight" or "late"), or nil
-- when nothing is shown: the forecast end time against the time limit, from
-- the reference run or the projection. Without the TimePace module the
-- setting cannot be read: fail closed.
local function BuildTimePaceText(data)
  local status = type(data) == "table" and data.timePace or nil
  if type(status) ~= "table" then
    return nil
  end
  local pace = addonTable.TimePace
  if type(pace) ~= "table" or type(pace.IsEnabled) ~= "function" or pace.IsEnabled() ~= true then
    return nil
  end
  if type(pace.ClassifyDelta) ~= "function" then
    return nil
  end
  local text, paceState
  if status.mode == "reference" then
    local delta = status.delta
    if type(delta) ~= "number" or delta ~= delta then
      return nil
    end
    text, paceState = FormatTimeDelta(pace, delta, status.verdict)
  elseif status.mode == "projection" then
    local projected, limit = status.projected, status.timeLimit
    if type(projected) ~= "number" or projected ~= projected or type(limit) ~= "number" or limit <= 0 then
      return nil
    end
    text, paceState = FormatTimeDelta(pace, projected - limit, status.verdict)
  else
    return nil
  end
  return text, paceState
end

local TIME_PACE_BADGE_COLORS = {
  ontime = { bg = "MPLUS_TIME_PACE_ONTIME_BG", text = "GREEN_HINT_TEXT" },
  tight = { bg = "MPLUS_TIME_PACE_TIGHT_BG", text = "AMBER_SUPPORT_NOTICE" },
  late = { bg = "MPLUS_TIME_PACE_LATE_BG", text = "TEXT_ALERT_DANGER" },
}

local function ShowRegion(region, shown)
  if not region then
    return
  end
  if shown then
    if type(region.Show) == "function" then
      region:Show()
    end
  elseif type(region.Hide) == "function" then
    region:Hide()
  end
end

local function SetRegionColor(region, method, color)
  if region and color and type(region[method]) == "function" then
    region[method](region, unpack(color))
  end
end

-- White text on the state colour, in and out of a fight: during a fight the
-- value moves on kills (game/isiLive_time_pace.lua), so it is never shown as
-- frozen.
local function UpdateTimePaceText(row, data)
  local fontString = row.killTrackTimePaceText
  if not fontString then
    return
  end
  local text, paceState = BuildTimePaceText(data)
  SetReadableText(fontString, text or "")
  local badge = row.killTrackTimePaceBadge
  ShowRegion(badge, text ~= nil)
  -- The click posts exactly the status the badge shows (rule 255).
  row.killTrackTimePaceStatus = text and data.timePace or nil
  if not text then
    return
  end
  local colors = UICommon.Colors or {}
  local tokens = TIME_PACE_BADGE_COLORS[paceState]
  SetRegionColor(row.killTrackTimePaceBadgeBg, "SetVertexColor", colors[tokens.bg])
  SetRegionColor(fontString, "SetTextColor", colors.WHITE_RGB or { 1, 1, 1 })
  if badge and type(badge.SetWidth) == "function" and type(fontString.GetStringWidth) == "function" then
    -- Own font string holding our own plain badge text: the width is never secret.
    local textWidth = tonumber(fontString:GetStringWidth()) or 0 -- secret-value-ok
    badge:SetWidth(math.ceil(textWidth) + 2 * TIME_PACE_BADGE_PAD)
  end
end

local function PrintLocal(message)
  local printFn = rawget(_G, "print")
  if type(printFn) == "function" and type(message) == "string" then
    pcall(printFn, message)
  end
end

-- Pace announce (rule 255): left click posts the badge's expectation to the
-- group chat (game/isiLive_time_pace_announce.lua). Without a running key
-- (demo) the line is only printed locally as a preview.
local function AnnounceTimePace(row)
  local announce = addonTable.TimePaceAnnounce
  if type(announce) ~= "table" or type(announce.Announce) ~= "function" then
    return nil
  end
  local outcome, line = announce.Announce(row.killTrackTimePaceStatus)
  if outcome == "no_key" and line then
    PrintLocal(string.format(LocalizedText("TIME_PACE_ANNOUNCE_PREVIEW_FMT", "isiLive preview: %s"), line))
  elseif outcome == "no_group" then
    PrintLocal(LocalizedText("TIME_PACE_ANNOUNCE_NO_GROUP", "isiLive: pace not posted - you are not in a group."))
  end
  return outcome
end

local function ShowTimePaceTooltip(row, badge, tooltipFrame)
  local anchor = RI.AnchorRosterHoverTooltip
  local tooltip = type(anchor) == "function" and tooltipFrame and anchor(tooltipFrame, badge) or nil
  if type(tooltip) ~= "table" or type(tooltip.SetText) ~= "function" then
    return
  end
  tooltip:SetText(LocalizedText("TIME_PACE_ANNOUNCE_TOOLTIP_TITLE", "Time pace"), 1, 1, 1) -- i18n-ok
  if type(tooltip.AddLine) == "function" then
    tooltip:AddLine(
      LocalizedText("TIME_PACE_ANNOUNCE_TOOLTIP_HINT", "Click: post the expectation to the group chat"),
      0.46,
      0.94,
      1,
      true
    )
    local announce = addonTable.TimePaceAnnounce
    local line = type(announce) == "table"
      and type(announce.BuildLine) == "function"
      and announce.BuildLine(row.killTrackTimePaceStatus)
    if type(line) == "string" then
      tooltip:AddLine(line, 0.75, 0.75, 0.75, true)
    end
  end
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
end

-- Hover: a calm blue ADD-blended wash over the pill (CLAUDE.md highlight style).
local function CreateTimePaceHover(badge)
  if type(badge.CreateTexture) ~= "function" then
    return nil
  end
  local hover = badge:CreateTexture(nil, "ARTWORK")
  if type(hover.SetAllPoints) == "function" then
    hover:SetAllPoints(badge)
  end
  if type(hover.SetTexture) == "function" then
    hover:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(hover.SetBlendMode) == "function" then
    hover:SetBlendMode("ADD")
  end
  local colors = UICommon.Colors or {}
  SetRegionColor(hover, "SetVertexColor", colors.BLUE_HOVER_GLOW or { 0.3, 0.65, 1, 0.2 })
  if type(hover.Hide) == "function" then
    hover:Hide()
  end
  return hover
end

local function AttachTimePaceClick(row, badge, tooltipFrame)
  if type(badge.EnableMouse) == "function" then
    badge:EnableMouse(true)
  end
  if type(badge.SetScript) ~= "function" then
    return
  end
  local hover = CreateTimePaceHover(badge)
  row.killTrackTimePaceHover = hover
  badge:SetScript("OnEnter", function(self)
    ShowRegion(hover, true)
    ShowTimePaceTooltip(row, self, tooltipFrame)
  end)
  badge:SetScript("OnLeave", function()
    ShowRegion(hover, false)
    local hide = RI.HideRosterHoverTooltip
    if type(hide) == "function" then
      hide(tooltipFrame)
    end
  end)
  badge:SetScript("OnMouseUp", function(_self, button)
    if button == nil or button == "LeftButton" then
      AnnounceTimePace(row)
    end
  end)
end

-- Builds the badge on the bar overlay: its own frame, so it draws above
-- fill, gap and strip; the key end banner stays above it.
local function CreateTimePaceBadge(row, barOverlay, tooltipFrame)
  local timePaceBadge = CreateFrame("Frame", nil, barOverlay)
  -- Marks the clickable pill for frame scans (tests look for roster hover frames).
  timePaceBadge._isiLiveTimePaceBadge = true
  timePaceBadge:SetPoint("RIGHT", barOverlay, "RIGHT", -TIME_PACE_RIGHT_INSET, 0)
  if type(timePaceBadge.SetHeight) == "function" then
    timePaceBadge:SetHeight(TIME_PACE_BADGE_HEIGHT)
  end
  if type(timePaceBadge.SetWidth) == "function" then
    timePaceBadge:SetWidth(1)
  end
  if type(timePaceBadge.SetFrameLevel) == "function" then
    local overlayLevel = type(barOverlay.GetFrameLevel) == "function" and tonumber(barOverlay:GetFrameLevel()) or nil
    timePaceBadge:SetFrameLevel((overlayLevel or 1) + 1)
  end
  local timePaceBadgeBg = timePaceBadge:CreateTexture(nil, "BACKGROUND")
  if type(timePaceBadgeBg.SetAllPoints) == "function" then
    timePaceBadgeBg:SetAllPoints(timePaceBadge)
  end
  if type(timePaceBadgeBg.SetTexture) == "function" then
    timePaceBadgeBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  timePaceBadge:Hide()

  local timePaceText = timePaceBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  timePaceText:SetPoint("RIGHT", timePaceBadge, "RIGHT", -TIME_PACE_BADGE_PAD, 0)
  timePaceText:SetJustifyH("RIGHT")
  -- One line: the badge grows with the text, it never wraps.
  if type(timePaceText.SetWordWrap) == "function" then
    timePaceText:SetWordWrap(false)
  end
  if type(timePaceText.SetDrawLayer) == "function" then
    timePaceText:SetDrawLayer("OVERLAY", 7)
  end
  SetReadableText(timePaceText, "")
  ApplyFontStringSize(timePaceText, TIME_PACE_FONT_SIZE)

  row.killTrackTimePaceText = timePaceText
  row.killTrackTimePaceBadge = timePaceBadge
  row.killTrackTimePaceBadgeBg = timePaceBadgeBg
  AttachTimePaceClick(row, timePaceBadge, tooltipFrame)
end

RI.CreateKillTrackTimePaceBadge = CreateTimePaceBadge
RI.UpdateKillTrackTimePace = UpdateTimePaceText
RI.AnnounceKillTrackTimePace = AnnounceTimePace
