---@diagnostic disable: undefined-global

-- Mythic+ score colours: ui/isiLive_roster.lua paints the roster rio column
-- with C_ChallengeMode.GetDungeonScoreRarityColor. Every scenario goes
-- through the real Roster.BuildDisplayData; only the Blizzard API is mocked.

local SECRET = setmetatable({}, {
  __tostring = function()
    return "<secret>"
  end,
})

-- Channels chosen as exact multiples of 1/255 so the expected hex is exact.
local SCORE_COLOR = { r = 163 / 255, g = 53 / 255, b = 238 / 255 }
local SCORE_HEX = "ffa335ee"

local function BuildGlobals(getColor)
  return {
    issecretvalue = function(value)
      return value == SECRET
    end,
    C_ChallengeMode = { GetDungeonScoreRarityColor = getColor },
  }
end

local function Colored(hex, text)
  return "|c" .. hex .. text .. "|r"
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function WithRoster(globals, fn)
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_roster.lua" })
      fn(addon.Roster)
    end)
  end

  local function RioText(Roster, rio, delta)
    local opts = {}
    if delta then
      opts.getRioDelta = function()
        return delta
      end
    end
    return Roster.BuildDisplayData({ name = "Felix", class = "WARRIOR", rio = rio }, opts).rioText
  end

  test.describe("Roster M+ score colours", function()
    test.it("colours only the score number with Blizzard's score colour", function()
      local seen = {}
      local globals = BuildGlobals(function(score)
        seen[#seen + 1] = score
        return SCORE_COLOR
      end)
      WithRoster(globals, function(Roster)
        Assert.Equal(RioText(Roster, 3012.7), Colored(SCORE_HEX, "3012"), "the score is wrapped in its colour")
        Assert.Equal(seen[1], 3012.7, "Blizzard receives the raw score")
        Assert.Equal(RioText(Roster, 3012, 40), "(+40)" .. Colored(SCORE_HEX, "3012"), "the delta prefix stays plain")
        Assert.Equal(RioText(Roster, nil), "-", "no score stays an uncoloured dash")
        Assert.Equal(RioText(Roster, nil, 40), "-", "no score ignores the delta")
        local callsBefore = #seen
        Assert.Equal(RioText(Roster, 0), "0", "a zero score stays uncoloured")
        Assert.Equal(#seen, callsBefore, "a zero score never asks Blizzard for a colour")
      end)
    end)

    test.it("keeps the score uncoloured when the colour is unusable", function()
      local cases = {
        { name = "missing function", getColor = nil },
        {
          name = "throwing function",
          getColor = function()
            error("boom")
          end,
        },
        { name = "nil result", getColor = function() end },
        {
          name = "secret result",
          getColor = function()
            return SECRET
          end,
        },
        {
          name = "secret channel",
          getColor = function()
            return { r = SECRET, g = 0.5, b = 0.5 }
          end,
        },
        {
          name = "non-numeric channel",
          getColor = function()
            return { r = "1", g = 0.5, b = 0.5 }
          end,
        },
        {
          name = "out-of-range channel",
          getColor = function()
            return { r = 2, g = 0.5, b = 0.5 }
          end,
        },
        {
          name = "non-table result",
          getColor = function()
            return 5
          end,
        },
      }
      for _, case in ipairs(cases) do
        WithRoster(BuildGlobals(case.getColor), function(Roster)
          Assert.Equal(RioText(Roster, 3012), "3012", case.name .. " must leave the text uncoloured")
          Assert.Equal(RioText(Roster, 3012, 40), "(+40)3012", case.name .. " must leave the prefix text plain")
        end)
      end

      local noNamespace = BuildGlobals(nil)
      noNamespace.C_ChallengeMode = nil
      WithRoster(noNamespace, function(Roster)
        Assert.Equal(RioText(Roster, 3012), "3012", "a missing C_ChallengeMode must leave the text uncoloured")
      end)

      WithRoster(
        BuildGlobals(function()
          error("a secret score must never reach Blizzard")
        end),
        function(Roster)
          Assert.Equal(Roster.ColorizeScoreText(SECRET, "x"), "x", "a secret score is returned unchanged")
          Assert.Equal(Roster.ColorizeScoreText("3000", "x"), "x", "a non-number score is returned unchanged")
        end
      )
    end)
  end)
end
