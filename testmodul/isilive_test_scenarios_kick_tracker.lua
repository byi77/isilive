---@diagnostic disable: undefined-global
---@class KickController
---@field GetKickInfo fun(): table
---@field ResolveKickState fun(): table
---@field OnCast fun(unit: string, spellID: number): boolean|nil
---@field CacheCooldown fun(): boolean|nil
---@field Scan fun()

---@param controller KickController|nil
---@param message string
---@param Assert table
---@return KickController
local function RequireController(controller, message, Assert)
  Assert.NotNil(controller, message)
  if controller == nil then
    error(message)
  end
  return controller
end

local function RegisterBasicKickTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KickTracker reports no interrupt for Holy Paladin (no Rebuke in Midnight)", function()
    ---@type KickController|nil
    local controller = nil
    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 65
        end
        return nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return 100
        end,
      })
    end)

    local kickController = RequireController(controller, "kick info must exist for Holy Paladin", Assert)
    local info = kickController.GetKickInfo()
    Assert.NotNil(info, "kick info must exist for Holy Paladin")
    Assert.False(info.hasKick, "Holy Paladin must report hasKick=false (no Rebuke in Midnight)")
    Assert.Equal(info.spellID, nil, "Holy Paladin must not resolve any interrupt spell")
  end)

  test("KickTracker resolves Devourer Demon Hunter to Disrupt", function()
    ---@type KickController|nil
    local controller = nil
    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 1480
        end
        return nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return 100
        end,
      })
    end)

    local kickController = RequireController(controller, "kick info must exist for Devourer Demon Hunter", Assert)
    local info = kickController.GetKickInfo()
    Assert.NotNil(info, "kick info must exist for Devourer Demon Hunter")
    Assert.Equal(info.spellID, 183752, "Devourer Demon Hunter must map to Disrupt")
    Assert.False(info.onCooldown, "fresh Devourer interrupt must start ready")
  end)

  test("KickTracker keeps unresolved kick availability distinct from exact no-kick", function()
    ---@type KickController|nil
    local controller = nil
    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 9999
        end
        return nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return 100
        end,
      })
    end)

    local kickController =
      RequireController(controller, "kick info table must still exist for unresolved kick availability", Assert)
    local info = kickController.GetKickInfo()
    local resolvedState = kickController.ResolveKickState()
    Assert.NotNil(info, "kick info table must still exist for unresolved kick availability")
    Assert.False(
      info.availabilityResolved,
      "unknown specialization mapping must stay unresolved instead of becoming no-kick"
    )
    Assert.False(info.hasKick, "unresolved kick availability must not expose a kick")
    Assert.Nil(info.spellID, "unresolved kick availability must not invent a spellID")
    Assert.False(
      resolvedState.availabilityResolved,
      "ResolveKickState must preserve unresolved kick availability for unknown specializations"
    )
    Assert.False(resolvedState.hasKick, "unresolved kick availability must not become an exact no-kick state")
    Assert.False(
      resolvedState.exactCooldownKnown,
      "unresolved kick availability must not claim exact cooldown recovery"
    )
  end)
end

local function RegisterKickMatrixTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KickTracker resolves interrupt matrix for all mapped specs", function()
    local mappedSpecs = {
      { specID = 250, spellID = 47528, label = "Blood Death Knight" },
      { specID = 251, spellID = 47528, label = "Frost Death Knight" },
      { specID = 252, spellID = 47528, label = "Unholy Death Knight" },
      { specID = 577, spellID = 183752, label = "Havoc Demon Hunter" },
      { specID = 581, spellID = 183752, label = "Vengeance Demon Hunter" },
      { specID = 1480, spellID = 183752, label = "Devourer Demon Hunter" },
      { specID = 102, spellID = 78675, label = "Balance Druid" },
      { specID = 103, spellID = 106839, label = "Feral Druid" },
      { specID = 104, spellID = 106839, label = "Guardian Druid" },
      { specID = 1467, spellID = 351338, label = "Devastation Evoker" },
      { specID = 1468, spellID = 351338, label = "Preservation Evoker" },
      { specID = 1473, spellID = 351338, label = "Augmentation Evoker" },
      { specID = 253, spellID = 147362, label = "Beast Mastery Hunter" },
      { specID = 254, spellID = 147362, label = "Marksmanship Hunter" },
      { specID = 255, spellID = 187707, label = "Survival Hunter" },
      { specID = 62, spellID = 2139, label = "Arcane Mage" },
      { specID = 63, spellID = 2139, label = "Fire Mage" },
      { specID = 64, spellID = 2139, label = "Frost Mage" },
      { specID = 268, spellID = 116705, label = "Brewmaster Monk" },
      { specID = 269, spellID = 116705, label = "Windwalker Monk" },
      { specID = 66, spellID = 96231, label = "Protection Paladin" },
      { specID = 70, spellID = 96231, label = "Retribution Paladin" },
      { specID = 258, spellID = 15487, label = "Shadow Priest" },
      { specID = 259, spellID = 1766, label = "Assassination Rogue" },
      { specID = 260, spellID = 1766, label = "Outlaw Rogue" },
      { specID = 261, spellID = 1766, label = "Subtlety Rogue" },
      { specID = 262, spellID = 57994, label = "Elemental Shaman" },
      { specID = 263, spellID = 57994, label = "Enhancement Shaman" },
      { specID = 264, spellID = 57994, label = "Restoration Shaman" },
      { specID = 265, spellID = 19647, label = "Affliction Warlock" },
      { specID = 266, spellID = 119914, label = "Demonology Warlock" },
      { specID = 267, spellID = 19647, label = "Destruction Warlock" },
      { specID = 71, spellID = 6552, label = "Arms Warrior" },
      { specID = 72, spellID = 6552, label = "Fury Warrior" },
      { specID = 73, spellID = 6552, label = "Protection Warrior" },
    }

    for _, spec in ipairs(mappedSpecs) do
      WithGlobals({
        GetSpecialization = function()
          return 1
        end,
        GetSpecializationInfo = function(index)
          if index == 1 then
            return spec.specID
          end
          return nil
        end,
        UnitExists = function(unit)
          if unit == "pet" and (spec.specID == 265 or spec.specID == 266 or spec.specID == 267) then
            return true
          end
          return false
        end,
        GetSpellBaseCooldown = function(spellID)
          if spellID == spec.spellID then
            if spellID == 119914 then
              return 30000 -- Demo Warlock Axe Toss (player-facing ID)
            end
            if spellID == 78675 then
              return 45000 -- Balance Druid Solar Beam (Midnight: 45s)
            end
            if spellID == 351338 then
              return 18000 -- Evoker Quell (Midnight: 18s)
            end
            if spellID == 2139 then
              return 25000 -- Mage Counterspell (25s base; talent 382297 reduces to 20s)
            end
            if spellID == 147362 then
              return 24000
            end
            if spellID == 15487 then
              return 30000
            end
            if spellID == 57994 then
              if spec.specID == 264 then
                return 30000
              end
              return 12000
            end
            return 15000
          end
          return 0
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
        local controller = addon.KickTracker.CreateController({
          getTime = function()
            return 100
          end,
        })
        local kickController = RequireController(controller, spec.label .. " must produce kick info", Assert)
        local info = kickController.GetKickInfo()
        Assert.True(info.availabilityResolved, spec.label .. " kick availability must resolve")
        Assert.True(info.hasKick, spec.label .. " must expose a kick")
        Assert.Equal(info.spellID, spec.spellID, spec.label .. " must resolve the expected interrupt spell")
        Assert.False(info.onCooldown, spec.label .. " must start ready")
        Assert.Equal(info.cooldownRemain, 0, spec.label .. " must start with zero remaining cooldown")
      end)
    end
  end)

  test("KickTracker resolves exact no-kick matrix for supported specs", function()
    local noKickSpecs = {
      { specID = 105, label = "Restoration Druid" },
      { specID = 256, label = "Discipline Priest" },
      { specID = 257, label = "Holy Priest" },
      { specID = 65, label = "Holy Paladin" },
      { specID = 270, label = "Mistweaver Monk" },
    }

    for _, spec in ipairs(noKickSpecs) do
      WithGlobals({
        GetSpecialization = function()
          return 1
        end,
        GetSpecializationInfo = function(index)
          if index == 1 then
            return spec.specID
          end
          return nil
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
        local controller = addon.KickTracker.CreateController({
          getTime = function()
            return 100
          end,
        })
        local kickController = RequireController(controller, spec.label .. " must still produce kick info", Assert)
        local info = kickController.GetKickInfo()
        local resolvedState = kickController.ResolveKickState()
        Assert.True(info.availabilityResolved, spec.label .. " no-kick state must resolve exactly")
        Assert.False(info.hasKick, spec.label .. " must stay in the exact no-kick state")
        Assert.Nil(info.spellID, spec.label .. " must not invent an interrupt spell")
        Assert.False(info.onCooldown, spec.label .. " must not appear on cooldown")
        Assert.True(
          resolvedState.availabilityResolved,
          spec.label .. " ResolveKickState must preserve the exact no-kick state"
        )
        Assert.False(resolvedState.hasKick, spec.label .. " ResolveKickState must not invent a kick")
      end)
    end
  end)
end

local function RegisterWarlockKickTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KickTracker resolves Warlock pet-based Spell Lock for Affliction and Destruction", function()
    local warlockSpecs = { 265, 267 }

    for _, specID in ipairs(warlockSpecs) do
      WithGlobals({
        GetSpecialization = function()
          return 1
        end,
        GetSpecializationInfo = function(index)
          if index == 1 then
            return specID
          end
          return nil
        end,
        UnitExists = function(unit)
          return unit == "pet"
        end,
        GetSpellBaseCooldown = function(spellID)
          if spellID == 19647 then
            return 24000
          end
          return 0
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
        ---@type KickController|nil
        local controller = addon.KickTracker.CreateController({
          getTime = function()
            return 100
          end,
        })
        local kickController =
          RequireController(controller, "kick info table must exist for tracked warlock pet interrupts", Assert)
        local info = kickController.GetKickInfo()
        Assert.Equal(info.spellID, 19647, "Warlock spec " .. tostring(specID) .. " must resolve pet Spell Lock")
        Assert.False(info.onCooldown, "tracked pet interrupt must start ready")
      end)
    end
  end)

  test("KickTracker resolves Demonology Warlock pet interrupt when available", function()
    ---@type KickController|nil
    local controller = nil
    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 266
        end
        return nil
      end,
      UnitExists = function(unit)
        return unit == "pet"
      end,
      GetSpellBaseCooldown = function(spellID)
        if spellID == 119914 then
          return 30000
        end
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return 100
        end,
      })
    end)

    local kickController =
      RequireController(controller, "kick info must exist for Demonology when the pet interrupt is available", Assert)
    local info = kickController.GetKickInfo()
    Assert.NotNil(info, "kick info must exist for Demonology when the pet interrupt is available")
    Assert.Equal(info.spellID, 119914, "Demonology must prefer the player-facing Axe Toss spell ID")
    Assert.False(info.onCooldown, "available Demonology pet interrupt must start ready")
  end)

  test("KickTracker tracks Demonology Axe Toss cooldown from the pet-cast spell alias", function()
    local now = 100
    ---@type KickController|nil
    local controller = nil
    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 266
        end
        return nil
      end,
      UnitExists = function(unit)
        return unit == "pet"
      end,
      GetSpellBaseCooldown = function(spellID)
        if spellID == 119914 then
          return 30000
        end
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return now
        end,
      })
    end)

    local kickController =
      RequireController(controller, "kick info must exist for Demonology Axe Toss alias tracking", Assert)
    local castOk = kickController.OnCast("pet", 89766)
    local info = kickController.GetKickInfo()

    Assert.True(castOk, "raw pet-cast Axe Toss spell ID must be accepted as a verified cast alias")
    Assert.Equal(info.spellID, 119914, "Axe Toss display spell must remain the player-facing spell ID")
    Assert.True(info.onCooldown, "pet-cast Axe Toss alias must start the primary cooldown")
    Assert.Equal(info.cooldownRemain, 30, "Axe Toss alias cooldown must use the exact configured duration")
  end)

  test("KickTracker shows no kick when Warlock pet interrupt is unavailable", function()
    ---@type KickController|nil
    local controller = nil
    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 265
        end
        return nil
      end,
      UnitExists = function(_)
        return false
      end,
      GetSpellBaseCooldown = function(_spellID)
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return 100
        end,
      })
    end)

    local kickController =
      RequireController(controller, "kick info table must still exist when no pet interrupt is available", Assert)
    local info = kickController.GetKickInfo()
    Assert.NotNil(info, "kick info table must still exist when no pet interrupt is available")
    Assert.Nil(info.spellID, "missing pet interrupt must render as no available kick")
    Assert.False(info.onCooldown, "missing pet interrupt must not appear on cooldown")
    Assert.Equal(info.cooldownRemain, 0, "missing pet interrupt must keep zero cooldown")
  end)

  test("KickTracker tracks pet-based Warlock interrupt cooldown from pet casts", function()
    local now = 100
    ---@type KickController|nil
    local controller = nil
    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 265
        end
        return nil
      end,
      UnitExists = function(unit)
        return unit == "pet"
      end,
      GetSpellBaseCooldown = function(spellID)
        if spellID == 19647 then
          return 24000
        end
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return now
        end,
      })
      local kickController =
        RequireController(controller, "kick info must exist for pet-based interrupt tracking", Assert)
      kickController.OnCast("player", 19647)
      local idleInfo = kickController.GetKickInfo()
      Assert.False(idleInfo.onCooldown, "player casts must not start pet-based interrupt cooldowns")

      kickController.OnCast("pet", 19647)
      local activeInfo = kickController.GetKickInfo()
      Assert.True(activeInfo.onCooldown, "pet cast must start the tracked interrupt cooldown")
      Assert.Equal(activeInfo.cooldownRemain, 24, "pet interrupt cooldown must use the configured duration")
    end)
  end)
end

local function RegisterCooldownRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KickTracker reconstructs active cooldown from Blizzard cooldown data without guessing", function()
    local now = 100
    ---@type KickController|nil
    local controller = nil

    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 71
        end
        return nil
      end,
      GetSpellBaseCooldown = function(spellID)
        if spellID == 6552 then
          return 15000
        end
        return 0
      end,
      InCombatLockdown = function()
        return true
      end,
      C_Spell = {
        GetSpellCooldown = function(spellID)
          if spellID == 6552 then
            return {
              startTime = 94,
              duration = 15,
              isEnabled = true,
            }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return now
        end,
      })
    end)

    local kickController =
      RequireController(controller, "kick info must exist when Blizzard cooldown data is available", Assert)
    local info = kickController.GetKickInfo()
    Assert.NotNil(info, "kick info must exist when Blizzard cooldown data is available")
    Assert.Equal(info.spellID, 6552, "Warrior interrupt must still resolve to Pummel")
    Assert.True(info.onCooldown, "active Blizzard cooldown data must restore a running kick cooldown")
    Assert.Equal(info.cooldownRemain, 9, "reconstructed kick cooldown must use Blizzard start/duration data exactly")
  end)

  test("KickTracker keeps observed active cooldown when Blizzard cooldown fields are unreadable", function()
    local now = 100
    ---@type KickController|nil
    local controller = nil
    local secretValue = {}
    local cooldownPayload = {
      startTime = 0,
      duration = 0,
      isEnabled = true,
    }

    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 71
        end
        return nil
      end,
      GetSpellBaseCooldown = function(spellID)
        if spellID == 6552 then
          return 15000
        end
        return 0
      end,
      issecretvalue = function(value)
        return value == secretValue
      end,
      C_Spell = {
        GetSpellCooldown = function(spellID)
          if spellID == 6552 then
            return cooldownPayload
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return now
        end,
      })
    end)

    local kickController = RequireController(controller, "kick info must exist while reconstructing cooldown", Assert)
    kickController.OnCast("player", 6552)
    local observedInfo = kickController.GetKickInfo()
    Assert.True(observedInfo.onCooldown, "observed player casts must establish a local active cooldown")
    Assert.Equal(observedInfo.cooldownRemain, 15, "observed kick casts must keep the configured cooldown remain")

    cooldownPayload = {
      startTime = secretValue,
      duration = secretValue,
      isEnabled = true,
    }

    local exactStateKnown = kickController.CacheCooldown()
    local refreshedInfo = kickController.GetKickInfo()
    Assert.False(exactStateKnown, "unreadable Blizzard cooldown payloads must not be treated as exact kick state")
    Assert.True(refreshedInfo.onCooldown, "unreadable cooldown payloads must not clear an already observed active kick")
    Assert.Equal(
      refreshedInfo.cooldownRemain,
      15,
      "unreadable cooldown payloads must preserve the observed cooldown remain instead of guessing ready"
    )
  end)

  test("KickTracker scans all talent trees for cooldown reductions", function()
    local now = 100
    ---@type KickController|nil
    local controller = nil

    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 71
        end
        return nil
      end,
      GetSpellBaseCooldown = function(spellID)
        if spellID == 6552 then
          return 15000
        end
        return 0
      end,
      C_ClassTalents = {
        GetActiveConfigID = function()
          return 42
        end,
      },
      C_Traits = {
        GetConfigInfo = function(configID)
          if configID == 42 then
            return {
              treeIDs = { 1001, 1002 },
            }
          end
          return nil
        end,
        GetTreeNodes = function(treeID)
          if treeID == 1001 then
            return { 11 }
          end
          if treeID == 1002 then
            return { 22 }
          end
          return nil
        end,
        GetNodeInfo = function(_configID, nodeID)
          if nodeID == 11 then
            return nil
          end
          if nodeID == 22 then
            return {
              activeEntry = { entryID = 222 },
              activeRank = 1,
            }
          end
          return nil
        end,
        GetEntryInfo = function(_configID, entryID)
          if entryID == 222 then
            return { definitionID = 333 }
          end
          return nil
        end,
        GetDefinitionInfo = function(definitionID)
          if definitionID == 333 then
            return { spellID = 391271 }
          end
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return now
        end,
      })
    end)

    local kickController =
      RequireController(controller, "kick info must exist while scanning multiple talent trees", Assert)
    local observedKick = kickController.OnCast("player", 6552)
    local info = kickController.GetKickInfo()

    Assert.True(observedKick, "tracked warrior kick cast must still be observed")
    Assert.True(info.onCooldown, "tracked warrior kick cast must still start cooldown")
    Assert.Equal(info.cooldownRemain, 14, "cooldown reduction on a non-first talent tree must be applied exactly")
  end)
end

local function RegisterMultiKickExtrasTests(test, Assert, WithGlobals, LoadAddonModules)
  test("KickTracker tracks Avenger's Shield as an extra kick for Protection Paladin", function()
    ---@type KickController|nil
    local controller = nil
    local clock = 100
    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 66
        end
        return nil
      end,
      UnitClass = function(unit)
        if unit == "player" then
          return "Paladin", "PALADIN"
        end
        return nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return clock
        end,
      })
    end)

    local kickController = RequireController(controller, "Prot Paladin must build", Assert)
    local info = kickController.GetKickInfo()
    Assert.Equal(info.spellID, 96231, "primary must be Rebuke")
    Assert.Equal(info.extras, nil, "no extras before any cast")

    -- Cast Avenger's Shield (31935) -> must land in extras, not primary.
    local castOk = kickController.OnCast("player", 31935)
    Assert.True(castOk, "Avenger's Shield cast must be tracked as an extra")
    info = kickController.GetKickInfo()
    Assert.Equal(info.spellID, 96231, "primary must remain Rebuke after extra-cast")
    Assert.False(info.onCooldown, "primary must NOT be marked on cooldown by extra-cast")
    Assert.NotNil(info.extras, "extras map must be populated")
    Assert.NotNil(info.extras[31935], "Avenger's Shield must appear in extras map")
    Assert.True(info.extras[31935].onCooldown, "extra entry must be marked on cooldown")
    Assert.True(info.extras[31935].cooldownRemain > 0, "extra entry remain must be > 0 right after cast")
  end)

  test("KickTracker drops expired extras on Scan", function()
    ---@type KickController|nil
    local controller = nil
    local clock = 100
    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 66
        end
        return nil
      end,
      UnitClass = function(unit)
        if unit == "player" then
          return "Paladin", "PALADIN"
        end
        return nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return clock
        end,
      })
    end)

    local kickController = RequireController(controller, "Prot Paladin must build", Assert)
    kickController.OnCast("player", 31935)
    Assert.NotNil(kickController.GetKickInfo().extras[31935], "extra must exist right after cast")

    clock = clock + 15
    kickController.Scan()
    Assert.NotNil(kickController.GetKickInfo().extras[31935], "extra must remain before its cooldown expires")

    -- Advance clock past the 30s Avenger's Shield CD.
    clock = clock + 20
    kickController.Scan()
    local info = kickController.GetKickInfo()
    Assert.Equal(info.extras, nil, "expired extras must be removed by Scan")
  end)

  test("KickTracker ignores casts of non-class-interrupt spells", function()
    ---@type KickController|nil
    local controller = nil
    WithGlobals({
      GetSpecialization = function()
        return 1
      end,
      GetSpecializationInfo = function(index)
        if index == 1 then
          return 66
        end
        return nil
      end,
      UnitClass = function(unit)
        if unit == "player" then
          return "Paladin", "PALADIN"
        end
        return nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_kick_tracker.lua" })
      controller = addon.KickTracker.CreateController({
        getTime = function()
          return 100
        end,
      })
    end)

    local kickController = RequireController(controller, "Prot Paladin must build", Assert)
    local castOk = kickController.OnCast("player", 999999) -- random non-interrupt spell
    Assert.False(castOk, "non-interrupt cast must NOT be tracked")
    Assert.Equal(kickController.GetKickInfo().extras, nil, "extras must stay empty")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterBasicKickTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKickMatrixTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterWarlockKickTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCooldownRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterMultiKickExtrasTests(test, Assert, WithGlobals, LoadAddonModules)
end
