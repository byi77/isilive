local _, addonTable = ...
addonTable = addonTable or {}

local DeathWatch = {}
addonTable.DeathWatch = DeathWatch

-- Units watched for death transitions. UNIT_HEALTH cannot be registered via
-- RegisterUnitEvent for five tokens (two-unit API limit), so the dispatcher
-- registers it unfiltered and this lookup drops everything but the party.
local WATCHED_UNITS = {
  player = true,
  party1 = true,
  party2 = true,
  party3 = true,
  party4 = true,
}

local DEATH_TTS_BURST_PAUSE_SECONDS = 30

local function DefaultGetTime()
  local fn = rawget(_G, "GetTime")
  if type(fn) ~= "function" then
    return 0
  end
  local ok, value = pcall(fn)
  if not ok then
    return 0
  end
  return tonumber(value) or 0
end

local function DefaultIsInKey()
  local api = rawget(_G, "C_ChallengeMode")
  if type(api) ~= "table" or type(api.GetActiveChallengeMapID) ~= "function" then
    return false
  end
  local ok, mapID = pcall(api.GetActiveChallengeMapID)
  if not ok then
    return false
  end
  return type(mapID) == "number" and mapID > 0
end

local function DefaultUnitExists(unit)
  local fn = rawget(_G, "UnitExists")
  if type(fn) ~= "function" then
    return false
  end
  local ok, value = pcall(fn, unit)
  return ok and value == true
end

-- pcall-guarded against WoW 12.0 Secret Values: fail-closed, an unreadable
-- value is treated as "not dead" so a masked read can never fire an alert.
local function DefaultUnitIsDeadOrGhost(unit)
  local fn = rawget(_G, "UnitIsDeadOrGhost")
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, unit)
  if not ok then
    return nil
  end
  return value == true
end

local function DefaultUnitIsConnected(unit)
  local fn = rawget(_G, "UnitIsConnected")
  if type(fn) ~= "function" then
    return true
  end
  local ok, value = pcall(fn, unit)
  if not ok then
    return true
  end
  return value ~= false
end

local function DefaultUnitGUID(unit)
  local fn = rawget(_G, "UnitGUID")
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, unit)
  if not ok or type(value) ~= "string" or value == "" then
    return nil
  end
  return value
end

local function DefaultGetUnitRole(unit)
  local units = addonTable.Units
  if type(units) == "table" and type(units.GetUnitRole) == "function" then
    return units.GetUnitRole(unit)
  end
  return "NONE"
end

local function DefaultGetUnitNameAndRealm(unit)
  local units = addonTable.Units
  if type(units) == "table" and type(units.GetUnitNameAndRealm) == "function" then
    return units.GetUnitNameAndRealm(unit)
  end
  local unitName = rawget(_G, "UnitName")
  if type(unitName) ~= "function" then
    return nil, nil
  end
  local ok, name, realm = pcall(unitName, unit)
  if not ok or type(name) ~= "string" or name == "" then
    return nil, nil
  end
  if type(realm) ~= "string" or realm == "" then
    realm = nil
  end
  return name, realm
end

local function PlayerKey(name, realm)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name .. "-" .. (type(realm) == "string" and realm or "")
end

local function CopyDeathSummary(entry)
  if type(entry) ~= "table" then
    return nil
  end
  return {
    name = entry.name,
    realm = entry.realm,
    role = entry.role,
    count = entry.count,
  }
end

function DeathWatch.CreateController(opts)
  opts = opts or {}
  local isInKey = type(opts.isInKey) == "function" and opts.isInKey or DefaultIsInKey
  local unitExists = type(opts.unitExists) == "function" and opts.unitExists or DefaultUnitExists
  local unitIsDeadOrGhost = type(opts.unitIsDeadOrGhost) == "function" and opts.unitIsDeadOrGhost
    or DefaultUnitIsDeadOrGhost
  local unitIsConnected = type(opts.unitIsConnected) == "function" and opts.unitIsConnected or DefaultUnitIsConnected
  local unitGUID = type(opts.unitGUID) == "function" and opts.unitGUID or DefaultUnitGUID
  local getUnitRole = type(opts.getUnitRole) == "function" and opts.getUnitRole or DefaultGetUnitRole
  local getUnitNameAndRealm = type(opts.getUnitNameAndRealm) == "function" and opts.getUnitNameAndRealm
    or DefaultGetUnitNameAndRealm
  local getTime = type(opts.getTime) == "function" and opts.getTime or DefaultGetTime
  local getDB = type(opts.getDB) == "function" and opts.getDB
    or function()
      return rawget(_G, "IsiLiveDB") or {}
    end
  local onRoleDeath = type(opts.onRoleDeath) == "function" and opts.onRoleDeath or function(_role, _unit) end

  local controller = {}
  -- Edge-triggered dead flags keyed by GUID, not by unit token: party tokens
  -- shift on roster changes, a GUID stays with the player. Only the
  -- alive -> dead transition fires; repeated UNIT_HEALTH ticks while dead and
  -- the dead -> ghost transition (both report dead) stay silent.
  local deadByGuid = {}
  local deadRoleByGuid = {}
  local deathSummaryByGuid = {}
  local guidByPlayerKey = {}
  local previousDeathGuid = nil
  local sequentialDifferentDeaths = 0
  local deathTtsPausedUntil = 0
  -- Same in-key cache pattern as CombatEvents: invalidated via Reset() on
  -- CHALLENGE_MODE_START / COMPLETED / RESET, the only events that change it.
  local cachedInKey = nil

  local function IsInKeyCached()
    if cachedInKey == nil then
      cachedInKey = isInKey() == true
    end
    return cachedInKey
  end

  local function IsEnabled()
    local db = getDB() or {}
    return db.deathAlertEnabled ~= false
  end

  local function HasDeadTankAndHealer()
    local tankDead = false
    local healerDead = false
    for _, role in pairs(deadRoleByGuid) do
      if role == "TANK" then
        tankDead = true
      elseif role == "HEALER" then
        healerDead = true
      end
      if tankDead and healerDead then
        return true
      end
    end
    return false
  end

  local function GetNow()
    return tonumber(getTime()) or 0
  end

  local function IsDeathTtsPaused(now)
    return tonumber(deathTtsPausedUntil) and now < deathTtsPausedUntil
  end

  local function UpdateDeathTtsBurstPause(guid, now)
    if IsDeathTtsPaused(now) then
      return true
    end
    if tonumber(deathTtsPausedUntil) and deathTtsPausedUntil > 0 then
      previousDeathGuid = nil
      sequentialDifferentDeaths = 0
      deathTtsPausedUntil = 0
    end
    local suppressTts = false
    if previousDeathGuid and previousDeathGuid ~= guid then
      sequentialDifferentDeaths = sequentialDifferentDeaths + 1
    else
      sequentialDifferentDeaths = 1
    end
    previousDeathGuid = guid
    if sequentialDifferentDeaths >= 2 then
      deathTtsPausedUntil = now + DEATH_TTS_BURST_PAUSE_SECONDS
      suppressTts = true
    end
    return suppressTts
  end

  local function RecordDeath(guid, unit, role)
    local name, realm = getUnitNameAndRealm(unit)
    local entry = deathSummaryByGuid[guid]
    if type(entry) ~= "table" then
      entry = { count = 0 }
      deathSummaryByGuid[guid] = entry
    end
    entry.count = (tonumber(entry.count) or 0) + 1
    entry.role = role
    if type(name) == "string" and name ~= "" then
      entry.name = name
      entry.realm = type(realm) == "string" and realm or nil
      local key = PlayerKey(entry.name, entry.realm)
      if key then
        guidByPlayerKey[key] = guid
      end
    end
  end

  function controller.HandleUnitHealth(unit)
    if type(unit) ~= "string" or not WATCHED_UNITS[unit] then
      return
    end
    if not IsEnabled() or not IsInKeyCached() then
      return
    end
    if not unitExists(unit) then
      return
    end
    -- Offline members report dead-like health; a disconnect must not fire
    -- a death alert, so the unit is skipped without touching its flag.
    if unitIsConnected(unit) ~= true then
      return
    end
    local guid = unitGUID(unit)
    if not guid then
      return
    end
    local dead = unitIsDeadOrGhost(unit)
    if dead == nil then
      return
    end
    if not dead then
      deadByGuid[guid] = nil
      deadRoleByGuid[guid] = nil
      return
    end
    if deadByGuid[guid] then
      return
    end
    deadByGuid[guid] = true
    local role = getUnitRole(unit)
    RecordDeath(guid, unit, role)
    -- Damage-dealer deaths are useful while the run can still recover. Once
    -- both critical roles are dead, extra DPS TTS would only add noise.
    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
      if role == "DAMAGER" and HasDeadTankAndHealer() then
        return
      end
      local suppressTts = UpdateDeathTtsBurstPause(guid, GetNow())
      deadRoleByGuid[guid] = role
      onRoleDeath(role, unit, { suppressTts = suppressTts })
    end
  end

  function controller.GetDeathSummaryForPlayer(name, realm)
    local key = PlayerKey(name, realm)
    local guid = key and guidByPlayerKey[key] or nil
    return CopyDeathSummary(guid and deathSummaryByGuid[guid] or nil)
  end

  function controller.GetDeathSummaryForUnit(unit)
    if type(unit) ~= "string" or unit == "" then
      return nil
    end
    local guid = unitGUID(unit)
    return CopyDeathSummary(guid and deathSummaryByGuid[guid] or nil)
  end

  function controller.GetAllDeathSummaries()
    local out = {}
    for _, entry in pairs(deathSummaryByGuid) do
      if type(entry) == "table" and tonumber(entry.count) and tonumber(entry.count) > 0 then
        out[#out + 1] = CopyDeathSummary(entry)
      end
    end
    table.sort(out, function(a, b)
      local nameA = type(a.name) == "string" and a.name or ""
      local nameB = type(b.name) == "string" and b.name or ""
      if nameA ~= nameB then
        return nameA < nameB
      end
      return tostring(a.realm or "") < tostring(b.realm or "")
    end)
    return out
  end

  -- Drops dead flags of players who left the group so a returning slot
  -- occupant starts with a clean edge state.
  function controller.HandleGroupRosterUpdate()
    local current = {}
    for unit in pairs(WATCHED_UNITS) do
      if unitExists(unit) then
        local guid = unitGUID(unit)
        if guid then
          current[guid] = true
        end
      end
    end
    for guid in pairs(deadByGuid) do
      if not current[guid] then
        deadByGuid[guid] = nil
        deadRoleByGuid[guid] = nil
      end
    end
  end

  function controller.ResetEdges()
    deadByGuid = {}
    deadRoleByGuid = {}
    previousDeathGuid = nil
    sequentialDifferentDeaths = 0
    deathTtsPausedUntil = 0
    cachedInKey = nil
  end

  function controller.Reset()
    controller.ResetEdges()
    deathSummaryByGuid = {}
    guidByPlayerKey = {}
  end

  return controller
end

local controllerInstance = nil

function DeathWatch.SetDependencies(deps)
  if type(deps) ~= "table" then
    return
  end
  controllerInstance = DeathWatch.CreateController(deps)
end

function DeathWatch.HandleEvent(event, ...)
  if not controllerInstance then
    return
  end
  if event == "UNIT_HEALTH" then
    controllerInstance.HandleUnitHealth(...)
    return
  end
  if event == "GROUP_ROSTER_UPDATE" then
    controllerInstance.HandleGroupRosterUpdate()
    return
  end
  if event == "CHALLENGE_MODE_START" then
    controllerInstance.Reset()
    return
  end
  if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    controllerInstance.ResetEdges()
  end
end

function DeathWatch.GetDeathSummaryForPlayer(name, realm)
  if not controllerInstance or type(controllerInstance.GetDeathSummaryForPlayer) ~= "function" then
    return nil
  end
  return controllerInstance.GetDeathSummaryForPlayer(name, realm)
end

function DeathWatch.GetAllDeathSummaries()
  if not controllerInstance or type(controllerInstance.GetAllDeathSummaries) ~= "function" then
    return {}
  end
  return controllerInstance.GetAllDeathSummaries()
end
