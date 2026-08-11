local _, addonTable = ...

addonTable = addonTable or {}

local Validators = {}
addonTable.Validators = Validators

--- Returns true when Blizzard marks a runtime value as secret/inaccessible.
--- The helper itself is protected because sandboxed test environments and
--- future client builds may expose a throwing compatibility function.
--- @param value any
--- @return boolean
function Validators.IsSecretValue(value)
  local isSecretValue = rawget(_G, "issecretvalue")
  if type(isSecretValue) ~= "function" then
    return false
  end
  local ok, result = pcall(isSecretValue, value)
  return ok and result == true
end

local function HasSecretInstanceInfoValue(...)
  for index = 1, select("#", ...) do
    if Validators.IsSecretValue(select(index, ...)) then
      return true
    end
  end
  return false
end

--- Reads the optional instance API and rejects every returned secret value.
--- @return boolean, table|nil -- success flag followed by verified metadata
function Validators.GetInstanceInfoSafe()
  local getInstanceInfo = rawget(_G, "GetInstanceInfo")
  if type(getInstanceInfo) ~= "function" then
    return false
  end

  local results = { pcall(getInstanceInfo) }
  if
    not results[1]
    or HasSecretInstanceInfoValue(
      results[2],
      results[3],
      results[4],
      results[5],
      results[6],
      results[7],
      results[8],
      results[9],
      results[10],
      results[11],
      results[12],
      results[13]
    )
  then
    return false
  end

  return true,
    {
      instanceName = results[2],
      instanceType = results[3],
      difficultyID = results[4],
      difficultyName = results[5],
      maxPlayers = results[6],
      dynamicDifficultyID = results[7],
      isDynamic = results[8],
      instanceMapID = results[9],
      instanceID = results[10],
      lfgDungeonID = results[11],
      lfgDungeonMapID = results[12],
      lfgDungeonName = results[13],
    }
end

--- Asserts that a value is a function and returns it.
--- @param value any
--- @param name string -- dependency name for error messages
--- @param moduleName string|nil -- calling module name for error messages
--- @return function
function Validators.RequireFunction(value, name, moduleName)
  assert(type(value) == "function", string.format("isiLive: %s requires %s", moduleName or "module", name))
  return value
end

--- Asserts that a value is a table and returns it.
--- @param value any
--- @param name string -- dependency name for error messages
--- @param moduleName string|nil -- calling module name for error messages
--- @return table
function Validators.RequireTable(value, name, moduleName)
  assert(type(value) == "table", string.format("isiLive: %s requires table %s", moduleName or "module", name))
  return value
end

--- Checks whether a WoW unit token refers to an existing unit.
--- Uses rawget + pcall for defensive WoW API access.
--- @param unit string
--- @return boolean
function Validators.IsExistingUnit(unit)
  if type(unit) ~= "string" or unit == "" then
    return false
  end

  local unitExists = rawget(_G, "UnitExists")
  if type(unitExists) ~= "function" then
    return false
  end

  local ok, exists = pcall(unitExists, unit)
  return ok and not Validators.IsSecretValue(exists) and exists == true
end
