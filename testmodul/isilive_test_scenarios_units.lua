return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test.describe("Units Robustness", function()
    test.it("Units GetUnitRole returns NONE for non-existing unit", function()
      WithGlobals({
        UnitExists = function(u)
          return u == "player" -- "party1" exists not
        end,
        UnitGroupRolesAssigned = function(_u)
          return "DAMAGER"
        end,
        UnitIsUnit = function(a, b)
          return a == b
        end,
        UnitClass = function(unit)
          if unit == "player" then
            return "Warrior", "WARRIOR"
          end
          error("UnitClass must not be called for missing units")
        end,
        GetInspectSpecialization = function(unit)
          if unit == "player" then
            return 72
          end
          error("GetInspectSpecialization must not be called for missing units")
        end,
        GetSpecializationInfoByID = function(specID)
          if specID == 72 then
            return nil, "Fury"
          end
          error("GetSpecializationInfoByID must not be called for unexpected spec IDs")
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units

        -- Case 1: Unit exists
        local roleExisting = Units.GetUnitRole("player")
        Assert.Equal(roleExisting, "DAMAGER", "existing unit should keep its assigned group role")
        local localizedClass, classToken = Units.GetUnitClass("player")
        Assert.Equal(localizedClass, "Warrior", "existing unit should keep its localized class")
        Assert.Equal(classToken, "WARRIOR", "existing unit should keep its class token")
        local inspectSpecName = Units.GetInspectSpecName("player")
        Assert.Equal(inspectSpecName, "Fury", "existing unit should resolve its inspect specialization")

        -- Case 2: Unit does not exist (simulating race condition)
        -- If UnitGroupRolesAssigned was called, it might return something or crash,
        -- but our mock ensures we rely on UnitExists check first.
        local roleNonExisting = Units.GetUnitRole("party1")
        Assert.Equal(roleNonExisting, "NONE", "non-existing unit should return NONE safely")
        local classNonExisting, classTokenNonExisting = Units.GetUnitClass("party1")
        Assert.Nil(classNonExisting, "non-existing unit should return nil localized class")
        Assert.Nil(classTokenNonExisting, "non-existing unit should return nil class token")
        local inspectSpecMissing = Units.GetInspectSpecName("party1")
        Assert.Nil(inspectSpecMissing, "non-existing unit should return nil inspect specialization")
      end)
    end)

    test.it("Units GetUnitNameAndRealm returns nil for non-existing unit", function()
      WithGlobals({
        UnitExists = function(u)
          return u == "player"
        end,
        UnitFullName = function(_u)
          return "TestName", "TestRealm"
        end,
        UnitName = function(_u)
          return "TestName"
        end,
        GetRealmName = function()
          return "LocalRealm"
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units

        -- Case 1: Unit exists
        local name, realm = Units.GetUnitNameAndRealm("player")
        Assert.Equal(name, "TestName")
        Assert.Equal(realm, "TestRealm")

        -- Case 2: Unit does not exist
        local nameGhost, realmGhost = Units.GetUnitNameAndRealm("party99")
        Assert.Nil(nameGhost, "non-existing unit should return nil name")
        Assert.Nil(realmGhost, "non-existing unit should return nil realm")
      end)
    end)
  end)
end
