local _, addonTable = ...

addonTable = addonTable or {}

-- Probe mode (rule 239): opt-in, read-only in-game API checks whose results go
-- into the runtime log ring (IsiLiveDB.runtimeLog) as `[PROBE] event=...`
-- lines, so the open questions about the 12.x restrictions can be read back
-- from SavedVariables instead of being typed as /run lines.
--
--   /isilive probe [on|off|status]   toggles without an argument
--   /isilive probe report            one verdict line per question (ProbeReport)
--
-- IsiLiveDB.probeLogEnabled is Pattern B (default off). It is an admin tool:
-- ADDON_LOADED resets it to off on every load and relog (like the runtime
-- log), the user switches it on by hand for each session. Switching it on
-- also switches the runtime log on for the context lines.
--
-- Every hook starts with IsEnabled(): with the mode off nothing else runs, no
-- timer is scheduled and no API is read. Nothing here sends chat or addon
-- messages. Every value coming from the client is checked with
-- IsSecretValue before any comparison, arithmetic or string conversion; a
-- secret value is only ever written as the word "secret".
local ProbeLog = {}
addonTable.ProbeLog = ProbeLog
local IsSecretValue = addonTable.Validators.IsSecretValue

-- Line budgets per run segment (a segment starts at CHALLENGE_MODE_START or at
-- the load of the addon). The runtime ring holds 1500 entries; a full segment
-- stays below ~500 probe lines.
local LIMITS = {
  meterThrottleSeconds = 10, -- per meter phase
  meterSnapshotsPerRun = 30, -- 4 lines each (Overall/Current x DamageDone/Interrupts)
  postKeySnapshotsPerPhase = 3,
  postKeyWindowSeconds = 900,
  keyEndFollowUpSeconds = 5,
  threatDelaySeconds = 2,
  threatPullsPerRun = 60,
  ownCastSpellsPerRun = 40,
  kicksPerRun = 80,
  kickVerdictSeconds = 1,
  kickPreCastLookbackSeconds = 2,
  restrictionLinesPerRun = 80,
  chatLockdownLinesPerRun = 40,
  meterSourcesShown = 8,
  nameplates = 40,
  readyChecksPerRun = 20,
  playerAuras = 40,
  channelStopsPerRun = 60,
  actionBlockedPerRun = 30,
  kickCellLinesPerRun = 20,
}
ProbeLog.LIMITS = LIMITS

local sink = nil
local readLog = nil
local getAddonVersion = nil
local setRuntimeLogEnabled = nil
local sessionHeaderWritten = false
local sessionLineCount = 0

local lastChatLockdown = nil
local keyEndedAt = nil
local lastInterruptAt = nil
local pendingKicks = {}
-- True between a seen CHALLENGE_MODE_START (or a running key found after a
-- reload) and its end. The client fires CHALLENGE_MODE_RESET ~0.2 s before
-- every CHALLENGE_MODE_START (probe log 2026-11-12); without a running key
-- that reset is not a key end.
local keyRunning = false
local lastIdleResetAt = nil

local function NewRunState()
  return {
    meterSnapshots = 0,
    meterPhaseAt = {},
    meterPhaseCount = {},
    threatPulls = 0,
    ownCastSpells = 0,
    ownCastSeen = {},
    kicks = 0,
    restrictionLines = 0,
    chatLockdownLines = 0,
    readyChecks = 0,
    channelStops = 0,
    actionBlocked = 0,
    kickCellLines = 0,
    kickCellSeen = {},
    capped = {},
  }
end
local run = NewRunState()

local function GetDB()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db or nil
end

--- True while probe mode is on (Pattern B: IsiLiveDB.probeLogEnabled == true).
function ProbeLog.IsEnabled()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db.probeLogEnabled == true
end

local function Now()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return nil
  end
  local ok, now = pcall(getTime)
  if not ok or IsSecretValue(now) or type(now) ~= "number" then
    return nil
  end
  return now
end

local function TimerAfter(delay, callback)
  local timer = rawget(_G, "C_Timer")
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return false
  end
  timer.After(delay, callback)
  return true
end

local function Ms(seconds)
  return string.format("%d", math.floor(seconds * 1000 + 0.5))
end

local function YesNo(value)
  return value and "yes" or "no"
end

local function IsRuntimeLogOn()
  local db = GetDB()
  return db ~= nil and db.runtimeLogEnabled == true
end

local function Append(message)
  if type(sink) ~= "function" then
    return false
  end
  if not sessionHeaderWritten then
    sessionHeaderWritten = true
    local version = type(getAddonVersion) == "function" and getAddonVersion() or nil
    sink(
      string.format(
        "[PROBE] event=probe_session version=%s runtimeLog=%s note=probe_lines_are_written_even_with_runtime_log_off",
        tostring(version or "unknown"),
        IsRuntimeLogOn() and "on" or "off"
      )
    )
    sessionLineCount = sessionLineCount + 1
  end
  sink(message)
  sessionLineCount = sessionLineCount + 1
  return true
end

-- Counts one line against a per-run budget. The first refusal writes a single
-- cap_reached line so a silent probe is never mistaken for "nothing happened".
local function TakeBudget(counterKey, limit, probeName)
  if run[counterKey] >= limit then
    if not run.capped[probeName] then
      run.capped[probeName] = true
      Append(string.format("[PROBE] event=cap_reached probe=%s limit=%d until=next_key_start", probeName, limit))
    end
    return false
  end
  run[counterKey] = run[counterKey] + 1
  return true
end

-- Name of an enum value, looked up in the client's Enum table at run time.
-- Returns "secret" for a masked value and "<number>" or "?" when unnamed.
local function DescribeEnumValue(enumName, value)
  if IsSecretValue(value) then
    return "secret"
  end
  if type(value) ~= "number" then
    return value == nil and "nil" or "?"
  end
  local enum = rawget(_G, "Enum")
  local values = type(enum) == "table" and rawget(enum, enumName) or nil
  if type(values) == "table" then
    for name, enumValue in pairs(values) do
      if not IsSecretValue(enumValue) and enumValue == value then
        return string.format("%s(%d)", tostring(name), value)
      end
    end
  end
  return string.format("unnamed(%d)", value)
end

local function ReadEnumValue(enumName, key)
  local enum = rawget(_G, "Enum")
  local values = type(enum) == "table" and rawget(enum, enumName) or nil
  if type(values) ~= "table" then
    return nil
  end
  local value = rawget(values, key)
  if IsSecretValue(value) or type(value) ~= "number" then
    return nil
  end
  return value
end

-- true / false when the client names a running key readably, nil otherwise.
local function ReadActiveMapID()
  local challengeMode = rawget(_G, "C_ChallengeMode")
  local getMapID = type(challengeMode) == "table" and rawget(challengeMode, "GetActiveChallengeMapID") or nil
  if type(getMapID) ~= "function" then
    return nil
  end
  local ok, mapID = pcall(getMapID)
  if not ok or IsSecretValue(mapID) or type(mapID) ~= "number" or mapID <= 0 then
    return nil
  end
  return mapID
end

local function IsKeyActive()
  return ReadActiveMapID() ~= nil
end

local function ReadInInstance()
  local isInInstance = rawget(_G, "IsInInstance")
  if type(isInInstance) ~= "function" then
    return nil
  end
  local ok, inInstance = pcall(isInInstance)
  if not ok or IsSecretValue(inInstance) then
    return nil
  end
  return inInstance == true or inInstance == 1
end

-- Chat lockdown (C_ChatInfo.InChatMessagingLockdown, no arguments; returns
-- isRestricted only since 12.0.5 removed the reason, warcraft.wiki.gg).
local function ReadChatLockdown()
  local chatInfo = rawget(_G, "C_ChatInfo")
  local fn = type(chatInfo) == "table" and rawget(chatInfo, "InChatMessagingLockdown") or nil
  if type(fn) ~= "function" then
    return "api_missing"
  end
  local ok, restricted, reason = pcall(fn)
  if not ok then
    return "error"
  end
  if IsSecretValue(restricted) then
    return "secret"
  end
  local value = restricted == true and "yes" or (restricted == false and "no" or "nil")
  -- A client that still answers a second value gets it logged.
  if reason ~= nil then
    value = value .. " reason=" .. (IsSecretValue(reason) and "secret" or tostring(reason))
  end
  return value
end

local function CheckChatLockdown(moment)
  local value = ReadChatLockdown()
  if value == lastChatLockdown then
    return
  end
  local previous = lastChatLockdown or "unknown"
  lastChatLockdown = value
  if not TakeBudget("chatLockdownLines", LIMITS.chatLockdownLinesPerRun, "chat_lockdown") then
    return
  end
  Append(
    string.format(
      "[PROBE] event=chat_lockdown at=%s inKey=%s value=%s prev=%s",
      moment,
      YesNo(IsKeyActive()),
      value,
      previous
    )
  )
end

-- One damage-meter session, described without converting a secret value.
local function DescribeMeterSession(api, sessionType, meterType)
  if sessionType == nil or meterType == nil then
    return "present=no reason=enum_missing"
  end
  local ok, session = pcall(api.GetCombatSessionFromType, sessionType, meterType)
  if not ok then
    return "present=no reason=call_error"
  end
  if IsSecretValue(session) then
    return "present=secret"
  end
  if type(session) ~= "table" then
    return "present=no reason=" .. (session == nil and "nil_session" or "not_a_table")
  end
  local okSources, sources = pcall(rawget, session, "combatSources")
  if not okSources or IsSecretValue(sources) then
    return "present=yes sources=secret"
  end
  if type(sources) ~= "table" then
    return "present=yes sources=none"
  end

  local count, secretEntries, secretNames, secretAmounts = 0, 0, 0, 0
  local shown = {}
  for index = 1, 40 do
    local okEntry, source = pcall(rawget, sources, index)
    if not okEntry then
      break
    end
    if IsSecretValue(source) then
      count = count + 1
      secretEntries = secretEntries + 1
    elseif type(source) ~= "table" then
      break
    else
      count = count + 1
      local okName, name = pcall(rawget, source, "name")
      local okAmount, amount = pcall(rawget, source, "totalAmount")
      local nameSecret = not okName or IsSecretValue(name)
      local amountSecret = not okAmount or IsSecretValue(amount)
      if nameSecret then
        secretNames = secretNames + 1
      end
      if amountSecret then
        secretAmounts = secretAmounts + 1
      end
      if not nameSecret and type(name) == "string" and name ~= "" and #shown < LIMITS.meterSourcesShown then
        local amountText
        if amountSecret then
          amountText = "secret"
        elseif type(amount) == "number" then
          amountText = string.format("%.0f", amount)
        else
          amountText = "nil"
        end
        shown[#shown + 1] = name .. ":" .. amountText
      end
    end
  end
  return string.format(
    "present=yes sources=%d secretEntries=%d secretNames=%d secretAmounts=%d values=%s",
    count,
    secretEntries,
    secretNames,
    secretAmounts,
    #shown > 0 and table.concat(shown, ",") or "none"
  )
end

local METER_SESSIONS = { "Overall", "Current" }
local METER_TYPES = { "DamageDone", "Interrupts" }

local function SnapshotMeter(phase)
  local api = rawget(_G, "C_DamageMeter")
  if type(api) ~= "table" or type(rawget(api, "GetCombatSessionFromType")) ~= "function" then
    Append(string.format("[PROBE] event=meter phase=%s api=missing", phase))
    return
  end
  for _, sessionName in ipairs(METER_SESSIONS) do
    local sessionType = ReadEnumValue("DamageMeterSessionType", sessionName)
    for _, meterName in ipairs(METER_TYPES) do
      local meterType = ReadEnumValue("DamageMeterType", meterName)
      Append(
        string.format(
          "[PROBE] event=meter phase=%s session=%s(%s) meter=%s(%s) %s",
          phase,
          sessionName,
          sessionType ~= nil and tostring(sessionType) or "?",
          meterName,
          meterType ~= nil and tostring(meterType) or "?",
          DescribeMeterSession(api, sessionType, meterType)
        )
      )
    end
  end
end

-- Throttled meter snapshot: one per phase per meterThrottleSeconds, at most
-- meterSnapshotsPerRun per run segment.
local function TryMeterSnapshot(phase, perPhaseLimit)
  local now = Now()
  if not now then
    return false
  end
  local lastAt = run.meterPhaseAt[phase]
  if lastAt and now - lastAt < LIMITS.meterThrottleSeconds then
    return false
  end
  local phaseCount = run.meterPhaseCount[phase] or 0
  if perPhaseLimit and phaseCount >= perPhaseLimit then
    return false
  end
  if not TakeBudget("meterSnapshots", LIMITS.meterSnapshotsPerRun, "meter") then
    return false
  end
  run.meterPhaseAt[phase] = now
  run.meterPhaseCount[phase] = phaseCount + 1
  SnapshotMeter(phase)
  return true
end

local function IsInPostKeyWindow()
  local now = Now()
  return keyEndedAt ~= nil and now ~= nil and now - keyEndedAt <= LIMITS.postKeyWindowSeconds
end

local function ReadUnitBoolean(fn, ...)
  local ok, value = pcall(fn, ...)
  if not ok then
    return "error"
  end
  if IsSecretValue(value) then
    return "secret"
  end
  return value == true
end

-- A threat status (0..3) as text: the number, "nil", "secret" or "error".
local function DescribeThreat(ok, threat)
  if not ok then
    return "error"
  end
  if IsSecretValue(threat) then
    return "secret"
  end
  if type(threat) == "number" then
    return string.format("%d", threat)
  end
  return threat == nil and "nil" or "?"
end

-- Threat readability (K6): hostile nameplates, UnitThreatSituation("player", unit),
-- plus the one-argument UnitThreatSituation("player") (highest own status
-- over all enemies), the cheaper source an aggro warning would use.
local function SampleThreat()
  if not ProbeLog.IsEnabled() then
    return
  end
  local unitExists = rawget(_G, "UnitExists")
  local unitCanAttack = rawget(_G, "UnitCanAttack")
  local threatSituation = rawget(_G, "UnitThreatSituation")
  if type(unitExists) ~= "function" or type(unitCanAttack) ~= "function" or type(threatSituation) ~= "function" then
    Append("[PROBE] event=threat phase=pull_start+2s api=missing")
    return
  end
  local counts = {
    plates = 0,
    hostile = 0,
    hostileSecret = 0,
    t0 = 0,
    t1 = 0,
    t2 = 0,
    t3 = 0,
    tNil = 0,
    tSecret = 0,
    tOther = 0,
  }
  for index = 1, LIMITS.nameplates do
    local unit = "nameplate" .. index
    if ReadUnitBoolean(unitExists, unit) == true then
      counts.plates = counts.plates + 1
      local canAttack = ReadUnitBoolean(unitCanAttack, "player", unit)
      if canAttack == "secret" then
        counts.hostileSecret = counts.hostileSecret + 1
      end
      if canAttack == true or canAttack == "secret" then
        if canAttack == true then
          counts.hostile = counts.hostile + 1
        end
        local ok, threat = pcall(threatSituation, "player", unit)
        if not ok then
          counts.tOther = counts.tOther + 1
        elseif IsSecretValue(threat) then
          counts.tSecret = counts.tSecret + 1
        elseif threat == nil then
          counts.tNil = counts.tNil + 1
        elseif threat == 0 then
          counts.t0 = counts.t0 + 1
        elseif threat == 1 then
          counts.t1 = counts.t1 + 1
        elseif threat == 2 then
          counts.t2 = counts.t2 + 1
        elseif threat == 3 then
          counts.t3 = counts.t3 + 1
        else
          counts.tOther = counts.tOther + 1
        end
      end
    end
  end
  local selfThreat = DescribeThreat(pcall(threatSituation, "player"))
  Append(
    string.format(
      "[PROBE] event=threat phase=pull_start+2s inKey=%s self=%s plates=%d hostile=%d hostileSecret=%d "
        .. "threat0=%d threat1=%d threat2=%d threat3=%d threatNil=%d threatSecret=%d threatOther=%d",
      YesNo(IsKeyActive()),
      selfThreat,
      counts.plates,
      counts.hostile,
      counts.hostileSecret,
      counts.t0,
      counts.t1,
      counts.t2,
      counts.t3,
      counts.tNil,
      counts.tSecret,
      counts.tOther
    )
  )
end

-- Own buffs (K4): how many the client lists and how many of them, or of
-- their spell IDs and expiration times, are masked. Also whether
-- GetPlayerAuraBySpellID answers readably for the first readable spell ID,
-- the call a consumable check would make with a season ID list.
local function SampleOwnAuras()
  local unitAuras = rawget(_G, "C_UnitAuras")
  local byIndex = type(unitAuras) == "table" and rawget(unitAuras, "GetAuraDataByIndex") or nil
  if type(byIndex) ~= "function" then
    return "auras=api_missing"
  end
  local counts = { auras = 0, auraSecret = 0, spellIdSecret = 0, expirationSecret = 0, errors = 0 }
  local candidate = nil
  -- Readable spell IDs of the own buffs: the season IDs of food, flask and
  -- augment rune for the consumable check (rule 246) come from here.
  local spellIds = {}
  for index = 1, LIMITS.playerAuras do
    local ok, aura = pcall(byIndex, "player", index, "HELPFUL")
    if not ok then
      counts.errors = counts.errors + 1
      break
    end
    if IsSecretValue(aura) then
      counts.auras = counts.auras + 1
      counts.auraSecret = counts.auraSecret + 1
    elseif type(aura) ~= "table" then
      break
    else
      counts.auras = counts.auras + 1
      local spellId = aura.spellId
      if IsSecretValue(spellId) then
        counts.spellIdSecret = counts.spellIdSecret + 1
      elseif type(spellId) == "number" then
        candidate = candidate or spellId
        spellIds[#spellIds + 1] = string.format("%d", spellId)
      end
      if IsSecretValue(aura.expirationTime) then
        counts.expirationSecret = counts.expirationSecret + 1
      end
    end
  end
  local bySpellId = "no_candidate"
  local bySpellFn = type(unitAuras) == "table" and rawget(unitAuras, "GetPlayerAuraBySpellID") or nil
  if type(bySpellFn) ~= "function" then
    bySpellId = "api_missing"
  elseif candidate ~= nil then
    local ok, aura = pcall(bySpellFn, candidate)
    if not ok then
      bySpellId = "error"
    elseif IsSecretValue(aura) then
      bySpellId = "secret"
    else
      bySpellId = type(aura) == "table" and "readable" or "nil"
    end
  end
  return string.format(
    "auras=%d auraSecret=%d spellIdSecret=%d expirationSecret=%d auraErrors=%d bySpellID=%s",
    counts.auras,
    counts.auraSecret,
    counts.spellIdSecret,
    counts.expirationSecret,
    counts.errors,
    bySpellId
  ),
    #spellIds > 0 and table.concat(spellIds, ",") or "none"
end

-- One weapon slot of GetWeaponEnchantInfo: has / minutes left / enchant ID.
local function DescribeWeaponSlot(prefix, has, expirationMs, enchantId)
  local hasText
  if IsSecretValue(has) then
    hasText = "secret"
  else
    hasText = YesNo(has == true or has == 1)
  end
  local minutes = "nil"
  if IsSecretValue(expirationMs) then
    minutes = "secret"
  elseif type(expirationMs) == "number" then
    minutes = string.format("%d", math.floor(expirationMs / 60000))
  end
  local enchant = "nil"
  if IsSecretValue(enchantId) then
    enchant = "secret"
  elseif type(enchantId) == "number" then
    enchant = string.format("%d", enchantId)
  end
  return string.format("%s=%s %sMin=%s %sEnchant=%s", prefix, hasText, prefix, minutes, prefix, enchant)
end

-- Weapon oil (K4): GetWeaponEnchantInfo needs no season ID list.
local function SampleWeaponEnchants()
  local getInfo = rawget(_G, "GetWeaponEnchantInfo")
  if type(getInfo) ~= "function" then
    return "weapon=api_missing"
  end
  local ok, hasMain, mainExp, _, mainId, hasOff, offExp, _, offId = pcall(getInfo)
  if not ok then
    return "weapon=error"
  end
  return DescribeWeaponSlot("mh", hasMain, mainExp, mainId) .. " " .. DescribeWeaponSlot("oh", hasOff, offExp, offId)
end

local function ReadInCombat()
  local inCombat = rawget(_G, "InCombatLockdown")
  if type(inCombat) ~= "function" then
    return "nil"
  end
  local ok, value = pcall(inCombat)
  if not ok or IsSecretValue(value) then
    return "secret"
  end
  return YesNo(value == true)
end

--- READY_CHECK: readability of the own buffs and weapon enchants (K4).
function ProbeLog.OnReadyCheck()
  if not ProbeLog.IsEnabled() then
    return
  end
  if not TakeBudget("readyChecks", LIMITS.readyChecksPerRun, "ready_check") then
    return
  end
  local auraSummary, spellIds = SampleOwnAuras()
  Append(
    string.format(
      "[PROBE] event=ready_check inKey=%s inInstance=%s inCombat=%s %s %s spellIDs=%s",
      YesNo(IsKeyActive()),
      tostring(ReadInInstance()),
      ReadInCombat(),
      auraSummary,
      SampleWeaponEnchants(),
      spellIds or "none"
    )
  )
end

--- Wires the log sink (runtime log AppendLog), the ring reader for the
-- report, the version reader and the runtime log switch.
-- @param opts table {appendLog = function(message), readLog = function(needle): table,
--   getAddonVersion = function(), setRuntimeLogEnabled = function(enabled)}
function ProbeLog.Attach(opts)
  opts = type(opts) == "table" and opts or {}
  sink = type(opts.appendLog) == "function" and opts.appendLog or nil
  readLog = type(opts.readLog) == "function" and opts.readLog or nil
  getAddonVersion = type(opts.getAddonVersion) == "function" and opts.getAddonVersion or nil
  setRuntimeLogEnabled = type(opts.setRuntimeLogEnabled) == "function" and opts.setRuntimeLogEnabled or nil
end

--- Ring size for the runtime log: a probe session keeps the context lines
-- of two keys (about 1000 lines each at normal level), otherwise 1500.
ProbeLog.RING_ENTRIES_DEFAULT = 1500
ProbeLog.RING_ENTRIES_PROBE = 4000
function ProbeLog.GetRingEntries()
  return ProbeLog.IsEnabled() and ProbeLog.RING_ENTRIES_PROBE or ProbeLog.RING_ENTRIES_DEFAULT
end

-- Probe mode needs the context lines ([STATS], [TIMEPACE], [SYNC],
-- [INSTANCE_RESET], ...) next to its own: it switches the runtime log on.
-- Returns true when the runtime log is on afterwards.
local function EnsureRuntimeLogOn()
  if IsRuntimeLogOn() then
    return true
  end
  if type(setRuntimeLogEnabled) ~= "function" then
    return false
  end
  setRuntimeLogEnabled(true)
  return IsRuntimeLogOn()
end

--- Probe lines written since the addon was loaded.
function ProbeLog.GetSessionLineCount()
  return sessionLineCount
end

--- Turns probe mode on or off and persists it (Pattern B).
-- @return boolean the new state
function ProbeLog.SetEnabled(enabled)
  local db = GetDB()
  if not db then
    return false
  end
  local nextEnabled = enabled == true
  if db.probeLogEnabled == true and not nextEnabled then
    Append("[PROBE] event=probe_disabled")
  end
  local wasEnabled = db.probeLogEnabled == true
  db.probeLogEnabled = nextEnabled
  if nextEnabled and not wasEnabled then
    Append(
      string.format(
        "[PROBE] event=probe_enabled inKey=%s inInstance=%s",
        YesNo(IsKeyActive()),
        tostring(ReadInInstance())
      )
    )
  end
  if nextEnabled then
    EnsureRuntimeLogOn()
  end
  return nextEnabled
end

--- CHALLENGE_MODE_START: new run segment, budgets reset.
function ProbeLog.OnKeyStart()
  if not ProbeLog.IsEnabled() then
    return
  end
  run = NewRunState()
  keyEndedAt = nil
  pendingKicks = {}
  keyRunning = true
  local now = Now()
  local resetBefore = "none"
  if lastIdleResetAt ~= nil and now ~= nil and now - lastIdleResetAt >= 0 and now - lastIdleResetAt <= 5 then
    resetBefore = Ms(now - lastIdleResetAt)
  end
  lastIdleResetAt = nil
  local mapID = ReadActiveMapID()
  Append(
    string.format(
      "[PROBE] event=key_start mapID=%s resetBeforeStartMs=%s note=budgets_reset",
      tostring(mapID or "unknown"),
      resetBefore
    )
  )
  CheckChatLockdown("key_start")
end

--- CHALLENGE_MODE_COMPLETED / CHALLENGE_MODE_RESET: meter at the key end and
-- once more keyEndFollowUpSeconds later. A reset without a running key (the
-- one the client fires right before every key start) is logged as
-- challenge_reset kind=no_running_key and is not a key end; with a running
-- key it is an abandoned key.
function ProbeLog.OnKeyEnd(event)
  if not ProbeLog.IsEnabled() then
    return
  end
  local isReset = event == "CHALLENGE_MODE_RESET"
  if isReset and not keyRunning then
    lastIdleResetAt = Now()
    Append(
      string.format(
        "[PROBE] event=challenge_reset kind=no_running_key activeMap=%s inInstance=%s",
        tostring(ReadActiveMapID() or "none"),
        tostring(ReadInInstance())
      )
    )
    return
  end
  keyRunning = false
  keyEndedAt = Now()
  local phase = isReset and "key_reset" or "key_completed"
  Append(
    string.format("[PROBE] event=key_end trigger=%s kind=%s", tostring(event), isReset and "abandoned" or "completed")
  )
  CheckChatLockdown(phase)
  TryMeterSnapshot(phase)
  TimerAfter(LIMITS.keyEndFollowUpSeconds, function()
    if ProbeLog.IsEnabled() then
      TryMeterSnapshot(phase .. "+5s")
    end
  end)
end

--- PLAYER_REGEN_DISABLED: chat lockdown edge; threat sample 2 s into a key pull.
function ProbeLog.OnCombatStart()
  if not ProbeLog.IsEnabled() then
    return
  end
  CheckChatLockdown("combat_start")
  if not IsKeyActive() then
    return
  end
  if not TakeBudget("threatPulls", LIMITS.threatPullsPerRun, "threat") then
    return
  end
  if not TimerAfter(LIMITS.threatDelaySeconds, SampleThreat) then
    Append("[PROBE] event=threat phase=pull_start+2s api=timer_missing")
  end
end

--- PLAYER_REGEN_ENABLED: chat lockdown edge; meter between pulls (K9).
function ProbeLog.OnCombatEnd()
  if not ProbeLog.IsEnabled() then
    return
  end
  CheckChatLockdown("combat_end")
  if IsKeyActive() then
    TryMeterSnapshot("between_pulls")
  end
end

--- ADDON_RESTRICTION_STATE_CHANGED (type, state). After a key a lifted
-- restriction also triggers a meter snapshot.
function ProbeLog.OnRestrictionChanged(restrictionType, state)
  if not ProbeLog.IsEnabled() then
    return
  end
  local stateName = DescribeEnumValue("AddOnRestrictionState", state)
  if TakeBudget("restrictionLines", LIMITS.restrictionLinesPerRun, "restriction") then
    Append(
      string.format(
        "[PROBE] event=restriction type=%s state=%s inKey=%s",
        DescribeEnumValue("AddOnRestrictionType", restrictionType),
        stateName,
        YesNo(IsKeyActive())
      )
    )
  end
  CheckChatLockdown("restriction_changed")
  if stateName:find("^Inactive%(") and not IsKeyActive() and IsInPostKeyWindow() then
    TryMeterSnapshot("post_key_restriction_lifted", LIMITS.postKeySnapshotsPerPhase)
  end
end

--- PLAYER_ENTERING_WORLD / ZONE_CHANGED_NEW_AREA: a readable "outside any
-- instance" after a key reads the meter again.
function ProbeLog.OnZoneChanged()
  if not ProbeLog.IsEnabled() then
    return
  end
  -- A reload inside a running key misses CHALLENGE_MODE_START.
  if not keyRunning and IsKeyActive() then
    keyRunning = true
  end
  if ReadInInstance() ~= false or not IsInPostKeyWindow() then
    return
  end
  TryMeterSnapshot("post_key_outside_instance", LIMITS.postKeySnapshotsPerPhase)
end

--- Own UNIT_SPELLCAST_SUCCEEDED (player or pet), once per spell per run:
-- were spellID and castGUID readable?
function ProbeLog.OnOwnCast(unit, castGUID, spellID, observedKick)
  if not ProbeLog.IsEnabled() then
    return
  end
  local spellSecret = IsSecretValue(spellID)
  local unitSecret = IsSecretValue(unit)
  local unitText = unitSecret and "secret" or tostring(unit)
  local key
  if spellSecret then
    key = "secret:" .. unitText
  elseif type(spellID) == "number" then
    key = spellID
  else
    key = "nil:" .. unitText
  end
  if run.ownCastSeen[key] then
    return
  end
  if not TakeBudget("ownCastSpells", LIMITS.ownCastSpellsPerRun, "own_cast") then
    return
  end
  run.ownCastSeen[key] = true
  local guidText
  if IsSecretValue(castGUID) then
    guidText = "secret"
  elseif castGUID == nil then
    guidText = "nil"
  else
    guidText = "readable"
  end
  Append(
    string.format(
      "[PROBE] event=own_cast unit=%s spellID=%s spellIDSecret=%s castGUID=%s kick=%s inKey=%s "
        .. "note=once_per_spell_per_run",
      unitText,
      spellSecret and "secret" or tostring(spellID),
      YesNo(spellSecret),
      guidText,
      YesNo(observedKick == true),
      YesNo(IsKeyActive())
    )
  )
end

--- A hostile cast was interrupted (already filtered by the kick tracker).
function ProbeLog.OnHostileInterrupt(event)
  if not ProbeLog.IsEnabled() then
    return
  end
  local now = Now()
  if not now then
    return
  end
  lastInterruptAt = now
  for _, record in ipairs(pendingKicks) do
    if record.firstAfter == nil and now >= record.castAt then
      record.firstAfter = now - record.castAt
      record.firstEvent = tostring(event)
    end
  end
end

local function FinishKick(record)
  for index, pending in ipairs(pendingKicks) do
    if pending == record then
      table.remove(pendingKicks, index)
      break
    end
  end
  local verdict
  if record.excluded then
    verdict = "excluded"
  elseif type(record.window) ~= "number" then
    verdict = "unknown"
  elseif record.firstAfter ~= nil and record.firstAfter <= record.window then
    verdict = "landed"
  else
    verdict = "missed"
  end
  local firstAfterText = record.firstAfter ~= nil and Ms(record.firstAfter) or "none"
  Append(
    string.format(
      "[PROBE] event=kick spellID=%s inKey=%s inCombat=%s alert=%s window_ms=%s verdict=%s "
        .. "firstInterruptAfterMs=%s firstEvent=%s interruptBeforeCastMs=%s lookahead_ms=%s",
      tostring(record.spellID),
      YesNo(record.inKey),
      YesNo(record.inCombat),
      record.alertEnabled and "on" or "off",
      type(record.window) == "number" and Ms(record.window) or "none",
      verdict,
      firstAfterText,
      record.firstEvent or "none",
      record.preCast ~= nil and Ms(record.preCast) or "none",
      Ms(LIMITS.kickVerdictSeconds)
    )
  )
end

--- Own kick observed by the kick tracker (K3 calibration). `pending` is the
-- tracker's armed kick ({seq, spellID, window}) or nil for an excluded spell.
function ProbeLog.OnOwnKick(spellID, pending, alertEnabled)
  if not ProbeLog.IsEnabled() then
    return
  end
  local now = Now()
  if not now then
    return
  end
  if not TakeBudget("kicks", LIMITS.kicksPerRun, "kick") then
    return
  end
  local inCombatLockdown = rawget(_G, "InCombatLockdown")
  local inCombat = false
  if type(inCombatLockdown) == "function" then
    local ok, value = pcall(inCombatLockdown)
    inCombat = ok and not IsSecretValue(value) and value == true
  end
  local record = {
    castAt = now,
    spellID = not IsSecretValue(spellID) and type(spellID) == "number" and spellID or "unknown",
    excluded = type(pending) ~= "table",
    window = type(pending) == "table" and tonumber(pending.window) or nil,
    alertEnabled = alertEnabled == true,
    inKey = IsKeyActive(),
    inCombat = inCombat,
  }
  if lastInterruptAt ~= nil then
    local before = now - lastInterruptAt
    if before == 0 then
      -- Same frame as the own cast: the event order inside a frame is not
      -- documented, the tracker counts it as landed.
      record.firstAfter = 0
      record.firstEvent = "same_frame"
      record.preCast = 0
    elseif before > 0 and before <= LIMITS.kickPreCastLookbackSeconds then
      record.preCast = before
    end
  end
  pendingKicks[#pendingKicks + 1] = record
  if not TimerAfter(LIMITS.kickVerdictSeconds, function()
    FinishKick(record)
  end) then
    FinishKick(record)
  end
end

-- interruptedBy of UNIT_SPELLCAST_CHANNEL_STOP as text, never converted.
local function DescribePresence(value)
  if IsSecretValue(value) then
    return "secret"
  end
  if value == nil then
    return "nil"
  end
  if type(value) == "string" then
    return value == "" and "empty" or "readable"
  end
  return type(value)
end

--- Every hostile UNIT_SPELLCAST_CHANNEL_STOP, interrupted or not: is
-- interruptedBy set for a kicked channel and nil for one that simply ends?
-- ownKickPendingMs = time since the newest own kick still waiting for its
-- verdict (none = no own kick in the last second).
function ProbeLog.OnChannelStop(unit, interruptedBy)
  if not ProbeLog.IsEnabled() then
    return
  end
  if not TakeBudget("channelStops", LIMITS.channelStopsPerRun, "channel_stop") then
    return
  end
  local now = Now()
  local newestKickAt = nil
  for _, record in ipairs(pendingKicks) do
    if newestKickAt == nil or record.castAt > newestKickAt then
      newestKickAt = record.castAt
    end
  end
  local kickText = "none"
  if newestKickAt ~= nil and now ~= nil and now >= newestKickAt then
    kickText = Ms(now - newestKickAt)
  end
  Append(
    string.format(
      "[PROBE] event=channel_stop unit=%s interruptedBy=%s ownKickPendingMs=%s inKey=%s",
      IsSecretValue(unit) and "secret" or tostring(unit),
      DescribePresence(interruptedBy),
      kickText,
      YesNo(IsKeyActive())
    )
  )
end

--- ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN naming isiLive: which
-- protected call, in which context. Answers the taint checks (resize grip,
-- settings window, edit mode, demo) without /console taintLog.
function ProbeLog.OnActionBlocked(event, addonName, functionName)
  if not ProbeLog.IsEnabled() then
    return
  end
  if IsSecretValue(addonName) or addonName ~= "isiLive" then
    return
  end
  if not TakeBudget("actionBlocked", LIMITS.actionBlockedPerRun, "action_blocked") then
    return
  end
  Append(
    string.format(
      "[PROBE] event=action_blocked kind=%s func=%s inCombat=%s inKey=%s",
      tostring(event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked"),
      IsSecretValue(functionName) and "secret" or tostring(functionName or "nil"),
      ReadInCombat(),
      YesNo(IsKeyActive())
    )
  )
end

--- Kick column of a roster row: did the run-kick pair fit the cell, and did
-- the landed-only fallback fit? One line per distinct outcome per run.
function ProbeLog.OnKickCellFit(text, fits, fallbackText, fallbackFits, width)
  if not ProbeLog.IsEnabled() then
    return
  end
  local key = string.format("%s|%s|%s", tostring(text), tostring(fits), tostring(fallbackFits))
  if run.kickCellSeen[key] then
    return
  end
  if not TakeBudget("kickCellLines", LIMITS.kickCellLinesPerRun, "kick_cell") then
    return
  end
  run.kickCellSeen[key] = true
  Append(
    string.format(
      "[PROBE] event=kick_cell text=%s fits=%s fallback=%s fallbackFits=%s width=%s",
      tostring(text),
      YesNo(fits),
      tostring(fallbackText or "none"),
      fallbackFits == nil and "n/a" or YesNo(fallbackFits),
      type(width) == "number" and string.format("%d", math.floor(width + 0.5)) or "nil"
    )
  )
end

-- ADDON_ACTION_BLOCKED / _FORBIDDEN are registered once in the main chunk on
-- a frame of their own (registering from a handler would be forbidden); the
-- handler does nothing while probe mode is off.
do
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) == "function" then
    local ok, frame = pcall(createFrame, "Frame")
    if ok and type(frame) == "table" and type(frame.RegisterEvent) == "function" then
      pcall(frame.RegisterEvent, frame, "ADDON_ACTION_BLOCKED")
      pcall(frame.RegisterEvent, frame, "ADDON_ACTION_FORBIDDEN")
      if type(frame.SetScript) == "function" then
        frame:SetScript("OnEvent", function(_, event, addonName, functionName)
          ProbeLog.OnActionBlocked(event, addonName, functionName)
        end)
      end
      ProbeLog._actionBlockedFrame = frame
    end
  end
end

local ARG_ON = { on = true, ["1"] = true, ["true"] = true }
local ARG_OFF = { off = true, ["0"] = true, ["false"] = true }

-- /isilive probe report: reads the [PROBE] lines of the whole ring (also
-- with probe mode off) and prints one verdict line per question. Printed
-- without logging, so the report never lands in the ring it reads.
local function PrintReport(printFn, L)
  local report = addonTable.ProbeReport
  if type(report) ~= "table" or type(report.BuildLines) ~= "function" then
    return
  end
  local entries = type(readLog) == "function" and readLog("[PROBE] ") or {}
  for _, line in ipairs(report.BuildLines(entries, L)) do
    printFn(line)
  end
end

--- /isilive probe [on|off|status|report]; toggles without an argument.
function ProbeLog.HandleCommand(ctx, cmd)
  local printFn = type(ctx.printNoLogFn) == "function" and ctx.printNoLogFn or ctx.printFn or print
  local L = type(ctx.getL) == "function" and ctx.getL() or {}
  local arg = tostring(cmd or ""):match("^probe%s+(%S+)") or ""
  if arg == "report" then
    PrintReport(printFn, L)
    return
  end
  if arg == "status" then
    printFn(
      string.format(
        L.PROBE_LOG_STATUS or "Probe mode: %s | runtime log: %s | probe lines this session: %d",
        ProbeLog.IsEnabled() and "ON" or "OFF",
        IsRuntimeLogOn() and "ON" or "OFF",
        sessionLineCount
      )
    )
    return
  end
  local nextEnabled
  if ARG_ON[arg] then
    nextEnabled = true
  elseif ARG_OFF[arg] then
    nextEnabled = false
  elseif arg == "" then
    nextEnabled = not ProbeLog.IsEnabled()
  else
    printFn(
      L.HELP_PROBE or "  /isilive probe [on|off|status|report] - Probe mode: in-game API checks into the runtime log"
    )
    return
  end
  local enabled = ProbeLog.SetEnabled(nextEnabled)
  if enabled then
    printFn(L.PROBE_LOG_ON or "Probe mode ON: in-game API checks are written to the runtime log.")
    if not IsRuntimeLogOn() then
      printFn(
        L.PROBE_LOG_RUNTIME_OFF
          or "The runtime log is off: only [PROBE] lines are recorded. /isilive log on adds context lines."
      )
    end
  else
    printFn(L.PROBE_LOG_OFF or "Probe mode OFF.")
  end
end
