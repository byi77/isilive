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

    test.it("Units GetShortSpecLabel prefers readable five-character labels", function()
      WithGlobals({}, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units

        local cases = {
          { input = "Wiederherstellung", expected = "Resto" },
          { input = "Vergeltung", expected = "Retri" },
          { input = "Schutz", expected = "Prote" },
          { input = "Schatten", expected = "Shado" },
          { input = "Gleichgewicht", expected = "Boomy" },
          { input = "Wachter", expected = "Guard" },
          { input = "Verwustung", expected = "Havoc" },
          { input = "Rachsucht", expected = "Venge" },
          { input = "Brewmaster", expected = "Brewm" },
          { input = "Verstarkung", expected = "Enhan" },
          { input = "Elemental", expected = "Eleme" },
          { input = "Treffsicherheit", expected = "MM" },
          { input = "Tierherrschaft", expected = "BM" },
          { input = "Uberleben", expected = "Survi" },
          { input = "Gebrechen", expected = "Affli" },
          { input = "Demonologie", expected = "Demon" },
          { input = "Zerstorung", expected = "Destr" },
          { input = "Meucheln", expected = "Assas" },
          { input = "Gesetzlosigkeit", expected = "Outla" },
          { input = "Tauschung", expected = "Subtl" },
          { input = "Arkan", expected = "Arcan" },
          { input = "Bewahrung", expected = "Prese" },
          { input = "Verwustung-Evoker", expected = "Devas" },
        }

        for _, case in ipairs(cases) do
          Assert.Equal(
            case.expected,
            Units.GetShortSpecLabel(case.input),
            case.input .. " should map to " .. case.expected
          )
        end
      end)
    end)

    test.it("Units TruncateName keeps Cyrillic characters intact", function()
      WithGlobals({}, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units

        local input = string.rep("А", 13)
        local expected = string.rep("А", 12)

        Assert.Equal(expected, Units.TruncateName(input, 12), "UTF-8 truncation must not split Cyrillic characters")
      end)
    end)

    test.it("Units TruncateName handles ASCII fast-path when utf8len/utf8sub globals exist", function()
      WithGlobals({
        utf8len = function(s)
          return #tostring(s)
        end,
        utf8sub = function(s, a, b)
          return string.sub(tostring(s), a, b)
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units

        Assert.Equal(Units.TruncateName("Alice", 3), "Ali", "utf8 globals route truncates via string.sub")
        Assert.Equal(Units.TruncateName("Bob", 10), "Bob", "short names pass through unchanged when utf8 globals exist")
      end)
    end)

    test.it("Units TruncateName returns empty string for nil name", function()
      WithGlobals({}, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units
        Assert.Equal(Units.TruncateName(nil, 10), "", "nil input must resolve to empty string")
        Assert.Equal(Units.TruncateName(nil), "", "missing maxChars must not crash on nil input")
      end)
    end)

    test.it("Units TruncateName handles 3-byte and 4-byte UTF-8 sequences in the manual path", function()
      WithGlobals({}, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units

        -- 3-byte CJK (U+4E2D = \xE4\xB8\xAD)
        local cjk = string.rep("中", 13)
        Assert.Equal(#Units.TruncateName(cjk, 12), 12 * 3, "CJK chars must yield 12*3 bytes after truncation")

        -- 4-byte emoji (U+1F600). Use string.char to stay Lua 5.1-compatible
        -- (\xHH escapes are Lua 5.2+).
        local emoji = string.rep(string.char(0xF0, 0x9F, 0x98, 0x80), 5)
        Assert.Equal(#Units.TruncateName(emoji, 4), 4 * 4, "emoji (4-byte UTF-8) must yield 4*4 bytes after truncation")
      end)
    end)

    test.it("Units GetUnitRole falls back to player spec role when group role is NONE", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        UnitGroupRolesAssigned = function()
          return "NONE"
        end,
        UnitIsUnit = function(a, b)
          return a == "player" and b == "player"
        end,
        GetSpecialization = function()
          return 1
        end,
        GetSpecializationRole = function(idx)
          if idx == 1 then
            return "TANK"
          end
          return nil
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units
        Assert.Equal(Units.GetUnitRole("player"), "TANK", "spec-role fallback must kick in when group role is unset")
      end)
    end)

    test.it("Units GetUnitRole prefers spec role for player over group role assignment", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        UnitGroupRolesAssigned = function()
          return "DAMAGER"
        end,
        UnitIsUnit = function(a, b)
          return a == "player" and b == "player"
        end,
        GetSpecialization = function()
          return 1
        end,
        GetSpecializationRole = function()
          return "TANK"
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units
        Assert.Equal(
          Units.GetUnitRole("player"),
          "TANK",
          "spec-role must override group-role for player so spec switches drive the icon"
        )
      end)
    end)

    test.it("Units GetUnitRole keeps group role for non-player units", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        UnitGroupRolesAssigned = function()
          return "HEALER"
        end,
        UnitIsUnit = function()
          return false
        end,
        GetSpecialization = function()
          return 1
        end,
        GetSpecializationRole = function()
          return "TANK"
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units
        Assert.Equal(
          Units.GetUnitRole("party1"),
          "HEALER",
          "non-player units must keep UnitGroupRolesAssigned without spec override"
        )
      end)
    end)

    test.it("Units GetUnitRole returns NONE when spec fallback also fails", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        UnitGroupRolesAssigned = function()
          return "NONE"
        end,
        UnitIsUnit = function(a, b)
          return a == "player" and b == "player"
        end,
        GetSpecialization = function()
          return nil
        end,
        GetSpecializationRole = function()
          return nil
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units
        Assert.Equal(Units.GetUnitRole("player"), "NONE")
      end)
    end)

    test.it("Units GetUnitClass returns nil/nil when UnitClass global is absent", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        UnitClass = false,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units
        local a, b = Units.GetUnitClass("player")
        Assert.Nil(a)
        Assert.Nil(b)
      end)
    end)

    test.it("Units GetUnitClass returns nil/nil when UnitClass raises", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        UnitClass = function()
          error("api missing", 0)
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units
        local a, b = Units.GetUnitClass("player")
        Assert.Nil(a)
        Assert.Nil(b)
      end)
    end)

    test.it("Units GetUnitNameAndRealm falls back to UnitName + GetRealmName when UnitFullName returns nil", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        UnitFullName = function()
          return nil, nil
        end,
        UnitName = function(u)
          if u == "player" then
            return "Tester"
          end
        end,
        GetRealmName = function()
          return "Fallback-Realm"
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units
        local name, realm = Units.GetUnitNameAndRealm("player")
        Assert.Equal(name, "Tester")
        Assert.Equal(realm, "Fallback-Realm")
      end)
    end)

    test.it("Units GetUnitNameAndRealm returns nil/nil for missing unit", function()
      WithGlobals({
        UnitExists = function()
          return false
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units
        local name, realm = Units.GetUnitNameAndRealm("party9")
        Assert.Nil(name)
        Assert.Nil(realm)
      end)
    end)

    test.it("Units GetPlayerSpecName returns nil when API is missing", function()
      WithGlobals({
        GetSpecialization = false,
        GetSpecializationInfo = false,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Nil(addon.Units.GetPlayerSpecName())
      end)
    end)

    test.it("Units GetPlayerSpecName returns nil when GetSpecialization yields zero", function()
      WithGlobals({
        GetSpecialization = function()
          return 0
        end,
        GetSpecializationInfo = function()
          error("must not be called", 0)
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Nil(addon.Units.GetPlayerSpecName())
      end)
    end)

    test.it("Units GetPlayerSpecName returns the spec name from GetSpecializationInfo", function()
      WithGlobals({
        GetSpecialization = function()
          return 2
        end,
        GetSpecializationInfo = function(idx)
          if idx == 2 then
            return 63, "Fire"
          end
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Equal(addon.Units.GetPlayerSpecName(), "Fire")
      end)
    end)

    test.it("Units GetInspectSpecName returns nil when GetInspectSpecialization raises", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        GetInspectSpecialization = function()
          error("inspect api raises", 0)
        end,
        GetSpecializationInfoByID = function()
          error("must not be called", 0)
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Nil(addon.Units.GetInspectSpecName("party1"))
      end)
    end)

    test.it("Units GetInspectSpecName returns nil when GetSpecializationInfoByID raises", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        GetInspectSpecialization = function()
          return 63
        end,
        GetSpecializationInfoByID = function()
          error("info api raises", 0)
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Nil(addon.Units.GetInspectSpecName("party1"))
      end)
    end)

    test.it("Units GetInspectSpecRole resolves role from inspected specialization id", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        GetInspectSpecialization = function(unit)
          if unit == "party1" then
            return 250
          end
          return nil
        end,
        GetSpecializationRoleByID = function(specID)
          if specID == 250 then
            return "TANK"
          end
          return nil
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Equal(
          addon.Units.GetInspectSpecRole("party1"),
          "TANK",
          "inspect role must come from the verified inspected specialization id"
        )
      end)
    end)

    test.it("Units GetShortSpecLabel normalizes umlauts and maps to short German labels", function()
      WithGlobals({}, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        local Units = addon.Units
        Assert.Equal(Units.GetShortSpecLabel("Gleichgewicht"), "Boomy", "lowercased + normalized DE spec must map")
        Assert.Equal(
          Units.GetShortSpecLabel("Zerstörung"),
          "Destr",
          "umlaut normalization must hit the 'zerstorung' key"
        )
        Assert.Equal(Units.GetShortSpecLabel("Treffsicherheit"), "MM")
        Assert.Equal(
          Units.GetShortSpecLabel("  Holy  "),
          "Holy",
          "leading/trailing whitespace must be stripped before mapping"
        )
        Assert.Equal(Units.GetShortSpecLabel("Unknown Spec"), "Unknown Spec", "unmapped spec passes through verbatim")
        Assert.Equal(Units.GetShortSpecLabel(""), "", "empty string passes through")
        Assert.Equal(Units.GetShortSpecLabel(nil), nil, "nil passes through")
      end)
    end)

    test.it("Units GetUnitRio returns nil when C_PlayerInfo API is missing", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        C_PlayerInfo = false,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Nil(addon.Units.GetUnitRio("player"))
      end)
    end)

    test.it("Units GetUnitRio returns currentSeasonScore when summary provides it", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        C_PlayerInfo = {
          GetPlayerMythicPlusRatingSummary = function()
            return { currentSeasonScore = 3400 }
          end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Equal(addon.Units.GetUnitRio("player"), 3400)
      end)
    end)

    test.it("Units GetUnitRio falls back through currentSeasonBestScore / rating / score in order", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        C_PlayerInfo = {
          GetPlayerMythicPlusRatingSummary = function()
            return { currentSeasonBestScore = 3100, rating = 3000, score = 2900 }
          end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Equal(addon.Units.GetUnitRio("player"), 3100)
      end)

      WithGlobals({
        UnitExists = function()
          return true
        end,
        C_PlayerInfo = {
          GetPlayerMythicPlusRatingSummary = function()
            return { rating = 2800 }
          end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Equal(addon.Units.GetUnitRio("player"), 2800)
      end)

      WithGlobals({
        UnitExists = function()
          return true
        end,
        C_PlayerInfo = {
          GetPlayerMythicPlusRatingSummary = function()
            return { score = 2500 }
          end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Equal(addon.Units.GetUnitRio("player"), 2500)
      end)
    end)

    test.it("Units GetUnitRio returns nil when pcall fails", function()
      WithGlobals({
        UnitExists = function()
          return true
        end,
        C_PlayerInfo = {
          GetPlayerMythicPlusRatingSummary = function()
            error("rating api missing", 0)
          end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Nil(addon.Units.GetUnitRio("player"))
      end)
    end)

    test.it("Units GetUnitRio returns nil for missing unit", function()
      WithGlobals({
        UnitExists = function()
          return false
        end,
      }, function()
        local addon = LoadAddonModules({ "isiLive_units.lua" })
        Assert.Nil(addon.Units.GetUnitRio("party9"))
      end)
    end)
  end)
end
