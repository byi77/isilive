local _, addonTable = ...

addonTable = addonTable or {}

local Commands = {}
addonTable.Commands = Commands

local function BuildDeps(opts)
  opts = opts or {}
  return {
    printFn = opts.printFn or print,
    getL = opts.getL or function()
      return {}
    end,
    getState = opts.getState or function()
      return {}
    end,
    setState = opts.setState or function(_patch) end,
    triggerGroupRosterUpdate = opts.triggerGroupRosterUpdate or function() end,
    toggleStandardTestMode = opts.toggleStandardTestMode or function() end,
    enterFullDummyPreview = opts.enterFullDummyPreview or function() end,
    setMainFrameVisible = opts.setMainFrameVisible or function(_visible) end,
    updateLeaderButtons = opts.updateLeaderButtons or function() end,
    isPlayerLeader = opts.isPlayerLeader or function()
      return false
    end,
    setLanguage = opts.setLanguage or function(_language) end,
    forceTeleportTestTarget = opts.forceTeleportTestTarget or function() end,
    printTeleportDebug = opts.printTeleportDebug or function() end,
    setQueueDebugEnabled = opts.setQueueDebugEnabled or function(_enabled) end,
    getQueueDebugEnabled = opts.getQueueDebugEnabled or function()
      return false
    end,
    clearQueueDebugLog = opts.clearQueueDebugLog or function() end,
    getQueueDebugLogCount = opts.getQueueDebugLogCount or function()
      return 0
    end,
    getQueueDebugLogTail = opts.getQueueDebugLogTail or function(_limit)
      return {}
    end,
    setRuntimeLogEnabled = opts.setRuntimeLogEnabled or function(_enabled) end,
    getRuntimeLogEnabled = opts.getRuntimeLogEnabled or function()
      return false
    end,
    clearRuntimeLog = opts.clearRuntimeLog or function() end,
    getRuntimeLogCount = opts.getRuntimeLogCount or function()
      return 0
    end,
    getRuntimeLogTail = opts.getRuntimeLogTail or function(_limit)
      return {}
    end,
  }
end

local function PrintHelp(printFn, L)
  printFn(L.HELP_HEADER)
  printFn(L.HELP_LEAD)
  printFn(L.HELP_TEST)
  printFn(L.HELP_TESTALL)
  printFn(L.HELP_TPTEST)
  printFn(L.HELP_TPDEBUG)
  printFn(L.HELP_LOG)
  printFn(L.HELP_BINDCHECK)
  printFn(L.HELP_LANG)
  printFn(L.HELP_PAUSE)
  printFn(L.HELP_RESUME)
  printFn(L.HELP_STOP)
  printFn(L.HELP_START)
end

local function HandleLogCommand(ctx, cmd)
  local arg, numText = cmd:match("^log%s+(%S+)%s*(%d*)$")
  if not arg or arg == "status" then
    ctx.printFn(
      "Runtime log: "
        .. (ctx.getRuntimeLogEnabled() and "ON" or "OFF")
        .. " | entries: "
        .. tostring(ctx.getRuntimeLogCount())
    )
    return
  end

  if arg == "on" or arg == "start" or arg == "1" or arg == "true" then
    ctx.setRuntimeLogEnabled(true)
    ctx.printFn("Runtime log: ON")
    return
  end
  if arg == "off" or arg == "stop" or arg == "0" or arg == "false" then
    ctx.setRuntimeLogEnabled(false)
    ctx.printFn("Runtime log: OFF")
    return
  end
  if arg == "clear" then
    ctx.clearRuntimeLog()
    ctx.printFn("Runtime log: cleared")
    return
  end

  if arg == "tail" or arg == "dump" then
    local limit = tonumber(numText) or 20
    if limit < 1 then
      limit = 1
    elseif limit > 100 then
      limit = 100
    end
    local lines = ctx.getRuntimeLogTail(limit)
    ctx.printFn("Runtime log tail: " .. tostring(#lines) .. "/" .. tostring(ctx.getRuntimeLogCount()) .. " entries")
    for _, line in ipairs(lines) do
      ctx.printFn(tostring(line))
    end
    return
  end

  ctx.printFn("Usage: /isilive log [on|off|start|stop|status|clear|tail [n]]")
end

local function HandleQDebugCommand(ctx, cmd)
  local arg, numText = cmd:match("^qdebug%s+(%S+)%s*(%d*)$")
  if not arg or arg == "status" then
    ctx.printFn(
      "Queue debug: "
        .. (ctx.getQueueDebugEnabled() and "ON" or "OFF")
        .. " | entries: "
        .. tostring(ctx.getQueueDebugLogCount())
    )
    return
  end

  if arg == "on" or arg == "1" or arg == "true" then
    ctx.setQueueDebugEnabled(true)
    ctx.printFn("Queue debug: ON")
    return
  end
  if arg == "off" or arg == "0" or arg == "false" then
    ctx.setQueueDebugEnabled(false)
    ctx.printFn("Queue debug: OFF")
    return
  end
  if arg == "clear" then
    ctx.clearQueueDebugLog()
    ctx.printFn("Queue debug log: cleared")
    return
  end

  if arg == "tail" or arg == "dump" then
    local limit = tonumber(numText) or 20
    if limit < 1 then
      limit = 1
    elseif limit > 100 then
      limit = 100
    end
    local lines = ctx.getQueueDebugLogTail(limit)
    ctx.printFn("Queue debug tail: " .. tostring(#lines) .. "/" .. tostring(ctx.getQueueDebugLogCount()) .. " entries")
    for _, line in ipairs(lines) do
      ctx.printFn(tostring(line))
    end
    return
  end

  ctx.printFn("Usage: /isilive qdebug [on|off|status|clear|tail [n]]")
end

local function HandleBindCheck(printFn)
  local action1 = GetBindingAction("CTRL-F9", true)
  local action2 = GetBindingAction("CTRL-ALT-F9", true)
  local action3 = GetBindingAction("ALT-CTRL-F9", true)
  printFn("CTRL-F9 => " .. (action1 and action1 ~= "" and action1 or "<none>"))
  printFn("CTRL-ALT-F9 => " .. (action2 and action2 ~= "" and action2 or "<none>"))
  printFn("ALT-CTRL-F9 => " .. (action3 and action3 ~= "" and action3 or "<none>"))
end

local function ExecuteSlashCommand(ctx, msg)
  local L = ctx.getL() or {}
  local state = ctx.getState() or {}
  local cmd = string.lower(strtrim(msg or ""))

  if cmd == "test" then
    ctx.toggleStandardTestMode()
    return
  end

  if cmd == "testall" then
    if state.isStopped then
      ctx.printFn(L.ERR_STOPPED_TEST)
      return
    end
    if state.isPaused then
      ctx.printFn(L.ERR_PAUSED_TEST)
      return
    end
    ctx.enterFullDummyPreview()
    return
  end

  if cmd == "stop" then
    ctx.setState({
      isStopped = true,
      isPaused = false,
      isTestMode = false,
      isTestAllMode = false,
      wasGroupLeader = nil,
    })
    ctx.setMainFrameVisible(false)
    ctx.updateLeaderButtons()
    ctx.printFn(L.STOPPED)
    return
  end

  if cmd == "pause" then
    if state.isStopped then
      ctx.printFn(L.ERR_STOPPED_USE_START)
      return
    end
    ctx.setState({
      isPaused = true,
      isTestMode = false,
      isTestAllMode = false,
    })
    ctx.setMainFrameVisible(false)
    ctx.updateLeaderButtons()
    ctx.printFn(L.PAUSED)
    return
  end

  if cmd == "resume" then
    if state.isStopped then
      ctx.printFn(L.ERR_STOPPED_USE_START)
      return
    end
    ctx.setState({
      isPaused = false,
      isTestMode = false,
      isTestAllMode = false,
    })
    ctx.updateLeaderButtons()
    ctx.printFn(L.RESUMED)
    ctx.triggerGroupRosterUpdate()
    return
  end

  if cmd == "start" then
    ctx.setState({
      isStopped = false,
      isPaused = false,
      isTestMode = false,
      isTestAllMode = false,
    })
    ctx.updateLeaderButtons()
    ctx.printFn(L.STARTED)
    ctx.triggerGroupRosterUpdate()
    return
  end

  if cmd == "lead" then
    ctx.printFn(ctx.isPlayerLeader() and L.LEAD_STATUS_YES or L.LEAD_STATUS_NO)
    return
  end

  if cmd:find("^lang") == 1 then
    local arg = cmd:match("^lang%s+(%S+)$")
    if arg == "en" or arg == "de" or arg == "enus" or arg == "dede" then
      ctx.setLanguage(arg)
    else
      ctx.printFn(L.LANG_USAGE)
    end
    return
  end

  if cmd == "tptest" then
    ctx.forceTeleportTestTarget()
    return
  end

  if cmd == "tpdebug" then
    ctx.printTeleportDebug()
    return
  end

  if cmd == "log" or cmd:find("^log%s+") == 1 then
    HandleLogCommand(ctx, cmd)
    return
  end

  if cmd == "qdebug" or cmd:find("^qdebug%s+") == 1 then
    HandleQDebugCommand(ctx, cmd)
    return
  end

  if cmd == "bindcheck" then
    HandleBindCheck(ctx.printFn)
    return
  end

  PrintHelp(ctx.printFn, L)
end

function Commands.RegisterSlashCommands(opts)
  local deps = BuildDeps(opts)

  SLASH_ISILIVE1 = "/isilive"
  SlashCmdList["ISILIVE"] = function(msg)
    ExecuteSlashCommand(deps, msg)
  end
end
