local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- Defensive / external cooldown wiring (rule 267, vorhaben V1 stage 1).
--
-- Connects the own tracker (game/isiLive_defensive_tracker.lua), the store
-- (logic/isiLive_defensive_store.lua) and the DEF sync bucket (Sync.SendDef):
--   * runs only with `defensiveTrackerEnabled` (Pattern B), in the KEY
--     profile (rule 109) and never in a raid (rule 11); otherwise the ticker
--     stops and the store is emptied
--   * DEF goes out only with `defensiveSyncEnabled` (Pattern B) as well:
--     event-driven (own cast, cooldown events) and on a 1 s tick that carries
--     the 15 s heartbeat; Sync.SendDef owns the gate, dedupe and lockdown flag
--   * own addon chat locked down (a key from the first pull on): the store
--     freezes the peer records; when it lifts the store thaws and a REQSYNC
--     asks the peers for their current state
-- The kick tracker's event stream (UNIT_SPELLCAST_SUCCEEDED player/pet, the
-- coalesced SPELL_UPDATE_COOLDOWN, SPELLS_CHANGED, spec and roster changes)
-- reaches HandleDefensiveTrackerEvent through the controller wiring, so no
-- event is registered here (rule 258).
--
-- Stage 2 (rules 268, 269):
--   * estimate: with `defensiveEstimateEnabled` (Pattern B) and a client that
--     offers the sensor chain (DefensiveSensors.IsSupported), every pass
--     points the sensors at party1..4 members without an isiLive state
--     (store source ~= "sync"); built and re-filtered out of combat only,
--     torn down with the feature, the profile, a raid or a group change
--   * cell: every pass repaints the visible defensives cells; a phase change
--     (key start / end, switch) asks for one full roster render instead.
local TICK_SECONDS = 1
local CAST_REREAD_DELAY_SECONDS = 0.2

local function ReadDB()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db or nil
end

local function IsTrackerEnabled()
  local db = ReadDB()
  return db ~= nil and db.defensiveTrackerEnabled == true
end

local function IsDefSyncEnabled()
  local db = ReadDB()
  return db ~= nil and db.defensiveSyncEnabled == true
end

local function IsEstimateEnabled()
  local db = ReadDB()
  return db ~= nil and db.defensiveEstimateEnabled == true
end

local PARTY_UNITS = { "party1", "party2", "party3", "party4" }

local function Sensors()
  local sensors = addonTable.DefensiveSensors
  return type(sensors) == "table" and type(sensors.Configure) == "function" and sensors or nil
end

local function IsKeyProfile()
  local runtimeMode = addonTable.RuntimeMode
  if type(runtimeMode) ~= "table" or type(runtimeMode.IsKey) ~= "function" then
    return false
  end
  local ok, isKey = pcall(runtimeMode.IsKey)
  return ok and isKey == true
end

local function IsChatLockedDown()
  local transport = addonTable.SyncTransport
  if type(transport) ~= "table" or type(transport.IsAddonChatLockedDown) ~= "function" then
    return false
  end
  local ok, locked = pcall(transport.IsAddonChatLockedDown)
  return ok and locked == true
end

local function InitializeFactoryDefensives(
  ctx,
  modules,
  getTime,
  getUnitName,
  getRealmName,
  IsRaidModeActive,
  IsGroupSyncActive
)
  local trackerModule = addonTable.DefensiveTracker
  local store = addonTable.DefensiveStore
  if type(trackerModule) ~= "table" or type(trackerModule.CreateController) ~= "function" or type(store) ~= "table" then
    return
  end

  local timerApi = rawget(_G, "C_Timer")
  local tracker = trackerModule.CreateController({ getTime = getTime })
  ctx.defensiveTrackerController = tracker
  local ticker = nil
  local forceNextSend = false

  local function Now()
    return type(getTime) == "function" and getTime() or 0
  end

  local function IsContextActive()
    return IsTrackerEnabled() and not IsRaidModeActive() and IsKeyProfile()
  end

  -- Peers are accepted only while this client would send as well.
  store.SetPeerGate(function()
    return IsContextActive() and IsDefSyncEnabled()
  end)

  local function RefreshOwnKey()
    local sync = modules.sync
    local selfName = getUnitName and getUnitName("player") or nil
    if type(sync) ~= "table" or type(sync.NormalizePlayerKey) ~= "function" then
      return
    end
    if addonTable.StringUtils.IsBlank(selfName) then
      return
    end
    store.SetOwnKey(sync.NormalizePlayerKey(selfName, getRealmName and getRealmName() or nil))
  end

  local function StopTicker()
    if ticker and type(ticker.Cancel) == "function" then
      ticker:Cancel()
    end
    ticker = nil
  end

  -- Party members without an isiLive state, for the estimate sensors. A
  -- member whose name reads masked right now keeps its previous sensors.
  local function BuildEstimateMembers(now)
    local units = addonTable.Units
    local sync = modules.sync
    local members = {}
    if type(units) ~= "table" or type(sync) ~= "table" or type(sync.NormalizePlayerKey) ~= "function" then
      return members
    end
    for _, unit in ipairs(PARTY_UNITS) do
      local name, realm, realmMasked = units.GetUnitNameAndRealm(unit)
      if name == nil or realmMasked == true then
        members[#members + 1] = { unit = unit, keep = true }
      else
        local playerKey = sync.NormalizePlayerKey(name, realm)
        if store.GetForPlayer(playerKey, now).source ~= "sync" then
          local _, classToken = units.GetUnitClass(unit)
          members[#members + 1] = {
            unit = unit,
            playerKey = playerKey,
            classToken = classToken,
            specID = type(units.GetInspectSpecID) == "function" and units.GetInspectSpecID(unit) or nil,
          }
        end
      end
    end
    return members
  end

  local function UpdateEstimate(now)
    local sensors = Sensors()
    if not sensors then
      return
    end
    if not IsEstimateEnabled() or not sensors.IsSupported() then
      sensors.Suspend()
      return
    end
    sensors.SetClock(getTime)
    sensors.Configure(BuildEstimateMembers(now))
  end

  -- Visible cells follow the store and the sensors every pass; a phase
  -- change needs the full render (DPS <-> Def, RIO width).
  local function RefreshCells(now)
    local cell = addonTable.RosterDefensiveCell
    if type(cell) ~= "table" then
      return
    end
    if cell.NeedsRender() and type(ctx.UpdateUI) == "function" then
      pcall(ctx.UpdateUI)
      return
    end
    cell.RefreshAll(now)
  end

  local function Shutdown()
    StopTicker()
    forceNextSend = false
    store.Clear()
    tracker.Reset()
    local sensors = Sensors()
    if sensors then
      sensors.Suspend()
    end
  end

  -- Freeze while the own addon chat is locked down; on the way out thaw and
  -- ask the peers for their current state (only with the sync on).
  local function ApplyChatLockdown(now)
    local locked = IsChatLockedDown()
    if locked and not store.IsFrozen() then
      store.Freeze(now)
    elseif not locked and store.IsFrozen() then
      store.Thaw()
      forceNextSend = true
      local sync = modules.sync
      if IsDefSyncEnabled() and type(sync) == "table" and type(sync.SendRefreshRequest) == "function" then
        sync.SendRefreshRequest({ force = true })
      end
    end
  end

  local function SendOwnState(entries, force)
    local sync = modules.sync
    if not IsDefSyncEnabled() or type(IsGroupSyncActive) ~= "function" or IsGroupSyncActive() ~= true then
      return false
    end
    if type(sync) ~= "table" or type(sync.SendDef) ~= "function" then
      return false
    end
    local sent = sync.SendDef({ entries = entries, force = force == true or forceNextSend })
    if sent == true then
      forceNextSend = false
    end
    return sent == true
  end

  -- One pass: own state from the live client into the store, lockdown
  -- freeze/thaw, stale peers out, DEF out (gated in Sync.SendDef).
  local function RunPass(force)
    if not IsContextActive() then
      Shutdown()
      return false
    end
    local now = Now()
    local entries = tracker.ReadEntries(now)
    store.SetOwn(entries, now)
    ApplyChatLockdown(now)
    store.Prune(now)
    SendOwnState(entries, force)
    UpdateEstimate(now)
    RefreshCells(now)
    return true
  end

  local function RefreshDefensiveTracker()
    if not IsContextActive() then
      Shutdown()
      return false
    end
    RefreshOwnKey()
    if ticker == nil and type(timerApi) == "table" and type(timerApi.NewTicker) == "function" then
      ticker = timerApi.NewTicker(TICK_SECONDS, function()
        RunPass(false)
      end)
    end
    return true
  end

  ctx.RefreshDefensiveTracker = RefreshDefensiveTracker

  -- Settings switches (rule 269): start or stop the tracker, run one pass
  -- and re-render the roster so the cell follows at once.
  local function ApplyDefensiveSettings()
    local wasRunning = ticker ~= nil
    if RefreshDefensiveTracker() then
      RunPass(true)
    elseif wasRunning then
      Shutdown()
    end
    if type(ctx.UpdateUI) == "function" then
      pcall(ctx.UpdateUI)
    end
  end
  ctx.ApplyDefensiveSettings = ApplyDefensiveSettings
  addonTable.DefensiveRuntime = { ApplySettings = ApplyDefensiveSettings }

  -- Forced own state: PLAYER_ENTERING_WORLD and the HELLO / REQSYNC peer
  -- fan-out (rides along with the own kick state, see controller wiring).
  ctx.SendOwnDefensiveState = function(force)
    if not RefreshDefensiveTracker() then
      return false
    end
    return RunPass(force ~= false)
  end

  ctx.HandleDefensiveTrackerEvent = function(event, unit, _castGUID, spellID)
    if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
      return
    end
    if not RefreshDefensiveTracker() then
      return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      if tracker.OnCast(unit, spellID) and type(timerApi) == "table" and type(timerApi.After) == "function" then
        -- The cooldown starts with the cast; read it once the client updated it.
        timerApi.After(CAST_REREAD_DELAY_SECONDS, function()
          RunPass(false)
        end)
      end
      return
    end
    if event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UNIT_PET" then
      tracker.ResolveKnownSpells()
      RunPass(true)
      return
    end
    if event == "SPELL_UPDATE_COOLDOWN" or event == "PLAYER_REGEN_ENABLED" or event == "GROUP_ROSTER_UPDATE" then
      RunPass(false)
    end
  end

  RefreshDefensiveTracker()
end

FI.InitializeFactoryDefensives = InitializeFactoryDefensives
