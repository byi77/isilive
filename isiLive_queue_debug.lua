local _, addonTable = ...

addonTable = addonTable or {}

local QueueDebug = {}
addonTable.QueueDebug = QueueDebug

local function EnsureStorage()
  if not IsiLiveDB then
    IsiLiveDB = {}
  end
  if type(IsiLiveDB.queueDebugLog) ~= "table" then
    IsiLiveDB.queueDebugLog = {}
  end
  return IsiLiveDB.queueDebugLog
end

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
    local logs = EnsureStorage()
    local text = tostring(message or "")
    -- Keep SavedVariables debug logs ASCII-friendly for easier external parsing.
    text = text:gsub("[\128-\255]", "")
    table.insert(logs, string.format("%s %s", tostring(getTimestamp()), text))
    local overflow = #logs - maxEntries
    while overflow > 0 do
      table.remove(logs, 1)
      overflow = overflow - 1
    end
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
    local logs = EnsureStorage()
    local total = #logs
    local count = tonumber(limit) or 20
    if count < 1 then
      count = 1
    elseif count > 100 then
      count = 100
    end
    local startIndex = total - count + 1
    if startIndex < 1 then
      startIndex = 1
    end
    local out = {}
    for i = startIndex, total do
      out[#out + 1] = logs[i]
    end
    return out
  end

  return controller
end
