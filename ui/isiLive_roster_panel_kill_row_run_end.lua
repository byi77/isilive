local _, addonTable = ...
addonTable = addonTable or {}

-- Same Lua 5.1 / 5.4 bridge as isiLive_roster_panel_kill_row.lua.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI
local UICommon = addonTable.UICommon or {}

-- Key end banner (rule 231): covers the whole row with the verified outcome and
-- loops until the logic clears it, at most RUN_END_LIMIT_SECONDS. The OnUpdate
-- drives it at a capped rate; a hidden window pauses it without any work, while
-- the limit keeps counting.
local RUN_END_FONT_SIZE = 12
local RUN_END_FADE_SECONDS = 0.35
local RUN_END_LIMIT_SECONDS = 60
local RUN_END_TICK_SECONDS = 1 / 30
local RUN_END_SWEEP_SECONDS = 1.4
local RUN_END_SWEEP_PERIOD_SECONDS = 2.4
local RUN_END_SWEEP_WIDTH = 72
local RUN_END_PULSE_SECONDS = 1.2
local RUN_END_PULSE_MIN_ALPHA = 0.55
local RUN_END_DRAIN_PERIOD_SECONDS = 3
local RUN_END_WASH_ALPHA = 0.55
local RUN_END_STYLES = {
  timed = {
    textKey = "KEY_END_TIMED",
    fallback = "Key timed",
    colorKey = "SUCCESS_GREEN_BAR",
    color = { 0.2, 0.75, 0.35 },
    motion = "sweep",
  },
  late = {
    textKey = "KEY_END_LATE",
    fallback = "Key over time",
    colorKey = "TEXT_ALERT_DANGER",
    color = { 1, 0.14, 0.16 },
    motion = "pulse",
  },
  abandoned = {
    textKey = "KEY_END_ABANDONED",
    fallback = "Key abandoned",
    colorKey = "GRAY_MUTED_PCT",
    color = { 0.4, 0.4, 0.5 },
    motion = "drain",
  },
  left = {
    textKey = "KEY_END_LEFT_GROUP",
    fallback = "Left the group",
    colorKey = "GRAY_MUTED_PCT",
    color = { 0.4, 0.4, 0.5 },
    motion = "drain",
  },
}

local function StopRunEnd(row)
  row._runEndMotion = nil
  local banner = row.killTrackRunEnd
  if banner then
    if type(banner.SetScript) == "function" then
      banner:SetScript("OnUpdate", nil)
    end
    banner:Hide()
  end
end

local function ApplyRunEndFrame(row, motion)
  local banner = row.killTrackRunEnd
  local wash = row.killTrackRunEndWash
  local sweep = row.killTrackRunEndSweep
  local width = tonumber(banner:GetWidth()) or 0
  local t = motion.elapsed
  local washFraction, washAlpha = 1, RUN_END_WASH_ALPHA

  if RI.KillRowIsReducedMotion() then
    -- Rule 125: the outcome stays readable, nothing moves or fades.
    banner:SetAlpha(1)
    sweep:Hide()
  else
    local alpha = math.min(t / RUN_END_FADE_SECONDS, 1)
    if motion.closedElapsed then
      alpha = math.min(alpha, math.max(1 - (motion.closedElapsed / RUN_END_FADE_SECONDS), 0))
    end
    banner:SetAlpha(alpha)
    local sweepTime = t % RUN_END_SWEEP_PERIOD_SECONDS
    if motion.style.motion == "sweep" and sweepTime < RUN_END_SWEEP_SECONDS and width > 0 then
      local x = (sweepTime / RUN_END_SWEEP_SECONDS) * (width + RUN_END_SWEEP_WIDTH) - RUN_END_SWEEP_WIDTH
      sweep:ClearAllPoints()
      sweep:SetPoint("TOPLEFT", banner, "TOPLEFT", x, 0)
      sweep:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", x, 0)
      sweep:Show()
    else
      sweep:Hide()
    end
    if motion.style.motion == "pulse" then
      local wave = (1 + math.cos((t / RUN_END_PULSE_SECONDS) * math.pi * 2)) / 2
      washAlpha = RUN_END_WASH_ALPHA * (RUN_END_PULSE_MIN_ALPHA + ((1 - RUN_END_PULSE_MIN_ALPHA) * wave))
    elseif motion.style.motion == "drain" then
      washFraction = 1 - ((t % RUN_END_DRAIN_PERIOD_SECONDS) / RUN_END_DRAIN_PERIOD_SECONDS)
    end
  end

  wash:SetWidth(math.max(1, width * washFraction))
  wash:SetAlpha(washAlpha)
end

local function CreateRunEndBanner(row, box, barOverlay)
  local banner = CreateFrame("Frame", nil, box)
  banner:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  banner:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
  if type(banner.SetClipsChildren) == "function" then
    banner:SetClipsChildren(true)
  end
  if type(banner.SetFrameLevel) == "function" then
    local baseLevel = type(barOverlay.GetFrameLevel) == "function" and tonumber(barOverlay:GetFrameLevel()) or nil
    banner:SetFrameLevel((baseLevel or 1) + 5)
  end

  -- Opaque backing: the row's own texts stay out of the outcome line.
  local backing = banner:CreateTexture(nil, "BACKGROUND")
  backing:SetAllPoints(banner)
  backing:SetTexture("Interface\\Buttons\\WHITE8X8")
  if type(backing.SetVertexColor) == "function" then
    backing:SetVertexColor(unpack((UICommon.Colors and UICommon.Colors.DARK_GRAY_BAR_BG) or { 0.12, 0.12, 0.12 }))
  end

  local wash = banner:CreateTexture(nil, "ARTWORK")
  if type(wash.SetPoint) == "function" then
    wash:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, 0)
    wash:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 0, 0)
  end
  if type(wash.SetWidth) == "function" then
    wash:SetWidth(1)
  end
  wash:SetTexture("Interface\\Buttons\\WHITE8X8")

  local sweep = banner:CreateTexture(nil, "ARTWORK", nil, 1)
  if type(sweep.SetWidth) == "function" then
    sweep:SetWidth(RUN_END_SWEEP_WIDTH)
  end
  sweep:SetTexture("Interface\\Buttons\\WHITE8X8")
  if type(sweep.SetBlendMode) == "function" then
    sweep:SetBlendMode("ADD")
  end
  RI.KillRowPaintGradient(sweep, { 1, 1, 1 }, 0, 0.35)
  sweep:Hide()

  local label = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  label:SetPoint("LEFT", banner, "LEFT", 0, 0)
  label:SetPoint("RIGHT", banner, "RIGHT", 0, 0)
  label:SetJustifyH("CENTER")
  label:SetText("")
  if type(label.SetTextColor) == "function" then
    label:SetTextColor(unpack((UICommon.Colors and UICommon.Colors.WHITE_RGB) or { 1, 1, 1 }))
  end
  RI.ApplyFontStringSize(label, RUN_END_FONT_SIZE)

  banner:Hide()

  row.killTrackRunEnd = banner
  row.killTrackRunEndWash = wash
  row.killTrackRunEndSweep = sweep
  row.killTrackRunEndText = label
end

local ClearKillTrackRunEnd

--- Shows the key end banner for "timed", "late", "abandoned" or "left" until
-- ClearKillTrackRunEnd or the limit. A hidden row picks it up when it opens;
-- unknown outcomes do nothing.
local function PlayKillTrackRunEnd(row, outcome)
  local style = RUN_END_STYLES[outcome]
  if not row or not row.killTrackRunEnd or not style then
    return false
  end

  local color = (UICommon.Colors and UICommon.Colors[style.colorKey]) or style.color
  row.killTrackRunEndWash:SetVertexColor(color[1], color[2], color[3])
  RI.KillRowSetReadableText(row.killTrackRunEndText, RI.KillRowLocalizedText(style.textKey, style.fallback))

  local motion = { style = style, elapsed = 0 }
  local banner = row.killTrackRunEnd
  local pending = 0
  row._runEndMotion = motion
  banner:Show()
  ApplyRunEndFrame(row, motion)
  banner:SetScript("OnUpdate", function(_, elapsed)
    pending = pending + (tonumber(elapsed) or 0)
    if pending < RUN_END_TICK_SECONDS then
      return
    end
    motion.elapsed = motion.elapsed + pending
    if motion.closedElapsed then
      motion.closedElapsed = motion.closedElapsed + pending
    end
    pending = 0
    if motion.closedElapsed and motion.closedElapsed >= RUN_END_FADE_SECONDS then
      StopRunEnd(row)
      return
    end
    ApplyRunEndFrame(row, motion)
  end)
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    timer.After(RUN_END_LIMIT_SECONDS, function()
      -- A newer banner owns its own limit.
      if row._runEndMotion == motion then
        ClearKillTrackRunEnd(row)
      end
    end)
  end
  return true
end

--- Ends the banner: a short fade on screen, at once when nobody sees it or
-- reduced motion is on.
function ClearKillTrackRunEnd(row)
  local motion = row and row._runEndMotion
  if not motion then
    return false
  end
  if row.killTrackRunEnd:IsVisible() and not RI.KillRowIsReducedMotion() then
    motion.closedElapsed = motion.closedElapsed or 0
  else
    StopRunEnd(row)
  end
  return true
end

RI.CreateRunEndBanner = CreateRunEndBanner
RI.PlayKillTrackRunEnd = PlayKillTrackRunEnd
RI.ClearKillTrackRunEnd = ClearKillTrackRunEnd
