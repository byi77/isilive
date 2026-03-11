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
          return "NONE" -- Return NONE so we test the fallback or empty state
        end,
        UnitIsUnit = function(a, b)
          return a == b
        end,
        GetSpecialization = function()
          return nil -- Simulate no spec role available
        end,
        GetSpecializationRole = function()
          return nil
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units

        -- Case 1: Unit exists
        local roleExisting = Units.GetUnitRole("player")
        Assert.Equal(roleExisting, "NONE", "fallback for player without spec role should be NONE")

        -- Case 2: Unit does not exist (simulating race condition)
        -- If UnitGroupRolesAssigned was called, it might return something or crash,
        -- but our mock ensures we rely on UnitExists check first.
        local roleNonExisting = Units.GetUnitRole("party1")
        Assert.Equal(roleNonExisting, "NONE", "non-existing unit should return NONE safely")
      end)
    end)

    test.it("Units GetUnitNameAndRealm returns nil for non-existing unit", function()
      local unitNameCalled = false
      WithGlobals({
        UnitExists = function(u)
          return u == "player"
        end,
        UnitFullName = function(_u)
          return "TestName", "TestRealm"
        end,
        UnitName = function(_u)
          unitNameCalled = true
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