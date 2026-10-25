local _, addonTable = ...

addonTable = addonTable or {}

-- Time to kill (TTK) of the current target in an active M+ key.
--
-- Enemy health is a Secret Value in keys: Lua may not compare or compute with
-- it. The estimate therefore never leaves Blizzard's side:
--   TTK = t * p / (1 - p) - d
-- p = remaining health share (secret), t = plain seconds from the mob's clock
-- start to its last health change, d = plain seconds since that change. The
-- health share only moves on hits, so the rate is measured at the last hit and
-- the estimate counts down evenly in between instead of creeping up until the
-- next hit (saw-tooth). The formula is written into a Curve rebuilt from the
-- plain t and d on every update; UnitHealthPercent(unit, false, curve)
-- evaluates it with the secret, unpredicted health and the FontString
-- displays the secret result through SetFormattedText. Lua never reads,
-- compares or computes with p or the TTK.
--
-- Clocks (all plain GetTime() values):
--   boss       -- ENCOUNTER_START, for a target that is a boss unit
--   nameplate  -- the first UNIT_HEALTH of that nameplate in combat, i.e. the
--                 mob's first damage; recycled tokens restart it
--   combat     -- PLAYER_REGEN_DISABLED, when the mob has no own clock yet
local TTK = {}
addonTable.TTK = TTK

-- Two updates a second: the even countdown needs no more.
local UPDATE_SECONDS = 0.5
-- Below this the rate estimate is noise; the display shows a placeholder.
local MIN_ELAPSED = 3
local CAP_SECONDS = 999
-- Sample points of p; dense near 1, where t * p / (1 - p) bends hard.
local SAMPLES = { 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.92, 0.94, 0.96, 0.97, 0.98 }
local BOSS_UNITS = { "boss1", "boss2", "boss3", "boss4", "boss5" }
local MAX_NAMEPLATES = 40
local PLATE_TOKENS = {}
for i = 1, MAX_NAMEPLATES do
  PLATE_TOKENS[i] = "nameplate" .. i
end

local IsSecretValue = addonTable.Validators.IsSecretValue

local state = {
  inCombat = false,
  combatStart = nil,
  encounterStart = nil,
  plateClock = {},
  -- Last health change per nameplate token and for the "target" unit.
  lastHit = {},
  targetLastHit = nil,
  -- Visible nameplate tokens and the one showing the target. Resolved
  -- lazily after a target or nameplate change, not on every tick.
  plates = {},
  targetToken = nil,
  targetDirty = true,
}

-- Optional runtime-log sink: one line whenever the reason the TTK shows (or
-- does not show) changes, at most TRACE_MAX_PER_FIGHT per fight.
local TRACE_MAX_PER_FIGHT = 12
local traceFn = nil
local traceActive = nil
local traceCount = 0
local lastTraceKey = nil
local displays = {}
-- Diagnostics sink, defined with the trace below; declared early for callers above it.
local DebugNote
local ticker = nil
local eventFrame = nil
-- Refreshed on lifecycle edges, never queried on the UNIT_HEALTH hot path.
local raidBlocked = false

local function Now()
  local getTime = rawget(_G, "GetTime")
  return type(getTime) == "function" and getTime() or 0
end

local function GetDB()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db or nil
end

-- Display toggle (default on).
function TTK.IsEnabled()
  local db = GetDB()
  return not db or db.ttkEnabled ~= false
end

-- Session-only test mode (/isilive ttktest): the TTK runs in every fight, so
-- it can be checked on a training dummy. Never persisted.
local testMode = false
-- Sample value shown above the target's nameplate in test mode outside
-- combat, so position and look can be checked on any target.
local PREVIEW_SECONDS = 12

local function IsKeyActive()
  if testMode then
    return true
  end
  local timer = addonTable.MplusTimer
  return type(timer) == "table" and type(timer.IsRunning) == "function" and timer.IsRunning() == true
end

-- Plain boolean from a unit query, false when missing or answering secret.
-- Called directly: these queries take only fixed unit tokens and do not
-- raise, and the 4 Hz ticker must stay inside the key's pcall budget.
local function PlainTrue(fn, ...)
  if type(fn) ~= "function" then
    return false
  end
  local value = fn(...)
  return not IsSecretValue(value) and value == true
end

--- Curve points: p -> clamp(t * p / (1 - p) - d, 0, cap).
-- @param elapsedAtHit number t, seconds from the clock start to the last hit
-- @param sinceHit number|nil d, seconds since the last hit (default 0)
-- Pure; exposed for tests.
function TTK.BuildPoints(elapsedAtHit, sinceHit)
  local since = sinceHit or 0
  local points = {}
  for i = 1, #SAMPLES do
    local p = SAMPLES[i]
    local seconds = math.min(CAP_SECONDS, elapsedAtHit * p / (1 - p))
    points[i] = { p, math.max(0, seconds - since) }
  end
  points[#points + 1] = { 0.99, CAP_SECONDS }
  points[#points + 1] = { 1, CAP_SECONDS }
  return points
end

local function IsBossTarget()
  local unitIsUnit = rawget(_G, "UnitIsUnit")
  for i = 1, #BOSS_UNITS do
    if PlainTrue(unitIsUnit, "target", BOSS_UNITS[i]) then
      return true
    end
  end
  return false
end

local function PlainToken(token)
  if not IsSecretValue(token) and type(token) == "string" and token ~= "" then
    return token
  end
  return nil
end

-- The target's nameplate token. GetNamePlateForUnit("target") may come back
-- empty in a key, so the visible plates are matched with UnitIsUnit, which
-- stays plain there (nameplate addons compare it directly).
local function ResolveTargetToken()
  if not state.targetDirty then
    return state.targetToken
  end
  state.targetDirty = false
  state.targetToken = nil
  local api = rawget(_G, "C_NamePlate")
  if type(api) == "table" and type(api.GetNamePlateForUnit) == "function" then
    local plate = api.GetNamePlateForUnit("target")
    state.targetToken = type(plate) == "table" and PlainToken(plate.namePlateUnitToken) or nil
  end
  if not state.targetToken then
    local unitIsUnit = rawget(_G, "UnitIsUnit")
    for token in pairs(state.plates) do
      if PlainTrue(unitIsUnit, "target", token) then
        state.targetToken = token
        break
      end
    end
  end
  if not state.targetToken then
    -- Plates already visible before the event frame existed never sent
    -- NAME_PLATE_UNIT_ADDED: scan the fixed tokens like the forces overlay's
    -- full scan does. Runs only after a target or nameplate change.
    local unitIsUnit = rawget(_G, "UnitIsUnit")
    for i = 1, MAX_NAMEPLATES do
      local token = PLATE_TOKENS[i]
      if PlainTrue(unitIsUnit, "target", token) then
        state.targetToken = token
        state.plates[token] = true
        break
      end
    end
  end
  return state.targetToken
end

--- Nameplate token of the current target, or nil.
function TTK.GetTargetPlateToken()
  return ResolveTargetToken()
end

--- Time of the target's last health change in this fight, or nil.
function TTK.GetTargetLastHit()
  local token = state.inCombat and ResolveTargetToken() or nil
  local plateHit = token and state.lastHit[token] or nil
  local unitHit = state.targetLastHit
  if plateHit and unitHit then
    return math.max(plateHit, unitHit)
  end
  return plateHit or unitHit
end

--- Clock start for the current target, or nil (see the clock list above).
function TTK.GetTargetClock()
  if not state.inCombat then
    return nil
  end
  if state.encounterStart and IsBossTarget() then
    return state.encounterStart
  end
  local token = ResolveTargetToken()
  local start = token and state.plateClock[token] or nil
  return start or state.combatStart
end

local function IsTargetAlive()
  local unitIsDead = rawget(_G, "UnitIsDead")
  if type(unitIsDead) ~= "function" then
    return false
  end
  local dead = unitIsDead("target")
  return not IsSecretValue(dead)
    and dead == false
    and PlainTrue(rawget(_G, "UnitExists"), "target")
    and PlainTrue(rawget(_G, "UnitCanAttack"), "player", "target")
end

-- Plain value of a unit query, nil when missing or secret.
local function PlainValue(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local value = fn(...)
  if IsSecretValue(value) then
    return nil
  end
  return value
end

--- Setting (default on): show the TTK only for important enemies.
function TTK.IsImportantOnly()
  local db = GetDB()
  return not db or db.ttkImportantOnly ~= false
end

--- Boss, miniboss or caster, from game data every nameplate addon sees the
-- same (no addon colours): boss units, world bosses and mobs two levels above
-- the player; elites that are lieutenants or above the player's level
-- (minibosses); elites with mana (casters). All fields read here are plain
-- in a key.
function TTK.IsImportantTarget()
  if IsBossTarget() then
    return true
  end
  local classification = PlainValue(rawget(_G, "UnitClassification"), "target")
  if classification == "worldboss" then
    return true
  end
  if classification ~= "elite" and classification ~= "rareelite" then
    return false
  end
  local level = PlainValue(rawget(_G, "UnitEffectiveLevel"), "target")
  local playerLevel = PlainValue(rawget(_G, "UnitEffectiveLevel"), "player")
  if level == -1 then
    return true
  end
  if type(level) == "number" and type(playerLevel) == "number" and level > playerLevel then
    return true
  end
  if PlainTrue(rawget(_G, "UnitIsLieutenant"), "target") then
    return true
  end
  local powerTypes = rawget(_G, "Enum") and rawget(_G, "Enum").PowerType
  local mana = type(powerTypes) == "table" and powerTypes.Mana or 0
  return PlainTrue(rawget(_G, "UnitHasPowerType"), "target", mana)
end

local function NewCurve()
  local util = rawget(_G, "C_CurveUtil")
  if type(util) ~= "table" or type(util.CreateCurve) ~= "function" then
    return nil
  end
  -- The client hands back a userdata object, not a Lua table: accept any
  -- value; a curve that cannot take points fails inside the protected fill.
  local ok, curve = pcall(util.CreateCurve)
  if ok and curve ~= nil then
    return curve
  end
  return nil
end

-- One protected call for the whole fill: the points are plain numbers built
-- here, so a failure means the curve API itself is unusable.
local function FillCurveRaw(curve, points)
  if type(curve.ClearPoints) == "function" then
    curve:ClearPoints()
  end
  for i = 1, #points do
    curve:AddPoint(points[i][1], points[i][2])
  end
end

-- Shared curve: every display shows the same target, so the formula is
-- filled and evaluated once per update.
local sharedCurve = nil

-- true plus the secret TTK value of the target for `elapsed` seconds, or
-- false. The flag is separate because even `value == nil` is a forbidden
-- comparison on a secret.
-- First failing step of the current fight, noted once (diagnostics).
local evalFailureNoted = false

local function NoteEvalFailure(step, err)
  if evalFailureNoted then
    return
  end
  evalFailureNoted = true
  DebugNote("evaluation failed at " .. step .. ": " .. tostring(err))
end

local function EvaluateTargetTtk(elapsedAtHit, sinceHit)
  sharedCurve = sharedCurve or NewCurve()
  local healthPercent = rawget(_G, "UnitHealthPercent")
  if not sharedCurve then
    NoteEvalFailure("create", "C_CurveUtil.CreateCurve unavailable")
    return false
  end
  if type(healthPercent) ~= "function" then
    NoteEvalFailure("evaluate", "UnitHealthPercent unavailable")
    return false
  end
  local filled, fillErr = pcall(FillCurveRaw, sharedCurve, TTK.BuildPoints(elapsedAtHit, sinceHit))
  if not filled then
    NoteEvalFailure("fill", fillErr)
    return false
  end
  -- Unpredicted health: it changes exactly with the UNIT_HEALTH events the
  -- last-hit time comes from.
  local ok, value = pcall(healthPercent, "target", false, sharedCurve)
  if not ok then
    NoteEvalFailure("evaluate", value)
    return false
  end
  return true, value
end

local function Resolve(value)
  if type(value) == "function" then
    return value()
  end
  return value
end

-- Displays are cleared once when the TTK goes away, not on every tick.
local displaysShown = false

local function HideDisplays()
  if not displaysShown then
    return
  end
  displaysShown = false
  for i = 1, #displays do
    local display = displays[i]
    display.fontString:SetText("")
    if type(display.onHide) == "function" then
      display.onHide()
    end
  end
end

-- `hasValue` / `value`: the secret TTK when evaluated (Lua only hands it to
-- SetFormattedText); `pending` shows the placeholder (fight too short).
-- Returns how many displays accepted the update (onShow did not refuse).
local function ShowDisplays(hasValue, value, pending)
  displaysShown = true
  local accepted = 0
  for i = 1, #displays do
    local display = displays[i]
    local fs = display.fontString
    if type(display.onShow) ~= "function" or display.onShow() ~= false then
      accepted = accepted + 1
      local format = Resolve(display.format)
      if pending or not hasValue or type(format) ~= "string" then
        local placeholder = pending and Resolve(display.placeholder) or nil
        fs:SetText(type(placeholder) == "string" and placeholder or "")
      elseif not pcall(fs.SetFormattedText, fs, format, value) then
        fs:SetText("")
      end
    end
  end
  return accepted
end

-- Always-on diagnostics for the test phase: the last DEBUG_MAX state changes
-- in IsiLiveDB.ttkDebug (unknown fields survive the schema sanitizer), so a
-- run can be read back even with the runtime log off.
local DEBUG_MAX = 60
local counters = { updates = 0, health = 0, plateEvents = 0 }

function DebugNote(message)
  local db = GetDB()
  if not db then
    return
  end
  if type(db.ttkDebug) ~= "table" then
    db.ttkDebug = {}
  end
  local list = db.ttkDebug
  local dateFn = rawget(_G, "date")
  local stamp = type(dateFn) == "function" and dateFn("%m-%d %H:%M:%S") or tostring(Now())
  list[#list + 1] = stamp .. " " .. message
  while #list > DEBUG_MAX do
    table.remove(list, 1)
  end
end

local function Trace(reason, accepted, evaluated)
  if traceCount >= TRACE_MAX_PER_FIGHT then
    return
  end
  -- Diagnostics must not trigger a nameplate scan for an excluded display.
  local token = state.inCombat and state.targetToken or nil
  local key = table.concat({ reason, tostring(token), tostring(accepted), tostring(evaluated) }, "|")
  if key == lastTraceKey then
    return
  end
  lastTraceKey = key
  traceCount = traceCount + 1
  local plateCount = 0
  for _ in pairs(state.plates) do
    plateCount = plateCount + 1
  end
  local line = string.format(
    "[TTK] reason=%s token=%s plates=%d clock=%s displays=%s/%d evaluated=%s test=%s",
    reason,
    tostring(token),
    plateCount,
    token and state.plateClock[token] and "nameplate" or (state.combatStart and "combat" or "none"),
    tostring(accepted),
    #displays,
    tostring(evaluated),
    tostring(testMode)
  )
  DebugNote(line)
  if traceFn and (not traceActive or traceActive() == true) then
    traceFn(function()
      return line
    end)
  end
end

-- Why nothing is shown, or nil when the TTK can show.
local function HiddenReason()
  if not state.inCombat then
    return "nocombat"
  elseif not TTK.IsEnabled() then
    return "off"
  elseif not IsKeyActive() then
    return "nokey"
  elseif not IsTargetAlive() then
    return "notarget"
  elseif not testMode and TTK.IsImportantOnly() and not TTK.IsImportantTarget() then
    return "unimportant"
  end
  return nil
end

--- Redraws every display once. Called by the ticker; exposed for tests.
-- Test-mode status sink (the centre panel of /isilive ttktest). Fed only in
-- test mode, so a key fight pays nothing for it.
local statusListener = nil

local function Publish(reason, start, elapsedAtHit, sinceHit, evaluated)
  if not testMode or not statusListener then
    return
  end
  local token = state.inCombat and ResolveTargetToken() or nil
  local clock = nil
  if start then
    if start == state.encounterStart then
      clock = "boss"
    elseif token and state.plateClock[token] == start then
      clock = "nameplate"
    else
      clock = "combat"
    end
  end
  statusListener({
    reason = reason,
    token = token,
    clock = clock,
    elapsedAtHit = elapsedAtHit,
    sinceHit = sinceHit,
    evaluated = evaluated,
  })
end

--- Sets the listener that receives a plain status table after every update
-- while the test mode is on, and `nil` when the test mode turns off.
function TTK.SetStatusListener(fn)
  statusListener = type(fn) == "function" and fn or nil
end

function TTK.Update()
  if raidBlocked then
    HideDisplays()
    return
  end
  counters.updates = counters.updates + 1
  if testMode and not state.inCombat and TTK.IsEnabled() then
    if PlainTrue(rawget(_G, "UnitExists"), "target") then
      Trace("preview", ShowDisplays(true, PREVIEW_SECONDS, false), true)
      Publish("preview", nil, nil, nil, true)
    else
      HideDisplays()
      Publish("notarget")
    end
    return
  end
  local reason = HiddenReason()
  local start = not reason and TTK.GetTargetClock() or nil
  if not start then
    HideDisplays()
    Trace(reason or "noclock", 0, false)
    Publish(reason or "noclock")
    return
  end
  local now = Now()
  local hitAt = TTK.GetTargetLastHit() or now
  if hitAt < start then
    hitAt = start
  end
  local elapsedAtHit = hitAt - start
  if elapsedAtHit < MIN_ELAPSED then
    Trace("pending", ShowDisplays(false, nil, true), false)
    Publish("pending", start, elapsedAtHit, now - hitAt, false)
    return
  end
  local hasValue, value = EvaluateTargetTtk(elapsedAtHit, now - hitAt)
  Trace("shown", ShowDisplays(hasValue, value, false), hasValue)
  Publish("shown", start, elapsedAtHit, now - hitAt, hasValue)
end

--- Sets the runtime-log sink for the TTK reason trace.
-- @param fn function|nil Receives a lazy builder function (RuntimeLog.Trace). nil disables it.
-- @param isActive function|nil When it returns false nothing is built.
function TTK.SetTraceLogger(fn, isActive)
  traceFn = type(fn) == "function" and fn or nil
  traceActive = type(isActive) == "function" and isActive or nil
end

--- Registers a FontString the ticker writes the target TTK into.
-- opts.format: format with one %.0f for the seconds (or a function returning
-- it, so a language switch applies); opts.placeholder: text (or function)
-- below the minimum fight time; opts.onShow / opts.onHide: optional hooks
-- (onShow returning false skips the frame, e.g. no anchor available).
function TTK.RegisterDisplay(fontString, opts)
  if type(fontString) ~= "table" or type(fontString.SetText) ~= "function" then
    return
  end
  opts = opts or {}
  displays[#displays + 1] = {
    fontString = fontString,
    format = (type(opts.format) == "string" or type(opts.format) == "function") and opts.format or "%.0fs",
    placeholder = opts.placeholder,
    onShow = opts.onShow,
    onHide = opts.onHide,
  }
end

local function StopTicker()
  if ticker and type(ticker.Cancel) == "function" then
    ticker:Cancel()
  end
  ticker = nil
end

local function StartTicker()
  if ticker then
    return
  end
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.NewTicker) == "function" then
    ticker = timer.NewTicker(UPDATE_SECONDS, TTK.Update)
  end
end

-- UNIT_HEALTH fires for every unit; it is only listened to while a key fight
-- needs nameplate clocks (registration from a plain combat event, never from a
-- protected-dispatch handler).
local function SetHealthListening(listen)
  if not eventFrame then
    return
  end
  if listen == (eventFrame._isiLiveHealthListening == true) then
    return
  end
  local ok, err
  if listen then
    ok, err = pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_HEALTH")
  elseif type(eventFrame.UnregisterEvent) == "function" then
    ok, err = pcall(eventFrame.UnregisterEvent, eventFrame, "UNIT_HEALTH")
  else
    ok = true
  end
  if not ok then
    DebugNote("UNIT_HEALTH " .. (listen and "register" or "unregister") .. " failed: " .. tostring(err))
  else
    eventFrame._isiLiveHealthListening = listen
  end
end

local function BeginCombat()
  state.inCombat = true
  -- After reload only this observation time is known, not the original pull.
  state.combatStart = Now()
  state.plateClock = {}
  state.lastHit = {}
  state.targetLastHit = nil
  state.targetDirty = true
  traceCount = 0
  lastTraceKey = nil
  counters = { updates = 0, health = 0, plateEvents = 0 }
  evalFailureNoted = false
end

-- Called from settings clicks and plain lifecycle events. No permanent poll
-- is needed to wake an initially disabled TTK in an already running fight.
function TTK.RefreshRuntime()
  raidBlocked = addonTable.RuntimeMode.IsRaidContext() == true
  if raidBlocked then
    StopTicker()
    SetHealthListening(false)
    state.inCombat = false
    state.combatStart = nil
    state.encounterStart = nil
    state.plateClock = {}
    state.lastHit = {}
    state.plates = {}
    state.targetLastHit = nil
    state.targetToken = nil
    state.targetDirty = true
    HideDisplays()
    return
  end
  local inCombat = PlainValue(rawget(_G, "UnitAffectingCombat"), "player")
  if inCombat == false and state.inCombat then
    state.inCombat = false
    state.combatStart = nil
    state.encounterStart = nil
    state.plateClock = {}
    state.lastHit = {}
    state.targetLastHit = nil
    state.targetDirty = true
  elseif not state.inCombat and inCombat == true then
    BeginCombat()
  end
  local enabled = TTK.IsEnabled() and IsKeyActive()
  if enabled and (state.inCombat or testMode) then
    StartTicker()
    SetHealthListening(state.inCombat)
  else
    StopTicker()
    SetHealthListening(false)
    state.lastHit = {}
    state.targetLastHit = nil
  end
  TTK.Update()
end

local function EndCombat()
  SetHealthListening(false)
  state.inCombat = false
  state.combatStart = nil
  state.plateClock = {}
  state.lastHit = {}
  state.targetLastHit = nil
  if not testMode then
    StopTicker()
  end
  TTK.Update()
end

--- Event entry point (own frame, see TTK.Install). Exposed for tests.
function TTK.HandleEvent(event, arg1)
  if event == "PLAYER_ENTERING_WORLD" then
    -- The central dispatcher restores MplusTimer on the same event. Defer
    -- until every frame has received it, regardless of frame dispatch order.
    local timer = rawget(_G, "C_Timer")
    if type(timer) == "table" and type(timer.After) == "function" then
      timer.After(0, TTK.RefreshRuntime)
    end
    TTK.RefreshRuntime()
    return
  elseif event == "GROUP_ROSTER_UPDATE" then
    TTK.RefreshRuntime()
    return
  end
  if raidBlocked then
    return
  end
  if event == "UNIT_HEALTH" then
    -- Hot path: table writes only, no Blizzard call.
    counters.health = counters.health + 1
    if state.inCombat and type(arg1) == "string" then
      if arg1 == "target" then
        state.targetLastHit = Now()
      elseif state.plates[arg1] or arg1:find("^nameplate%d+$") then
        local now = Now()
        state.lastHit[arg1] = now
        if state.plateClock[arg1] == nil then
          state.plateClock[arg1] = now
        end
      end
    end
  elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
    -- Tokens are recycled: a new mob on the same token starts a fresh clock.
    counters.plateEvents = counters.plateEvents + 1
    if type(arg1) == "string" then
      state.plateClock[arg1] = nil
      state.lastHit[arg1] = nil
      state.plates[arg1] = event == "NAME_PLATE_UNIT_ADDED" or nil
      state.targetDirty = true
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    BeginCombat()
    local keyActive, enabled = IsKeyActive(), TTK.IsEnabled()
    if keyActive and enabled then
      -- Ticker first: the TTK must run even if the listener registration fails.
      StartTicker()
      SetHealthListening(true)
    end
    DebugNote(
      string.format(
        "combat start key=%s test=%s enabled=%s ticker=%s displays=%d",
        tostring(keyActive),
        tostring(testMode),
        tostring(enabled),
        tostring(ticker ~= nil),
        #displays
      )
    )
  elseif event == "PLAYER_REGEN_ENABLED" then
    DebugNote(
      string.format(
        "combat end updates=%d health=%d plateEvents=%d",
        counters.updates,
        counters.health,
        counters.plateEvents
      )
    )
    EndCombat()
  elseif event == "ENCOUNTER_START" then
    state.encounterStart = Now()
  elseif event == "ENCOUNTER_END" then
    state.encounterStart = nil
  elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    state.encounterStart = nil
    EndCombat()
  elseif event == "PLAYER_TARGET_CHANGED" then
    state.targetDirty = true
    state.targetLastHit = nil
    TTK.Update()
  end
end

local EVENTS = {
  "PLAYER_ENTERING_WORLD",
  "GROUP_ROSTER_UPDATE",
  "NAME_PLATE_UNIT_ADDED",
  "NAME_PLATE_UNIT_REMOVED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "ENCOUNTER_START",
  "ENCOUNTER_END",
  "CHALLENGE_MODE_COMPLETED",
  "CHALLENGE_MODE_RESET",
  "PLAYER_TARGET_CHANGED",
}

--- Test mode on/off (session only). On: the ticker runs right away, outside
-- combat with a sample value above the target's nameplate, in combat with the
-- real estimate. Off outside a key: displays cleared, ticker stopped.
-- @return boolean the new state
function TTK.SetTestMode(flag)
  testMode = flag == true
  TTK.RefreshRuntime()
  if not testMode and statusListener then
    statusListener(nil)
  end
  return testMode
end

function TTK.IsTestMode()
  return testMode
end

--- Creates the module's own event frame once. Called from the factory at
-- load (never from a protected-dispatch handler). The frame keeps the
-- UNIT_HEALTH hot path out of the central dispatcher and its pcall budget.
function TTK.Install()
  if eventFrame then
    return true
  end
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return false
  end
  local ok, frame = pcall(createFrame, "Frame")
  if not ok or type(frame) ~= "table" then
    return false
  end
  frame:SetScript("OnEvent", function(_, event, arg1)
    TTK.HandleEvent(event, arg1)
  end)
  for i = 1, #EVENTS do
    frame:RegisterEvent(EVENTS[i])
  end
  eventFrame = frame
  raidBlocked = addonTable.RuntimeMode.IsRaidContext() == true
  if not raidBlocked then
    DebugNote("install ok")
  end
  return true
end
