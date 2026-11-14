---@diagnostic disable: undefined-global

-- Rule 252: dungeon-category LFG listings (M0, heroic, normal) resolve their
-- target through the instance against the active season. End-to-end through
-- the real LFGDetect, LFGEntryResolver, SeasonData and Validators.

local envChunk, envErr = loadfile("testmodul/isilive_test_lfg_detect_env.lua")
if not envChunk then
  error("cannot load LFG detect env: " .. tostring(envErr))
end
local BuildLFGDetectEnv = envChunk()

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  test("LFGDetect resolves an M0 or heroic dungeon listing of the active season", function()
    -- Den of Nalorakk (586) is a midnight_s2 dungeon; its instance is 2825
    -- in this stub. A follower or old dungeon (instance 1234) is no season map.
    local activities = {
      [7701] = { mapID = 2825, isMythicPlusActivity = false, categoryID = 2 },
      [7702] = { mapID = 1234, isMythicPlusActivity = false, categoryID = 2 },
      [7703] = { mapID = 2825, isMythicPlusActivity = false, categoryID = 1 },
    }
    local listings = {
      [61] = { activityID = 7701, name = "M0 Den weekly", leaderName = "Lead" },
      [62] = { activityID = 7702, name = "Normal follower", leaderName = "Lead" },
      [63] = { activityID = 7703, name = "Questing", leaderName = "Lead" },
    }
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_ChallengeMode = {
          GetMapUIInfo = function(mapID)
            local instanceID = mapID == 586 and 2825 or (5000 + mapID)
            return "Dungeon", mapID, 1800, nil, nil, instanceID
          end,
        },
        C_LFGList = {
          GetSearchResultInfo = function(id)
            return listings[id]
          end,
          GetActiveEntryInfo = function()
            return nil
          end,
          GetActivityFullName = function()
            return nil
          end,
          GetActivityInfoTable = function(activityID)
            return activities[activityID]
          end,
        },
      },
    })
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 61, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 61, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 586, "an M0 listing of a season dungeon resolves its map")

      addon.LFGDetect.ClearAllState()
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 62, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 62, "inviteaccepted")
      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "a dungeon outside the active season stays unresolved")

      addon.LFGDetect.ClearAllState()
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 63, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 63, "inviteaccepted")
      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "a non-dungeon category never resolves a dungeon")
    end)
  end)
end
