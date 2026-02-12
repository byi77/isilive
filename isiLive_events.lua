local addonName, addonTable = ...

addonTable = addonTable or {}

local Events = {}
addonTable.Events = Events

function Events.CreateGate(config)
    config = config or {}
    local dispatch = config.dispatch or function(...) end
    local isStopped = config.isStopped or function() return false end
    local isPaused = config.isPaused or function() return false end
    local isTestMode = config.isTestMode or function() return false end
    local allowWhenHidden = config.allowWhenHidden or {}
    local shouldAllowWhenHidden = config.shouldAllowWhenHidden or function(...) return false end

    return function(frame, event, ...)
        if isStopped() and event ~= "ADDON_LOADED" then return end
        if isPaused() and event ~= "ADDON_LOADED" then return end
        if isTestMode() and event ~= "ADDON_LOADED" then return end

        if not frame:IsShown() and not allowWhenHidden[event] and not shouldAllowWhenHidden(frame, event, ...) then
            return
        end

        dispatch(frame, event, ...)
    end
end
