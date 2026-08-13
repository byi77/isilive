-- Standalone CLI tool: runtime defense-in-depth for the WoW 12.0 (Midnight)
-- Secret Value contract.
--
-- Background: in tainted M+ contexts Blizzard's Unit* / GetActiveChallengeMapID
-- APIs return masked Secret Value sentinels. Reading them as plain strings or
-- comparing them with `==` raises a tainted-compare error that can crash the
-- entire dispatch path. The static gate `tools/check_secret_value_guards.lua`
-- pins that every production reader pcall-wraps the API call. This simulator
-- is the runtime sibling: it FIRES tainted errors from the mocked API and
-- asserts every consumer fails closed without re-raising.
--
-- Verifies for every watched API consumer:
--   * Happy-path: the API returns a clean value -> consumer returns it.
--   * Taint-error path: the API raises (simulating Secret-Value compare) ->
--     pcall in the consumer catches it -> consumer returns the documented
--     fail-closed value (e.g. "NONE" for roles, nil for class/name).
--   * Nil-return path: the API returns nil -> consumer returns the same
--     fail-closed value.
--
-- Watched consumers covered here:
--   * Units.GetUnitRole         (UnitGroupRolesAssigned + UnitIsUnit)
--   * Units.GetUnitClass        (UnitClass)
--   * Units.GetUnitNameAndRealm (UnitFullName + UnitName)
--   * Status BuildStatusLineText (C_ChallengeMode.GetActiveChallengeMapID)
--
-- The MobNameplate Secret-Value branches (UnitGUID secret + secret mapID +
-- secret percent string) are covered by simulate_nameplate_keystart.lua's
-- `secret_guid` / `api_only` / `secret_mapid` modes — not duplicated here.
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- the real Units / Status modules are loaded; each consumer is invoked with
-- the production signature; the WoW Unit*/C_ChallengeMode globals are
-- replaced with steerable mocks that can be flipped between happy / nil /
-- taint-error per scenario.
---@diagnostic disable: undefined-global
local io = io
---@diagnostic disable-next-line: undefined-global
local load = load
---@diagnostic disable-next-line: undefined-global
local os = os

local function LoadLocal(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  assert(chunk, err)
  return chunk()
end

local Harness = LoadLocal("testmodul/isilive_test_harness.lua")

local failures = 0

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

-- ----------------------------------------------------------------------
-- Steerable WoW-globals model. Each `mode` field can be:
--   * a value -> the API returns that value
--   * "nil" string -> the API returns nil
--   * "taint" string -> the API raises (simulates tainted-compare crash)
-- This lets each scenario flip between happy/nil/taint per API.
-- ----------------------------------------------------------------------
local model = {
  rolesAssigned = "TANK",
  unitIsUnit = false,
  unitClass = { localized = "Warrior", token = "WARRIOR" },
  unitFullName = { name = "Tank", realm = "Realm" },
  unitName = "TankFallback",
  realmName = "Realm",
  unitExists = true,
  activeChallengeMapID = nil, -- nil -> no active challenge
  isPlayerLeader = false,
  -- helper for "force taint":
  forceTaintRoles = false,
  forceTaintIsUnit = false,
  forceTaintUnitClass = false,
  forceTaintFullName = false,
  forceTaintUnitName = false,
  forceTaintMapID = false,
}

local function ResetModel()
  model.rolesAssigned = "TANK"
  model.unitIsUnit = false
  model.unitClass = { localized = "Warrior", token = "WARRIOR" }
  model.unitFullName = { name = "Tank", realm = "Realm" }
  model.unitName = "TankFallback"
  model.realmName = "Realm"
  model.unitExists = true
  model.activeChallengeMapID = nil
  model.isPlayerLeader = false
  model.forceTaintRoles = false
  model.forceTaintIsUnit = false
  model.forceTaintUnitClass = false
  model.forceTaintFullName = false
  model.forceTaintUnitName = false
  model.forceTaintMapID = false
end

local function buildGlobals()
  return {
    UnitGroupRolesAssigned = function()
      if model.forceTaintRoles then
        error("simulated Secret-Value tainted-compare on UnitGroupRolesAssigned", 0)
      end
      return model.rolesAssigned
    end,
    UnitIsUnit = function()
      if model.forceTaintIsUnit then
        error("simulated Secret-Value tainted-compare on UnitIsUnit", 0)
      end
      return model.unitIsUnit
    end,
    UnitClass = function()
      if model.forceTaintUnitClass then
        error("simulated Secret-Value tainted-compare on UnitClass", 0)
      end
      return model.unitClass.localized, model.unitClass.token
    end,
    UnitFullName = function()
      if model.forceTaintFullName then
        error("simulated Secret-Value tainted-compare on UnitFullName", 0)
      end
      return model.unitFullName.name, model.unitFullName.realm
    end,
    UnitName = function()
      if model.forceTaintUnitName then
        error("simulated Secret-Value tainted-compare on UnitName", 0)
      end
      return model.unitName
    end,
    UnitExists = function()
      return model.unitExists
    end,
    GetRealmName = function()
      return model.realmName
    end,
    -- Specialization-fallback path in Units.GetUnitRole:
    GetSpecialization = function()
      return 1
    end,
    GetSpecializationRole = function()
      return "DAMAGER"
    end,
    GetSpecializationInfo = function()
      return 71, "Arms"
    end,
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        if model.forceTaintMapID then
          error("simulated Secret-Value tainted-compare on GetActiveChallengeMapID", 0)
        end
        return model.activeChallengeMapID
      end,
    },
    GetInstanceInfo = function()
      -- name, type, difficultyID, difficultyName, ...
      return "Outside", "none", 1, "Normal"
    end,
    GetDifficultyInfo = function()
      return "Normal", "party"
    end,
  }
end

-- ----------------------------------------------------------------------
-- Phase 1 - Units.GetUnitRole: happy + taint + nil paths.
-- ----------------------------------------------------------------------
local function ScenarioGetUnitRole()
  print("\n========== Scenario 1: Units.GetUnitRole ==========")
  local addon
  Harness.WithGlobals(buildGlobals(), function()
    addon = Harness.LoadAddonModules({ "isiLive_units.lua" })
  end)

  -- Happy path
  ResetModel()
  model.rolesAssigned = "HEALER"
  local role
  Harness.WithGlobals(buildGlobals(), function()
    role = addon.Units.GetUnitRole("party1")
  end)
  Check(role == "HEALER", "happy: UnitGroupRolesAssigned returns 'HEALER' -> GetUnitRole returns 'HEALER'")

  -- Taint path: API raises -> pcall catches -> fall through to spec fallback
  -- (UnitIsUnit also taints in tainted contexts, so the whole branch fails closed).
  ResetModel()
  model.forceTaintRoles = true
  model.forceTaintIsUnit = true
  Harness.WithGlobals(buildGlobals(), function()
    role = addon.Units.GetUnitRole("party1")
  end)
  Check(role == "NONE", "taint: both UnitGroupRolesAssigned + UnitIsUnit raise -> GetUnitRole returns 'NONE'")

  -- Nil path: API returns nil
  ResetModel()
  model.rolesAssigned = nil
  Harness.WithGlobals(buildGlobals(), function()
    role = addon.Units.GetUnitRole("party1")
  end)
  Check(role == "NONE", "nil: UnitGroupRolesAssigned returns nil -> GetUnitRole returns 'NONE'")

  -- Player fallback: API returns nil but unit IS player -> spec fallback wins
  ResetModel()
  model.rolesAssigned = nil
  model.unitIsUnit = true -- unit == "player"
  Harness.WithGlobals(buildGlobals(), function()
    role = addon.Units.GetUnitRole("player")
  end)
  Check(role == "DAMAGER", "player-fallback: nil API + UnitIsUnit('player')=true -> GetSpecializationRole='DAMAGER'")
end

-- ----------------------------------------------------------------------
-- Phase 2 - Units.GetUnitClass: happy + taint + nil paths.
-- ----------------------------------------------------------------------
local function ScenarioGetUnitClass()
  print("\n========== Scenario 2: Units.GetUnitClass ==========")
  local addon
  Harness.WithGlobals(buildGlobals(), function()
    addon = Harness.LoadAddonModules({ "isiLive_units.lua" })
  end)

  -- Happy
  ResetModel()
  local localized, token
  Harness.WithGlobals(buildGlobals(), function()
    localized, token = addon.Units.GetUnitClass("party1")
  end)
  Check(localized == "Warrior" and token == "WARRIOR", "happy: GetUnitClass returns ('Warrior','WARRIOR')")

  -- Taint
  ResetModel()
  model.forceTaintUnitClass = true
  Harness.WithGlobals(buildGlobals(), function()
    localized, token = addon.Units.GetUnitClass("party1")
  end)
  Check(localized == nil and token == nil, "taint: UnitClass raises -> GetUnitClass returns (nil, nil)")

  -- Unit absent
  ResetModel()
  model.unitExists = false
  Harness.WithGlobals(buildGlobals(), function()
    localized, token = addon.Units.GetUnitClass("party99")
  end)
  Check(localized == nil and token == nil, "absent unit: GetUnitClass returns (nil, nil) without calling the API")
end

-- ----------------------------------------------------------------------
-- Phase 3 - Units.GetUnitNameAndRealm: happy + taint on UnitFullName +
-- taint on both + UnitFullName returns nil but UnitName fallback succeeds.
-- ----------------------------------------------------------------------
local function ScenarioGetUnitNameAndRealm()
  print("\n========== Scenario 3: Units.GetUnitNameAndRealm ==========")
  local addon
  Harness.WithGlobals(buildGlobals(), function()
    addon = Harness.LoadAddonModules({ "isiLive_units.lua" })
  end)

  -- Happy: UnitFullName returns clean
  ResetModel()
  local name, realm
  Harness.WithGlobals(buildGlobals(), function()
    name, realm = addon.Units.GetUnitNameAndRealm("party1")
  end)
  Check(name == "Tank" and realm == "Realm", "happy: UnitFullName returns ('Tank','Realm')")

  -- UnitFullName taints, UnitName fallback returns "TankFallback"
  ResetModel()
  model.forceTaintFullName = true
  Harness.WithGlobals(buildGlobals(), function()
    name, realm = addon.Units.GetUnitNameAndRealm("party1")
  end)
  Check(
    name == "TankFallback" and realm == "Realm",
    "fullname-taint: UnitFullName raises -> UnitName fallback gives 'TankFallback', realm via GetRealmName"
  )

  -- Both taint: bails out with nil, nil. A realm without a name is useless to
  -- every caller, and Sync.NormalizePlayerKey treats a nil realm as
  -- "self-realm fallback" anyway, so GetUnitNameAndRealm drops both instead of
  -- returning a half-resolved pair (see the early bail-out in
  -- game/isiLive_units.lua and "Units GetUnitNameAndRealm returns nil/nil for
  -- missing unit").
  ResetModel()
  model.forceTaintFullName = true
  model.forceTaintUnitName = true
  Harness.WithGlobals(buildGlobals(), function()
    name, realm = addon.Units.GetUnitNameAndRealm("party1")
  end)
  Check(name == nil, "both-taint: name is nil when both UnitFullName + UnitName raise")
  Check(realm == nil, "both-taint: realm is dropped too instead of a name-less GetRealmName fallback")

  -- UnitFullName returns nil realm -> GetRealmName fills it.
  ResetModel()
  model.unitFullName = { name = "Tank", realm = nil }
  Harness.WithGlobals(buildGlobals(), function()
    name, realm = addon.Units.GetUnitNameAndRealm("party1")
  end)
  Check(name == "Tank", "nil-realm: name preserved")
  Check(realm == "Realm", "nil-realm: realm filled from GetRealmName")
end

-- ----------------------------------------------------------------------
-- Phase 4 - Status.BuildStatusLineText: GetActiveChallengeMapID may taint
-- in 12.0 keys; the status-line build must not crash.
-- ----------------------------------------------------------------------
local function ScenarioBuildStatusLine()
  print("\n========== Scenario 4: Status BuildStatusLineText ==========")
  local addon
  Harness.WithGlobals(buildGlobals(), function()
    addon = Harness.LoadAddonModules({ "isiLive_status.lua" })
  end)

  local L = {
    STATUS_LEAD_YES = "L+",
    STATUS_LEAD_NO = "L-",
    STATUS_MPLUS_YES = "M+",
    STATUS_MPLUS_NO = "M-",
    STATUS_STATE_STOPPED = "S",
    STATUS_STATE_PAUSED = "P",
    STATUS_STATE_TEST = "T",
    STATUS_STATE_RUNNING = "R",
    STATUS_TARGET_DUNGEON_TEXT = "T:%s",
    STATUS_TARGET_DUNGEON_NONE = "T:-",
    STATUS_RAID_GROUP_HIDDEN = "R-",
    DUNGEON_DIFF_TEXT = "D:%s",
    DUNGEON_DIFF_DUNGEON_NORMAL = "N",
    DUNGEON_DIFF_DUNGEON_HEROIC = "H",
    DUNGEON_DIFF_DUNGEON_MYTHIC = "Mp",
    DUNGEON_DIFF_DUNGEON_MYTHIC_KEYSTONE = "Mk",
    DUNGEON_DIFF_RAID_NORMAL = "RN",
    DUNGEON_DIFF_RAID_HEROIC = "RH",
    DUNGEON_DIFF_RAID_MYTHIC = "RM",
    DUNGEON_DIFF_NONE = "-",
    -- Every label GetDungeonDifficultyLabel can return must be present. A
    -- missing key makes it hand nil to string.format, which Lua 5.4 quietly
    -- renders as "nil" but Lua 5.1 -- the version WoW and GitHub CI run --
    -- rejects outright ("bad argument #2 to 'format'"). Keep this table
    -- complete rather than only covering the branches a scenario happens to
    -- hit today.
    DUNGEON_DIFF_NORMAL = "N",
    DUNGEON_DIFF_HEROIC = "H",
    DUNGEON_DIFF_MYTHIC = "M",
    DUNGEON_DIFF_UNKNOWN = "?",
    DUNGEON_DIFF_OUTSIDE = "Out",
    DUNGEON_DIFF_RAID_UNKNOWN = "R?",
  }
  local controller = addon.Status.CreateController({
    getL = function()
      return L
    end,
    isInGroup = function()
      return true
    end,
    getTargetDungeonInfo = function()
      return nil
    end,
    isPlayerLeader = function()
      return false
    end,
    printFn = function() end,
  })

  -- Happy: API returns nil (no active challenge)
  ResetModel()
  local text
  Harness.WithGlobals(buildGlobals(), function()
    text = controller.BuildStatusLineText({})
  end)
  Check(
    type(text) == "string" and text:find("M-", 1, true) ~= nil,
    "happy: nil mapID -> M+ section reads 'M-' (no active challenge)"
  )

  -- Active challenge: API returns 2649
  ResetModel()
  model.activeChallengeMapID = 2649
  Harness.WithGlobals(buildGlobals(), function()
    text = controller.BuildStatusLineText({})
  end)
  Check(text:find("M+", 1, true) ~= nil, "active: mapID=2649 -> M+ section reads 'M+'")

  -- Taint: API raises -> pcall catches -> falls back to "no active challenge"
  ResetModel()
  model.forceTaintMapID = true
  local ok, taintedText = pcall(function()
    Harness.WithGlobals(buildGlobals(), function()
      text = controller.BuildStatusLineText({})
    end)
    return text
  end)
  Check(
    ok == true,
    "taint-no-crash: GetActiveChallengeMapID raises but BuildStatusLineText completes without re-raising"
  )
  Check(
    type(text) == "string" and text:find("M-", 1, true) ~= nil,
    "taint-fail-closed: tainted mapID -> M+ section falls back to 'M-'"
  )
  -- Suppress unused warning on taintedText (kept so the pcall return is visible).
  local _ = taintedText
end

-- ----------------------------------------------------------------------
-- Phase 5 - UNIT_AURA payload fields. WoW 12.1 masks
-- `unitAuraUpdateInfo.isFullUpdate` inside restricted instances; comparing it
-- raised "attempt to compare field 'isFullUpdate' (a secret boolean value)",
-- which aborted the whole UNIT_AURA handler. Because PiTracker runs FIRST in
-- that handler, the abort also silently killed the CD-tracker resync and the
-- Bloodlust button warning behind it -- so this scenario drives the real
-- dispatcher with the real PiTracker wired in and asserts all three survive.
-- ----------------------------------------------------------------------
local function ScenarioUnitAuraPayload()
  print("\n========== Scenario 5: UNIT_AURA masked payload fields ==========")
  local Fixtures = LoadLocal("testmodul/isilive_test_fixtures.lua")
  local secret = {}
  local globals = buildGlobals()
  globals.issecretvalue = function(value)
    return value == secret
  end

  local announces = {}
  local cdScans = 0
  local addon
  local controller

  Harness.WithGlobals(globals, function()
    addon = Harness.LoadAddonModules({ "isiLive_event_handlers.lua", "isiLive_pi_tracker.lua" })
    addon.PiTracker.SetDependencies({
      getTime = function()
        return 500
      end,
      getUnitName = function(unit)
        return unit == "party1" and "Priest-Realm" or "Me-Realm"
      end,
      getUnitClassToken = function(unit)
        return unit == "party1" and "PRIEST" or "MAGE"
      end,
      getAuraDataByIndex = function(unit, index, filter)
        if unit == "player" and index == 1 and filter == "HELPFUL" then
          return { spellId = 10060, auraInstanceID = 501, sourceUnit = "party1" }
        end
        return nil
      end,
      announcePowerInfusion = function(casterName, recipientName)
        announces[#announces + 1] = { casterName = casterName, recipientName = recipientName }
      end,
    })
    controller = Fixtures.BuildEventHandlersController(addon.EventHandlers, { value = nil }, {}, {
      handlePiTrackerEvent = function(event, unit, payload)
        addon.PiTracker.HandleEvent(event, unit, payload)
      end,
      updateCdTracker = function()
        cdScans = cdScans + 1
      end,
    })
  end)

  -- Masked flag, no delta list: the shape of a full update.
  local ok = pcall(function()
    Harness.WithGlobals(globals, function()
      controller:Dispatch("UNIT_AURA", "player", { isFullUpdate = secret })
    end)
  end)
  Check(ok == true, "masked isFullUpdate: UNIT_AURA dispatch completes without re-raising")
  Check(#announces == 1, "masked isFullUpdate: the inferred full-update scan still announces Power Infusion")
  Check(cdScans == 1, "masked isFullUpdate: the cd-tracker resync behind PiTracker still runs")

  -- Masked flag next to a delta list: incremental, must not force a full scan.
  Harness.WithGlobals(globals, function()
    controller:Dispatch("UNIT_AURA", "player", { isFullUpdate = secret, updatedAuraInstanceIDs = { 7 } })
  end)
  Check(#announces == 1, "masked incremental payload: no extra PI announce from a 40-slot scan")

  -- Masked aura fields inside a delta list must not reach a comparison or a
  -- table lookup either.
  local okFields = pcall(function()
    Harness.WithGlobals(globals, function()
      controller:Dispatch("UNIT_AURA", "player", {
        isFullUpdate = secret,
        addedAuras = { { spellId = secret, auraInstanceID = secret, sourceUnit = secret } },
      })
    end)
  end)
  Check(okFields == true, "masked aura fields: UNIT_AURA dispatch completes without re-raising")
  Check(#announces == 1, "masked aura fields: nothing is announced from unreadable aura data")
end

ScenarioGetUnitRole()
ScenarioGetUnitClass()
ScenarioGetUnitNameAndRealm()
ScenarioBuildStatusLine()
ScenarioUnitAuraPayload()

if failures > 0 then
  print(string.format("\nSecret-Value pipeline simulator failed: %d check(s) failed", failures))
  os.exit(1)
end

print("\nSecret-Value pipeline simulator passed.")
