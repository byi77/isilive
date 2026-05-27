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
    getMainFrameLocked = opts.getMainFrameLocked or function()
      return true
    end,
    setMainFrameLocked = opts.setMainFrameLocked or function(_locked) end,
    resetMainFramePosition = opts.resetMainFramePosition or function() end,
    updateLeaderButtons = opts.updateLeaderButtons or function() end,
    isPlayerLeader = opts.isPlayerLeader or function()
      return false
    end,
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
    setRuntimeLogLevel = opts.setRuntimeLogLevel or function(_level) end,
    getRuntimeLogLevel = opts.getRuntimeLogLevel or function()
      return "normal"
    end,
    clearRuntimeLog = opts.clearRuntimeLog or function() end,
    getRuntimeLogCount = opts.getRuntimeLogCount or function()
      return 0
    end,
    getRuntimeLogTail = opts.getRuntimeLogTail or function(_limit)
      return {}
    end,
    getRuntimeLogTailFiltered = type(opts.getRuntimeLogTailFiltered) == "function" and opts.getRuntimeLogTailFiltered
      or nil,
    setRuntimeLogWatch = type(opts.setRuntimeLogWatch) == "function" and opts.setRuntimeLogWatch or nil,
    getRuntimeLogWatchActive = type(opts.getRuntimeLogWatchActive) == "function" and opts.getRuntimeLogWatchActive
      or nil,
    openTraceChatFrame = type(opts.openTraceChatFrame) == "function" and opts.openTraceChatFrame or nil,
    closeTraceChatFrame = type(opts.closeTraceChatFrame) == "function" and opts.closeTraceChatFrame or nil,
    isTraceChatFrameOpen = type(opts.isTraceChatFrameOpen) == "function" and opts.isTraceChatFrameOpen or nil,
    addTraceChatFrameMessage = type(opts.addTraceChatFrameMessage) == "function" and opts.addTraceChatFrameMessage
      or nil,
    resetDB = opts.resetDB or function() end,
    toggleNameplateTestMode = type(opts.toggleNameplateTestMode) == "function" and opts.toggleNameplateTestMode
      or function()
        return false
      end,
    dumpNameplateState = type(opts.dumpNameplateState) == "function" and opts.dumpNameplateState or function() end,
    openSettings = type(opts.openSettings) == "function" and opts.openSettings or function()
      return false
    end,
    logRuntimeTrace = type(opts.logRuntimeTrace) == "function" and opts.logRuntimeTrace or nil,
    logRuntimeTracef = type(opts.logRuntimeTracef) == "function" and opts.logRuntimeTracef or nil,
    -- Always-on Lua-error capture (see core/isiLive_error_log.lua).
    getErrorLogTail = type(opts.getErrorLogTail) == "function" and opts.getErrorLogTail or function(_limit)
      return {}
    end,
    getErrorLogCount = type(opts.getErrorLogCount) == "function" and opts.getErrorLogCount or function()
      return 0
    end,
    getErrorLogMaxEntries = type(opts.getErrorLogMaxEntries) == "function" and opts.getErrorLogMaxEntries or function()
      return 0
    end,
    getErrorLogInstalled = type(opts.getErrorLogInstalled) == "function" and opts.getErrorLogInstalled or function()
      return false
    end,
    clearErrorLog = type(opts.clearErrorLog) == "function" and opts.clearErrorLog or function() end,
  }
end

-- Ordered list mirrors the command handlers in TryHandle*Commands below.
-- Keep in sync when adding a new slash command.
local HELP_KEYS = {
  "HELP_HEADER",
  "HELP_HELP",
  "HELP_LOCK",
  "HELP_UNLOCK",
  "HELP_RESETUI",
  "HELP_SETTINGS",
  "HELP_ADMIN",
}

local ADMIN_HELP_KEYS = {
  "ADMIN_HEADER",
  "HELP_TESTALL",
  "HELP_LOG",
  "HELP_QDEBUG",
  "HELP_ERRORLOG",
  "HELP_BINDCHECK",
  "HELP_TPTEST",
  "HELP_TPDEBUG",
  "HELP_NPTEST",
  "HELP_NPSTATE",
  "HELP_RESET",
}

local function PrintHelpByKeys(printFn, L, keys)
  for _, key in ipairs(keys) do
    local line = L[key]
    if type(line) == "string" and line ~= "" then
      printFn(line)
    end
  end
end

local function PrintHelp(printFn, L)
  PrintHelpByKeys(printFn, L, HELP_KEYS)
end

local function PrintAdminHelp(printFn, L)
  PrintHelpByKeys(printFn, L, ADMIN_HELP_KEYS)
end

local ARG_ON = { on = true, ["1"] = true, ["true"] = true }
local ARG_OFF = { off = true, ["0"] = true, ["false"] = true }

-- Tiny shim so the slash-command parser can run in unit-test contexts that
-- only stub _G and don't bring the Blizzard `strtrim` global with them. Falls
-- back to a pure-Lua trim when WoW's helper is missing.
local function TrimWhitespace(text)
  local strtrimFn = rawget(_G, "strtrim")
  if type(strtrimFn) == "function" then
    return strtrimFn(text or "")
  end
  return tostring(text or ""):match("^%s*(.-)%s*$") or ""
end

-- Generic handler for debug log sub-commands (shared by "log" and "qdebug").
-- cfg fields: prefix, label, extraOn (table), extraOff (table),
--             getEnabled, setEnabled, getLevel, setLevel, clearLog, getCount,
--             getTail, usageStr
local function HandleDebugLogCommand(ctx, cmd, cfg)
  local arg, restText = cmd:match("^" .. cfg.prefix .. "%s+(%S+)%s*(.-)%s*$")
  if not arg or arg == "status" then
    local levelText = cfg.getLevel and (" | level: " .. tostring(cfg.getLevel())) or ""
    ctx.printFn(
      cfg.label
        .. ": "
        .. (cfg.getEnabled() and "ON" or "OFF")
        .. levelText
        .. " | entries: "
        .. tostring(cfg.getCount())
    )
    return
  end

  if cfg.setLevel and cfg.getLevel and (arg == "level" or arg == "normal" or arg == "deep") then
    local requestedLevel = arg == "level" and tostring(restText or "") or arg
    if requestedLevel == "normal" or requestedLevel == "deep" then
      cfg.setLevel(requestedLevel)
      ctx.printFn(cfg.label .. " level: " .. tostring(cfg.getLevel()))
      return
    end
    ctx.printFn(cfg.label .. " level: " .. tostring(cfg.getLevel()))
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
    local limitStr, tagFilter = (restText or ""):match("^(%S*)%s*(.-)%s*$")
    local limit = tonumber(limitStr) or 20
    if limit < 1 then
      limit = 1
    elseif limit > 100 then
      limit = 100
    end
    local lines, totalFiltered
    if cfg.getFilteredTail and tagFilter and tagFilter ~= "" then
      lines, totalFiltered = cfg.getFilteredTail(limit, tagFilter)
    else
      lines = cfg.getTail(limit)
    end
    local header = cfg.label .. " tail: " .. tostring(#lines)
    if totalFiltered then
      header = header .. "/" .. tostring(totalFiltered) .. " (filter=" .. tagFilter .. ")"
    else
      header = header .. "/" .. tostring(cfg.getCount()) .. " entries"
    end
    ctx.printFn(header)
    for _, line in ipairs(lines) do
      ctx.printFn(tostring(line))
    end
    return
  end

  if arg == "watch" and cfg.setWatchFn then
    if cfg.getWatchActive and cfg.getWatchActive() then
      cfg.setWatchFn(nil)
      if cfg.closeTraceChatFrame then
        cfg.closeTraceChatFrame()
      end
      ctx.printFn(cfg.label .. ": watch OFF")
    else
      local inWatch = false
      local rawPrint = rawget(_G, "print") or print
      local sink
      if cfg.openTraceChatFrame and cfg.addTraceChatFrameMessage then
        cfg.openTraceChatFrame()
        sink = cfg.addTraceChatFrameMessage
        ctx.printFn(cfg.label .. ": watch ON (entries stream to trace chat tab)")
      else
        sink = function(entry)
          rawPrint("[watch] " .. tostring(entry))
        end
        ctx.printFn(cfg.label .. ": watch ON (new entries will be printed live)")
      end
      cfg.setWatchFn(function(entry)
        if inWatch then
          return
        end
        inWatch = true
        local ok, err = pcall(sink, entry)
        inWatch = false
        if not ok then
          rawPrint("isiLive watch sink error: " .. tostring(err))
        end
      end)
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
    getLevel = ctx.getRuntimeLogLevel,
    setLevel = ctx.setRuntimeLogLevel,
    clearLog = ctx.clearRuntimeLog,
    getCount = ctx.getRuntimeLogCount,
    getTail = ctx.getRuntimeLogTail,
    getFilteredTail = ctx.getRuntimeLogTailFiltered,
    setWatchFn = ctx.setRuntimeLogWatch,
    getWatchActive = ctx.getRuntimeLogWatchActive,
    openTraceChatFrame = ctx.openTraceChatFrame,
    closeTraceChatFrame = ctx.closeTraceChatFrame,
    addTraceChatFrameMessage = ctx.addTraceChatFrameMessage,
    usageStr = "Usage: /isilive log [on|off|start|stop|status|level normal|deep|clear|tail [n [TAG]]|watch]",
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

-- /isilive errorlog [N|clear|status]
-- Always-on Lua-error capture (see core/isiLive_error_log.lua). Entries are
-- structured tables (message, fullText, count, firstSeen, lastSeen) so we
-- format them differently from the flat-string runtime/queue logs.
local function HandleErrorLogCommand(ctx, cmd)
  local arg = cmd:match("^errorlog%s+(%S+)") or "tail"

  if arg == "status" then
    local count = ctx.getErrorLogCount and ctx.getErrorLogCount() or 0
    local cap = ctx.getErrorLogMaxEntries and ctx.getErrorLogMaxEntries() or 100
    local installed = ctx.getErrorLogInstalled and ctx.getErrorLogInstalled() or false
    ctx.printFn(
      string.format("Error log: %s | entries: %d / %d", installed and "installed" or "NOT installed", count, cap)
    )
    return
  end

  if arg == "clear" then
    if ctx.clearErrorLog then
      ctx.clearErrorLog()
      ctx.printFn("Error log: cleared")
    end
    return
  end

  -- "tail" or numeric arg: show last N entries (default 10).
  local limit = tonumber(arg) or 10
  if limit < 1 then
    limit = 1
  elseif limit > 100 then
    limit = 100
  end

  local entries = ctx.getErrorLogTail and ctx.getErrorLogTail(limit) or {}
  if #entries == 0 then
    ctx.printFn("Error log: no entries.")
    return
  end

  ctx.printFn(string.format("Error log tail: %d entries", #entries))
  for _, entry in ipairs(entries) do
    if type(entry) == "table" then
      local countSuffix = entry.count and entry.count > 1 and string.format(" (x%d)", entry.count) or ""
      local firstStamp = entry.firstSeenDisplay or tostring(entry.firstSeen or "?")
      local lastStamp = entry.lastSeenDisplay or tostring(entry.lastSeen or "?")
      ctx.printFn(string.format("[%s..%s%s] %s", firstStamp, lastStamp, countSuffix, tostring(entry.message or "")))
      if type(entry.fullText) == "string" and entry.fullText ~= entry.message then
        ctx.printFn("    " .. entry.fullText)
      end
    end
  end
end

local function HandleBindCheck(printFn)
  local getBindingAction = rawget(_G, "GetBindingAction")
  if type(getBindingAction) ~= "function" then
    printFn("GetBindingAction is unavailable; cannot inspect override bindings.")
    return
  end
  local action1 = getBindingAction("CTRL-F9", true)
  local action2 = getBindingAction("CTRL-ALT-F9", true)
  local action3 = getBindingAction("ALT-CTRL-F9", true)
  printFn("CTRL-F9 => " .. (action1 and action1 ~= "" and action1 or "<none>"))
  printFn("CTRL-ALT-F9 => " .. (action2 and action2 ~= "" and action2 or "<none>"))
  printFn("ALT-CTRL-F9 => " .. (action3 and action3 ~= "" and action3 or "<none>"))
end

local function TryHandleTestCommands(ctx, L, state, cmd)
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

local function TryHandleStateCommands()
  return false
end

local function TryHandleLockCommands(ctx, L, cmd)
  if cmd == "lock" then
    ctx.setMainFrameLocked(true)
    ctx.printFn(L.LOCKED)
    return true
  end

  if cmd == "unlock" then
    ctx.setMainFrameLocked(false)
    ctx.printFn(L.UNLOCKED)
    return true
  end

  if cmd == "resetui" then
    ctx.resetMainFramePosition()
    ctx.printFn(L.RESETUI_DONE)
    return true
  end

  return false
end

local function TryHandleInfoCommands()
  return false
end

local function TryHandleUtilityCommands(ctx, cmd)
  if cmd == "settings" then
    ctx.openSettings()
    return true
  end

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

  if cmd == "errorlog" or cmd:find("^errorlog%s+") == 1 then
    HandleErrorLogCommand(ctx, cmd)
    return true
  end

  if cmd == "bindcheck" then
    HandleBindCheck(ctx.printFn)
    return true
  end

  if cmd == "reset" then
    ctx.resetDB()
    return true
  end

  if cmd == "nptest" or cmd:find("^nptest%s+") == 1 then
    local arg = nil
    local space = cmd:find("%s+")
    if space then
      arg = TrimWhitespace(cmd:sub(space + 1))
    end
    local active = ctx.toggleNameplateTestMode(arg)
    if active then
      ctx.printFn("Nameplate test mode ON — target/mouseover any hostile mob to see the fake percent.")
    else
      ctx.printFn("Nameplate test mode OFF.")
    end
    return true
  end

  if cmd == "npstate" or cmd:find("^npstate%s+") == 1 then
    local arg = nil
    local space = cmd:find("%s+")
    if space then
      arg = TrimWhitespace(cmd:sub(space + 1))
    end
    ctx.dumpNameplateState(arg)
    return true
  end

  return false
end

local function ExecuteSlashCommand(ctx, msg)
  local L = ctx.getL() or {}
  local state = ctx.getState() or {}
  local cmd = string.lower(TrimWhitespace(msg))
  if ctx.logRuntimeTracef then
    ctx.logRuntimeTracef("[CMD] execute cmd=%s", tostring(cmd))
  end

  if cmd == "" or cmd == "help" then
    PrintHelp(ctx.printFn, L)
    return
  end

  if cmd == "admin" then
    PrintAdminHelp(ctx.printFn, L)
    return
  end

  if TryHandleTestCommands(ctx, L, state, cmd) then
    return
  end
  if TryHandleStateCommands(ctx, L, state, cmd) then
    return
  end
  if TryHandleLockCommands(ctx, L, cmd) then
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
  SLASH_ISILIVE2 = "/il"
  SlashCmdList["ISILIVE"] = function(msg)
    ExecuteSlashCommand(deps, msg)
  end
end
