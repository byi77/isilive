local _, addonTable = ...

addonTable = addonTable or {}

local Stats = {}
addonTable.Stats = Stats

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
    local getRealmName = _G.GetRealmName
    if type(getRealmName) == "function" then
      local ok, realmName = pcall(getRealmName)
      if ok and type(realmName) == "string" then
        r = realmName
      end
    end
  end
  return string.lower(n .. "-" .. r)
end

local function EnsureStatsTables()
  if not IsiLiveDB then
    IsiLiveDB = {}
  end
  if not IsiLiveDB.stats then
    IsiLiveDB.stats = {}
  end
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

  local stats = IsiLiveDB.stats
  if type(stats.playerLastRun) ~= "table" then
    local legacyLastRuns = type(stats.playerLastRuns) == "table" and stats.playerLastRuns or nil
    if legacyLastRuns and localPlayerKey and type(legacyLastRuns[localPlayerKey]) == "table" then
      stats.playerLastRun = legacyLastRuns[localPlayerKey]
    end
  end

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

  -- Parameterreihenfolge: WoW-Doku ggf. prüfen (damageMeterType vs. sessionType).
  -- Derzeit harmlos da beide Konstanten den Wert 0 haben.
  local ok, session = pcall(api.GetCombatSessionFromType, sessionType, damageMeterType)
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

function Stats.CreateController(opts)
  opts = opts or {}
  local getRoster = opts.getRoster
  local getUnitNameAndRealm = opts.getUnitNameAndRealm

  local localPlayerKey = ResolveLocalPlayerKey(getUnitNameAndRealm)
  local sessionPlayerLastRuns = {}

  MigrateAndPrunePersistentPlayerStats(localPlayerKey)

  local controller = {}

  function controller.RecordRun(mapID, level, onTime, rosterOverride)
    if not mapID then
      return
    end

    EnsureStatsTables()

    local roster = type(rosterOverride) == "table" and rosterOverride or (getRoster and getRoster())
    local runSnapshot = CaptureRunPerformanceSnapshot(roster, mapID, level, onTime)
    sessionPlayerLastRuns = runSnapshot

    local selfRun = localPlayerKey and runSnapshot[localPlayerKey] or nil
    if selfRun then
      IsiLiveDB.stats.playerLastRun = selfRun
    end
  end

  function controller.GetPlayerLastRunDps(name, realm)
    if not name or not IsiLiveDB or not IsiLiveDB.stats then
      return nil
    end
    local key = NormalizeName(name, realm)
    local info = key and sessionPlayerLastRuns[key] or nil
    if type(info) ~= "table" and key and localPlayerKey and key == localPlayerKey then
      info = IsiLiveDB.stats.playerLastRun
    end
    if type(info) ~= "table" then
      return nil
    end
    return tonumber(info.dps)
  end

  return controller
end
