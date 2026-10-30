---@diagnostic disable: undefined-global

-- data/isiLive_spells.lua and data/isiLive_specs.lua replaced per-module ID
-- tables on 2026-10-20. The snapshots below are those former tables verbatim;
-- the tests drive the real consumers so a manifest edit that changes runtime
-- behaviour shows up here, and run the coverage gate on the shipped files.

local FORMER_BATTLE_RES = { 20484, 61999, 391054, 20707 }
local FORMER_LUST_CASTS = {
  2825,
  32182,
  80353,
  264667,
  390386,
  466904,
  381301,
  178207,
  230935,
  256740,
  292463,
  90355,
  160452,
}
local FORMER_LUST_BUTTON_SPELLS = { 2825, 32182, 80353, 264667, 390386, 466904, 90355, 160452 }
local FORMER_LUST_SATED = { 57723, 57724, 80354, 264689, 390435, 95809 }

local FORMER_INTELLECT =
  { 62, 63, 64, 65, 102, 105, 256, 257, 258, 262, 264, 265, 266, 267, 270, 1467, 1468, 1473, 1480 }
local FORMER_AP = {
  66,
  70,
  71,
  72,
  73,
  103,
  104,
  250,
  251,
  252,
  253,
  254,
  255,
  259,
  260,
  261,
  263,
  268,
  269,
  577,
  581,
}
local FORMER_MAGIC = { 62, 63, 64, 251, 252, 102, 256, 257, 258, 262, 264, 265, 266, 267, 1467, 1468, 1473, 1480 }
local FORMER_PHYSICAL = { 66, 70, 71, 72, 73, 103, 104, 250, 253, 254, 255, 259, 260, 261, 263, 268, 269, 577, 581 }
local FORMER_PRIMARY_BY_SPEC = {
  [65] = "intellect",
  [66] = "strength",
  [70] = "strength",
  [102] = "intellect",
  [103] = "agility",
  [104] = "agility",
  [105] = "intellect",
  [262] = "intellect",
  [263] = "agility",
  [264] = "intellect",
  [268] = "agility",
  [269] = "agility",
  [270] = "intellect",
  [577] = "agility",
  [581] = "agility",
  [1480] = "intellect",
}
local FORMER_PRIMARY_BY_CLASS = {
  DEATHKNIGHT = "strength",
  EVOKER = "intellect",
  HUNTER = "agility",
  MAGE = "intellect",
  PRIEST = "intellect",
  ROGUE = "agility",
  WARLOCK = "intellect",
  WARRIOR = "strength",
}
local FORMER_SPEC_CLASS_TOKENS = { [253] = "HUNTER", [254] = "HUNTER", [255] = "HUNTER", [1473] = "EVOKER" }

local function ToSet(list)
  local set = {}
  for _, value in ipairs(list) do
    set[value] = true
  end
  return set
end

local function SortedKeys(map)
  local keys = {}
  for key in pairs(map) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function AssertSameSet(Assert, actual, expectedList, label)
  local expected = ToSet(expectedList)
  for _, id in ipairs(SortedKeys(expected)) do
    Assert.True(actual[id] == true, string.format("%s must contain %d", label, id))
  end
  for _, id in ipairs(SortedKeys(actual)) do
    Assert.True(expected[id] == true, string.format("%s must not contain %d", label, id))
  end
end

local function RegisterSpellManifestTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("SpellManifest keeps the former Battle Res, Lust, Sated and PI ID sets", function()
    local addon = LoadAddonModules({ "isiLive_spells.lua" })
    local Spells, Manifest = addon.Spells, addon.SpellManifest
    local battleRes = Spells.BuildIDList(Manifest.battleRes)
    Assert.Equal(#battleRes, #FORMER_BATTLE_RES, "Battle Res list keeps its length")
    for index, id in ipairs(FORMER_BATTLE_RES) do
      Assert.Equal(battleRes[index], id, "Battle Res scan order must stay unchanged at " .. index)
    end
    AssertSameSet(Assert, Spells.BuildIDSet(Manifest.lustCasts), FORMER_LUST_CASTS, "lustCasts")
    AssertSameSet(
      Assert,
      Spells.BuildIDSet(Manifest.lustCasts, Spells.IsActionButtonLust),
      FORMER_LUST_BUTTON_SPELLS,
      "action-button Lust spells"
    )
    AssertSameSet(Assert, Spells.BuildIDSet(Manifest.lustSated), FORMER_LUST_SATED, "lustSated")
    Assert.Equal(Manifest.powerInfusion, 10060, "Power Infusion spell ID")
    Assert.Equal(Manifest.icons.battleRes, 20484, "Battle Res row icon spell")
    Assert.Equal(Manifest.icons.lust, 2825, "Lust row icon spell")
  end)

  test("CombatEvents announces every manifest Battle Res and Lust cast through the real controller", function()
    local addon = nil
    WithGlobals({
      GetTime = function()
        return 0
      end,
    }, function()
      addon = LoadAddonModules({ "isiLive_combat_events.lua" })
    end)
    local now = 0
    local broadcasts = {}
    local controller = addon.CombatEvents.CreateController({
      getTime = function()
        return now
      end,
      isInKey = function()
        return true
      end,
      getUnitName = function()
        return "Alice-Realm"
      end,
      broadcastCombatAnnounce = function(kind, _, spellID)
        broadcasts[#broadcasts + 1] = { kind = kind, spellID = spellID }
      end,
      getDB = function()
        return {}
      end,
    })
    local function Cast(spellID)
      now = now + 10
      local before = #broadcasts
      controller.HandleUnitSpellcastSucceeded("player", "cast-" .. spellID, spellID)
      return #broadcasts == before + 1 and broadcasts[#broadcasts] or nil
    end
    for _, id in ipairs(FORMER_BATTLE_RES) do
      local sent = Cast(id)
      Assert.True(sent ~= nil and sent.kind == "BR", "spell " .. id .. " must announce as BR")
    end
    for _, id in ipairs(FORMER_LUST_CASTS) do
      local sent = Cast(id)
      Assert.True(sent ~= nil and sent.kind == "LUST", "spell " .. id .. " must announce as LUST")
    end
    for _, id in ipairs(FORMER_LUST_SATED) do
      Assert.Nil(Cast(id), "Sated debuff " .. id .. " is not a cast and must stay silent")
    end
  end)

  test("CdTracker reports every manifest Sated debuff as active Lust lockout", function()
    local NOW = 1000
    for _, id in ipairs(FORMER_LUST_SATED) do
      local auras = { { spellId = id, expirationTime = NOW + 300, icon = 1 } }
      WithGlobals({
        C_UnitAuras = {
          GetAuraDataByIndex = function(unit, index, filter)
            if unit ~= "player" or filter ~= "HARMFUL" then
              return nil
            end
            return auras[index]
          end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_cd_tracker.lua" })
        local ctrl = addon.CdTracker.CreateController({
          getTime = function()
            return NOW
          end,
        })
        ctrl.Scan()
        local info = ctrl.GetLustInfo()
        Assert.True(info ~= nil and info.remain == 300, "Sated debuff " .. id .. " must report 300s remaining")
      end)
    end
  end)
end

local function RegisterSpecManifestTests(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function SpecGlobals(classToken, specID, extra)
    local globals = {
      UnitExists = function()
        return true
      end,
      UnitClass = function()
        return classToken, classToken
      end,
      GetSpecialization = function()
        return specID and 1 or nil
      end,
      GetSpecializationInfo = function()
        return specID
      end,
    }
    for key, value in pairs(extra or {}) do
      globals[key] = value
    end
    return globals
  end

  test("LFG bonus profile classifies every manifest spec exactly like the former lists", function()
    local specs = LoadAddonModules({ "isiLive_specs.lua" }).SpecManifest.specs
    local intellect, ap = ToSet(FORMER_INTELLECT), ToSet(FORMER_AP)
    local magic, physical = ToSet(FORMER_MAGIC), ToSet(FORMER_PHYSICAL)
    for _, specID in ipairs(SortedKeys(specs)) do
      local profile
      WithGlobals(SpecGlobals(specs[specID].class, specID), function()
        profile = LoadAddonModules({ "isiLive_lfg_bonus_model.lua" }).LFGBonusModel.ResolvePlayerBonusProfile()
      end)
      local label = "spec " .. specID
      Assert.Equal(profile.specID, specID, label .. " profile spec")
      Assert.Equal(profile.usesIntellect, intellect[specID] == true, label .. " usesIntellect")
      Assert.Equal(profile.usesAttackPower, ap[specID] == true, label .. " usesAttackPower")
      Assert.Equal(profile.dealsMagicDamage, magic[specID] == true, label .. " dealsMagicDamage")
      Assert.Equal(profile.dealsPhysicalDamage, physical[specID] == true, label .. " dealsPhysicalDamage")
    end
  end)

  test("LFG spec bonus class gate stays limited to the specs with spec-level bonuses", function()
    local model = LoadAddonModules({ "isiLive_lfg_bonus_model.lua" }).LFGBonusModel
    local actual = model.SPEC_CLASS_TOKENS
    for _, specID in ipairs(SortedKeys(FORMER_SPEC_CLASS_TOKENS)) do
      Assert.Equal(actual[specID], FORMER_SPEC_CLASS_TOKENS[specID], "spec " .. specID .. " bonus class")
    end
    for _, specID in ipairs(SortedKeys(actual)) do
      Assert.True(FORMER_SPEC_CLASS_TOKENS[specID] ~= nil, "spec " .. specID .. " must not join the bonus gate")
    end
  end)

  test("StatsBox resolves the primary stat of every manifest spec exactly like the former tables", function()
    local helpers = assert(loadfile("testmodul/isilive_test_ui_helpers.lua"))()
    local specs = LoadAddonModules({ "isiLive_specs.lua" }).SpecManifest.specs
    local statByKey = { strength = 1, agility = 2, intellect = 4 }
    for _, specID in ipairs(SortedKeys(specs)) do
      local classToken = specs[specID].class
      local expected = FORMER_PRIMARY_BY_SPEC[specID] or FORMER_PRIMARY_BY_CLASS[classToken]
      local rows
      WithGlobals({ UIParent = {}, CreateFrame = helpers.BuildCreateFrameStub() }, function()
        local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_stats_box.lua" })
        rows = addon.StatsBox.CollectPlayerStats({
          UnitStat = function(_unit, statIndex)
            return 0, statIndex * 100
          end,
          UnitClass = function()
            return classToken, classToken
          end,
          GetSpecialization = function()
            return 1
          end,
          GetSpecializationInfo = function()
            return specID
          end,
        })
      end)
      local primary = rows[1] and statByKey[rows[1].key] and rows[1] or nil
      if expected then
        Assert.True(primary ~= nil and primary.key == expected, string.format("spec %d primary %s", specID, expected))
      else
        Assert.Nil(primary, string.format("spec %d must not guess a primary stat", specID))
      end
    end
  end)
end

local function RegisterSpecCoverageGateTests(test, ctx)
  local Assert = ctx.assert

  local function LoadGate()
    local chunk = assert(loadfile("tools/check_spec_coverage.lua"))
    return chunk()
  end

  local function WriteTemp(content)
    local path = os.tmpname()
    local file = assert(io.open(path, "wb"))
    file:write(content)
    file:close()
    return path
  end

  test("Spec coverage gate passes on the shipped data, kick tracker and runtime modules", function()
    local ok, result = LoadGate().Check({})
    Assert.True(ok, "spec coverage gate must pass: " .. table.concat(result.errors, "; "))
    Assert.Equal(result.specCount, 40, "the manifest carries all 40 current specs")
  end)

  test("Spec coverage gate rejects a spec without interrupt decision or required fields", function()
    local dataPath = WriteTemp([[
local _, addonTable = ...
addonTable.SpecManifest = { specs = {
  [62] = { class = "MAGE", name = "Arcane",
    lfg = { intellect = true, attackPower = false, magicDamage = true, physicalDamage = false } },
  [9999] = { class = "MAGE", lfg = { intellect = true } },
} }
]])
    local kickPath = WriteTemp(
      "local x = 1\nlocal NO_INTERRUPT_SPEC_IDS = {\n}\n\n"
        .. "local SPEC_DATA = {\n  [62] = { spellID = 2139, cd = 25 },\n}\n"
    )
    local ok, result = LoadGate().Check({ dataPath = dataPath, kickTrackerPath = kickPath, scanFiles = {} })
    os.remove(dataPath)
    os.remove(kickPath)
    local text = table.concat(result.errors, "\n")
    Assert.False(ok, "gate must fail")
    Assert.True(text:find("spec 9999: name is required", 1, true) ~= nil, "missing name is reported")
    Assert.True(text:find("lfg.attackPower must be an explicit boolean", 1, true) ~= nil, "missing flag is reported")
    Assert.True(text:find("spec 9999 has no interrupt decision", 1, true) ~= nil, "missing kick entry is reported")
    Assert.True(text:find("spec 62 has no interrupt decision", 1, true) == nil, "covered spec stays clean")
  end)

  test("Spec coverage gate flags a literal spec-ID table outside data/ but not other number keys", function()
    local gate = LoadGate()
    local specs = { [62] = {}, [63] = {}, [64] = {} }
    local flagged = gate.FindLiteralSpecTables(
      "ui/x.lua",
      "local MAGE_SPECS = {\n  [62] = true,\n  -- Fire\n  [63] = true,\n  [64] = true,\n}\n",
      specs
    )
    Assert.Equal(#flagged, 1, "one literal spec table is flagged")
    Assert.Equal(flagged[1].name, "MAGE_SPECS", "the table name is reported")
    local clean = gate.FindLiteralSpecTables(
      "ui/y.lua",
      "local OTHER = {\n  [62] = true,\n  [5000] = true,\n  [63] = true,\n}\n",
      specs
    )
    Assert.Equal(#clean, 0, "a run broken below the threshold is not flagged")
  end)
end

return function(test, ctx)
  RegisterSpellManifestTests(test, ctx)
  RegisterSpecManifestTests(test, ctx)
  RegisterSpecCoverageGateTests(test, ctx)
end
