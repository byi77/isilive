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
  local forceRefreshSyncState = opts.forceRefreshSyncState or function(_refreshOpts) end
  local sendIsiLiveHello = opts.sendIsiLiveHello or function(_force, _source) end
  local sendOwnKeySnapshot = opts.sendOwnKeySnapshot or function(_force, _source) end
  local sendOwnBackgroundSnapshot = opts.sendOwnBackgroundSnapshot or function(_source) end
  local sendRefreshRequest = opts.sendRefreshRequest or function(_force) end
  local queueForceRefreshData = opts.queueForceRefreshData or function() end
  local updateUI = opts.updateUI or function() end
  local isTestMode = opts.isTestMode or function()
    return false
  end
  local isTestAllMode = opts.isTestAllMode or function()
    return false
  end
  local refreshTestModeRoster = opts.refreshTestModeRoster or function()
    return false
  end
  local refreshLocalPlayerKey = opts.refreshLocalPlayerKey or function()
    return false
  end
  local getActiveChallengeMapID = opts.getActiveChallengeMapID or function()
    return nil
  end
  local getTime = opts.getTime
    or function()
      local getTimeFn = rawget(_G, "GetTime")
      if type(getTimeFn) == "function" then
        return getTimeFn()
      end
      return nil
    end
  local refreshDebounceSeconds = tonumber(opts.refreshDebounceSeconds) or 0
  if refreshDebounceSeconds < 0 then
    refreshDebounceSeconds = 0
  end
  local logRuntimeTrace = type(opts.logRuntimeTrace) == "function" and opts.logRuntimeTrace or nil
  local logRuntimeTracef = type(opts.logRuntimeTracef) == "function" and opts.logRuntimeTracef or nil
  local lastRefreshAt = nil
  local pendingPostChallengeSync = false

  local controller = {}

  -- refreshOpts.keepKnownPeers: see KeySync ForceRefreshSyncState (post-run refresh).
  -- refreshOpts.ignoreDebounce: the post-run refresh skips the click debounce
  -- (rule 19 guards the button, not this scheduled caller). A Re-Sync click
  -- shortly after the key ended would otherwise block every post-run attempt,
  -- and rule 4 then keeps the RIO delta off for the whole session.
  function controller.RunFullRefresh(refreshOpts)
    if isStopped() or isPaused() then
      if logRuntimeTracef then
        logRuntimeTracef("[REFRESH] run_full_refresh blocked reason=%s", isStopped() and "stopped" or "paused")
      end
      return false
    end
    local challengeMapID = getActiveChallengeMapID()
    if challengeMapID then
      if logRuntimeTracef then
        logRuntimeTracef(
          "[REFRESH] run_full_refresh blocked reason=challenge_active mapID=%s",
          tostring(challengeMapID)
        )
      end
      return false
    end

    local now = tonumber(getTime())
    local ignoreDebounce = type(refreshOpts) == "table" and refreshOpts.ignoreDebounce == true
    if
      now
      and not ignoreDebounce
      and refreshDebounceSeconds > 0
      and lastRefreshAt
      and (now - lastRefreshAt) < refreshDebounceSeconds
    then
      if logRuntimeTracef then
        logRuntimeTracef(
          "[REFRESH] run_full_refresh blocked reason=debounce remain=%.1f",
          refreshDebounceSeconds - (now - lastRefreshAt)
        )
      end
      return false
    end
    if now then
      lastRefreshAt = now
    end

    if isTestMode() or isTestAllMode() then
      if logRuntimeTrace then
        logRuntimeTrace("[REFRESH] run_full_refresh testmode")
      end
      return refreshTestModeRoster()
    end

    if logRuntimeTracef then
      logRuntimeTracef(
        "[REFRESH] run_full_refresh isInGroup=%s isRosterEmpty=%s",
        tostring(isInGroup()),
        tostring(isRosterEmpty())
      )
    end

    if isInGroup() and isRosterEmpty() then
      triggerGroupRosterUpdate()
    end

    forceRefreshSyncState(refreshOpts)
    sendIsiLiveHello(true, "refresh")
    sendOwnKeySnapshot(true, "refresh")
    sendRefreshRequest(true)
    queueForceRefreshData()
    updateUI()
    return true
  end

  function controller.NotifyPostChallengeSync()
    if logRuntimeTrace then
      logRuntimeTrace("[REFRESH] notify_post_challenge_sync")
    end
    pendingPostChallengeSync = true
  end

  function controller.HandleOwnedKeyRefresh()
    local changed = refreshLocalPlayerKey()
    if logRuntimeTracef then
      logRuntimeTracef(
        "[REFRESH] handle_owned_key_refresh changed=%s pendingPostChallenge=%s",
        tostring(changed),
        tostring(pendingPostChallengeSync)
      )
    end
    if changed then
      updateUI()
    end
    if pendingPostChallengeSync or changed then
      -- "post-challenge" stays for the case that NotifyPostChallengeSync set
      -- the flag earlier. When the trigger is purely "owned key changed mid-
      -- session" we tag the snapshot accordingly so the receiver's trace logs
      -- aren't mislabelled.
      local source = pendingPostChallengeSync and "post-challenge" or "owned-key-changed"
      pendingPostChallengeSync = false
      sendOwnKeySnapshot(true, source)
    else
      sendOwnBackgroundSnapshot("owned-key-refresh")
    end
    return changed
  end

  return controller
end
