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

local DAMAGE_METER_TYPE_DAMAGE_DONE = 0
local DAMAGE_METER_SESSION_TYPE_OVERALL = 0
local DAMAGE_METER_SESSION_TYPE_CURRENT = 1

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
  -- Normalize via shared StringUtils (matches Sync.NormalizePlayerKey):
  local n_clean = StringUtils.StripWhitespace(n)
  local r_clean = StringUtils.NormalizeRealmName(r)
  return string.lower(n_clean .. "-" .. r_clean)
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
  return NormalizeName(name, realm)
end

local function MigrateAndPrunePersistentPlayerStats(localPlayerKey)
  EnsureStatsTables()

  local db = rawget(_G, "IsiLiveDB")
  local stats = db and db.stats
  if not stats then
    return
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

  -- Parameterreihenfolge: (damageMeterType, sessionType)
  -- 0=Damage/0=Overall; 0=Damage/1=Current
  local ok, session = pcall(api.GetCombatSessionFromType, damageMeterType, sessionType)
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

local function ResolveCompletedRunSession()
  local api = ResolveDamageMeterAPI()
  if not api then
    return nil
  end

  local overallSession =
    GetCombatSessionFromTypeSafe(api, DAMAGE_METER_SESSION_TYPE_OVERALL, DAMAGE_METER_TYPE_DAMAGE_DONE)
  if overallSession then
    return overallSession
  end

  return GetCombatSessionFromTypeSafe(api, DAMAGE_METER_SESSION_TYPE_CURRENT, DAMAGE_METER_TYPE_DAMAGE_DONE)
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
local function CaptureRunPerformanceSnapshot(roster, mapID, level, onTime)
  local diagnostics = {
    sessionFound = false,
    sourceCount = 0,
    matchedCount = 0,
    maskedCount = 0,
    rosterKeys = {},
    sourceKeys = {},
  }

  if type(roster) ~= "table" then
    return {}, diagnostics
  end

  local session = ResolveCompletedRunSession()
  if not session then
    return {}, diagnostics
  end
  diagnostics.sessionFound = true

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

  return snapshot, diagnostics
end

function Stats.CreateController(opts)
  opts = opts or {}
  local getRoster = opts.getRoster
  local getUnitNameAndRealm = opts.getUnitNameAndRealm
  local logRuntimeTracef = type(opts.logRuntimeTracef) == "function" and opts.logRuntimeTracef or nil

  -- localPlayerKey and migration are intentionally lazy-initialized:
  -- Stats.CreateController() runs at Lua load time, before ADDON_LOADED fires.
  -- At that point the player unit may not exist yet (UnitExists("player") can
  -- return false) and SavedVariables (IsiLiveDB) are not yet restored.
  local localPlayerKey = nil
  local initialized = false
  local sessionPlayerLastRuns = {}
  local sessionPlayerLastRunMisses = {}

  local function EnsureInitialized()
    if initialized then
      return
    end
    initialized = true
    localPlayerKey = ResolveLocalPlayerKey(getUnitNameAndRealm)
    MigrateAndPrunePersistentPlayerStats(localPlayerKey)
  end

  local controller = {}

  function controller.RecordRun(mapID, level, onTime, rosterOverride)
    if not mapID then
      return false
    end

    EnsureInitialized()
    EnsureStatsTables()

    local roster = type(rosterOverride) == "table" and rosterOverride or (getRoster and getRoster())
    local runSnapshot, diagnostics = CaptureRunPerformanceSnapshot(roster, mapID, level, onTime)
    local recordedAnyPlayer = next(runSnapshot) ~= nil

    if type(logRuntimeTracef) == "function" and type(diagnostics) == "table" then
      -- One line per attempt, retries included. It names the stage that failed:
      -- session=false is a damage meter with nothing to read, matched=0 with a
      -- non-zero sourceCount is a key mismatch between meter and roster.
      logRuntimeTracef(
        "[STATS] record_run mapID=%s level=%s session=%s sources=%d matched=%d masked=%d "
          .. "playerKey=%s rosterKeys=%s sourceKeys=%s",
        tostring(mapID),
        tostring(level),
        tostring(diagnostics.sessionFound),
        diagnostics.sourceCount,
        diagnostics.matchedCount,
        diagnostics.maskedCount,
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

    sessionPlayerLastRuns = runSnapshot
    sessionPlayerLastRunMisses = {}
    for _, info in pairs(roster or {}) do
      if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
        local key = NormalizeName(info.name, info.realm)
        if key and runSnapshot[key] == nil then
          sessionPlayerLastRunMisses[key] = true
        end
      end
    end

    local selfRun = localPlayerKey and runSnapshot[localPlayerKey] or nil
    if selfRun and localPlayerKey then
      local db = rawget(_G, "IsiLiveDB")
      if db and db.stats then
        EnsurePlayerLastRunByCharacterTable(db.stats)[localPlayerKey] = selfRun
      end
    end

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
