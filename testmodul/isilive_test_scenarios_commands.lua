---@diagnostic disable: undefined-global, duplicate-set-field

local function BuildCommandLocale()
  return {
    HELP_HEADER = "Commands:",
    HELP_LEAD = "/isilive lead",
    HELP_TEST = "/isilive test",
    HELP_TESTALL = "/isilive testall",
    HELP_TPTEST = "/isilive tptest",
    HELP_TPDEBUG = "/isilive tpdebug",
    HELP_LOG = "/isilive log",
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
end

local function BuildCommandState(overrides)
  return {
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
    runtimeLogEnabled = false,
    runtimeLogs = {},
    _overrides = overrides or {},
  }
end

local function BuildRuntimeLogTail(state, limit)
  local count = tonumber(limit) or 20
  if count < 1 then
    count = 1
  elseif count > 100 then
    count = 100
  end
  local startIndex = #state.runtimeLogs - count + 1
  if startIndex < 1 then
    startIndex = 1
  end
  local out = {}
  for i = startIndex, #state.runtimeLogs do
    out[#out + 1] = state.runtimeLogs[i]
  end
  return out
end

local function BuildCommandDeps(state, L)
  local overrides = state._overrides or {}
  return {
    printFn = function(msg)
      table.insert(state.prints, tostring(msg))
    end,
    getL = function()
      return L
    end,
    getState = function()
      return state
    end,
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
    isPlayerLeader = overrides.isPlayerLeader or function()
      return false
    end,
    setLanguage = function(lang)
      state.languageSet = lang
    end,
    forceTeleportTestTarget = function() end,
    printTeleportDebug = function() end,
    setQueueDebugEnabled = function() end,
    getQueueDebugEnabled = function()
      return false
    end,
    clearQueueDebugLog = function() end,
    getQueueDebugLogCount = function()
      return 0
    end,
    getQueueDebugLogTail = function()
      return {}
    end,
    setRuntimeLogEnabled = function(enabled)
      state.runtimeLogEnabled = enabled == true
    end,
    getRuntimeLogEnabled = function()
      return state.runtimeLogEnabled
    end,
    clearRuntimeLog = function()
      state.runtimeLogs = {}
    end,
    getRuntimeLogCount = function()
      return #state.runtimeLogs
    end,
    getRuntimeLogTail = function(limit)
      return BuildRuntimeLogTail(state, limit)
    end,
  }
end

local function BuildCommandExecutor(WithGlobals, LoadAddonModules, overrides)
  local state = BuildCommandState(overrides)
  local L = BuildCommandLocale()
  local executor = nil

  WithGlobals({
    strtrim = function(s)
      return s:match("^%s*(.-)%s*$")
    end,
    SLASH_ISILIVE1 = nil,
    SlashCmdList = SlashCmdList or {},
  }, function()
    local addon = LoadAddonModules({ "isiLive_commands.lua" })
    addon.Commands.RegisterSlashCommands(BuildCommandDeps(state, L))
    executor = SlashCmdList["ISILIVE"]
  end)

  state._execute = function(msg)
    local oldStrtrim = rawget(_G, "strtrim")
    _G.strtrim = function(s)
      return s:match("^%s*(.-)%s*$")
    end
    if type(executor) ~= "function" then
      return
    end
    executor(msg)
    if oldStrtrim then
      _G.strtrim = oldStrtrim
    else
      _G.strtrim = nil
    end
  end

  state._overrides = nil
  return state
end

local function RegisterCommandCoreTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Commands routes test command to toggle", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("test")
    Assert.Equal(state.testToggles, 1, "test command must trigger toggle")
  end)

  test("Commands stop/start cycle works correctly", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)

    state._execute("stop")
    Assert.True(state.isStopped, "stop must set isStopped")
    Assert.False(state.mainFrameVisible, "stop must hide frame")

    state._execute("start")
    Assert.False(state.isStopped, "start must clear isStopped")
    Assert.Equal(state.rosterUpdates, 1, "start must trigger roster update")
  end)

  test("Commands pause/resume cycle works correctly", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)

    state._execute("pause")
    Assert.True(state.isPaused, "pause must set isPaused")

    state._execute("resume")
    Assert.False(state.isPaused, "resume must clear isPaused")
    Assert.Equal(state.rosterUpdates, 1, "resume must trigger roster update")
  end)

  test("Commands lang sets language for valid args", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)

    state._execute("lang de")
    Assert.Equal(state.languageSet, "de", "lang de must set German")

    state._execute("lang en")
    Assert.Equal(state.languageSet, "en", "lang en must set English")

    state._execute("lang xx")
    Assert.Equal(state.languageSet, "en", "invalid lang must not change from last valid")
    Assert.True(#state.prints > 0, "invalid lang must print usage")
  end)
end

local function RegisterCommandRuntimeLogTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Commands runtime log toggle and status output work", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)

    state._execute("log status")
    Assert.True(state.prints[#state.prints]:find("Runtime log: OFF") ~= nil, "status should report runtime log OFF")

    state._execute("log start")
    Assert.True(state.runtimeLogEnabled, "log start must enable runtime log")

    state._execute("log stop")
    Assert.False(state.runtimeLogEnabled, "log stop must disable runtime log")

    state._execute("log on")
    Assert.True(state.runtimeLogEnabled, "log on alias must enable runtime log")

    state._execute("log off")
    Assert.False(state.runtimeLogEnabled, "log off alias must disable runtime log")
  end)

  test("Commands runtime log tail and clear work", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state.runtimeLogs = {
      "10:00:00 first",
      "10:00:01 second",
      "10:00:02 third",
    }

    state._execute("log tail 2")
    Assert.True(state.prints[#state.prints - 1]:find("10:00:01 second") ~= nil, "tail must include second newest entry")
    Assert.True(state.prints[#state.prints]:find("10:00:02 third") ~= nil, "tail must include newest entry")

    state._execute("log clear")
    Assert.Equal(#state.runtimeLogs, 0, "log clear must wipe runtime log storage")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterCommandCoreTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCommandRuntimeLogTests(test, Assert, WithGlobals, LoadAddonModules)
end
