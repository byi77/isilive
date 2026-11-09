local _, addonTable = ...

addonTable = addonTable or {}

local Stats = {}
addonTable.Stats = Stats
local StringUtils = addonTable.StringUtils
-- Damage-meter fields arrive masked while the key is ending: reading them is
-- safe, but comparing one raises and kills the whole event dispatch. That is
-- what happened at every CHALLENGE_MODE_COMPLETED -- `amountPerSecond >= 0`
-- threw before anything was recorded. `type()` lies about a Secret Value, so
-- every field below goes through the plain readers instead of a type check.
local ReadPlainNumber = addonTable.Validators.ReadPlainNumber
local ReadPlainString = addonTable.Validators.ReadPlainString
local ReadPlainField = addonTable.Validators.ReadPlainField
local IsSecretValue = addonTable.Validators.IsSecretValue

local DAMAGE_METER_TYPE_DAMAGE_DONE = 0
local DAMAGE_METER_SESSION_TYPE_OVERALL = 0
local DAMAGE_METER_SESSION_TYPE_CURRENT = 1

local NORMALIZED_NAME_CACHE_LIMIT = 200
local normalizedNameCache = {}
local normalizedNameCacheSize = 0

local function NormalizeName(name, realm)
  if not name then
    return nil
  end
  local n = tostring(name)
  local explicitName, explicitRealm = string.match(n, "^(.-)%-(.+)$")
  if explicitName and explicitName ~= "" and explicitRealm and explicitRealm ~= "" then
    n = explicitName
    if realm == nil or tostring(realm) == "" then
      realm = explicitRealm
    end
  end
  local r = realm and tostring(realm) or ""
  if r == "" then
    local getRealmName = rawget(_G, "GetRealmName")
    if type(getRealmName) == "function" then
      local ok, realmName = pcall(getRealmName)
      if ok and type(realmName) == "string" then
        r = realmName
      end
    end
  end
  -- Every roster render and DPS tooltip asks for the same few players, so the
  -- normalized key is cached per resolved (name, realm) pair. The cap bounds a
  -- long session full of group changes; dropping the cache only costs one
  -- recomputation per player.
  local byRealm = normalizedNameCache[n]
  local cachedKey = byRealm and byRealm[r]
  if cachedKey then
    return cachedKey
  end
  -- Normalize via shared StringUtils (matches Sync.NormalizePlayerKey):
  local n_clean = StringUtils.StripWhitespace(n)
  local r_clean = StringUtils.NormalizeRealmName(r)
  local key = string.lower(n_clean .. "-" .. r_clean)
  if normalizedNameCacheSize >= NORMALIZED_NAME_CACHE_LIMIT then
    normalizedNameCache = {}
    normalizedNameCacheSize = 0
  end
  if not normalizedNameCache[n] then
    normalizedNameCache[n] = {}
  end
  normalizedNameCache[n][r] = key
  normalizedNameCacheSize = normalizedNameCacheSize + 1
  return key
end

local function EnsureStatsTables()
  -- SavedVariables are restored by Blizzard before ADDON_LOADED and every
  -- public Stats entry point runs from a post-ADDON_LOADED context (the
  -- challenge-mode completion handler and the roster render path). Lazy-
  -- allocating IsiLiveDB here would race the SavedVariables restore on the
  -- (theoretical) pre-load callsite and wipe other settings.
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return
  end
  if not db.stats then
    db.stats = {}
  end
end

local function EnsurePlayerLastRunByCharacterTable(stats)
  if type(stats.playerLastRunByCharacter) ~= "table" then
    stats.playerLastRunByCharacter = {}
  end
  return stats.playerLastRunByCharacter
end

local function ResolveLocalPlayerKey(getUnitNameAndRealm)
  if type(getUnitNameAndRealm) ~= "function" then
    return nil
  end

  local name, realm = getUnitNameAndRealm("player")
  -- UNKNOWNOBJECT is the client's localized placeholder for an unresolved name.
  if name == "Unknown" or name == rawget(_G, "UNKNOWNOBJECT") then
    return nil
  end
  local key = NormalizeName(name, realm)
  -- A name without a resolvable realm yields "name-": that is not a character
  -- identity, and persisting or migrating under it would be a guess.
  return key and string.match(key, "^.+%-.+$") or nil
end

local function MigrateAndPrunePersistentPlayerStats(localPlayerKey)
  EnsureStatsTables()

  local db = rawget(_G, "IsiLiveDB")
  local stats = db and db.stats
  if not stats then
    return false
  end
  local persistentLastRuns = EnsurePlayerLastRunByCharacterTable(stats)
  local legacyLastRuns = type(stats.playerLastRuns) == "table" and stats.playerLastRuns or nil
  if legacyLastRuns and localPlayerKey and type(legacyLastRuns[localPlayerKey]) == "table" then
    persistentLastRuns[localPlayerKey] = legacyLastRuns[localPlayerKey]
  end

  -- The legacy single-slot snapshot has no owner identity attached.
  -- Reassigning it to whichever character logs in first would be a guess,
  -- so it is discarded during migration.
  stats.playerLastRun = nil

  -- Foreign player stats must never persist across sessions.
  stats.dungeons = nil
  stats.players = nil
  stats.playerLastRuns = nil
  return true
end

local function ResolveDamageMeterAPI()
  local api = rawget(_G, "C_DamageMeter")
  if type(api) ~= "table" or type(api.GetCombatSessionFromType) ~= "function" then
    return nil
  end
  return api
end

local function GetCombatSessionFromTypeSafe(api, sessionType, damageMeterType)
  if type(api) ~= "table" then
    return nil
  end

  -- Blizzard signature (DamageMeterDocumentation, 12.1.0): (sessionType, type).
  -- sessionType 0=Overall / 1=Current; type 0=DamageDone.
  local ok, session = pcall(api.GetCombatSessionFromType, sessionType, damageMeterType)
  if not ok or type(session) ~= "table" then
    return nil
  end

  -- `type()` cannot be trusted here either: a masked combatSources table passes
  -- the type check and then raises inside next(). Both reads fail closed.
  local combatSources = ReadPlainField(session, "combatSources")
  if type(combatSources) ~= "table" then
    return nil
  end
  local okNext, firstEntry = pcall(next, combatSources)
  if not okNext or firstEntry == nil then
    return nil
  end

  return session
end

-- Overall is the session the key start reset (CHALLENGE_MODE_START calls
-- ResetAllCombatSessions), so it spans exactly the run. Current is only the
-- last combat segment; it stays a fallback for the capture at the key end,
-- where it can still hold the whole last pull. A late capture after the key
-- (`overallOnly`) never falls back to it: by then Current may already be a
-- fight that has nothing to do with the run.
local function ResolveCompletedRunSession(overallOnly)
  local api = ResolveDamageMeterAPI()
  if not api then
    return nil, nil
  end

  local overallSession =
    GetCombatSessionFromTypeSafe(api, DAMAGE_METER_SESSION_TYPE_OVERALL, DAMAGE_METER_TYPE_DAMAGE_DONE)
  if overallSession then
    return overallSession, DAMAGE_METER_SESSION_TYPE_OVERALL
  end
  if overallOnly then
    return nil, nil
  end

  local currentSession =
    GetCombatSessionFromTypeSafe(api, DAMAGE_METER_SESSION_TYPE_CURRENT, DAMAGE_METER_TYPE_DAMAGE_DONE)
  if currentSession then
    return currentSession, DAMAGE_METER_SESSION_TYPE_CURRENT
  end
  return nil, nil
end

-- Enum.DamageMeterType.Interrupts (warcraft.wiki.gg, 12.0.0), read at run time
-- and never hard-coded: without it the run has no landed kicks.
local function ResolveInterruptsMeterType()
  local enum = rawget(_G, "Enum")
  local types = type(enum) == "table" and enum.DamageMeterType or nil
  local interrupts = type(types) == "table" and types.Interrupts or nil
  if IsSecretValue(interrupts) or type(interrupts) ~= "number" then
    return nil
  end
  return interrupts
end

-- Landed interrupts per normalized player key from the Interrupts session of
-- the same session type the DPS came from (rule 238). Returns nil -- no value
-- for anybody -- when the type, the session or any source is missing, masked
-- or unreadable: only a fully readable list proves that a member who is not
-- in it landed no interrupt. A readable empty list is a run without any
-- landed interrupt.
local function ReadLandedInterrupts(sessionType)
  local api = ResolveDamageMeterAPI()
  local interruptsType = ResolveInterruptsMeterType()
  if not api or not interruptsType or sessionType == nil then
    return nil
  end
  local ok, session = pcall(api.GetCombatSessionFromType, sessionType, interruptsType)
  if not ok or type(session) ~= "table" then
    return nil
  end
  local combatSources = ReadPlainField(session, "combatSources")
  if type(combatSources) ~= "table" then
    return nil
  end
  local counts = {}
  local readable = true
  local okIterate = pcall(function()
    for _, source in ipairs(combatSources) do
      local name = ReadPlainString(source, "name")
      local amount = ReadPlainNumber(source, "totalAmount")
      local key = name and name ~= "" and NormalizeName(name, nil) or nil
      if not key or not amount or amount < 0 then
        readable = false
        return
      end
      counts[key] = (counts[key] or 0) + math.floor(amount + 0.5)
    end
  end)
  if not okIterate or not readable then
    return nil
  end
  return counts
end

-- Joins up to MAX_TRACED_KEYS keys into one sorted, comma-separated string.
-- The capture either matches every group member or none of them, so a handful
-- of keys from each side is enough to tell a lookup miss from an empty session.
local MAX_TRACED_KEYS = 6
local function FormatKeysForTrace(keySet)
  local keys = {}
  for key in pairs(keySet or {}) do
    keys[#keys + 1] = tostring(key)
  end
  table.sort(keys)
  local shown = {}
  for index = 1, math.min(#keys, MAX_TRACED_KEYS) do
    shown[index] = keys[index]
  end
  local text = table.concat(shown, ",")
  if #keys > MAX_TRACED_KEYS then
    text = text .. ",+" .. tostring(#keys - MAX_TRACED_KEYS)
  end
  return text ~= "" and text or "none"
end

-- The second return value is diagnostics only: the caller traces it so a failed
-- capture says which of the three stages broke (no roster, no damage-meter
-- session, or names that do not resolve to the same key on both sides).
local function CaptureRunPerformanceSnapshot(roster, mapID, level, onTime, overallOnly)
  local diagnostics = {
    sessionFound = false,
    sessionType = nil,
    kicksState = "none",
    sourceCount = 0,
    matchedCount = 0,
    maskedCount = 0,
    rosterKeys = {},
    sourceKeys = {},
  }

  if type(roster) ~= "table" then
    return {}, diagnostics
  end

  local session, sessionType = ResolveCompletedRunSession(overallOnly)
  if not session then
    return {}, diagnostics
  end
  diagnostics.sessionFound = true
  diagnostics.sessionType = sessionType

  local rosterByKey = {}
  for _, info in pairs(roster) do
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
      local key = NormalizeName(info.name, info.realm)
      if key then
        rosterByKey[key] = true
        diagnostics.rosterKeys[key] = true
      end
    end
  end

  local durationSeconds = ReadPlainNumber(session, "durationSeconds")
  local snapshot = {}
  for _, source in ipairs(session.combatSources) do
    local sourceName = ReadPlainString(source, "name")
    local dps = ReadPlainNumber(source, "amountPerSecond")
    if sourceName and sourceName ~= "" and dps then
      local key = NormalizeName(sourceName, nil)
      diagnostics.sourceCount = diagnostics.sourceCount + 1
      if key then
        diagnostics.sourceKeys[key] = true
      end
      if key and rosterByKey[key] and dps >= 0 then
        diagnostics.matchedCount = diagnostics.matchedCount + 1
        snapshot[key] = {
          dps = dps,
          totalDamage = ReadPlainNumber(source, "totalAmount"),
          mapID = tonumber(mapID),
          level = tonumber(level),
          onTime = onTime and true or false,
          durationSeconds = durationSeconds,
        }
      end
    else
      -- Masked or unreadable source: counted so the trace shows the difference
      -- between "the meter was empty" and "the meter answered in secrets".
      diagnostics.maskedCount = diagnostics.maskedCount + 1
    end
  end

  -- Landed kicks come from the same pass and the same session type, and only
  -- for members whose DPS was captured: a member of the run who is missing
  -- from a fully readable Interrupts list landed none.
  if next(snapshot) ~= nil then
    local landed = ReadLandedInterrupts(sessionType)
    diagnostics.kicksState = landed and "read" or "unreadable"
    if landed then
      for key, entry in pairs(snapshot) do
        entry.kicksLanded = landed[key] or 0
      end
    end
  end

  return snapshot, diagnostics
end

function Stats.CreateController(opts)
  opts = opts or {}
  local getRoster = opts.getRoster
  local getUnitNameAndRealm = opts.getUnitNameAndRealm
  local logRuntimeTracef = type(opts.logRuntimeTracef) == "function" and opts.logRuntimeTracef or nil
  local getPeerRunKicksCast = type(opts.getPeerRunKicksCast) == "function" and opts.getPeerRunKicksCast or nil

  -- localPlayerKey and migration are intentionally lazy-initialized:
  -- Stats.CreateController() runs at Lua load time, before ADDON_LOADED fires.
  -- At that point the player unit may not exist yet (UnitExists("player") can
  -- return false) and SavedVariables (IsiLiveDB) are not yet restored.
  local localPlayerKey = nil
  local migrated = false
  local sessionPlayerLastRuns = {}
  local sessionPlayerLastRunMisses = {}
  -- Run kicks belong to the last run only (rule 238): a key start hides them
  -- until that key is captured. DPS keeps its last-captured value.
  local runKicksSuperseded = false

  local function PersistOwnRun(selfRun)
    local db = rawget(_G, "IsiLiveDB")
    if selfRun and localPlayerKey and db and db.stats then
      EnsurePlayerLastRunByCharacterTable(db.stats)[localPlayerKey] = selfRun
    end
  end

  -- Identity and database become ready independently, so each is retried until
  -- it is there. The migration deletes the legacy tables and therefore waits
  -- for both; a run captured in the meantime stays in the session snapshot and
  -- reaches the character key here.
  local function EnsureInitialized()
    if migrated then
      return
    end
    localPlayerKey = localPlayerKey or ResolveLocalPlayerKey(getUnitNameAndRealm)
    if not localPlayerKey then
      return
    end
    migrated = MigrateAndPrunePersistentPlayerStats(localPlayerKey)
    if migrated then
      PersistOwnRun(sessionPlayerLastRuns[localPlayerKey])
    end
  end

  local controller = {}

  -- captureOpts (optional): overallOnly restricts the capture to the Overall
  -- session (late capture after the key), phase and trigger only label the
  -- trace line ("initial", "retry", "late"), kicksCast is the own interrupt
  -- cast count of the run and kicksMissed the own missed kicks of it (rule
  -- 240); each is nil when unknown.
  function controller.RecordRun(mapID, level, onTime, rosterOverride, captureOpts)
    if not mapID then
      return false
    end
    captureOpts = type(captureOpts) == "table" and captureOpts or {}

    EnsureInitialized()
    EnsureStatsTables()

    local roster = type(rosterOverride) == "table" and rosterOverride or (getRoster and getRoster())
    local runSnapshot, diagnostics =
      CaptureRunPerformanceSnapshot(roster, mapID, level, onTime, captureOpts.overallOnly == true)
    local recordedAnyPlayer = next(runSnapshot) ~= nil

    if type(logRuntimeTracef) == "function" and type(diagnostics) == "table" then
      -- One line per attempt, retries included. It names the stage that failed:
      -- session=false is a damage meter with nothing to read, matched=0 with a
      -- non-zero sourceCount is a key mismatch between meter and roster, and
      -- masked>0 is a meter that still answers in secrets (key end); the late
      -- capture after the key shows up as phase=late with its trigger.
      logRuntimeTracef(
        "[STATS] record_run phase=%s trigger=%s mapID=%s level=%s session=%s sessionType=%s sources=%d "
          .. "matched=%d masked=%d kicks=%s kicksCast=%s kicksMissed=%s playerKey=%s rosterKeys=%s sourceKeys=%s",
        tostring(captureOpts.phase or "initial"),
        tostring(captureOpts.trigger or "-"),
        tostring(mapID),
        tostring(level),
        tostring(diagnostics.sessionFound),
        tostring(diagnostics.sessionType),
        diagnostics.sourceCount,
        diagnostics.matchedCount,
        diagnostics.maskedCount,
        tostring(diagnostics.kicksState),
        tostring(captureOpts.kicksCast),
        tostring(captureOpts.kicksMissed),
        tostring(localPlayerKey),
        FormatKeysForTrace(diagnostics.rosterKeys),
        FormatKeysForTrace(diagnostics.sourceKeys)
      )
    end

    if not recordedAnyPlayer then
      -- Nothing was captured: the damage meter had no usable session for this
      -- run (the caller retries) or the run ended somewhere the meter no longer
      -- reports. Publishing the empty snapshot here wiped the previous run and
      -- marked every roster member as a miss, so the DPS column fell back to
      -- "-" for the rest of the session -- including the local player, whose
      -- persisted last run is suppressed by the miss table. An uncaptured run
      -- must leave the last captured run untouched.
      return false
    end

    local ownEntry = localPlayerKey and runSnapshot[localPlayerKey] or nil
    local kicksCast = tonumber(captureOpts.kicksCast)
    if ownEntry and kicksCast and kicksCast >= 0 then
      ownEntry.kicksCast = math.floor(kicksCast)
      local kicksMissed = tonumber(captureOpts.kicksMissed)
      if kicksMissed and kicksMissed >= 0 and kicksMissed <= ownEntry.kicksCast then
        ownEntry.kicksMissed = math.floor(kicksMissed)
      end
    end

    sessionPlayerLastRuns = runSnapshot
    sessionPlayerLastRunMisses = {}
    runKicksSuperseded = false
    for _, info in pairs(roster or {}) do
      if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
        local key = NormalizeName(info.name, info.realm)
        if key and runSnapshot[key] == nil then
          sessionPlayerLastRunMisses[key] = true
        end
      end
    end

    PersistOwnRun(localPlayerKey and runSnapshot[localPlayerKey] or nil)

    return recordedAnyPlayer
  end

  local function GetPlayerLastRunInfo(name, realm)
    EnsureInitialized()
    local db = rawget(_G, "IsiLiveDB")
    if not name or not db or not db.stats then
      return nil
    end
    local key = NormalizeName(name, realm)
    local info = key and sessionPlayerLastRuns[key] or nil
    if key and sessionPlayerLastRunMisses[key] == true then
      return nil
    end
    if type(info) ~= "table" and key and localPlayerKey and key == localPlayerKey then
      local persistentLastRuns = type(db.stats.playerLastRunByCharacter) == "table"
          and db.stats.playerLastRunByCharacter
        or nil
      info = persistentLastRuns and persistentLastRuns[localPlayerKey] or nil
    end
    return type(info) == "table" and info or nil
  end

  function controller.GetPlayerLastRunDps(name, realm)
    local info = GetPlayerLastRunInfo(name, realm)
    return info and tonumber(info.dps) or nil
  end

  local function ReadCount(value)
    local number = tonumber(value)
    if not number or number < 0 or number ~= math.floor(number) then
      return nil
    end
    return number
  end

  --- Kicks of the last captured run for one member (rule 238), or nil.
  -- landed comes from the damage meter; cast is the member's own count --
  -- the local player's from the kick tracker, a peer's from its KC sync when
  -- it names the same map and key level. A cast count below the landed one
  -- is incomplete and dropped. missed (rule 240) comes from the same source
  -- as cast and only stands next to it, never above it.
  -- @return table|nil {landed:number, cast:number|nil, missed:number|nil}
  function controller.GetPlayerLastRunKicks(name, realm)
    if runKicksSuperseded then
      return nil
    end
    local info = GetPlayerLastRunInfo(name, realm)
    local landed = info and ReadCount(info.kicksLanded) or nil
    if not landed then
      return nil
    end
    local cast = ReadCount(info.kicksCast)
    local missed = cast and ReadCount(info.kicksMissed) or nil
    if cast == nil and getPeerRunKicksCast then
      local peer = getPeerRunKicksCast(name, realm)
      if
        type(peer) == "table"
        and tonumber(peer.mapID) == tonumber(info.mapID)
        and tonumber(peer.level) == tonumber(info.level)
      then
        cast = ReadCount(peer.cast)
        missed = cast and ReadCount(peer.missed) or nil
      end
    end
    if cast and cast < landed then
      cast = nil
    end
    if not cast or (missed and missed > cast) then
      missed = nil
    end
    return { landed = landed, cast = cast, missed = missed }
  end

  --- True when some member has run kicks to show. Costs no API call, so the
  -- roster asks it before reading the key state on every kick refresh.
  -- @return boolean
  function controller.HasRunKicks()
    if runKicksSuperseded then
      return false
    end
    for _, entry in pairs(sessionPlayerLastRuns) do
      if type(entry) == "table" and ReadCount(entry.kicksLanded) then
        return true
      end
    end
    EnsureInitialized()
    local own = localPlayerKey and GetPlayerLastRunInfo(localPlayerKey) or nil
    return own ~= nil and ReadCount(own.kicksLanded) ~= nil
  end

  --- Own interrupt casts (and missed kicks, rule 240) of the last captured run
  -- for the KC/KM sync suffix, or nil.
  -- @return table|nil {cast, mapID, level, missed}
  function controller.GetOwnRunKicks()
    EnsureInitialized()
    local info = localPlayerKey and GetPlayerLastRunInfo(localPlayerKey) or nil
    local cast = info and ReadCount(info.kicksCast) or nil
    local mapID = info and tonumber(info.mapID) or nil
    if not cast or not mapID then
      return nil
    end
    local missed = ReadCount(info.kicksMissed)
    if missed and missed > cast then
      missed = nil
    end
    return { cast = cast, mapID = mapID, level = tonumber(info.level) or 0, missed = missed }
  end

  --- Hides the run kicks of the previous key while a new key runs (called at
  -- CHALLENGE_MODE_START); the next captured run shows its own.
  function controller.MarkRunStarted()
    runKicksSuperseded = true
  end

  -- Runs the real capture against the live damage meter and current roster
  -- without publishing anything, so the three stages can be inspected at any
  -- time -- the run-completion trace only answers while a key is ending, which
  -- makes every diagnosis cost a full key.
  function controller.BuildCaptureDumpLines()
    EnsureInitialized()

    local lines = {}
    local roster = (getRoster and getRoster()) or {}
    local _, diagnostics = CaptureRunPerformanceSnapshot(roster, nil, nil, nil)
    diagnostics = type(diagnostics) == "table" and diagnostics or {}

    lines[#lines + 1] = string.format(
      "[DPS] meterApi=%s session=%s sources=%s matched=%s playerKey=%s",
      ResolveDamageMeterAPI() and "available" or "missing",
      tostring(diagnostics.sessionFound),
      tostring(diagnostics.sourceCount),
      tostring(diagnostics.matchedCount),
      tostring(localPlayerKey)
    )
    lines[#lines + 1] = "[DPS] rosterKeys=" .. FormatKeysForTrace(diagnostics.rosterKeys)
    lines[#lines + 1] = "[DPS] sourceKeys=" .. FormatKeysForTrace(diagnostics.sourceKeys)

    for unit, info in pairs(roster) do
      if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
        local key = NormalizeName(info.name, info.realm)
        lines[#lines + 1] = string.format(
          "[DPS] unit=%s name=%s realm=%s key=%s shown=%s miss=%s",
          tostring(unit),
          tostring(info.name),
          tostring(info.realm),
          tostring(key),
          tostring(controller.GetPlayerLastRunDps(info.name, info.realm)),
          tostring(key ~= nil and sessionPlayerLastRunMisses[key] == true)
        )
      end
    end

    local db = rawget(_G, "IsiLiveDB")
    local persistentLastRuns = type(db) == "table"
        and type(db.stats) == "table"
        and type(db.stats.playerLastRunByCharacter) == "table"
        and db.stats.playerLastRunByCharacter
      or nil
    local persistedSelf = persistentLastRuns and localPlayerKey and persistentLastRuns[localPlayerKey] or nil
    lines[#lines + 1] = string.format(
      "[DPS] persistedSelfDps=%s persistedSelfMapID=%s sessionEntries=%s",
      tostring(persistedSelf and persistedSelf.dps),
      tostring(persistedSelf and persistedSelf.mapID),
      tostring(FormatKeysForTrace(sessionPlayerLastRuns))
    )

    return lines
  end

  function controller.PrintCaptureDump(printFn)
    printFn = type(printFn) == "function" and printFn or print
    for _, line in ipairs(controller.BuildCaptureDumpLines()) do
      printFn(line)
    end
  end

  return controller
end
