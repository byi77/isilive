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

local ARG_ON  = { on = true, ["1"] = true, ["true"] = true }
local ARG_OFF = { off = true, ["0"] = true, ["false"] = true }

-- Generic handler for debug log sub-commands (shared by "log" and "qdebug").
-- cfg fields: prefix, label, extraOn (table), extraOff (table),
--             getEnabled, setEnabled, clearLog, getCount, getTail, usageStr
local function HandleDebugLogCommand(ctx, cmd, cfg)
  local arg, numText = cmd:match("^" .. cfg.prefix .. "%s+(%S+)%s*(%d*)$")
  if not arg or arg == "status" then
    ctx.printFn(cfg.label .. ": " .. (cfg.getEnabled() and "ON" or "OFF") .. " | entries: " .. tostring(cfg.getCount()))
    return
  end

  if ARG_ON[arg] or (cfg.extraOn and cfg.extraOn[arg]) then
    cfg.setEnabled(true)
    ctx.printFn(cfg.label .. ": ON")
    return
  end
  if ARG_OFF[arg] or (cfg.extraOff and cfg.extraOff[arg]) then
    cfg.setEnabled(false)
    ctx.printFn(cfg.label .. ": OFF")
    return
  end
  if arg == "clear" then
    cfg.clearLog()
    ctx.printFn(cfg.label .. ": cleared")
    return
  end

  if arg == "tail" or arg == "dump" then
    local limit = tonumber(numText) or 20
    if limit < 1 then
      limit = 1
    elseif limit > 100 then
      limit = 100
    end
    local lines = cfg.getTail(limit)
    ctx.printFn(cfg.label .. " tail: " .. tostring(#lines) .. "/" .. tostring(cfg.getCount()) .. " entries")
    for _, line in ipairs(lines) do
      ctx.printFn(tostring(line))
    end
    return
  end

  ctx.printFn(cfg.usageStr)
end

local function HandleLogCommand(ctx, cmd)
  HandleDebugLogCommand(ctx, cmd, {
    prefix = "log",
    label = "Runtime log",
    extraOn = { start = true },
    extraOff = { stop = true },
    getEnabled = ctx.getRuntimeLogEnabled,
    setEnabled = ctx.setRuntimeLogEnabled,
    clearLog = ctx.clearRuntimeLog,
    getCount = ctx.getRuntimeLogCount,
    getTail = ctx.getRuntimeLogTail,
    usageStr = "Usage: /isilive log [on|off|start|stop|status|clear|tail [n]]",
  })
end

local function HandleQDebugCommand(ctx, cmd)
  HandleDebugLogCommand(ctx, cmd, {
    prefix = "qdebug",
    label = "Queue debug",
    getEnabled = ctx.getQueueDebugEnabled,
    setEnabled = ctx.setQueueDebugEnabled,
    clearLog = ctx.clearQueueDebugLog,
    getCount = ctx.getQueueDebugLogCount,
    getTail = ctx.getQueueDebugLogTail,
    usageStr = "Usage: /isilive qdebug [on|off|status|clear|tail [n]]",
  })
end

local function HandleBindCheck(printFn)
  local action1 = GetBindingAction("CTRL-F9", true)
  local action2 = GetBindingAction("CTRL-ALT-F9", true)
  local action3 = GetBindingAction("ALT-CTRL-F9", true)
  printFn("CTRL-F9 => " .. (action1 and action1 ~= "" and action1 or "<none>"))
  printFn("CTRL-ALT-F9 => " .. (action2 and action2 ~= "" and action2 or "<none>"))
  printFn("ALT-CTRL-F9 => " .. (action3 and action3 ~= "" and action3 or "<none>"))
end

local function TryHandleTestCommands(ctx, L, state, cmd)
  if cmd == "test" then
    ctx.toggleStandardTestMode()
    return true
  end

  if cmd == "testall" then
    if state.isStopped then
      ctx.printFn(L.ERR_STOPPED_TEST)
      return true
    end
    if state.isPaused then
      ctx.printFn(L.ERR_PAUSED_TEST)
      return true
    end
    ctx.enterFullDummyPreview()
    return true
  end

  return false
end

local function TryHandleStateCommands(ctx, L, state, cmd)
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
    return true
  end

  if cmd == "pause" then
    if state.isStopped then
      ctx.printFn(L.ERR_STOPPED_USE_START)
      return true
    end
    ctx.setState({
      isPaused = true,
      isTestMode = false,
      isTestAllMode = false,
    })
    ctx.setMainFrameVisible(false)
    ctx.updateLeaderButtons()
    ctx.printFn(L.PAUSED)
    return true
  end

  if cmd == "resume" then
    if state.isStopped then
      ctx.printFn(L.ERR_STOPPED_USE_START)
      return true
    end
    ctx.setState({
      isPaused = false,
      isTestMode = false,
      isTestAllMode = false,
    })
    ctx.updateLeaderButtons()
    ctx.printFn(L.RESUMED)
    ctx.triggerGroupRosterUpdate()
    return true
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
    return true
  end

  return false
end

local function TryHandleInfoCommands(ctx, L, cmd)
  if cmd == "lead" then
    ctx.printFn(ctx.isPlayerLeader() and L.LEAD_STATUS_YES or L.LEAD_STATUS_NO)
    return true
  end

  if cmd:find("^lang") == 1 then
    local arg = cmd:match("^lang%s+(%S+)$")
    if arg == "en" or arg == "de" or arg == "enus" or arg == "dede" then
      ctx.setLanguage(arg)
    else
      ctx.printFn(L.LANG_USAGE)
    end
    return true
  end

  return false
end

local function TryHandleUtilityCommands(ctx, cmd)
  if cmd == "tptest" then
    ctx.forceTeleportTestTarget()
    return true
  end

  if cmd == "tpdebug" then
    ctx.printTeleportDebug()
    return true
  end

  if cmd == "log" or cmd:find("^log%s+") == 1 then
    HandleLogCommand(ctx, cmd)
    return true
  end

  if cmd == "qdebug" or cmd:find("^qdebug%s+") == 1 then
    HandleQDebugCommand(ctx, cmd)
    return true
  end

  if cmd == "bindcheck" then
    HandleBindCheck(ctx.printFn)
    return true
  end

  return false
end

local function ExecuteSlashCommand(ctx, msg)
  local L = ctx.getL() or {}
  local state = ctx.getState() or {}
  local cmd = string.lower(strtrim(msg or ""))

  if TryHandleTestCommands(ctx, L, state, cmd) then
    return
  end
  if TryHandleStateCommands(ctx, L, state, cmd) then
    return
  end
  if TryHandleInfoCommands(ctx, L, cmd) then
    return
  end
  if TryHandleUtilityCommands(ctx, cmd) then
    return
  end

  PrintHelp(ctx.printFn, L)
end

function Commands.RegisterSlashCommands(opts)
  local deps = BuildDeps(opts)

  SLASH_ISILIVE1 = "/isilive"
  SLASH_ISILIVE2 = "/isk"
  SlashCmdList["ISILIVE"] = function(msg)
    ExecuteSlashCommand(deps, msg)
  end
end
