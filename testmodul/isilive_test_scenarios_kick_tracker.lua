---@diagnostic disable: undefined-global
---@class KickController
---@field GetKickInfo fun(): table
---@field ResolveKickState fun(): table
---@field OnCast fun(unit: string, spellID: number): boolean|nil
---@field CacheCooldown fun(): boolean|nil

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
  test("KickTracker resolves Holy Paladin to Rebuke", function()
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
    Assert.Equal(info.spellID, 96231, "Holy Paladin must map to Rebuke")
    Assert.False(info.onCooldown, "fresh Holy Paladin interrupt must start ready")
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
        if spellID == 89766 then
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
    Assert.Equal(info.spellID, 89766, "Demonology must prefer the available pet interrupt")
    Assert.False(info.onCooldown, "available Demonology pet interrupt must start ready")
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
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterBasicKickTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterWarlockKickTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCooldownRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
end
