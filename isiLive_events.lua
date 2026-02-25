local _, addonTable = ...

addonTable = addonTable or {}

local Events = {}
addonTable.Events = Events

function Events.CreateGate(config)
  config = config or {}
  local dispatch = config.dispatch or function(_frame, _event, ...)
    local _ = ...
  end
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
    or function(_frame, _event, ...)
      local _ = ...
      return false
    end
  local allowInCombat = config.allowInCombat or {}
  local shouldAllowInCombat = config.shouldAllowInCombat
    or function(_frame, _event, ...)
      local _ = ...
      return false
    end
  local allowInTestMode = config.allowInTestMode or {
    ADDON_LOADED = true,
  }
  local onDispatchError = type(config.onDispatchError) == "function" and config.onDispatchError or nil

  local function DispatchSafe(frame, event, ...)
    if not onDispatchError then
      dispatch(frame, event, ...)
      return
    end

    local args = { ... }
    local ok, err = xpcall(function()
      dispatch(frame, event, unpack(args))
    end, function(runtimeErr)
      local msg = tostring(runtimeErr)
      if type(debug) == "table" and type(debug.traceback) == "function" then
        return debug.traceback(msg, 2)
      end
      return msg
    end)
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

    if isInCombat() and not allowInCombat[event] and not shouldAllowInCombat(frame, event, ...) then
      return
    end

    if not frame:IsShown() and not allowWhenHidden[event] and not shouldAllowWhenHidden(frame, event, ...) then
      return
    end

    DispatchSafe(frame, event, ...)
  end
end
