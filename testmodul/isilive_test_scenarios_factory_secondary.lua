local _, addonTable = ...
addonTable = addonTable or {}

local function FindTicker(tickers, interval)
  for _, ticker in ipairs(tickers or {}) do
    if ticker.interval == interval then
      return ticker
    end
  end
  return nil
end

local function BuildDefaultKickInfo(initial)
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
  return kickInfo
end

local function BuildGlobalsEnv(state)
  return {
    GetTime = function()
      return state.time
    end,
    UnitName = function(unit)
      if unit == "player" then
        return "Player"
      end
      return nil
    end,
    GetRealmName = function()
      return "Realm"
    end,
    IsiLiveDB = state.db,
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
  }
end

local function BuildKickTrackerModule(state, initial, kickInfo)
  return {
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
  }
end

local function BuildControllerContext(state, addon, initial)
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
        CreateController = function(opts)
          state.testModeOpts = opts
          return {
            EnterFullDummyPreview = function()
              if type(opts.setDemoTimerData) == "function" then
                opts.setDemoTimerData()
              end
              if type(opts.setDemoFeatureData) == "function" then
                opts.setDemoFeatureData()
              end
            end,
            ExitTestMode = function()
              if type(opts.clearDemoTimerData) == "function" then
                opts.clearDemoTimerData()
              end
              if type(opts.clearDemoFeatureData) == "function" then
                opts.clearDemoFeatureData()
              end
            end,
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
              return state.lustInfo
            end,
            SetDemoData = function(data)
              state.cdTrackerDemoData = data
            end,
            ClearDemoData = function()
              state.cdTrackerDemoData = nil
              state.cdTrackerDemoCleared = (state.cdTrackerDemoCleared or 0) + 1
            end,
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
      SetLatestQueueState = function(dungeonName, activityID, teleportSpellID, mapID)
        state.latestQueueState = {
          dungeonName = dungeonName,
          activityID = activityID,
          teleportSpellID = teleportSpellID,
          mapID = mapID,
        }
      end,
      ClearLatestQueueTarget = function()
        state.latestQueueState = nil
      end,
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
        INVITE_ACCEPTED_NOTICE_TITLE = "Invite accepted",
        INVITE_ACCEPTED_NOTICE_LABEL_DUNGEON = "Dungeon:",
        INVITE_ACCEPTED_NOTICE_LABEL_GROUP = "Group:",
        INVITE_ACCEPTED_NOTICE_LABEL_ROLE = "Role:",
        PORTAL_NAVIGATOR_TITLE = "Navigator",
        PORTAL_NAVIGATOR_HALF_LEFT = "Half-left",
        PORTAL_NAVIGATOR_LEFT = "Left",
        PORTAL_NAVIGATOR_RIGHT = "Right",
        PORTAL_NAVIGATOR_HALF_RIGHT = "Half-right",
        PORTAL_NAVIGATOR_PIT_OF_SARON = "Pit",
        PORTAL_NAVIGATOR_SKYREACH = "Sky",
        PORTAL_NAVIGATOR_TRIUMVIRATE = "Seat",
        PORTAL_NAVIGATOR_ALGETHAR = "AA",
        ROLE_NAME_DAMAGE = "Damage",
      }
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
    ShowCenterNotice = function(message, durationSeconds, dungeonName, activityID, opts)
      state.centerNotice = {
        message = message,
        durationSeconds = durationSeconds,
        dungeonName = dungeonName,
        activityID = activityID,
        opts = opts,
      }
    end,
    ResetInspectAll = function() end,
    CaptureRioBaselineSnapshot = function() end,
    ClearRioBaselineSnapshot = function() end,
    EnableRioDeltaDisplay = function() end,
    UpdateMPlusTeleportButton = function() end,
    SetCenterNoticeVisible = function() end,
    SetPortalNavigatorVisible = function(visible)
      state.portalNavigatorVisible = visible
    end,
    ShowPortalNavigatorNotice = function(layout)
      state.portalNavigatorLayout = layout
      state.portalNavigatorVisible = true
    end,
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
      return nil
    end,
    ClearLatestQueueTarget = function() end,
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
      RefreshKillTrackRow = function()
        state.killTrackRowRefreshes = (state.killTrackRowRefreshes or 0) + 1
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
    mplusTimerData = initial.mplusTimerData,
    sentKick = {},
    tickers = {},
    createdFrames = {},
    roster = initial.roster or {
      player = { name = "Player", realm = "Realm" },
    },
    db = initial.db or {},
  }

  local kickInfo = BuildDefaultKickInfo(initial)

  WithGlobals(BuildGlobalsEnv(state), function()
    local addon = LoadAddonModules({
      "isiLive_factory_controllers.lua",
      "isiLive_factory_kick_tracker.lua",
    }, {
      _FactoryInternal = {},
      KickTracker = BuildKickTrackerModule(state, initial, kickInfo),
      MplusTimer = {
        GetTimerData = function()
          return state.mplusTimerData
        end,
        SetDemoData = function(data)
          state.mplusDemoData = data
        end,
        ClearDemoData = function()
          state.mplusDemoData = nil
          state.mplusDemoCleared = (state.mplusDemoCleared or 0) + 1
        end,
      },
      KillTrack = {
        SetDemoData = function(data)
          state.killTrackDemoData = data
        end,
        ClearDemoData = function()
          state.killTrackDemoData = nil
          state.killTrackDemoCleared = (state.killTrackDemoCleared or 0) + 1
        end,
        OnUpdate = function(callback)
          state.killTrackCallbacks = state.killTrackCallbacks or {}
          table.insert(state.killTrackCallbacks, callback)
        end,
        SetDebugLogger = function() end,
      },
      MobNameplate = {
        SetEnabled = function(enabled)
          state.mobNameplateEnabled = enabled
        end,
        SetFormat = function(format)
          state.mobNameplateFormat = format
        end,
        SetAppearance = function(appearance)
          state.mobNameplateAppearance = appearance
        end,
        SetTestMode = function(enabled, percent)
          state.mobNameplateTestMode = enabled
          state.mobNameplateTestPercent = percent
        end,
        RefreshAll = function()
          state.mobNameplateRefreshes = (state.mobNameplateRefreshes or 0) + 1
        end,
      },
      MobTooltip = {
        SetEnabled = function(enabled)
          state.mobTooltipEnabled = enabled
        end,
      },
      LFGFlags = {
        SetEnabled = function(enabled)
          state.lfgFlagsEnabled = enabled
        end,
        SetGroupBonusesEnabled = function(enabled)
          state.lfgGroupBonusesEnabled = enabled
        end,
      },
      StatsBox = {
        SetDemoData = function(data)
          state.statsBoxDemoData = data
        end,
        ClearDemoData = function()
          state.statsBoxDemoData = nil
          state.statsBoxDemoCleared = (state.statsBoxDemoCleared or 0) + 1
        end,
        SetEnabled = function(enabled)
          state.statsBoxEnabled = enabled
        end,
        ApplySettings = function()
          state.statsBoxApplySettings = (state.statsBoxApplySettings or 0) + 1
        end,
      },
      SoundUtils = {
        PlayBloodlust = function()
          state.bloodlustSoundCalls = (state.bloodlustSoundCalls or 0) + 1
        end,
      },
    })

    local ctx = BuildControllerContext(state, addon, initial)

    addon._FactoryInternal.InitializeFactorySecondaryControllers(ctx)
    state.ctx = ctx
  end)

  return state
end

addonTable._FactorySecondaryTests = addonTable._FactorySecondaryTests or {}
addonTable._FactorySecondaryTests.BuildFactorySecondaryControllerState = BuildFactorySecondaryControllerState

local function RegisterTestModeDemoDataTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Factory test mode populates timer, cooldown and kill-track demo data", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
    })

    Assert.NotNil(state.testModeOpts, "factory must pass test-mode options into the controller")
    WithGlobals(BuildGlobalsEnv(state), function()
      state.ctx.EnterFullDummyPreview()
    end)

    Assert.NotNil(state.mplusDemoData, "test mode must populate M+ timer demo data")
    Assert.True(state.mplusDemoData.running, "M+ timer demo data must represent a running key")
    Assert.NotNil(state.killTrackDemoData, "test mode must populate bottom M+ forces tracker demo data")
    Assert.True(state.killTrackDemoData.active, "kill-track demo data must be active")
    Assert.Equal(state.killTrackDemoData.percent, 47.34, "kill-track demo percent must match the preview value")
    Assert.NotNil(state.latestQueueState, "test mode must populate a demo target dungeon context")
    Assert.Equal(state.latestQueueState.dungeonName, "Nexus-Point Xenas", "demo target dungeon name must be explicit")
    Assert.Equal(state.latestQueueState.mapID, 559, "demo target dungeon map must match kill-track preview map")

    Assert.NotNil(state.afterCallbacks, "test mode must defer CD tracker demo data until controller creation")
    state.afterCallbacks[1]()
    Assert.NotNil(state.cdTrackerDemoData, "test mode must populate combat cooldown demo data")
    Assert.NotNil(state.statsBoxDemoData, "test mode must populate stats-box demo data")
    Assert.Equal(state.statsBoxDemoData[2].key, "stamina", "stats-box demo data must include stamina")
    Assert.Equal(state.statsBoxDemoData[7].key, "leech", "stats-box demo data must include Leech")
    Assert.Equal(state.statsBoxDemoData[7].percent, 3.27, "stats-box Leech demo percent must be explicit")
    Assert.Equal(state.statsBoxDemoData[8].key, "speed", "stats-box Speed demo row must remain after Leech")
    Assert.Equal(state.statsBoxDemoData[9].key, "durability", "stats-box demo data must include durability")
    Assert.Equal(state.statsBoxDemoData[10].key, "avoidance", "stats-box demo data must include avoidance")
    Assert.True(state.statsBoxEnabled == true, "test mode must enable the stats box surface")
    Assert.True(state.lfgFlagsEnabled == true, "test mode must enable LFG language flags")
    Assert.True(state.lfgGroupBonusesEnabled == true, "test mode must enable LFG group-bonus markers")
    Assert.True(state.mobTooltipEnabled == true, "test mode must enable M+ forces tooltip demo surface")
    Assert.True(state.mobNameplateTestMode == true, "test mode must enable nameplate forces demo mode")
    Assert.Equal(state.mobNameplateTestPercent, "12.34", "nameplate demo percent must be explicit")
    Assert.Nil(state.mobNameplateFormat, "nameplate demo must not override the user's percent format settings")
    Assert.Nil(state.mobNameplateAppearance, "nameplate demo must not override the user's appearance settings")
    Assert.NotNil(state.portalNavigatorLayout, "test mode must show the portal navigator demo")
    Assert.NotNil(state.centerNotice, "test mode must show the accepted-invite center notice demo")
    Assert.Equal(state.centerNotice.dungeonName, "Nexus-Point Xenas", "center notice demo must use the demo target")
    Assert.Equal(state.centerNotice.opts.teleportMapID, 559, "center notice demo must configure a verified map portal")
    Assert.Nil(state.centerNotice.opts.teleportLabel, "center notice demo must omit the redundant teleport header")

    state.ctx.ExitTestMode()
    Assert.Nil(state.mplusDemoData, "test mode exit must clear M+ timer demo data")
    Assert.Nil(state.killTrackDemoData, "test mode exit must clear kill-track demo data")
    Assert.Equal(state.mplusDemoCleared, 1, "M+ timer demo data must be cleared once")
    Assert.Equal(state.killTrackDemoCleared, 1, "kill-track demo data must be cleared once")
    Assert.Nil(state.statsBoxDemoData, "test mode exit must clear stats-box demo data")
    Assert.Equal(state.statsBoxDemoCleared, 1, "stats-box demo data must be cleared once")
    Assert.False(state.mobNameplateTestMode, "test mode exit must disable nameplate forces demo mode")
    Assert.False(state.portalNavigatorVisible, "test mode exit must hide the portal navigator demo")
  end)

  test("Factory test mode does not resize the stats box font setting", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
      db = {
        statsBoxFontSizeOffset = -2,
      },
    })

    WithGlobals(BuildGlobalsEnv(state), function()
      state.ctx.EnterFullDummyPreview()
    end)

    Assert.Equal(state.db.statsBoxFontSizeOffset, -2, "demo mode must not override the stats-box font size")

    state.ctx.ExitTestMode()
    Assert.Equal(state.db.statsBoxFontSizeOffset, -2, "demo exit must preserve the user's stats-box font size")
  end)

  test("Factory test mode temporarily enables notice demo settings", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
      db = {
        acceptedInviteNoticeEnabled = false,
        groupJoinNoticeEnabled = false,
      },
    })

    WithGlobals(BuildGlobalsEnv(state), function()
      state.ctx.EnterFullDummyPreview()
    end)

    Assert.True(state.db.acceptedInviteNoticeEnabled, "demo mode must enable accepted-invite notice preview")
    Assert.True(state.db.groupJoinNoticeEnabled, "demo mode must enable group-join target notice preview")

    WithGlobals(BuildGlobalsEnv(state), function()
      state.ctx.ExitTestMode()
    end)
    Assert.False(state.db.acceptedInviteNoticeEnabled, "demo exit must restore accepted-invite notice setting")
    Assert.False(state.db.groupJoinNoticeEnabled, "demo exit must restore group-join target notice setting")
  end)
end

local function RegisterKillTrackNameplateRefreshTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Factory kill-track updates refresh the kill row and active nameplates", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
    })

    Assert.NotNil(state.killTrackCallbacks, "factory must subscribe to KillTrack updates")
    local callback = Assert.NotNil(state.killTrackCallbacks[1], "KillTrack update callback must be registered")
    callback()

    Assert.Equal(state.killTrackRowRefreshes, 1, "KillTrack update must refresh the lower M+ forces row")
    Assert.Equal(state.mobNameplateRefreshes, 1, "KillTrack update must refresh nameplate remaining-percent text")
  end)
end

local function RegisterPostRaidKickRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
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
    if type(ticker) ~= "table" or type(ticker.callback) ~= "function" then
      return
    end
    Assert.Equal(type(state.ctx.HandleKickTrackerEvent), "function", "kick tracker must expose central event handler")
    if type(state.ctx.HandleKickTrackerEvent) ~= "function" then
      return
    end

    ticker.callback()
    state.isRaidGroup = false

    state.ctx.HandleKickTrackerEvent("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 133)
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

    state.ctx.HandleKickTrackerEvent("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 6552)
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

  test("Factory hidden CD ticker skips polling while frame is hidden", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = false,
      mplusTimerData = {
        running = true,
      },
    })

    local ticker = FindTicker(state.tickers, 1.0)
    Assert.NotNil(ticker, "secondary controller init must register the CD tracker ticker")
    if type(ticker) ~= "table" or type(ticker.callback) ~= "function" then
      return
    end

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

  test("Factory UNIT_AURA CD refresh plays Bloodlust sound only on new aura onset", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules)

    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustSoundCalls or 0, 0, "plain CD refresh must not play a Bloodlust sound")

    state.lustInfo = { remain = 39, icon = 132114 }
    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    Assert.Equal(state.bloodlustSoundCalls or 0, 1, "Sated aura onset must play the Bloodlust sound")

    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    Assert.Equal(state.bloodlustSoundCalls or 0, 1, "still-active Sated aura must not replay the Bloodlust sound")

    state.lustInfo = nil
    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    state.lustInfo = { remain = 25, icon = 132114 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustSoundCalls or 0, 1, "non-UNIT_AURA refresh must not play a Bloodlust sound")
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
    if type(ticker) ~= "table" or type(ticker.callback) ~= "function" then
      return
    end

    ticker.callback()

    Assert.Equal(state.kickScans or 0, 1, "hidden kick ticker must still scan the local kick state")
    Assert.Equal(#state.sentKick, 1, "hidden kick ticker must keep syncing kick state for peers")
    Assert.NotNil(state.lastSetKickInfo, "hidden kick ticker must still update the local kick sync cache")
    Assert.Equal(state.kickRefreshes or 0, 0, "hidden kick ticker must avoid polling-driven UI refreshes")
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
    if type(ticker) ~= "table" or type(ticker.callback) ~= "function" then
      return
    end
    Assert.Equal(type(state.ctx.HandleKickTrackerEvent), "function", "kick tracker must expose central event handler")
    if type(state.ctx.HandleKickTrackerEvent) ~= "function" then
      return
    end

    ticker.callback()
    state.ctx.HandleKickTrackerEvent("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 6552)

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
  RegisterTestModeDemoDataTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterKillTrackNameplateRefreshTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterPostRaidKickRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
end
