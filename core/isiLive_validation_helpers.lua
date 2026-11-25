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

--- True for a real number that is neither NaN nor infinite. A Secret Value
--- is never finite here: the secret check runs first, because type() on a
--- Secret Value is not trustworthy and the comparisons below would raise
--- (and taint) on one. Callers need no separate IsSecretValue guard.
--- @param value any
--- @return boolean
function Validators.IsFiniteNumber(value)
  if Validators.IsSecretValue(value) then
    return false
  end
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
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

--- ReadPlainString restricted to a non-empty string. C_LFGList result structs
--- (search result, applicant, active entry) are SecretInChatMessagingLockdown;
--- comparing their name fields with "" raises there.
--- @param source table|nil
--- @param key any
--- @return string|nil -- nil when the field is missing, masked, not a string or empty
function Validators.ReadNonEmptyString(source, key)
  local value = Validators.ReadPlainString(source, key)
  if value == nil or value == "" then
    return nil
  end
  return value
end

-- Takes the pcall results as parameters instead of a `{ pcall(...) }` table
-- plus a vararg scan: the runtime-profile resolver reaches this on per-event
-- paths.
local function VerifyInstanceInfo(
  ok,
  instanceName,
  instanceType,
  difficultyID,
  difficultyName,
  maxPlayers,
  dynamicDifficultyID,
  isDynamic,
  instanceMapID,
  instanceID,
  lfgDungeonID,
  lfgDungeonMapID,
  lfgDungeonName
)
  local isSecret = Validators.IsSecretValue
  if
    not ok
    or isSecret(instanceName)
    or isSecret(instanceType)
    or isSecret(difficultyID)
    or isSecret(difficultyName)
    or isSecret(maxPlayers)
    or isSecret(dynamicDifficultyID)
    or isSecret(isDynamic)
    or isSecret(instanceMapID)
    or isSecret(instanceID)
    or isSecret(lfgDungeonID)
    or isSecret(lfgDungeonMapID)
    or isSecret(lfgDungeonName)
  then
    return false
  end

  return true,
    {
      instanceName = instanceName,
      instanceType = instanceType,
      difficultyID = difficultyID,
      difficultyName = difficultyName,
      maxPlayers = maxPlayers,
      dynamicDifficultyID = dynamicDifficultyID,
      isDynamic = isDynamic,
      instanceMapID = instanceMapID,
      instanceID = instanceID,
      lfgDungeonID = lfgDungeonID,
      lfgDungeonMapID = lfgDungeonMapID,
      lfgDungeonName = lfgDungeonName,
    }
end

--- Reads the optional instance API and rejects every returned secret value.
--- @return boolean, table|nil -- success flag followed by verified metadata
function Validators.GetInstanceInfoSafe()
  local getInstanceInfo = rawget(_G, "GetInstanceInfo")
  if type(getInstanceInfo) ~= "function" then
    return false
  end
  return VerifyInstanceInfo(pcall(getInstanceInfo))
end

--- Resolves a Blizzard API function, preferring the namespaced member over
--- its legacy global. Retail 12.1.5 keeps several legacy globals only as
--- Blizzard_Deprecated* shims (GetSpecialization, GetSpecializationInfo,
--- GetInspectSpecialization, GetWeaponEnchantInfo, SendChatMessage); a shim
--- loads only while the CVar loadDeprecationFallbacks is on and is scheduled
--- for removal at the next expansion. The legacy global stays the fallback
--- for clients that predate the namespaced member.
--- @param namespace string -- e.g. "C_SpecializationInfo"
--- @param member string -- function name inside the namespace
--- @param legacyGlobal string|nil -- global fallback name
--- @return function|nil
function Validators.ResolveApiFunction(namespace, member, legacyGlobal)
  local ns = rawget(_G, namespace)
  local fn = type(ns) == "table" and ns[member] or nil
  if type(fn) == "function" then
    return fn
  end
  if legacyGlobal then
    fn = rawget(_G, legacyGlobal)
    if type(fn) == "function" then
      return fn
    end
  end
  return nil
end

-- Mirrors the GetWeaponEnchantInfo tuple (has, remainingMs, charges, enchantID
-- per slot: main hand, off hand) from C_PaperDollInfo.GetTemporaryEnchantmentInfo,
-- exactly as Blizzard's own shim in Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua
-- builds it. Field values are copied untouched, secret or not; callers keep
-- their own secret checks.
local function ReadTemporaryWeaponEnchants(getEnchantInfo, mainSlot, offSlot)
  local main = getEnchantInfo(mainSlot)
  local off = getEnchantInfo(offSlot)
  local hasMain = main ~= nil
  local hasOff = off ~= nil
  return hasMain,
    hasMain and main.remainingTimeMs or nil,
    hasMain and main.chargesRemaining or nil,
    hasMain and main.enchantID or nil,
    hasOff,
    hasOff and off.remainingTimeMs or nil,
    hasOff and off.chargesRemaining or nil,
    hasOff and off.enchantID or nil
end

--- Resolves a reader with the GetWeaponEnchantInfo return shape (main hand,
--- then off hand). Prefers C_PaperDollInfo.GetTemporaryEnchantmentInfo; the
--- global only remains as a deprecated shim in 12.1.5. Call the result under pcall.
--- @return function|nil
function Validators.ResolveWeaponEnchantReader()
  local getEnchantInfo = Validators.ResolveApiFunction("C_PaperDollInfo", "GetTemporaryEnchantmentInfo")
  local mainSlot = rawget(_G, "INVSLOT_MAINHAND")
  local offSlot = rawget(_G, "INVSLOT_OFFHAND")
  if getEnchantInfo and type(mainSlot) == "number" and type(offSlot) == "number" then
    return function()
      return ReadTemporaryWeaponEnchants(getEnchantInfo, mainSlot, offSlot)
    end
  end
  local legacy = rawget(_G, "GetWeaponEnchantInfo")
  return type(legacy) == "function" and legacy or nil
end

-- Blizzard uses three separate ID spaces for a dungeon. Ingame 2026-10-08,
-- Murder Row: challenge-mode map ID 587 (season data, ResolveStatusTargetMapID),
-- instance ID 2813 (8th return of GetInstanceInfo, 6th return of
-- C_ChallengeMode.GetMapUIInfo(587)) and UiMapID 2433
-- (C_Map.GetBestMapForUnit). Only the instance ID links the challenge map to
-- the player's location. The challenge -> instance mapping is static, so a
-- resolved pair is cached; failed lookups are not.
local instanceIDByChallengeMapID = {}

--- Resolves the instance ID behind a challenge-mode map ID.
--- @param challengeMapID any
--- @return number|nil -- nil when the API is missing, fails or returns a masked/unusable value
function Validators.ResolveChallengeMapInstanceID(challengeMapID)
  if Validators.IsSecretValue(challengeMapID) or type(challengeMapID) ~= "number" or challengeMapID <= 0 then
    return nil
  end
  local cached = instanceIDByChallengeMapID[challengeMapID]
  if cached then
    return cached
  end

  local challengeModeApi = rawget(_G, "C_ChallengeMode")
  if type(challengeModeApi) ~= "table" then
    return nil
  end
  local getMapUIInfo = rawget(challengeModeApi, "GetMapUIInfo")
  if type(getMapUIInfo) ~= "function" then
    return nil
  end
  -- Returns name, id, timeLimit, texture, backgroundTexture, mapID; the 6th
  -- value is the instance ID (verified ingame, see above).
  local ok, _, _, _, _, _, instanceID = pcall(getMapUIInfo, challengeMapID)
  if not ok or Validators.IsSecretValue(instanceID) or type(instanceID) ~= "number" or instanceID <= 0 then
    return nil
  end
  instanceIDByChallengeMapID[challengeMapID] = instanceID
  return instanceID
end

--- Instance ID of the player's current location, only inside a party
--- (dungeon) instance.
--- @return number|nil -- nil outside a party instance or when the data is missing/masked
function Validators.GetCurrentPartyInstanceID()
  local ok, instanceInfo = Validators.GetInstanceInfoSafe()
  return Validators.GetPartyInstanceIDFromInfo(ok, instanceInfo)
end

--- Same check on an already read GetInstanceInfoSafe() result, for callers
--- that need further fields of the same read.
--- @return number|nil
function Validators.GetPartyInstanceIDFromInfo(ok, instanceInfo)
  if not ok or type(instanceInfo) ~= "table" or instanceInfo.instanceType ~= "party" then
    return nil
  end
  local instanceID = instanceInfo.instanceMapID
  if type(instanceID) ~= "number" or instanceID <= 0 then
    return nil
  end
  return instanceID
end

--- True only when the player stands inside the party instance that belongs to
--- the given challenge-mode map ID. Every missing or masked input fails closed.
--- @param challengeMapID any
--- @return boolean, number|nil, number|nil -- matched, current instance ID, target instance ID
function Validators.IsPlayerInChallengeMapInstance(challengeMapID)
  local currentInstanceID = Validators.GetCurrentPartyInstanceID()
  if not currentInstanceID then
    return false, nil, nil
  end
  local targetInstanceID = Validators.ResolveChallengeMapInstanceID(challengeMapID)
  if not targetInstanceID then
    return false, currentInstanceID, nil
  end
  return currentInstanceID == targetInstanceID, currentInstanceID, targetInstanceID
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
