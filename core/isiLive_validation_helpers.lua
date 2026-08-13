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

--- Reads a single field out of a table that Blizzard handed us (event payload,
--- API result struct, tooltip data) without ever operating on a masked value.
---
--- Secret Values do not only arrive as return values of the APIs watched by
--- `tools/check_secret_value_guards.lua`. Since WoW 12.1 they also arrive as
--- FIELDS of event payloads -- `unitAuraUpdateInfo.isFullUpdate` is masked
--- inside restricted instances. Reading such a field is safe, but comparing,
--- concatenating or calculating with it raises and kills the whole dispatch.
--- `type()` lies about a Secret Value, so the secret check has to run before
--- any type inspection.
--- @param source table|nil
--- @param key any
--- @return any -- nil when the table, the key or the value is unusable
function Validators.ReadPlainField(source, key)
  if type(source) ~= "table" then
    return nil
  end
  local ok, value = pcall(rawget, source, key)
  if not ok or Validators.IsSecretValue(value) then
    return nil
  end
  return value
end

--- True when the field exists but Blizzard masked it: reading it is safe, every
--- comparison raises. ReadPlainField collapses "masked" and "absent" into one
--- nil; callers that must tell them apart (a masked flag still carries meaning,
--- an absent one does not) ask here.
--- @param source table|nil
--- @param key any
--- @return boolean
function Validators.IsSecretField(source, key)
  if type(source) ~= "table" then
    return false
  end
  local ok, value = pcall(rawget, source, key)
  if not ok then
    return true
  end
  return Validators.IsSecretValue(value)
end

--- ReadPlainField restricted to a readable plain boolean.
--- @param source table|nil
--- @param key any
--- @return boolean|nil -- nil when the field is missing, masked or not a boolean
function Validators.ReadPlainBoolean(source, key)
  local value = Validators.ReadPlainField(source, key)
  if type(value) ~= "boolean" then
    return nil
  end
  return value
end

--- ReadPlainField restricted to a readable plain number.
--- @param source table|nil
--- @param key any
--- @return number|nil -- nil when the field is missing, masked or not a number
function Validators.ReadPlainNumber(source, key)
  local value = Validators.ReadPlainField(source, key)
  if type(value) ~= "number" then
    return nil
  end
  return value
end

--- ReadPlainField restricted to a readable plain string.
--- @param source table|nil
--- @param key any
--- @return string|nil -- nil when the field is missing, masked or not a string
function Validators.ReadPlainString(source, key)
  local value = Validators.ReadPlainField(source, key)
  if type(value) ~= "string" then
    return nil
  end
  return value
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
