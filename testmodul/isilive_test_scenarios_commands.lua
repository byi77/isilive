---@diagnostic disable: undefined-global, duplicate-set-field, need-check-nil
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function BuildCommandExecutor(overrides)
    overrides = overrides or {}
    local state = {
      prints = {},
      isStopped = false,
      isPaused = false,
      isTestMode = false,
      isTestAllMode = false,
      testToggles = 0,
      fullPreviews = 0,
      mainFrameVisible = true,
      languageSet = nil,
      rosterUpdates = 0,
    }

    local L = {
      HELP_HEADER = "Commands:",
      HELP_LEAD = "/isilive lead",
      HELP_TEST = "/isilive test",
      HELP_TESTALL = "/isilive testall",
      HELP_TPTEST = "/isilive tptest",
      HELP_TPDEBUG = "/isilive tpdebug",
      HELP_BINDCHECK = "/isilive bindcheck",
      HELP_LANG = "/isilive lang [en|de]",
      HELP_PAUSE = "/isilive pause",
      HELP_RESUME = "/isilive resume",
      HELP_STOP = "/isilive stop",
      HELP_START = "/isilive start",
      STOPPED = "Addon manually stopped.",
      PAUSED = "Addon paused.",
      RESUMED = "Addon resumed.",
      STARTED = "Addon started.",
      ERR_STOPPED_USE_START = "Addon is stopped. Use /isilive start.",
      ERR_STOPPED_TEST = "Addon is stopped.",
      ERR_PAUSED_TEST = "Addon is paused.",
      LEAD_STATUS_YES = "Lead: Yes",
      LEAD_STATUS_NO = "Lead: No",
      LANG_USAGE = "Usage: /isilive lang [en|de]",
    }

    local executor = nil

    WithGlobals({
      strtrim = function(s)
        return s:match("^%s*(.-)%s*$")
      end,
      SLASH_ISILIVE1 = nil,
      SlashCmdList = SlashCmdList or {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_commands.lua" })
      addon.Commands.RegisterSlashCommands({
        printFn = function(msg)
          table.insert(state.prints, tostring(msg))
        end,
        getL = function() return L end,
        getState = function() return state end,
        setState = function(patch)
          for k, v in pairs(patch) do
            state[k] = v
          end
        end,
        triggerGroupRosterUpdate = function()
          state.rosterUpdates = state.rosterUpdates + 1
        end,
        toggleStandardTestMode = function()
          state.testToggles = state.testToggles + 1
        end,
        enterFullDummyPreview = function()
          state.fullPreviews = state.fullPreviews + 1
        end,
        setMainFrameVisible = function(visible)
          state.mainFrameVisible = visible
        end,
        updateLeaderButtons = function() end,
        isPlayerLeader = overrides.isPlayerLeader or function() return false end,
        setLanguage = function(lang)
          state.languageSet = lang
        end,
        forceTeleportTestTarget = function() end,
        printTeleportDebug = function() end,
        setQueueDebugEnabled = function() end,
        getQueueDebugEnabled = function() return false end,
        clearQueueDebugLog = function() end,
        getQueueDebugLogCount = function() return 0 end,
        getQueueDebugLogTail = function() return {} end,
      })

      executor = SlashCmdList["ISILIVE"]
    end)

    state._execute = function(msg)
      -- strtrim must be available during execution too
      local oldStrtrim = rawget(_G, "strtrim")
      _G.strtrim = function(s) return s:match("^%s*(.-)%s*$") end
      executor(msg)
      if oldStrtrim then
        _G.strtrim = oldStrtrim
      else
        _G.strtrim = nil
      end
    end

    return state
  end

  test("Commands routes test command to toggle", function()
    local state = BuildCommandExecutor()
    state._execute("test")
    Assert.Equal(state.testToggles, 1, "test command must trigger toggle")
  end)

  test("Commands stop/start cycle works correctly", function()
    local state = BuildCommandExecutor()

    state._execute("stop")
    Assert.True(state.isStopped, "stop must set isStopped")
    Assert.False(state.mainFrameVisible, "stop must hide frame")

    state._execute("start")
    Assert.False(state.isStopped, "start must clear isStopped")
    Assert.Equal(state.rosterUpdates, 1, "start must trigger roster update")
  end)

  test("Commands pause/resume cycle works correctly", function()
    local state = BuildCommandExecutor()

    state._execute("pause")
    Assert.True(state.isPaused, "pause must set isPaused")

    state._execute("resume")
    Assert.False(state.isPaused, "resume must clear isPaused")
    Assert.Equal(state.rosterUpdates, 1, "resume must trigger roster update")
  end)

  test("Commands lang sets language for valid args", function()
    local state = BuildCommandExecutor()

    state._execute("lang de")
    Assert.Equal(state.languageSet, "de", "lang de must set German")

    state._execute("lang en")
    Assert.Equal(state.languageSet, "en", "lang en must set English")

    state._execute("lang xx")
    Assert.Equal(state.languageSet, "en", "invalid lang must not change from last valid")
    Assert.True(#state.prints > 0, "invalid lang must print usage")
  end)
end
