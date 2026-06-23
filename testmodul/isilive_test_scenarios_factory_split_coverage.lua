---@diagnostic disable: undefined-global

local function NewButton()
  local button = {
    _scripts = {},
    enabled = true,
    alpha = 1,
    text = nil,
    shown = true,
  }
  function button:SetScript(name, fn)
    self._scripts[name] = fn
  end
  function button:GetScript(name)
    return self._scripts[name]
  end
  function button:SetEnabled(value)
    self.enabled = value
  end
  function button:SetAlpha(value)
    self.alpha = value
  end
  function button:SetText(value)
    self.text = value
  end
  function button:IsShown()
    return self.shown == true
  end
  return button
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  test("factory split coverage: combat announce callbacks render, sound, and broadcast", function()
    local prints = {}
    local sent
    local brSounds = 0
    local lustSounds = 0
    local piAlerts = 0
    local deps

    local addon = LoadAddonModules({ "isiLive_factory_combat_announces.lua" })
    addon.SoundUtils = {
      PlayBattleRes = function()
        brSounds = brSounds + 1
      end,
      PlayBloodlust = function()
        lustSounds = lustSounds + 1
      end,
    }
    addon.CombatEvents = {
      SetDependencies = function(value)
        deps = value
      end,
    }
    addon.PiTracker = {
      SetDependencies = function(value)
        deps.pi = value
      end,
    }
    addon.DeathAlert = {
      ShowPowerInfusion = function()
        piAlerts = piAlerts + 1
      end,
    }

    local factoryCtx = {
      GetL = function()
        return {
          COMBAT_CHAT_BR_USED = "%s used BR",
          COMBAT_CHAT_LUST_STARTED = "%s started Lust",
          COMBAT_CHAT_PI_RECEIVED = "%s empowered %s with PI",
        }
      end,
      Print = function(line)
        prints[#prints + 1] = line
      end,
      modules = {
        sync = {
          SendCombatAnnounce = function(info)
            sent = info
          end,
        },
      },
    }

    WithGlobals({ IsiLiveDB = { combatChatBRAnnounce = true } }, function()
      addon._FactoryInternal.InitializeFactoryCombatAnnounceControllers(factoryCtx)
      Assert.Equal(type(deps), "table", "combat events dependencies must be registered")
      Assert.Equal(deps.getDB().combatChatBRAnnounce, true, "combat dependency getDB must read live DB")

      factoryCtx.ShowCombatAnnounce(nil)
      factoryCtx.ShowCombatAnnounce({ kind = "UNKNOWN", caster = "Nope-Realm" })
      factoryCtx.ShowCombatAnnounce({ kind = "BR" })
      factoryCtx.ShowCombatAnnounce({ kind = "LUST", caster = "Mage-Realm" })
      factoryCtx.BroadcastCombatAnnounce("BR", "Druid-Realm", 20484)
      deps.pi.announcePowerInfusion("Priest-Realm", "Target-Realm", false)
      deps.pi.announcePowerInfusion("Priest-Realm", "Me-Realm", true)
    end)

    Assert.Equal(prints[1], "? used BR", "missing caster must render a placeholder")
    Assert.Equal(prints[2], "Mage started Lust", "realm suffix must be stripped from lust caster")
    Assert.Equal(prints[3], "Druid used BR", "broadcast path must also render locally")
    Assert.Equal(prints[4], "Priest empowered Target with PI", "PI on other players must render as local chat only")
    Assert.Equal(prints[5], "Priest empowered Me with PI", "PI on player must render as local chat")
    Assert.Equal(brSounds, 2, "BR sound must fire for BR local and broadcast render")
    Assert.Equal(lustSounds, 1, "lust sound must fire for lust render")
    Assert.Equal(piAlerts, 1, "PI center alert must fire only for the local recipient")
    Assert.Equal(sent.spellID, 20484, "broadcast path must send the combat announce payload")
  end)

  test("factory split coverage: combat announce in-key gate uses running M+ timer when map API is masked", function()
    local deps
    local addon = LoadAddonModules({ "isiLive_factory_combat_announces.lua" })
    addon.MplusTimer = {
      GetTimerData = function()
        return { running = true }
      end,
    }
    addon.CombatEvents = {
      SetDependencies = function(value)
        deps = value
      end,
    }

    local factoryCtx = {
      GetActiveChallengeMapID = function()
        return nil
      end,
      GetL = function()
        return {}
      end,
      Print = function() end,
      modules = {},
    }

    addon._FactoryInternal.InitializeFactoryCombatAnnounceControllers(factoryCtx)

    Assert.Equal(type(deps.isInKey), "function", "combat dependency must provide a live in-key gate")
    Assert.True(deps.isInKey(), "running M+ timer must keep combat announces enabled when map ID is masked")
  end)

  test("factory split coverage: Power Infusion text setting suppresses chat and center alert", function()
    local prints = {}
    local piAlerts = 0
    local deps

    local addon = LoadAddonModules({ "isiLive_factory_combat_announces.lua" })
    addon.CombatEvents = {
      SetDependencies = function(value)
        deps = value
      end,
    }
    addon.PiTracker = {
      SetDependencies = function(value)
        deps.pi = value
      end,
    }
    addon.DeathAlert = {
      ShowPowerInfusion = function()
        piAlerts = piAlerts + 1
      end,
    }

    local factoryCtx = {
      GetL = function()
        return {
          COMBAT_CHAT_PI_RECEIVED = "%s empowered %s with PI",
        }
      end,
      Print = function(line)
        prints[#prints + 1] = line
      end,
      modules = {},
    }

    WithGlobals({ IsiLiveDB = { powerInfusionTextEnabled = false } }, function()
      addon._FactoryInternal.InitializeFactoryCombatAnnounceControllers(factoryCtx)
      deps.pi.announcePowerInfusion("Priest-Realm", "Me-Realm", true)
    end)

    Assert.Equal(#prints, 0, "disabled PI text setting must suppress the local chat line")
    Assert.Equal(piAlerts, 0, "disabled PI text setting must suppress the local center alert")
  end)

  test("factory split coverage: refresh button cooldown and refresh-controller callbacks execute", function()
    local addon = LoadAddonModules({ "isiLive_factory_refresh.lua" })
    local now = 0
    local tickerCallback
    local tickerCancelCount = 0
    local roster = {}
    local eventHits = 0
    local forceRefreshHits = 0
    local inspectHits = 0
    local fullRefreshHits = 0
    local previewHits = 0
    local capturedOpts

    local refreshButton = NewButton()
    refreshButton._fullText = "Re-Sync"
    local mainFrame = {
      GetScript = function(_, name)
        if name == "OnEvent" then
          return function(_, event)
            if event == "GROUP_ROSTER_UPDATE" then
              eventHits = eventHits + 1
            end
          end
        end
        return nil
      end,
    }

    local factoryCtx = {
      inspectController = {
        QueueForceRefreshData = function(value)
          if value == roster then
            inspectHits = inspectHits + 1
          end
        end,
      },
      keySyncController = {
        ForceRefreshSyncState = function(value)
          if value == roster then
            forceRefreshHits = forceRefreshHits + 1
          end
        end,
      },
      GetRoster = function()
        return roster
      end,
      mainFrame = mainFrame,
      refreshButton = refreshButton,
      runtimeLogController = {
        Log = function() end,
        Logf = function() end,
      },
      SendIsiLiveHello = function() end,
      SendOwnKeySnapshot = function() end,
      SendOwnBackgroundSnapshot = function() end,
      SendRefreshRequest = function() end,
      UpdateUI = function() end,
      RefreshLocalPlayerKey = function() end,
      GetActiveChallengeMapID = function() end,
    }

    local modules = {
      refresh = {
        CreateController = function(opts)
          capturedOpts = opts
          return {
            RunFullRefresh = function()
              fullRefreshHits = fullRefreshHits + 1
            end,
          }
        end,
      },
      configBuilders = {
        BuildRefreshControllerOpts = function(opts)
          return opts
        end,
      },
    }
    local runtimeState = {
      IsStopped = function()
        return false
      end,
      IsPaused = function()
        return false
      end,
      IsTestMode = function()
        return false
      end,
      IsTestAllMode = function()
        return false
      end,
    }

    WithGlobals({
      IsInGroup = function()
        return true
      end,
      GetTime = function()
        return now
      end,
      C_Timer = {
        NewTicker = function(_, callback)
          tickerCallback = callback
          return {
            Cancel = function()
              tickerCancelCount = tickerCancelCount + 1
            end,
          }
        end,
      },
    }, function()
      addon._FactoryInternal.InitializeFactoryRefreshControllers(factoryCtx, modules, runtimeState)
      Assert.Equal(capturedOpts.isRosterEmpty(), true, "empty roster callback must resolve true")
      Assert.Equal(capturedOpts.refreshTestModeRoster(), false, "missing testmode controller must fail closed")
      factoryCtx.testModeController = {
        RefreshActivePreview = function()
          previewHits = previewHits + 1
          return true
        end,
      }
      Assert.Equal(
        capturedOpts.refreshTestModeRoster(),
        true,
        "testmode controller callback must forward preview refresh"
      )
      capturedOpts.triggerGroupRosterUpdate()
      capturedOpts.queueForceRefreshData()
      capturedOpts.forceRefreshSyncState()

      refreshButton:GetScript("OnClick")()
      now = 5
      refreshButton:GetScript("OnClick")()
      now = 20
      refreshButton:GetScript("OnClick")()
      now = 40
      tickerCallback()
    end)

    Assert.Equal(eventHits, 1, "triggerGroupRosterUpdate must dispatch GROUP_ROSTER_UPDATE")
    Assert.Equal(inspectHits, 1, "queueForceRefreshData must pass the live roster")
    Assert.Equal(forceRefreshHits, 1, "forceRefreshSyncState must pass the live roster")
    Assert.Equal(previewHits, 1, "refreshTestModeRoster must call the preview refresh once")
    Assert.Equal(fullRefreshHits, 2, "cooldown must block only the middle click")
    Assert.True(tickerCancelCount >= 1, "cooldown ticker must be cancelled after expiry")
    Assert.Equal(refreshButton.enabled, true, "button must re-enable after cooldown expiry")
  end)

  test("factory split coverage: localization panel callbacks and center teleport refresh execute", function()
    local addon = LoadAddonModules({ "isiLive_factory_localization.lua" })
    local capturedThirdPanelOpts
    local centerVisualHits = 0
    local settingsOpened
    local refreshHits = 0

    local centerButton = NewButton()
    centerButton.spellID = 12345
    centerButton.inCombatBlocked = false

    local factoryCtx = {
      GetL = function()
        return {}
      end,
      IsInCombat = function()
        return false
      end,
      panelUI = nil,
      secondPanelUI = nil,
      mountPanelUI = nil,
      rosterPanelController = {
        ApplyLocalization = function() end,
      },
      UpdateCountdownCancelButton = function() end,
      centerNoticeTeleportButton = centerButton,
      IsSpellKnownSafe = function(spellID)
        return spellID == 12345
      end,
      UpdateCenterTeleportButtonVisual = function()
        centerVisualHits = centerVisualHits + 1
      end,
      UpdateMPlusTeleportButton = function() end,
      UpdateStatusLine = function() end,
      settingsPanel = {
        category = { ID = "isiLive-settings" },
        Refresh = function()
          refreshHits = refreshHits + 1
        end,
      },
    }

    local modules = {
      ui = {
        EnsurePanelUI = function(opts)
          Assert.Equal(opts.isEnabled(), true, "first panel isEnabled must read the live DB")
          return { panel = 1 }
        end,
        EnsureSecondPanelUI = function(opts)
          Assert.Equal(opts.isEnabled(), true, "second panel isEnabled must read the live DB")
          return { panel = 2, first = opts.firstPanelState }
        end,
        EnsureMountPanelUI = function(opts)
          Assert.Equal(opts.isEnabled(), true, "mount panel isEnabled must read the live DB")
          return { panel = 3, travel = opts.travelPanelState }
        end,
        EnsureThirdPanelUI = function(opts)
          capturedThirdPanelOpts = opts
          Assert.Equal(opts.isEnabled(), true, "third panel isEnabled must read the live DB")
          return { panel = 4, second = opts.secondPanelState }
        end,
      },
    }

    WithGlobals({
      IsiLiveDB = { showEscPanel = true },
      Settings = {
        OpenToCategory = function(id)
          settingsOpened = id
        end,
      },
    }, function()
      addon._FactoryInternal.InitializeFactoryLocalizationControllers(factoryCtx, modules)
      factoryCtx.ApplyLocalizationToUI()
      Assert.Equal(capturedThirdPanelOpts.panelActions.isilive(), true, "settings panel action must open category")
    end)

    Assert.Equal(settingsOpened, "isiLive-settings", "settings category ID must be forwarded")
    Assert.Equal(centerVisualHits, 1, "visible center teleport button must refresh its visual state")
    Assert.Equal(refreshHits, 1, "settings panel must be refreshed after localization")
  end)

  test("factory split coverage: status wiring callbacks execute", function()
    local addon = LoadAddonModules({
      "isiLive_factory_notices.lua",
      "isiLive_factory_localization.lua",
      "isiLive_factory_refresh.lua",
      "isiLive_factory_status.lua",
    })

    local teleportDebugOpts
    local statusOpts
    local lfgChatCallback
    local latestQueueState
    local updateStatusHits = 0
    local statusTextWrites = 0
    local snapshotHits = 0
    local announceHits = 0
    local payloadAnnounce
    local countdownHits = 0
    local timerHits = 0
    local centerHidden = false
    local portalHidden = false
    local killRefreshHits = 0
    local logfHits = 0

    local countdownButton = NewButton()
    local refreshButton = NewButton()
    refreshButton._fullText = "Re-Sync"

    local runtimeState = {
      GetLatestQueueState = function()
        return latestQueueState
      end,
      SetLatestQueueState = function(dungeonName, activityID, spellID, mapID)
        latestQueueState = { dungeonName, activityID, spellID, mapID }
      end,
      GetRuntimeFlags = function()
        return { isStopped = false, isPaused = false, isTestMode = false }
      end,
      IsStopped = function()
        return false
      end,
      IsPaused = function()
        return false
      end,
      IsTestMode = function()
        return false
      end,
      IsTestAllMode = function()
        return false
      end,
    }

    local factoryCtx = {
      addonTable = addon,
      runtimeState = runtimeState,
      modules = nil,
      Print = function() end,
      PrintHighlighted = function() end,
      GetL = function()
        return {}
      end,
      UpdateMPlusTeleportButton = function() end,
      ResolveActiveTeleportSpellID = function() end,
      IsSpellKnownSafe = function()
        return true
      end,
      GetTeleportCooldownRemaining = function()
        return 0
      end,
      GetSpellCooldownSafe = function()
        return 0, 0, 0
      end,
      FormatCooldownSeconds = function(value)
        return tostring(value)
      end,
      ResolveMapIDByActivityID = function(activityID)
        return activityID
      end,
      ResolveTeleportSpellIDByActivityID = function(activityID)
        return activityID and activityID + 1000
      end,
      GetNormalizedActiveEntryInfo = function()
        return nil
      end,
      ResolveTeleportSpellID = function()
        return 777
      end,
      centerNoticeTeleportButton = { spellID = 777 },
      mplusTeleportButtons = { [777] = NewButton() },
      ShowCenterNotice = function() end,
      countdownCancelButton = countdownButton,
      IsPlayerLeader = function()
        return true
      end,
      runtimeLogController = {
        Log = function() end,
        Logf = function()
          logfHits = logfHits + 1
        end,
      },
      mainFrame = {
        SetScript = function() end,
        GetScript = function()
          return nil
        end,
      },
      InspectLoop = function() end,
      inspectController = {
        ResetQueues = function() end,
        QueueForceRefreshData = function() end,
      },
      keySyncController = {
        ForceRefreshSyncState = function() end,
      },
      statusLine = {
        SetText = function(_, text)
          statusTextWrites = statusTextWrites + 1
          Assert.Equal(text, "ready", "status text must be built through the status controller")
        end,
      },
      SendOwnTargetSnapshot = function()
        snapshotHits = snapshotHits + 1
      end,
      centerNotice = {
        SetVisible = function(value)
          centerHidden = value == false
        end,
      },
      SetPortalNavigatorVisible = function(value)
        portalHidden = value == false
      end,
      ShowPortalNavigatorNotice = function() end,
      IsPortalNavigatorEnabled = function()
        return true
      end,
      GetStatusTargetDungeonInfo = function()
        return { name = "Target", level = 7 }
      end,
      ResolveLocalStatusTargetMapID = function()
        return 77
      end,
      GetSubZoneText = function()
        return "Sub"
      end,
      GetZoneText = function()
        return "Zone"
      end,
      GetRealZoneText = function()
        return "Real"
      end,
      GetPlayerMapID = function()
        return 77
      end,
      GetMapInfoName = function()
        return "Map"
      end,
      panelUI = nil,
      secondPanelUI = nil,
      mountPanelUI = nil,
      rosterPanelController = {
        ApplyLocalization = function() end,
        RefreshKillTrackRow = function()
          killRefreshHits = killRefreshHits + 1
        end,
      },
      UpdateCountdownCancelButton = function() end,
      UpdateCenterTeleportButtonVisual = function() end,
      UpdateStatusLine = function()
        updateStatusHits = updateStatusHits + 1
      end,
      settingsPanel = {
        category = { ID = "isiLive-settings" },
        Refresh = function() end,
      },
      refreshButton = refreshButton,
      GetRoster = function()
        return {}
      end,
      SendIsiLiveHello = function() end,
      SendOwnKeySnapshot = function() end,
      SendOwnBackgroundSnapshot = function() end,
      SendRefreshRequest = function() end,
      UpdateUI = function() end,
      RefreshLocalPlayerKey = function() end,
      GetActiveChallengeMapID = function() end,
    }

    local modules = {
      teleportDebug = {
        CreateController = function(opts)
          teleportDebugOpts = opts
          return { created = true }
        end,
      },
      teleport = {
        ResolveTeleportSpellIDByMapID = function(mapID)
          return mapID and mapID + 2000
        end,
        GetTeleportInfoByMapID = function(mapID)
          return { mapName = "Dungeon " .. tostring(mapID) }
        end,
      },
      status = {
        CreateController = function(opts)
          statusOpts = opts
          return {
            BuildStatusLineText = function(statusFlags)
              Assert.Equal(statusFlags.isStopped, false, "runtime flags must be forwarded")
              return "ready"
            end,
            MaybeAnnounceTargetDungeonChat = function()
              announceHits = announceHits + 1
            end,
            AnnounceTargetDungeonFromPayload = function(payload)
              payloadAnnounce = payload
            end,
          }
        end,
      },
      ui = {
        EnsurePanelUI = function()
          return {}
        end,
        EnsureSecondPanelUI = function()
          return {}
        end,
        EnsureMountPanelUI = function()
          return {}
        end,
        EnsureThirdPanelUI = function()
          return {}
        end,
      },
      refresh = {
        CreateController = function()
          return { RunFullRefresh = function() end }
        end,
      },
      configBuilders = {
        BuildRefreshControllerOpts = function(opts)
          return opts
        end,
      },
    }
    factoryCtx.modules = modules
    addon.SeasonData = {
      HasActiveDungeons = function()
        return false
      end,
      GetSeasonLabel = function()
        return "Midnight"
      end,
    }
    addon.LFGDetect = {
      SetTargetDungeonChatCallback = function(callback)
        lfgChatCallback = callback
      end,
    }

    WithGlobals({
      IsInGroup = function()
        return true
      end,
      C_Timer = {
        After = function(_, callback)
          callback()
        end,
        NewTicker = function()
          return { Cancel = function() end }
        end,
      },
      C_PartyInfo = {
        DoCountdown = function(value)
          if value == 0 then
            countdownHits = countdownHits + 1
          end
        end,
      },
      Settings = {
        OpenToCategory = function() end,
      },
      IsiLiveDB = { showEscPanel = true },
    }, function()
      addon._FactoryInternal.InitializeFactoryRefreshAndStatusControllers(factoryCtx)

      Assert.Equal(teleportDebugOpts.getLatestQueueState(), nil, "latest queue callback must read runtime state")
      Assert.Equal(
        teleportDebugOpts.getCenterNoticeTeleportButton(),
        factoryCtx.centerNoticeTeleportButton,
        "center teleport button callback must read context state"
      )
      Assert.Equal(
        teleportDebugOpts.getMplusTeleportButtons(),
        factoryCtx.mplusTeleportButtons,
        "teleport button callback must read context state"
      )
      teleportDebugOpts.setLatestQueueState("Dungeon 77", 12, 2077, 77)

      statusOpts.timerAfter(0.1, function()
        timerHits = timerHits + 1
      end)
      statusOpts.hideCenterNotice()
      statusOpts.hidePortalNavigatorNotice()
      Assert.Equal(statusOpts.hasLocalTargetSource(), true, "local target callback must accept resolved map IDs")
      Assert.Equal(statusOpts.hasActiveDungeons(), false, "active dungeon callback must read season data")
      Assert.Equal(statusOpts.getActiveSeasonLabel(), "Midnight", "season label callback must read season data")

      countdownButton:GetScript("OnClick")()
      lfgChatCallback({ mapID = 77, activityID = 12, level = 9 })
    end)

    Assert.Equal(updateStatusHits, 0, "old status callback must be replaced during status initialization")
    Assert.Equal(statusTextWrites, 1, "setLatestQueueState callback must refresh the status line")
    Assert.Equal(snapshotHits, 1, "status refresh must send the own target snapshot")
    Assert.Equal(announceHits, 1, "status refresh must run target chat evaluation")
    Assert.Equal(timerHits, 1, "timer callback must execute through the protected wrapper")
    Assert.Equal(centerHidden, true, "hideCenterNotice callback must hide the notice")
    Assert.Equal(portalHidden, true, "hidePortalNavigatorNotice callback must hide the portal navigator")
    Assert.Equal(countdownHits, 1, "leader countdown cancel must call the party countdown API")
    Assert.Equal(payloadAnnounce.name, "Dungeon 77", "LFG chat callback must resolve dungeon name")
    Assert.Equal(payloadAnnounce.level, 9, "LFG chat callback must forward payload level")
    Assert.Equal(killRefreshHits, 1, "LFG chat callback must refresh the kill tracker row")
    Assert.True(logfHits > 0, "status wiring must use runtime logging callbacks")
  end)

  test("factory split coverage: cd tracker and secondary runtime dark callbacks execute", function()
    local addon = LoadAddonModules({
      "isiLive_factory_cd_tracker.lua",
      "isiLive_factory_secondary_runtime.lua",
    })

    local tickerCallback
    local mainShown = true
    local raidMode = false
    local runningTimer = false
    local lustInfo = { remain = 0 }
    local scans = 0
    local readyRefreshHits = 0
    local killRefreshHits = 0
    local nameplateRefreshHits = 0
    local debugLogger
    local logfHits = 0
    local bloodlustHits = 0

    local factoryCtx = {
      addonTable = {
        SoundUtils = {
          PlayBloodlust = function()
            bloodlustHits = bloodlustHits + 1
          end,
        },
        KillTrack = {
          OnUpdate = function(callback)
            callback()
          end,
          SetDebugLogger = function(callback)
            debugLogger = callback
          end,
        },
        MobNameplate = {
          RefreshAll = function()
            nameplateRefreshHits = nameplateRefreshHits + 1
          end,
        },
        _RosterInternal = {
          RegisterBlizzardUnitLanguageTooltip = function(opts)
            Assert.Equal(type(opts.getUnitServerLanguage), "function", "language tooltip must receive resolver")
          end,
        },
        LFGFlags = {
          Register = function(opts)
            Assert.Equal(type(opts.localeModule), "table", "LFG flags must receive locale module")
          end,
        },
        LFGDetect = {
          ClearAllState = function() end,
        },
      },
      rosterPanelController = {
        SetCdController = function() end,
        RefreshCdTracker = function() end,
        RefreshReadyCheckState = function()
          readyRefreshHits = readyRefreshHits + 1
        end,
        RefreshKillTrackRow = function()
          killRefreshHits = killRefreshHits + 1
        end,
      },
      runtimeLogController = {
        Logf = function()
          logfHits = logfHits + 1
        end,
        Log = function() end,
        LogDeep = function() end,
      },
      GetRoster = function()
        return {}
      end,
      GetRealmInfoLib = function() end,
      GetUnitNameAndRealm = function()
        return "Tester", "Realm"
      end,
      GetLanguageTooltipMarkup = function()
        return "English"
      end,
      isInGroup = function()
        return true
      end,
      locales = {
        enUS = { LANG_SET_EN = "English" },
        deDE = { LANG_SET_DE = "Deutsch" },
      },
      L = {},
      Print = function() end,
      ApplyLocalizationToUI = function() end,
      inspectController = {
        EnqueueInspect = function() end,
      },
      ResolveStatusTargetMapID = function()
        return 42
      end,
      ClearLatestQueueTarget = function() end,
      UpdateMPlusTeleportButton = function() end,
    }

    local modules = {
      cdTracker = {
        CreateController = function()
          return {
            Scan = function()
              scans = scans + 1
            end,
            GetLustInfo = function()
              return lustInfo
            end,
          }
        end,
      },
      contextHelpers = {
        GetUnitServerLanguage = function(_, _, unit, realm)
          return unit .. "-" .. realm
        end,
      },
      locale = {
        ResolveLocaleTag = function(tag)
          return tag == "deDE" and "deDE" or "enUS"
        end,
      },
    }
    local runtimeState = {
      IsReadyCheckActive = function()
        return true
      end,
      HasReadyCheckHold = function()
        return false
      end,
    }

    WithGlobals({
      C_Timer = {
        NewTicker = function(_, callback)
          tickerCallback = callback
          return { Cancel = function() end }
        end,
      },
      C_Map = {
        GetBestMapForUnit = function()
          return 42
        end,
      },
      UnitExists = function()
        return true
      end,
      IsiLiveDB = {},
    }, function()
      addon._FactoryInternal.InitializeFactorySecondaryCdTracker(factoryCtx, {}, runtimeState, function()
        return 0
      end, function()
        return mainShown
      end, function()
        return raidMode
      end)
      addon._FactoryInternal.InitializeFactorySecondaryCdTracker(factoryCtx, modules, runtimeState, function()
        return 0
      end, function()
        return mainShown
      end, function()
        return raidMode
      end)

      runningTimer = true
      factoryCtx.addonTable.MplusTimer = {
        GetTimerData = function()
          return { running = runningTimer }
        end,
      }
      factoryCtx.UpdateCdTracker()
      lustInfo = { remain = 12 }
      factoryCtx.UpdateCdTracker({ playLustSoundOnStart = true })
      raidMode = true
      factoryCtx.UpdateCdTracker()
      raidMode = false

      mainShown = false
      tickerCallback()
      mainShown = true
      tickerCallback()
      debugLogger("[KILL] drift=%s", "seen")

      addon._FactoryInternal.RegisterBlizzardUnitLanguageTooltip(factoryCtx, modules)
      Assert.Equal(factoryCtx.GetUnitServerLanguage("player", "Realm"), "player-Realm")
      addon._FactoryInternal.InitializeFactorySecondaryRuntimeMethods(factoryCtx, modules)
      factoryCtx.SetLanguage("deDE")
      factoryCtx.SetLocaleTable({ LANG_SET_EN = "Manual" })
      factoryCtx.EnqueueInspect("party1")
      factoryCtx.CheckIfEnteredTargetDungeon()
    end)

    Assert.True(scans >= 3, "cd tracker scan path and ticker path must run")
    Assert.True(readyRefreshHits >= 2, "ready-check refresh must run during cd updates")
    Assert.True(killRefreshHits >= 1, "killtrack OnUpdate callback must refresh the row")
    Assert.True(nameplateRefreshHits >= 1, "killtrack OnUpdate callback must refresh nameplates")
    Assert.Equal(logfHits > 0, true, "runtime logf paths must be exercised")
    Assert.Equal(bloodlustHits, 1, "new lust activation must play the configured sound")
  end)
end
