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

  -- The slash command reaches the real ApiHealth and ErrorLog through the
  -- factory and Bootstrap.RegisterSlashCommands. Its hand-kept option list
  -- used to drop printSelfTest and the error log accessors, so both commands
  -- answered with nothing or an empty log in the client.
  test("Slash commands selftest and errorlog reach the real modules after login", function()
    Stress.WithParty(ctx, Fixture, function(session)
      local slash = session.globals.SlashCmdList.ISILIVE
      Assert.Equal(type(slash), "function", "the /isilive handler is registered")
      local before = #session.chat
      slash("selftest")
      local report = table.concat(session.chat, "\n", before + 1)
      Assert.True(report:find("[SELFTEST]", 1, true) ~= nil, "/isilive selftest prints the report")
      Assert.True(report:find("of %d+ Blizzard APIs") ~= nil, "the report ends the API block with its summary")
      Assert.True(report:find("data IDs", 1, true) ~= nil, "the report includes the data checks")

      before = #session.chat
      slash("selftest all")
      Assert.True(#session.chat - before > 10, "/isilive selftest all lists every check")

      before = #session.chat
      slash("errorlog status")
      local status = table.concat(session.chat, "\n", before + 1)
      Assert.True(status:find("Error log:", 1, true) ~= nil, "/isilive errorlog status answers")
      Assert.Nil(
        status:find("/ 0", 1, true),
        "the status reads the real error log cap, not the empty fallback: " .. status
      )
    end, Prepare(BUILD))
  end)

  test("Patch watch stays silent after login when the build was already checked", function()
    Stress.WithParty(ctx, Fixture, function(session)
      session.Advance(session.addon.ApiHealth.PATCH_WATCH_DELAY_SECONDS + 5)
      Assert.Equal(#NoticeLines(session), 0, "an unchanged build runs no check and prints nothing")
    end, Prepare(BUILD))
  end)
end
