local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeMode = addonTable.RuntimeMode or {}
addonTable.RuntimeMode = RuntimeMode

-- Runtime profiles. isiLive is a Mythic+ companion: the full feature set only
-- pays for itself inside a key. Everything else runs a reduced profile so the
-- addon stays cheap in content it does not serve.
--
--   OFF  -- raid or any group larger than 5. Hard off, see RULE 11.
--   IDLE -- five or fewer players outside a mythic dungeon: open world, normal,
--           heroic, timewalking, delves, torghast, follower dungeons. Group
--           display and group sync only.
--   KEY  -- mythic party dungeon (active keystone or M0). Everything runs.
RuntimeMode.OFF = "OFF"
RuntimeMode.IDLE = "IDLE"
RuntimeMode.KEY = "KEY"

-- Party difficulty IDs that receive the full profile.
--   8  = Mythic Keystone (key inserted and running)
--   23 = Mythic
--
-- The API cannot tell a genuine M0 run apart from a key dungeon whose keystone
-- has not been inserted yet: both report difficultyID 23 with no active
-- challenge map, and only CHALLENGE_MODE_START separates them -- after the fact.
-- difficultyID 23 is therefore treated as the run-up to a key, where roster,
-- keys and ready-check matter most. The cost is that a real M0 run also runs the
-- full profile; that is the cheaper of the two errors.
--
-- Deliberately absent: 24 (Timewalking), 1 (Normal), 2 (Heroic). Those are IDLE.
local FULL_PROFILE_PARTY_DIFFICULTY_IDS = {
  [8] = true,
  [23] = true,
}

local RAID_GROUP_SIZE_THRESHOLD = 5

local function IsSecretValue(value)
  local validators = addonTable.Validators
  if type(validators) ~= "table" or type(validators.IsSecretValue) ~= "function" then
    return false
  end
  local ok, isSecret = pcall(validators.IsSecretValue, value)
  return ok and isSecret == true
end

-- Calls a global by name under pcall and fails closed on Secret Values. Returns
-- nil when the global is missing, the call raised, or the result is masked.
local function SafeCallGlobal(name, ...)
  local fn = rawget(_G, name)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, result = pcall(fn, ...)
  if not ok or IsSecretValue(result) then
    return nil
  end
  return result
end

local function ToPositiveInteger(value)
  local numeric = tonumber(value)
  if not numeric or numeric <= 0 then
    return nil
  end
  return math.floor(numeric)
end

--- True while the player is in a raid or any group larger than five.
-- Mirrors the long-standing IsRaidGroup bridge so the hard-off contract keeps
-- one definition across the codebase.
-- @return boolean
function RuntimeMode.IsRaidContext()
  if SafeCallGlobal("IsInRaid") == true then
    return true
  end
  if SafeCallGlobal("IsInGroup") ~= true then
    return false
  end
  local groupMembers = ToPositiveInteger(SafeCallGlobal("GetNumGroupMembers"))
  return groupMembers ~= nil and groupMembers > RAID_GROUP_SIZE_THRESHOLD
end

--- True only while a keystone is actually running.
-- Forces tracking and the M+ timer depend on live challenge-mode data and must
-- keep using this, not the wider full-profile check.
-- @return boolean
function RuntimeMode.IsActiveChallenge()
  local api = rawget(_G, "C_ChallengeMode")
  if type(api) ~= "table" or type(api.GetActiveChallengeMapID) ~= "function" then
    return false
  end
  local ok, mapID = pcall(api.GetActiveChallengeMapID)
  if not ok or IsSecretValue(mapID) then
    return false
  end
  return ToPositiveInteger(mapID) ~= nil
end

--- True in a mythic party dungeon: active keystone or M0 / pre-insert.
-- This is the gate for everything that used to be spelled as a local
-- DefaultIsInKey() copy (death alerts, BR/Lust announces, combat trackers).
-- @return boolean
function RuntimeMode.IsFullProfileContext()
  if RuntimeMode.IsRaidContext() then
    return false
  end
  if RuntimeMode.IsActiveChallenge() then
    return true
  end

  local getInstanceInfoSafe = addonTable.Validators.GetInstanceInfoSafe
  if type(getInstanceInfoSafe) ~= "function" then
    return false
  end
  local ok, instanceInfo = getInstanceInfoSafe()
  if not ok then
    return false
  end
  local instanceType = instanceInfo.instanceType
  local difficultyID = instanceInfo.difficultyID
  if instanceType ~= "party" then
    return false
  end
  return FULL_PROFILE_PARTY_DIFFICULTY_IDS[difficultyID] == true
end

--- Resolves the current runtime profile.
-- @return string one of RuntimeMode.OFF, RuntimeMode.IDLE, RuntimeMode.KEY
function RuntimeMode.Resolve()
  if RuntimeMode.IsRaidContext() then
    return RuntimeMode.OFF
  end
  if RuntimeMode.IsFullProfileContext() then
    return RuntimeMode.KEY
  end
  return RuntimeMode.IDLE
end

--- True when the addon must stay hard off (raid / group larger than five).
-- @return boolean
function RuntimeMode.IsOff()
  return RuntimeMode.Resolve() == RuntimeMode.OFF
end

--- True in the reduced profile: group display and group sync only.
-- @return boolean
function RuntimeMode.IsIdle()
  return RuntimeMode.Resolve() == RuntimeMode.IDLE
end

--- True in the full profile (mythic party dungeon).
-- @return boolean
function RuntimeMode.IsKey()
  return RuntimeMode.Resolve() == RuntimeMode.KEY
end

--- True when a party difficulty ID belongs to the full profile.
-- Membership test without allocating, for callers that already hold a verified
-- difficulty ID and only need the classification.
-- @param difficultyID number
-- @return boolean
function RuntimeMode.IsFullProfileDifficulty(difficultyID)
  return FULL_PROFILE_PARTY_DIFFICULTY_IDS[difficultyID] == true
end

--- Exposes the full-profile difficulty table for deterministic tests and docs.
-- Returns a copy so callers cannot mutate the contract.
-- @return table map of difficultyID -> true
function RuntimeMode.GetFullProfileDifficultyIDs()
  local copy = {}
  for difficultyID in pairs(FULL_PROFILE_PARTY_DIFFICULTY_IDS) do
    copy[difficultyID] = true
  end
  return copy
end
