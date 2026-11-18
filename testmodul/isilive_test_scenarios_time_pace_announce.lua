---@diagnostic disable: undefined-global, undefined-field
-- Pace announce (rule 255, game/isiLive_time_pace_announce.lua and the time
-- pace badge in ui/isiLive_roster_panel_kill_row_time_pace.lua). The click
-- flows boot the real factory through the stress fixture, start the key with
-- CHALLENGE_MODE_START, let the real TimePace answer and click the real
-- badge; SendChatMessage is the client mock that records the post.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

-- A dungeon of the active season, so the line carries its short code.
local MAP_ID = 250
local KEY_LEVEL = 12

local function Prepare(globals, session)
  session.grouped = true
  globals.C_ChallengeMode.GetActiveChallengeMapID = function()
    return session.active and MAP_ID or nil
  end
  globals.C_ChallengeMode.GetMapUIInfo = function()
    return "Test dungeon", MAP_ID, 1800
  end
  session.chat = {}
  session.printed = {}
  globals.SendChatMessage = function(message, channel)
    session.chat[#session.chat + 1] = { message = message, channel = channel }
  end
  local basePrint = globals.print
  globals.print = function(message)
    session.printed[#session.printed + 1] = tostring(message)
    return basePrint(message)
  end
  -- Forces plus two bosses: TimePace needs the boss list for its progress.
  local scenario = globals.C_ScenarioInfo
  local forcesInfo = scenario.GetCriteriaInfo
  local stepInfo = scenario.GetScenarioStepInfo
  scenario.GetScenarioStepInfo = function()
    local info = stepInfo()
    info.numCriteria = 3
    return info
  end
  scenario.GetCriteriaInfo = function(index)
    if index == 1 then
      return forcesInfo(index)
    end
    return { criteriaID = 9000 + index, isWeightedProgress = false, completed = false }
  end
end

local function FindBadgeRow(session)
  for _, frame in ipairs(session.frames) do
    if type(frame) == "table" and frame.killTrackTimePaceBadge then
      return frame
    end
  end
  return nil
end

-- Enough forces and time for the TimePace projection (>= 5 % progress and
-- 60 s on the timer), then a killtracker refresh shows the badge.
local function ShowBadge(ctx, session)
  session.forces = 40
  session.Dispatch("SCENARIO_CRITERIA_UPDATE")
  session.Advance(90)
  session.runtime.rosterPanelController.RefreshKillTrackRow()
  local row = ctx.assert.NotNil(FindBadgeRow(session), "the killtracker row carries the time pace badge")
  ctx.assert.True(row.killTrackTimePaceBadge._shown ~= false, "the badge is shown with a pace answer")
  ctx.assert.NotNil(row.killTrackTimePaceStatus, "the badge keeps the status it shows")
  return row
end

local function Click(row)
  local badge = row.killTrackTimePaceBadge
  local onMouseUp = badge:GetScript("OnMouseUp")
  onMouseUp(badge, "LeftButton")
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  test("TimePaceAnnounce builds the short English expectation line", function()
    local addon = LoadAddonModules({ "isiLive_time_pace.lua", "isiLive_time_pace_announce.lua" })
    local build = addon.TimePaceAnnounce.BuildLine
    Assert.Equal(
      build({ mode = "reference", delta = -72, verdict = "ontime" }, "KR", 15),
      "KR +15 expected: INTIME - 1:12 spare. Go for it! (via isiLive M+Addon)",
      "on time names the spare time"
    )
    Assert.Equal(
      build({ mode = "projection", projected = 2050, timeLimit = 1900, verdict = "late" }, "KR", 15),
      "KR +15 expected: OUT-OF-TIME - 2:30 over. Sorry boys and girls. (via isiLive M+Addon)",
      "late names the time over the timer"
    )
    Assert.Equal(
      build({ mode = "reference", delta = -12, verdict = "tight" }, "KR", 15),
      "KR +15 expected: INTIME (close) - 0:12 spare. Push it! (via isiLive M+Addon)",
      "a close call on the good side stays INTIME with (close)"
    )
    Assert.Equal(
      build({ mode = "reference", delta = 20, verdict = "tight" }, "KR", 15),
      "KR +15 expected: OUT-OF-TIME (close) - 0:20 over. Every second counts! (via isiLive M+Addon)",
      "a close call on the bad side is OUT-OF-TIME with (close)"
    )
    Assert.Equal(
      build({ mode = "reference", delta = -200 }, nil, nil),
      "Key expected: INTIME - 3:20 spare. Go for it! (via isiLive M+Addon)",
      "without verdict the delta is classified; without dungeon the key is generic"
    )
    Assert.Nil(build(nil, "KR", 15), "no status, no line")
    Assert.Nil(build({ mode = "projection", projected = 0 / 0, timeLimit = 1800 }, "KR", 15), "NaN, no line")
  end)

  test("TimePace badge click posts the expectation to the group chat, also in combat", function()
    Stress.WithKey(ctx, Fixture, function(session)
      local addon = session.addon
      local row = ShowBadge(ctx, session)
      local expected = addon.TimePaceAnnounce.BuildLine(
        row.killTrackTimePaceStatus,
        addon.Teleport.GetDungeonShortCode(MAP_ID, "enUS"),
        KEY_LEVEL
      )
      Assert.NotNil(expected, "the shown status builds a line")
      Assert.NotNil(addon.Teleport.GetDungeonShortCode(MAP_ID, "enUS"), "the test dungeon has an English short code")
      Assert.True(expected:find("+" .. KEY_LEVEL .. " expected: ", 1, true) ~= nil, "the line names the key level")
      Assert.True(expected:find("(via isiLive M+Addon)", 1, true) ~= nil, "the line names isiLive")

      session.runtime.SetLanguage("deDE")
      session.combat = true
      Click(row)
      Assert.Equal(#session.chat, 1, "one click posts one line, in combat too")
      Assert.Equal(session.chat[1].channel, "PARTY", "the post goes to the group chat")
      Assert.Equal(session.chat[1].message, expected, "the post is English in every UI language")

      Click(row)
      Assert.Equal(#session.chat, 1, "a second click inside the cooldown posts nothing")
      session.Advance(addon.TimePaceAnnounce.COOLDOWN_SECONDS + 1)
      Click(row)
      Assert.Equal(#session.chat, 2, "after the cooldown the click posts again")
      Assert.Equal(session.chat[2].channel, "PARTY", "again only to the group chat")
    end, Prepare)
  end)

  test("TimePace badge click outside a group posts nothing and says why", function()
    Stress.WithKey(ctx, Fixture, function(session)
      local row = ShowBadge(ctx, session)
      session.addon.TimePaceAnnounce.ResetCooldown()
      session.grouped = false
      session.printed = {}
      Click(row)
      Assert.Equal(#session.chat, 0, "outside a group nothing is posted")
      local hinted = false
      for _, line in ipairs(session.printed) do
        if line:find("not in a group", 1, true) then
          hinted = true
        end
      end
      Assert.True(hinted, "the player reads locally why nothing was posted")
    end, Prepare)
  end)
end
