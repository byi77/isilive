---@diagnostic disable: undefined-global

-- Season item level colours: game/isiLive_ilvl_bands.lua derives the bands
-- from C_MythicPlus.GetRewardLevelFromKeystoneLevel, ui/isiLive_roster.lua
-- paints the roster column with them. Every scenario goes through the real
-- Roster.BuildDisplayData on top of the real ItemLevelBands; only the Blizzard
-- APIs are mocked.

local SECRET = setmetatable({}, {
  __tostring = function()
    return "<secret>"
  end,
})

-- Channels chosen as exact multiples of 1/255 so the expected hex is exact.
local QUALITY_COLORS = {
  [4] = { 163 / 255, 53 / 255, 238 / 255 },
  [3] = { 0, 112 / 255, 221 / 255 },
  [2] = { 30 / 255, 1, 0 },
  [0] = { 157 / 255, 157 / 255, 157 / 255 },
}
local EPIC, RARE, UNCOMMON, POOR = "ffa335ee", "ff0070dd", "ff1eff00", "ff9d9d9d"

local function BuildEnv(rewards)
  local env = { now = 100, rewardCalls = 0, requestCalls = 0, rewards = rewards }
  env.globals = {
    issecretvalue = function(value)
      return value == SECRET
    end,
    GetTime = function()
      return env.now
    end,
    C_MythicPlus = {
      GetRewardLevelFromKeystoneLevel = function(keyLevel)
        env.rewardCalls = env.rewardCalls + 1
        return env.rewards[keyLevel]
      end,
      RequestMapInfo = function()
        env.requestCalls = env.requestCalls + 1
      end,
    },
    C_Item = {
      GetItemQualityColor = function(quality)
        local color = QUALITY_COLORS[quality]
        return color[1], color[2], color[3], "ff000000"
      end,
    },
    RAID_CLASS_COLORS = { WARRIOR = { r = 1, g = 1, b = 1 } },
    CreateColor = function()
      return {
        GenerateHexColor = function()
          return "ffffffff"
        end,
      }
    end,
  }
  return env
end

local function Colored(hex, text)
  return "|c" .. hex .. text .. "|r"
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function WithRoster(env, fn)
    WithGlobals(env.globals, function()
      local addon = LoadAddonModules({ "isiLive_ilvl_bands.lua", "isiLive_roster.lua" })
      fn(addon.Roster, addon.ItemLevelBands)
    end)
  end

  local function IlvlText(Roster, ilvl)
    return Roster.BuildDisplayData({ name = "Felix", class = "WARRIOR", ilvl = ilvl }, {}).ilvlText
  end

  test.describe("Roster item level season colours", function()
    test.it("maps item levels onto the reward-curve bands", function()
      local env = BuildEnv({ [10] = 318, [6] = 311, [2] = 305 })
      WithRoster(env, function(Roster)
        Assert.Equal(IlvlText(Roster, 324), Colored(EPIC, "324"), "above the +10 reward is epic")
        Assert.Equal(IlvlText(Roster, 318), Colored(EPIC, "318"), "the +10 reward itself is epic")
        Assert.Equal(IlvlText(Roster, 317.9), Colored(RARE, "317"), "just below +10 is rare")
        Assert.Equal(IlvlText(Roster, 311), Colored(RARE, "311"), "the +6 reward is rare")
        Assert.Equal(IlvlText(Roster, 305), Colored(UNCOMMON, "305"), "the +2 reward is uncommon")
        Assert.Equal(IlvlText(Roster, 280), Colored(POOR, "280"), "below the season floor is poor")
        Assert.Equal(IlvlText(Roster, nil), "-", "no item level stays an uncoloured dash")
        Assert.Equal(env.rewardCalls, 3, "a resolved scale is cached for the session")
        Assert.Equal(env.requestCalls, 0, "resolved data must not request map info")
      end)
    end)

    test.it("keeps the item level uncoloured without usable reward data", function()
      local cases = {
        { name = "secret reward level", rewards = { [10] = SECRET, [6] = 311, [2] = 305 } },
        { name = "zero reward level", rewards = { [10] = 0, [6] = 311, [2] = 305 } },
        { name = "missing floor", rewards = { [10] = 318, [6] = 311 } },
        { name = "gap in the curve", rewards = { [10] = 318, [6] = 320, [2] = 305 } },
        { name = "equal anchors", rewards = { [10] = 318, [6] = 318, [2] = 305 } },
      }
      for _, case in ipairs(cases) do
        local env = BuildEnv(case.rewards)
        WithRoster(env, function(Roster)
          Assert.Equal(IlvlText(Roster, 320), "320", case.name .. " must leave the text uncoloured")
        end)
      end

      local noApi = BuildEnv({})
      noApi.globals.C_MythicPlus = nil
      WithRoster(noApi, function(Roster)
        Assert.Equal(IlvlText(Roster, 320), "320", "a missing C_MythicPlus must leave the text uncoloured")
      end)

      local secretColor = BuildEnv({ [10] = 318, [6] = 311, [2] = 305 })
      secretColor.globals.C_Item.GetItemQualityColor = function()
        return SECRET, 0, 0
      end
      WithRoster(secretColor, function(Roster)
        Assert.Equal(IlvlText(Roster, 320), "320", "a secret quality colour must leave the text uncoloured")
      end)
    end)

    test.it("retries throttled and bounded, requesting map info once", function()
      local env = BuildEnv({})
      WithRoster(env, function(Roster)
        Assert.Equal(IlvlText(Roster, 320), "320", "a cold login has no reward data yet")
        Assert.Equal(env.requestCalls, 1, "the first miss asks the server for season data")
        local callsAfterFirst = env.rewardCalls

        env.rewards = { [10] = 318, [6] = 311, [2] = 305 }
        env.now = env.now + 1
        Assert.Equal(IlvlText(Roster, 320), "320", "a retry inside the throttle window is skipped")
        Assert.Equal(env.rewardCalls, callsAfterFirst, "the throttle must not read the API again")

        env.now = env.now + 5
        Assert.Equal(IlvlText(Roster, 320), Colored(EPIC, "320"), "the next due retry picks up the data")
      end)

      local never = BuildEnv({})
      WithRoster(never, function(Roster)
        for _ = 1, 20 do
          IlvlText(Roster, 320)
          never.now = never.now + 10
        end
        local callsAtCap = never.rewardCalls
        IlvlText(Roster, 320)
        Assert.Equal(never.rewardCalls, callsAtCap, "the retry budget is bounded")
        Assert.True(callsAtCap <= 6, "at most six attempts read the first anchor")
        Assert.Equal(never.requestCalls, 1, "map info is requested only once")
      end)
    end)

    test.it("CHALLENGE_MODE_MAPS_UPDATE refresh resolves the scale and reports the change", function()
      local env = BuildEnv({})
      WithRoster(env, function(Roster, ItemLevelBands)
        Assert.Equal(IlvlText(Roster, 320), "320", "no data before the event")
        Assert.False(ItemLevelBands.Refresh(), "still no data: nothing changed, no repaint")

        env.rewards = { [10] = 318, [6] = 311, [2] = 305 }
        Assert.True(ItemLevelBands.Refresh(), "arriving data must report a changed scale")
        Assert.Equal(IlvlText(Roster, 320), Colored(EPIC, "320"), "the refreshed scale colours at once")
        Assert.False(ItemLevelBands.Refresh(), "an identical scale must not trigger a repaint")

        env.rewards = { [10] = 330, [6] = 320, [2] = 310 }
        Assert.True(ItemLevelBands.Refresh(), "a new season curve must report a change")
        Assert.Equal(IlvlText(Roster, 324), Colored(RARE, "324"), "the new curve moves the bands")
        Assert.Equal(env.requestCalls, 1, "a refresh must not re-arm the map info request")
      end)
    end)
  end)
end
