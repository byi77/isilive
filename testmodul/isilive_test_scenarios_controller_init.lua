return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  test("ControllerInit wires getDungeonName into the roster panel controller", function()
    local capturedRosterOpts = nil
    local capturedTeleportOpts = nil
    local dragGripVisible = nil

    local addon = LoadAddonModules({ "isiLive_controller_init.lua" })
    local result = addon.ControllerInit.CreateControllers({
      sync = {
        MarkUser = function() end,
        IsUnitKnown = function()
          return false
        end,
        RegisterPrefix = function() end,
        SendHello = function() end,
        SendKey = function() end,
        SendStats = function() end,
        SendDps = function() end,
        SendLoc = function() end,
        SendRefreshRequest = function() end,
        SendLibKeystoneRequest = function() end,
        SendLibKeystonePartyData = function() end,
        GetPlayerKeyInfo = function() end,
        GetPlayerStatsInfo = function() end,
        GetPlayerDpsInfo = function() end,
        GetPlayerLocInfo = function() end,
        SetPlayerKeyInfo = function() end,
        GetProtocolVersion = function()
          return 2
        end,
      },
      keySyncModule = {
        CreateController = function()
          return {
            MarkIsiLiveUser = function() end,
            UnitHasIsiLive = function()
              return false
            end,
            RegisterIsiLiveSyncPrefix = function() end,
            SendIsiLiveHello = function() end,
            SendRefreshRequest = function() end,
            SendLibKeystonePartyData = function() end,
            GetOwnedKeystoneSnapshot = function() end,
            SendOwnKeySnapshot = function() end,
            SendRefreshResponse = function() end,
            ApplyKnownKeyToRosterEntry = function()
              return false
            end,
          }
        end,
      },
      highlightModule = {
        CreateController = function()
          return {}
        end,
      },
      rosterPanelModule = {
        CreateController = function(opts)
          capturedRosterOpts = opts
          return {
            ApplyLocalization = function() end,
            GetRefreshButton = function()
              return {}
            end,
            GetCountdownCancelButton = function()
              return {}
            end,
            GetStatusLine = function()
              return {}
            end,
            SetCollapseChangedHandler = function() end,
            SetLayoutChangedHandler = function() end,
            GetLayoutMode = function()
              return "expanded"
            end,
            IsCollapsed = function()
              return false
            end,
          }
        end,
      },
      teleportUIModule = {
        CreateController = function(opts)
          capturedTeleportOpts = opts
          return {
            BuildButtons = function() end,
            GetButtons = function()
              return {}
            end,
            SetLayoutMode = function() end,
            SetVisible = function() end,
          }
        end,
      },
      statsModule = {
        CreateController = function()
          return {
            GetPlayerLastRunDps = function() end,
            RecordRun = function() end,
          }
        end,
      },
      getRoster = function()
        return {}
      end,
      getUnitNameAndRealm = function()
        return "Me", "Realm"
      end,
      getAddonVersionRaw = function()
        return "0.9.106"
      end,
      isFrameVisible = function()
        return true
      end,
      canRespondToRefreshRequest = function()
        return true
      end,
      resolveTeleportSpellIDByMapID = function() end,
      resolveMapIDByActivityID = function() end,
      mainUI = {
        SetDragGripVisible = function(visible)
          dragGripVisible = visible
        end,
      },
      mainFrame = {},
      getL = function()
        return {}
      end,
      isPlayerLeader = function()
        return true
      end,
      getAddonVersionText = function()
        return "V.0.9.106"
      end,
      getUnitRio = function() end,
      updateStatusLine = function() end,
      setMainFrameHeightSafe = function() end,
      setMainFrameWidthSafe = function() end,
      minFrameHeight = 100,
      buildOrderedRoster = function()
        return {}
      end,
      hasFullSync = function()
        return false
      end,
      buildDisplayData = function()
        return {}
      end,
      truncateName = function(value)
        return value
      end,
      getShortSpecLabel = function(value)
        return value
      end,
      getLanguageFlagMarkup = function()
        return ""
      end,
      getLanguageTooltipMarkup = function()
        return ""
      end,
      getDungeonShortCode = function()
        return "AA"
      end,
      getDungeonName = function()
        return "Akademie von Algeth'ar"
      end,
      getRioDelta = function() end,
      getPlayerSyncSummary = function() end,
      resolveActiveKeyOwnerUnit = function() end,
      resolveTargetMapID = function() end,
      isReadyCheckActive = function()
        return false
      end,
      isInGroup = function()
        return true
      end,
      isRaidGroup = function()
        return false
      end,
      getTime = function()
        return 0
      end,
      shareKeysDebounceSeconds = 1,
      applySecureSpellToButton = function() end,
      getEntries = function()
        return {}
      end,
      isSpellKnown = function()
        return false
      end,
      getTeleportCooldownRemaining = function()
        return 0
      end,
      formatCooldownSeconds = function()
        return "0"
      end,
      getSpellCooldownSafe = function()
        return 0, 0, true
      end,
      applyCooldownFrameSafe = function() end,
      getSpellTexture = function() end,
      getTeleportEmptyStateText = function() end,
    })

    Assert.NotNil(result.rosterPanelController, "controller init should create the roster panel controller")
    Assert.NotNil(capturedRosterOpts, "roster panel controller should receive an options table")
    Assert.Equal(
      capturedRosterOpts.getDungeonName and capturedRosterOpts.getDungeonName(402),
      "Akademie von Algeth'ar",
      "controller init must pass getDungeonName through to the roster panel controller"
    )
    Assert.NotNil(capturedTeleportOpts, "teleport UI controller should receive an options table")
    Assert.Equal(
      capturedTeleportOpts.getDungeonName and capturedTeleportOpts.getDungeonName(558, "enUS"),
      "Akademie von Algeth'ar",
      "controller init must pass getDungeonName through to the teleport UI controller"
    )
    Assert.True(dragGripVisible, "expanded layout should keep drag grip lines visible")
  end)
end
