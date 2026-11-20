---@diagnostic disable: undefined-global, undefined-field
-- Patch watch (rule 261, game/isiLive_api_health.lua). The flows boot the
-- real factory through the stress fixture and pump PLAYER_LOGIN through the
-- real gated dispatcher; the chat line is the real ctx.Print output.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local BUILD = "70001"

local function Prepare(storedBuild)
  return function(globals, session)
    session.chat = {}
    globals.GetBuildInfo = function()
      return "12.9.0", BUILD, "Nov 20 2026", 120900
    end
    local basePrint = globals.print
    globals.print = function(message)
      session.chat[#session.chat + 1] = tostring(message)
      return basePrint(message)
    end
    globals.IsiLiveDB.selftestBuild = storedBuild
  end
end

local function NoticeLines(session)
  local out = {}
  for _, line in ipairs(session.chat) do
    if line:find("Self test after the client update", 1, true) then
      out[#out + 1] = line
    end
  end
  return out
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Patch watch runs the self test once after login when the client build changed", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local apiHealth = session.addon.ApiHealth
      local db = session.globals.IsiLiveDB
      Assert.Equal(db.selftestBuild, "69999", "nothing runs inside the login burst")
      session.Advance(apiHealth.PATCH_WATCH_DELAY_SECONDS)
      Assert.Equal(db.selftestBuild, BUILD, "the new build is checked and stored")
      -- The fixture client lacks many Blizzard APIs, so the check finds problems.
      local notices = NoticeLines(session)
      Assert.Equal(#notices, 1, "one chat line reports the problems")
      Assert.True(notices[1]:find("(build " .. BUILD .. ")", 1, true) ~= nil, "the line names the build")
      Assert.True(notices[1]:find("/isilive selftest", 1, true) ~= nil, "the line points to the details")
    end, Prepare("69999"))
  end)

  test("Patch watch stays silent after login when the build was already checked", function()
    Stress.WithParty(ctx, Fixture, function(session)
      session.Advance(session.addon.ApiHealth.PATCH_WATCH_DELAY_SECONDS + 5)
      Assert.Equal(#NoticeLines(session), 0, "an unchanged build runs no check and prints nothing")
    end, Prepare(BUILD))
  end)
end
