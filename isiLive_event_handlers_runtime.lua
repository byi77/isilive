local _, addonTable = ...

addonTable = addonTable or {}

local RuntimeLifecycle = {}
addonTable.EventHandlersRuntimeLifecycle = RuntimeLifecycle

function RuntimeLifecycle.BuildHandlers(ctx)
  local function HandleGroupRosterUpdateEvent(_self)
    if ctx.isInGroup() and (ctx.isTestMode() or ctx.isTestAllMode()) then
      ctx.exitTestMode()
      return
    end

    ctx.handleGroupRosterUpdate()
  end

  local function HandleAddonLoadedEvent(_self, loadedAddon)
    if loadedAddon ~= ctx.addonName then
      return
    end

    IsiLiveDB = IsiLiveDB or {}
    IsiLiveDB.position = IsiLiveDB.position or { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    IsiLiveDB.locale = ctx.resolveLocaleTag(IsiLiveDB.locale or ctx.defaultLocale)
    ctx.setLocaleTable(ctx.locales[IsiLiveDB.locale] or ctx.locales.enUS)
    if IsiLiveDB.queueDebug == nil then
      IsiLiveDB.queueDebug = false
    end
    if IsiLiveDB.runtimeLogEnabled == nil then
      IsiLiveDB.runtimeLogEnabled = false
    end
    ctx.ensureQueueDebugStorage()
    ctx.setQueueDebugEnabled(IsiLiveDB.queueDebug)
    ctx.ensureRuntimeLogStorage()
    ctx.setRuntimeLogEnabled(IsiLiveDB.runtimeLogEnabled)
    ctx.restoreRioBaseline()

    local mainFrame = ctx.getMainFrame()
    local pos = IsiLiveDB.position
    if mainFrame and mainFrame.ClearAllPoints and mainFrame.SetPoint then
      mainFrame:ClearAllPoints()
      mainFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    end
    ctx.registerIsiLiveSyncPrefix()
    ctx.applyHotkeyBindings()
    ctx.startBindingWatchdog()
    ctx.applyLocalizationToUI()
    ctx.updateCountdownCancelButton()
    ctx.updateLeaderButtons()
  end

  local function HandlePlayerLoginEvent(_self)
    ctx.registerIsiLiveSyncPrefix()
    local playerName, playerRealm = ctx.getUnitNameAndRealm("player")
    ctx.markIsiLiveUser(playerName, playerRealm)
    ctx.applyHotkeyBindings()
    ctx.startBindingWatchdog()
  end

  local function HandlePlayerEnteringWorldEvent(_self)
    ctx.applyHotkeyBindings()
    ctx.startBindingWatchdog()
    if ctx.timerAfter then
      ctx.timerAfter(1, ctx.applyHotkeyBindings)
      ctx.timerAfter(3, ctx.applyHotkeyBindings)
    end
    ctx.sendOwnKeySnapshot(true)
    ctx.maybeShowNonMythicDungeonEntryNotice()
    ctx.updateStatusLine()
    ctx.checkIfEnteredTargetDungeon()

    local inPartyInstance = ctx.isInPartyInstance() and true or false
    local wasInPartyInstance = ctx.wasInPartyInstance
    ctx.wasInPartyInstance = inPartyInstance
    if wasInPartyInstance ~= nil and not wasInPartyInstance and inPartyInstance and not ctx.isInChallengeMode() then
      ctx.setMainFrameVisible(true)
    end
  end

  local function HandleUpdateBindingsEvent(_self)
    ctx.applyHotkeyBindings()
  end

  local function HandlePlayerRegenEnabledEvent(_self)
    if ctx.getPendingBindingApply() then
      ctx.applyHotkeyBindings()
    end
    local pendingMainFrameHeight = ctx.getPendingMainFrameHeight()
    if pendingMainFrameHeight then
      ctx.setMainFrameHeightSafe(pendingMainFrameHeight)
    end
    if ctx.isMainFrameShown() then
      ctx.updateMPlusTeleportButton()
      ctx.tryRestoreCenterNoticeTeleportButton()
    end
  end

  local function HandleInstanceContextChangedEvent(_self)
    ctx.updateStatusLine()
    ctx.maybeShowNonMythicDungeonEntryNotice()
    ctx.checkIfEnteredTargetDungeon()
  end

  local function HandleOwnedKeyContextEvent(_self)
    ctx.updateStatusLine()
    ctx.handleOwnedKeyRefresh()
    ctx.maybeShowNonMythicDungeonEntryNotice()
    ctx.checkIfEnteredTargetDungeon()
  end

  local function HandleInspectReadyEvent(_self, guid)
    if not ctx.isMainFrameShown() then
      return
    end

    if ctx.onInspectReady(guid) then
      ctx.updateUI()
    end
  end

  local function HandleChatMsgAddonEvent(_self, prefix, message, _channel, sender)
    local syncResult = ctx.processAddonMessage(prefix, message, sender)
    if not syncResult then
      return
    end

    if syncResult.shouldAck then
      ctx.sendAck(syncResult.sender)
    end

    local changed = false
    ctx.forEachRosterInfo(function(info)
      if not info.hasIsiLive and ctx.isSyncUserKnown(info.name, info.realm) then
        info.hasIsiLive = true
        changed = true
      end
      if ctx.applyKnownKeyToRosterEntry(info) then
        changed = true
      end
    end)
    if changed then
      ctx.updateUI()
    end
  end

  local function HandleSpellUpdateCooldownEvent(_self)
    ctx.updateMPlusTeleportButton()
  end

  return {
    GROUP_ROSTER_UPDATE = HandleGroupRosterUpdateEvent,
    ADDON_LOADED = HandleAddonLoadedEvent,
    PLAYER_LOGIN = HandlePlayerLoginEvent,
    PLAYER_ENTERING_WORLD = HandlePlayerEnteringWorldEvent,
    UPDATE_BINDINGS = HandleUpdateBindingsEvent,
    PLAYER_REGEN_ENABLED = HandlePlayerRegenEnabledEvent,
    PLAYER_DIFFICULTY_CHANGED = HandleInstanceContextChangedEvent,
    ZONE_CHANGED_NEW_AREA = HandleInstanceContextChangedEvent,
    UPDATE_INSTANCE_INFO = HandleInstanceContextChangedEvent,
    BAG_UPDATE_DELAYED = HandleOwnedKeyContextEvent,
    CHALLENGE_MODE_MAPS_UPDATE = HandleOwnedKeyContextEvent,
    INSPECT_READY = HandleInspectReadyEvent,
    CHAT_MSG_ADDON = HandleChatMsgAddonEvent,
    SPELL_UPDATE_COOLDOWN = HandleSpellUpdateCooldownEvent,
  }
end
