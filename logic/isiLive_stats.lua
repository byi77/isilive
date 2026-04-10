local _, addonTable = ...

addonTable = addonTable or {}

local Stats = {}
addonTable.Stats = Stats
local StringUtils = addonTable.StringUtils

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
  local db = rawget(_G, "IsiLiveDB")
  if not db then
    db = {}
    IsiLiveDB = db
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

local function EnsurePlayerLastKickStatsByCharacterTable(stats)
  if type(stats.playerLastKickStatsByCharacter) ~= "table" then
    stats.playerLastKickStatsByCharacter = {}
  end
  return stats.playerLastKickStatsByCharacter
end

local function NormalizeKickStats(stats)
  if type(stats) ~= "table" then
    return nil
  end

  local kicks = math.max(0, math.floor(tonumber(stats.kicks) or 0))
  local failed = math.max(0, math.floor(tonumber(stats.failed) or 0))
  local missed = math.max(0, math.floor(tonumber(stats.missed) or 0))

  if kicks == 0 and failed == 0 and missed == 0 then
    return nil
  end

  return {
    kicks = kicks,
    failed = failed,
    missed = missed,
  }
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
  if type(session.combatSources) ~= "table" or next(session.combatSources) == nil then
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

local function CaptureRunPerformanceSnapshot(roster, mapID, level, onTime)
  if type(roster) ~= "table" then
    return {}
  end

  local session = ResolveCompletedRunSession()
  if not session then
    return {}
  end

  local rosterByKey = {}
  for _, info in pairs(roster) do
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
      local key = NormalizeName(info.name, info.realm)
      if key then
        rosterByKey[key] = true
      end
    end
  end

  local snapshot = {}
  for _, source in ipairs(session.combatSources) do
    if type(source) == "table" and type(source.name) == "string" and source.name ~= "" then
      local key = NormalizeName(source.name, nil)
      local dps = tonumber(source.amountPerSecond)
      if key and rosterByKey[key] and dps and dps >= 0 then
        snapshot[key] = {
          dps = dps,
          totalDamage = tonumber(source.totalAmount),
          mapID = tonumber(mapID),
          level = tonumber(level),
          onTime = onTime and true or false,
          durationSeconds = tonumber(session.durationSeconds),
        }
      end
    end
  end

  return snapshot
end

local function ResolveRosterEntryBySourceGUID(roster, sourceGUID)
  if type(roster) ~= "table" or type(sourceGUID) ~= "string" or sourceGUID == "" then
    return nil
  end

  local unitExists = rawget(_G, "UnitExists")
  local unitGUID = rawget(_G, "UnitGUID")
  if type(unitGUID) ~= "function" then
    return nil
  end

  local function MatchesToken(unitToken)
    if type(unitToken) ~= "string" or unitToken == "" then
      return false
    end
    local okGuid, guid = pcall(unitGUID, unitToken)
    return okGuid and guid == sourceGUID
  end

  for unit, info in pairs(roster) do
    if type(unit) == "string" and unit ~= "" and type(info) == "table" and info.isGhost ~= true then
      local exists = true
      if type(unitExists) == "function" then
        local okExists, unitExistsResult = pcall(unitExists, unit)
        exists = okExists and unitExistsResult == true
      end
      if exists then
        local okGuid, guid = pcall(unitGUID, unit)
        if okGuid and guid == sourceGUID then
          return unit, info
        end
        if unit == "player" then
          if MatchesToken("pet") or MatchesToken("playerpet") then
            return unit, info
          end
        elseif MatchesToken(unit .. "pet") then
          return unit, info
        end
      end
    end
  end

  return nil
end

local function BuildKickSpellIDSet(info)
  if type(info) ~= "table" then
    return nil
  end

  local spellIDs = {}
  local function AddSpellID(spellID)
    if type(spellID) == "number" then
      spellIDs[spellID] = true
    end
  end

  local kickSlots = type(info.kickSlots) == "table" and info.kickSlots or nil
  if type(kickSlots) == "table" then
    for _, slot in ipairs(kickSlots) do
      if type(slot) == "table" then
        AddSpellID(slot.spellID)
      end
    end
  end

  local syncKickSlots = type(info.syncKickSlots) == "table" and info.syncKickSlots or nil
  if type(syncKickSlots) == "table" then
    for _, slot in ipairs(syncKickSlots) do
      if type(slot) == "table" then
        AddSpellID(slot.spellID)
      end
    end
  end

  AddSpellID(info.spellID)

  if next(spellIDs) == nil then
    return nil
  end

  return spellIDs
end

local function CloneKickStats(stats)
  local normalized = NormalizeKickStats(stats)
  if not normalized then
    return nil
  end

  return {
    kicks = normalized.kicks,
    failed = normalized.failed,
    missed = normalized.missed,
  }
end

function Stats.CreateController(opts)
  opts = opts or {}
  local getRoster = opts.getRoster
  local getUnitNameAndRealm = opts.getUnitNameAndRealm
  local isInChallengeMode = type(opts.isInChallengeMode) == "function" and opts.isInChallengeMode or nil

  -- localPlayerKey und Migration werden bewusst lazy initialisiert:
  -- Stats.CreateController() wird zur Lua-Ladezeit aufgerufen, bevor
  -- ADDON_LOADED feuert. Zu diesem Zeitpunkt existiert die Spielereinheit
  -- noch nicht sicher (UnitExists("player") kann false liefern) und die
  -- SavedVariables (IsiLiveDB) sind noch nicht wiederhergestellt.
  local localPlayerKey = nil
  local initialized = false
  local sessionPlayerLastRuns = {}
  local sessionPlayerKickStats = {}

  local function EnsureInitialized()
    if initialized then
      return
    end
    initialized = true
    localPlayerKey = ResolveLocalPlayerKey(getUnitNameAndRealm)
    MigrateAndPrunePersistentPlayerStats(localPlayerKey)
  end

  local controller = {}

  local function GetSessionKickStatsByKey(key)
    if type(key) ~= "string" or key == "" then
      return nil
    end

    local stats = sessionPlayerKickStats[key]
    if type(stats) == "table" then
      return stats
    end

    if type(isInChallengeMode) == "function" and isInChallengeMode() then
      return nil
    end

    local db = rawget(_G, "IsiLiveDB")
    local persistentKickStats = db
        and db.stats
        and type(db.stats.playerLastKickStatsByCharacter) == "table"
        and db.stats.playerLastKickStatsByCharacter
      or nil
    local persistent = persistentKickStats and persistentKickStats[key] or nil
    if type(persistent) ~= "table" then
      return nil
    end

    return CloneKickStats(persistent)
  end

  function controller.RecordRun(mapID, level, onTime, rosterOverride)
    if not mapID then
      return false
    end

    EnsureInitialized()
    EnsureStatsTables()

    local roster = type(rosterOverride) == "table" and rosterOverride or (getRoster and getRoster())
    local runSnapshot = CaptureRunPerformanceSnapshot(roster, mapID, level, onTime)
    sessionPlayerLastRuns = runSnapshot
    local recordedAnyPlayer = next(runSnapshot) ~= nil

    local selfRun = localPlayerKey and runSnapshot[localPlayerKey] or nil
    if selfRun and localPlayerKey then
      local db = rawget(_G, "IsiLiveDB")
      if db and db.stats then
        EnsurePlayerLastRunByCharacterTable(db.stats)[localPlayerKey] = selfRun
      end
    end

    local db = rawget(_G, "IsiLiveDB")
    if db and db.stats then
      local persistentKickStats = EnsurePlayerLastKickStatsByCharacterTable(db.stats)
      for key, kickStats in pairs(sessionPlayerKickStats) do
        persistentKickStats[key] = CloneKickStats(kickStats)
      end
    end

    return recordedAnyPlayer
  end

  function controller.ResetKickStats()
    sessionPlayerKickStats = {}
  end

  function controller.RecordKickCombatLogEvent(timestamp, subevent, sourceGUID, spellID, missType, rosterOverride)
    if type(timestamp) ~= "number" or type(subevent) ~= "string" then
      return false
    end
    if type(sourceGUID) ~= "string" or sourceGUID == "" then
      return false
    end

    EnsureInitialized()

    local roster = type(rosterOverride) == "table" and rosterOverride or (getRoster and getRoster())
    local unit, info = ResolveRosterEntryBySourceGUID(roster, sourceGUID)
    if not unit or type(info) ~= "table" or type(info.name) ~= "string" or info.name == "" then
      return false
    end

    local spellIDs = BuildKickSpellIDSet(info)
    if not spellIDs or type(spellID) ~= "number" or not spellIDs[spellID] then
      return false
    end

    local key = NormalizeName(info.name, info.realm)
    if not key then
      return false
    end

    local stats = sessionPlayerKickStats[key]
    if type(stats) ~= "table" then
      stats = {
        kicks = 0,
        failed = 0,
        missed = 0,
      }
      sessionPlayerKickStats[key] = stats
    end

    if subevent == "SPELL_INTERRUPT" then
      stats.kicks = stats.kicks + 1
    elseif subevent == "SPELL_MISSED" then
      if type(missType) == "string" and missType ~= "" then
        stats.missed = stats.missed + 1
      end
    elseif subevent == "SPELL_CAST_FAILED" then
      stats.failed = stats.failed + 1
    end

    return true
  end

  local function GetPlayerLastRunInfo(name, realm)
    EnsureInitialized()
    local db = rawget(_G, "IsiLiveDB")
    if not name or not db or not db.stats then
      return nil
    end
    local key = NormalizeName(name, realm)
    local info = key and sessionPlayerLastRuns[key] or nil
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

  function controller.GetPlayerKickStats(name, realm)
    EnsureInitialized()
    if not name then
      return nil
    end

    local key = NormalizeName(name, realm)
    local stats = key and GetSessionKickStatsByKey(key) or nil
    if not stats then
      return nil
    end

    return {
      kicks = stats.kicks,
      failed = stats.failed,
      missed = stats.missed,
    }
  end

  return controller
end
