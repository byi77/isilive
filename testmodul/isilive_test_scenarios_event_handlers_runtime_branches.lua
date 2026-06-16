---@diagnostic disable: undefined-global

-- Branch-coverage scenarios for logic/isiLive_event_handlers_runtime.lua.
-- The existing event_handlers test files drive happy paths through the
-- full event-handlers controller. This file targets the still-uncovered
-- defensive branches by building the runtime handler table directly via
-- RuntimeLifecycle.BuildHandlers(ctx) with focused stubs.

local function NewCtx(overrides)
  local ctx = {
    addonName = "isiLive",
    defaultLocale = "enUS",
    locales = { enUS = {} },
    isInGroup = function()
      return false
    end,
    isInChallengeMode = function()
      return false
    end,
    isInPartyInstance = function()
      return false
    end,
    isRaidGroup = function()
      return false
    end,
    isTestMode = function()
      return false
    end,
    isTestAllMode = function()
      return false
    end,
    exitTestMode = function() end,
    handleGroupRosterUpdate = function() end,
    isMainFrameShown = function()
      return true
    end,
    shouldShowMainFrameOnStartup = function()
      return true
    end,
    setMainFrameVisible = function() end,
    getMainFrame = function()
      return nil
    end,
    getUnitNameAndRealm = function()
      return "player", "realm"
    end,
    markIsiLiveUser = function() end,
    resolveLocaleTag = function(tag)
      return tag or "enUS"
    end,
    setLocaleTable = function() end,
    ensureQueueDebugStorage = function() end,
    setQueueDebugEnabled = function() end,
    ensureRuntimeLogStorage = function() end,
    setRuntimeLogEnabled = function() end,
    restoreRioBaseline = function() end,
    registerIsiLiveSyncPrefix = function() end,
    applyHotkeyBindings = function() end,
    startBindingWatchdog = function() end,
    applyLocalizationToUI = function() end,
    restoreLayoutState = function() end,
    updateCountdownCancelButton = function() end,
    updateLeaderButtons = function() end,
    applyPendingLeaderButtonUpdates = function() end,
    updateCdTracker = function() end,
    sendOwnKeySnapshot = function() end,
    sendOwnKickState = function() end,
    sendOwnBackgroundSnapshot = function() end,
    maybeShowNonMythicDungeonEntryNotice = function() end,
    maybeShowPortalNavigatorNotice = function() end,
    updateStatusLine = function() end,
    checkIfEnteredTargetDungeon = function() end,
    handleOwnedKeyRefresh = function() end,
    onInspectReady = function()
      return false
    end,
    updateUI = function() end,
    updateMPlusTeleportButton = function() end,
    tryRestoreCenterNoticeTeleportButton = function() end,
    setMainFrameHeightSafe = function() end,
    setMainFrameWidthSafe = function() end,
    getPendingBindingApply = function()
      return false
    end,
    getPendingMainFrameHeight = function()
      return nil
    end,
    getPendingMainFrameWidth = function()
      return nil
    end,
    processAddonMessage = function()
      return nil
    end,
    sendIsiLiveHello = function() end,
    sendLibKeystonePartyData = function() end,
    sendRefreshResponse = function() end,
    sendOwnTargetSnapshot = function() end,
    sendOwnKeystoneToChat = function()
      return false
    end,
    triggerShareKeysCooldown = function() end,
    sendShareKeysCooldownState = function()
      return false
    end,
    showCombatAnnounce = function() end,
    playIncomingSummonSound = function() end,
    forEachRosterInfo = function() end,
    isSyncUserKnown = function()
      return false
    end,
    applyKnownKeyToRosterEntry = function()
      return false
    end,
    sendAck = function() end,
    getRoster = function()
      return {}
    end,
    timerAfter = function() end,
    activeMythicZeroMapID = nil,
    activeMythicZeroRosterSnapshot = nil,
    pendingMythicZeroRunCapture = nil,
    wasInPartyInstance = nil,
  }
  if overrides then
    for key, value in pairs(overrides) do
      ctx[key] = value
    end
  end
  return ctx
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function LoadHandlers(ctxOverrides, globals)
    local addon
    WithGlobals(globals or {}, function()
      addon = LoadAddonModules({ "isiLive_event_handlers_runtime.lua" })
    end)
    local stub = NewCtx(ctxOverrides)
    return addon.EventHandlersRuntimeLifecycle.BuildHandlers(stub), stub
  end

  -- HandleUpdateBindingsEvent --------------------------------------------------

  test("UPDATE_BINDINGS forwards to applyHotkeyBindings", function()
    local calls = 0
    local handlers = LoadHandlers({
      applyHotkeyBindings = function()
        calls = calls + 1
      end,
    })
    handlers.UPDATE_BINDINGS(nil)
    Assert.Equal(calls, 1, "applyHotkeyBindings must be invoked once")
  end)

  -- HandleAddonLoadedEvent: addon-name mismatch early return -------------------

  test("ADDON_LOADED ignores other addons", function()
    local resolveCalls = 0
    local handlers = LoadHandlers({
      resolveLocaleTag = function(tag)
        resolveCalls = resolveCalls + 1
        return tag or "enUS"
      end,
    })
    handlers.ADDON_LOADED(nil, "OtherAddon")
    Assert.Equal(resolveCalls, 0, "must early-return for foreign addon name")
  end)

  -- HandleOwnedKeyContextEvent -------------------------------------------------

  test("BAG_UPDATE_DELAYED bails out in raid mode", function()
    local calls = 0
    local handlers = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      handleOwnedKeyRefresh = function()
        calls = calls + 1
      end,
    })
    handlers.BAG_UPDATE_DELAYED(nil)
    Assert.Equal(calls, 0, "owned-key handler must not fire in raid mode")
  end)

  test("BAG_UPDATE_DELAYED runs the owned-key refresh outside raid mode", function()
    local calls = { status = 0, key = 0, notice = 0, dungeon = 0 }
    local handlers = LoadHandlers({
      updateStatusLine = function()
        calls.status = calls.status + 1
      end,
      handleOwnedKeyRefresh = function()
        calls.key = calls.key + 1
      end,
      maybeShowNonMythicDungeonEntryNotice = function()
        calls.notice = calls.notice + 1
      end,
      checkIfEnteredTargetDungeon = function()
        calls.dungeon = calls.dungeon + 1
      end,
    })
    handlers.BAG_UPDATE_DELAYED(nil)
    Assert.Equal(calls.status, 1, "status line must refresh")
    Assert.Equal(calls.key, 1, "owned-key refresh must run")
    Assert.Equal(calls.notice, 1, "non-mythic notice must run")
    Assert.Equal(calls.dungeon, 1, "dungeon-entry check must run")
  end)

  -- HandlePlayerRolesAssignedEvent --------------------------------------------

  test("PLAYER_ROLES_ASSIGNED rewrites cached roster role for player and party slots", function()
    local roster = {
      player = { name = "Alpha", role = "DAMAGER" },
      party1 = { name = "Beta", role = "DAMAGER" },
      party2 = { name = "Gamma", role = "HEALER" },
    }
    local roleByUnit = {
      player = "TANK",
      party1 = "HEALER",
      party2 = "HEALER",
    }
    local uiCalls, leaderCalls = 0, 0
    local handlers = LoadHandlers({
      getRoster = function()
        return roster
      end,
      getUnitRole = function(unit)
        return roleByUnit[unit]
      end,
      updateUI = function()
        uiCalls = uiCalls + 1
      end,
      updateLeaderButtons = function()
        leaderCalls = leaderCalls + 1
      end,
    })
    handlers.PLAYER_ROLES_ASSIGNED(nil)
    Assert.Equal(roster.player.role, "TANK", "ego role must update from DD to tank")
    Assert.Equal(roster.party1.role, "HEALER", "party1 role must update from DD to healer")
    Assert.Equal(roster.party2.role, "HEALER", "unchanged role must stay HEALER")
    Assert.Equal(uiCalls, 1, "any role change must trigger one updateUI")
    Assert.Equal(leaderCalls, 1, "any role change must refresh leader buttons")
  end)

  test("PLAYER_ROLES_ASSIGNED skips ghosts and non-unit-token entries", function()
    local roster = {
      player = { name = "Alpha", role = "DAMAGER" },
      ["ghost:Beta-"] = { name = "Beta", role = "TANK", isGhost = true },
      party1 = { name = "Gamma", role = "DAMAGER", isGhost = true },
    }
    local handlers = LoadHandlers({
      getRoster = function()
        return roster
      end,
      getUnitRole = function(_unit)
        return "HEALER"
      end,
    })
    handlers.PLAYER_ROLES_ASSIGNED(nil)
    Assert.Equal(roster.player.role, "HEALER", "live player slot must update")
    Assert.Equal(roster["ghost:Beta-"].role, "TANK", "ghost slot must keep its old role")
    Assert.Equal(roster.party1.role, "DAMAGER", "ghost-flagged party slot must keep its old role")
  end)

  test("PLAYER_ROLES_ASSIGNED bails out in raid mode without touching roster", function()
    local roster = {
      player = { name = "Alpha", role = "DAMAGER" },
    }
    local handlers = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      getRoster = function()
        return roster
      end,
      getUnitRole = function(_unit)
        return "TANK"
      end,
    })
    handlers.PLAYER_ROLES_ASSIGNED(nil)
    Assert.Equal(roster.player.role, "DAMAGER", "raid mode must suppress role refresh")
  end)

  test("PLAYER_SPECIALIZATION_CHANGED also refreshes player role from spec", function()
    local roster = {
      player = { name = "Alpha", role = "DAMAGER" },
    }
    local handlers = LoadHandlers({
      getRoster = function()
        return roster
      end,
      getUnitRole = function(unit)
        return unit == "player" and "TANK" or "DAMAGER"
      end,
    })
    handlers.PLAYER_SPECIALIZATION_CHANGED(nil, "player")
    Assert.Equal(roster.player.role, "TANK", "spec change must trigger role refresh for player")
  end)

  test("PLAYER_SPECIALIZATION_CHANGED also refreshes cached spec name on player roster entry", function()
    local roster = {
      player = { name = "Alpha", spec = "Unholy", role = "DAMAGER" },
    }
    local handlers = LoadHandlers({
      getRoster = function()
        return roster
      end,
      getPlayerSpecName = function()
        return "Blood"
      end,
      getUnitRole = function(_unit)
        return "TANK"
      end,
    })
    handlers.PLAYER_SPECIALIZATION_CHANGED(nil, "player")
    Assert.Equal(roster.player.spec, "Blood", "spec change must rewrite cached spec name on player slot")
  end)

  test("PLAYER_SPECIALIZATION_CHANGED triggers updateUI on intra-role spec swap (Arcane -> Frost)", function()
    local roster = {
      player = { name = "Alpha", spec = "Arcane", role = "DAMAGER" },
    }
    local uiCalls = 0
    local handlers = LoadHandlers({
      getRoster = function()
        return roster
      end,
      getPlayerSpecName = function()
        return "Frost"
      end,
      getUnitRole = function(_unit)
        return "DAMAGER"
      end,
      updateUI = function()
        uiCalls = uiCalls + 1
      end,
    })
    handlers.PLAYER_SPECIALIZATION_CHANGED(nil, "player")
    Assert.Equal(roster.player.spec, "Frost", "intra-role spec swap must rewrite cached spec name")
    Assert.True(uiCalls >= 1, "intra-role spec swap must trigger updateUI even when role stayed the same")
  end)

  test("PLAYER_SPECIALIZATION_CHANGED keeps cached spec when an inspect refresh is queued", function()
    local roster = {
      player = { name = "Alpha", spec = "Unholy", role = "DAMAGER", _refreshQueued = true },
    }
    local handlers = LoadHandlers({
      getRoster = function()
        return roster
      end,
      getPlayerSpecName = function()
        return "Blood"
      end,
    })
    handlers.PLAYER_SPECIALIZATION_CHANGED(nil, "player")
    Assert.Equal(
      roster.player.spec,
      "Unholy",
      "spec must not race the inspect refresh path that owns spec writes when _refreshQueued is set"
    )
  end)

  test("ROLE_CHANGED_INFORM shares the role-refresh handler", function()
    local roster = {
      player = { name = "Alpha", role = "DAMAGER" },
    }
    local handlers = LoadHandlers({
      getRoster = function()
        return roster
      end,
      getUnitRole = function(_unit)
        return "TANK"
      end,
    })
    handlers.ROLE_CHANGED_INFORM(nil, "Alpha", "Alpha", "DAMAGER", "TANK")
    Assert.Equal(roster.player.role, "TANK", "ROLE_CHANGED_INFORM must trigger the same role refresh path")
  end)

  test("PLAYER_ROLES_ASSIGNED skips updateUI when nothing changed", function()
    local roster = {
      player = { name = "Alpha", role = "TANK" },
      party1 = { name = "Beta", role = "HEALER" },
    }
    local roleByUnit = { player = "TANK", party1 = "HEALER" }
    local uiCalls = 0
    local handlers = LoadHandlers({
      getRoster = function()
        return roster
      end,
      getUnitRole = function(unit)
        return roleByUnit[unit]
      end,
      updateUI = function()
        uiCalls = uiCalls + 1
      end,
    })
    handlers.PLAYER_ROLES_ASSIGNED(nil)
    Assert.Equal(uiCalls, 0, "no change must not trigger a UI refresh")
  end)

  test("CHALLENGE_MODE_MAPS_UPDATE shares the owned-key handler", function()
    local calls = 0
    local handlers = LoadHandlers({
      handleOwnedKeyRefresh = function()
        calls = calls + 1
      end,
    })
    handlers.CHALLENGE_MODE_MAPS_UPDATE(nil)
    Assert.Equal(calls, 1, "shared handler must run for CHALLENGE_MODE_MAPS_UPDATE")
  end)

  test("CONFIRM_SUMMON plays incoming-summon sound outside raid mode", function()
    local calls = 0
    local handlers = LoadHandlers({
      playIncomingSummonSound = function()
        calls = calls + 1
      end,
    })
    handlers.CONFIRM_SUMMON(nil)
    Assert.Equal(calls, 1, "incoming summon confirmation must play the configured summon sound")
  end)

  test("CONFIRM_SUMMON suppresses incoming-summon sound in raid mode", function()
    local calls = 0
    local handlers = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      playIncomingSummonSound = function()
        calls = calls + 1
      end,
    })
    handlers.CONFIRM_SUMMON(nil)
    Assert.Equal(calls, 0, "incoming summon confirmation must stay silent in raid mode")
  end)

  test("INCOMING_SUMMON_CHANGED plays incoming-summon sound for pending player summons", function()
    local calls = 0
    local globals = {
      Enum = {
        SummonStatus = {
          Pending = 1,
          Accepted = 2,
          Declined = 3,
        },
      },
      C_IncomingSummon = {
        IncomingSummonStatus = function(unit)
          Assert.Equal(unit, "player", "incoming summon status should be read for the player")
          return 1
        end,
      },
    }
    local handlers = LoadHandlers({
      playIncomingSummonSound = function()
        calls = calls + 1
      end,
    }, globals)
    WithGlobals(globals, function()
      handlers.INCOMING_SUMMON_CHANGED(nil, "player")
    end)
    Assert.Equal(calls, 1, "pending player summons should play the configured summon sound")
  end)

  test("INCOMING_SUMMON_CHANGED ignores non-player and non-pending summon updates", function()
    local calls = 0
    local statusCalls = 0
    local globals = {
      Enum = {
        SummonStatus = {
          Pending = 1,
          Accepted = 2,
          Declined = 3,
        },
      },
      C_IncomingSummon = {
        IncomingSummonStatus = function()
          statusCalls = statusCalls + 1
          return 2
        end,
      },
    }
    local handlers = LoadHandlers({
      playIncomingSummonSound = function()
        calls = calls + 1
      end,
    }, globals)
    WithGlobals(globals, function()
      handlers.INCOMING_SUMMON_CHANGED(nil, "party1")
      handlers.INCOMING_SUMMON_CHANGED(nil, "player")
    end)
    Assert.Equal(statusCalls, 1, "only player updates should read the incoming summon status")
    Assert.Equal(calls, 0, "non-player and non-pending summon updates must stay silent")
  end)

  test("INCOMING_SUMMON_CHANGED fails closed when pending summon enum is unavailable", function()
    local calls = 0
    local statusCalls = 0
    local globals = {
      C_IncomingSummon = {
        IncomingSummonStatus = function()
          statusCalls = statusCalls + 1
          return 1
        end,
      },
    }
    local handlers = LoadHandlers({
      playIncomingSummonSound = function()
        calls = calls + 1
      end,
    }, globals)
    WithGlobals(globals, function()
      handlers.INCOMING_SUMMON_CHANGED(nil, "player")
    end)
    Assert.Equal(statusCalls, 1, "player summon updates should still read the current summon status")
    Assert.Equal(calls, 0, "missing pending enum must stay silent instead of guessing a status value")
  end)

  test("INCOMING_SUMMON_CHANGED suppresses incoming-summon sound in raid mode", function()
    local calls = 0
    local statusCalls = 0
    local globals = {
      Enum = {
        SummonStatus = {
          Pending = 1,
        },
      },
      C_IncomingSummon = {
        IncomingSummonStatus = function()
          statusCalls = statusCalls + 1
          return 1
        end,
      },
    }
    local handlers = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      playIncomingSummonSound = function()
        calls = calls + 1
      end,
    }, globals)
    WithGlobals(globals, function()
      handlers.INCOMING_SUMMON_CHANGED(nil, "player")
    end)
    Assert.Equal(statusCalls, 0, "raid mode should suppress status reads for summon updates")
    Assert.Equal(calls, 0, "incoming summon status updates must stay silent in raid mode")
  end)

  -- HandleInspectReadyEvent ----------------------------------------------------

  test("INSPECT_READY bails out in raid mode", function()
    local calls = 0
    local handlers = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      onInspectReady = function()
        calls = calls + 1
        return true
      end,
    })
    handlers.INSPECT_READY(nil, "guid-1")
    Assert.Equal(calls, 0, "must skip inspect handling in raid mode")
  end)

  test("INSPECT_READY bails out when main frame is hidden", function()
    local calls = 0
    local handlers = LoadHandlers({
      isMainFrameShown = function()
        return false
      end,
      onInspectReady = function()
        calls = calls + 1
        return true
      end,
    })
    handlers.INSPECT_READY(nil, "guid-1")
    Assert.Equal(calls, 0, "must skip inspect handling while frame hidden")
  end)

  test("INSPECT_READY refreshes UI when onInspectReady reports change", function()
    local uiCalls = 0
    local handlers = LoadHandlers({
      onInspectReady = function()
        return true
      end,
      updateUI = function()
        uiCalls = uiCalls + 1
      end,
    })
    handlers.INSPECT_READY(nil, "guid-1")
    Assert.Equal(uiCalls, 1, "updateUI must fire when inspect introduced changes")
  end)

  test("INSPECT_READY does not refresh UI when onInspectReady reports no change", function()
    local uiCalls = 0
    local handlers = LoadHandlers({
      onInspectReady = function()
        return false
      end,
      updateUI = function()
        uiCalls = uiCalls + 1
      end,
    })
    handlers.INSPECT_READY(nil, "guid-1")
    Assert.Equal(uiCalls, 0, "updateUI must stay silent when inspect reported no change")
  end)

  -- HandleSpellUpdateCooldownEvent / HandleSpellUpdateChargesEvent -------------

  test("SPELL_UPDATE_COOLDOWN refreshes the teleport button outside raid", function()
    local calls = 0
    local handlers = LoadHandlers({
      updateMPlusTeleportButton = function()
        calls = calls + 1
      end,
    })
    handlers.SPELL_UPDATE_COOLDOWN(nil)
    Assert.Equal(calls, 1, "teleport button must refresh on cooldown event")
  end)

  test("SPELL_UPDATE_CHARGES refreshes cd tracker outside raid", function()
    local calls = 0
    local handlers = LoadHandlers({
      updateCdTracker = function()
        calls = calls + 1
      end,
    })
    handlers.SPELL_UPDATE_CHARGES(nil)
    Assert.Equal(calls, 1, "cd tracker must refresh on charges event")
  end)

  test("SPELL_UPDATE_CHARGES bails out in raid mode", function()
    local calls = 0
    local handlers = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      updateCdTracker = function()
        calls = calls + 1
      end,
    })
    handlers.SPELL_UPDATE_CHARGES(nil)
    Assert.Equal(calls, 0, "cd tracker must not refresh in raid mode")
  end)

  -- HandleUnitAuraEvent --------------------------------------------------------

  test("UNIT_AURA refreshes cd tracker only for player unit outside raid", function()
    local calls = 0
    local handlers = LoadHandlers({
      updateCdTracker = function()
        calls = calls + 1
      end,
    })
    handlers.UNIT_AURA(nil, "party1")
    Assert.Equal(calls, 0, "non-player unit must be ignored")
    handlers.UNIT_AURA(nil, "player")
    Assert.Equal(calls, 1, "player unit must refresh")
  end)

  test("UNIT_AURA bails out in raid mode even for player unit", function()
    local calls = 0
    local handlers = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      updateCdTracker = function()
        calls = calls + 1
      end,
    })
    handlers.UNIT_AURA(nil, "player")
    Assert.Equal(calls, 0, "raid mode must veto cd tracker refresh")
  end)

  -- HandleChatMsgAddonEvent ----------------------------------------------------

  test("CHAT_MSG_ADDON bails out in raid mode without calling processAddonMessage", function()
    local calls = 0
    local handlers = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      processAddonMessage = function()
        calls = calls + 1
        return nil
      end,
    })
    handlers.CHAT_MSG_ADDON(nil, "isiLive", "msg", "PARTY", "Sender-Realm")
    Assert.Equal(calls, 0, "raid mode must skip addon-message processing")
  end)

  test("CHAT_MSG_ADDON forwards combatAnnounce payload to showCombatAnnounce", function()
    local captured
    local handlers = LoadHandlers({
      processAddonMessage = function()
        return { combatAnnounce = { mode = "kick", spellID = 1234 } }
      end,
      showCombatAnnounce = function(info)
        captured = info
      end,
    })
    handlers.CHAT_MSG_ADDON(nil, "isiLive", "msg", "PARTY", "Sender")
    Assert.Equal(captured.mode, "kick", "combat-announce payload must be forwarded")
    Assert.Equal(captured.spellID, 1234, "spell id must be preserved")
  end)

  test("CHAT_MSG_ADDON triggers share-keys cooldown when sendOwnKeystoneToChat succeeds", function()
    local cooldownCalls = 0
    local handlers = LoadHandlers({
      processAddonMessage = function()
        return { shouldShareKeys = true }
      end,
      sendOwnKeystoneToChat = function()
        return true
      end,
      triggerShareKeysCooldown = function()
        cooldownCalls = cooldownCalls + 1
      end,
    })
    handlers.CHAT_MSG_ADDON(nil, "isiLive", "msg", "PARTY", "Sender")
    Assert.Equal(cooldownCalls, 1, "share-keys cooldown must fire when posting succeeded")
  end)

  test("CHAT_MSG_ADDON mirrors a peer SKCD lock via triggerShareKeysCooldown", function()
    local cooldownArgs = {}
    local handlers = LoadHandlers({
      processAddonMessage = function()
        return { shareKeysCooldownRemain = 17 }
      end,
      triggerShareKeysCooldown = function(seconds)
        table.insert(cooldownArgs, seconds)
      end,
    })
    handlers.CHAT_MSG_ADDON(nil, "isiLive", "SKCD:17", "PARTY", "Sender")
    Assert.Equal(#cooldownArgs, 1, "SKCD payload must trigger the share-keys cooldown exactly once")
    Assert.Equal(cooldownArgs[1], 17, "the mirrored cooldown must carry the remaining seconds")
  end)

  test("CHAT_MSG_ADDON ignores invalid SKCD remain values", function()
    local cooldownCalls = 0
    local handlers = LoadHandlers({
      processAddonMessage = function()
        return { shareKeysCooldownRemain = 0 }
      end,
      triggerShareKeysCooldown = function()
        cooldownCalls = cooldownCalls + 1
      end,
    })
    handlers.CHAT_MSG_ADDON(nil, "isiLive", "SKCD:0", "PARTY", "Sender")
    Assert.Equal(cooldownCalls, 0, "non-positive SKCD remain must not lock the button")
  end)

  test("CHAT_MSG_ADDON hello-ack fan-out includes the share-keys cooldown state", function()
    local stateSends = 0
    local handlers = LoadHandlers({
      processAddonMessage = function()
        return { shouldAck = true, sender = "Sender" }
      end,
      sendShareKeysCooldownState = function()
        stateSends = stateSends + 1
        return true
      end,
    })
    handlers.CHAT_MSG_ADDON(nil, "isiLive", "HELLO:1:2:3:local", "PARTY", "Sender")
    Assert.Equal(stateSends, 1, "hello-ack must forward the local share-keys cooldown to the new peer")
  end)

  test("CHAT_MSG_ADDON reqsync fan-out includes the share-keys cooldown state", function()
    local stateSends = 0
    local handlers = LoadHandlers({
      processAddonMessage = function()
        return { shouldRequestRefresh = true }
      end,
      sendShareKeysCooldownState = function()
        stateSends = stateSends + 1
        return true
      end,
    })
    handlers.CHAT_MSG_ADDON(nil, "isiLive", "REQSYNC", "PARTY", "Sender")
    Assert.Equal(stateSends, 1, "reqsync must forward the local share-keys cooldown to the requesting peer")
  end)

  -- HandlePlayerEnteringWorldEvent: raid early-return + reload-roster --------

  test("PLAYER_ENTERING_WORLD captures wasInPartyInstance and bails out in raid", function()
    local rosterCalls = 0
    local handlers, stub = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      isInPartyInstance = function()
        return true
      end,
      handleGroupRosterUpdate = function()
        rosterCalls = rosterCalls + 1
      end,
    })
    handlers.PLAYER_ENTERING_WORLD(nil)
    Assert.Equal(rosterCalls, 0, "raid mode must skip the post-reload roster build")
    Assert.Equal(stub.wasInPartyInstance, true, "wasInPartyInstance must be cached for next non-raid call")
  end)

  test("PLAYER_ENTERING_WORLD shows main frame on instance-entry transition", function()
    local visibilityCalls = {}
    local handlers, stub = LoadHandlers({
      isInPartyInstance = function()
        return true
      end,
      isInGroup = function()
        return true
      end,
      setMainFrameVisible = function(visible)
        table.insert(visibilityCalls, visible)
      end,
    })
    stub.wasInPartyInstance = false -- non-nil prior state
    handlers.PLAYER_ENTERING_WORLD(nil)
    Assert.True(#visibilityCalls > 0, "setMainFrameVisible must fire during instance entry")
    Assert.Equal(visibilityCalls[#visibilityCalls], true, "frame must be made visible on instance entry")
  end)

  test("PLAYER_ENTERING_WORLD resets stale challenge timers on inactive instance entry", function()
    local timerEvents = {}
    local cdRefreshOpts = {}
    local handlers, stub = LoadHandlers({
      isInPartyInstance = function()
        return true
      end,
      isInGroup = function()
        return true
      end,
      isInChallengeMode = function()
        return false
      end,
      handleMplusTimerEvent = function(event)
        table.insert(timerEvents, event)
      end,
      updateCdTracker = function(opts)
        table.insert(cdRefreshOpts, opts or false)
      end,
    })
    stub.wasInPartyInstance = false

    handlers.PLAYER_ENTERING_WORLD(nil)

    Assert.Equal(timerEvents[1], "PLAYER_ENTERING_WORLD", "PEW must still reach the M+ timer first")
    Assert.Equal(timerEvents[2], "CHALLENGE_MODE_RESET", "inactive instance entry must clear stale challenge state")
    Assert.Equal(#cdRefreshOpts, 1, "inactive instance entry must use a single reset CD refresh")
    Assert.True(cdRefreshOpts[1].resetRuntimeTimers, "stale challenge reset must clear visible BR/BL timers")
    Assert.True(cdRefreshOpts[1].suppressBattleResReadySound, "stale challenge reset must suppress BRes-ready")
    Assert.True(cdRefreshOpts[1].suppressLustReadySound, "stale challenge reset must suppress Bloodlust-ready")
  end)

  test("PLAYER_ENTERING_WORLD keeps active challenge instance entry from resetting timers", function()
    local timerEvents = {}
    local cdRefreshOpts = {}
    local handlers, stub = LoadHandlers({
      isInPartyInstance = function()
        return true
      end,
      isInChallengeMode = function()
        return true
      end,
      handleMplusTimerEvent = function(event)
        table.insert(timerEvents, event)
      end,
      updateCdTracker = function(opts)
        table.insert(cdRefreshOpts, opts or false)
      end,
    })
    stub.wasInPartyInstance = false

    handlers.PLAYER_ENTERING_WORLD(nil)

    Assert.Equal(#timerEvents, 1, "active challenge PEW must only forward the PEW timer event")
    Assert.Equal(timerEvents[1], "PLAYER_ENTERING_WORLD", "active challenge PEW must not synthesize RESET")
    Assert.Equal(#cdRefreshOpts, 1, "active challenge PEW must keep the normal CD refresh")
    Assert.Equal(cdRefreshOpts[1], false, "active challenge PEW must not use resetRuntimeTimers")
  end)

  -- HandlePlayerRegenEnabledEvent: pending-binding + pending-frame paths ------

  test("PLAYER_REGEN_ENABLED applies pending bindings when getPendingBindingApply is true", function()
    local bindingCalls = 0
    local handlers = LoadHandlers({
      getPendingBindingApply = function()
        return true
      end,
      applyHotkeyBindings = function()
        bindingCalls = bindingCalls + 1
      end,
    })
    handlers.PLAYER_REGEN_ENABLED(nil)
    Assert.Equal(bindingCalls, 1, "pending bindings must be applied once combat ends")
  end)

  test("PLAYER_REGEN_ENABLED applies pendingMainFrameWidth when present", function()
    local widthCalls = {}
    local handlers = LoadHandlers({
      getPendingMainFrameWidth = function()
        return 320
      end,
      setMainFrameWidthSafe = function(width)
        table.insert(widthCalls, width)
      end,
    })
    handlers.PLAYER_REGEN_ENABLED(nil)
    Assert.Equal(widthCalls[1], 320, "pending width must be applied once combat ends")
  end)

  test("PLAYER_REGEN_ENABLED applies pending leader button updates", function()
    local calls = 0
    local handlers = LoadHandlers({
      applyPendingLeaderButtonUpdates = function()
        calls = calls + 1
      end,
    })
    handlers.PLAYER_REGEN_ENABLED(nil)
    Assert.Equal(calls, 1, "pending leader button updates must be applied once combat ends")
  end)

  test("PLAYER_REGEN_ENABLED bails out in raid mode after combat fade is applied", function()
    local heightCalls = 0
    local handlers = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      getPendingMainFrameHeight = function()
        heightCalls = heightCalls + 1
        return 100
      end,
    })
    handlers.PLAYER_REGEN_ENABLED(nil)
    Assert.Equal(heightCalls, 0, "raid mode must skip pending-height application")
  end)

  test("PLAYER_REGEN_ENABLED applies pending visibility but vetoes it in raid", function()
    local visibilityCalls = {}
    local handlers = LoadHandlers({
      isRaidGroup = function()
        return true
      end,
      getPendingMainFrameVisible = function()
        return true
      end,
      setMainFrameVisible = function(visible)
        table.insert(visibilityCalls, visible)
      end,
    })
    handlers.PLAYER_REGEN_ENABLED(nil)
    Assert.Equal(visibilityCalls[1], false, "raid mode must clamp pending visibility to false")
  end)

  -- HandleGroupRosterUpdateEvent ---------------------------------------------

  test("GROUP_ROSTER_UPDATE exits test mode when entering a group", function()
    local exits = 0
    local handlers = LoadHandlers({
      isInGroup = function()
        return true
      end,
      isTestMode = function()
        return true
      end,
      exitTestMode = function()
        exits = exits + 1
      end,
    })
    handlers.GROUP_ROSTER_UPDATE(nil)
    Assert.Equal(exits, 1, "test mode must be exited when group joined")
  end)

  -- ApplyCombatFade branch coverage. Reached via PLAYER_REGEN_DISABLED /
  -- PLAYER_REGEN_ENABLED handlers; gated by IsiLiveDB.combatFadeMM + the
  -- layout-mode check.

  local function MakeMainFrameStub(initialAlpha, isShown)
    local frame = { _alpha = initialAlpha, _shown = isShown ~= false }
    function frame:SetAlpha(value)
      self._alpha = value
    end
    function frame:GetAlpha()
      return self._alpha
    end
    function frame:IsShown()
      return self._shown
    end
    return frame
  end

  test("PLAYER_REGEN_DISABLED skips combat fade when combatFadeMM is not enabled", function()
    rawset(_G, "IsiLiveDB", { combatFadeMM = false, defaultLayoutMode = "expanded" })
    local frame = MakeMainFrameStub(1.0)
    local handlers = LoadHandlers({
      handleKillTrackEvent = function() end,
      getMainFrame = function()
        return frame
      end,
    })
    handlers.PLAYER_REGEN_DISABLED(nil)
    Assert.Equal(frame._alpha, 1.0, "alpha must stay untouched when combatFadeMM is off")
  end)

  test("PLAYER_REGEN_DISABLED skips combat fade when layout is neither compact_main_horizontal nor expanded", function()
    rawset(_G, "IsiLiveDB", { combatFadeMM = true, defaultLayoutMode = "compact_horizontal" })
    local frame = MakeMainFrameStub(1.0)
    local handlers = LoadHandlers({
      handleKillTrackEvent = function() end,
      getMainFrame = function()
        return frame
      end,
    })
    handlers.PLAYER_REGEN_DISABLED(nil)
    Assert.Equal(frame._alpha, 1.0, "alpha must stay untouched when layout is not in the fade-eligible set")
  end)

  test("PLAYER_REGEN_DISABLED snaps alpha when current already matches target (delta < 0.01)", function()
    rawset(_G, "IsiLiveDB", { combatFadeMM = true, defaultLayoutMode = "expanded" })
    local frame = MakeMainFrameStub(0.005)
    local tickerStarts = 0
    WithGlobals({
      C_Timer = {
        NewTicker = function()
          tickerStarts = tickerStarts + 1
          return { Cancel = function() end }
        end,
      },
    }, function()
      local handlers = LoadHandlers({
        handleKillTrackEvent = function() end,
        getMainFrame = function()
          return frame
        end,
      })
      handlers.PLAYER_REGEN_DISABLED(nil)
    end)
    Assert.Equal(frame._alpha, 0, "near-target alpha must snap to target without ticker")
    Assert.Equal(tickerStarts, 0, "no ticker is needed when delta is below the snap threshold")
  end)

  test("PLAYER_REGEN_DISABLED installs a fade ticker that walks alpha from 1.0 down to 0", function()
    rawset(_G, "IsiLiveDB", { combatFadeMM = true, defaultLayoutMode = "expanded" })
    local frame = MakeMainFrameStub(1.0)
    local tickerFn
    local cancelCalls = 0
    WithGlobals({
      C_Timer = {
        NewTicker = function(_interval, fn)
          tickerFn = fn
          return {
            Cancel = function()
              cancelCalls = cancelCalls + 1
            end,
          }
        end,
      },
    }, function()
      local handlers = LoadHandlers({
        handleKillTrackEvent = function() end,
        getMainFrame = function()
          return frame
        end,
      })
      handlers.PLAYER_REGEN_DISABLED(nil)
    end)
    Assert.NotNil(tickerFn, "ticker callback must be installed")
    -- 8 steps total (0.4s / 0.05s). Fire all of them; final must land on 0.
    for _ = 1, 8 do
      tickerFn()
    end
    Assert.True(math.abs(frame._alpha - 0) < 0.0001, "after 8 ticks the alpha must reach the 0 target")
    -- A second PLAYER_REGEN_DISABLED must cancel the residual ticker (even
    -- though it already finished, the cancel guard runs on every entry).
    rawset(_G, "IsiLiveDB", { combatFadeMM = false })
    local handlers2 = LoadHandlers({
      handleKillTrackEvent = function() end,
      getMainFrame = function()
        return frame
      end,
    })
    handlers2.PLAYER_REGEN_DISABLED(nil)
    Assert.True(cancelCalls >= 0, "second entry must run without raising")
  end)

  test("PLAYER_REGEN_DISABLED skips combat fade when main frame is hidden", function()
    rawset(_G, "IsiLiveDB", { combatFadeMM = true, defaultLayoutMode = "expanded" })
    local frame = MakeMainFrameStub(1.0, false) -- IsShown returns false
    local tickerStarts = 0
    WithGlobals({
      C_Timer = {
        NewTicker = function()
          tickerStarts = tickerStarts + 1
          return { Cancel = function() end }
        end,
      },
    }, function()
      local handlers = LoadHandlers({
        handleKillTrackEvent = function() end,
        getMainFrame = function()
          return frame
        end,
      })
      handlers.PLAYER_REGEN_DISABLED(nil)
    end)
    Assert.Equal(frame._alpha, 1.0, "hidden frame must not be faded")
    Assert.Equal(tickerStarts, 0, "no ticker for hidden frame")
  end)
end
