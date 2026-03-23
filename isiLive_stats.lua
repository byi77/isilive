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
          deaths = tonumber(source.deathCount),
          kicks = tonumber(source.interruptCount),
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

function Stats.CreateController(opts)
  opts = opts or {}
  local getRoster = opts.getRoster
  local getUnitNameAndRealm = opts.getUnitNameAndRealm

  -- localPlayerKey und Migration werden bewusst lazy initialisiert:
  -- Stats.CreateController() wird zur Lua-Ladezeit aufgerufen, bevor
  -- ADDON_LOADED feuert. Zu diesem Zeitpunkt existiert die Spielereinheit
  -- noch nicht sicher (UnitExists("player") kann false liefern) und die
  -- SavedVariables (IsiLiveDB) sind noch nicht wiederhergestellt.
  local localPlayerKey = nil
  local initialized = false
  local sessionPlayerLastRuns = {}

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

  function controller.GetPlayerLastRunDeaths(name, realm)
    local info = GetPlayerLastRunInfo(name, realm)
    return info and tonumber(info.deaths) or nil
  end

  function controller.GetPlayerLastRunKicks(name, realm)
    local info = GetPlayerLastRunInfo(name, realm)
    return info and tonumber(info.kicks) or nil
  end

  return controller
end
