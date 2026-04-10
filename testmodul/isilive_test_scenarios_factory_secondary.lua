local function FindTicker(tickers, interval)
  for _, ticker in ipairs(tickers or {}) do
    if ticker.interval == interval then
      return ticker
    end
  end
  return nil
end

local function BuildFactorySecondaryTestContext(state, initial, addon)
  local ctx = {
    modules = {
      contextHelpers = {
        GetUnitServerLanguage = function()
          return "en"
        end,
      },
      locale = {
        ResolveLocaleTag = function(tag)
          return tag
        end,
      },
      testMode = {
        CreateController = function(_opts)
          return {
            EnterFullDummyPreview = function() end,
            ExitTestMode = function() end,
            ToggleStandardTestMode = function() end,
            RefreshActivePreview = function()
              return false
            end,
          }
        end,
      },
      configBuilders = {
        BuildTestModeControllerOpts = function(opts)
          return opts
        end,
      },
      bindings = {
        CreateController = function(_opts)
          return {
            ApplyHotkeyBindings = function()
              state.bindingApplyCalls = (state.bindingApplyCalls or 0) + 1
            end,
            StartBindingWatchdog = function() end,
            GetPendingBindingApply = function()
              return false
            end,
          }
        end,
      },
      cdTracker = {
        CreateController = function(opts)
          state.cdTrackerOpts = opts
          return {
            Scan = function()
              state.cdScans = (state.cdScans or 0) + 1
            end,
            GetBResInfo = function()
              return nil
            end,
            GetLustInfo = function()
              return nil
            end,
            SetDemoData = function() end,
            ClearDemoData = function() end,
          }
        end,
      },
      sync = {
        SetPlayerKickInfo = function(name, realm, onCooldown, cooldownRemain, capturedAt, hasKick)
          state.lastSetKickInfo = {
            name = name,
            realm = realm,
            onCooldown = onCooldown,
            cooldownRemain = cooldownRemain,
            capturedAt = capturedAt,
            hasKick = hasKick,
          }
        end,
        SendKick = function(opts)
          table.insert(state.sentKick, {
            hasKick = opts.hasKick,
            onCooldown = opts.onCooldown,
            cooldownRemain = opts.cooldownRemain,
            force = opts.force,
          })
        end,
        ClearPlayerKickInfo = function(name, realm)
          state.clearKickInfoCalls = (state.clearKickInfoCalls or 0) + 1
          state.lastClearedKickInfo = {
            name = name,
            realm = realm,
          }
          return true
        end,
      },
    },
    runtimeState = {
      GetRuntimeFlags = function()
        return {
          isStopped = false,
          isPaused = false,
          isTestMode = false,
          isTestAllMode = false,
        }
      end,
      PatchRuntimeFlags = function() end,
      ClearLatestQueueTarget = function() end,
      IsReadyCheckActive = function()
        return initial.readyCheckActive == true
      end,
      HasReadyCheckHold = function()
        return initial.readyCheckHold == true
      end,
    },
    addonTable = addon,
    locales = {
      enUS = {
        LANG_SET_EN = "Language set",
      },
    },
    L = {
      LANG_SET_EN = "Language set",
    },
    GetL = function()
      return {
        LANG_SET_EN = "Language set",
      }
    end,
    GetUnitNameAndRealm = function(unit)
      if unit == "player" and state.playerExists == true then
        return state.playerName, state.playerRealm
      end
      return nil, nil
    end,
    GetRealmInfoLib = function()
      return nil
    end,
    GetLanguageTooltipMarkup = function()
      return ""
    end,
    BuildDummyRoster = function()
      return {}
    end,
    SetRoster = function(roster)
      state.roster = roster
    end,
    SetMainFrameVisible = function(_visible) end,
    UpdateUI = function()
      state.uiUpdates = (state.uiUpdates or 0) + 1
    end,
    UpdateLeaderButtons = function() end,
    ShowCenterNotice = function() end,
    ResetInspectAll = function() end,
    CaptureRioBaselineSnapshot = function() end,
    ClearRioBaselineSnapshot = function() end,
    EnableRioDeltaDisplay = function() end,
    UpdateMPlusTeleportButton = function()
      state.teleportButtonUpdates = (state.teleportButtonUpdates or 0) + 1
    end,
    SetCenterNoticeVisible = function() end,
    inviteHint = {
      frame = {
        Hide = function() end,
      },
    },
    TriggerGroupRosterUpdate = function() end,
    ToggleMainFrameVisibility = function() end,
    ApplyLocalizationToUI = function() end,
    inspectController = {
      EnqueueInspect = function() end,
    },
    GetRoster = function()
      return state.roster
    end,
    ResolveStatusTargetMapID = function()
      return initial.targetMapID
    end,
    ClearLatestQueueTarget = function()
      state.latestQueueTargetClears = (state.latestQueueTargetClears or 0) + 1
    end,
    mainFrame = {
      IsShown = function()
        return state.mainFrameShown == true
      end,
    },
    rosterPanelController = {
      RefreshCdTracker = function()
        state.cdRefreshes = (state.cdRefreshes or 0) + 1
      end,
      RefreshReadyCheckState = function()
        state.readyCheckRefreshes = (state.readyCheckRefreshes or 0) + 1
      end,
      RefreshKickColumn = function()
        state.kickRefreshes = (state.kickRefreshes or 0) + 1
      end,
      SetCdController = function(ctrl)
        state.cdController = ctrl
      end,
    },
    IsRaidGroup = function()
      return state.isRaidGroup == true
    end,
  }

  ctx.ApplyHotkeyBindings = function()
    if ctx.bindingController and type(ctx.bindingController.ApplyHotkeyBindings) == "function" then
      ctx.bindingController.ApplyHotkeyBindings()
    end
  end

  return ctx
end

local function BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, initial)
  initial = initial or {}

  local state = {
    time = tonumber(initial.time) or 0,
    mainFrameShown = initial.mainFrameShown == true,
    isRaidGroup = initial.isRaidGroup == true,
    playerExists = initial.playerExists ~= false,
    playerName = initial.playerName or "Player",
    playerRealm = initial.playerRealm or "Realm",
    mplusTimerData = initial.mplusTimerData,
    sentKick = {},
    tickers = {},
    createdFrames = {},
    roster = initial.roster or {
      player = { name = "Player", realm = "Realm" },
    },
  }

  local kickInfo = initial.kickInfo
    or {
      availabilityResolved = true,
      spellID = 6552,
      hasKick = true,
      onCooldown = false,
      cooldownRemain = 0,
    }
  if kickInfo.availabilityResolved == nil then
    kickInfo.availabilityResolved = true
  end

  WithGlobals({
    GetTime = function()
      return state.time
    end,
    UnitExists = function(unit)
      if unit == "player" then
        return state.playerExists == true
      end
      if unit == "pet" then
        return initial.petExists == true
      end
      return false
    end,
    UnitName = function(unit)
      if unit == "player" and state.playerExists == true then
        return state.playerName
      end
      return nil
    end,
    GetRealmName = function()
      return state.playerRealm
    end,
    IsiLiveDB = {},
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return initial.activeChallengeMapID
      end,
    },
    C_Map = {
      GetBestMapForUnit = function(unit)
        state.playerMapLookupCalls = (state.playerMapLookupCalls or 0) + 1
        if type(initial.onGetBestMapForUnit) == "function" then
          return initial.onGetBestMapForUnit(unit, state)
        end
        if unit == "player" and state.playerExists == true then
          return initial.playerMapID
        end
        return nil
      end,
    },
    CreateFrame = function()
      local frame = {
        scripts = {},
        registeredEvents = {},
        registeredUnitEvents = {},
      }

      function frame:RegisterEvent(event)
        self.registeredEvents[event] = true
      end

      function frame:RegisterUnitEvent(event, ...)
        self.registeredUnitEvents[event] = { ... }
      end

      function frame:SetScript(name, fn)
        self.scripts[name] = fn
      end

      table.insert(state.createdFrames, frame)
      return frame
    end,
    C_Timer = {
      NewTicker = function(interval, callback)
        local ticker = {
          interval = interval,
          callback = callback,
          cancelled = false,
        }

        function ticker:Cancel()
          self.cancelled = true
        end

        table.insert(state.tickers, ticker)
        return ticker
      end,
      After = function(_seconds, callback)
        state.afterCallbacks = state.afterCallbacks or {}
        table.insert(state.afterCallbacks, callback)
      end,
    },
  }, function()
    local addon = LoadAddonModules({ "isiLive_factory_controllers.lua" }, {
      _FactoryInternal = {},
      KickTracker = {
        CreateController = function(opts)
          state.kickTrackerOpts = opts
          local function CacheCooldown()
            state.kickCacheCalls = (state.kickCacheCalls or 0) + 1
            local success = initial.kickCacheSuccess ~= false
            if type(initial.onKickCacheCooldown) == "function" then
              success = initial.onKickCacheCooldown(kickInfo, state) ~= false
            end
            if
              success
              and initial.fireKickCooldownChangedOnCache == true
              and state.kickTrackerOpts
              and type(state.kickTrackerOpts.onCooldownChanged) == "function"
            then
              state.kickCooldownChangedCallbacks = (state.kickCooldownChangedCallbacks or 0) + 1
              state.kickTrackerOpts.onCooldownChanged(kickInfo.onCooldown, kickInfo.cooldownRemain, kickInfo.spellID)
            end
            return success
          end
          return {
            OnCast = function(unit, spellID)
              state.kickOnCastCalls = (state.kickOnCastCalls or 0) + 1
              state.lastKickCast = {
                unit = unit,
                spellID = spellID,
              }
              local observedKick = true
              if type(initial.onKickCast) == "function" then
                observedKick = initial.onKickCast(kickInfo, state, unit, spellID) == true
              end
              if observedKick then
                kickInfo.availabilityResolved = true
                kickInfo.hasKick = true
              end
              if
                observedKick
                and initial.fireKickCooldownChangedOnCast == true
                and state.kickTrackerOpts
                and type(state.kickTrackerOpts.onCooldownChanged) == "function"
              then
                state.kickOnCastCooldownChangedCallbacks = (state.kickOnCastCooldownChangedCallbacks or 0) + 1
                state.kickTrackerOpts.onCooldownChanged(kickInfo.onCooldown, kickInfo.cooldownRemain, kickInfo.spellID)
              end
              return observedKick
            end,
            CacheCooldown = CacheCooldown,
            ResolveKickState = function()
              state.kickResolveCalls = (state.kickResolveCalls or 0) + 1
              local exactCooldownKnown = CacheCooldown()
              if type(initial.resolveKickState) == "function" then
                local overrideExactStateKnown = initial.resolveKickState(kickInfo, state)
                if overrideExactStateKnown ~= nil then
                  exactCooldownKnown = overrideExactStateKnown == true
                end
              elseif type(initial.resolveKickSpellID) == "function" then
                kickInfo.spellID = initial.resolveKickSpellID(kickInfo, state)
                if kickInfo.spellID == nil then
                  kickInfo.availabilityResolved = true
                  kickInfo.hasKick = false
                  kickInfo.onCooldown = false
                  kickInfo.cooldownRemain = 0
                else
                  kickInfo.availabilityResolved = true
                  kickInfo.hasKick = true
                end
              end

              return {
                spellID = kickInfo.spellID,
                hasKick = kickInfo.hasKick == true,
                availabilityResolved = kickInfo.availabilityResolved == true,
                onCooldown = kickInfo.onCooldown == true,
                cooldownRemain = kickInfo.cooldownRemain,
                exactCooldownKnown = kickInfo.availabilityResolved == true
                  and kickInfo.hasKick == true
                  and exactCooldownKnown == true,
              }
            end,
            Scan = function()
              state.kickScans = (state.kickScans or 0) + 1
            end,
            GetKickInfo = function()
              return {
                availabilityResolved = kickInfo.availabilityResolved == true,
                spellID = kickInfo.spellID,
                hasKick = kickInfo.hasKick,
                onCooldown = kickInfo.onCooldown,
                cooldownRemain = kickInfo.cooldownRemain,
              }
            end,
          }
        end,
      },
      MplusTimer = {
        GetTimerData = function()
          return state.mplusTimerData
        end,
      },
    })

    local ctx = BuildFactorySecondaryTestContext(state, initial, addon)
    addon._FactoryInternal.InitializeFactorySecondaryControllers(ctx)
    state.ctx = ctx
  end)

  return state
end

local function RegisterFactorySecondaryVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Factory hidden CD ticker skips polling while frame is hidden", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = false,
      mplusTimerData = {
        running = true,
      },
    })

    local ticker = FindTicker(state.tickers, 1.0)
    Assert.NotNil(ticker, "secondary controller init must register the CD tracker ticker")

    ticker.callback()

    Assert.Equal(state.cdScans or 0, 0, "hidden CD ticker must not keep polling the CD tracker")
    Assert.Equal(state.cdRefreshes or 0, 0, "hidden CD ticker must not refresh the CD row")
    Assert.Equal(state.readyCheckRefreshes or 0, 0, "hidden CD ticker must not refresh ready-check rows")
    Assert.Equal(state.uiUpdates or 0, 0, "hidden CD ticker must not rerender the UI for active timers")
  end)

  test("Factory hidden explicit CD refresh keeps pre-rendered state current", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = false,
      readyCheckActive = true,
      mplusTimerData = {
        running = true,
      },
    })

    state.ctx.UpdateCdTracker()

    Assert.Equal(state.cdScans or 0, 1, "event-driven hidden CD refresh must still scan the CD tracker")
    Assert.Equal(state.cdRefreshes or 0, 1, "event-driven hidden CD refresh must still pre-render the CD row")
    Assert.Equal(state.readyCheckRefreshes or 0, 1, "event-driven hidden CD refresh must keep ready-check rows current")
    Assert.Equal(state.uiUpdates or 0, 1, "event-driven hidden CD refresh must keep the timer display current")
  end)

  test("Factory hidden kick ticker keeps syncing while frame is hidden", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = false,
      kickInfo = {
        spellID = 6552,
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
      },
    })

    local ticker = FindTicker(state.tickers, 0.5)
    Assert.NotNil(ticker, "secondary controller init must register the kick ticker")

    ticker.callback()

    Assert.Equal(state.kickScans or 0, 1, "hidden kick ticker must still scan the local kick state")
    Assert.Equal(#state.sentKick, 1, "hidden kick ticker must keep syncing kick state for peers")
    Assert.NotNil(state.lastSetKickInfo, "hidden kick ticker must still update the local kick sync cache")
    Assert.Equal(state.kickRefreshes or 0, 0, "hidden kick ticker must avoid polling-driven UI refreshes")
  end)

  test("Factory target-dungeon entry check skips player map lookup when player unit is missing", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      playerExists = false,
      targetMapID = 2662,
      onGetBestMapForUnit = function()
        error("GetBestMapForUnit must not run when player unit is missing")
      end,
    })

    state.ctx.CheckIfEnteredTargetDungeon()

    Assert.Equal(
      state.playerMapLookupCalls or 0,
      0,
      "target-dungeon check must skip player map lookup for missing units"
    )
    Assert.Equal(
      state.latestQueueTargetClears or 0,
      0,
      "target-dungeon check must not clear the queue target without an exact player map"
    )
    Assert.Equal(
      state.teleportButtonUpdates or 0,
      0,
      "target-dungeon check must not refresh teleport UI without an exact player map"
    )
  end)

  test("Factory kick sync cache uses cached player identity when player unit is missing", function()
    local kickInfo = {
      availabilityResolved = true,
      spellID = 6552,
      hasKick = true,
      onCooldown = false,
      cooldownRemain = 0,
    }
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      kickInfo = kickInfo,
    })

    local ticker = FindTicker(state.tickers, 0.5)
    Assert.NotNil(ticker, "secondary controller init must register the kick ticker")
    if type(ticker) ~= "table" or type(ticker.callback) ~= "function" then
      return
    end

    ticker.callback()
    Assert.NotNil(state.lastSetKickInfo, "initial kick sync should populate the local kick cache")

    state.playerExists = false
    kickInfo.availabilityResolved = false

    local sent = state.ctx.SendOwnKickState()

    Assert.False(sent, "unresolved kick state must stay unsent while player unit is missing")
    Assert.Equal(
      state.clearKickInfoCalls or 0,
      1,
      "cached player identity must still clear stale local kick sync state when UnitExists is false"
    )
    Assert.Equal(state.lastClearedKickInfo.name, "Player", "cached player name must be reused for stale kick cleanup")
    Assert.Equal(state.lastClearedKickInfo.realm, "Realm", "cached player realm must be reused for stale kick cleanup")
  end)

  test("Factory raid kick tracker suppresses sync until raid ends and then recovers", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
      isRaidGroup = true,
      kickInfo = {
        spellID = 6552,
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
      },
    })

    local ticker = FindTicker(state.tickers, 0.5)
    Assert.NotNil(ticker, "secondary controller init must register the kick ticker")
    local castFrame = state.createdFrames[1]
    Assert.NotNil(castFrame, "kick tracker init must create a dedicated cast frame")
    Assert.NotNil(castFrame.scripts.OnEvent, "kick cast frame must register an OnEvent handler")

    ticker.callback()
    castFrame.scripts.OnEvent(castFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 6552)

    Assert.Equal(#state.sentKick, 0, "raid mode must suppress outgoing kick sync")
    Assert.Nil(state.lastSetKickInfo, "raid mode must not mutate the local kick sync cache")
    Assert.Equal(state.kickOnCastCalls or 0, 0, "raid mode must ignore dedicated kick cast events")
    Assert.Equal(state.kickRefreshes or 0, 0, "raid mode must not refresh the kick column")

    state.isRaidGroup = false
    ticker.callback()

    Assert.Equal(state.kickResolveCalls or 0, 1, "kick tracker must recover spell resolution after leaving raid")
    Assert.Equal(state.kickCacheCalls or 0, 1, "kick tracker must refresh cooldown data after leaving raid")
    Assert.Equal(#state.sentKick, 1, "kick tracker must resume syncing once raid hard-off ends")
    Assert.NotNil(state.lastSetKickInfo, "kick tracker must restore the local kick sync cache after raid exit")
    Assert.Equal(state.kickRefreshes or 0, 1, "visible raid exit recovery must refresh the kick column once")
  end)

  test("Factory explicit kick sync reply uses recovered cooldown state instead of stale ready state", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = false,
      isRaidGroup = true,
      kickInfo = {
        spellID = 6552,
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
      },
      onKickCacheCooldown = function(info)
        info.onCooldown = true
        info.cooldownRemain = 11
      end,
    })

    local sentInRaid = state.ctx.SendOwnKickState()
    Assert.False(sentInRaid, "explicit kick sync replies must stay suppressed while raid hard-off is active")
    Assert.Equal(#state.sentKick, 0, "raid hard-off must suppress explicit kick sync replies")

    state.isRaidGroup = false
    local sentAfterRaid = state.ctx.SendOwnKickState()

    Assert.True(sentAfterRaid, "first explicit kick sync reply after raid exit must succeed")
    Assert.Equal(
      state.kickResolveCalls or 0,
      1,
      "post-raid explicit reply must recover spell resolution before sending"
    )
    Assert.Equal(
      state.kickCacheCalls or 0,
      1,
      "post-raid explicit reply must refresh exact cooldown state before sending"
    )
    Assert.Equal(#state.sentKick, 1, "post-raid explicit reply must emit exactly one kick sync packet")
    Assert.True(state.sentKick[1].onCooldown, "post-raid explicit reply must send the recovered active cooldown state")
    Assert.Equal(
      state.sentKick[1].cooldownRemain,
      11,
      "post-raid explicit reply must send the recovered cooldown remain"
    )
  end)

  test("Factory post-raid kick reply stays unresolved until exact recovery succeeds", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
      isRaidGroup = true,
      kickInfo = {
        spellID = 6552,
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
      },
      onKickCacheCooldown = function()
        return false
      end,
    })

    local ticker = FindTicker(state.tickers, 0.5)
    Assert.NotNil(ticker, "secondary controller init must register the kick ticker")
    if type(ticker) ~= "table" or type(ticker.callback) ~= "function" then
      return
    end

    ticker.callback()

    Assert.Equal(state.clearKickInfoCalls or 0, 1, "raid suppression must clear stale local kick sync state")
    Assert.Equal(#state.sentKick, 0, "raid suppression must not send kick sync")

    state.isRaidGroup = false
    local sentAfterRaid = state.ctx.SendOwnKickState()

    Assert.False(sentAfterRaid, "post-raid explicit kick reply must stay unresolved when exact recovery fails")
    Assert.Equal(state.kickResolveCalls or 0, 1, "post-raid unresolved reply must still attempt exact recovery")
    Assert.Equal(state.kickCacheCalls or 0, 1, "post-raid unresolved reply must check exact cooldown data once")
    Assert.Equal(#state.sentKick, 0, "post-raid unresolved reply must not send stale kick data")
    Assert.Equal(state.kickScans or 0, 0, "post-raid unresolved reply must not resume periodic kick scans yet")
    Assert.Equal(
      state.clearKickInfoCalls or 0,
      2,
      "failed post-raid recovery must keep the local kick state unresolved"
    )
    Assert.Equal(state.kickRefreshes or 0, 1, "visible unresolved recovery must refresh the kick column once")
  end)
end

local function RegisterFactorySecondaryKickRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Factory post-raid kick recovery sends exact no-kick state when spell is unavailable", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
      isRaidGroup = true,
      kickInfo = {
        spellID = 6552,
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
      },
      resolveKickSpellID = function()
        return nil
      end,
    })

    local ticker = FindTicker(state.tickers, 0.5)
    Assert.NotNil(ticker, "secondary controller init must register the kick ticker")
    if type(ticker) ~= "table" or type(ticker.callback) ~= "function" then
      return
    end

    ticker.callback()
    state.isRaidGroup = false

    local sentAfterRaid = state.ctx.SendOwnKickState()

    Assert.True(sentAfterRaid, "exact no-kick recovery after raid must complete immediately")
    Assert.Equal(state.kickResolveCalls or 0, 1, "post-raid no-kick recovery must resolve the tracked spell once")
    Assert.Equal(#state.sentKick, 1, "post-raid no-kick recovery must emit one clearing kick sync packet")
    Assert.False(state.sentKick[1].hasKick, "post-raid no-kick recovery must send hasKick=false")
    Assert.NotNil(state.lastSetKickInfo, "post-raid no-kick recovery must update the local kick cache")
    Assert.False(state.lastSetKickInfo.hasKick, "local kick cache must store the exact no-kick state")
  end)

  test("Factory post-raid unresolved kick availability does not invent a no-kick state", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
      isRaidGroup = true,
      kickInfo = {
        availabilityResolved = true,
        spellID = 6552,
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
      },
      resolveKickState = function(info)
        info.availabilityResolved = false
        info.spellID = nil
        info.hasKick = false
        info.onCooldown = false
        info.cooldownRemain = 0
        return false
      end,
    })

    local ticker = FindTicker(state.tickers, 0.5)
    Assert.NotNil(ticker, "secondary controller init must register the kick ticker")
    if type(ticker) ~= "table" or type(ticker.callback) ~= "function" then
      return
    end

    ticker.callback()
    state.isRaidGroup = false

    local sentAfterRaid = state.ctx.SendOwnKickState()

    Assert.False(sentAfterRaid, "post-raid unresolved kick availability must stay unsent")
    Assert.Equal(#state.sentKick, 0, "unresolved post-raid kick availability must not invent a no-kick sync packet")
    Assert.Nil(state.lastSetKickInfo, "unresolved post-raid kick availability must not repopulate the local kick cache")
    Assert.Equal(
      state.clearKickInfoCalls or 0,
      2,
      "unresolved post-raid kick availability must keep the local kick sync cache cleared"
    )
  end)

  test("Factory post-raid kick recovery emits exactly one sync after exact cooldown change", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
      isRaidGroup = true,
      kickInfo = {
        spellID = 6552,
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
      },
      fireKickCooldownChangedOnCache = true,
      onKickCacheCooldown = function(info)
        info.onCooldown = true
        info.cooldownRemain = 12
      end,
    })

    local ticker = FindTicker(state.tickers, 0.5)
    Assert.NotNil(ticker, "secondary controller init must register the kick ticker")
    if type(ticker) ~= "table" or type(ticker.callback) ~= "function" then
      return
    end

    ticker.callback()

    state.isRaidGroup = false
    local sentAfterRaid = state.ctx.SendOwnKickState()

    Assert.True(sentAfterRaid, "post-raid recovery must succeed once exact cooldown data is available")
    Assert.Equal(
      state.kickCooldownChangedCallbacks or 0,
      1,
      "exact recovery may report one internal cooldown change while rebuilding the local kick state"
    )
    Assert.Equal(#state.sentKick, 1, "post-raid recovery must emit exactly one outgoing kick sync packet")
    Assert.Equal(state.kickRefreshes or 0, 1, "visible post-raid recovery must refresh the kick column exactly once")
    Assert.True(state.sentKick[1].onCooldown, "the single recovered kick sync packet must carry the active cooldown")
    Assert.Equal(
      state.sentKick[1].cooldownRemain,
      12,
      "the recovered kick sync packet must use the exact cooldown remain"
    )
  end)

  test("Factory post-raid unrelated cast keeps kick state unresolved until the tracked kick is observed", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
      isRaidGroup = true,
      kickInfo = {
        spellID = 6552,
        hasKick = true,
        onCooldown = false,
        cooldownRemain = 0,
      },
      onKickCacheCooldown = function()
        return false
      end,
      onKickCast = function(info, _state, _unit, spellID)
        if spellID ~= 6552 then
          return false
        end
        info.onCooldown = true
        info.cooldownRemain = 15
        return true
      end,
      fireKickCooldownChangedOnCast = true,
    })

    local ticker = FindTicker(state.tickers, 0.5)
    Assert.NotNil(ticker, "secondary controller init must register the kick ticker")
    local castFrame = state.createdFrames[1]
    Assert.NotNil(castFrame, "kick tracker init must create a dedicated cast frame")
    Assert.NotNil(castFrame.scripts.OnEvent, "kick cast frame must register an OnEvent handler")

    ticker.callback()
    state.isRaidGroup = false

    castFrame.scripts.OnEvent(castFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 133)
    Assert.Equal(state.kickOnCastCalls or 0, 1, "post-raid unrelated casts must still reach the kick tracker")
    Assert.Equal(#state.sentKick, 0, "unrelated post-raid casts must not resume stale kick sync")
    Assert.Equal(
      state.kickOnCastCooldownChangedCallbacks or 0,
      0,
      "unrelated post-raid casts must not fire the kick cooldown changed callback"
    )

    ticker.callback()
    Assert.Equal(
      state.kickResolveCalls or 0,
      1,
      "ticker must still attempt exact recovery while state stays unresolved"
    )
    Assert.Equal(#state.sentKick, 0, "unresolved post-raid state must stay unsent after unrelated casts")

    castFrame.scripts.OnEvent(castFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", nil, 6552)
    Assert.Equal(
      state.kickOnCastCooldownChangedCallbacks or 0,
      1,
      "the first tracked post-raid kick cast must raise one local cooldown change callback"
    )
    Assert.Equal(#state.sentKick, 1, "the first tracked post-raid kick cast must restore kick sync immediately")
    Assert.True(state.sentKick[1].onCooldown, "the restored kick sync packet must carry the observed active cooldown")
    Assert.Equal(
      state.sentKick[1].cooldownRemain,
      15,
      "the restored kick sync packet must carry the observed cooldown remain"
    )
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterFactorySecondaryVisibilityTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterFactorySecondaryKickRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
end
