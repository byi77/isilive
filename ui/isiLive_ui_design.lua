local _, addonTable = ...

addonTable = addonTable or {}

-- The "modern" UI design (rule 233): a calm graphite surface language on top
-- of the classic palette. Everything here is data plus decorations that only
-- exist while modern is the active design; UICommon.ApplyDesign writes the
-- palette in place and UICommon.RepaintDesign re-applies backdrops, token
-- paints and decorations to frames that were built before SavedVariables.
-- Classic stays untouched: no classic token, preset or region changes here.
local UICommon = addonTable.UICommon
if type(UICommon) ~= "table" then
  return
end

-- Palette: neutral graphite surfaces with a hint of blue, hairline borders
-- instead of framed boxes, a saturated cool accent for primary actions and
-- dimmed supporting text so values carry the visual weight.
UICommon.ThemeOverrides.modern = {
  SURFACE_MAIN_FRAME = { 0.043, 0.047, 0.060 },
  SURFACE_TITLE_BAR = { 0.090, 0.098, 0.122, 0.90 },
  BORDER_TITLE_BAR = { 0.62, 0.72, 0.86, 0.16 },

  SURFACE_ACTION_PRIMARY = { 0.10, 0.38, 0.74, 0.96 },
  SURFACE_ACTION_PRIMARY_HOVER = { 0.15, 0.47, 0.88, 0.98 },
  SURFACE_ACTION_PRIMARY_PRESSED = { 0.07, 0.28, 0.56, 1 },
  BORDER_ACTION_PRIMARY = { 0.48, 0.74, 1, 0.42 },
  SURFACE_ACTION_SECONDARY = { 0.105, 0.115, 0.140, 0.94 },
  SURFACE_ACTION_SECONDARY_HOVER = { 0.150, 0.165, 0.200, 0.97 },
  SURFACE_ACTION_SECONDARY_PRESSED = { 0.065, 0.070, 0.088, 0.98 },
  BORDER_ACTION_SECONDARY = { 0.62, 0.70, 0.82, 0.14 },

  SURFACE_RUN_ZONE = { 0.105, 0.115, 0.145, 0.94 },
  BORDER_RUN_ZONE = { 0.62, 0.72, 0.86, 0.12 },

  TEXT_HEADING = { 0.96, 0.97, 1 },
  TEXT_SECTION = { 0.60, 0.67, 0.78 },
  BLUE_VERSION_TEXT = { 0.44, 0.51, 0.62 },
  ROW_ALT = { 1, 1, 1, 0.028 },
  MPLUS_FORCES_PROGRESS_FILL = { 0.30, 0.62, 1.0 },
  -- Empty killtracker bar: a translucent graphite track instead of a black block.
  DARK_GRAY_BAR_BG = { 0.20, 0.23, 0.29, 0.55 },
}

-- Text roles: run-card values read as cool white values instead of the gold
-- of the Blizzard default font object.
UICommon.DesignTextRoles.modern = {
  RUN_VALUE = "TEXT_HEADING",
}

-- Backdrop patches: the run-zone cards (BR/BL, M+ timer, killtracker) get a
-- real surface instead of the classic faint tint behind a framed border.
-- Buttons are borderless surfaces: fill and sheen carry them, the role shows
-- in the fill (primary accent, secondary graphite).
local BACKDROP_BORDERLESS = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
}

UICommon.DesignBackdropPresets.modern = {
  CD_BOX = { backgroundAlphaFactor = 0.85 },
  MPLUS_BOX = { backgroundAlphaFactor = 0.85 },
  FLAT_BUTTON = { backdrop = BACKDROP_BORDERLESS },
  TITLE_BUTTON = { backdrop = BACKDROP_BORDERLESS },
}

-- All action buttons share the calm secondary surface (user decision
-- 2026-11-02): no accent fill for Readycheck / Countdown.
UICommon.DesignButtonRoles.modern = {
  primary = "secondary",
}

-- Locked buttons (leader-only for a non-leader, unavailable) keep the quiet
-- secondary hairline, so they read as dimmed instead of outlined. Cooldown
-- and combat locks keep their informative classic state colors.
UICommon.DesignAvailabilityBorders.modern = {
  leader = UICommon.Colors.BORDER_ACTION_SECONDARY,
  unavailable = UICommon.Colors.BORDER_ACTION_SECONDARY,
}

-- Kept small and light: over bright zones a strong shadow reads as a dark box.
local SHADOW_SIZE = 7
local SHADOW_ALPHA = 0.2
local PORTAL_ICON_INSET = 1
-- The short code sits in the middle of the tile, so the scrim has to carry
-- about half darkness there: bright artwork (e.g. TVS, DBT) stayed borderline
-- readable with a 0.5 -> 0 scrim in the client (2026-11-02).
local PORTAL_SCRIM_BOTTOM_ALPHA = 0.8
local PORTAL_SCRIM_TOP_ALPHA = 0.25
-- Matches the 27 px title bar of CreatePanelChrome.
local HEADER_GLOW_HEIGHT = 28
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function NewColor(color, alpha)
  local createColor = rawget(_G, "CreateColor")
  if type(createColor) ~= "function" or type(color) ~= "table" then
    return nil
  end
  return createColor(color[1], color[2], color[3], alpha)
end

-- A white texture tinted by a two-stop gradient. Clients without CreateColor
-- or SetGradient get the start color as a flat tint.
local function PaintGradient(texture, orientation, color, fromAlpha, toAlpha)
  texture:SetTexture(WHITE)
  local from, to = NewColor(color, fromAlpha), NewColor(color, toAlpha)
  if from and to and type(texture.SetGradient) == "function" then
    texture:SetGradient(orientation, from, to)
  elseif type(texture.SetVertexColor) == "function" then
    texture:SetVertexColor(color[1], color[2], color[3], fromAlpha)
  end
end

local function SetShown(regions, shown)
  for _, region in ipairs(regions) do
    if shown then
      region:Show()
    else
      region:Hide()
    end
  end
end

-- Lazily creates a frame's decoration set once, then only toggles it.
local function Decoration(frame, key, active, build)
  local store = frame._isiLiveDesignDecor
  if not store then
    if not active then
      return
    end
    store = {}
    frame._isiLiveDesignDecor = store
  end
  local regions = store[key]
  if not regions then
    if not active or type(frame.CreateTexture) ~= "function" then
      return
    end
    regions = build(frame)
    store[key] = regions
  end
  SetShown(regions, active)
end

local BLACK = { 0, 0, 0 }

-- Soft drop shadow outside the frame edges, a thin accent line along the top
-- that fades out to the right, and a faint top-down sheen on the surface.
local function BuildMainFrameDecor(frame)
  local colors = UICommon.Colors
  local regions = {}

  local function Shadow(point1, rel1, point2, rel2, orientation, fromAlpha, toAlpha, width, height)
    local shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetPoint(point1, frame, rel1)
    shadow:SetPoint(point2, frame, rel2)
    if width then
      shadow:SetWidth(width)
    end
    if height then
      shadow:SetHeight(height)
    end
    PaintGradient(shadow, orientation, BLACK, fromAlpha, toAlpha)
    regions[#regions + 1] = shadow
  end
  Shadow("BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT", "TOPRIGHT", "VERTICAL", SHADOW_ALPHA, 0, nil, SHADOW_SIZE)
  Shadow("TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", "VERTICAL", 0, SHADOW_ALPHA, nil, SHADOW_SIZE)
  Shadow("TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", "HORIZONTAL", 0, SHADOW_ALPHA, SHADOW_SIZE, nil)
  Shadow("TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "HORIZONTAL", SHADOW_ALPHA, 0, SHADOW_SIZE, nil)

  local sheen = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  sheen:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  sheen:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
  PaintGradient(sheen, "VERTICAL", colors.WHITE_RGB, 0, 0.035)
  regions[#regions + 1] = sheen

  -- Cool accent glow behind the title row, strongest at the brand on the left.
  local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
  glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  glow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  glow:SetHeight(HEADER_GLOW_HEIGHT)
  PaintGradient(glow, "HORIZONTAL", colors.ACCENT_BLUE, 0.16, 0)
  regions[#regions + 1] = glow

  local accent = frame:CreateTexture(nil, "ARTWORK", nil, 7)
  accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  accent:SetHeight(2)
  PaintGradient(accent, "HORIZONTAL", colors.ACCENT_BLUE, 0.95, 0.08)
  regions[#regions + 1] = accent

  return regions
end

-- Run-zone cards: an accent stripe on the left edge and a hairline highlight
-- along the top, so the card reads as a raised surface without a frame.
local function BuildRunCardDecor(frame)
  local colors = UICommon.Colors
  local stripe = frame:CreateTexture(nil, "ARTWORK", nil, 7)
  stripe:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  stripe:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
  stripe:SetWidth(2)
  PaintGradient(stripe, "VERTICAL", colors.ACCENT_BLUE, 0.55, 0.95)

  local highlight = frame:CreateTexture(nil, "ARTWORK", nil, 6)
  highlight:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -1)
  highlight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  highlight:SetHeight(1)
  PaintGradient(highlight, "HORIZONTAL", colors.WHITE_RGB, 0.10, 0.02)

  return { stripe, highlight }
end

-- Buttons: a faint top-down sheen behind the label.
local function BuildButtonDecor(frame)
  local sheen = frame:CreateTexture(nil, "BORDER", nil, 1)
  sheen:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  sheen:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
  PaintGradient(sheen, "VERTICAL", UICommon.Colors.WHITE_RGB, 0, 0.07)
  return { sheen }
end

-- Portal tiles (ui/isiLive_teleport_ui.lua): a bottom-up scrim keeps the
-- dungeon short code readable on bright artwork, a hairline replaces the dark
-- tile frame, and a soft additive highlight answers the mouse. Drawn on the
-- tile button itself, so the cooldown swipe and the label frame stay on top.
local function BuildPortalTileDecor(frame)
  local colors = UICommon.Colors
  local regions = {}

  local scrim = frame:CreateTexture(nil, "ARTWORK", nil, 7)
  scrim:SetPoint("TOPLEFT", frame, "TOPLEFT", PORTAL_ICON_INSET, -PORTAL_ICON_INSET)
  scrim:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PORTAL_ICON_INSET, PORTAL_ICON_INSET)
  PaintGradient(scrim, "VERTICAL", BLACK, PORTAL_SCRIM_BOTTOM_ALPHA, PORTAL_SCRIM_TOP_ALPHA)
  regions[#regions + 1] = scrim

  local edges = {
    { "TOPLEFT", "TOPRIGHT", nil, 1 },
    { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
    { "TOPLEFT", "BOTTOMLEFT", 1, nil },
    { "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
  }
  for _, edge in ipairs(edges) do
    local line = frame:CreateTexture(nil, "OVERLAY", nil, 6)
    line:SetPoint(edge[1], frame, edge[1])
    line:SetPoint(edge[2], frame, edge[2])
    if edge[3] then
      line:SetWidth(edge[3])
    else
      line:SetHeight(edge[4])
    end
    PaintGradient(line, "HORIZONTAL", colors.WHITE_RGB, 0.14, 0.14)
    regions[#regions + 1] = line
  end

  local hover = frame:CreateTexture(nil, "HIGHLIGHT")
  hover:SetAllPoints(frame)
  PaintGradient(hover, "VERTICAL", colors.WHITE_RGB, 0.04, 0.16)
  if type(hover.SetBlendMode) == "function" then
    hover:SetBlendMode("ADD")
  end
  regions[#regions + 1] = hover

  return regions
end

-- The classic tile shows a 2 px dark frame around the artwork; modern lets
-- the artwork run to a 1 px hairline.
local CLASSIC_PORTAL_ICON_INSET = 2
local function SetPortalIconInset(frame, inset)
  local icon = frame.icon
  if type(icon) ~= "table" or type(icon.ClearAllPoints) ~= "function" then
    return
  end
  icon:ClearAllPoints()
  icon:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
  icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
end

-- Killtracker forces bar (ui/isiLive_roster_panel_kill_row.lua): a slightly
-- taller track with a hairline edge and a glassy top sheen. Section ticks,
-- the pull segment and the time strip keep drawing above it (OVERLAY and
-- higher ARTWORK sublevels).
local MODERN_FORCES_BAR_HEIGHT = 12
local function BuildForcesBarDecor(frame)
  local colors = UICommon.Colors
  local regions = {}

  local gloss = frame:CreateTexture(nil, "ARTWORK", nil, 7)
  gloss:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  gloss:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  gloss:SetHeight(MODERN_FORCES_BAR_HEIGHT / 2)
  PaintGradient(gloss, "VERTICAL", colors.WHITE_RGB, 0, 0.14)
  regions[#regions + 1] = gloss

  local edges = {
    { "TOPLEFT", "TOPRIGHT", nil, 1 },
    { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
    { "TOPLEFT", "BOTTOMLEFT", 1, nil },
    { "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
  }
  for _, edge in ipairs(edges) do
    local line = frame:CreateTexture(nil, "OVERLAY", nil, -1)
    line:SetPoint(edge[1], frame, edge[1])
    line:SetPoint(edge[2], frame, edge[2])
    if edge[3] then
      line:SetWidth(edge[3])
    else
      line:SetHeight(edge[4])
    end
    PaintGradient(line, "HORIZONTAL", colors.WHITE_RGB, 0.10, 0.10)
    regions[#regions + 1] = line
  end
  return regions
end

-- BR/BL icons in the run card (ui/isiLive_roster_panel_cd_row.lua): round
-- icons with a thin light ring and a circular cooldown swipe. The circle is
-- Blizzard's portrait alpha mask, which the client ships and many maintained
-- addons use for round icons and swipes. The card lists its icons in
-- `frame._isiLiveRunIcons` ({ icon, cooldown } pairs).
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local RUN_ICON_RING_WIDTH = 1
local RUN_ICON_SQUARE_SWIPE = WHITE

local function NewCircleMask(frame, anchor, outset)
  local mask = frame:CreateMaskTexture()
  mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetPoint("TOPLEFT", anchor, "TOPLEFT", -outset, outset)
  mask:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", outset, -outset)
  return mask
end

local function DecorateRunIcon(frame, entry, active)
  local icon, cooldown = entry.icon, entry.cooldown
  if type(icon) ~= "table" then
    return
  end
  if active and not entry.mask then
    if type(frame.CreateMaskTexture) ~= "function" or type(icon.AddMaskTexture) ~= "function" then
      return
    end
    entry.mask = NewCircleMask(frame, icon, 0)
    -- The ring is a light disc one pixel wider than the icon, drawn behind it.
    entry.ring = frame:CreateTexture(nil, "ARTWORK", nil, 7)
    entry.ring:SetPoint("TOPLEFT", icon, "TOPLEFT", -RUN_ICON_RING_WIDTH, RUN_ICON_RING_WIDTH)
    entry.ring:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", RUN_ICON_RING_WIDTH, -RUN_ICON_RING_WIDTH)
    local ringColor = UICommon.Colors.BORDER_TITLE_BAR
    entry.ring:SetColorTexture(ringColor[1], ringColor[2], ringColor[3], ringColor[4] or 1)
    entry.ringMask = NewCircleMask(frame, icon, RUN_ICON_RING_WIDTH)
    entry.ring:AddMaskTexture(entry.ringMask)
  end
  if not entry.mask then
    return
  end
  if active and not entry.masked then
    icon:AddMaskTexture(entry.mask)
    entry.masked = true
  elseif not active and entry.masked then
    icon:RemoveMaskTexture(entry.mask)
    entry.masked = false
  end
  if active then
    entry.ring:Show()
  else
    entry.ring:Hide()
  end
  if type(cooldown) == "table" then
    if type(cooldown.SetSwipeTexture) == "function" then
      cooldown:SetSwipeTexture(active and CIRCLE_MASK or RUN_ICON_SQUARE_SWIPE)
    end
    if type(cooldown.SetUseCircularEdge) == "function" then
      cooldown:SetUseCircularEdge(active)
    end
  end
end

local function DecorateRunIcons(frame, active)
  local entries = frame._isiLiveRunIcons
  if type(entries) ~= "table" then
    return
  end
  for _, entry in ipairs(entries) do
    DecorateRunIcon(frame, entry, active)
  end
end

local function Decorator(key, build)
  return function(frame, active)
    Decoration(frame, key, active, build)
  end
end

local runCard = Decorator("runCard", BuildRunCardDecor)
local button = Decorator("button", BuildButtonDecor)
local portalTile = Decorator("portalTile", BuildPortalTileDecor)
local forcesBar = Decorator("forcesBar", BuildForcesBarDecor)

UICommon.DesignDecorators.modern = {
  MAIN_FRAME = Decorator("mainFrame", BuildMainFrameDecor),
  CD_BOX = runCard,
  MPLUS_BOX = runCard,
  FLAT_BUTTON = button,
  TITLE_BUTTON = button,
  RUN_ICONS = DecorateRunIcons,
  FORCES_BAR = function(frame, active)
    if active and frame._isiLiveClassicHeight == nil and type(frame.GetHeight) == "function" then
      frame._isiLiveClassicHeight = frame:GetHeight()
    end
    forcesBar(frame, active)
    local height = active and MODERN_FORCES_BAR_HEIGHT or frame._isiLiveClassicHeight
    if height and type(frame.SetHeight) == "function" then
      frame:SetHeight(height)
    end
  end,
  PORTAL_TILE = function(frame, active)
    portalTile(frame, active)
    -- Only a tile modern has decorated before needs its classic inset back.
    if active or frame._isiLiveDesignDecor then
      SetPortalIconInset(frame, active and PORTAL_ICON_INSET or CLASSIC_PORTAL_ICON_INSET)
    end
  end,
}

-- M+ timer box (ui/isiLive_roster_panel_cd_row.lua): the elapsed time leads,
-- next to the time limit; a short time strip shows the run against the limit
-- with +3/+2 ticks; only the chest grade that is still reachable is listed,
-- with its remaining time (overtime: red +1 overshoot). The death count, its
-- icon and tooltip keep their classic place at the right of the box.
local TIMER_CLASSIC_KEYS = { "mplusLabel", "mp3Icon", "mp3Text", "mp2Icon", "mp2Text", "mp1Icon", "mp1Text" }
local TIMER_ELAPSED_SIZE = 15
local TIMER_LIMIT_SIZE = 10
local TIMER_GRADE_SIZE = 12
local TIMER_TRACK_LEFT = 98
local TIMER_TRACK_WIDTH = 68
local TIMER_TRACK_HEIGHT = 4
local TIMER_TICK_HEIGHT = 8
local TIMER_GRADE_TOKENS = {
  [3] = "MPLUS_GRADE3_FILL",
  [2] = "MPLUS_GRADE2_FILL",
  [1] = "MPLUS_GRADE1_FILL",
  [0] = "MPLUS_OVERTIME_FILL",
}

local function SetTokenColor(region, methodName, token)
  local color = UICommon.Colors[token]
  if type(color) == "table" and type(region[methodName]) == "function" then
    region[methodName](region, color[1], color[2], color[3], color[4] or 1)
  end
end

local function SizeFont(fontString, size)
  local path, _, flags = fontString:GetFont()
  local localePath = type(UICommon.GetLocaleFontPath) == "function" and UICommon.GetLocaleFontPath() or nil
  path = localePath or path
  if type(path) == "string" and path ~= "" then
    fontString:SetFont(path, size, flags)
  end
end

local function FormatTimerSeconds(seconds)
  local total = math.floor(math.abs(seconds))
  return string.format("%d:%02d", math.floor(total / 60), total % 60)
end

local function NewTimerText(box, size)
  local text = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  SizeFont(text, size)
  text:SetJustifyH("LEFT")
  if type(text.SetWordWrap) == "function" then
    text:SetWordWrap(false)
  end
  return text
end

local function NewTrackTexture(box, layer, sublevel, token)
  local texture = box:CreateTexture(nil, layer, nil, sublevel)
  SetTokenColor(texture, "SetColorTexture", token)
  return texture
end

local function BuildTimerParts(row)
  local box = row.mplusBox
  local parts = {}
  parts.elapsed = NewTimerText(box, TIMER_ELAPSED_SIZE)
  parts.elapsed:SetPoint("LEFT", box, "LEFT", 8, 0)
  parts.limit = NewTimerText(box, TIMER_LIMIT_SIZE)
  parts.limit:SetPoint("LEFT", parts.elapsed, "RIGHT", 3, -1)
  SetTokenColor(parts.limit, "SetTextColor", "TEXT_SUPPORTING")

  parts.track = NewTrackTexture(box, "ARTWORK", 1, "DARK_GRAY_BAR_BG")
  parts.track:SetPoint("LEFT", box, "LEFT", TIMER_TRACK_LEFT, 0)
  parts.track:SetSize(TIMER_TRACK_WIDTH, TIMER_TRACK_HEIGHT)
  parts.fill = NewTrackTexture(box, "ARTWORK", 2, "MPLUS_GRADE3_FILL")
  parts.fill:SetPoint("LEFT", parts.track, "LEFT", 0, 0)
  parts.fill:SetSize(1, TIMER_TRACK_HEIGHT)
  parts.ticks = {}
  for grade = 3, 2, -1 do
    local tick = NewTrackTexture(box, "OVERLAY", 1, "MPLUS_TIMELINE_TICK")
    tick:SetSize(1, TIMER_TICK_HEIGHT)
    parts.ticks[grade] = tick
  end

  parts.gradeLabel = NewTimerText(box, TIMER_GRADE_SIZE)
  parts.gradeLabel:SetPoint("LEFT", parts.track, "RIGHT", 8, 0)
  parts.gradeTime = NewTimerText(box, TIMER_GRADE_SIZE)
  parts.gradeTime:SetPoint("LEFT", parts.gradeLabel, "RIGHT", 4, 0)

  parts.regions = {
    parts.elapsed,
    parts.limit,
    parts.track,
    parts.fill,
    parts.ticks[3],
    parts.ticks[2],
    parts.gradeLabel,
    parts.gradeTime,
  }
  return parts
end

local function SetClassicTimerShown(row, shown)
  for _, key in ipairs(TIMER_CLASSIC_KEYS) do
    local element = row[key]
    if type(element) == "table" and type(element.Show) == "function" then
      if shown then
        element:Show()
      else
        element:Hide()
      end
    end
  end
end

local function RenderIdleTimer(parts)
  parts.elapsed:SetText("--:--")
  SetTokenColor(parts.elapsed, "SetTextColor", "TEXT_SUPPORTING")
  parts.limit:SetText("")
  parts.fill:Hide()
  parts.ticks[3]:Hide()
  parts.ticks[2]:Hide()
  parts.gradeLabel:SetText("")
  parts.gradeTime:SetText("")
end

local function PlaceTimerTick(parts, grade, timer, remaining, limit)
  local tick = parts.ticks[grade]
  local cutoff = timer + (tonumber(remaining) or -timer)
  if limit <= 0 or cutoff <= 0 or cutoff >= limit then
    tick:Hide()
    return
  end
  tick:ClearAllPoints()
  tick:SetPoint("CENTER", parts.track, "LEFT", TIMER_TRACK_WIDTH * cutoff / limit, 0)
  tick:Show()
end

local function RenderRunningTimer(parts, data, activeGrade)
  local timer = math.max(0, tonumber(data.timer) or 0)
  local limit = tonumber(data.timeLimit) or 0
  local grade = TIMER_GRADE_TOKENS[activeGrade] and activeGrade or 0
  local gradeToken = TIMER_GRADE_TOKENS[grade]

  parts.elapsed:SetText(FormatTimerSeconds(timer))
  SetTokenColor(parts.elapsed, "SetTextColor", grade == 0 and "TEXT_ALERT_DANGER" or "TEXT_HEADING")
  parts.limit:SetText(limit > 0 and ("/ " .. FormatTimerSeconds(limit)) or "")

  local fraction = limit > 0 and math.min(1, timer / limit) or 0
  parts.fill:SetWidth(math.max(1, TIMER_TRACK_WIDTH * fraction))
  SetTokenColor(parts.fill, "SetColorTexture", gradeToken)
  parts.fill:Show()
  PlaceTimerTick(parts, 3, timer, data.timeRemaining3, limit)
  PlaceTimerTick(parts, 2, timer, data.timeRemaining2, limit)

  local remaining = tonumber(data["timeRemaining" .. math.max(1, grade)]) or 0
  parts.gradeLabel:SetText("+" .. math.max(1, grade))
  SetTokenColor(parts.gradeLabel, "SetTextColor", gradeToken)
  parts.gradeTime:SetText((grade == 0 and "-" or "") .. FormatTimerSeconds(remaining))
  SetTokenColor(parts.gradeTime, "SetTextColor", grade == 0 and "TEXT_ALERT_DANGER" or "TEXT_HEADING")
end

-- Ready-check status on a roster row (ui/isiLive_roster_panel_render.lua):
-- a lighter wash over the row instead of the classic full-strength tint. No
-- status stripe: the class stripe already sits on the left edge, and a second
-- colored stripe next to it read as too many colors (user decision
-- 2026-11-02). The wash is a plain SetColorTexture fill on the classic tint's
-- own anchors: a gradient on this per-render path drew as an opaque white
-- block in the client. The hold bar along the bottom edge is unchanged.
local READY_CHECK_WASH_ALPHA_FACTOR = 0.5

local function BuildReadyCheckParts(row)
  local anchor = row.hoverFrame or row
  local parts = {}
  parts.wash = anchor:CreateTexture(nil, "BACKGROUND", nil, 1)
  if row.readyCheckBackground then
    parts.wash:SetAllPoints(row.readyCheckBackground)
  else
    parts.wash:SetAllPoints(anchor)
  end
  parts.regions = { parts.wash }
  return parts
end

local function ApplyReadyCheckRow(row, color)
  if type(row) ~= "table" then
    return
  end
  local parts = row._modernReadyCheck
  if type(color) ~= "table" or #color < 4 then
    if parts then
      SetShown(parts.regions, false)
      parts.statusKey = nil
    end
    return
  end
  if not parts then
    if type((row.hoverFrame or row).CreateTexture) ~= "function" then
      return
    end
    parts = BuildReadyCheckParts(row)
    row._modernReadyCheck = parts
  end
  if row.readyCheckBackground and type(row.readyCheckBackground.Hide) == "function" then
    row.readyCheckBackground:Hide()
  end
  parts.wash:SetColorTexture(color[1], color[2], color[3], color[4] * READY_CHECK_WASH_ALPHA_FACTOR)
  SetShown(parts.regions, true)
  local statusKey = table.concat(color, ",")
  if parts.statusKey ~= statusKey and type(UICommon.PlayAlphaTransition) == "function" then
    UICommon.PlayAlphaTransition(parts.wash, "readyCheckTint", { fromAlpha = 0, toAlpha = 1, duration = "normal" })
  end
  parts.statusKey = statusKey
end

UICommon.DesignComponents.modern = {
  READY_CHECK_ROW = {
    -- `color` is the classic status tint ({ r, g, b, a }) or nil without a status.
    Apply = ApplyReadyCheckRow,
    Release = function(row)
      local parts = type(row) == "table" and row._modernReadyCheck or nil
      if parts then
        SetShown(parts.regions, false)
        parts.statusKey = nil
      end
      if type(row) == "table" and row._readyCheckStatusKey and row.readyCheckBackground then
        row.readyCheckBackground:Show()
      end
    end,
  },
  MPLUS_TIMER = {
    -- `data` is the MplusTimer snapshot of a running or completed key, nil
    -- without one; `activeGrade` is 3/2/1, or 0 in overtime.
    Update = function(row, data, activeGrade)
      if type(row) ~= "table" or type(row.mplusBox) ~= "table" then
        return
      end
      local parts = row._modernTimer
      if not parts then
        parts = BuildTimerParts(row)
        row._modernTimer = parts
      end
      SetClassicTimerShown(row, false)
      SetShown(parts.regions, true)
      if type(data) == "table" then
        RenderRunningTimer(parts, data, activeGrade)
      else
        RenderIdleTimer(parts)
      end
    end,
    Release = function(row)
      if type(row) == "table" and row._modernTimer then
        SetShown(row._modernTimer.regions, false)
      end
      SetClassicTimerShown(row, true)
    end,
  },
}
