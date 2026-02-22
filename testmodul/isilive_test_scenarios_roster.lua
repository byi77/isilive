return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function CreateColorStub(_r, _g, _b)
    return {
      GenerateHexColor = function()
        return "ffffffff"
      end,
    }
  end

  test("Roster display prepends positive RIO delta in parentheses", function()
    WithGlobals({
      RAID_CLASS_COLORS = {
        MAGE = { r = 0.25, g = 0.78, b = 0.92 },
      },
      CreateColor = CreateColorStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster.lua" })
      local result = addon.Roster.BuildDisplayData({
        class = "MAGE",
        name = "Tester",
        language = "DE",
        rio = 3123.9,
      }, {
        getRioDelta = function(_info)
          return 12
        end,
      })

      Assert.Equal(result.rioText, "(+12)3123", "positive RIO delta must render before rio value")
    end)
  end)

  test("Roster display clamps negative RIO delta to +0", function()
    WithGlobals({
      RAID_CLASS_COLORS = {
        MAGE = { r = 0.25, g = 0.78, b = 0.92 },
      },
      CreateColor = CreateColorStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster.lua" })
      local result = addon.Roster.BuildDisplayData({
        class = "MAGE",
        name = "Tester",
        language = "DE",
        rio = 3123.9,
      }, {
        getRioDelta = function(_info)
          return -18
        end,
      })

      Assert.Equal(result.rioText, "(+0)3123", "negative RIO delta must never render as minus")
    end)
  end)

  test("Roster display keeps plain RIO text when no baseline delta exists", function()
    WithGlobals({
      RAID_CLASS_COLORS = {
        MAGE = { r = 0.25, g = 0.78, b = 0.92 },
      },
      CreateColor = CreateColorStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster.lua" })
      local result = addon.Roster.BuildDisplayData({
        class = "MAGE",
        name = "Tester",
        language = "DE",
        rio = 3123.9,
      }, {
        getRioDelta = function(_info)
          return nil
        end,
      })

      Assert.Equal(result.rioText, "3123", "missing baseline delta must keep plain RIO text")
    end)
  end)

  test("Roster display forwards unit to delta callback and renders live-updated rio", function()
    WithGlobals({
      RAID_CLASS_COLORS = {
        MAGE = { r = 0.25, g = 0.78, b = 0.92 },
      },
      CreateColor = CreateColorStub,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster.lua" })
      local info = {
        class = "MAGE",
        name = "Tester",
        language = "DE",
      }
      local result = addon.Roster.BuildDisplayData(info, {
        unit = "party1",
        getRioDelta = function(receivedInfo, receivedUnit)
          Assert.Equal(receivedUnit, "party1", "delta callback must receive roster unit token")
          receivedInfo.rio = 3500
          return 15
        end,
      })

      Assert.Equal(result.rioText, "(+15)3500", "delta callback should allow live rio rendering")
    end)
  end)
end
