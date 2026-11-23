local _, addonTable = ...

addonTable = addonTable or {}

-- Defensive estimate for group members inside a key (rule 268, vorhaben V1).
-- Isolated exception to the no-guess rules 23/24 (today rule 54): display
-- only, always marked "~", never read back into isiLive logic, announcements
-- or sorting.
--
-- Sensor chain (probe result 2026-11-21, rule 239, archived probe log):
--   * per member up to five manifest spells (LIMITS.slotsPerUnit). A personal spell is watched on
--     the caster; an external or group cooldown on all five possible targets
--     (player, party1..4), and only while exactly one group member can cast
--     it, otherwise the slot says "?" and has no sensor. One invisible
--     AuraContainer (CustomAuraContainerTemplate, includeSpellIDs) per
--     target: with the aura up Blizzard lays out one frame `sensorStride`
--     wide, so IsMouseOver(<huge vertical reach>) answers "active" wherever
--     the cursor is on the screen. The answer is secret in a key.
--   * Time: C_CurveUtil.EvaluateColorValueFromBoolean takes and returns a
--     color value, so it keeps only 255 steps (researched 2026-11-22, not
--     measured in game). Each spell therefore keeps one byte: the buff start
--     in steps of `step` seconds from a window epoch, 0 = none. Two windows
--     half a window apart are both written; the older one is shown and
--     always holds every cast of the last cooldown length. Each tick the
--     rising edge on any target selects the plain code of this tick; Lua
--     never compares, adds or tests a sensor value.
--   * Display: StatusBar:SetMinMaxValues gets plain bounds, SetValue the
--     (maybe secret) byte; the fill is the remaining share of the estimated
--     cooldown, exact to one step (1 to 3 s).
--   * An isiLive user's synced list names the spells; while the sync is live
--     its cooldown also seeds the byte (plain numbers), so the estimate
--     starts the key with the shared state.
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
local GROUP_TARGETS = { "player", "party1", "party2", "party3", "party4" }
local BORDER_TEXTURE = "Interface\\AddOns\\isiLive\\media\\defensive_border"

local LIMITS = {
  -- The most defensives one spec has in the manifest (Holy and Protection
  -- Paladin); the cell shows all of them.
  slotsPerUnit = 5,
  -- Own frame budget; Blizzard_CustomAuraContainer sets no limit on the
  -- number of containers. Worst case: 4 members x (3 group spells x 5
  -- targets + 2 personal) = 68 sensors + 5 rows x 5 cell slots = 93. A slot
  -- without a free container reads "?" (`untracked`), the rest keeps working.
  maxContainers = 100,
  tickSeconds = 0.5,
  -- One byte: code 0 = no cast, 1..254 = steps from the window epoch.
  byteSteps = 255,
  lastCode = 254,
  halfWindowSteps = 127,
}
DefensiveSensors.LIMITS = LIMITS

local GEOMETRY = {
  sensorStride = 60000,
  sensorOffsetX = -16,
  mouseOverReach = 100000,
  activeIcon = 14,
}
DefensiveSensors.GEOMETRY = GEOMETRY

local containerCount = 0
local sensors = {} -- [unitIndex][slotIndex] = sensor record
local assignments = {} -- [playerKey] = { unitIndex, unit, slots = { { spellID, auraID, kind, cooldown } } }
local boundBars = {} -- [statusBar] = { playerKey, slotIndex }
local activeByHolder = {} -- [holder frame] = { container, unit, auraID }
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

local function Contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end
  return false
end

-- A member's candidates: exactly the synced list, or class and spec minus
-- the talents the inspect shows as not taken. A talent spell without a
-- readable inspect is `unverified`.
local function CandidatesOf(classToken, specID, knownSpells, talents)
  local manifest = Manifest()
  if not manifest then
    return {}
  end
  if type(knownSpells) ~= "table" then
    local out = {}
    for _, candidate in ipairs(DefensiveSensors.GetCandidateSpells(classToken, specID)) do
      local record = manifest.spells[candidate.spellID]
      if not (record and record.talent) then
        out[#out + 1] = candidate
      elseif type(talents) ~= "table" then
        candidate.unverified = true
        out[#out + 1] = candidate
      elseif talents[candidate.spellID] == true then
        out[#out + 1] = candidate
      end
    end
    return out
  end
  local order = type(manifest.kindOrder) == "table" and manifest.kindOrder or {}
  local list = {}
  for index, record in ipairs(manifest.list) do
    if Contains(knownSpells, record.cast) then
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

-- The (at most five) spells a member's estimate shows: candidates with a
-- verified manifest cooldown, in display order.
function DefensiveSensors.SelectSpells(classToken, specID, knownSpells, talents)
  local out = {}
  for _, candidate in ipairs(CandidatesOf(classToken, specID, knownSpells, talents)) do
    if type(candidate.cooldown) == "number" and type(candidate.auraID) == "number" then
      out[#out + 1] = candidate
      if #out >= LIMITS.slotsPerUnit then
        break
      end
    end
  end
  return out
end

-- Whether this caster may have the spell. An unknown class or spec may.
local function CanCast(caster, record)
  if type(caster.knownSpells) == "table" then
    return Contains(caster.knownSpells, record.cast)
  end
  if caster.classToken == nil then
    return true
  end
  if caster.classToken ~= record.class then
    return false
  end
  if record.talent and type(caster.talents) == "table" and caster.talents[record.cast] ~= true then
    return false
  end
  return record.specs == nil or type(caster.specID) ~= "number" or Contains(record.specs, caster.specID)
end

-- A buff on a target does not name its caster: only a single possible caster
-- gets an external or group cooldown credited.
local function HasSeveralCasters(casters, spell)
  if spell.kind == "personal" then
    return false
  end
  local manifest = Manifest()
  for _, record in ipairs(manifest and manifest.list or {}) do
    if record.cast == spell.spellID then
      local count = 0
      for _, caster in ipairs(casters) do
        if CanCast(caster, record) then
          count = count + 1
        end
      end
      return count > 1
    end
  end
  return true
end

-- Seconds per code: half a window covers the cooldown plus two steps.
local function StepSeconds(cooldown)
  return math.max(1, math.ceil(cooldown / (LIMITS.halfWindowSteps - 2)))
end

local function NewLatch()
  return { prev = {} }
end

-- The two windows at `now`, oldest first.
local function AdvanceWindows(latch, cooldown, now)
  local step = StepSeconds(cooldown)
  local half = LIMITS.halfWindowSteps * step
  local windows = latch.windows
  if windows and now - windows[2].epoch >= 2 * half then
    windows = nil
  end
  if not windows then
    latch.step = step
    latch.windows = { { epoch = now - half, value = 0 }, { epoch = now, value = 0 } }
    return
  end
  if now - windows[1].epoch >= 2 * half then
    windows[1], windows[2] = windows[2], { epoch = windows[1].epoch + 2 * half, value = 0 }
  end
end

local function EncodeStart(window, step, start)
  local code = math.floor((start - window.epoch) / step + 0.5) + 1
  return math.max(1, math.min(LIMITS.lastCode, code)) / LIMITS.byteSteps
end

-- The plain state of a live sync: `readyIn` seconds at `now`.
local function SeedLatch(sensor, readyIn, now)
  local latch = sensor.latch
  AdvanceWindows(latch, sensor.cooldown, now)
  local start = now + math.min(readyIn, sensor.cooldown) - sensor.cooldown
  for _, window in ipairs(latch.windows) do
    local holds = readyIn > 0 and start > window.epoch - latch.step
    window.value = holds and EncodeStart(window, latch.step, start) or 0
  end
end

-- Out of budget is no setup failure: the caller leaves that slot out.
local function NewFrame(frameType, parent, template)
  if containerCount >= LIMITS.maxContainers and frameType == "AuraContainer" then
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
  for _, container in pairs(sensor.containers) do
    CallMethod(container, "SetEnabled", false)
  end
  sensor.targetCount = 0
  sensor.spellID, sensor.auraID, sensor.cooldown, sensor.playerKey, sensor.unit = nil, nil, nil, nil, nil
  sensor.latch = NewLatch()
end

-- Points one sensor at (caster, spell) and its targets. Out of combat only.
local function ConfigureSensor(unitIndex, slotIndex, unit, playerKey, spell)
  sensors[unitIndex] = sensors[unitIndex] or {}
  local sensor = sensors[unitIndex][slotIndex]
  if not sensor then
    sensor = { containers = {}, targetCount = 0, latch = NewLatch() }
    sensors[unitIndex][slotIndex] = sensor
  end
  if spell.ambiguous or spell.unverified then
    DisableSensor(sensor)
    return true
  end
  if sensor.playerKey == playerKey and sensor.spellID == spell.spellID and sensor.unit == unit then
    return true
  end
  local targets = spell.kind == "personal" and { unit } or GROUP_TARGETS
  if containerCount + math.max(0, #targets - #sensor.containers) > LIMITS.maxContainers then
    spell.untracked = true
    DisableSensor(sensor)
    return true
  end
  for index, target in ipairs(targets) do
    local container = sensor.containers[index]
    if not container then
      local uiParent = rawget(_G, "UIParent")
      container = BuildContainer(uiParent, target, SENSOR_GROUP, SensorOptions(spell.auraID), function(new)
        CallMethod(new, "SetSize", 1, 1)
        CallMethod(new, "SetPoint", "TOPLEFT", uiParent, "TOPLEFT", GEOMETRY.sensorOffsetX, 0)
        CallMethod(new, "SetAlpha", 0)
        CallMethod(new, "EnableMouse", false)
      end)
      if not container then
        DisableSensor(sensor)
        return false
      end
      sensor.containers[index] = container
    else
      local okFilter, filterErr = CallMethod(
        container,
        "SetAuraGroupCandidateFilters",
        SENSOR_GROUP,
        { includeSpellIDs = { [spell.auraID] = true } }
      )
      if not okFilter then
        NoteFailure("filter", filterErr)
        DisableSensor(sensor)
        return false
      end
      CallMethod(container, "SetUnit", target)
      CallMethod(container, "SetEnabled", true)
    end
  end
  for index = #targets + 1, #sensor.containers do
    CallMethod(sensor.containers[index], "SetEnabled", false)
  end
  sensor.targetCount = #targets
  sensor.playerKey, sensor.unit = playerKey, unit
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
  CallMethod(bar, "SetMinMaxValues", 0, 1)
  CallMethod(bar, "SetValue", 0)
end

-- Hands the older window to a bound bar: plain bounds, the byte as the value.
-- A bound number strip gets the byte too, with the plain step "now".
local function PaintBar(bar, sensor, now, strip)
  local latch = sensor.latch
  if latch.windows == nil or type(now) ~= "number" then
    ResetBar(bar)
    if strip then
      CallMethod(strip, "Clear")
    end
    return
  end
  local shown = latch.windows[1]
  local high = ((now - shown.epoch) / latch.step + 1) / LIMITS.byteSteps
  local low = high - sensor.cooldown / latch.step / LIMITS.byteSteps
  CallMethod(bar, "SetMinMaxValues", low, high)
  CallMethod(bar, "SetValue", shown.value)
  if strip then
    local nowStep = math.floor((now - shown.epoch) / latch.step + 0.5)
    CallMethod(strip, "Paint", shown.value, nowStep, math.ceil(sensor.cooldown / latch.step), latch.step)
  end
end

local function PaintBoundBars(now)
  for bar, binding in pairs(boundBars) do
    local sensor = FindSensor(binding.playerKey, binding.slotIndex)
    if sensor then
      PaintBar(bar, sensor, now, binding.strip)
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

-- One sensor read and latch update over every possible target. Only
-- assignments and the selection run on the read values; nothing compares or
-- computes with them. A failed read keeps the windows as they were.
local function ReadSensor(sensor, now, evaluate)
  local reach = GEOMETRY.mouseOverReach
  local latch = sensor.latch
  local active = {}
  for index = 1, sensor.targetCount do
    local okOver, answer = CallMethod(sensor.containers[index], "IsMouseOver", reach, -reach, 0, 0)
    if not okOver or type(answer) ~= "boolean" then
      return false
    end
    active[index] = answer
  end
  local selected = {}
  for windowIndex, window in ipairs(latch.windows) do
    local candidate = EncodeStart(window, latch.step, now)
    local value = window.value
    for index = 1, sensor.targetCount do
      local before = latch.prev[index]
      if type(before) ~= "boolean" then
        before = false
      end
      -- Rising edge on this target -> this tick's code.
      local okEdge, onEdge = Select(evaluate, before, value, candidate)
      if not okEdge then
        return false
      end
      local okNext, following = Select(evaluate, active[index], onEdge, value)
      if not okNext then
        return false
      end
      value = following
    end
    selected[windowIndex] = value
  end
  for windowIndex, window in ipairs(latch.windows) do
    window.value = selected[windowIndex]
  end
  latch.prev = active
  return true
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
  ForEachSensor(function(sensor)
    if sensor.spellID ~= nil then
      AdvanceWindows(sensor.latch, sensor.cooldown, now)
    end
  end)
  local reads = 0
  if IsCursorOnScreen() then
    ForEachSensor(function(sensor)
      if sensor.spellID ~= nil and ReadSensor(sensor, now, evaluate) then
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
    local other = b[index]
    if other.spellID ~= spell.spellID or other.ambiguous ~= spell.ambiguous or other.unverified ~= spell.unverified then
      return false
    end
  end
  return true
end

local function HasItsSensors(playerKey, slots)
  for index, spell in ipairs(slots) do
    if not (spell.ambiguous or spell.unverified or spell.untracked) and FindSensor(playerKey, index) == nil then
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

--- Points the sensors at the group members:
-- members = { { unit = "partyN", playerKey, classToken, specID,
--               knownSpells = synced cast IDs | nil,
--               talents = { [castID] = true|false } | nil (inspect),
--               readyIn = { [castID] = seconds } | nil (live sync only) } }.
-- player = { knownSpells } counts as a possible caster. A member whose name
-- is unreadable right now keeps its previous assignment (pass keep = true).
-- Frames are created and re-filtered only out of combat; in combat a changed
-- member just loses its sensors until the next call out of combat. Returns
-- true when the sensors match the request.
function DefensiveSensors.Configure(members, player)
  if not DefensiveSensors.IsSupported() or IsRaid() then
    DefensiveSensors.Suspend()
    return false
  end
  local inCombat = IsInCombat()
  local wanted, keepUnits = {}, {}
  local casters = { type(player) == "table" and player or {} }
  for _, member in ipairs(type(members) == "table" and members or {}) do
    local unitIndex = nil
    for index, unit in ipairs(PARTY_UNITS) do
      if unit == member.unit then
        unitIndex = index
      end
    end
    if unitIndex and member.keep == true then
      keepUnits[unitIndex] = true
      local previous = {}
      for _, assignment in pairs(assignments) do
        if assignment.unitIndex == unitIndex then
          previous = assignment
        end
      end
      casters[#casters + 1] = previous
    elseif unitIndex and type(member.playerKey) == "string" and member.playerKey ~= "" then
      casters[#casters + 1] = member
      wanted[member.playerKey] = {
        unitIndex = unitIndex,
        unit = member.unit,
        classToken = member.classToken,
        specID = member.specID,
        knownSpells = member.knownSpells,
        talents = member.talents,
        readyIn = member.readyIn,
        slots = DefensiveSensors.SelectSpells(member.classToken, member.specID, member.knownSpells, member.talents),
      }
    end
  end
  for _, want in pairs(wanted) do
    for _, spell in ipairs(want.slots) do
      spell.ambiguous = HasSeveralCasters(casters, spell)
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
      and HasItsSensors(playerKey, current.slots)
    if unchanged then
      current.classToken, current.specID = want.classToken, want.specID
      current.knownSpells, current.readyIn = want.knownSpells, want.readyIn
      current.talents = want.talents
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
  local now = Now()
  for playerKey, assignment in pairs(assignments) do
    if assignment.readyIn and now then
      for slotIndex, spell in ipairs(assignment.slots) do
        local sensor = FindSensor(playerKey, slotIndex)
        local readyIn = assignment.readyIn[spell.spellID]
        if sensor and type(readyIn) == "number" and not IsSecretValue(readyIn) then
          SeedLatch(sensor, readyIn, now)
        end
      end
    end
  end
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

--- The estimated slots of a player: { { spellID, auraID, kind, cooldown,
-- ambiguous, unverified, untracked, slotIndex } }
-- (copies), empty without an assignment. The kind and IDs are plain manifest
-- data; the estimate itself never leaves the widgets.
function DefensiveSensors.GetEstimate(playerKey)
  local assignment = type(playerKey) == "string" and assignments[playerKey] or nil
  local out = {}
  if not assignment then
    return out
  end
  for slotIndex, spell in ipairs(assignment.slots) do
    if spell.ambiguous or spell.unverified or spell.untracked or FindSensor(playerKey, slotIndex) then
      out[#out + 1] = {
        unverified = spell.unverified == true or nil,
        ambiguous = spell.ambiguous == true or nil,
        untracked = spell.untracked == true or nil,
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

--- Every defensive the estimate knows of a player (tooltip): the synced
-- list, else class and spec.
function DefensiveSensors.GetPlayerCandidates(playerKey, classToken, specID)
  local assignment = type(playerKey) == "string" and assignments[playerKey] or nil
  if not assignment then
    return CandidatesOf(classToken, specID)
  end
  return CandidatesOf(classToken, specID, assignment.knownSpells, assignment.talents)
end

--- Binds a cell StatusBar (and its number strip, `strip` with Paint and
-- Clear) to the estimate of (playerKey, slotIndex), or
-- unbinds it with playerKey = nil. The bar is painted at once.
function DefensiveSensors.BindBar(bar, playerKey, slotIndex, strip)
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
  boundBars[bar] = { playerKey = playerKey, slotIndex = slotIndex, strip = strip }
  PaintBar(bar, FindSensor(playerKey, slotIndex), Now(), strip)
  return true
end

-- Same font as the numbers of the cell (outlined, with a fallback).
local function IconFont()
  local cell = addonTable.RosterDefensiveCell
  if type(cell) == "table" and type(cell.ResolveIconFont) == "function" then
    return cell.ResolveIconFont()
  end
  return "GameFontHighlightSmall"
end

-- Aura frame of the visible cell container: icon, Blizzard duration text
-- on the icon and the blue border whose pulse Blizzard plays while the
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
  local okText, text = CallMethod(button, "CreateFontString", nil, "OVERLAY", IconFont())
  if okText and type(text) == "table" then
    CallMethod(text, "SetPoint", "CENTER", button, "CENTER", 0, 0)
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
