local _, addonTable = ...

addonTable = addonTable or {}

local Refresh = {}
addonTable.Refresh = Refresh

function Refresh.CreateController(opts)
  opts = opts or {}
  local isStopped = opts.isStopped or function()
    return false
  end
  local isPaused = opts.isPaused or function()
    return false
  end
  local isInGroup = opts.isInGroup or function()
    return false
  end
  local isRosterEmpty = opts.isRosterEmpty or function()
    return false
  end
  local triggerGroupRosterUpdate = opts.triggerGroupRosterUpdate or function() end
  local forceRefreshSyncState = opts.forceRefreshSyncState or function() end
  local sendIsiLiveHello = opts.sendIsiLiveHello or function(_force) end
  local sendOwnKeySnapshot = opts.sendOwnKeySnapshot or function(_force) end
  local queueForceRefreshData = opts.queueForceRefreshData or function() end
  local updateUI = opts.updateUI or function() end
  local refreshLocalPlayerKey = opts.refreshLocalPlayerKey or function()
    return false
  end
  local getActiveChallengeMapID = opts.getActiveChallengeMapID or function()
    return nil
  end
  local getTime = opts.getTime or function()
    if type(GetTime) == "function" then
      return GetTime()
    end
    return nil
  end
  local refreshDebounceSeconds = tonumber(opts.refreshDebounceSeconds) or 0
  if refreshDebounceSeconds < 0 then
    refreshDebounceSeconds = 0
  end
  local lastRefreshAt = nil

  local controller = {}

  function controller.RunFullRefresh()
    if isStopped() or isPaused() or getActiveChallengeMapID() then
      return false
    end

    local now = tonumber(getTime())
    if now and refreshDebounceSeconds > 0 and lastRefreshAt and (now - lastRefreshAt) < refreshDebounceSeconds then
      return false
    end
    if now then
      lastRefreshAt = now
    end

    if isInGroup() and isRosterEmpty() then
      triggerGroupRosterUpdate()
    end

    forceRefreshSyncState()
    sendIsiLiveHello(true)
    sendOwnKeySnapshot(true)
    queueForceRefreshData()
    updateUI()
    return true
  end

  function controller.HandleOwnedKeyRefresh()
    local changed = refreshLocalPlayerKey()
    if changed then
      updateUI()
    end
    sendOwnKeySnapshot(false)
    return changed
  end

  return controller
end
