local _, addonTable = ...
addonTable = addonTable or {}

-- Lua 5.1 (WoW client) exposes global `unpack`; Lua 5.4 (local tooling) only
-- has `table.unpack`. Bridge locally so this file works under both without
-- depending on the entrypoint script to have set up a global compat shim.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

local MobNameplate = {}
addonTable.MobNameplate = MobNameplate

local UICommon = addonTable.UICommon

local enabled = false
local registered = false
local eventFrame = nil

local frames = {}

local format = {
  showPercent = true,
  showRemaining = false,
}

local appearance = {
  fontSize = 14,
  position = "RIGHT",
  xOffset = 0,
  yOffset = 0,
}

local ANCHOR_GAP = 8

-- Debug overlay: when active, UpdateNameplate skips the challenge-mode and
-- DB/API checks and renders `testPercent` on every eligible (hostile/neutral)
-- nameplate. Drives the ApplyFont / ApplyFrameSizeForFont path live so the
-- size slider can be verified outside a key.
local testMode = false
local testPercent = "1.23"
local testActiveMapID = nil

local IsSecretValue = addonTable.Validators.IsSecretValue

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok then
    return nil
  end
  return a, b, c, d
end

local function IsChallengeModeActive()
  local api = rawget(_G, "C_ChallengeMode")
  if type(api) ~= "table" or type(api.IsChallengeModeActive) ~= "function" then
    return false
  end
  local ok, active = pcall(api.IsChallengeModeActive)
  return ok and not IsSecretValue(active) and active == true
end

local function HasProgressAPI()
  local api = rawget(_G, "C_ScenarioInfo")
  return type(api) == "table" and type(api.GetUnitCriteriaProgressValues) == "function"
end

local function HasNamePlateAPI()
  local api = rawget(_G, "C_NamePlate")
  return type(api) == "table" and type(api.GetNamePlateForUnit) == "function"
end

local function GetNameplate(unit)
  local api = rawget(_G, "C_NamePlate")
  if type(api) ~= "table" or type(api.GetNamePlateForUnit) ~= "function" then
    return nil
  end
  local ok, plate = pcall(api.GetNamePlateForUnit, unit)
  if not ok or type(plate) ~= "table" then
    return nil
  end
  return plate
end

-- Parses a unit GUID and returns the NPC id as a number (nil for players/pets).
-- Secret-Value guarded: the GUID must be type-checked, Secret-checked and
-- non-empty BEFORE `:match` runs, otherwise a tainted GUID taints the stack.
local function NpcIdFromGuid(guid)
  if type(guid) ~= "string" or IsSecretValue(guid) or guid == "" then
    return nil
  end
  local kind, _, _, _, _, npcStr = guid:match("^(%a+)%-(%d+)%-(%d+)%-(%d+)%-(%d+)%-(%d+)%-")
  if kind ~= "Creature" and kind ~= "Vehicle" then
    return nil
  end
  return tonumber(npcStr)
end

-- Computes a mob's forces contribution from the bundled MDT-synced DB
-- (data/isiLive_mplus_forces.lua). Returns (percentString, rawCount) on success
-- or (nil, nil) when the NPC is not tracked / the map has no forces total.
-- This is the source of truth for "what does THIS mob contribute to the key"
-- because Blizzard's GetUnitCriteriaProgressValues(unit) percentString in 12.0+
-- can return the cumulative dungeon progress under some protected paths instead
-- of the per-mob value the criterion was originally designed to expose.
local function GetForcesDB()
  local seasonData = addonTable.SeasonData
  if type(seasonData) == "table" and type(seasonData.GetMatchingForcesData) == "function" then
    return seasonData.GetMatchingForcesData()
  end
  return addonTable.MPlusForces
end

local function ResolveMobContributionFromDB(unit, activeMapID)
  if type(activeMapID) ~= "number" or not addonTable.Validators.IsExistingUnit(unit) then
    return nil, nil
  end
  local unitGUIDFn = rawget(_G, "UnitGUID")
  if type(unitGUIDFn) ~= "function" then
    return nil, nil
  end
  local okGuid, guid = pcall(unitGUIDFn, unit)
  if not okGuid or IsSecretValue(guid) or type(guid) ~= "string" then
    return nil, nil
  end
  local npcId = NpcIdFromGuid(guid)
  if not npcId then
    return nil, nil
  end
  local db = GetForcesDB()
  if type(db) ~= "table" or type(db.byNpcId) ~= "table" or type(db.dungeonTotal) ~= "table" then
    return nil, nil
  end
  local entry = db.byNpcId[npcId]
  if type(entry) ~= "table" or entry.mapID ~= activeMapID then
    return nil, nil
  end
  local dungeon = db.dungeonTotal[activeMapID]
  local total = dungeon and tonumber(dungeon.total) or 0
  local count = tonumber(entry.count) or 0
  if total <= 0 or count <= 0 then
    return nil, nil
  end
  local percent = (count / total) * 100
  return string.format("%.2f", percent), count
end

local function GetActiveChallengeMapID()
  local api = rawget(_G, "C_ChallengeMode")
  if type(api) ~= "table" or type(api.GetActiveChallengeMapID) ~= "function" then
    return nil
  end
  local ok, mapID = pcall(api.GetActiveChallengeMapID)
  if not ok or IsSecretValue(mapID) or type(mapID) ~= "number" or mapID <= 0 then
    return nil
  end
  return mapID
end

local function IsEligibleUnit(unit)
  local unitExists = rawget(_G, "UnitExists")
  if type(unitExists) ~= "function" then
    return false
  end
  local okExists, exists = pcall(unitExists, unit)
  if not okExists or IsSecretValue(exists) or exists ~= true then
    return false
  end

  -- The GUID is intentionally NOT required here. In WoW 12.0 M+ keystones
  -- UnitGUID returns a Secret Value on tainted-context targets, which would
  -- otherwise hide every nameplate during a key. Downstream consumers
  -- (ResolveMobContributionFromDB) handle a missing GUID with their own
  -- guard and fall back to the API path.
  local unitReaction = rawget(_G, "UnitReaction")
  if type(unitReaction) == "function" then
    local okReact, reaction = pcall(unitReaction, unit, "player")
    if okReact and not IsSecretValue(reaction) and type(reaction) == "number" and reaction > 4 then
      return false
    end
  end

  return true
end

local function ResolveRemainingPercent(activeMapID)
  if not format.showRemaining or type(activeMapID) ~= "number" then
    return nil
  end
  local killTrack = addonTable.KillTrack
  if type(killTrack) ~= "table" or type(killTrack.GetData) ~= "function" then
    return nil
  end
  local ok, data = pcall(killTrack.GetData)
  if not ok or type(data) ~= "table" or data.active ~= true then
    return nil
  end
  if tonumber(data.mapID) ~= activeMapID then
    return nil
  end
  local total = tonumber(data.total)
  if not total or total <= 0 then
    return nil
  end
  local rawCount = tonumber(data.rawCount)
  if rawCount == nil then
    local percent = tonumber(data.percent)
    if not percent then
      return nil
    end
    rawCount = (percent / 100) * total
  end
  local remainingCount = math.max(0, total - rawCount)
  return string.format("%.2f", (remainingCount / total) * 100)
end

local function BuildTextForFormat(fmt, percentString, remainingPercentString)
  fmt = type(fmt) == "table" and fmt or format
  if not fmt.showPercent or type(percentString) ~= "string" then
    return nil
  end
  -- Do NOT compare percentString to "" — in WoW 12.0 M+ tainted context the
  -- API returns it as a Secret Value and `==` raises a tainted-compare
  -- error. The concatenation below is wrapped in pcall: an empty Secret
  -- string concatenates to "%" (still rendered), and any genuine string
  -- runtime errors fall through to nil.
  local ok, text = pcall(function()
    local text = percentString .. "%"
    if type(remainingPercentString) == "string" then
      text = text .. "/" .. remainingPercentString .. "%"
    end
    return text
  end)
  if not ok or type(text) ~= "string" then
    return nil
  end
  return text
end

local function BuildText(percentString, remainingPercentString)
  return BuildTextForFormat(format, percentString, remainingPercentString)
end

local function ResolveFontSize()
  return tonumber(appearance.fontSize) or 14
end

local function ApplyFrameSizeForFont(frame, size, showRemainingOverride)
  if not frame or type(frame.SetSize) ~= "function" then
    return
  end
  -- Scale the host frame so larger fonts have enough room. Height ≈ size + 6
  -- (small visual padding); width grows linearly so 4-character percent text
  -- ("99.9%") never gets clipped on the side.
  local height = math.max(20, math.ceil(size + 6))
  local showRemaining = showRemainingOverride
  if type(showRemaining) ~= "boolean" then
    showRemaining = format.showRemaining == true
  end
  local widthMultiplier = showRemaining and 7 or 4
  local width = math.max(80, math.ceil(size * widthMultiplier))
  -- Dirty-check: SetSize is invoked from RefreshAll (every kill in M+) for
  -- frames whose dimensions haven't changed. Skipping the pcall+API call is
  -- a measurable win during AoE pulls.
  if frame._lastSizeW == width and frame._lastSizeH == height then
    return
  end
  if pcall(frame.SetSize, frame, width, height) then
    frame._lastSizeW = width
    frame._lastSizeH = height
  end
end

local function ApplyRenderedText(frame, text)
  if not (frame and frame.text and frame.text.SetText) then
    return
  end
  -- Dirty-check `_lastText` so RefreshAll (fires on every mob kill in M+)
  -- does not re-SetText 40 plates when nothing changed. `text` can be a
  -- Secret Value in 12.0 M+ tainted context. Plain compare and plain assign
  -- both poison the field and raise "tainted by 'isiLive'" on the next
  -- call, so both the read and the write are pcall-guarded.
  local equal = false
  pcall(function()
    equal = frame.text._lastText == text
  end)
  if equal then
    return
  end
  frame.text:SetText(text)
  local canCache = false
  pcall(function()
    canCache = text == text
  end)
  if canCache then
    frame.text._lastText = text
  else
    frame.text._lastText = nil
  end
end

local function ApplyFont(fontString)
  if type(fontString) ~= "table" or type(fontString.SetFont) ~= "function" then
    return
  end
  local size = ResolveFontSize()
  -- Dirty-check: ApplyFont is called from every UpdateNameplate. The font
  -- size only changes when the user moves the slider or fontSize default
  -- switches; skip the SetFontObject/SetFont/SetTextHeight chain when nothing
  -- could have changed. WoW can still re-assert the inherited FontObject
  -- height after our previous SetFont call, so the cache is only valid when
  -- the actual FontString height still matches the requested setting.
  local actualSize
  if type(fontString.GetFont) == "function" then
    local ok, _, height = pcall(fontString.GetFont, fontString)
    if ok and type(height) == "number" then
      actualSize = height
    end
  end
  if fontString._lastFontSize == size and (actualSize == nil or actualSize == size) then
    return
  end
  -- Detach from the FontObject template the FontString inherited from at
  -- creation. Without this the FontObject's `.height` re-asserts itself on
  -- some Blizzard internal refresh paths and our SetFont call is silently
  -- reverted, leaving the slider visually inert.
  if type(fontString.SetFontObject) == "function" then
    pcall(fontString.SetFontObject, fontString, nil)
  end
  local file, flags
  local template = rawget(_G, "GameFontNormalOutline")
  if type(template) == "table" and type(template.GetFont) == "function" then
    local ok, f, _, fl = pcall(template.GetFont, template)
    if ok then
      file, flags = f, fl
    end
  end
  if type(file) ~= "string" or file == "" then
    file = "Fonts\\FRIZQT__.TTF"
  end
  if type(flags) ~= "string" or flags == "" then
    flags = "OUTLINE"
  end
  pcall(fontString.SetFont, fontString, file, size, flags)
  -- Belt-and-suspenders: SetTextHeight pins the rendered height even if
  -- SetFont's size argument is overruled by inherited scaling.
  if type(fontString.SetTextHeight) == "function" then
    pcall(fontString.SetTextHeight, fontString, size)
  end
  fontString._lastFontSize = size
end

local function CreateOrGetFrame(unit)
  local frame = frames[unit]
  if frame then
    return frame
  end
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  local uiParent = rawget(_G, "UIParent")
  local ok, f = pcall(createFrame, "Frame", nil, uiParent)
  if not ok or type(f) ~= "table" then
    return nil
  end
  ApplyFrameSizeForFont(f, ResolveFontSize())
  if f.SetIgnoreParentAlpha then
    f:SetIgnoreParentAlpha(true)
  end
  if type(f.CreateTexture) == "function" then
    f.background = f:CreateTexture(nil, "BACKGROUND")
    if type(f.background.SetAllPoints) == "function" then
      f.background:SetAllPoints(f)
    end
    if type(f.background.SetColorTexture) == "function" then
      f.background:SetColorTexture(
        unpack(
          (type(UICommon) == "table" and UICommon.Colors and UICommon.Colors.SURFACE_COMPACT_OVERLAY)
            or { 0.025, 0.04, 0.06, 0.78 }
        )
      )
    end
  end
  f._isiLiveSurfaceRole = "compact_overlay"
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalOutline")
  f.text:SetPoint("CENTER")
  if f.text.SetTextColor then
    f.text:SetTextColor(
      unpack((type(UICommon) == "table" and UICommon.Colors and UICommon.Colors.TEXT_SECTION) or { 0.64, 0.80, 0.96 })
    )
  end
  if f.text.SetDrawLayer then
    f.text:SetDrawLayer("OVERLAY", 7)
  end
  ApplyFont(f.text)
  frames[unit] = f
  return f
end

local function ApplyTextAnchor(frame, pos)
  if not frame or type(frame.text) ~= "table" then
    return
  end
  local text = frame.text
  if type(text.ClearAllPoints) == "function" then
    text:ClearAllPoints()
  end
  if pos == "RIGHT" then
    text:SetPoint("LEFT", frame, "LEFT", 0, 0)
    if type(text.SetJustifyH) == "function" then
      text:SetJustifyH("LEFT")
    end
  elseif pos == "LEFT" then
    text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    if type(text.SetJustifyH) == "function" then
      text:SetJustifyH("RIGHT")
    end
  else
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    if type(text.SetJustifyH) == "function" then
      text:SetJustifyH("CENTER")
    end
  end
end

local function FrameIsShownOrUnknown(frame)
  if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then
    return true
  end
  local ok, shown = pcall(frame.IsShown, frame)
  return ok and shown ~= false
end

local function GetFrameChildren(frame)
  if type(frame) ~= "table" or type(frame.GetChildren) ~= "function" then
    return nil
  end
  local ok, children = pcall(function()
    return { frame:GetChildren() }
  end)
  if ok and type(children) == "table" then
    return children
  end
  return nil
end

local function ResolvePlatynatorHealthWidget(nameplate)
  local children = GetFrameChildren(nameplate)
  if type(children) ~= "table" then
    return nil
  end

  for _, child in ipairs(children) do
    if type(child) == "table" and type(child.widgets) == "table" then
      for _, widget in ipairs(child.widgets) do
        local details = type(widget) == "table" and widget.details or nil
        if type(details) == "table" and details.kind == "health" and FrameIsShownOrUnknown(widget) then
          return widget
        end
      end
    end
  end

  return nil
end

local function ResolveAnchorTarget(nameplate)
  if type(nameplate) ~= "table" then
    return nil, "missing"
  end

  local platynatorHealthWidget = ResolvePlatynatorHealthWidget(nameplate)
  if platynatorHealthWidget then
    return platynatorHealthWidget, "platynator-health-widget"
  end

  local containers = {
    { frame = nameplate.UnitFrame, source = "UnitFrame" },
    { frame = nameplate.unitFrame, source = "unitFrame" },
    { frame = nameplate, source = "nameplate" },
  }
  local names = {
    "healthBar",
    "HealthBar",
    "healthbar",
  }
  for _, containerInfo in ipairs(containers) do
    local container = containerInfo.frame
    if type(container) == "table" then
      for _, fieldName in ipairs(names) do
        local candidate = container[fieldName]
        if type(candidate) == "table" then
          return candidate, containerInfo.source .. "." .. fieldName
        end
      end
    end
  end

  return nameplate, "nameplate-root"
end

local function ApplyPosition(frame, nameplate)
  if not frame or not nameplate then
    return
  end
  local anchorTarget, anchorSource = ResolveAnchorTarget(nameplate)
  if not anchorTarget then
    return
  end
  frame._isiLiveAnchorSource = anchorSource
  if frame._isiLiveSettingsPreviewOverlay ~= true and type(frame.SetParent) == "function" then
    local uiParent = rawget(_G, "UIParent")
    if type(uiParent) == "table" then
      pcall(frame.SetParent, frame, uiParent)
    end
  end
  local levelSource = type(anchorTarget.GetFrameLevel) == "function" and anchorTarget or nameplate
  local strataSource = type(nameplate.GetFrameStrata) == "function" and nameplate or anchorTarget
  if type(frame.SetFrameStrata) == "function" and type(strataSource.GetFrameStrata) == "function" then
    local okStrata, strata = pcall(strataSource.GetFrameStrata, strataSource)
    if okStrata and type(strata) == "string" and strata ~= "" then
      pcall(frame.SetFrameStrata, frame, strata)
    end
  end
  if type(frame.SetFrameLevel) == "function" and type(levelSource.GetFrameLevel) == "function" then
    local okLevel, level = pcall(levelSource.GetFrameLevel, levelSource)
    if okLevel and type(level) == "number" then
      pcall(frame.SetFrameLevel, frame, level + 20)
    end
  end
  frame:ClearAllPoints()
  local pos = appearance.position or "RIGHT"
  local xo = appearance.xOffset or 0
  local yo = appearance.yOffset or 0
  if pos == "RIGHT" then
    xo = math.max(xo, ANCHOR_GAP)
    frame:SetPoint("LEFT", anchorTarget, "RIGHT", xo, yo)
  elseif pos == "LEFT" then
    xo = math.min(xo, -ANCHOR_GAP)
    frame:SetPoint("RIGHT", anchorTarget, "LEFT", xo, yo)
  elseif pos == "TOP" then
    yo = math.max(yo, ANCHOR_GAP)
    frame:SetPoint("BOTTOM", anchorTarget, "TOP", xo, yo)
  elseif pos == "BOTTOM" then
    yo = math.min(yo, -ANCHOR_GAP)
    frame:SetPoint("TOP", anchorTarget, "BOTTOM", xo, yo)
  else
    frame:SetPoint("CENTER", anchorTarget, "CENTER", xo, yo)
  end
  ApplyTextAnchor(frame, pos)
end

local function UpdateNameplate(unit)
  local frame = frames[unit]

  -- testMode keeps the API/nameplate guards (we still need a real plate to
  -- anchor against and the WoW namplate API to be present) but bypasses the
  -- challenge-mode + forces-DB checks so the slider can be verified outside
  -- a key.
  if enabled == false or not HasNamePlateAPI() then
    if frame then
      frame:Hide()
    end
    return
  end

  if not testMode and not IsChallengeModeActive() then
    if frame then
      frame:Hide()
    end
    return
  end

  if not testMode then
    local seasonData = addonTable.SeasonData
    local hasSeasonForcesGate = type(seasonData) == "table" and type(seasonData.GetMatchingForcesData) == "function"
    if hasSeasonForcesGate and not GetForcesDB() then
      if frame then
        frame:Hide()
      end
      return
    end
  end

  if not IsEligibleUnit(unit) then
    if frame then
      frame:Hide()
    end
    return
  end

  local percentString
  local activeMapID
  if testMode then
    percentString = testPercent
    activeMapID = testActiveMapID
  else
    activeMapID = GetActiveChallengeMapID() -- secret-value-ok: file-local helper is pcall-protected
    -- Primary source: bundled MDT-synced forces DB, which is deterministic and
    -- guaranteed to be the per-mob contribution. Fallback to the Blizzard API
    -- when the NPC is missing from the DB (e.g. freshly added patch mob, OR
    -- the GUID is masked as a Secret Value in 12.0 M+ tainted context).
    --
    -- The API result is passed through even when it is a Secret Value: WoW's
    -- FontString renderer can still display the masked text — only Lua-side
    -- inspection is blocked. Filtering Secret Values out at this point would
    -- leave the nameplate empty in M+ keys.
    percentString = ResolveMobContributionFromDB(unit, activeMapID)
    if not percentString and HasProgressAPI() then
      local api = rawget(_G, "C_ScenarioInfo")
      local _, _, apiPercent = SafeCall(api.GetUnitCriteriaProgressValues, unit)
      if apiPercent ~= nil then
        percentString = apiPercent
      end
    end
  end

  local text = BuildText(percentString, ResolveRemainingPercent(activeMapID))
  if not text then
    if frame then
      frame:Hide()
    end
    return
  end

  local nameplate = GetNameplate(unit)
  if not nameplate then
    if frame then
      frame:Hide()
    end
    return
  end

  frame = CreateOrGetFrame(unit)
  if not frame then
    return
  end

  ApplyPosition(frame, nameplate)
  ApplyFrameSizeForFont(frame, ResolveFontSize())
  ApplyFont(frame.text)
  ApplyRenderedText(frame, text)
  frame:Show()
end

local function HideAll()
  for unit, frame in pairs(frames) do
    if frame and frame.Hide then
      frame:Hide()
    end
    frames[unit] = nil
  end
end

-- Pre-allocated unit tokens for RefreshAll. The Blizzard nameplate roster
-- maxes out at 40, so we know up front which tokens to query. Building these
-- strings every frame ("nameplate" .. i) allocated 40 strings per call;
-- RefreshAll is triggered on every SCENARIO_CRITERIA_UPDATE (i.e. every mob
-- kill in M+) so this matters during AoE pulls.
local NAMEPLATE_UNIT_TOKENS = {}
for i = 1, 40 do
  NAMEPLATE_UNIT_TOKENS[i] = "nameplate" .. i
end

local function RefreshAll()
  for i = 1, 40 do
    UpdateNameplate(NAMEPLATE_UNIT_TOKENS[i])
  end
end

-- Periodic forces changes only affect overlays already discovered through
-- NAME_PLATE_UNIT_ADDED or an explicit full scan. Avoid probing all 40
-- possible unit tokens twice per second during an active key.
local function RefreshActive()
  for unit in pairs(frames) do
    UpdateNameplate(unit)
  end
end

local function ScheduleRefreshAll(delay)
  local timer = rawget(_G, "C_Timer")
  local after = type(timer) == "table" and timer.After or nil
  if type(after) ~= "function" then
    return
  end
  pcall(after, delay, RefreshAll)
end

local function OnEvent(_, event, arg1)
  if event == "NAME_PLATE_UNIT_ADDED" and type(arg1) == "string" then
    UpdateNameplate(arg1)
  elseif event == "NAME_PLATE_UNIT_REMOVED" and type(arg1) == "string" then
    local frame = frames[arg1]
    if frame then
      frame:Hide()
      frames[arg1] = nil
    end
  elseif event == "CHALLENGE_MODE_START" then
    RefreshAll()
    ScheduleRefreshAll(0.25)
    ScheduleRefreshAll(1)
  else
    RefreshAll()
  end
end

local function EnsureEventFrame()
  if eventFrame then
    return eventFrame
  end
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  local ok, f = pcall(createFrame, "Frame")
  if not ok or type(f) ~= "table" then
    return nil
  end
  f:SetScript("OnEvent", OnEvent)
  eventFrame = f
  return f
end

local function RegisterEvents()
  local f = EnsureEventFrame()
  if not f or not f.RegisterEvent then
    return false
  end
  f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
  f:RegisterEvent("CHALLENGE_MODE_START")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("SCENARIO_UPDATE")
  return true
end

local function UnregisterEvents()
  if not eventFrame or not eventFrame.UnregisterAllEvents then
    return
  end
  eventFrame:UnregisterAllEvents()
end

function MobNameplate.SetEnabled(flag)
  -- Named nextEnabled, not next: shadowing the Lua standard `next` inside a
  -- function is a footgun for anyone adding a table walk here later.
  local nextEnabled = flag ~= false
  if nextEnabled == enabled and registered then
    return
  end
  enabled = nextEnabled
  if enabled then
    if RegisterEvents() then
      registered = true
      RefreshAll()
    end
  else
    UnregisterEvents()
    registered = false
    HideAll()
  end
end

function MobNameplate.SetFormat(opts)
  if type(opts) ~= "table" then
    return
  end
  if type(opts.showPercent) == "boolean" then
    format.showPercent = opts.showPercent
  end
  if type(opts.showRemaining) == "boolean" then
    format.showRemaining = opts.showRemaining
  end
  if enabled then
    RefreshAll()
  end
end

function MobNameplate.RefreshAll()
  if enabled then
    RefreshAll()
  end
end

function MobNameplate.RefreshActive()
  if enabled then
    RefreshActive()
  end
end

function MobNameplate.SetAppearance(opts)
  if type(opts) ~= "table" then
    return
  end
  if type(opts.fontSize) == "number" and opts.fontSize > 0 then
    appearance.fontSize = opts.fontSize
  end
  if type(opts.position) == "string" then
    appearance.position = opts.position
  end
  if type(opts.xOffset) == "number" then
    appearance.xOffset = opts.xOffset
  end
  if type(opts.yOffset) == "number" then
    appearance.yOffset = opts.yOffset
  end
  if enabled then
    RefreshAll()
  end
end

function MobNameplate.ApplyPreview(frame, anchor, opts)
  if type(frame) ~= "table" or type(anchor) ~= "table" or type(opts) ~= "table" then
    return nil
  end
  local previewFormat = {
    showPercent = opts.showPercent ~= false,
    showRemaining = opts.showRemaining == true,
  }
  local text = BuildTextForFormat(previewFormat, opts.percentString, opts.remainingPercentString)
  if not text then
    if type(frame.Hide) == "function" then
      frame:Hide()
    end
    return nil
  end

  local previousAppearance = {
    fontSize = appearance.fontSize,
    position = appearance.position,
    xOffset = appearance.xOffset,
    yOffset = appearance.yOffset,
  }
  appearance.fontSize = tonumber(opts.fontSize) or previousAppearance.fontSize
  appearance.position = type(opts.position) == "string" and opts.position or previousAppearance.position
  appearance.xOffset = tonumber(opts.xOffset) or 0
  appearance.yOffset = tonumber(opts.yOffset) or 0

  ApplyPosition(frame, anchor)
  ApplyFrameSizeForFont(frame, ResolveFontSize(), previewFormat.showRemaining)
  ApplyFont(frame.text)
  ApplyRenderedText(frame, text)
  if frame.text and type(frame.text.Show) == "function" then
    frame.text:Show()
  end
  if type(frame.Show) == "function" then
    frame:Show()
  end

  appearance.fontSize = previousAppearance.fontSize
  appearance.position = previousAppearance.position
  appearance.xOffset = previousAppearance.xOffset
  appearance.yOffset = previousAppearance.yOffset

  return text
end

-- Toggle the debug overlay. When `flag` is omitted, the current state is
-- inverted. `percent` is optional and defaults to "1.23" — pass any string
-- (e.g. "42") to control the rendered text. `opts.activeMapID` lets the
-- ingame demo reuse the remaining-percent runtime path against demo KillTrack
-- data without pretending that a live challenge is active.
function MobNameplate.SetTestMode(flag, percent, opts)
  local nextMode
  if flag == nil then
    nextMode = not testMode
  else
    nextMode = flag == true
  end
  testMode = nextMode
  if type(percent) == "string" and percent ~= "" then
    testPercent = percent
  end
  if testMode and type(opts) == "table" and type(opts.activeMapID) == "number" and opts.activeMapID > 0 then
    testActiveMapID = opts.activeMapID
  elseif not testMode then
    testActiveMapID = nil
  end
  if testMode and not enabled then
    MobNameplate.SetEnabled(true)
  elseif enabled then
    if testMode then
      RefreshAll()
    else
      HideAll()
    end
  end
  return testMode
end

function MobNameplate.IsTestMode()
  return testMode
end

-- Inspects every active nameplate frame and returns one row per frame with
-- the actually-rendered font height, text, frame size etc. Used to verify
-- whether the slider value truly hits the FontString in M+ keys (where the
-- per-unit data path is masked but the rendering may still be happening).
function MobNameplate.DumpFrames()
  local rows = {}
  for unit, frame in pairs(frames) do
    local row = { unit = unit }
    if frame and type(frame) == "table" then
      row.frameShown = type(frame.IsShown) == "function" and frame:IsShown() == true or false
      if type(frame.GetSize) == "function" then
        local okSize, w, h = pcall(frame.GetSize, frame)
        if okSize then
          row.frameWidth = w
          row.frameHeight = h
        end
      end
      if frame.text then
        if type(frame.text.GetFont) == "function" then
          local okFont, file, height, flags = pcall(frame.text.GetFont, frame.text)
          if okFont then
            row.fontFile = file
            row.fontHeight = height
            row.fontFlags = flags
          end
        end
        if type(frame.text.GetText) == "function" then
          local okText, txt = pcall(frame.text.GetText, frame.text)
          if okText then
            row.fontStringText = txt
          end
        end
      end
    end
    rows[#rows + 1] = row
  end
  return {
    enabled = enabled,
    testMode = testMode,
    testActiveMapID = testActiveMapID,
    appearanceFontSize = appearance.fontSize,
    frameCount = #rows,
    frames = rows,
  }
end

-- Diagnostic dump for the live data path. `unit` defaults to "target".
-- Returns a table with the resolved values at every gate so a slash command
-- can print why a nameplate text might be missing or off-size in real keys.
function MobNameplate.DumpState(unit)
  unit = type(unit) == "string" and unit ~= "" and unit or "target"

  local out = {
    unit = unit,
    enabled = enabled,
    testMode = testMode,
    testActiveMapID = testActiveMapID,
    appearanceFontSize = appearance.fontSize,
    hasNamePlateAPI = HasNamePlateAPI(),
    hasProgressAPI = HasProgressAPI(),
    challengeActive = IsChallengeModeActive(),
    -- secret-value-ok: file-local helper is pcall-protected.
    activeMapID = testMode and testActiveMapID or GetActiveChallengeMapID(),
    eligible = IsEligibleUnit(unit),
  }

  local unitGUIDFn = rawget(_G, "UnitGUID")
  if out.eligible and type(unitGUIDFn) == "function" then
    local okGuid, guid = pcall(unitGUIDFn, unit)
    if okGuid then
      out.guidIsSecret = IsSecretValue(guid)
      out.guid = out.guidIsSecret and "<secret>" or guid
      out.npcId = NpcIdFromGuid(guid)
    end
  end

  local unitNameFn = rawget(_G, "UnitName")
  if out.eligible and type(unitNameFn) == "function" then
    local okName, name = pcall(unitNameFn, unit)
    if okName then
      out.unitNameSecret = IsSecretValue(name)
      out.unitName = out.unitNameSecret and "<secret>" or name
    end
  end

  local db = GetForcesDB()
  if type(db) == "table" and out.npcId then
    out.dbHasByNpcId = type(db.byNpcId) == "table"
    if type(db.byNpcId) == "table" then
      local entry = db.byNpcId[out.npcId]
      out.dbEntry = entry
      if type(entry) == "table" and out.activeMapID then
        out.dbEntryMatchesMap = entry.mapID == out.activeMapID
      end
    end
    if type(db.dungeonTotal) == "table" and out.activeMapID then
      out.dbDungeonTotal = db.dungeonTotal[out.activeMapID]
    end
  end

  local dbPercent = ResolveMobContributionFromDB(unit, out.activeMapID)
  out.dbPercent = dbPercent

  -- Diagnostic: try the API regardless of eligibility so we can see what it
  -- returns in M+ tainted context. Redact the value if it comes back as a
  -- Secret Value so the resulting line does not get filtered out by chat
  -- copy/paste tools.
  if HasProgressAPI() then
    local api = rawget(_G, "C_ScenarioInfo")
    local _, _, apiPercent = SafeCall(api.GetUnitCriteriaProgressValues, unit)
    out.apiPercentSecret = IsSecretValue(apiPercent)
    out.apiPercent = out.apiPercentSecret and "<secret>" or apiPercent
  end

  local percentString = dbPercent
  if not percentString and out.apiPercent and not out.apiPercentSecret then
    percentString = out.apiPercent
  end
  out.resolvedPercent = percentString
  out.remainingPercent = ResolveRemainingPercent(out.activeMapID)
  out.resolvedText = BuildText(percentString, out.remainingPercent)

  local frame = frames[unit]
  if frame then
    out.frameExists = true
    out.frameShown = frame.IsShown and frame:IsShown() == true or false
    out.anchorSource = frame._isiLiveAnchorSource
    if frame.text then
      if type(frame.text.GetFont) == "function" then
        local okFont, file, height, flags = pcall(frame.text.GetFont, frame.text)
        if okFont then
          out.fontFile = file
          out.fontHeight = height
          out.fontFlags = flags
        end
      end
      if type(frame.text.GetText) == "function" then
        local okText, txt = pcall(frame.text.GetText, frame.text)
        if okText then
          out.fontStringText = txt
        end
      end
    end
  else
    out.frameExists = false
  end

  return out
end

function MobNameplate.Register()
  if registered then
    return true
  end
  if not HasNamePlateAPI() then
    return false
  end
  if not enabled then
    return true
  end
  if RegisterEvents() then
    registered = true
    RefreshAll()
    return true
  end
  return false
end

function MobNameplate._Test_GetFrames()
  return frames
end

function MobNameplate._Test_GetState()
  return {
    enabled = enabled,
    registered = registered,
    format = { showPercent = format.showPercent, showRemaining = format.showRemaining },
    appearance = {
      fontSize = appearance.fontSize,
      position = appearance.position,
      xOffset = appearance.xOffset,
      yOffset = appearance.yOffset,
    },
  }
end

function MobNameplate._Test_UpdateNameplate(unit)
  UpdateNameplate(unit)
end

return MobNameplate
