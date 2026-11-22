local _, addonTable = ...

addonTable = addonTable or {}

-- Defensive estimate for group members without an isiLive state (rule 268,
-- vorhaben V1 stage 2). Isolated exception to the no-guess rules 23/24 (today
-- rule 54): display only, always marked "~", never read back into isiLive
-- logic, announcements or sorting.
--
-- Sensor chain (probe result 2026-11-21, rule 239, archived probe log):
--   * per party member and displayed manifest spell (at most two per member,
--     chosen by class and inspected spec) one invisible AuraContainer
--     (CustomAuraContainerTemplate) on HELPFUL with
--     candidateFilters.includeSpellIDs = { <manifest aura> }. With the aura up
--     Blizzard lays out one frame `sensorStride` wide, so
--     IsMouseOver(<huge vertical reach>) answers "active" wherever the cursor
--     is on the screen. The answer is secret in a key (and mostly outside).
--   * Edge and countdown stay secret: two latch values per sensor hold the
--     cooldown window [start, start + manifest cooldown] encoded as
--     lo = 1 - n(end), hi = 1 - n(start) with n(t) = (t - base) / RANGE in
--     (0, 1). Each tick the rising edge "active now and not active before"
--     picks the candidate window of this tick through
--     C_CurveUtil.EvaluateColorValueFromBoolean(condition, ifTrue, ifFalse),
--     which accepts secret arguments from addon code; the candidates are
--     plain numbers computed before the selection. Lua never compares, adds
--     or tests a sensor value: they are only assigned and handed on.
--   * Display: a StatusBar with SetMinMaxValues(lo, hi) (secret-capable) and
--     SetValue(1 - n(now)) (plain) fills with the remaining share of the
--     estimated cooldown. A secret countdown NUMBER is not possible: Lua
--     arithmetic on the latch is forbidden, and the client APIs that could
--     turn it into seconds (Curve:Evaluate, DurationObject setters,
--     Cooldown:SetCooldown) refuse secret arguments from addon code
--     (SecretArguments = AllowedWhenUntainted, wow-ui-source 12.1.5). The
--     cell therefore shows "~" plus this fill instead of "~<seconds>".
--   * While the buff runs a visible AuraContainer in the cell slot shows it
--     the Blizzard way: aura icon, Blizzard duration text, and a cool blue
--     border whose alpha pulse (0.55 -> 1.0, 1.2 s) Blizzard plays when the
--     aura frame is shown (AddAuraShownAnimation).
--
-- Fail-safe: frames are created and re-filtered out of combat only; in
-- combat a changed member only switches its sensors off. A tick reads only
-- while the cursor is readable and inside the screen (IsMouseOver depends on
-- the cursor); otherwise the tick is skipped and the latches keep their
-- state, so a buff seen only while the cursor was outside the game window is
-- missed (the slot then reads "ready" too early). Never in a raid (rule 11).
-- Missing APIs or a failed container setup switch the estimate off and show
-- up in /isilive selftest (rule 251).
local DefensiveSensors = {}
addonTable.DefensiveSensors = DefensiveSensors

local IsSecretValue = addonTable.Validators.IsSecretValue

local TEMPLATE = "CustomAuraContainerTemplate"
local FILTER_HELPFUL = "HELPFUL"
local SENSOR_GROUP = "isiLiveDefSensor"
local ACTIVE_GROUP = "isiLiveDefActive"
local PARTY_UNITS = { "party1", "party2", "party3", "party4" }
local BORDER_TEXTURE = "Interface\\AddOns\\isiLive\\media\\defensive_border"

local LIMITS = {
  slotsPerUnit = 2,
  -- Frame budget of the V1 plan (< 60). Real use: 8 sensors + 10 cell slots.
  maxContainers = 56,
  tickSeconds = 0.5,
  -- Time encoding range; a session longer than this re-bases (all estimates
  -- restart as "ready").
  timeRangeSeconds = 86400,
}
DefensiveSensors.LIMITS = LIMITS

local GEOMETRY = {
  sensorStride = 60000,
  sensorOffsetX = -16,
  mouseOverReach = 100000,
  activeIcon = 14,
  durationTextOffset = 9,
}
DefensiveSensors.GEOMETRY = GEOMETRY

-- Initial latch: an empty window just below the encoded "now", so the bar
-- shows no remaining cooldown.
local INIT_LO = 1 - 0.5 / LIMITS.timeRangeSeconds
local INIT_HI = 1

local containerCount = 0
local sensors = {} -- [unitIndex][slotIndex] = sensor record
local assignments = {} -- [playerKey] = { unitIndex, unit, slots = { { spellID, auraID, kind, cooldown } } }
local boundBars = {} -- [statusBar] = { playerKey, slotIndex }
local activeByHolder = {} -- [holder frame] = { container, unit, auraID }
local timeBase = nil
local setupFailure = nil
local ticker = nil
local getTimeFn = nil
local readCount = 0

local function Manifest()
  local manifest = addonTable.DefensiveManifest
  return type(manifest) == "table" and type(manifest.list) == "table" and manifest or nil
end

local function ResolveFunction(namespace, name)
  local root = namespace and rawget(_G, namespace) or _G
  if type(root) ~= "table" then
    return nil
  end
  local fn = rawget(root, name)
  return type(fn) == "function" and fn or nil
end

-- object:methodName(...) under pcall: ok, first result.
local function CallMethod(object, methodName, ...)
  if type(object) ~= "table" then
    return false, nil
  end
  local okLookup, method = pcall(function()
    return object[methodName]
  end)
  if not okLookup or type(method) ~= "function" then
    return false, nil
  end
  return pcall(method, object, ...)
end

local function NoteFailure(step, err)
  if setupFailure == nil then
    local text = IsSecretValue(err) and "secret" or tostring(err or "")
    text = text:gsub("^[^:]*:%d+:%s*", "")
    setupFailure = string.format("%s: %s", step, text:sub(1, 80))
  end
end

local function IsInCombat()
  local inCombat = rawget(_G, "InCombatLockdown")
  if type(inCombat) ~= "function" then
    return false
  end
  local ok, value = pcall(inCombat)
  if not ok or IsSecretValue(value) then
    -- Unknown counts as in combat: never build frames on a guess.
    return true
  end
  return value == true
end

local function IsRaid()
  local runtimeMode = addonTable.RuntimeMode
  if type(runtimeMode) ~= "table" or type(runtimeMode.IsRaidContext) ~= "function" then
    return false
  end
  local ok, isRaid = pcall(runtimeMode.IsRaidContext)
  return ok and isRaid == true
end

local function Now()
  if type(getTimeFn) == "function" then
    local ok, value = pcall(getTimeFn)
    if ok and type(value) == "number" and not IsSecretValue(value) then
      return value
    end
  end
  local getTime = rawget(_G, "GetTime")
  if type(getTime) == "function" then
    local ok, value = pcall(getTime)
    if ok and type(value) == "number" and not IsSecretValue(value) then
      return value
    end
  end
  return nil
end

--- True when the client offers every API the sensor chain needs. Read only:
-- nothing is created. Fail-closed after a recorded setup failure.
function DefensiveSensors.IsSupported()
  if setupFailure ~= nil then
    return false
  end
  if not ResolveFunction(nil, "CreateFrame") or not ResolveFunction(nil, "GetCursorPosition") then
    return false
  end
  if not ResolveFunction("C_CurveUtil", "EvaluateColorValueFromBoolean") then
    return false
  end
  local getInfo = ResolveFunction("C_XMLUtil", "GetTemplateInfo")
  if not getInfo then
    return false
  end
  local ok, info = pcall(getInfo, TEMPLATE)
  return ok and not IsSecretValue(info) and info ~= nil
end

--- Selftest view (rule 251): supported flag, the first setup failure and the
-- number of containers created this session.
function DefensiveSensors.GetHealth()
  return { supported = DefensiveSensors.IsSupported(), failure = setupFailure, containers = containerCount }
end

-- Manifest spells a member of `classToken` may have, in display order
-- (external > raid > personal, then manifest order). Spec-bound spells only
-- with a known matching spec.
function DefensiveSensors.GetCandidateSpells(classToken, specID)
  local manifest = Manifest()
  if not manifest or type(classToken) ~= "string" then
    return {}
  end
  local order = type(manifest.kindOrder) == "table" and manifest.kindOrder or {}
  local list = {}
  for index, record in ipairs(manifest.list) do
    local specOk = record.specs == nil
    if not specOk and type(specID) == "number" then
      for _, allowed in ipairs(record.specs) do
        if allowed == specID then
          specOk = true
          break
        end
      end
    end
    if record.class == classToken and specOk and type(record.cast) == "number" then
      list[#list + 1] = {
        spellID = record.cast,
        auraID = record.aura,
        kind = record.kind,
        cooldown = record.cooldown,
        rank = (order[record.kind] or 99) * 1000 + index,
      }
    end
  end
  table.sort(list, function(a, b)
    return a.rank < b.rank
  end)
  return list
end

-- The (at most two) spells a member's estimate shows: candidates with a
-- verified manifest cooldown, in display order.
function DefensiveSensors.SelectSpells(classToken, specID)
  local out = {}
  for _, candidate in ipairs(DefensiveSensors.GetCandidateSpells(classToken, specID)) do
    if type(candidate.cooldown) == "number" and type(candidate.auraID) == "number" then
      out[#out + 1] = candidate
      if #out >= LIMITS.slotsPerUnit then
        break
      end
    end
  end
  return out
end

local function Normalize(t)
  return (t - timeBase) / LIMITS.timeRangeSeconds
end

local function NewLatch()
  return { prev = false, lo = INIT_LO, hi = INIT_HI }
end

local function NewFrame(frameType, parent, template)
  if containerCount >= LIMITS.maxContainers and frameType == "AuraContainer" then
    NoteFailure("budget", "container budget exhausted")
    return nil
  end
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return nil
  end
  local ok, frame = pcall(createFrame, frameType, nil, parent, template)
  if not ok or type(frame) ~= "table" then
    NoteFailure("create", ok and "no frame" or frame)
    return nil
  end
  if frameType == "AuraContainer" then
    containerCount = containerCount + 1
  end
  return frame
end

-- Create, place, add the group, set the unit, enable. `place` sizes and
-- anchors the container before AddAuraGroup, which forbids untrusted layout
-- scripts on it afterwards.
local function BuildContainer(parent, unit, groupKey, options, place)
  local container = NewFrame("AuraContainer", parent, TEMPLATE)
  if not container then
    return nil
  end
  place(container)
  local okGroup, groupErr = CallMethod(container, "AddAuraGroup", groupKey, FILTER_HELPFUL, options)
  if not okGroup then
    NoteFailure("group", groupErr)
    return nil
  end
  local okUnit, unitErr = CallMethod(container, "SetUnit", unit)
  if not okUnit then
    NoteFailure("unit", unitErr)
    return nil
  end
  CallMethod(container, "SetEnabled", true)
  return container
end

local function InitSensorButton(button)
  CallMethod(button, "SetSize", 1, 1)
  CallMethod(button, "EnableMouse", false)
end

local function SensorOptions(auraID)
  return {
    maxFrameCount = 1,
    candidateFilters = { includeSpellIDs = { [auraID] = true } },
    initializeFrame = InitSensorButton,
    layout = { elementWidth = GEOMETRY.sensorStride, elementHeight = 1 },
  }
end

local function DisableSensor(sensor)
  if sensor.container then
    CallMethod(sensor.container, "SetEnabled", false)
  end
  sensor.spellID, sensor.auraID, sensor.cooldown, sensor.playerKey = nil, nil, nil, nil
  sensor.latch = NewLatch()
end

-- Points one sensor at (unit, spell). Out of combat only.
local function ConfigureSensor(unitIndex, slotIndex, unit, playerKey, spell)
  sensors[unitIndex] = sensors[unitIndex] or {}
  local sensor = sensors[unitIndex][slotIndex]
  if not sensor then
    sensor = { latch = NewLatch() }
    sensors[unitIndex][slotIndex] = sensor
  end
  if sensor.playerKey == playerKey and sensor.spellID == spell.spellID and sensor.container then
    return true
  end
  if not sensor.container then
    local uiParent = rawget(_G, "UIParent")
    sensor.container = BuildContainer(uiParent, unit, SENSOR_GROUP, SensorOptions(spell.auraID), function(new)
      CallMethod(new, "SetSize", 1, 1)
      CallMethod(new, "SetPoint", "TOPLEFT", uiParent, "TOPLEFT", GEOMETRY.sensorOffsetX, 0)
      CallMethod(new, "SetAlpha", 0)
      CallMethod(new, "EnableMouse", false)
    end)
    if not sensor.container then
      return false
    end
  else
    local okFilter, filterErr = CallMethod(
      sensor.container,
      "SetAuraGroupCandidateFilters",
      SENSOR_GROUP,
      { includeSpellIDs = { [spell.auraID] = true } }
    )
    if not okFilter then
      NoteFailure("filter", filterErr)
      return false
    end
    CallMethod(sensor.container, "SetUnit", unit)
    CallMethod(sensor.container, "SetEnabled", true)
  end
  sensor.playerKey = playerKey
  sensor.spellID, sensor.auraID, sensor.cooldown = spell.spellID, spell.auraID, spell.cooldown
  sensor.latch = NewLatch()
  return true
end

local function ForEachSensor(callback)
  for unitIndex, slots in pairs(sensors) do
    for slotIndex, sensor in pairs(slots) do
      callback(sensor, unitIndex, slotIndex)
    end
  end
end

local function FindSensor(playerKey, slotIndex)
  local assignment = assignments[playerKey]
  if not assignment then
    return nil
  end
  local slots = sensors[assignment.unitIndex]
  local sensor = slots and slots[slotIndex] or nil
  if sensor and sensor.playerKey == playerKey and sensor.spellID ~= nil then
    return sensor
  end
  return nil
end

local function ResetBar(bar)
  CallMethod(bar, "SetMinMaxValues", INIT_LO, INIT_HI)
  CallMethod(bar, "SetValue", 0)
end

-- Hands the latch to a bound bar: remaining share of the estimated cooldown.
local function PaintBar(bar, sensor, now)
  if timeBase == nil or type(now) ~= "number" then
    ResetBar(bar)
    return
  end
  local latch = sensor.latch
  CallMethod(bar, "SetMinMaxValues", latch.lo, latch.hi)
  CallMethod(bar, "SetValue", 1 - Normalize(now))
end

local function PaintBoundBars(now)
  for bar, binding in pairs(boundBars) do
    local sensor = FindSensor(binding.playerKey, binding.slotIndex)
    if sensor then
      PaintBar(bar, sensor, now)
    else
      ResetBar(bar)
    end
  end
end

-- GetCursorPosition is plain (probe P5); only "in" allows a sensor read.
local function IsCursorOnScreen()
  local getCursor = rawget(_G, "GetCursorPosition")
  if type(getCursor) ~= "function" then
    return false
  end
  local ok, x, y = pcall(getCursor)
  if not ok or IsSecretValue(x) or IsSecretValue(y) or type(x) ~= "number" or type(y) ~= "number" then
    return false
  end
  local uiParent = rawget(_G, "UIParent")
  local okScale, scale = CallMethod(uiParent, "GetEffectiveScale")
  local okWidth, width = CallMethod(uiParent, "GetWidth")
  local okHeight, height = CallMethod(uiParent, "GetHeight")
  if not (okScale and okWidth and okHeight) then
    return false
  end
  if IsSecretValue(scale) or IsSecretValue(width) or IsSecretValue(height) then
    return false
  end
  if type(scale) ~= "number" or type(width) ~= "number" or type(height) ~= "number" or scale <= 0 then
    return false
  end
  local uiX, uiY = x / scale, y / scale
  return uiX >= 0 and uiY >= 0 and uiX <= width and uiY <= height
end

-- Secret-capable select: ok flag plus the chosen value (maybe secret).
local function Select(evaluate, condition, ifTrue, ifFalse)
  return pcall(evaluate, condition, ifTrue, ifFalse)
end

-- One sensor read and latch update. Only assignments and the selection run
-- on the read value; nothing compares or computes with it.
local function ReadSensor(sensor, now, evaluate)
  local reach = GEOMETRY.mouseOverReach
  local okOver, active = CallMethod(sensor.container, "IsMouseOver", reach, -reach, 0, 0)
  if not okOver or type(active) ~= "boolean" then
    return false
  end
  local latch = sensor.latch
  local candidateLo = 1 - Normalize(now + sensor.cooldown)
  local candidateHi = 1 - Normalize(now)
  -- Rising edge: active and not active on the previous read -> this window.
  local okA, edgeLo = Select(evaluate, latch.prev, latch.lo, candidateLo)
  local okB, edgeHi = Select(evaluate, latch.prev, latch.hi, candidateHi)
  if not (okA and okB) then
    return false
  end
  local okC, nextLo = Select(evaluate, active, edgeLo, latch.lo)
  local okD, nextHi = Select(evaluate, active, edgeHi, latch.hi)
  if not (okC and okD) then
    return false
  end
  latch.lo, latch.hi, latch.prev = nextLo, nextHi, active
  return true
end

local function ResetAllLatches()
  ForEachSensor(function(sensor)
    sensor.latch = NewLatch()
  end)
end

--- One pass over every configured sensor (ticker, tests). Skipped without a
-- readable on-screen cursor, in a raid and without the curve API.
function DefensiveSensors.Tick(now)
  now = now or Now()
  if type(now) ~= "number" or next(assignments) == nil then
    return 0
  end
  if IsRaid() then
    DefensiveSensors.Suspend()
    return 0
  end
  local evaluate = ResolveFunction("C_CurveUtil", "EvaluateColorValueFromBoolean")
  if not evaluate then
    return 0
  end
  if timeBase == nil then
    timeBase = now - 1
  end
  local maxCooldown = 0
  ForEachSensor(function(sensor)
    if type(sensor.cooldown) == "number" and sensor.cooldown > maxCooldown then
      maxCooldown = sensor.cooldown
    end
  end)
  if Normalize(now + maxCooldown) >= 1 then
    timeBase = now - 1
    ResetAllLatches()
  end
  local reads = 0
  if IsCursorOnScreen() then
    ForEachSensor(function(sensor)
      if sensor.container and sensor.spellID ~= nil and ReadSensor(sensor, now, evaluate) then
        reads = reads + 1
      end
    end)
  end
  readCount = readCount + reads
  PaintBoundBars(now)
  return reads
end

local function StopTicker()
  if ticker and type(ticker.Cancel) == "function" then
    ticker:Cancel()
  end
  ticker = nil
end

local function EnsureTicker()
  if ticker ~= nil then
    return
  end
  local timerApi = rawget(_G, "C_Timer")
  if type(timerApi) == "table" and type(timerApi.NewTicker) == "function" then
    ticker = timerApi.NewTicker(LIMITS.tickSeconds, function()
      DefensiveSensors.Tick()
    end)
  end
end

--- The clock the ticker reads (the factory passes its getTime).
function DefensiveSensors.SetClock(getTime)
  getTimeFn = type(getTime) == "function" and getTime or nil
end

local function SameSpells(a, b)
  if #a ~= #b then
    return false
  end
  for index, spell in ipairs(a) do
    if b[index].spellID ~= spell.spellID then
      return false
    end
  end
  return true
end

local function DropUnit(unitIndex)
  for _, sensor in pairs(sensors[unitIndex] or {}) do
    DisableSensor(sensor)
  end
end

--- Points the sensors at the group members that need an estimate:
-- members = { { unit = "partyN", playerKey, classToken, specID } }. A member
-- whose name is unreadable right now keeps its previous assignment (pass
-- keep = true). Frames are created and re-filtered only out of combat; in
-- combat a changed member just loses its sensors until the next call out of
-- combat. Returns true when the sensors match the request.
function DefensiveSensors.Configure(members)
  if not DefensiveSensors.IsSupported() or IsRaid() then
    DefensiveSensors.Suspend()
    return false
  end
  local inCombat = IsInCombat()
  local wanted, keepUnits = {}, {}
  for _, member in ipairs(type(members) == "table" and members or {}) do
    local unitIndex = nil
    for index, unit in ipairs(PARTY_UNITS) do
      if unit == member.unit then
        unitIndex = index
      end
    end
    if unitIndex and member.keep == true then
      keepUnits[unitIndex] = true
    elseif unitIndex and type(member.playerKey) == "string" and member.playerKey ~= "" then
      wanted[member.playerKey] = {
        unitIndex = unitIndex,
        unit = member.unit,
        slots = DefensiveSensors.SelectSpells(member.classToken, member.specID),
      }
    end
  end
  local complete = true
  local nextAssignments = {}
  for playerKey, assignment in pairs(assignments) do
    if keepUnits[assignment.unitIndex] then
      nextAssignments[playerKey] = assignment
    end
  end
  for playerKey, want in pairs(wanted) do
    local current = assignments[playerKey]
    local unchanged = current ~= nil
      and current.unitIndex == want.unitIndex
      and SameSpells(current.slots, want.slots)
      and (#want.slots == 0 or FindSensor(playerKey, 1) ~= nil)
    if unchanged then
      nextAssignments[playerKey] = current
    elseif inCombat then
      complete = false
    elseif #want.slots > 0 then
      local ok = true
      for slotIndex, spell in ipairs(want.slots) do
        ok = ConfigureSensor(want.unitIndex, slotIndex, want.unit, playerKey, spell) and ok
      end
      for slotIndex = #want.slots + 1, LIMITS.slotsPerUnit do
        local sensor = sensors[want.unitIndex] and sensors[want.unitIndex][slotIndex]
        if sensor then
          DisableSensor(sensor)
        end
      end
      if ok then
        nextAssignments[playerKey] = want
      else
        complete = false
      end
    end
  end
  -- Units without a (kept) assignment lose their sensors.
  local usedUnits = {}
  for _, assignment in pairs(nextAssignments) do
    usedUnits[assignment.unitIndex] = true
  end
  for unitIndex in pairs(sensors) do
    if not usedUnits[unitIndex] then
      DropUnit(unitIndex)
    end
  end
  assignments = nextAssignments
  if next(assignments) ~= nil then
    EnsureTicker()
  else
    StopTicker()
  end
  return complete and setupFailure == nil
end

--- Switches every sensor and cell container off (feature off, raid, out of
-- the KEY profile). Safe in combat: SetEnabled/Hide are allowed there (probe
-- P3); nothing is created or re-filtered.
function DefensiveSensors.Suspend()
  StopTicker()
  ForEachSensor(function(sensor)
    DisableSensor(sensor)
  end)
  for _, entry in pairs(activeByHolder) do
    entry.attached = nil
    CallMethod(entry.container, "Hide")
    CallMethod(entry.container, "SetEnabled", false)
  end
  for bar in pairs(boundBars) do
    ResetBar(bar)
  end
  boundBars = {}
  assignments = {}
end

--- The estimated slots of a player: { { spellID, auraID, kind, cooldown } }
-- (copies), empty without an assignment. The kind and IDs are plain manifest
-- data; the estimate itself never leaves the widgets.
function DefensiveSensors.GetEstimate(playerKey)
  local assignment = type(playerKey) == "string" and assignments[playerKey] or nil
  local out = {}
  if not assignment then
    return out
  end
  for slotIndex, spell in ipairs(assignment.slots) do
    if FindSensor(playerKey, slotIndex) then
      out[#out + 1] = {
        spellID = spell.spellID,
        auraID = spell.auraID,
        kind = spell.kind,
        cooldown = spell.cooldown,
        slotIndex = slotIndex,
      }
    end
  end
  return out
end

--- Binds a cell StatusBar to the estimate of (playerKey, slotIndex), or
-- unbinds it with playerKey = nil. The bar is painted at once.
function DefensiveSensors.BindBar(bar, playerKey, slotIndex)
  if type(bar) ~= "table" then
    return false
  end
  if playerKey == nil or not FindSensor(playerKey, slotIndex) then
    if boundBars[bar] then
      boundBars[bar] = nil
    end
    ResetBar(bar)
    return false
  end
  boundBars[bar] = { playerKey = playerKey, slotIndex = slotIndex }
  PaintBar(bar, FindSensor(playerKey, slotIndex), Now())
  return true
end

-- Aura frame of the visible cell container: icon, Blizzard duration text
-- right of the icon and the blue border whose pulse Blizzard plays while the
-- aura frame is shown.
local function InitActiveButton(button)
  local size = GEOMETRY.activeIcon
  CallMethod(button, "SetSize", size, size)
  CallMethod(button, "EnableMouse", false)
  local okIcon, icon = CallMethod(button, "CreateTexture", nil, "ARTWORK")
  if okIcon and type(icon) == "table" then
    CallMethod(icon, "SetAllPoints", button)
    CallMethod(icon, "SetTexCoord", 0.08, 0.92, 0.08, 0.92)
    CallMethod(button, "SetIcon", icon)
  end
  local okBorder, border = CallMethod(button, "CreateTexture", nil, "OVERLAY")
  if okBorder and type(border) == "table" then
    CallMethod(border, "SetTexture", BORDER_TEXTURE)
    CallMethod(border, "SetPoint", "TOPLEFT", button, "TOPLEFT", -1, 1)
    CallMethod(border, "SetPoint", "BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    CallMethod(border, "SetVertexColor", 0.35, 0.7, 1, 1)
    CallMethod(border, "SetBlendMode", "ADD")
    local okGroup, pulse = CallMethod(border, "CreateAnimationGroup")
    if okGroup and type(pulse) == "table" then
      CallMethod(pulse, "SetLooping", "BOUNCE")
      local okAlpha, alpha = CallMethod(pulse, "CreateAnimation", "Alpha")
      if okAlpha and type(alpha) == "table" then
        CallMethod(alpha, "SetFromAlpha", 0.55)
        CallMethod(alpha, "SetToAlpha", 1)
        CallMethod(alpha, "SetDuration", 1.2)
      end
      CallMethod(button, "AddAuraShownAnimation", pulse)
    end
  end
  local okText, text = CallMethod(button, "CreateFontString", nil, "OVERLAY", "GameFontHighlightSmall")
  if okText and type(text) == "table" then
    CallMethod(text, "SetPoint", "LEFT", button, "RIGHT", GEOMETRY.durationTextOffset, 0)
    CallMethod(text, "SetTextColor", 0.55, 0.82, 1, 1)
    CallMethod(button, "SetDurationText", text, {})
  end
end

local function ActiveOptions(auraID)
  return {
    maxFrameCount = 1,
    candidateFilters = { includeSpellIDs = { [auraID] = true } },
    initializeFrame = InitActiveButton,
    layout = { elementWidth = GEOMETRY.activeIcon, elementHeight = GEOMETRY.activeIcon },
  }
end

--- Hides the visible container of a cell slot holder (safe in combat).
function DefensiveSensors.DetachActive(holder)
  local entry = type(holder) == "table" and activeByHolder[holder] or nil
  if entry and entry.attached ~= nil then
    entry.attached = nil
    CallMethod(entry.container, "Hide")
    CallMethod(entry.container, "SetEnabled", false)
  end
end

--- Shows the buff of (playerKey, slotIndex) in a cell slot holder through a
-- visible Blizzard container. Created and re-filtered out of combat only; in
-- combat a holder whose unit or spell changed stays hidden. Returns true when
-- the container shows the requested aura.
function DefensiveSensors.AttachActive(holder, playerKey, slotIndex)
  local assignment = type(playerKey) == "string" and assignments[playerKey] or nil
  local spell = assignment and assignment.slots[slotIndex] or nil
  if type(holder) ~= "table" or not spell or not FindSensor(playerKey, slotIndex) then
    DefensiveSensors.DetachActive(holder)
    return false
  end
  local entry = activeByHolder[holder]
  local attachKey = playerKey .. "#" .. tostring(slotIndex)
  if entry and entry.attached == attachKey and entry.unit == assignment.unit and entry.auraID == spell.auraID then
    return true
  end
  if not entry then
    if IsInCombat() then
      return false
    end
    local container = BuildContainer(holder, assignment.unit, ACTIVE_GROUP, ActiveOptions(spell.auraID), function(new)
      CallMethod(new, "SetSize", GEOMETRY.activeIcon, GEOMETRY.activeIcon)
      CallMethod(new, "SetPoint", "TOPLEFT", holder, "TOPLEFT", 0, 0)
      CallMethod(new, "EnableMouse", false)
      -- Above the cell's estimate fill, so the running buff covers it.
      local okLevel, level = CallMethod(holder, "GetFrameLevel")
      if okLevel and type(level) == "number" then
        CallMethod(new, "SetFrameLevel", level + 5)
      end
    end)
    if not container then
      return false
    end
    entry = { container = container, unit = assignment.unit, auraID = spell.auraID }
    activeByHolder[holder] = entry
  elseif entry.unit ~= assignment.unit or entry.auraID ~= spell.auraID then
    if IsInCombat() then
      DefensiveSensors.DetachActive(holder)
      return false
    end
    local okFilter, filterErr = CallMethod(
      entry.container,
      "SetAuraGroupCandidateFilters",
      ACTIVE_GROUP,
      { includeSpellIDs = { [spell.auraID] = true } }
    )
    if not okFilter then
      NoteFailure("filter", filterErr)
      DefensiveSensors.DetachActive(holder)
      return false
    end
    CallMethod(entry.container, "SetUnit", assignment.unit)
    entry.unit, entry.auraID = assignment.unit, spell.auraID
  end
  CallMethod(entry.container, "SetEnabled", true)
  CallMethod(entry.container, "Show")
  entry.attached = attachKey
  return true
end

--- Number of AuraContainers created this session (budget, tests).
function DefensiveSensors.GetContainerCount()
  return containerCount
end

--- Successful sensor reads this session (tests, diagnostics; a count of
-- reads, never of answers).
function DefensiveSensors.GetReadCount()
  return readCount
end
