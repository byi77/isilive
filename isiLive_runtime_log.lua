local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeLog = {}
addonTable.RuntimeLog = RuntimeLog
local logBuffer = assert(addonTable.LogBuffer, "isiLive: LogBuffer module missing")
local EnsureStorage = logBuffer.EnsureSavedTable("runtimeLog")

function RuntimeLog.CreateController(opts)
  opts = opts or {}

  local getTimestamp = opts.getTimestamp
    or function()
      return date and date("%H:%M:%S") or tostring(GetTime and GetTime() or 0)
    end

  local maxEntries = tonumber(opts.maxEntries) or 800
  if maxEntries < 1 then
    maxEntries = 1
  end

  assert(type(getTimestamp) == "function", "isiLive: RuntimeLog requires getTimestamp")

  local controller = {}

  function controller.EnsureStorage()
    return EnsureStorage()
  end

  function controller.SetEnabled(enabled)
    if not IsiLiveDB then
      IsiLiveDB = {}
    end
    IsiLiveDB.runtimeLogEnabled = enabled and true or false
  end

  function controller.IsEnabled()
    return IsiLiveDB and IsiLiveDB.runtimeLogEnabled == true
  end

  function controller.AppendLog(message)
    logBuffer.Append(EnsureStorage(), getTimestamp(), message, maxEntries)
  end

  function controller.Log(message)
    if not controller.IsEnabled() then
      return
    end
    controller.AppendLog(message)
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
