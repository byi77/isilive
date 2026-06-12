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

function DeathWatch.CreateController(opts)
  opts = opts or {}
  local isInKey = type(opts.isInKey) == "function" and opts.isInKey or DefaultIsInKey
  local unitExists = type(opts.unitExists) == "function" and opts.unitExists or DefaultUnitExists
  local unitIsDeadOrGhost = type(opts.unitIsDeadOrGhost) == "function" and opts.unitIsDeadOrGhost
    or DefaultUnitIsDeadOrGhost
  local unitIsConnected = type(opts.unitIsConnected) == "function" and opts.unitIsConnected or DefaultUnitIsConnected
  local unitGUID = type(opts.unitGUID) == "function" and opts.unitGUID or DefaultUnitGUID
  local getUnitRole = type(opts.getUnitRole) == "function" and opts.getUnitRole or DefaultGetUnitRole
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
      return
    end
    if deadByGuid[guid] then
      return
    end
    deadByGuid[guid] = true
    local role = getUnitRole(unit)
    if role == "TANK" or role == "HEALER" then
      onRoleDeath(role, unit)
    end
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
      end
    end
  end

  function controller.Reset()
    deadByGuid = {}
    cachedInKey = nil
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
  if event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    controllerInstance.Reset()
  end
end
