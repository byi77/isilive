local _, addonTable = ...

addonTable = addonTable or {}

local Events = {}
addonTable.Events = Events

local unpackFn = rawget(table, "unpack")
if type(unpackFn) ~= "function" then
  unpackFn = unpack
end

function Events.CreateGate(config)
  config = config or {}
  local dispatch = config.dispatch or function(_frame, _event, ...) end -- luacheck: ignore 212
  local isStopped = config.isStopped or function()
    return false
  end
  local isPaused = config.isPaused or function()
    return false
  end
  local isTestMode = config.isTestMode or function()
    return false
  end
  local isInCombat = config.isInCombat or function()
    return false
  end
  local allowWhenHidden = config.allowWhenHidden or {}
  local shouldAllowWhenHidden = config.shouldAllowWhenHidden
    or function(_frame, _event, ...) -- luacheck: ignore 212
      return false
    end
  -- Optional callback that decides "is the addon UI considered visible?".
  -- When the gate is bound to a frame that is not the visible UI frame (e.g.
  -- a hidden event-dispatcher frame), falling back to `frame:IsShown()` would
  -- always return true and skip the hidden-suppression branch. Callers can
  -- pass an explicit `isShown` (typically `mainFrame:IsShown()`) to decouple
  -- visibility gating from the dispatch frame's own shown state.
  local isShown = type(config.isShown) == "function" and config.isShown or nil
  local allowInCombat = config.allowInCombat or {}
  -- shouldAllowInCombat: extension point for callers that want to allow
  -- individual events even during combat. No current caller uses this;
  -- the fallback always returns false.
  local shouldAllowInCombat = config.shouldAllowInCombat
    or function(_frame, _event, ...) -- luacheck: ignore 212
      return false
    end
  local allowInTestMode = config.allowInTestMode or {
    ADDON_LOADED = true,
  }
  local onDispatchError = type(config.onDispatchError) == "function" and config.onDispatchError or nil

  -- The event gate sits in front of high-frequency combat events. Keep one
  -- reusable argument slot per re-entrancy depth so protected dispatch does
  -- not allocate an args table and two closures for every event.
  local dispatchDepth = 0
  local dispatchSlots = {}

  local function BuildDispatchSlot()
    local slot = {
      args = {},
      argCount = 0,
      previousArgCount = 0,
    }
    slot.invoke = function()
      return dispatch(slot.frame, slot.event, unpackFn(slot.args, 1, slot.argCount))
    end
    return slot
  end

  local function CaptureDispatchTraceback(runtimeErr)
    local msg = tostring(runtimeErr)
    local debugLib = rawget(_G, "debug")
    if type(debugLib) == "table" and type(debugLib.traceback) == "function" then
      return debugLib.traceback(msg, 2)
    end
    return msg
  end

  local function DispatchSafe(frame, event, ...)
    if not onDispatchError then
      dispatch(frame, event, ...)
      return
    end

    dispatchDepth = dispatchDepth + 1
    local slot = dispatchSlots[dispatchDepth]
    if not slot then
      slot = BuildDispatchSlot()
      dispatchSlots[dispatchDepth] = slot
    end

    local argCount = select("#", ...)
    slot.frame = frame
    slot.event = event
    slot.argCount = argCount
    for index = 1, argCount do
      slot.args[index] = select(index, ...)
    end

    local ok, err = xpcall(slot.invoke, CaptureDispatchTraceback)
    local clearCount = math.max(slot.previousArgCount, argCount)
    for index = 1, clearCount do
      slot.args[index] = nil
    end
    slot.previousArgCount = argCount
    slot.frame = nil
    slot.event = nil
    dispatchDepth = dispatchDepth - 1
    if not ok then
      local _ = pcall(onDispatchError, frame, event, err)
    end
  end

  return function(frame, event, ...)
    if isStopped() and event ~= "ADDON_LOADED" then
      return
    end
    if isPaused() and event ~= "ADDON_LOADED" then
      return
    end
    if isTestMode() and not allowInTestMode[event] then
      return
    end

    if isInCombat() and not (allowInCombat[event] or shouldAllowInCombat(frame, event, ...)) then
      return
    end

    local shown
    if isShown then
      shown = isShown() and true or false
    else
      shown = frame:IsShown()
    end
    if not shown and not (allowWhenHidden[event] or shouldAllowWhenHidden(frame, event, ...)) then
      return
    end

    -- Midnight marks the fourth LFG application-status payload
    -- (`groupName`) as kstringLfgListChat. It is not authoritative for dungeon
    -- detection and must not enter the reusable protected-dispatch slots:
    -- retaining restricted strings in a long-lived table can poison later
    -- reads from that slot in the live client. The queue/LFG pipeline only
    -- requires the stable search-result ID and the new status; listing details
    -- are resolved from C_LFGList by that ID.
    if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
      local searchResultID, newStatus = ...
      DispatchSafe(frame, event, searchResultID, newStatus)
      return
    end

    DispatchSafe(frame, event, ...)
  end
end
