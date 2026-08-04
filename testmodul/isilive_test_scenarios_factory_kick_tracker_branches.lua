---@diagnostic disable: undefined-global

-- Branch-coverage scenarios for factory/isiLive_factory_kick_tracker.lua.
-- The existing factory_secondary scenarios drive the post-raid recovery
-- flow but skip over several defensive branches inside the wiring
-- closures (ClearOwnKickSyncCache, SyncOwnKickState, the onCooldownChanged
-- transition-to-ready broadcast window, and the SPELL_UPDATE_COOLDOWN /
-- SPELLS_CHANGED event handlers). This file targets those branches by
-- driving InitializeFactorySecondaryKickTracker against minimal stubs
-- and then poking the captured event frame / ticker / cooldown callback
-- directly.

local function NewCreateFrame(framesOut)
  return function()
    local frame = {
      _events = {},
      _unitEvents = {},
      _scripts = {},
    }
    function frame:RegisterEvent(event)
      self._events[event] = true
    end
    function frame:RegisterUnitEvent(event, ...)
      self._unitEvents[event] = { ... }
    end
    function frame:UnregisterEvent(event)
      self._events[event] = nil
    end
    function frame:SetScript(name, fn)
      self._scripts[name] = fn
    end
    function frame:FireEvent(event, ...)
      local h = self._scripts.OnEvent
      if h then
        h(self, event, ...)
      end
    end
    table.insert(framesOut, frame)
    return frame
  end
end

local function BuildKickTrackerModule(state, controllerSetup)
  state.kickTrackerOpts = nil
  return {
    CreateController = function(opts)
      state.kickTrackerOpts = opts
      local controller = {
        Scan = function()
          state.scanCalls = (state.scanCalls or 0) + 1
        end,
        OnCast = function()
          return state.onCastReturn == true
        end,
        CacheCooldown = function()
          state.cacheCooldownCalls = (state.cacheCooldownCalls or 0) + 1
          if controllerSetup and controllerSetup.cacheCooldownPokesKickInfo then
            controllerSetup.cacheCooldownPokesKickInfo(state.kickInfo)
          end
        end,
        ReconcileObservedCooldown = function()
          state.reconcileObservedCooldownCalls = (state.reconcileObservedCooldownCalls or 0) + 1
          if controllerSetup and controllerSetup.reconcileObservedCooldown then
            return controllerSetup.reconcileObservedCooldown(state)
          end
          return false
        end,
        GetKickInfo = function()
          return state.kickInfo
        end,
        ResolveKickState = function()
          state.resolveCalls = (state.resolveCalls or 0) + 1
          state.kickInfo = state.resolveResult or state.kickInfo
          return state.kickInfo
        end,
      }
      return controller
    end,
  }
end

local function BuildSyncStub(state, opts)
  opts = opts or {}
  if opts.dropAll then
    return {} -- no functions => ClearOwnKickSyncCache early-returns false
  end
  return {
    ClearPlayerKickInfo = function(name, realm)
      table.insert(state.cleared, { name = name, realm = realm })
      return true
    end,
    SetPlayerKickInfo = function(name, realm, onCooldown, cooldownRemain, _spellID, hasKick, extras)
      state.lastSetKickInfo = {
        name = name,
        realm = realm,
        onCooldown = onCooldown,
        cooldownRemain = cooldownRemain,
        hasKick = hasKick,
        extras = extras,
      }
    end,
    SendKick = function(packet)
      table.insert(state.sentKick, packet)
    end,
  }
end

local function BuildCtxAndState(opts)
  opts = opts or {}
  local state = {
    time = opts.time or 0,
    isRaidGroup = opts.isRaidGroup == true,
    mainFrameShown = opts.mainFrameShown ~= false,
    sentKick = {},
    cleared = {},
    frames = {},
    kickInfo = opts.kickInfo or {
      availabilityResolved = true,
      spellID = 6552,
      hasKick = true,
      onCooldown = false,
      cooldownRemain = 0,
    },
    onCastReturn = opts.onCastReturn,
    resolveResult = opts.resolveResult,
  }

  local ctx = {
    addonTable = {
      KickTracker = BuildKickTrackerModule(state, opts.controllerSetup or {}),
      StringUtils = {
        IsBlank = function(s)
          return s == nil or s == ""
        end,
      },
    },
    -- Kick sync only runs in the full runtime profile. These branch scenarios
    -- all exercise in-key behaviour, so the challenge bridge reports a running
    -- keystone unless a scenario opts out.
    GetActiveChallengeMapID = function()
      if opts.activeChallengeMapID == false then
        return nil
      end
      return opts.activeChallengeMapID or 559
    end,
    rosterPanelController = {
      RefreshKickColumn = function()
        state.kickRefreshes = (state.kickRefreshes or 0) + 1
      end,
    },
  }

  local modules = {
    sync = BuildSyncStub(state, opts.sync or {}),
  }

  return ctx, modules, state
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function LoadFactoryKickTracker(opts)
    opts = opts or {}
    local _ctx, modules, state = BuildCtxAndState(opts)
    local globals = {
      CreateFrame = NewCreateFrame(state.frames),
      C_Timer = {
        After = function(delay, callback)
          state.afterCallbacks = state.afterCallbacks or {}
          table.insert(state.afterCallbacks, { delay = delay, callback = callback })
        end,
        NewTicker = function(interval, callback)
          state.tickers = state.tickers or {}
          local ticker = { interval = interval, callback = callback }
          table.insert(state.tickers, ticker)
          return ticker
        end,
      },
      UnitName = opts.UnitName or function()
        return "Player"
      end,
      GetRealmName = opts.GetRealmName or function()
        return "Realm"
      end,
    }
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_factory_kick_tracker.lua" })
      -- Make the loaded module's addonTable point at our stub before
      -- InitializeFactorySecondaryKickTracker reads it.
      addon._FactoryInternal.InitializeFactorySecondaryKickTracker(
        _ctx,
        modules,
        function()
          return state.time
        end,
        opts.UnitNameFn or function()
          return "Player"
        end,
        opts.GetRealmNameFn or function()
          return "Realm"
        end,
        function()
          return state.mainFrameShown == true
        end,
        function()
          return state.isRaidGroup == true
        end,
        function()
          return opts.inGroup ~= false
        end
      )
    end)
    -- ctx.addonTable.KickTracker hat sich nach Load geändert (LoadAddonModules
    -- überschreibt das im seed). Wir restoring den Stub:
    state.fireEvent = function(event, ...)
      Assert.True(type(_ctx.HandleKickTrackerEvent) == "function", "kick event handler must be exposed on ctx")
      _ctx.HandleKickTrackerEvent(event, ...)
    end
    return _ctx, modules, state
  end

  -- ClearOwnKickSyncCache defensive paths --------------------------------------

  test("kick tracker: SyncOwnKickState gracefully handles missing modules.sync.ClearPlayerKickInfo", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({
      sync = { dropAll = true },
      kickInfo = { availabilityResolved = false }, -- triggers ClearOwnKickSyncCache early
    })
    -- Ticker fires SyncOwnKickState which hits ClearOwnKickSyncCache.
    -- With dropAll, ClearOwnKickSyncCache returns false but does not crash.
    if state.tickers and state.tickers[1] then
      state.tickers[1].callback()
    end
    Assert.Equal(#state.cleared, 0, "no clears recorded when sync stub is empty")
  end)

  test("kick tracker: SyncOwnKickState skips when selfName is blank", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({
      UnitNameFn = function()
        return ""
      end,
      kickInfo = { availabilityResolved = false },
    })
    if state.tickers and state.tickers[1] then
      state.tickers[1].callback()
    end
    Assert.Equal(#state.cleared, 0, "blank selfName must short-circuit ClearPlayerKickInfo")
  end)

  test("kick tracker: SyncOwnKickState clears sync cache when info has no resolved availability", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({
      kickInfo = { availabilityResolved = false, spellID = 6552 },
    })
    if state.tickers and state.tickers[1] then
      state.tickers[1].callback()
    end
    Assert.True(#state.cleared >= 1, "unresolved availability must clear sync cache")
    Assert.Equal(#state.sentKick, 0, "unresolved availability must not send kick")
  end)

  -- onCooldownChanged callback paths ------------------------------------------

  test("kick tracker: onCooldownChanged opens 3s ready broadcast window when transitioning to ready", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({
      time = 100,
    })
    -- Trigger the callback as if cooldown just ended.
    state.kickTrackerOpts.onCooldownChanged(false, 0)
    -- Ticker fires now: time still 100, broadcastUntil = 103, so ready
    -- broadcast window is open and SendKick must fire even when not on cooldown.
    if state.tickers and state.tickers[1] then
      state.tickers[1].callback()
    end
    Assert.True(#state.sentKick >= 1, "transitioning to ready must trigger broadcast within 3s window")
  end)

  test("kick tracker: onCooldownChanged enters raid suppression when raid mode is active", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({
      isRaidGroup = true,
    })
    state.kickTrackerOpts.onCooldownChanged(true, 12)
    Assert.Equal(#state.sentKick, 0, "raid mode must veto cooldown-changed broadcast")
  end)

  test("kick tracker: observed casts schedule a post-cast exact cooldown reconcile", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({
      time = 100,
      onCastReturn = true,
      controllerSetup = {
        reconcileObservedCooldown = function(testState)
          testState.kickInfo = {
            availabilityResolved = true,
            spellID = 6552,
            hasKick = true,
            onCooldown = true,
            cooldownRemain = 12,
          }
          return true
        end,
      },
    })

    state.fireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", nil, 6552)
    Assert.Equal(#state.afterCallbacks, 1, "observed kick cast must queue a short post-cast reconcile")
    Assert.Equal(state.afterCallbacks[1].delay, 0.05, "post-cast reconcile must use the intended short delay")

    state.afterCallbacks[1].callback()
    Assert.Equal(state.reconcileObservedCooldownCalls, 1, "delayed callback must reconcile the observed cooldown")
    Assert.True(#state.sentKick >= 1, "reconciled exact cooldown must force a kick sync")
    Assert.True(state.lastSetKickInfo.onCooldown, "reconciled local kick state must be written to local sync cache")
    Assert.Equal(state.lastSetKickInfo.cooldownRemain, 12, "local sync cache must carry the refined remain")
  end)

  -- SendOwnKickState defensive paths ------------------------------------------

  test("kick tracker: SendOwnKickState returns false when controller is missing", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({})
    -- Drop the controller mid-flight.
    _ctx.kickTrackerController = nil
    Assert.False(_ctx.SendOwnKickState(true), "missing controller must yield false")
    Assert.Equal(#state.sentKick, 0, "missing controller must not send")
  end)

  -- SPELL_UPDATE_COOLDOWN event branch ----------------------------------------

  test("kick tracker: SPELL_UPDATE_COOLDOWN re-caches cooldown via the controller", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({})
    state.fireEvent("SPELL_UPDATE_COOLDOWN")
    Assert.Equal(state.cacheCooldownCalls, 1, "cooldown event must call CacheCooldown once")
  end)

  test("kick tracker: PLAYER_REGEN_ENABLED also re-caches cooldown", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({})
    state.fireEvent("PLAYER_REGEN_ENABLED")
    Assert.Equal(state.cacheCooldownCalls, 1, "regen-enabled event must call CacheCooldown once")
  end)

  -- SPELLS_CHANGED branch: kick tracking re-resolves and broadcasts -----------

  test("kick tracker: SPELLS_CHANGED broadcasts when previous availability was unresolved", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({
      time = 50,
      kickInfo = { availabilityResolved = false }, -- previousInfo
      resolveResult = { availabilityResolved = true, hasKick = true, spellID = 6552 },
    })
    state.fireEvent("SPELLS_CHANGED")
    Assert.Equal(state.resolveCalls, 1, "SPELLS_CHANGED must drive ResolveKickState")
    Assert.True(#state.sentKick >= 1, "newly resolved availability must trigger broadcast")
  end)

  test("kick tracker: SPELLS_CHANGED clears sync cache when resolution still fails", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({
      kickInfo = { availabilityResolved = false },
      resolveResult = { availabilityResolved = false }, -- still unresolved after re-resolve
    })
    state.fireEvent("SPELLS_CHANGED")
    Assert.True(#state.cleared >= 1, "still-unresolved must clear sync cache")
    Assert.Equal(#state.sentKick, 0, "still-unresolved must not broadcast")
  end)

  test("kick tracker: SPELLS_CHANGED stays silent when nothing changed", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({
      kickInfo = { availabilityResolved = true, hasKick = true, spellID = 6552 },
      resolveResult = { availabilityResolved = true, hasKick = true, spellID = 6552 },
    })
    state.fireEvent("SPELLS_CHANGED")
    Assert.Equal(#state.sentKick, 0, "no change in availability/spellID must skip broadcast")
  end)

  test("kick tracker: SPELLS_CHANGED broadcasts when spellID changes", function()
    local _ctx, _modules, state = LoadFactoryKickTracker({
      kickInfo = { availabilityResolved = true, hasKick = true, spellID = 6552 },
      resolveResult = { availabilityResolved = true, hasKick = true, spellID = 47528 }, -- mind freeze
    })
    state.fireEvent("SPELLS_CHANGED")
    Assert.True(#state.sentKick >= 1, "spellID change must trigger broadcast")
  end)

  -- Reduced-profile gate ---------------------------------------------------------

  test("kick tracker: reduced profile keeps polling and sync closed", function()
    -- No keystone and no live mythic instance data: open world, normal, heroic,
    -- timewalking, delves, torghast, follower dungeons. Kick tracking is a
    -- Mythic+ utility and must not run its 0.5s poll or its sync heartbeats
    -- for a roster column nobody is looking at.
    local _ctx, _modules, state = LoadFactoryKickTracker({
      activeChallengeMapID = false,
    })

    Assert.True(
      state.tickers == nil or #state.tickers == 0,
      "the reduced profile must not start the kick polling ticker"
    )
    Assert.False(_ctx.SendOwnKickState(true), "an explicit kick sync request must be refused in the reduced profile")
    Assert.Equal(#state.sentKick, 0, "no kick payload may leave the client in the reduced profile")

    state.fireEvent("SPELLS_CHANGED")
    Assert.Equal(#state.sentKick, 0, "spell changes must stay silent in the reduced profile")
  end)
end
