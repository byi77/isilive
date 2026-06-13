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
              return state.bresInfo
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
      teleport = {
        GetTeleportInfoByMapID = function(mapID)
          return {
            spellID = 100000 + mapID,
            icon = "icon-" .. tostring(mapID),
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
    ShowSimulationTablet = function()
      state.simulationTabletShown = true
      state.simulationTabletShowCalls = (state.simulationTabletShowCalls or 0) + 1
    end,
    HideSimulationTablet = function()
      state.simulationTabletShown = false
      state.simulationTabletHideCalls = (state.simulationTabletHideCalls or 0) + 1
    end,
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
        INVITE_ACCEPTED_NOTICE_LABEL_GROUP = "Title:",
        INVITE_ACCEPTED_NOTICE_LABEL_ROLE = "Role:",
        INVITE_ACCEPTED_NOTICE_LABEL_LEADER = "Leader:",
        INVITE_ACCEPTED_NOTICE_LABEL_SOURCE = "Source:",
        INVITE_ACCEPTED_NOTICE_SOURCE_LFG_ACCEPTED = "LFG accepted invite",
        INVITE_HINT_EYEBROW = "LFG Invite",
        INVITE_HINT_TITLE = "isiLive - Invite received",
        INVITE_HINT_SOURCE_LFG_INVITED = "LFG invite received",
        DUNGEON_DIFF_NORMAL = "Normal",
        NON_MYTHIC_ENTERED = "Warning: Entered non-Mythic dungeon (%s).",
        NON_MYTHIC_NOTICE_DUNGEON_EYEBROW = "Dungeon",
        NON_MYTHIC_NOTICE_DUNGEON_TITLE = "isiLive - Dungeon entered",
        NON_MYTHIC_NOTICE_LABEL_DUNGEON = "Dungeon:",
        NON_MYTHIC_NOTICE_LABEL_DIFFICULTY = "Difficulty:",
        NON_MYTHIC_NOTICE_LABEL_HINT = "Hint:",
        NON_MYTHIC_NOTICE_LABEL_SOURCE = "Source:",
        NON_MYTHIC_NOTICE_HINT_NON_MYTHIC = "Not a Mythic+ dungeon",
        NON_MYTHIC_NOTICE_SOURCE_INSTANCE_ENTERED = "Instance entered",
        NON_MYTHIC_NOTICE_DEMO_DUNGEON = "Priory of the Sacred Flame",
        PORTAL_NAVIGATOR_TITLE = "isiLive - Midnight Season One M+ Navigator",
        PORTAL_NAVIGATOR_EYEBROW = "Portal - Navigation",
        PORTAL_NAVIGATOR_HALF_LEFT = "Half-left",
        PORTAL_NAVIGATOR_LEFT = "Left",
        PORTAL_NAVIGATOR_RIGHT = "Right",
        PORTAL_NAVIGATOR_HALF_RIGHT = "Half-right",
        PORTAL_NAVIGATOR_CENTER = "Straight ahead",
        PORTAL_NAVIGATOR_PIT_OF_SARON = "Pit",
        PORTAL_NAVIGATOR_SKYREACH = "Sky",
        PORTAL_NAVIGATOR_TRIUMVIRATE = "Seat",
        PORTAL_NAVIGATOR_ALGETHAR = "AA",
        PORTAL_NAVIGATOR_HEAVEN = "Heaven",
        PORTAL_NAVIGATOR_UNOCCUPIED = "Unoccupied",
        ROLE_NAME_DAMAGE = "Damage",
        TTS_PREVIEW_TEXT = "isiLive text to speech is active.",
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
    RefreshReadyCheckUI = function()
      state.readyCheckRefreshes = (state.readyCheckRefreshes or 0) + 1
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
      state.centerNoticeHistory = state.centerNoticeHistory or {}
      table.insert(state.centerNoticeHistory, state.centerNotice)
    end,
    ShowDemoCenterNotices = function(notices)
      state.demoCenterNotices = notices
    end,
    ShowInviteHint = function(payload, durationSeconds, searchResultID)
      state.inviteHintPayload = payload
      state.inviteHintDurationSeconds = durationSeconds
      state.inviteHintSearchResultID = searchResultID
    end,
    SetDemoCenterNoticesVisible = function(visible)
      state.demoCenterNoticesVisible = visible
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
        Hide = function()
          state.inviteHintHidden = true
        end,
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
    SetReadyCheckActive = function(active)
      state.readyCheckActive = active == true
    end,
    SetReadyCheckReadyUntil = function(unit, untilTime)
      state.readyCheckReadyUntil = state.readyCheckReadyUntil or {}
      state.readyCheckReadyUntil[unit] = untilTime
    end,
    SetReadyCheckDeclinedUntil = function(unit, untilTime)
      state.readyCheckDeclinedUntil = state.readyCheckDeclinedUntil or {}
      state.readyCheckDeclinedUntil[unit] = untilTime
    end,
    ClearAllReadyCheckReady = function()
      state.readyCheckReadyUntil = {}
    end,
    ClearAllReadyCheckDeclined = function()
      state.readyCheckDeclinedUntil = {}
    end,
    TriggerShareKeysCooldown = function(seconds)
      state.shareKeysCooldownSeconds = seconds
    end,
    ClearShareKeysCooldown = function()
      state.shareKeysCooldownCleared = (state.shareKeysCooldownCleared or 0) + 1
      state.shareKeysCooldownSeconds = nil
    end,
    ShowRoleDeathAlert = function(role, unit)
      state.deathAlertPreviews = state.deathAlertPreviews or {}
      table.insert(state.deathAlertPreviews, {
        role = role,
        unit = unit,
      })
    end,
    IsRaidGroup = function()
      return state.isRaidGroup == true
    end,
    isInGroup = function()
      return state.inGroup == true
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
    inGroup = initial.inGroup ~= false,
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
        SetTestMode = function(enabled, percent, opts)
          state.mobNameplateTestMode = enabled
          state.mobNameplateTestPercent = percent
          state.mobNameplateTestOpts = opts
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
        PlayBattleResReady = function()
          state.battleResReadySoundCalls = (state.battleResReadySoundCalls or 0) + 1
          return true
        end,
        PlayBloodlust = function()
          state.bloodlustSoundCalls = (state.bloodlustSoundCalls or 0) + 1
        end,
        PlayBloodlustReady = function()
          state.bloodlustReadySoundCalls = (state.bloodlustReadySoundCalls or 0) + 1
          return true
        end,
        PlayReadyCheckComplete = function()
          state.readyCheckCompleteSoundCalls = (state.readyCheckCompleteSoundCalls or 0) + 1
          return true
        end,
        SpeakTts = function(text, opts)
          state.ttsPreviews = state.ttsPreviews or {}
          table.insert(state.ttsPreviews, {
            text = text,
            spamScope = opts and opts.spamScope or nil,
          })
          return true
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
    Assert.Equal(state.mplusDemoData.keyLevel, 15, "M+ timer demo data must expose the started key level")
    Assert.NotNil(state.killTrackDemoData, "test mode must populate bottom M+ forces tracker demo data")
    Assert.True(state.killTrackDemoData.active, "kill-track demo data must be active")
    Assert.Equal(state.killTrackDemoData.percent, 47.34, "kill-track demo percent must match the preview value")
    Assert.Equal(state.killTrackRowRefreshes, 1, "test mode must refresh the kill-track row after demo data is set")
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
    Assert.NotNil(state.mobNameplateTestOpts, "nameplate demo must pass an explicit demo context")
    Assert.Equal(state.mobNameplateTestOpts.activeMapID, 559, "nameplate demo must use the demo target map context")
    Assert.Nil(state.mobNameplateFormat, "nameplate demo must not override the user's percent format settings")
    Assert.Nil(state.mobNameplateAppearance, "nameplate demo must not override the user's appearance settings")
    Assert.False(state.readyCheckActive, "demo mode must use finished ready-check hold states, not live active status")
    Assert.Equal(state.readyCheckReadyUntil.player, 20, "demo mode must mark the player ready for the hold preview")
    Assert.Equal(state.readyCheckReadyUntil.party1, 20, "demo mode must mark one party row ready for the hold preview")
    Assert.Equal(state.readyCheckDeclinedUntil.party2, 20, "demo mode must mark one party row declined")
    Assert.Equal(state.readyCheckRefreshes, 1, "demo mode must refresh ready-check row decoration")
    Assert.Equal(state.shareKeysCooldownSeconds, 18, "demo mode must show the mirrored share-keys cooldown state")
    Assert.True(state.simulationTabletShown == true, "demo mode must show the simulation tablet")
    Assert.Equal(state.simulationTabletShowCalls, 1, "demo mode must show the simulation tablet once")
    Assert.NotNil(state.deathAlertPreviews, "demo mode must preview death alerts")
    Assert.Equal(state.deathAlertPreviews[1].role, "TANK", "demo mode must show the tank death alert preview")
    Assert.Equal(state.deathAlertPreviews[2].role, "DAMAGER", "demo mode must exercise the TTS-only DPS death path")
    Assert.Equal(state.readyCheckCompleteSoundCalls, 1, "demo mode must preview the ready-check-complete sound")
    Assert.NotNil(state.ttsPreviews, "demo mode must preview spoken TTS")
    Assert.Equal(
      state.ttsPreviews[1].text,
      "isiLive text to speech is active.",
      "demo TTS preview text must be explicit"
    )
    Assert.Equal(state.ttsPreviews[1].spamScope, "preview:demo", "demo TTS preview must use a separate spam scope")
    Assert.NotNil(state.portalNavigatorLayout, "test mode must show the portal navigator demo")
    Assert.Equal(
      state.portalNavigatorLayout.eyebrow,
      "Portal - Navigation",
      "portal navigator demo must render the blue header eyebrow"
    )
    Assert.Equal(
      state.portalNavigatorLayout.title,
      "isiLive - Midnight Season One M+ Navigator",
      "portal navigator demo must render the season navigator title"
    )
    Assert.Equal(#state.portalNavigatorLayout.entries, 5, "portal navigator demo must render all five portal positions")
    local portalEntriesBySlot = {}
    for _, entry in ipairs(state.portalNavigatorLayout.entries) do
      portalEntriesBySlot[entry.slot] = entry
    end
    Assert.Equal(portalEntriesBySlot.left.icon, "icon-161", "demo left portal must use the Skyreach teleport icon")
    Assert.Equal(portalEntriesBySlot.half_left.icon, "icon-556", "demo half-left portal must use the Pit teleport icon")
    Assert.Equal(
      portalEntriesBySlot.half_right.icon,
      "icon-402",
      "demo half-right portal must use the Academy teleport icon"
    )
    Assert.Equal(portalEntriesBySlot.right.icon, "icon-239", "demo right portal must use the Triumvirate teleport icon")
    Assert.True(portalEntriesBySlot.center.isEmpty == true, "demo center portal must stay marked as empty")
    Assert.Nil(portalEntriesBySlot.center.icon, "demo center portal must not synthesize an icon")
    Assert.NotNil(state.demoCenterNotices, "test mode must show the demo center notices without replacing each other")
    Assert.Equal(#state.demoCenterNotices, 2, "test mode must show both center notice demo variants at once")
    Assert.Nil(state.inviteHintPayload, "test mode must not show the removed pre-accept invite hint preview")
    local acceptedNotice = state.demoCenterNotices[1]
    local difficultyNotice = state.demoCenterNotices[2]
    Assert.Equal(acceptedNotice.dungeonName, "Nexus-Point Xenas", "center notice demo must use the demo target")
    Assert.Equal(
      acceptedNotice.showOptions.teleportMapID,
      559,
      "center notice demo must configure a verified map portal"
    )
    Assert.Nil(acceptedNotice.showOptions.teleportLabel, "center notice demo must omit the redundant teleport header")
    Assert.Equal(acceptedNotice.showOptions.frameWidth, 680, "accepted-invite demo notice must use the rich card width")
    Assert.Equal(
      acceptedNotice.showOptions.fields[3].value,
      "isiLive-Demo",
      "accepted-invite demo notice must render the leader row"
    )
    Assert.Equal(
      acceptedNotice.showOptions.fields[4].value,
      "LFG accepted invite",
      "accepted-invite demo notice must render the source row"
    )
    Assert.Equal(
      difficultyNotice.showOptions.title,
      "isiLive - Dungeon entered",
      "demo mode must preview the non-mythic dungeon-entry center notice beside the target notice"
    )
    Assert.Equal(
      difficultyNotice.showOptions.fields[1].value,
      "Priory of the Sacred Flame",
      "non-mythic demo notice must render the demo dungeon"
    )
    Assert.Equal(
      difficultyNotice.showOptions.fields[2].value,
      "Normal",
      "non-mythic demo notice must render the normal difficulty"
    )
    Assert.True(
      difficultyNotice.showOptions.fields[3].warning == true,
      "non-mythic demo notice hint must be marked as a warning row"
    )
    Assert.True(
      difficultyNotice.showOptions.fields[3].blink == true,
      "non-mythic demo notice hint must blink for emphasis"
    )

    state.ctx.ExitTestMode()
    Assert.Nil(state.mplusDemoData, "test mode exit must clear M+ timer demo data")
    Assert.Nil(state.killTrackDemoData, "test mode exit must clear kill-track demo data")
    Assert.Equal(state.mplusDemoCleared, 1, "M+ timer demo data must be cleared once")
    Assert.Equal(state.killTrackDemoCleared, 1, "kill-track demo data must be cleared once")
    Assert.Nil(state.statsBoxDemoData, "test mode exit must clear stats-box demo data")
    Assert.Equal(state.statsBoxDemoCleared, 1, "stats-box demo data must be cleared once")
    Assert.False(state.mobNameplateTestMode, "test mode exit must disable nameplate forces demo mode")
    Assert.Equal(next(state.readyCheckReadyUntil), nil, "test mode exit must clear ready-check ready holds")
    Assert.Equal(next(state.readyCheckDeclinedUntil), nil, "test mode exit must clear ready-check declined holds")
    Assert.Equal(state.shareKeysCooldownCleared, 1, "test mode exit must clear the demo share-keys cooldown")
    Assert.Nil(state.shareKeysCooldownSeconds, "test mode exit must leave no demo share-keys cooldown")
    Assert.False(state.portalNavigatorVisible, "test mode exit must hide the portal navigator demo")
    Assert.False(state.demoCenterNoticesVisible, "test mode exit must hide the stacked demo center notices")
    Assert.False(state.simulationTabletShown, "test mode exit must hide the simulation tablet")
    Assert.Equal(state.simulationTabletHideCalls, 1, "test mode exit must hide the simulation tablet once")
  end)

  test("Factory test mode does not show removed pre-accept invite hint demo", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules)

    WithGlobals(BuildGlobalsEnv(state), function()
      state.ctx.EnterFullDummyPreview()
      state.afterCallbacks[1]()

      Assert.Nil(state.inviteHintPayload, "removed pre-accept invite hint demo must not be shown")
      Assert.NotNil(state.demoCenterNotices, "accepted/group target center notices must still be previewed")
      Assert.Equal(#state.demoCenterNotices, 2, "center notice demos remain available after removing invite hint")
    end)
  end)

  test("Factory test mode shows portal navigator demo with matching header texts", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules)

    WithGlobals(BuildGlobalsEnv(state), function()
      state.ctx.EnterFullDummyPreview()
    end)

    Assert.NotNil(state.portalNavigatorLayout, "test mode must show the portal navigator demo")
    Assert.Equal(
      state.portalNavigatorLayout.eyebrow,
      "Portal - Navigation",
      "demo portal navigator must pass the blue eyebrow text"
    )
    Assert.Equal(
      state.portalNavigatorLayout.title,
      "isiLive - Midnight Season One M+ Navigator",
      "demo portal navigator must pass the gold season title"
    )
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
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = true,
      },
    })

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

  test("Factory CD refresh plays Bloodlust-ready sound and repeats while unused every 60 seconds", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = true,
      },
    })

    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 0, "inactive initial scan must not play Bloodlust-ready")

    state.lustInfo = { remain = 2, icon = 132114 }
    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 0, "active Bloodlust must not play the ready alert")

    state.lustInfo = { remain = 0, icon = 132114 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(
      state.bloodlustReadySoundCalls or 0,
      1,
      "displayed zero Bloodlust timer must play the ready alert once"
    )
    local readyDisplay = state.cdController.GetLustInfo()
    Assert.NotNil(readyDisplay, "Bloodlust-ready display state must stay visible after the ready transition")
    Assert.Equal(readyDisplay.remain, 0, "Bloodlust-ready display state must render as 00:00 through the UI controller")

    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 1, "still-ready Bloodlust must not replay the ready alert")

    state.time = 59
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 1, "Bloodlust-ready must not remind before 60 seconds")

    state.time = 60
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 2, "unused Bloodlust-ready must remind after 60 seconds")

    state.time = 119
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 2, "Bloodlust-ready reminders must wait another full minute")

    state.time = 120
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 3, "unused Bloodlust-ready must keep reminding every 60 seconds")

    state.lustInfo = { remain = 10, icon = 132114 }
    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    state.lustInfo = nil
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 4, "a later Bloodlust cycle may play one new ready alert")
  end)

  test("Factory CD refresh respects disabled Bloodlust-ready reminder loop setting", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      db = {
        soundBloodlustReadyReminderEnabled = false,
      },
      mplusTimerData = {
        running = true,
      },
    })

    state.lustInfo = { remain = 2, icon = 132114 }
    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    state.lustInfo = nil
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 1, "first Bloodlust-ready alert must still play")

    state.time = 60
    state.ctx.UpdateCdTracker()
    Assert.Equal(
      state.bloodlustReadySoundCalls or 0,
      1,
      "disabled Bloodlust-ready reminder setting must suppress the 60-second repeat"
    )
  end)

  test("Factory CD refresh exposes BL: -- when ready display context is inactive", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = true,
      },
    })

    state.lustInfo = { remain = 2, icon = 132114 }
    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    state.lustInfo = nil
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.cdController.GetLustInfo().remain, 0, "running grouped key must expose ready display as 00:00")

    state.inGroup = false
    state.ctx.UpdateCdTracker()
    Assert.Nil(state.cdController.GetLustInfo(), "ungrouped context must fall back to BL: --")
  end)

  test("Factory CD refresh routes Bloodlust-ready through the real SoundUtils asset", function()
    local now = 100
    local lustInfo = nil
    local playCalls = {}

    WithGlobals({
      IsiLiveDB = {
        soundBloodlustReadyEnabled = true,
      },
      GetTime = function()
        return now
      end,
      PlaySoundFile = function(path, channel)
        playCalls[#playCalls + 1] = { path = path, channel = channel }
        return true
      end,
      C_Timer = {
        NewTicker = function()
          return {
            Cancel = function() end,
          }
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_sound_utils.lua", "isiLive_factory_cd_tracker.lua" })
      addon.MplusTimer = {
        GetTimerData = function()
          return { running = true }
        end,
      }
      local modules = {
        cdTracker = {
          CreateController = function()
            return {
              Scan = function() end,
              GetBResInfo = function()
                return nil
              end,
              GetLustInfo = function()
                return lustInfo
              end,
            }
          end,
        },
      }
      local factoryCtx = {
        addonTable = addon,
        isInGroup = function()
          return true
        end,
        UpdateUI = function() end,
      }

      addon._FactoryInternal.InitializeFactorySecondaryCdTracker(factoryCtx, modules, {}, function()
        return now
      end, function()
        return false
      end, function()
        return false
      end)

      factoryCtx.UpdateCdTracker()
      lustInfo = { remain = 5, icon = 132114 }
      factoryCtx.UpdateCdTracker()
      lustInfo = { remain = 0, icon = 132114 }
      factoryCtx.UpdateCdTracker()
    end)

    Assert.Equal(#playCalls, 1, "Bloodlust-ready transition must emit exactly one real sound call")
    Assert.Equal(
      playCalls[1].path,
      "Interface\\AddOns\\isiLive\\sounds\\BloodlustReady.wav",
      "Bloodlust-ready transition must use the dedicated TTS asset"
    )
    Assert.Equal(playCalls[1].channel, "Master", "Bloodlust-ready transition must use the configured channel")
  end)

  test("Factory CD refresh suppresses Bloodlust-ready sound on key reset refresh", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = true,
      },
    })

    state.lustInfo = { remain = 20, icon = 132114 }
    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 0, "active Bloodlust must not play ready before reset")

    state.lustInfo = nil
    state.mplusTimerData = {
      running = false,
    }
    state.ctx.UpdateCdTracker({ suppressLustReadySound = true })
    Assert.Equal(
      state.bloodlustReadySoundCalls or 0,
      0,
      "key reset refresh must not announce Bloodlust-ready when the aura is force-cleared"
    )

    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 0, "suppressed reset must clear the observed cycle")
  end)

  test("Factory CD refresh clears Bloodlust-ready cycle when key ends during exhaustion", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = true,
      },
    })

    state.lustInfo = { remain = 20, icon = 132114 }
    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 0, "active Bloodlust must not play ready before key end")

    state.ctx.UpdateCdTracker({ suppressLustReadySound = true })
    Assert.Equal(
      state.bloodlustReadySoundCalls or 0,
      0,
      "key end refresh must not announce Bloodlust-ready while exhaustion is still active"
    )

    state.lustInfo = nil
    state.mplusTimerData = {
      running = false,
    }
    state.ctx.UpdateCdTracker()
    Assert.Equal(
      state.bloodlustReadySoundCalls or 0,
      0,
      "post-key zone refresh must not announce Bloodlust-ready after the suppressed cycle was cleared"
    )
  end)

  test("Factory CD refresh stops Bloodlust-ready reminders after key end or dungeon leave", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = true,
      },
    })

    state.lustInfo = { remain = 2, icon = 132114 }
    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    state.lustInfo = { remain = 0, icon = 132114 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 1, "in-key Bloodlust-ready must play before the key ends")

    state.time = 60
    state.mplusTimerData = {
      running = false,
    }
    state.ctx.UpdateCdTracker({ suppressLustReadySound = true })
    Assert.Equal(
      state.bloodlustReadySoundCalls or 0,
      1,
      "key-end refresh must not start the next Bloodlust-ready reminder"
    )

    state.time = 180
    state.ctx.UpdateCdTracker()
    Assert.Equal(
      state.bloodlustReadySoundCalls or 0,
      1,
      "post-key or dungeon-leave refreshes must not resume Bloodlust-ready reminders"
    )
  end)

  test("Factory CD refresh suppresses Bloodlust-ready reminders after group leave with stale timer", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = true,
      },
    })

    state.lustInfo = { remain = 2, icon = 132114 }
    state.ctx.UpdateCdTracker({ playLustSoundOnStart = true })
    Assert.Equal(state.bloodlustReadySoundCalls or 0, 0, "active Bloodlust must not play ready before group leave")

    state.inGroup = false
    state.lustInfo = { remain = 0, icon = 132114 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(
      state.bloodlustReadySoundCalls or 0,
      0,
      "group-leave refresh must not announce Bloodlust-ready even when the timer is stale"
    )

    state.time = 60
    state.ctx.UpdateCdTracker()
    Assert.Equal(
      state.bloodlustReadySoundCalls or 0,
      0,
      "group-leave refresh must discard the 60-second Bloodlust-ready reminder cycle"
    )
  end)

  test("Factory CD refresh plays Battle Res-ready sound once when cooldown reaches zero or charges recover", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = true,
      },
    })

    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 0, "unresolved initial BRes scan must not play ready")

    state.bresInfo = { charges = 1, maxCharges = 1, cooldownRemain = 0 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 0, "available initial BRes scan must not play ready")

    state.bresInfo = { charges = 0, maxCharges = 1, cooldownRemain = 120 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 0, "BRes cooldown start must not play ready")

    state.bresInfo = { charges = 0, maxCharges = 1, cooldownRemain = 0 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 1, "displayed zero BRes cooldown must play ready once")

    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 1, "still-ready BRes must not replay")

    state.bresInfo = { charges = 0, maxCharges = 1, cooldownRemain = 90 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 1, "a later BRes cooldown start must not play ready")

    state.bresInfo = { charges = 1, maxCharges = 1, cooldownRemain = 0 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 2, "BRes charge increase may still play one new ready alert")

    state.bresInfo = { charges = 2, maxCharges = 2, cooldownRemain = 0 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(
      state.battleResReadySoundCalls or 0,
      3,
      "any later BRes charge increase should play one new ready alert"
    )

    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 3, "unchanged increased BRes charges must not loop")
  end)

  test("Factory CD refresh suppresses the first Battle Res-ready state after key start only", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = false,
      },
    })

    state.bresInfo = { charges = 0, maxCharges = 1, cooldownRemain = 30 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 0, "pre-key BRes cooldown must not play ready")

    state.mplusTimerData = {
      running = true,
    }
    state.bresInfo = { charges = 1, maxCharges = 1, cooldownRemain = 0 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(
      state.battleResReadySoundCalls or 0,
      0,
      "first available BRes state directly after key start must stay silent"
    )

    state.bresInfo = { charges = 0, maxCharges = 1, cooldownRemain = 90 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 0, "first in-key BRes usage must not play ready early")

    state.bresInfo = { charges = 1, maxCharges = 1, cooldownRemain = 0 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 1, "later in-key BRes recovery must still play the ready alert")
  end)

  test("Factory visible CD rescan routes Battle Res-ready sound through the displayed timer path", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mainFrameShown = true,
      mplusTimerData = {
        running = true,
      },
    })

    state.bresInfo = { charges = 0, maxCharges = 1, cooldownRemain = 45 }
    state.cdController.Scan()
    Assert.Equal(state.battleResReadySoundCalls or 0, 0, "visible UI cooldown scan must not play ready early")
    Assert.Equal(state.uiUpdates or 0, 0, "visible UI cooldown scan must not re-enter the full UI render")

    state.bresInfo = { charges = 0, maxCharges = 1, cooldownRemain = 0 }
    state.cdController.Scan()
    Assert.Equal(
      state.battleResReadySoundCalls or 0,
      1,
      "visible UI cooldown scan must use the same BRes-ready transition as the displayed timer"
    )
    Assert.Equal(state.uiUpdates or 0, 0, "ready sound scan from visible render must not re-enter the full UI render")
  end)

  test("Factory CD refresh suppresses Battle Res-ready sound on key reset refresh", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = true,
      },
    })

    state.bresInfo = { charges = 0, maxCharges = 1, cooldownRemain = 120 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 0, "BRes cooldown state must not play ready")

    state.bresInfo = { charges = 1, maxCharges = 1, cooldownRemain = 0 }
    state.mplusTimerData = {
      running = false,
    }
    state.ctx.UpdateCdTracker({ suppressBattleResReadySound = true })
    Assert.Equal(
      state.battleResReadySoundCalls or 0,
      0,
      "key reset refresh must not announce Battle Res-ready when charges are force-restored"
    )

    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 0, "suppressed BRes reset must clear the observed cycle")
  end)

  test("Factory CD refresh clears Battle Res-ready cycle when key ends during cooldown", function()
    local state = BuildFactorySecondaryControllerState(WithGlobals, LoadAddonModules, {
      mplusTimerData = {
        running = true,
      },
    })

    state.bresInfo = { charges = 0, maxCharges = 1, cooldownRemain = 120 }
    state.ctx.UpdateCdTracker()
    Assert.Equal(state.battleResReadySoundCalls or 0, 0, "BRes cooldown state must not play ready")

    state.ctx.UpdateCdTracker({ suppressBattleResReadySound = true })
    Assert.Equal(
      state.battleResReadySoundCalls or 0,
      0,
      "key end refresh must not announce Battle Res-ready while BRes is still on cooldown"
    )

    state.bresInfo = { charges = 1, maxCharges = 1, cooldownRemain = 0 }
    state.mplusTimerData = {
      running = false,
    }
    state.ctx.UpdateCdTracker()
    Assert.Equal(
      state.battleResReadySoundCalls or 0,
      0,
      "post-key zone refresh must not announce Battle Res-ready after the suppressed cycle was cleared"
    )
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
