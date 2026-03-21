return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test.describe("Roster Display Data Builder", function()
    local mockInfo
    local mockOpts

    test.before_each(function()
      mockInfo = {
        name = "TestPlayer",
        class = "WARRIOR",
        rio = 1000,
      }
      mockOpts = {
        truncateName = function(name, maxChars)
          if string.len(name) > maxChars then
            return string.sub(name, 1, maxChars)
          end
          return name
        end,
        getShortSpecLabel = function(spec)
          return spec
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "XYZ"
        end,
        syncMarker = "",
      }
    end)

    local function runTest(testFn)
      WithGlobals({
        RAID_CLASS_COLORS = { WARRIOR = { r = 1, g = 1, b = 1 } },
        CreateColor = function()
          return {
            GenerateHexColor = function()
              return "ffffffff"
            end,
          }
        end,
      }, function()
        local Roster = LoadAddonModules({ "isiLive_roster.lua" }).Roster
        testFn(Roster)
      end)
    end

    test.it("Roster display prepends positive RIO delta in parentheses", function()
      runTest(function(Roster)
        mockOpts.getRioDelta = function(_info, _unit)
          return 15
        end
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("(+15)1000", result.rioText)
      end)
    end)

    test.it("Roster display clamps negative RIO delta to +0", function()
      runTest(function(Roster)
        mockOpts.getRioDelta = function(_info, _unit)
          return -25
        end
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("(+0)1000", result.rioText)
      end)
    end)

    test.it("Roster display keeps plain RIO text when no baseline delta exists", function()
      runTest(function(Roster)
        mockOpts.getRioDelta = function(_info, _unit)
          return nil
        end
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("1000", result.rioText)
      end)
    end)

    test.it("Roster display shows '-' for rio when rio is nil", function()
      runTest(function(Roster)
        mockInfo.rio = nil
        mockOpts.getRioDelta = function(_info, _unit)
          return 10
        end
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("-", result.rioText, "Delta should not be shown if base rio is missing")
      end)
    end)

    test.it("Roster display truncates names longer than 12 characters", function()
      runTest(function(Roster)
        mockInfo.name = "ThisIsAVeryLongName"
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("ThisIsAVeryL", result.displayName)
      end)
    end)

    test.it("Roster display keeps names with 12 or fewer characters intact", function()
      runTest(function(Roster)
        mockInfo.name = "TwelveChars!"
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("TwelveChars!", result.displayName)
      end)
    end)

    test.it("Roster display truncates spec labels longer than 5 characters", function()
      runTest(function(Roster)
        mockInfo.spec = "AVeryLongSpecName"
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("AVery", result.specText)
      end)
    end)

    test.it("Roster display keeps spec labels with 5 or fewer characters intact", function()
      runTest(function(Roster)
        mockInfo.spec = "Short"
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("Short", result.specText)
      end)
    end)

    test.it("Roster display formats valid key short code and level", function()
      runTest(function(Roster)
        mockInfo.keyMapID = 2662
        mockInfo.keyLevel = 15
        mockOpts.getDungeonShortCode = function(mapID)
          if mapID == 2662 then
            return "DB"
          end
          return "?"
        end
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("DB +15", result.keyText)
      end)
    end)

    test.it("Roster display falls back to '?' for nil key short codes", function()
      runTest(function(Roster)
        mockInfo.keyMapID = 888
        mockInfo.keyLevel = 20
        mockOpts.getDungeonShortCode = function(_mapID)
          return nil
        end
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("? +20", result.keyText)
      end)
    end)

    test.it("Roster display clamps key short code to four letters", function()
      runTest(function(Roster)
        mockInfo.keyMapID = 1234
        mockInfo.keyLevel = 14
        mockOpts.getDungeonShortCode = function()
          return "LONGER"
        end
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("LONG +14", result.keyText)
      end)
    end)

    test.it("Roster display falls back to '?' for numeric-only key short codes", function()
      runTest(function(Roster)
        mockInfo.keyMapID = 999
        mockInfo.keyLevel = 18
        mockOpts.getDungeonShortCode = function(mapID)
          if mapID == 999 then
            return "999" -- Simulate a numeric fallback from an unresolved map
          end
          return "?"
        end
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("? +18", result.keyText)
      end)
    end)

    test.it("Roster display forwards unit to delta callback and renders live-updated rio", function()
      runTest(function(Roster)
        mockOpts.unit = "party1"
        mockOpts.getRioDelta = function(receivedInfo, receivedUnit)
          Assert.Equal(receivedUnit, "party1", "delta callback must receive roster unit token")
          receivedInfo.rio = 3500
          return 15
        end
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)
        Assert.Equal("(+15)3500", result.rioText)
      end)
    end)

    test.it("Roster display treats missing units as online without calling UnitIsConnected", function()
      WithGlobals({
        RAID_CLASS_COLORS = { WARRIOR = { r = 1, g = 1, b = 1 } },
        CreateColor = function()
          return {
            GenerateHexColor = function()
              return "ffffffff"
            end,
          }
        end,
        UnitExists = function(unit)
          return unit == "player"
        end,
        UnitIsConnected = function(_unit)
          error("UnitIsConnected must not be called for missing units")
        end,
      }, function()
        local Roster = LoadAddonModules({ "isiLive_roster.lua" }).Roster
        mockOpts.unit = "party1"
        local result = Roster.BuildDisplayData(mockInfo, mockOpts)

        Assert.Equal(result.colorHex, "ffffffff", "missing unit tokens should not be treated as offline")
      end)
    end)
  end)
end
