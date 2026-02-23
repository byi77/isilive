return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function BuildLocale()
    return {
      DUNGEON_DIFF_OUTSIDE = "Outside",
      DUNGEON_DIFF_UNKNOWN = "Unknown",
      DUNGEON_DIFF_NORMAL = "Normal",
      DUNGEON_DIFF_HEROIC = "Heroic",
      DUNGEON_DIFF_MYTHIC = "Mythic",
      NON_MYTHIC_ENTERED = "Warning: Entered non-Mythic dungeon (%s).",
      STATUS_LEAD_YES = "Lead: Yes",
      STATUS_LEAD_NO = "Lead: No",
      STATUS_MPLUS_YES = "M+: Active",
      STATUS_MPLUS_NO = "M+: Inactive",
      STATUS_TARGET_DUNGEON_TEXT = "Target Dungeon: %s",
      STATUS_TARGET_DUNGEON_NONE = "Target Dungeon: -",
      STATUS_STATE_RUNNING = "State: Running",
      STATUS_STATE_PAUSED = "State: Paused",
      STATUS_STATE_STOPPED = "State: Stopped",
      STATUS_STATE_TEST = "State: Test",
      DUNGEON_DIFF_TEXT = "Dungeon: %s",
    }
  end

  test("Status maps heroic fallback difficulty IDs as non-mythic heroic", function()
    local current = {
      instanceName = "Priory of the Sacred Flame",
      instanceType = "party",
      difficultyID = 174,
    }

    WithGlobals({
      GetInstanceInfo = function()
        return current.instanceName, current.instanceType, current.difficultyID, "Heroic"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })

      local label, isMythic, inDungeon = controller.GetDungeonDifficultyLabel()
      Assert.Equal(label, "Heroic", "difficulty 174 should resolve as heroic")
      Assert.False(isMythic, "heroic fallback difficulty must not be mythic")
      Assert.True(inDungeon, "heroic fallback difficulty must be treated as dungeon context")
    end)
  end)

  test("Status warns when switching from normal to heroic without leaving dungeon context", function()
    local notices = {}
    local current = {
      instanceName = "Priory of the Sacred Flame",
      instanceType = "none",
      difficultyID = 0,
    }

    WithGlobals({
      GetInstanceInfo = function()
        return current.instanceName, current.instanceType, current.difficultyID, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
      C_Timer = {
        After = function(_delay, fn)
          fn()
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        showCenterNotice = function(message, duration, _dungeonName, _activityID, _showOptions)
          table.insert(notices, { message = message, duration = duration })
        end,
        hideCenterNotice = function() end,
      })

      -- Prime state outside dungeon.
      controller.MaybeShowNonMythicDungeonEntryNotice()

      current.instanceType = "party"
      current.difficultyID = 1
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(#notices, 1, "normal dungeon entry should show non-mythic notice")
      Assert.True(
        string.find(notices[1].message, "Normal", 1, true) ~= nil,
        "normal notice should include normal difficulty label"
      )

      -- Difficulty changes to heroic while still in party instance context.
      current.difficultyID = 2
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(#notices, 2, "normal -> heroic switch should show another non-mythic notice")
      Assert.True(
        string.find(notices[2].message, "Heroic", 1, true) ~= nil,
        "heroic notice should include heroic difficulty label"
      )

      -- Repeated context refreshes for same difficulty must not spam.
      controller.MaybeShowNonMythicDungeonEntryNotice()
      Assert.Equal(#notices, 2, "repeated heroic refresh should not re-show same notice")
    end)
  end)

  test("Status line includes target dungeon and key level when available", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        getTargetDungeonInfo = function()
          return {
            name = "Ara-Kara",
            level = 14,
          }
        end,
      })

      local text = controller.BuildStatusLineText({})
      Assert.True(
        string.find(text, "Target Dungeon: Ara-Kara +14", 1, true) ~= nil,
        "status line should include resolved target dungeon with key level"
      )
    end)
  end)

  test("Status line places target dungeon at the end", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
        getTargetDungeonInfo = function()
          return {
            name = "Ara-Kara",
            level = 14,
          }
        end,
      })

      local text = controller.BuildStatusLineText({})
      Assert.Equal(
        text,
        "Lead: No | M+: Inactive | State: Running | Dungeon: Outside | Target Dungeon: Ara-Kara +14",
        "target dungeon should be rendered at the end of the status line"
      )
    end)
  end)

  test("Status line keeps target placeholder when no target is available", function()
    WithGlobals({
      GetInstanceInfo = function()
        return "Outside", "none", 0, "Unknown"
      end,
      C_ChallengeMode = {
        GetActiveChallengeMapID = function()
          return nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_status.lua" })
      local controller = addon.Status.CreateController({
        getL = BuildLocale,
      })

      local text = controller.BuildStatusLineText({})
      Assert.True(
        string.find(text, "Target Dungeon: -", 1, true) ~= nil,
        "status line should show target placeholder when no target is known"
      )
    end)
  end)
end
