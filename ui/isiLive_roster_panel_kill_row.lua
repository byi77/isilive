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
-- Pre-key target on the bar: outlined like the time pace delta, the level
-- follows the name after a small gap.
local PREKEY_TARGET_FONT_SIZE = 11
local PREKEY_TARGET_LEFT_INSET = 2
local PREKEY_LEVEL_GAP = 4
local BAR_OVERLAY_RIGHT_OFFSET = 122
-- Pre-key target pulse: name and level fade between full and this alpha,
-- so the target never disappears.
local PREKEY_PULSE_MIN_ALPHA = 0.35
local PREKEY_PULSE_SECONDS = 0.8
-- Light sweep across the pre-key bar: a soft band of this width crosses
-- the bar once per period.
local PREKEY_SHIMMER_WIDTH = 36
local PREKEY_SHIMMER_SECONDS = 2.4
local M2_RUN_ROW_RIGHT_MARGIN = RI.M2_RUN_ROW_RIGHT_MARGIN or 6
local FormatMplusTime = RI.FormatMplusTime
  or function(seconds)
    local abs = math.abs(seconds)
    return string.format("%d:%02d", math.floor(abs / 60), math.floor(abs % 60))
  end
-- Time pace delta: right end of the forces bar, outlined like the dungeon name.
local TIME_PACE_FONT_SIZE = 11
local TIME_PACE_RIGHT_INSET = 2
-- Line under the bar in the frame's bottom padding: the target's time to kill
-- (game/isiLive_ttk.lua).
local TTK_FONT_SIZE = 10
local TTK_TEXT_WIDTH = 76
local FILL_MOTION_TOKEN = "normal"
local FILL_MOTION_FALLBACK_SECONDS = 0.2

-- Number text in the addon language's decimal format. Falls back to a plain
-- dot when UICommon is not loaded (standalone harness loads).
local function FormatPercentText(value)
  local format = type(UICommon.FormatDecimal) == "function" and UICommon.FormatDecimal or nil
  local text = format and format(value, 2) or string.format("%.2f", value)
  return (text or "") .. "%"
end

-- Forces percent for the fixed-width column: "100,00%" does not fit and got
-- truncated to "100,0...", so complete forces read "100%". An open run never
-- rounds up to 100 and stays at "99,99%" until the forces are really done.
local function FormatForcesPercentText(pct)
  if pct >= 100 then
    return "100%"
  end
  return FormatPercentText(math.min(pct, 99.99))
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

local function LocalizedText(key, fallback)
  if type(UICommon.GetLocalizedText) == "function" then
    local text = UICommon.GetLocalizedText(key, fallback)
    if type(text) == "string" and text ~= "" then
      return text
    end
  end
  return fallback
end

-- Signed whole-second delta: whole seconds decide the sign, so a run exactly
-- on target reads "0:00" and counts as on time.
local function FormatTimeDelta(delta)
  local seconds = math.floor(math.abs(delta) + 0.5)
  local sign = seconds == 0 and "" or (delta < 0 and "-" or "+")
  return sign .. FormatMplusTime(seconds), (sign == "+") and "late" or "ontime"
end

-- Time pace of the run (see game/isiLive_time_pace.lua) as a signed delta
-- plus "ontime" or "late", or nil when
-- nothing is shown: against the reference run at the same progress, otherwise
-- the forecast end time against the time limit. Without the TimePace module
-- the setting cannot be read: fail closed.
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
  if status.paused == true then
    -- Infight pause: the word in front says the frozen value is on purpose;
    -- the colour keeps the pull's on-time/late state.
    return string.format(LocalizedText("TIME_PACE_PAUSED_FMT", "Pause %s"), text), paceState
  end
  return text, paceState
end

local function UpdateTimePaceText(row, data)
  local fontString = row.killTrackTimePaceText
  if not fontString then
    return
  end
  local text, paceState = BuildTimePaceText(data)
  SetReadableText(fontString, text or "")
  if text and type(fontString.SetTextColor) == "function" then
    local colors = UICommon.Colors or {}
    local color = paceState == "late" and (colors.TEXT_ALERT_DANGER or { 1, 0.14, 0.16 })
      or (colors.GREEN_HINT_TEXT or { 0.45, 0.85, 0.45 })
    fontString:SetTextColor(color[1], color[2], color[3])
  end
end

-- Time overlay on the forces bar (rule 208): a strip along the bottom edge
-- shows the spent share of the time limit in the timer box's grade colour, and
-- the gap between forces and time is tinted green (forces lead) or red (time
-- leads). The snapshot comes from the M+ timer box's own 1 Hz read.
local TIME_STRIP_HEIGHT = 3
local TIME_OVERLAY_MIN_GAP = 1

local function HideTimeOverlay(row)
  if row.killTrackTimeStrip then
    row.killTrackTimeStrip:Hide()
  end
  if row.killTrackTimeGap then
    row.killTrackTimeGap:Hide()
  end
end

local function PaintOverlay(texture, colorKey, fallback)
  local color = (UICommon.Colors and UICommon.Colors[colorKey]) or fallback
  if texture._isiLivePaintedColor ~= color and type(texture.SetVertexColor) == "function" then
    texture._isiLivePaintedColor = color
    texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  end
end

local function RenderTimeOverlay(row)
  local snapshot = row._timeOverlaySnapshot
  local pace = addonTable.TimePace
  local enabled = type(pace) == "table" and type(pace.IsEnabled) == "function" and pace.IsEnabled() == true
  local timer = type(snapshot) == "table" and tonumber(snapshot.timer) or nil
  local limit = type(snapshot) == "table" and tonumber(snapshot.timeLimit) or nil
  local container = row.killTrackBarContainer
  local width = container and type(container.GetWidth) == "function" and tonumber(container:GetWidth()) or 0
  if
    not enabled
    or row._killTrackActive ~= true
    or type(snapshot) ~= "table"
    or snapshot.running ~= true
    or not timer
    or not limit
    or limit <= 0
    or width <= 0
  then
    HideTimeOverlay(row)
    return
  end
  local timeFraction = math.max(0, math.min(timer / limit, 1))
  local forcesFraction = math.max(0, math.min((row._killTrackPercent or 0) / 100, 1))

  local strip = row.killTrackTimeStrip
  local stripWidth = math.floor(width * timeFraction + 0.5)
  if strip and stripWidth >= 1 then
    strip:SetWidth(stripWidth)
    local keys = RI.MPLUS_GRADE_FILL_COLOR_KEYS or {}
    PaintOverlay(strip, keys[row._timeOverlayGrade] or "MPLUS_GRADE1_FILL", { 0.85, 0.88, 0.95, 0.85 })
    strip:Show()
  elseif strip then
    strip:Hide()
  end

  local gap = row.killTrackTimeGap
  if not gap then
    return
  end
  local left = math.floor(width * math.min(timeFraction, forcesFraction) + 0.5)
  local right = math.floor(width * math.max(timeFraction, forcesFraction) + 0.5)
  if right - left < TIME_OVERLAY_MIN_GAP then
    gap:Hide()
    return
  end
  if gap._isiLiveLeft ~= left then
    gap._isiLiveLeft = left
    gap:ClearAllPoints()
    gap:SetPoint("TOPLEFT", container, "TOPLEFT", left, 0)
    gap:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", left, 0)
  end
  gap:SetWidth(right - left)
  if forcesFraction >= timeFraction then
    PaintOverlay(gap, "MPLUS_PACE_AHEAD_GAP", { 0.3, 0.85, 0.4, 0.4 })
  else
    PaintOverlay(gap, "MPLUS_PACE_BEHIND_GAP", { 1, 0.25, 0.25, 0.45 })
  end
  gap:Show()
end

--- Feeds the time overlay with the M+ timer box's snapshot and grade (nil
-- without a running key) and redraws it.
local function UpdateKillTrackTimeOverlay(row, timerSnapshot, grade)
  if not row then
    return
  end
  row._timeOverlaySnapshot = timerSnapshot
  row._timeOverlayGrade = grade
  RenderTimeOverlay(row)
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

-- Paints a texture as a horizontal gradient between two alphas of one
-- color token; without gradient support it falls back to a flat tint.
local function PaintGradient(texture, color, fromAlpha, toAlpha)
  local createColor = rawget(_G, "CreateColor")
  if type(texture.SetGradient) == "function" and type(createColor) == "function" then
    texture:SetGradient(
      "HORIZONTAL",
      createColor(color[1], color[2], color[3], fromAlpha),
      createColor(color[1], color[2], color[3], toAlpha)
    )
  elseif type(texture.SetVertexColor) == "function" then
    texture:SetVertexColor(color[1], color[2], color[3], math.max(fromAlpha, toAlpha) / 2)
  end
end

-- Pre-key backdrop of the bar: a muted gold fill over the full width and a
-- light band that sweeps across it. The sweep runs on a child frame of the
-- clipping bar container, so it never draws outside the bar.
local function CreatePreKeyReadyLayer(row, barContainer)
  local colors = UICommon.Colors or {}
  local readyFill = barContainer:CreateTexture(nil, "ARTWORK", nil, 1)
  if type(readyFill.SetAllPoints) == "function" then
    readyFill:SetAllPoints(barContainer)
  end
  if type(readyFill.SetTexture) == "function" then
    readyFill:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(readyFill.SetVertexColor) == "function" then
    readyFill:SetVertexColor(unpack(colors.MPLUS_PREKEY_READY_FILL or { 1.0, 0.84, 0.35, 0.22 }))
  end
  readyFill:Hide()

  if type(barContainer.SetClipsChildren) == "function" then
    barContainer:SetClipsChildren(true)
  end
  local shimmer = CreateFrame("Frame", nil, barContainer)
  shimmer:SetPoint("TOPRIGHT", barContainer, "TOPLEFT", 0, 0)
  shimmer:SetPoint("BOTTOMRIGHT", barContainer, "BOTTOMLEFT", 0, 0)
  if type(shimmer.SetWidth) == "function" then
    shimmer:SetWidth(PREKEY_SHIMMER_WIDTH)
  end
  local shimmerColor = colors.MPLUS_PREKEY_SHIMMER or { 1.0, 0.95, 0.75, 0.55 }
  local half = PREKEY_SHIMMER_WIDTH / 2
  for index, alphas in ipairs({ { 0, shimmerColor[4] }, { shimmerColor[4], 0 } }) do
    local band = shimmer:CreateTexture(nil, "ARTWORK")
    if type(band.SetTexture) == "function" then
      band:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    if type(band.SetBlendMode) == "function" then
      band:SetBlendMode("ADD")
    end
    if type(band.SetPoint) == "function" then
      band:SetPoint("TOPLEFT", shimmer, "TOPLEFT", (index - 1) * half, 0)
      band:SetPoint("BOTTOMLEFT", shimmer, "BOTTOMLEFT", (index - 1) * half, 0)
    end
    if type(band.SetWidth) == "function" then
      band:SetWidth(half)
    end
    PaintGradient(band, shimmerColor, alphas[1], alphas[2])
  end
  local sweepGroup = type(shimmer.CreateAnimationGroup) == "function" and shimmer:CreateAnimationGroup() or nil
  local sweep = nil
  if sweepGroup then
    sweepGroup:SetLooping("REPEAT")
    sweep = sweepGroup:CreateAnimation("Translation")
    sweep:SetDuration(PREKEY_SHIMMER_SECONDS)
    sweep:SetSmoothing("IN_OUT")
  end
  -- Rule 168: no looping animation while hidden; OnShow resumes it.
  if sweepGroup and type(shimmer.SetScript) == "function" then
    shimmer:SetScript("OnHide", function()
      sweepGroup:Stop()
    end)
  end
  shimmer:Hide()

  row.killTrackReadyFill = readyFill
  row.killTrackShimmer = shimmer
  row.killTrackShimmerGroup = sweepGroup
  row.killTrackShimmerSweep = sweep
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

  CreatePreKeyReadyLayer(row, barContainer)

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

  -- Frame above the bar container for text drawn on the bar.
  local barOverlay = CreateFrame("Frame", nil, box)
  barOverlay:SetPoint("LEFT", box, "LEFT", 98, 0)
  barOverlay:SetPoint("RIGHT", box, "RIGHT", -BAR_OVERLAY_RIGHT_OFFSET, 0)
  barOverlay:SetHeight(CD_TRACKER_ROW_HEIGHT)
  if type(barOverlay.SetFrameLevel) == "function" then
    local baseLevel = type(barContainer.GetFrameLevel) == "function" and tonumber(barContainer:GetFrameLevel()) or nil
    barOverlay:SetFrameLevel((baseLevel or 1) + 5)
  end

  -- The pre-key target sits on the empty bar and pulses until the key
  -- starts; name and level share one frame so a single alpha animation
  -- drives both.
  local targetPulse = CreateFrame("Frame", nil, barOverlay)
  targetPulse:SetPoint("LEFT", barOverlay, "LEFT", 0, 0)
  targetPulse:SetPoint("RIGHT", barOverlay, "RIGHT", 0, 0)
  targetPulse:SetHeight(CD_TRACKER_ROW_HEIGHT)
  local targetPulseGroup = type(targetPulse.CreateAnimationGroup) == "function" and targetPulse:CreateAnimationGroup()
    or nil
  if targetPulseGroup then
    targetPulseGroup:SetLooping("BOUNCE")
    local fade = targetPulseGroup:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(PREKEY_PULSE_MIN_ALPHA)
    fade:SetDuration(PREKEY_PULSE_SECONDS)
    fade:SetSmoothing("IN_OUT")
  end
  -- Rule 168: no looping animation while hidden; OnShow resumes it.
  if targetPulseGroup and type(targetPulse.SetScript) == "function" then
    targetPulse:SetScript("OnHide", function()
      targetPulseGroup:Stop()
    end)
    targetPulse:SetScript("OnShow", function()
      if row._targetPulseWanted and not targetPulseGroup:IsPlaying() then
        targetPulseGroup:Play()
      end
    end)
  end

  local targetText = targetPulse:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  targetText:SetPoint("LEFT", targetPulse, "LEFT", PREKEY_TARGET_LEFT_INSET, 0)
  targetText:SetJustifyH("LEFT")
  SetReadableText(targetText, "")
  ApplyFontStringSize(targetText, PREKEY_TARGET_FONT_SIZE)

  local targetLevelText = targetPulse:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  targetLevelText:SetPoint("LEFT", targetText, "RIGHT", PREKEY_LEVEL_GAP, 0)
  targetLevelText:SetJustifyH("LEFT")
  targetLevelText:SetText("")
  ApplyFontStringSize(targetLevelText, PREKEY_TARGET_FONT_SIZE)

  local pctText = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  pctText:SetPoint("RIGHT", box, "RIGHT", -6, 0)
  pctText:SetWidth(58)
  pctText:SetJustifyH("RIGHT")
  pctText:SetText(BuildPercentPlaceholder())
  ApplyFontStringSize(pctText, CD_TRACKER_FONT_SIZE + 2)

  -- Lives on the bar overlay so it draws above fill, gap and strip.
  local timePaceText = barOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  timePaceText:SetPoint("RIGHT", barOverlay, "RIGHT", -TIME_PACE_RIGHT_INSET, 0)
  timePaceText:SetJustifyH("RIGHT")
  if type(timePaceText.SetDrawLayer) == "function" then
    timePaceText:SetDrawLayer("OVERLAY", 7)
  end
  SetReadableText(timePaceText, "")
  ApplyFontStringSize(timePaceText, TIME_PACE_FONT_SIZE)

  -- Time overlay: the gap tint sits above the forces fill, the time strip
  -- above both; the pace tick (OVERLAY) stays on top.
  local timeGap = barContainer:CreateTexture(nil, "ARTWORK", nil, 2)
  if type(timeGap.SetTexture) == "function" then
    timeGap:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  timeGap:Hide()
  local timeStrip = barContainer:CreateTexture(nil, "ARTWORK", nil, 3)
  if type(timeStrip.SetTexture) == "function" then
    timeStrip:SetTexture("Interface\\Buttons\\WHITE8X8")
  end
  if type(timeStrip.SetPoint) == "function" then
    timeStrip:SetPoint("BOTTOMLEFT", barContainer, "BOTTOMLEFT", 0, 0)
  end
  if type(timeStrip.SetHeight) == "function" then
    timeStrip:SetHeight(TIME_STRIP_HEIGHT)
  end
  timeStrip:Hide()
  row.killTrackTimeGap = timeGap
  row.killTrackTimeStrip = timeStrip

  local ttkText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ttkText:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -6, -1)
  ttkText:SetWidth(TTK_TEXT_WIDTH)
  ttkText:SetJustifyH("RIGHT")
  ttkText:SetText("")
  ApplyFontStringSize(ttkText, TTK_FONT_SIZE)
  if type(ttkText.SetTextColor) == "function" then
    ttkText:SetTextColor(unpack((UICommon.Colors and UICommon.Colors.LIGHT_BLUE_LEVEL_TEXT) or { 0.65, 0.85, 1.0 }))
  end
  local ttk = addonTable.TTK
  if type(ttk) == "table" and type(ttk.RegisterDisplay) == "function" then
    ttk.RegisterDisplay(ttkText, {
      format = function()
        return LocalizedText("TTK_WINDOW_FMT", "TTK %.0fs")
      end,
      placeholder = function()
        return LocalizedText("TTK_WINDOW_PENDING", "TTK …")
      end,
    })
  end

  row.killTrackBarContainer = barContainer
  row.killTrackBarBg = barBg
  row.killTrackBarFill = barFill
  row.killTrackBarPull = barPull
  row.killTrackPaceTick = paceTick
  row.killTrackTargetText = targetText
  row.killTrackTargetLevelText = targetLevelText
  row.killTrackBarOverlay = barOverlay
  row.killTrackTargetPulse = targetPulse
  row.killTrackTargetPulseGroup = targetPulseGroup
  row.killTrackPctText = pctText
  row.killTrackPullText = pullText
  row.killTrackTimePaceText = timePaceText
  row.killTrackTtkText = ttkText
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

-- Level of the started key, read only from the M+ timer: the target-dungeon
-- level may describe a key that is not the one running.
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

-- Writes the dungeon name (gold) and key level (light blue) onto the bar;
-- nil clears both.
local function SetBarTarget(row, name, level)
  local targetText = row.killTrackTargetText
  local targetLevelText = row.killTrackTargetLevelText
  if targetText then
    SetReadableText(targetText, name or "")
    if name and type(targetText.SetTextColor) == "function" then
      targetText:SetTextColor(unpack((UICommon.Colors and UICommon.Colors.GOLD_TARGET_TEXT) or { 1.0, 0.84, 0.35 }))
    end
  end
  if targetLevelText then
    targetLevelText:SetText((name and level) and ("+" .. tostring(level)) or "")
    if name and type(targetLevelText.SetTextColor) == "function" then
      targetLevelText:SetTextColor(
        unpack((UICommon.Colors and UICommon.Colors.LIGHT_BLUE_LEVEL_TEXT) or { 0.65, 0.85, 1.0 })
      )
    end
  end
end

-- Shows the gold pre-key backdrop and its light sweep, or hides both. The
-- sweep distance follows the current bar width; reduced motion keeps only the
-- gold fill.
local function SetPreKeyReady(row, ready)
  local fill = row.killTrackReadyFill
  if fill then
    if ready then
      fill:Show()
    else
      fill:Hide()
    end
  end
  local shimmer = row.killTrackShimmer
  local group = row.killTrackShimmerGroup
  if not shimmer then
    return
  end
  local container = row.killTrackBarContainer
  local width = container and type(container.GetWidth) == "function" and tonumber(container:GetWidth()) or 0
  if not ready or not group or width <= 0 or IsReducedMotionEnabled() then
    if group then
      group:Stop()
    end
    shimmer:Hide()
    return
  end
  local distance = width + PREKEY_SHIMMER_WIDTH
  if row._shimmerDistance ~= distance and row.killTrackShimmerSweep then
    group:Stop()
    row.killTrackShimmerSweep:SetOffset(distance, 0)
    row._shimmerDistance = distance
  end
  shimmer:Show()
  if not group:IsPlaying() then
    group:Play()
  end
end

-- Starts or stops the pre-key target pulse. Reduced motion keeps the target
-- steady; a stopped pulse leaves name and level fully opaque.
local function SetTargetPulse(row, wanted)
  row._targetPulseWanted = wanted and true or false
  local group = row.killTrackTargetPulseGroup
  if not group then
    return
  end
  if wanted and not IsReducedMotionEnabled() then
    if not group:IsPlaying() then
      group:Play()
    end
    return
  end
  group:Stop()
  local frame = row.killTrackTargetPulse
  if frame and type(frame.SetAlpha) == "function" then
    frame:SetAlpha(1)
  end
end

local function UpdateKillTrackRow(row, deps)
  if not row then
    return
  end
  row._killTrackActive = false

  local KillTrack = addonTable.KillTrack
  local data = type(KillTrack) == "table" and type(KillTrack.GetData) == "function" and KillTrack.GetData() or nil
  local targetInfo = ResolvePreKeyTargetInfo(deps, data)

  local barContainer = row.killTrackBarContainer
  local barBg = row.killTrackBarBg
  local barFill = row.killTrackBarFill
  local barPull = row.killTrackBarPull
  local pctText = row.killTrackPctText
  local pullText = row.killTrackPullText

  if data and data.active then
    if barContainer and type(barContainer.Show) == "function" then
      barContainer:Show()
    end
    if barBg and type(barBg.Show) == "function" then
      barBg:Show()
    end
    -- The running key keeps its dungeon on the bar, steady instead of pulsing.
    local activeInfo = type(deps) == "table"
        and type(deps.getTargetDungeonInfo) == "function"
        and deps.getTargetDungeonInfo()
      or nil
    local activeName = ResolveTargetDungeonNameFromInfo(activeInfo)
    SetBarTarget(row, activeName, activeName and ResolveActiveKeyLevel() or nil)
    SetTargetPulse(row, false)
    SetPreKeyReady(row, false)
    local pct = math.max(0, math.min(data.percent, 100))
    row._killTrackActive = true
    row._killTrackPercent = pct
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
      pctText:SetText(FormatForcesPercentText(pct))
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
    UpdateTimePaceText(row, data)
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
  else
    HidePaceTick(row)
    UpdateTimePaceText(row, nil)
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
    SetBarTarget(row, targetInfo and targetInfo.name, targetInfo and targetInfo.level)
    SetTargetPulse(row, targetInfo ~= nil)
    SetPreKeyReady(row, targetInfo ~= nil)
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
  RenderTimeOverlay(row)
end

RI.CreateKillTrackRow = CreateKillTrackRow
RI.UpdateKillTrackRow = UpdateKillTrackRow
RI.UpdateKillTrackTimeOverlay = UpdateKillTrackTimeOverlay
