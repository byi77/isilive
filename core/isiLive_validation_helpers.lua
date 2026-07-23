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
