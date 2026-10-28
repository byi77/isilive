local _, addonTable = ...

addonTable = addonTable or {}

-- Ingame measuring aid for the performance-audit checklist (todo.md,
-- "Ingame-Pruefliste"). Records C_AddOnProfiler metrics for isiLive into
-- IsiLiveDB.perfMarks so a session can be read back from SavedVariables
-- instead of copied from chat.
--
--   /isilive perf mark NAME    point snapshot (RecentAverageTime covers ~60 frames)
--   /isilive perf start NAME   window, samples RecentAverageTime every 0.5 s
--   /isilive perf stop         ends the window and stores it
--   /isilive perf auto [off]   snapshot of / stop the automatic recording
--   /isilive perf list|reset   show / clear stored entries
--   /isilive perf dev          shows the developer toggle in the settings
--
-- Automatic recording keeps one window per runtime-mode segment
-- (auto-OFF/auto-IDLE/auto-KEY) and counts UPDATE_BINDINGS,
-- SetOverrideBindingClick and (in KEY only) CHAT_MSG_ADDON per segment. A
-- completed key stores "key-end" and, 15 s later, "key-end+15s" with the
-- addon messages received in between (checklist point 7, sync storm).
local PerfProbe = {}
addonTable.PerfProbe = PerfProbe

-- Automatic recording is OFF by default; the developer settings toggle
-- (IsiLiveDB.perfAutoEnabled) turns it on per account. Only starts in the real
-- client, where C_AddOnProfiler exists.
local PERF_AUTO_ENABLED = false
PerfProbe.AUTO_DEFAULT = PERF_AUTO_ENABLED

local MAX_MARKS = 100
local SAMPLE_INTERVAL = 0.5
local AUTO_INTERVAL = 1
local KEY_END_WINDOW = 15
local ISILIVE_PREFIX = "ISILIVE"
local USAGE = "Usage: /isilive perf <mark NAME|start NAME|stop|auto [off]|list|reset|dev>"

local manualWindow = nil
local auto = nil
local eventFrame = nil
local bindingHookInstalled = false
local keyEnd = nil

local function GetDB()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db or nil
end

local function ReadMetric(name)
  local profiler = rawget(_G, "C_AddOnProfiler")
  local enum = rawget(_G, "Enum")
  local metrics = type(enum) == "table" and enum.AddOnProfilerMetric or nil
  if type(profiler) ~= "table" or type(profiler.GetAddOnMetric) ~= "function" or type(metrics) ~= "table" then
    return nil
  end
  if metrics[name] == nil then
    return nil
  end
  local ok, value = pcall(profiler.GetAddOnMetric, "isiLive", metrics[name])
  return ok and tonumber(value) or nil
end

local function ResolveMode()
  local runtimeMode = addonTable.RuntimeMode
  if type(runtimeMode) == "table" and type(runtimeMode.Resolve) == "function" then
    return tostring(runtimeMode.Resolve())
  end
  return "?"
end

local function ReadContext()
  local getNumGroupMembers = rawget(_G, "GetNumGroupMembers")
  local getTime = rawget(_G, "GetTime")
  local dateFn = rawget(_G, "date")
  local getInstanceInfo = rawget(_G, "GetInstanceInfo")
  local entry = {
    stamp = type(dateFn) == "function" and dateFn("%m-%d %H:%M:%S") or nil,
    time = type(getTime) == "function" and getTime() or nil,
    mode = ResolveMode(),
    groupSize = type(getNumGroupMembers) == "function" and getNumGroupMembers() or 0,
  }
  if type(getInstanceInfo) == "function" then
    local ok, instanceName, instanceType, difficultyID = pcall(getInstanceInfo)
    if ok then
      entry.instance = instanceName
      entry.instanceType = instanceType
      entry.difficultyID = difficultyID
    end
  end
  return entry
end

local function GetMarks()
  local db = GetDB()
  if not db then
    return nil
  end
  if type(db.perfMarks) ~= "table" then
    db.perfMarks = {}
  end
  return db.perfMarks
end

local function FormatMs(value)
  return value and string.format("%.3f", value) or "n/a"
end

local function StoreMark(ctx, entry)
  local marks = GetMarks()
  if marks then
    marks[#marks + 1] = entry
    while #marks > MAX_MARKS do
      table.remove(marks, 1)
    end
  end
  if not ctx then
    return
  end
  ctx.printNoLogFn(
    string.format(
      "perf %s [%s %s n=%d] avg=%s ms peak=%s ms >5ms=%s%s",
      entry.name,
      entry.kind,
      entry.mode,
      entry.groupSize,
      FormatMs(entry.avg),
      FormatMs(entry.peak),
      tostring(entry.over5 or "n/a"),
      entry.duration and string.format(" (%.0f s, max %.3f ms)", entry.duration, entry.windowMax or 0) or ""
    )
  )
end

local function NewWindow(name)
  local getTime = rawget(_G, "GetTime")
  return {
    name = name,
    sum = 0,
    count = 0,
    max = 0,
    over5Start = ReadMetric("CountTimeOver5Ms"),
    startTime = type(getTime) == "function" and getTime() or nil,
    counts = {},
  }
end

local function BuildWindowEntry(window)
  local entry = ReadContext()
  entry.kind = "window"
  entry.name = window.name
  entry.samples = window.count
  entry.avg = window.count > 0 and (window.sum / window.count) or ReadMetric("RecentAverageTime")
  entry.windowMax = window.max
  entry.peak = ReadMetric("PeakTime")
  local over5 = ReadMetric("CountTimeOver5Ms")
  entry.over5 = (over5 and window.over5Start) and (over5 - window.over5Start) or over5
  entry.duration = (entry.time and window.startTime) and (entry.time - window.startTime) or nil
  if next(window.counts) ~= nil then
    entry.counts = window.counts
  end
  return entry
end

local function SampleWindow(window)
  local value = ReadMetric("RecentAverageTime")
  if value then
    window.sum = window.sum + value
    window.count = window.count + 1
    if value > window.max then
      window.max = value
    end
  end
end

local function CountEvent(key)
  local window = auto and auto.window
  if window then
    window.counts[key] = (window.counts[key] or 0) + 1
  end
end

-- CHAT_MSG_ADDON is only counted where checklist point 7 needs it (KEY and
-- the key-end window): in a raid other addons send hundreds of messages and
-- the counter itself would show up in the OFF measurement.
local function UpdateAddonMessageRegistration()
  if not eventFrame then
    return
  end
  local wanted = auto ~= nil and (auto.mode == "KEY" or keyEnd ~= nil)
  if wanted and not eventFrame.addonMessagesRegistered then
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame.addonMessagesRegistered = true
  elseif not wanted and eventFrame.addonMessagesRegistered then
    eventFrame:UnregisterEvent("CHAT_MSG_ADDON")
    eventFrame.addonMessagesRegistered = false
  end
end

local function StoreKeyEndMark(name)
  local entry = ReadContext()
  entry.kind = "mark"
  entry.name = name
  entry.avg = ReadMetric("RecentAverageTime")
  entry.peak = ReadMetric("PeakTime")
  entry.over5 = ReadMetric("CountTimeOver5Ms")
  if keyEnd then
    entry.addonMessages = keyEnd.messages
    entry.isiLiveMessages = keyEnd.isiLiveMessages
    entry.over5InWindow = (entry.over5 and keyEnd.over5Start) and (entry.over5 - keyEnd.over5Start) or nil
  end
  StoreMark(nil, entry)
end

local function OnChallengeCompleted()
  local timer = rawget(_G, "C_Timer")
  StoreKeyEndMark("key-end")
  keyEnd = { messages = 0, isiLiveMessages = 0, over5Start = ReadMetric("CountTimeOver5Ms") }
  UpdateAddonMessageRegistration()
  if type(timer) == "table" and type(timer.After) == "function" then
    timer.After(KEY_END_WINDOW, function()
      StoreKeyEndMark("key-end+" .. KEY_END_WINDOW .. "s")
      keyEnd = nil
      UpdateAddonMessageRegistration()
    end)
  end
end

local function OnEvent(_, event, prefix)
  if event == "CHAT_MSG_ADDON" then
    CountEvent("addonMessages")
    if prefix == ISILIVE_PREFIX then
      CountEvent("isiLiveMessages")
    end
    if keyEnd then
      keyEnd.messages = keyEnd.messages + 1
      if prefix == ISILIVE_PREFIX then
        keyEnd.isiLiveMessages = keyEnd.isiLiveMessages + 1
      end
    end
  elseif event == "UPDATE_BINDINGS" then
    CountEvent("updateBindings")
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    OnChallengeCompleted()
  end
end

local function EnsureEventFrame()
  local createFrame = rawget(_G, "CreateFrame")
  if not eventFrame and type(createFrame) == "function" then
    eventFrame = createFrame("Frame")
    eventFrame:SetScript("OnEvent", OnEvent)
  end
  if eventFrame then
    eventFrame:RegisterEvent("UPDATE_BINDINGS")
    eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
  end
  local hook = rawget(_G, "hooksecurefunc")
  if not bindingHookInstalled and type(hook) == "function" and rawget(_G, "SetOverrideBindingClick") then
    -- Counts every addon's calls; checklist point 8 compares it with UPDATE_BINDINGS.
    hook("SetOverrideBindingClick", function()
      CountEvent("setOverrideBindingClick")
    end)
    bindingHookInstalled = true
  end
end

local function TickAuto()
  if not auto then
    return
  end
  local mode = ResolveMode()
  if mode ~= auto.mode then
    StoreMark(nil, BuildWindowEntry(auto.window))
    auto.mode = mode
    auto.window = NewWindow("auto-" .. mode)
    UpdateAddonMessageRegistration()
  end
  SampleWindow(auto.window)
end

function PerfProbe.IsAutoEnabled()
  local db = GetDB()
  if db and db.perfAutoEnabled ~= nil then
    return db.perfAutoEnabled == true
  end
  return PERF_AUTO_ENABLED
end

function PerfProbe.IsAutoRunning()
  return auto ~= nil
end

function PerfProbe.IsDevToolsEnabled()
  local db = GetDB()
  return db ~= nil and db.devTools == true
end

function PerfProbe.StartAuto()
  local timer = rawget(_G, "C_Timer")
  if auto or not PerfProbe.IsAutoEnabled() or rawget(_G, "C_AddOnProfiler") == nil then
    return false
  end
  if type(timer) ~= "table" or type(timer.NewTicker) ~= "function" then
    return false
  end
  local mode = ResolveMode()
  auto = { mode = mode, window = NewWindow("auto-" .. mode) }
  auto.ticker = timer.NewTicker(AUTO_INTERVAL, TickAuto)
  EnsureEventFrame()
  UpdateAddonMessageRegistration()
  return true
end

-- Returns the stored final segment entry, or nil when nothing was running.
function PerfProbe.StopAuto()
  local running = auto
  auto = nil
  if not running then
    return nil
  end
  if running.ticker and type(running.ticker.Cancel) == "function" then
    running.ticker:Cancel()
  end
  if eventFrame then
    eventFrame:UnregisterAllEvents()
    eventFrame.addonMessagesRegistered = false
  end
  local entry = BuildWindowEntry(running.window)
  StoreMark(nil, entry)
  return entry
end

-- Settings toggle: persists the choice and starts/stops immediately.
function PerfProbe.SetAutoEnabled(enabled)
  local db = GetDB()
  if db then
    db.perfAutoEnabled = enabled == true
  end
  if enabled then
    PerfProbe.StartAuto()
  else
    PerfProbe.StopAuto()
  end
end

local function StopManualWindow(ctx)
  local window = manualWindow
  manualWindow = nil
  if not window then
    ctx.printNoLogFn("perf: no window running.")
    return
  end
  if window.ticker and type(window.ticker.Cancel) == "function" then
    window.ticker:Cancel()
  end
  StoreMark(ctx, BuildWindowEntry(window))
end

local function StartManualWindow(ctx, name)
  if manualWindow then
    StopManualWindow(ctx)
  end
  local timer = rawget(_G, "C_Timer")
  local window = NewWindow(name)
  manualWindow = window
  if type(timer) == "table" and type(timer.NewTicker) == "function" then
    window.ticker = timer.NewTicker(SAMPLE_INTERVAL, function()
      SampleWindow(window)
    end)
  end
  ctx.printNoLogFn("perf: window '" .. name .. "' started, end with /isilive perf stop")
end

local function HandleAutoVerb(ctx, arg)
  if arg == "off" then
    local entry = PerfProbe.StopAuto()
    if entry then
      ctx.printNoLogFn("perf: auto recording stopped until /reload")
    else
      ctx.printNoLogFn("perf: auto recording is not running.")
    end
    return
  end
  if not auto then
    ctx.printNoLogFn("perf: auto recording is not running.")
    return
  end
  -- Snapshot the running segment without ending it.
  local entry = BuildWindowEntry(auto.window)
  entry.kind = "auto-snapshot"
  StoreMark(ctx, entry)
end

local function ListMarks(ctx)
  local marks = GetMarks() or {}
  ctx.printNoLogFn(string.format("perf: %d stored entries", #marks))
  for index = math.max(1, #marks - 19), #marks do
    local entry = marks[index]
    ctx.printNoLogFn(
      string.format(
        "%s %s [%s] avg=%s peak=%s",
        tostring(entry.stamp or "?"),
        tostring(entry.name),
        tostring(entry.mode),
        FormatMs(entry.avg),
        FormatMs(entry.peak)
      )
    )
  end
end

function PerfProbe.HandleCommand(ctx, cmd)
  local verb, name = cmd:match("^perf%s+(%S+)%s*(.-)%s*$")
  name = (name and name ~= "") and name or "unnamed"

  if verb == "mark" then
    local entry = ReadContext()
    entry.kind = "mark"
    entry.name = name
    entry.avg = ReadMetric("RecentAverageTime")
    entry.peak = ReadMetric("PeakTime")
    entry.over5 = ReadMetric("CountTimeOver5Ms")
    StoreMark(ctx, entry)
  elseif verb == "start" then
    StartManualWindow(ctx, name)
  elseif verb == "stop" then
    StopManualWindow(ctx)
  elseif verb == "auto" then
    HandleAutoVerb(ctx, name)
  elseif verb == "list" then
    ListMarks(ctx)
  elseif verb == "reset" then
    local db = GetDB()
    if db then
      db.perfMarks = {}
    end
    ctx.printNoLogFn("perf: stored entries cleared")
  elseif verb == "dev" then
    local db = GetDB()
    if db then
      db.devTools = db.devTools ~= true
      ctx.printNoLogFn(
        "perf: developer toggle in settings "
          .. (db.devTools and "shown" or "hidden")
          .. " (/reload if settings were open)"
      )
    end
  else
    ctx.printFn(USAGE)
  end
end
