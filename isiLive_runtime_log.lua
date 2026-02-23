local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeLog = {}
addonTable.RuntimeLog = RuntimeLog

local function EnsureStorage()
  if not IsiLiveDB then
    IsiLiveDB = {}
  end
  if type(IsiLiveDB.runtimeLog) ~= "table" then
    IsiLiveDB.runtimeLog = {}
  end
  return IsiLiveDB.runtimeLog
end

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
