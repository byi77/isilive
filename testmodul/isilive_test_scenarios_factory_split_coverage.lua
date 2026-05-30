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

    local factoryCtx = {
      GetL = function()
        return {
          COMBAT_CHAT_BR_USED = "%s used BR",
          COMBAT_CHAT_LUST_STARTED = "%s started Lust",
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
    end)

    Assert.Equal(prints[1], "? used BR", "missing caster must render a placeholder")
    Assert.Equal(prints[2], "Mage started Lust", "realm suffix must be stripped from lust caster")
    Assert.Equal(prints[3], "Druid used BR", "broadcast path must also render locally")
    Assert.Equal(brSounds, 2, "BR sound must fire for BR local and broadcast render")
    Assert.Equal(lustSounds, 1, "lust sound must fire for lust render")
    Assert.Equal(sent.spellID, 20484, "broadcast path must send the combat announce payload")
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

      factoryCtx.UpdateCdTracker()
      lustInfo = { remain = 12 }
      factoryCtx.UpdateCdTracker({ playLustSoundOnStart = true })
      raidMode = true
      factoryCtx.UpdateCdTracker()
      raidMode = false

      runningTimer = true
      factoryCtx.addonTable.MplusTimer = {
        GetTimerData = function()
          return { running = runningTimer }
        end,
      }
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
