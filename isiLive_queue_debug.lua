local _, addonTable = ...

addonTable = addonTable or {}

local QueueDebug = {}
addonTable.QueueDebug = QueueDebug
local logBuffer = assert(addonTable.LogBuffer, "isiLive: LogBuffer module missing")
local EnsureStorage = logBuffer.EnsureSavedTable("queueDebugLog")

function QueueDebug.CreateController(opts)
  opts = opts or {}

  local printFn = opts.printFn or print
  local queueSetDebugEnabled = opts.queueSetDebugEnabled or function(_enabled) end
  local queueIsDebugEnabled = opts.queueIsDebugEnabled or function()
    return nil
  end
  local getTimestamp = opts.getTimestamp
    or function()
      return date and date("%H:%M:%S") or tostring(GetTime and GetTime() or 0)
    end

  local maxEntries = tonumber(opts.maxEntries) or 400
  if maxEntries < 1 then
    maxEntries = 1
  end

  assert(type(printFn) == "function", "isiLive: QueueDebug requires printFn")
  assert(type(queueSetDebugEnabled) == "function", "isiLive: QueueDebug requires queueSetDebugEnabled")
  assert(type(queueIsDebugEnabled) == "function", "isiLive: QueueDebug requires queueIsDebugEnabled")
  assert(type(getTimestamp) == "function", "isiLive: QueueDebug requires getTimestamp")

  local controller = {}

  function controller.EnsureStorage()
    return EnsureStorage()
  end

  function controller.AppendLog(message)
    logBuffer.Append(EnsureStorage(), getTimestamp(), message, maxEntries)
  end

  function controller.Log(message)
    printFn(message)
    controller.AppendLog(message)
  end

  function controller.SetEnabled(enabled)
    local normalized = enabled and true or false
    queueSetDebugEnabled(normalized)
    if not IsiLiveDB then
      IsiLiveDB = {}
    end
    IsiLiveDB.queueDebug = normalized
  end

  function controller.IsEnabled()
    local moduleState = queueIsDebugEnabled()
    if moduleState ~= nil then
      return moduleState == true
    end
    return IsiLiveDB and IsiLiveDB.queueDebug == true
  end

  function controller.ClearLog()
    wipe(EnsureStorage())
  end

  function controller.GetLogCount()
    return #EnsureStorage()
  end

  function controller.GetLogTail(limit)
    return logBuffer.GetTail(EnsureStorage(), limit, 20, 100)
  end

  return controller
end
