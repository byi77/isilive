local _, addonTable = ...

addonTable = addonTable or {}

local Commands = {}
addonTable.Commands = Commands

function Commands.RegisterSlashCommands(opts)
  opts = opts or {}
  local printFn = opts.printFn or print
  local getL = opts.getL or function()
    return {}
  end
  local getState = opts.getState or function()
    return {}
  end
  local setState = opts.setState or function(_patch) end
  local triggerGroupRosterUpdate = opts.triggerGroupRosterUpdate or function() end

  local toggleStandardTestMode = opts.toggleStandardTestMode or function() end
  local enterFullDummyPreview = opts.enterFullDummyPreview or function() end
  local setMainFrameVisible = opts.setMainFrameVisible or function(_visible) end
  local updateLeaderButtons = opts.updateLeaderButtons or function() end
  local isPlayerLeader = opts.isPlayerLeader or function()
    return false
  end
  local setLanguage = opts.setLanguage or function(_language) end
  local forceTeleportTestTarget = opts.forceTeleportTestTarget or function() end
  local printTeleportDebug = opts.printTeleportDebug or function() end
  local setQueueDebugEnabled = opts.setQueueDebugEnabled or function(_enabled) end
  local getQueueDebugEnabled = opts.getQueueDebugEnabled or function()
    return false
  end
  local clearQueueDebugLog = opts.clearQueueDebugLog or function() end
  local getQueueDebugLogCount = opts.getQueueDebugLogCount or function()
    return 0
  end
  local getQueueDebugLogTail = opts.getQueueDebugLogTail or function(_limit)
    return {}
  end

  SLASH_ISILIVE1 = "/isilive"
  SlashCmdList["ISILIVE"] = function(msg)
    local L = getL() or {}
    local state = getState() or {}
    local cmd = string.lower(strtrim(msg or ""))

    if cmd == "test" then
      toggleStandardTestMode()
    elseif cmd == "testall" then
      if state.isStopped then
        printFn(L.ERR_STOPPED_TEST)
        return
      end
      if state.isPaused then
        printFn(L.ERR_PAUSED_TEST)
        return
      end
      enterFullDummyPreview()
    elseif cmd == "stop" then
      setState({
        isStopped = true,
        isPaused = false,
        isTestMode = false,
        isTestAllMode = false,
        wasGroupLeader = nil,
      })
      setMainFrameVisible(false)
      updateLeaderButtons()
      printFn(L.STOPPED)
    elseif cmd == "pause" then
      if state.isStopped then
        printFn(L.ERR_STOPPED_USE_START)
        return
      end
      setState({
        isPaused = true,
        isTestMode = false,
        isTestAllMode = false,
      })
      setMainFrameVisible(false)
      updateLeaderButtons()
      printFn(L.PAUSED)
    elseif cmd == "resume" then
      if state.isStopped then
        printFn(L.ERR_STOPPED_USE_START)
        return
      end
      setState({
        isPaused = false,
        isTestMode = false,
        isTestAllMode = false,
      })
      updateLeaderButtons()
      printFn(L.RESUMED)
      triggerGroupRosterUpdate()
    elseif cmd == "start" then
      setState({
        isStopped = false,
        isPaused = false,
        isTestMode = false,
        isTestAllMode = false,
      })
      updateLeaderButtons()
      printFn(L.STARTED)
      triggerGroupRosterUpdate()
    elseif cmd == "lead" then
      if isPlayerLeader() then
        printFn(L.LEAD_STATUS_YES)
      else
        printFn(L.LEAD_STATUS_NO)
      end
    elseif cmd:find("^lang") == 1 then
      local arg = cmd:match("^lang%s+(%S+)$")
      if arg == "en" or arg == "de" or arg == "enus" or arg == "dede" then
        setLanguage(arg)
      else
        printFn(L.LANG_USAGE)
      end
    elseif cmd == "tptest" then
      forceTeleportTestTarget()
    elseif cmd == "tpdebug" then
      printTeleportDebug()
    elseif cmd == "qdebug" or cmd:find("^qdebug%s+") == 1 then
      local arg, numText = cmd:match("^qdebug%s+(%S+)%s*(%d*)$")
      if not arg or arg == "status" then
        printFn(
          "Queue debug: "
            .. (getQueueDebugEnabled() and "ON" or "OFF")
            .. " | entries: "
            .. tostring(getQueueDebugLogCount())
        )
      elseif arg == "on" or arg == "1" or arg == "true" then
        setQueueDebugEnabled(true)
        printFn("Queue debug: ON")
      elseif arg == "off" or arg == "0" or arg == "false" then
        setQueueDebugEnabled(false)
        printFn("Queue debug: OFF")
      elseif arg == "clear" then
        clearQueueDebugLog()
        printFn("Queue debug log: cleared")
      elseif arg == "tail" or arg == "dump" then
        local limit = tonumber(numText) or 20
        if limit < 1 then
          limit = 1
        elseif limit > 100 then
          limit = 100
        end
        local lines = getQueueDebugLogTail(limit)
        printFn("Queue debug tail: " .. tostring(#lines) .. "/" .. tostring(getQueueDebugLogCount()) .. " entries")
        for _, line in ipairs(lines) do
          printFn(tostring(line))
        end
      else
        printFn("Usage: /isilive qdebug [on|off|status|clear|tail [n]]")
      end
    elseif cmd == "bindcheck" then
      local action1 = GetBindingAction("CTRL-F9", true)
      local action2 = GetBindingAction("CTRL-ALT-F9", true)
      local action3 = GetBindingAction("ALT-CTRL-F9", true)
      printFn("CTRL-F9 => " .. (action1 and action1 ~= "" and action1 or "<none>"))
      printFn("CTRL-ALT-F9 => " .. (action2 and action2 ~= "" and action2 or "<none>"))
      printFn("ALT-CTRL-F9 => " .. (action3 and action3 ~= "" and action3 or "<none>"))
    else
      printFn(L.HELP_HEADER)
      printFn(L.HELP_LEAD)
      printFn(L.HELP_TEST)
      printFn(L.HELP_TESTALL)
      printFn(L.HELP_TPTEST)
      printFn(L.HELP_TPDEBUG)
      printFn(L.HELP_BINDCHECK)
      printFn(L.HELP_LANG)
      printFn(L.HELP_PAUSE)
      printFn(L.HELP_RESUME)
      printFn(L.HELP_STOP)
      printFn(L.HELP_START)
    end
  end
end
