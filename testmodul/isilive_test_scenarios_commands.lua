---@diagnostic disable: undefined-global, duplicate-set-field

local function BuildCommandLocale()
  return {
    HELP_HEADER = "Commands:",
    HELP_HELP = "/isilive help",
    HELP_ADMIN = "/isilive admin",
    ADMIN_HEADER = "Admin commands:",
    HELP_TESTALL = "/isilive testall",
    HELP_SIM = "/isilive sim",
    HELP_TPTEST = "/isilive tptest",
    HELP_TPDEBUG = "/isilive tpdebug",
    HELP_SEASONDUMP = "/isilive seasondump",
    HELP_HEARTHDUMP = "/isilive hearthdump",
    HELP_LOG = "/isilive log",
    HELP_QDEBUG = "/isilive qdebug",
    HELP_ERRORLOG = "/isilive errorlog",
    HELP_LOCK = "/isilive lock",
    HELP_UNLOCK = "/isilive unlock",
    HELP_RESETUI = "/isilive resetui",
    HELP_SETTINGS = "/isilive settings",
    HELP_BINDCHECK = "/isilive bindcheck",
    HELP_NPTEST = "/isilive nptest",
    HELP_NPSTATE = "/isilive npstate",
    HELP_RESET = "/isilive reset",
    ERR_STOPPED_TEST = "Addon is stopped.",
    ERR_PAUSED_TEST = "Addon is paused.",
    LOCKED = "Main frame position locked.",
    UNLOCKED = "Main frame position unlocked.",
    RESETUI_DONE = "Main frame reset to defaults and centered.",
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
    runtimeLogLevel = overrides and overrides.runtimeLogLevel or "normal",
    runtimeLogs = {},
    lockMainFramePosition = true,
    uiScale = 1.25,
    bgAlpha = 0.73,
    resetMainFramePositionCalls = 0,
    openSettingsCalls = 0,
    tpTestCalls = 0,
    tpDebugCalls = 0,
    seasonDumpCalls = 0,
    hearthDumpCalls = 0,
    simToggleCalls = 0,
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
    toggleSimulationTablet = function()
      state.simToggleCalls = state.simToggleCalls + 1
      return true
    end,
    setMainFrameVisible = function(visible)
      state.mainFrameVisible = visible
    end,
    getMainFrameLocked = function()
      return state.lockMainFramePosition ~= false
    end,
    setMainFrameLocked = function(locked)
      state.lockMainFramePosition = locked == true
    end,
    resetMainFramePosition = function()
      state.resetMainFramePositionCalls = state.resetMainFramePositionCalls + 1
      state.uiScale = 1.0
      state.bgAlpha = 0.50
    end,
    updateLeaderButtons = function() end,
    isPlayerLeader = overrides.isPlayerLeader or function()
      return false
    end,
    setLanguage = function(lang)
      state.languageSet = lang
    end,
    forceTeleportTestTarget = function()
      state.tpTestCalls = state.tpTestCalls + 1
    end,
    printTeleportDebug = function()
      state.tpDebugCalls = state.tpDebugCalls + 1
    end,
    printSeasonDebug = function()
      state.seasonDumpCalls = state.seasonDumpCalls + 1
    end,
    printHearthstoneDebug = function()
      state.hearthDumpCalls = state.hearthDumpCalls + 1
    end,
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
    setRuntimeLogLevel = function(level)
      state.runtimeLogLevel = level
    end,
    getRuntimeLogLevel = function()
      return state.runtimeLogLevel
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
    -- Error-log mocks for /isilive errorlog tests.
    getErrorLogTail = function(limit)
      local out = {}
      local count = math.min(tonumber(limit) or 10, #(state.errorLogEntries or {}))
      for i = 1, count do
        out[i] = (state.errorLogEntries or {})[i]
      end
      return out
    end,
    getErrorLogCount = function()
      return #(state.errorLogEntries or {})
    end,
    getErrorLogMaxEntries = function()
      return state.errorLogMaxEntries or 100
    end,
    getErrorLogInstalled = function()
      return state.errorLogInstalled == true
    end,
    clearErrorLog = function()
      state.errorLogEntries = {}
      state.errorLogClearCalls = (state.errorLogClearCalls or 0) + 1
    end,
    openSettings = function()
      state.openSettingsCalls = state.openSettingsCalls + 1
      return true
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
    GetBindingAction = function(_binding, _mode)
      return nil
    end,
  }, function()
    local addon = LoadAddonModules({ "isiLive_commands.lua" })
    addon.Commands.RegisterSlashCommands(BuildCommandDeps(state, L))
    executor = SlashCmdList["ISILIVE"]
  end)

  state._execute = function(msg)
    local oldStrtrim = rawget(_G, "strtrim")
    local oldGetBinding = rawget(_G, "GetBindingAction")
    _G.strtrim = function(s)
      return s:match("^%s*(.-)%s*$")
    end
    _G.GetBindingAction = function(_binding, _mode)
      return nil
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
    if oldGetBinding then
      _G.GetBindingAction = oldGetBinding
    else
      _G.GetBindingAction = nil
    end
  end

  state._overrides = nil
  return state
end

local function RegisterCommandCoreTests(test, Assert, WithGlobals, LoadAddonModules) end

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

  test("Commands runtime log level command switches normal and deep", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)

    state._execute("log level")
    Assert.True(
      state.prints[#state.prints]:find("Runtime log level: normal", 1, true) ~= nil,
      "level must default to normal"
    )

    state._execute("log level deep")
    Assert.Equal(state.runtimeLogLevel, "deep", "log level deep must set deep tracing")
    Assert.True(
      state.prints[#state.prints]:find("Runtime log level: deep", 1, true) ~= nil,
      "level output must report deep"
    )

    state._execute("log normal")
    Assert.Equal(state.runtimeLogLevel, "normal", "log normal shortcut must set normal tracing")
  end)
end

local function RegisterCommandExtendedTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Commands testall blocked when stopped prints error", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state.isStopped = true
    state._execute("testall")
    Assert.Equal(state.fullPreviews, 0, "testall must not fire when stopped")
    Assert.True(#state.prints > 0, "must print error message")
  end)

  test("Commands testall blocked when paused prints error", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state.isPaused = true
    state._execute("testall")
    Assert.Equal(state.fullPreviews, 0, "testall must not fire when paused")
    Assert.True(#state.prints > 0, "must print error message")
  end)

  test("Commands testall delegates when running", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("testall")
    Assert.Equal(state.fullPreviews, 1, "testall must call enterFullDummyPreview")
  end)

  test("Commands sim toggles the simulation tablet", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("sim")
    Assert.Equal(state.simToggleCalls, 1, "sim must call toggleSimulationTablet")
  end)

  test("Commands tptest delegates to forceTeleportTestTarget", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("tptest")
    Assert.Equal(state.tpTestCalls, 1, "tptest must call forceTeleportTestTarget")
  end)

  test("Commands tpdebug delegates to printTeleportDebug", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("tpdebug")
    Assert.Equal(state.tpDebugCalls, 1, "tpdebug must call printTeleportDebug")
  end)

  test("Commands seasondump delegates to printSeasonDebug", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("seasondump")
    Assert.Equal(state.seasonDumpCalls, 1, "seasondump must call printSeasonDebug")
  end)

  test("Commands hearthdump delegates to printHearthstoneDebug", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("hearthdump")
    Assert.Equal(state.hearthDumpCalls, 1, "hearthdump must call printHearthstoneDebug")
  end)

  test("Commands bindcheck prints binding info", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("bindcheck")
    local foundCtrlF9 = false
    for _, msg in ipairs(state.prints) do
      if msg:find("CTRL%-F9") then
        foundCtrlF9 = true
      end
    end
    Assert.True(foundCtrlF9, "bindcheck must print CTRL-F9 binding info")
  end)

  test("Commands unknown input prints help", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("xyzgarbage")
    local foundHeader = false
    for _, msg in ipairs(state.prints) do
      if msg:find("Commands:") then
        foundHeader = true
      end
    end
    Assert.True(foundHeader, "unknown command must print help header")
  end)

  test("Commands help lists only public commands", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("")

    local expected = {
      "Commands:",
      "/isilive help",
      "/isilive lock",
      "/isilive unlock",
      "/isilive resetui",
      "/isilive settings",
      "/isilive admin",
    }

    Assert.Equal(#state.prints, #expected, "help must only print the public command list")
    for index, line in ipairs(expected) do
      Assert.True(state.prints[index] == line, "help line " .. tostring(index) .. " must match the public list")
    end
  end)

  test("Commands empty input prints help", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("")
    local foundHeader = false
    for _, msg in ipairs(state.prints) do
      if msg:find("Commands:") then
        foundHeader = true
      end
    end
    Assert.True(foundHeader, "empty command must print help header")
  end)

  test("Commands help input prints help", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("help")
    local foundHeader = false
    for _, msg in ipairs(state.prints) do
      if msg:find("Commands:") then
        foundHeader = true
      end
    end
    Assert.True(foundHeader, "help command must print help header")
  end)

  test("Commands admin input prints admin command list", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("admin")

    local expected = {
      "Admin commands:",
      "/isilive testall",
      "/isilive sim",
      "/isilive log",
      "/isilive qdebug",
      "/isilive errorlog",
      "/isilive bindcheck",
      "/isilive tptest",
      "/isilive tpdebug",
      "/isilive seasondump",
      "/isilive hearthdump",
      "/isilive nptest",
      "/isilive npstate",
      "/isilive reset",
    }

    Assert.Equal(#state.prints, #expected, "admin help must print only the admin command list")
    for index, line in ipairs(expected) do
      Assert.True(state.prints[index] == line, "admin help line " .. tostring(index) .. " must match")
    end
  end)

  test("Commands removed legacy commands fall back to public help", function()
    local removed = { "test", "pause", "resume", "lead", "stop", "start", "lang", "lang de" }
    for _, cmd in ipairs(removed) do
      local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
      state._execute(cmd)
      Assert.Equal(state.prints[1], "Commands:", "removed command " .. cmd .. " must print public help")
      Assert.Equal(state.testToggles, 0, "removed test command must not toggle test mode")
      Assert.False(state.isPaused, "removed pause command must not set paused state")
      Assert.Equal(state.rosterUpdates, 0, "removed command " .. cmd .. " must not trigger roster updates")
    end
  end)

  test("Commands settings opens the settings panel", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state._execute("settings")
    Assert.Equal(state.openSettingsCalls, 1, "settings command must call the settings opener")
  end)

  test("Commands lock and unlock update main frame lock state", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)

    state.lockMainFramePosition = false
    state._execute("lock")
    Assert.True(state.lockMainFramePosition, "lock must enable the main frame position lock")
    Assert.True(state.prints[#state.prints]:find("locked") ~= nil, "lock must print locked feedback")

    state._execute("unlock")
    Assert.False(state.lockMainFramePosition, "unlock must disable the main frame position lock")
    Assert.True(state.prints[#state.prints]:find("unlocked") ~= nil, "unlock must print unlocked feedback")
  end)

  test("Commands resetui restores main frame defaults", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)

    state._execute("resetui")
    Assert.Equal(state.resetMainFramePositionCalls, 1, "resetui must call the main frame reset helper")
    Assert.Equal(state.uiScale, 1.0, "resetui must restore the UI scale default")
    Assert.Equal(state.bgAlpha, 0.50, "resetui must restore the background opacity default")
    Assert.True(state.prints[#state.prints]:find("defaults") ~= nil, "resetui must print a defaults confirmation")
    Assert.True(state.prints[#state.prints]:find("center") ~= nil, "resetui must print a center confirmation")
  end)

  -- /isilive errorlog [N|status|clear] -------------------------------------

  test("Commands errorlog status prints install state and counts", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state.errorLogInstalled = true
    state.errorLogEntries = { { message = "isiLive: foo" } }
    state.errorLogMaxEntries = 100
    state._execute("errorlog status")
    local statusLine = state.prints[#state.prints]
    Assert.True(statusLine:find("installed") ~= nil, "status must print install state")
    Assert.True(statusLine:find("1") ~= nil, "status must print entry count")
    Assert.True(statusLine:find("100") ~= nil, "status must print cap")
  end)

  test("Commands errorlog clear empties the buffer", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state.errorLogEntries = { { message = "isiLive: foo" }, { message = "isiLive: bar" } }
    state._execute("errorlog clear")
    Assert.Equal(state.errorLogClearCalls, 1, "clear must call clearErrorLog once")
    Assert.True(state.prints[#state.prints]:find("cleared") ~= nil, "clear must print confirmation")
  end)

  test("Commands errorlog tail prints recent entries", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state.errorLogEntries = {
      {
        message = "isiLive: error A",
        fullText = "isiLive: error A\nstack frame 1",
        count = 1,
        firstSeenDisplay = "12:00:00",
        lastSeenDisplay = "12:00:00",
      },
      {
        message = "isiLive: error B",
        fullText = "isiLive: error B",
        count = 5,
        firstSeenDisplay = "12:01:00",
        lastSeenDisplay = "12:01:30",
      },
    }
    state._execute("errorlog 5")
    local found = {}
    for _, msg in ipairs(state.prints) do
      if msg:find("isiLive: error A", 1, true) then
        found.errorA = true
      end
      if msg:find("isiLive: error B", 1, true) then
        found.errorB = true
      end
      if msg:find("x5", 1, true) then
        found.dedupCount = true
      end
    end
    Assert.True(found.errorA, "errorlog tail must include error A")
    Assert.True(found.errorB, "errorlog tail must include error B")
    Assert.True(found.dedupCount, "errorlog tail must include the (xN) dedup suffix")
  end)

  test("Commands errorlog with empty buffer prints no-entries message", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state.errorLogEntries = {}
    state._execute("errorlog")
    local lastMessage = state.prints[#state.prints]
    Assert.True(lastMessage:find("no entries") ~= nil, "errorlog with empty buffer must say no entries")
  end)

  test("Commands errorlog defaults to tail with 10 entries when no arg given", function()
    local state = BuildCommandExecutor(WithGlobals, LoadAddonModules)
    state.errorLogEntries = {}
    for i = 1, 25 do
      state.errorLogEntries[i] = { message = "isiLive: err " .. i, count = 1 }
    end
    state._execute("errorlog")
    local headerFound = false
    for _, msg in ipairs(state.prints) do
      if msg:find("Error log tail:") then
        headerFound = true
        break
      end
    end
    Assert.True(headerFound, "errorlog must print tail header by default")
  end)
end

-- Branch-coverage tests targeting the rarely-exercised command handlers:
-- /isilive log watch (with and without trace-chat-frame integration), filtered
-- tail, qdebug-watch-removal, /isilive reset, /isilive nptest, /isilive
-- npstate, log-tail clamp boundaries, and the logRuntimeTracef trace hook.
local function RegisterCommandBranchCoverageTests(test, Assert, WithGlobals, LoadAddonModules)
  -- Variant of BuildCommandExecutor that lets tests inject extra deps (watch
  -- callbacks, resetDB, nameplate hooks, trace hook) on top of the standard set.
  local function BuildExecutorWithExtras(extras)
    local state = BuildCommandState(nil)
    local L = BuildCommandLocale()
    local executor = nil

    WithGlobals({
      strtrim = function(s)
        return s:match("^%s*(.-)%s*$")
      end,
      SLASH_ISILIVE1 = nil,
      SlashCmdList = SlashCmdList or {},
      GetBindingAction = function(_binding, _mode)
        return nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_commands.lua" })
      local deps = BuildCommandDeps(state, L)
      for k, v in pairs(extras or {}) do
        deps[k] = v
      end
      addon.Commands.RegisterSlashCommands(deps)
      executor = SlashCmdList["ISILIVE"]
    end)

    state._execute = function(msg)
      _G.strtrim = function(s)
        return s:match("^%s*(.-)%s*$")
      end
      _G.GetBindingAction = function(_binding, _mode)
        return nil
      end
      if type(executor) == "function" then
        executor(msg)
      end
    end

    return state
  end

  local function findPrint(state, needle)
    for _, msg in ipairs(state.prints) do
      if msg:find(needle, 1, true) then
        return msg
      end
    end
    return nil
  end

  test("Commands log watch toggles ON via raw print sink when no trace chat frame is wired", function()
    local watchActive = false
    local installedSink = nil
    local state = BuildExecutorWithExtras({
      setRuntimeLogWatch = function(fn)
        installedSink = fn
        watchActive = fn ~= nil
      end,
      getRuntimeLogWatchActive = function()
        return watchActive
      end,
    })
    state._execute("log watch")
    Assert.True(watchActive, "watch must be installed")
    Assert.NotNil(findPrint(state, "watch ON"), "watch ON message must be printed")
    Assert.True(type(installedSink) == "function", "sink callback must be installed")
  end)

  test("Commands log watch streams entries to trace chat frame when the hooks are provided", function()
    local watchActive = false
    local openCalls = 0
    local sinkMessages = {}
    local state = BuildExecutorWithExtras({
      setRuntimeLogWatch = function(fn)
        watchActive = fn ~= nil
      end,
      getRuntimeLogWatchActive = function()
        return watchActive
      end,
      openTraceChatFrame = function()
        openCalls = openCalls + 1
      end,
      addTraceChatFrameMessage = function(entry)
        table.insert(sinkMessages, entry)
      end,
    })
    state._execute("log watch")
    Assert.Equal(openCalls, 1, "trace chat frame must be opened on watch ON")
    Assert.NotNil(findPrint(state, "trace chat tab"), "trace-chat ON message must be printed")
  end)

  test("Commands log watch turns OFF when already active and closes the trace chat frame", function()
    local watchActive = true
    local clearedSink = false
    local closeCalls = 0
    local state = BuildExecutorWithExtras({
      setRuntimeLogWatch = function(fn)
        if fn == nil then
          clearedSink = true
          watchActive = false
        end
      end,
      getRuntimeLogWatchActive = function()
        return watchActive
      end,
      closeTraceChatFrame = function()
        closeCalls = closeCalls + 1
      end,
    })
    state._execute("log watch")
    Assert.True(clearedSink, "watch must be cleared")
    Assert.Equal(closeCalls, 1, "trace chat frame must be closed on watch OFF")
    Assert.NotNil(findPrint(state, "watch OFF"), "watch OFF message must be printed")
  end)

  test("Commands qdebug watch is no longer accepted as a special subcommand", function()
    local state = BuildExecutorWithExtras({})
    state._execute("qdebug watch")
    Assert.NotNil(findPrint(state, "Usage: /isilive qdebug"), "qdebug watch must fall back to the qdebug usage line")
  end)

  test("Commands log tail with tag filter delegates to getFilteredTail and renders filter header", function()
    local capturedLimit, capturedTag
    local state = BuildExecutorWithExtras({
      getRuntimeLogTailFiltered = function(limit, tag)
        capturedLimit = limit
        capturedTag = tag
        return { "[CMD] foo", "[CMD] bar" }, 17
      end,
    })
    state._execute("log tail 5 CMD")
    Assert.Equal(capturedLimit, 5, "filtered-tail must receive numeric limit")
    Assert.Equal(capturedTag, "cmd", "filtered-tail must receive tag (input is lowercased before dispatch)")
    Assert.NotNil(findPrint(state, "(filter=cmd)"), "header must mention the filter")
    Assert.NotNil(findPrint(state, "[CMD] foo"), "filtered entries must be printed")
  end)

  test("Commands log tail clamps negative or zero limit to 1", function()
    local capturedLimit
    local state = BuildExecutorWithExtras({
      getRuntimeLogTail = function(limit)
        capturedLimit = limit
        return {}
      end,
    })
    state._execute("log tail 0")
    Assert.Equal(capturedLimit, 1, "limit < 1 must be clamped to 1")
  end)

  test("Commands log tail clamps oversized limit to 100", function()
    local capturedLimit
    local state = BuildExecutorWithExtras({
      getRuntimeLogTail = function(limit)
        capturedLimit = limit
        return {}
      end,
    })
    state._execute("log tail 9999")
    Assert.Equal(capturedLimit, 100, "limit > 100 must be clamped to 100")
  end)

  test("Commands reset routes /isilive reset to ctx.resetDB", function()
    local resetCalls = 0
    local state = BuildExecutorWithExtras({
      resetDB = function()
        resetCalls = resetCalls + 1
      end,
    })
    state._execute("reset")
    Assert.Equal(resetCalls, 1, "/isilive reset must call ctx.resetDB exactly once")
  end)

  test("Commands nptest without arg toggles nameplate test mode and prints ON banner", function()
    local capturedArg = "<unset>"
    local state = BuildExecutorWithExtras({
      toggleNameplateTestMode = function(arg)
        capturedArg = arg
        return true
      end,
    })
    state._execute("nptest")
    Assert.Equal(capturedArg, nil, "nptest without arg must pass nil")
    Assert.NotNil(findPrint(state, "Nameplate test mode ON"), "ON banner must be printed")
  end)

  test(
    "Commands nptest with arg parses arg after whitespace and prints OFF banner when toggle returns false",
    function()
      local capturedArg
      local state = BuildExecutorWithExtras({
        toggleNameplateTestMode = function(arg)
          capturedArg = arg
          return false
        end,
      })
      state._execute("nptest 50")
      Assert.Equal(capturedArg, "50", "nptest must forward the trimmed arg string")
      Assert.NotNil(findPrint(state, "Nameplate test mode OFF"), "OFF banner must be printed")
    end
  )

  test("Commands npstate forwards arg to dumpNameplateState", function()
    local capturedArg
    local state = BuildExecutorWithExtras({
      dumpNameplateState = function(arg)
        capturedArg = arg
      end,
    })
    state._execute("npstate target")
    Assert.Equal(capturedArg, "target", "npstate must forward the parsed arg")
  end)

  test("Commands ExecuteSlashCommand emits trace via logRuntimeTracef when provided", function()
    local traces = {}
    local state = BuildExecutorWithExtras({
      logRuntimeTracef = function(fmt, ...)
        table.insert(traces, string.format(fmt, ...))
      end,
    })
    state._execute("help")
    local found = false
    for _, line in ipairs(traces) do
      if line:find("[CMD] execute cmd=help", 1, true) then
        found = true
        break
      end
    end
    Assert.True(found, "logRuntimeTracef must receive an [CMD] execute trace line")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterCommandCoreTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCommandRuntimeLogTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCommandExtendedTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCommandBranchCoverageTests(test, Assert, WithGlobals, LoadAddonModules)
end
