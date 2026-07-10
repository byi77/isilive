local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeLog = {}
addonTable.RuntimeLog = RuntimeLog
local logBuffer = assert(addonTable.LogBuffer, "isiLive: LogBuffer module missing")
local EnsureStorage = logBuffer.EnsureSavedTable("runtimeLog")
local DEFAULT_LEVEL = "normal"
local DEEP_LEVEL = "deep"

local function NormalizeLevel(level)
  local text = tostring(level or DEFAULT_LEVEL):lower()
  if text == DEEP_LEVEL then
    return DEEP_LEVEL
  end
  return DEFAULT_LEVEL
end

local function NormalizeRuntimeMessage(message)
  local text = tostring(message or "")
  local tag, firstToken, rest = text:match("^(%[[%w_%-]+%])%s+(%S+)%s*(.*)$")
  if not tag or not firstToken or firstToken:find("=", 1, true) then
    return text
  end
  if rest and rest ~= "" then
    return string.format("%s event=%s %s", tag, firstToken, rest)
  end
  return string.format("%s event=%s", tag, firstToken)
end

function RuntimeLog.CreateController(opts)
  opts = opts or {}

  local getTimestamp = opts.getTimestamp
    or function()
      local getTimeFn = rawget(_G, "GetTime")
      if type(getTimeFn) == "function" then
        return string.format("%.3f", tonumber(getTimeFn()) or 0)
      end
      local dateFn = rawget(_G, "date")
      return type(dateFn) == "function" and dateFn("%H:%M:%S") or "0.000"
    end

  local getRawTime = opts.getRawTime
    or function()
      local getTimeFn = rawget(_G, "GetTime")
      if type(getTimeFn) == "function" then
        return tonumber(getTimeFn())
      end
      return nil
    end

  local maxEntries = tonumber(opts.maxEntries) or 800
  if maxEntries < 1 then
    maxEntries = 1
  end
  local buildSessionHeader = type(opts.buildSessionHeader) == "function" and opts.buildSessionHeader or nil

  assert(type(getTimestamp) == "function", "isiLive: RuntimeLog requires getTimestamp")

  local controller = {}
  local sequence = 0
  local lastRawTime = nil
  local watchFn = nil

  local function GetStorage()
    return logBuffer.Normalize(EnsureStorage(), maxEntries)
  end

  function controller.EnsureStorage()
    return GetStorage()
  end

  function controller.SetEnabled(enabled)
    -- SavedVariables are restored before ADDON_LOADED and SetEnabled only runs
    -- from the /isilive log slash command (post-load). Lazy-creating
    -- IsiLiveDB pre-load would race the SavedVariables restore and clobber
    -- other settings.
    local db = rawget(_G, "IsiLiveDB")
    local nextEnabled = enabled and true or false
    local wasEnabled = false
    if type(db) == "table" then
      wasEnabled = db.runtimeLogEnabled == true
      db.runtimeLogEnabled = nextEnabled
    end
    if nextEnabled and not wasEnabled and buildSessionHeader then
      controller.AppendLog("[RUNTIME] session_start " .. tostring(buildSessionHeader()))
    end
  end

  function controller.IsEnabled()
    local db = rawget(_G, "IsiLiveDB")
    return db ~= nil and db.runtimeLogEnabled == true
  end

  function controller.SetLevel(level)
    -- See SetEnabled above for the no-op-on-nil rationale.
    local db = rawget(_G, "IsiLiveDB")
    if type(db) == "table" then
      db.runtimeLogLevel = NormalizeLevel(level)
    end
  end

  function controller.GetLevel()
    local db = rawget(_G, "IsiLiveDB")
    return NormalizeLevel(db and db.runtimeLogLevel or DEFAULT_LEVEL)
  end

  function controller.IsLevelEnabled(level)
    if not controller.IsEnabled() then
      return false
    end
    local normalizedLevel = NormalizeLevel(level)
    return normalizedLevel == DEFAULT_LEVEL or controller.GetLevel() == DEEP_LEVEL
  end

  function controller.AppendLog(message)
    sequence = sequence + 1
    local now = type(getRawTime) == "function" and tonumber(getRawTime()) or nil
    local deltaStr = ""
    if now and lastRawTime then
      deltaStr = string.format(" +%.3f", math.max(0, now - lastRawTime))
    end
    lastRawTime = now or lastRawTime
    local entry =
      string.format("seq=%d t=%s%s %s", sequence, tostring(getTimestamp()), deltaStr, NormalizeRuntimeMessage(message))
    logBuffer.Append(GetStorage(), "", entry, maxEntries)
    if watchFn then
      watchFn(entry)
    end
  end

  function controller.Log(message)
    if not controller.IsLevelEnabled(DEFAULT_LEVEL) then
      return
    end
    controller.AppendLog(message)
  end

  function controller.LogAt(level, message)
    if not controller.IsLevelEnabled(level) then
      return
    end
    controller.AppendLog(message)
  end

  function controller.Logf(formatText, ...)
    if not controller.IsLevelEnabled(DEFAULT_LEVEL) then
      return
    end
    controller.AppendLog(string.format(tostring(formatText or ""), ...))
  end

  function controller.LogfAt(level, formatText, ...)
    if not controller.IsLevelEnabled(level) then
      return
    end
    controller.AppendLog(string.format(tostring(formatText or ""), ...))
  end

  function controller.TraceAt(level, buildMessage)
    if not controller.IsLevelEnabled(level) then
      return
    end
    if type(buildMessage) ~= "function" then
      controller.AppendLog(buildMessage)
      return
    end
    local ok, message = pcall(buildMessage)
    if ok then
      controller.AppendLog(message)
    else
      controller.AppendLog("[LOG_ERROR] " .. tostring(message))
    end
  end

  function controller.Trace(buildMessage)
    controller.TraceAt(DEFAULT_LEVEL, buildMessage)
  end

  function controller.LogDeep(message)
    controller.LogAt(DEEP_LEVEL, message)
  end

  function controller.LogfDeep(formatText, ...)
    controller.LogfAt(DEEP_LEVEL, formatText, ...)
  end

  function controller.TraceDeep(buildMessage)
    controller.TraceAt(DEEP_LEVEL, buildMessage)
  end

  function controller.SetWatchFn(fn)
    watchFn = type(fn) == "function" and fn or nil
  end

  function controller.IsWatchActive()
    return watchFn ~= nil
  end

  function controller.GetLogTailFiltered(limit, filter)
    local clampedLimit = math.max(1, math.min(tonumber(limit) or 20, 100))
    local filterText = type(filter) == "string" and filter ~= "" and filter:upper() or nil
    if not filterText then
      return controller.GetLogTail(clampedLimit)
    end
    local fetchCount = maxEntries
    local all = logBuffer.GetTail(GetStorage(), fetchCount, fetchCount, fetchCount)
    local filtered = {}
    for _, line in ipairs(all) do
      if tostring(line):upper():find(filterText, 1, true) then
        filtered[#filtered + 1] = line
      end
    end
    local result = {}
    local start = math.max(1, #filtered - clampedLimit + 1)
    for i = start, #filtered do
      result[#result + 1] = filtered[i]
    end
    return result, #filtered
  end

  function controller.ClearLog()
    local wipeFn = rawget(_G, "wipe")
    local storage = GetStorage()
    if type(wipeFn) == "function" then
      wipeFn(storage)
    else
      for key in pairs(storage) do
        storage[key] = nil
      end
    end
    sequence = 0
    lastRawTime = nil
  end

  function controller.GetLogCount()
    return logBuffer.Count(GetStorage())
  end

  function controller.GetLogTail(limit)
    return logBuffer.GetTail(GetStorage(), limit, 20, 100)
  end

  return controller
end
