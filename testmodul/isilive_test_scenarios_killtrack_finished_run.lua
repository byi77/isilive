---@diagnostic disable: undefined-global, undefined-field
-- The finished key keeps its dungeon and the level it ran at on the
-- killtracker bar (killtracker target rule, rule 231). Since 0.9.504 the bar
-- no longer reads its target while forces data is active, so the running key
-- has to be recorded by the KillTrack update path, not by a render. The flow
-- boots the real factory through the stress fixture, starts the key with
-- CHALLENGE_MODE_START and ends it with CHALLENGE_MODE_COMPLETED through the
-- real gated dispatcher; the main window stays closed during the whole key.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

-- A dungeon of the active season, so the bar resolves a localized name.
local MAP_ID = 250
local INSTANCE_ID = 1877
local KEY_LEVEL = 12

local function Prepare(globals, session)
  session.inInstance = true
  globals.C_ChallengeMode.GetActiveChallengeMapID = function()
    return session.active and MAP_ID or nil
  end
  globals.C_ChallengeMode.GetMapUIInfo = function()
    return "Test dungeon", MAP_ID, 1800, nil, nil, INSTANCE_ID
  end
  globals.C_ChallengeMode.GetChallengeCompletionInfo = function()
    return { mapChallengeModeID = MAP_ID, level = KEY_LEVEL, time = 1700000, onTime = true }
  end
  globals.GetInstanceInfo = function()
    if not session.inInstance then
      return "Dornogal", "none", 0, "", 5, false, false, 2552
    end
    return "Test dungeon", "party", 8, "Mythic Keystone", 5, false, false, INSTANCE_ID
  end
end

-- Texts of every FontString the addon created; the dungeon name appears in
-- the window only on the killtracker bar (portal tiles and roster keys show
-- short codes).
local function ShownTexts(session)
  local texts = {}
  for _, frame in ipairs(session.frames) do
    for _, fontString in ipairs(frame._fontStrings or {}) do
      local text = type(fontString.GetText) == "function" and fontString:GetText() or nil
      if type(text) == "string" and text ~= "" then
        texts[text] = true
      end
    end
  end
  return texts
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Killtracker keeps the finished key's dungeon and level although the bar skipped it during the key", function()
    Stress.WithKey(ctx, Fixture, function(session)
      local runtime = session.runtime
      local name = session.addon.Teleport.GetDungeonName(MAP_ID)
      Assert.NotNil(name, "the test dungeon belongs to the active season")
      -- Forces progress while the key runs; the bar never asks for its target.
      session.forces = 40
      session.Dispatch("SCENARIO_CRITERIA_UPDATE")
      session.Advance(3)
      session.runtime.rosterPanelController.RefreshKillTrackRow()
      Assert.Nil(ShownTexts(session)[name], "the running key leaves the bar to forces and the time pace badge")

      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      session.Advance(2)

      local info = runtime.GetKillTrackTargetDungeonInfo()
      Assert.Equal(info and info.name, name, "the finished key keeps its dungeon")
      Assert.Equal(info and info.level, KEY_LEVEL, "the finished key keeps the level it ran at")
      Assert.True(info and info.finished == true, "the finished key is marked as finished")

      runtime.rosterPanelController.RefreshKillTrackRow()
      local texts = ShownTexts(session)
      Assert.True(texts[name] == true, "the bar shows the finished key's dungeon")
      Assert.True(texts["+" .. KEY_LEVEL] == true, "the bar shows the finished key's level")

      session.inInstance = false
      session.Dispatch("ZONE_CHANGED_NEW_AREA")
      Assert.Nil(runtime.GetKillTrackTargetDungeonInfo(), "leaving the instance drops the finished key")
    end, Prepare)
  end)

  test("Key end banner follows a language switch while it is shown", function()
    Stress.WithKey(ctx, Fixture, function(session)
      local runtime = session.runtime
      runtime.SetLanguage("enUS")
      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      session.Advance(2)
      Assert.True(ShownTexts(session)["Key timed"] == true, "the timed key shows its banner")

      runtime.SetLanguage("deDE")
      local texts = ShownTexts(session)
      Assert.True(texts["Key in der Zeit"] == true, "the shown banner relabels at once")
      Assert.Nil(texts["Key timed"], "no English banner text is left")
    end, Prepare)
  end)
end
