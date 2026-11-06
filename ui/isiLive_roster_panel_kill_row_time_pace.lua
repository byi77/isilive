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
-- A forecast within this many seconds of the limit, either side, is "tight":
-- the forecast is not precise enough to call it on time or late.
local TIME_PACE_TIGHT_SECONDS = 30
-- Pause sign in front of the text while a fight freezes the value: two bars.
local TIME_PACE_PAUSE_BAR_WIDTH = 2
local TIME_PACE_PAUSE_BAR_HEIGHT = 10
local TIME_PACE_PAUSE_BAR_GAP = 2
local TIME_PACE_PAUSE_TEXT_GAP = 4
local TIME_PACE_PAUSE_ICON_WIDTH = 2 * TIME_PACE_PAUSE_BAR_WIDTH + TIME_PACE_PAUSE_BAR_GAP

local TIME_PACE_FORMATS = {
  ontime = { key = "TIME_PACE_ONTIME_FMT", fallback = "ON TIME %s" },
  tight = { key = "TIME_PACE_TIGHT_FMT", fallback = "CLOSE %s" },
  late = { key = "TIME_PACE_LATE_FMT", fallback = "TOO SLOW %s" },
}

-- Forecast minus time limit as badge text and state. The margin is shown in
-- whole seconds without a sign; the word carries the direction. Whole
-- seconds decide the state, so a forecast exactly on the limit is "tight".
local function FormatTimeDelta(delta)
  local seconds = math.floor(math.abs(delta) + 0.5)
  local state
  if seconds <= TIME_PACE_TIGHT_SECONDS then
    state = "tight"
  elseif delta < 0 then
    state = "ontime"
  else
    state = "late"
  end
  local format = TIME_PACE_FORMATS[state]
  return string.format(LocalizedText(format.key, format.fallback), FormatMplusTime(seconds)), state
end

-- Time pace of the run (see game/isiLive_time_pace.lua) as badge text, its
-- state ("ontime", "tight" or "late") and whether a fight froze it, or nil
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
  local text, paceState
  if status.mode == "reference" then
    local delta = status.delta
    if type(delta) ~= "number" or delta ~= delta then
      return nil
    end
    text, paceState = FormatTimeDelta(delta)
  elseif status.mode == "projection" then
    local projected, limit = status.projected, status.timeLimit
    if type(projected) ~= "number" or projected ~= projected or type(limit) ~= "number" or limit <= 0 then
      return nil
    end
    text, paceState = FormatTimeDelta(projected - limit)
  else
    return nil
  end
  return text, paceState, status.paused == true
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

-- Live: white text on the state colour. Paused by a fight: the pill turns
-- grey, a pause sign leads, and the word keeps its state colour, so it reads
-- as "frozen" at a glance and still says on time / tight / late.
local function UpdateTimePaceText(row, data)
  local fontString = row.killTrackTimePaceText
  if not fontString then
    return
  end
  local text, paceState, paused = BuildTimePaceText(data)
  SetReadableText(fontString, text or "")
  local badge = row.killTrackTimePaceBadge
  ShowRegion(badge, text ~= nil)
  ShowRegion(row.killTrackTimePausePrimary, text ~= nil and paused)
  ShowRegion(row.killTrackTimePauseSecondary, text ~= nil and paused)
  if not text then
    return
  end
  local colors = UICommon.Colors or {}
  local tokens = TIME_PACE_BADGE_COLORS[paceState]
  local bgColor = paused and colors.MPLUS_TIME_PACE_PAUSED_BG or colors[tokens.bg]
  local textColor = paused and colors[tokens.text] or colors.WHITE_RGB
  SetRegionColor(row.killTrackTimePaceBadgeBg, "SetVertexColor", bgColor)
  SetRegionColor(fontString, "SetTextColor", textColor or { 1, 1, 1 })
  if badge and type(badge.SetWidth) == "function" and type(fontString.GetStringWidth) == "function" then
    -- Own font string holding our own plain badge text: the width is never secret.
    local textWidth = tonumber(fontString:GetStringWidth()) or 0 -- secret-value-ok
    local iconWidth = paused and (TIME_PACE_PAUSE_ICON_WIDTH + TIME_PACE_PAUSE_TEXT_GAP) or 0
    badge:SetWidth(math.ceil(textWidth) + iconWidth + 2 * TIME_PACE_BADGE_PAD)
  end
end

-- Builds the badge on the bar overlay: its own frame, so it draws above
-- fill, gap and strip; the key end banner stays above it.
local function CreateTimePaceBadge(row, barOverlay)
  local timePaceBadge = CreateFrame("Frame", nil, barOverlay)
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
  local pauseBars = {}
  for i = 1, 2 do
    local bar = timePaceBadge:CreateTexture(nil, "ARTWORK")
    if type(bar.SetTexture) == "function" then
      bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    if type(bar.SetWidth) == "function" then
      bar:SetWidth(TIME_PACE_PAUSE_BAR_WIDTH)
    end
    if type(bar.SetHeight) == "function" then
      bar:SetHeight(TIME_PACE_PAUSE_BAR_HEIGHT)
    end
    local x = TIME_PACE_BADGE_PAD + (i - 1) * (TIME_PACE_PAUSE_BAR_WIDTH + TIME_PACE_PAUSE_BAR_GAP)
    if type(bar.SetPoint) == "function" then
      bar:SetPoint("LEFT", timePaceBadge, "LEFT", x, 0)
    end
    SetRegionColor(bar, "SetVertexColor", (UICommon.Colors and UICommon.Colors.WHITE_RGB) or { 1, 1, 1 })
    bar:Hide()
    pauseBars[i] = bar
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
  row.killTrackTimePausePrimary = pauseBars[1]
  row.killTrackTimePauseSecondary = pauseBars[2]
end

RI.CreateKillTrackTimePaceBadge = CreateTimePaceBadge
RI.UpdateKillTrackTimePace = UpdateTimePaceText
