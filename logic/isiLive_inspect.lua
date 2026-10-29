local _, addonTable = ...

addonTable = addonTable or {}

local Inspect = {}
addonTable.Inspect = Inspect
local IsSecretValue = addonTable.Validators.IsSecretValue

local function IsUnitInInspectQueue(controller, unit)
  for i = 1, #controller.inspectQueue do
    if controller.inspectQueue[i] == unit then
      return true
    end
  end
  return false
end

local function IsGhostRosterUnit(unit, roster)
  if type(unit) ~= "string" then
    return false
  end
  if string.find(unit, "^ghost:") then
    return true
  end
  return type(roster) == "table" and type(roster[unit]) == "table" and roster[unit].isGhost == true
end

local IsExistingUnit = addonTable.Validators.IsExistingUnit

local function GetUnitGUIDSafe(unit)
  if not IsExistingUnit(unit) then
    return nil
  end

  local unitGUID = rawget(_G, "UnitGUID")
  if type(unitGUID) ~= "function" then
    return nil
  end

  local ok, guid = pcall(unitGUID, unit)
  if ok and not IsSecretValue(guid) and type(guid) == "string" and guid ~= "" then
    return guid
  end

  return nil
end

local function IsForceRefreshQueued(info)
  return type(info) == "table" and info._refreshQueued == true
end

local function EnqueueInspect(controller, unit, roster)
  if not unit or not roster or IsGhostRosterUnit(unit, roster) or not IsExistingUnit(unit) then
    return
  end

  local rosterEntry = roster[unit]
  local forceRefreshQueued = IsForceRefreshQueued(rosterEntry)
  local guid = GetUnitGUIDSafe(unit)
  if guid and rosterEntry and not forceRefreshQueued then
    if controller.ilvlCache[guid] then
      rosterEntry.ilvl = controller.ilvlCache[guid]
      rosterEntry._localIlvlFresh = true
    end
    if controller.rioCache[guid] then
      rosterEntry.rio = controller.rioCache[guid]
      rosterEntry._localRioFresh = true
    end
    -- The inspected spec role wins over the assigned group role: a healer who
    -- switched to a damage spec without re-setting the group role is a DPS.
    -- The roster rebuild writes the assigned role first, so re-apply it here.
    if controller.specRoleCache[guid] then
      rosterEntry.role = controller.specRoleCache[guid]
    end
    if controller.specCache[guid] then
      rosterEntry.spec = controller.specCache[guid]
      rosterEntry._localSpecFresh = true
    end
    if controller.ilvlCache[guid] and controller.rioCache[guid] and controller.specCache[guid] then
      return
    end
  end

  if
    not IsUnitInInspectQueue(controller, unit)
    and rosterEntry
    and (forceRefreshQueued or not rosterEntry.ilvl or not rosterEntry.rio or not rosterEntry.spec)
  then
    local logFn = forceRefreshQueued and controller.logRuntimeTracef or controller.logRuntimeTracefDeep
    if logFn then
      logFn(
        "[INSPECT] enqueue unit=%s forceRefresh=%s hasIlvl=%s hasRio=%s hasSpec=%s",
        tostring(unit),
        tostring(forceRefreshQueued),
        tostring(rosterEntry.ilvl ~= nil),
        tostring(rosterEntry.rio ~= nil),
        tostring(rosterEntry.spec ~= nil)
      )
    end
    table.insert(controller.inspectQueue, unit)
    -- Wake the idle-free inspect loop: the factory detaches the OnUpdate while
    -- the controller holds no work (rule 168, see HasPendingWork).
    if controller.onWorkQueued then
      controller.onWorkQueued()
    end
  end
end

local function QueueForceRefreshData(controller, roster)
  controller.ResetQueues()
  for unit, info in pairs(roster or {}) do
    if not (info.isGhost or IsGhostRosterUnit(unit, roster)) then
      if IsExistingUnit(unit) then
        local guid = GetUnitGUIDSafe(unit)
        if guid then
          controller.ilvlCache[guid] = nil
          controller.rioCache[guid] = nil
          controller.specCache[guid] = nil
          controller.specRoleCache[guid] = nil
        end
        info.spec = nil
        info.ilvl = nil
        info.rio = nil
        info._localSpecFresh = nil
        info._localIlvlFresh = nil
        info._localRioFresh = nil
        info._refreshQueued = true
        EnqueueInspect(controller, unit, roster)
      else
        info._refreshQueued = true
      end
    end
  end
end

-- A party member switched spec (or role): the per-GUID spec cache would keep
-- the old spec for the whole session, so drop it and inspect that member again.
local function InvalidateMember(controller, unit, roster)
  local info = type(roster) == "table" and roster[unit] or nil
  if type(info) ~= "table" or info.isGhost or IsGhostRosterUnit(unit, roster) or not IsExistingUnit(unit) then
    return false
  end
  local guid = GetUnitGUIDSafe(unit)
  if guid then
    controller.specCache[guid] = nil
    controller.specRoleCache[guid] = nil
  end
  info._localSpecFresh = nil
  info._refreshQueued = true
  EnqueueInspect(controller, unit, roster)
  return true
end

-- Reads one INSPECT_READY reply for `unit` into the roster and the per-GUID
-- caches. Shared by our own inspect and by harvested foreign ones, so both
-- apply exactly the same rules (no transient 0/nil overwrites, zero score is
-- data, the inspected spec role wins over the assigned group role).
local function ApplyInspectResult(controller, unit, guid, roster, getters)
  local info = roster[unit]
  local result = {}

  local ilvl = nil
  if C_PaperDollInfo and type(C_PaperDollInfo.GetInspectItemLevel) == "function" then
    local ok, ilvlResult = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
    if ok and not IsSecretValue(ilvlResult) and type(ilvlResult) == "number" then
      ilvl = ilvlResult
    end
  end
  -- GetInspectItemLevel("player") returns 0/nil in most contexts (in M+ under
  -- 12.0 the inspect path is restricted entirely). Fall back to the local
  -- C_Item.GetAverageItemLevel for own player so we never write a useless 0.
  if (not ilvl or ilvl <= 0) and unit == "player" and type(getters.getOwnAverageItemLevel) == "function" then
    local ownIlvl = getters.getOwnAverageItemLevel()
    if type(ownIlvl) == "number" and ownIlvl > 0 then
      ilvl = ownIlvl
    end
  end
  result.ilvl = ilvl
  if ilvl and ilvl > 0 then
    -- Only write a real value: do NOT overwrite a previously-good ilvl with a
    -- transient 0/nil from a partial inspect response. Preserves data both for
    -- player (our local-API fallback above) and for party members between
    -- successful inspects.
    if info then
      result.ilvlChanged = info.ilvl ~= ilvl
      info.ilvl = ilvl
      info._localIlvlFresh = true
    end
    controller.ilvlCache[guid] = ilvl
  end

  local rio = getters.getUnitRio and getters.getUnitRio(unit) or nil
  local rioResolved = addonTable.Validators.IsFiniteNumber(rio) and rio >= 0
  result.rio = rio
  if rioResolved then
    if info then
      result.rioChanged = info.rio ~= rio
      info.rio = rio
      info._localRioFresh = true
    end
    controller.rioCache[guid] = rio
  end

  local specName = getters.getInspectSpecName and getters.getInspectSpecName(unit) or nil
  if not specName and unit == "player" and getters.getPlayerSpecName then
    specName = getters.getPlayerSpecName()
  end
  local specResolved = type(specName) == "string" and specName ~= ""
  result.specName = specName
  if specResolved then
    if info then
      result.specChanged = info.spec ~= specName
      info.spec = specName
      info._localSpecFresh = true
    end
    controller.specCache[guid] = specName
  end

  local specRole = type(getters.getInspectSpecRole) == "function" and getters.getInspectSpecRole(unit) or nil
  result.specRole = specRole
  if specRole == "TANK" or specRole == "HEALER" or specRole == "DAMAGER" then
    controller.specRoleCache[guid] = specRole
    if info and info.role ~= specRole then
      info.role = specRole
      result.roleChanged = true
    end
  end

  result.incomplete = (type(getters.getUnitRio) == "function" and not rioResolved)
    or (type(getters.getInspectSpecName) == "function" and not specResolved)
    or not (ilvl and ilvl > 0)
  result.dataChanged = (result.ilvlChanged or result.rioChanged or result.specChanged or result.roleChanged) == true
  return result
end

-- Roster unit whose live GUID is `guid`, ghosts excluded.
local function FindRosterUnitByGuid(roster, guid)
  for unit, info in pairs(roster) do
    if type(info) == "table" and not info.isGhost and not IsGhostRosterUnit(unit, roster) then
      if GetUnitGUIDSafe(unit) == guid then
        return unit
      end
    end
  end
  return nil
end

local function RemoveUnitFromQueues(controller, unit)
  for i = #controller.inspectQueue, 1, -1 do
    if controller.inspectQueue[i] == unit then
      table.remove(controller.inspectQueue, i)
    end
  end
  for i = #controller.retryQueue, 1, -1 do
    if controller.retryQueue[i].unit == unit then
      table.remove(controller.retryQueue, i)
    end
  end
end

-- Own inspect finished: release the dispatcher. A readable item level alone is
-- not a completed inspect, so missing fields keep the member pending and get a
-- retry instead of marking the work done; last known values stay.
local function FinishOwnInspect(controller, unit, roster, result)
  controller.isInspecting = nil
  local getTimeFn = rawget(_G, "GetTime")
  controller.lastInspectTime = type(getTimeFn) == "function" and getTimeFn() or 0
  if roster[unit] then
    roster[unit]._refreshQueued = result.incomplete and true or nil
    if result.incomplete then
      table.insert(controller.retryQueue, {
        unit = unit,
        nextRetry = controller.lastInspectTime + controller.retryInterval,
      })
    end
  end
end

-- An INSPECT_READY somebody else asked for (Details!, Raider.IO, a manual
-- right-click inspect) still carries readable data for a group member. Keep
-- it, but leave our own in-flight inspect, its timer and the retry schedule
-- alone. A complete reply satisfies any pending work for that member; an
-- incomplete one changes nothing about the queue, the normal path still owns
-- it. Deliberately no pause after a foreign reply: other addons inspect the
-- whole group constantly, and backing off on each reply would stall our queue
-- for good.
local function FinishHarvestedInspect(controller, unit, roster, result)
  if result.incomplete or not roster[unit] then
    return
  end
  roster[unit]._refreshQueued = nil
  RemoveUnitFromQueues(controller, unit)
end

local function OnInspectReady(controller, guid, roster, getters)
  if guid == nil or IsSecretValue(guid) or type(roster) ~= "table" then
    return false
  end
  local inspectedUnit = controller.isInspecting
  local isOwn = inspectedUnit ~= nil and GetUnitGUIDSafe(inspectedUnit) == guid
  local unit = isOwn and inspectedUnit or FindRosterUnitByGuid(roster, guid)
  if not unit then
    return false
  end

  local result = ApplyInspectResult(controller, unit, guid, roster, getters)
  if isOwn then
    FinishOwnInspect(controller, unit, roster, result)
  else
    FinishHarvestedInspect(controller, unit, roster, result)
  end

  if controller.logRuntimeTracef then
    controller.logRuntimeTracef(
      "[INSPECT] %s unit=%s ilvl=%s rio=%s spec=%s role=%s "
        .. "ilvlChanged=%s rioChanged=%s specChanged=%s roleChanged=%s",
      isOwn and "result" or "harvested",
      tostring(unit),
      tostring(result.ilvl),
      tostring(result.rio),
      tostring(result.specName),
      tostring(result.specRole),
      tostring(result.ilvlChanged == true),
      tostring(result.rioChanged == true),
      tostring(result.specChanged == true),
      tostring(result.roleChanged == true)
    )
  end
  if unit == "player" and result.dataChanged and controller.TriggerOwnKeySnapshot then
    controller.TriggerOwnKeySnapshot(false, "inspect")
  end

  return result.dataChanged
end

local function OnInspectTimeout(controller, now)
  if controller.logRuntimeTracef then
    controller.logRuntimeTracef(
      "[INSPECT] timeout unit=%s retryIn=%s",
      tostring(controller.isInspecting),
      tostring(controller.retryInterval)
    )
  end
  table.insert(controller.retryQueue, {
    unit = controller.isInspecting,
    nextRetry = now + controller.retryInterval,
  })
  controller.isInspecting = nil
end

local function IsUnitInspectable(unit)
  if not IsExistingUnit(unit) then
    return false
  end

  local unitIsVisible = rawget(_G, "UnitIsVisible")
  if type(unitIsVisible) ~= "function" then
    return false
  end
  local okVisible, isVisible = pcall(unitIsVisible, unit)
  if not okVisible or IsSecretValue(isVisible) or not isVisible then
    return false
  end

  local canInspectFn = rawget(_G, "CanInspect")
  if type(canInspectFn) ~= "function" then
    return false
  end

  local okCanInspect, canInspect = pcall(canInspectFn, unit)
  if not okCanInspect or IsSecretValue(canInspect) or not canInspect then
    return false
  end
  return true
end

-- True while the player has Blizzard's inspect window open. Our NotifyInspect
-- would repopulate that window with a different group member under them.
-- InspectFrame is nil until Blizzard_InspectUI loads on demand, and that only
-- happens when the player opens an inspect, so "no frame" means "not
-- inspecting".
local function IsInspectFrameShown()
  local frame = rawget(_G, "InspectFrame")
  if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then
    return false
  end
  local ok, shown = pcall(frame.IsShown, frame)
  return ok and not IsSecretValue(shown) and shown == true
end

local function TryDispatchInspect(controller, now)
  if #controller.inspectQueue == 0 then
    return false
  end

  if now - controller.lastInspectTime < controller.inspectDelay then
    return true
  end

  -- Hold the queue while the inspect window is open. Returning true keeps the
  -- queue intact and the loop attached (HasDueWork stays true), so dispatch
  -- resumes on the first tick after the window closes.
  if IsInspectFrameShown() then
    if not controller.manualInspectPaused and controller.logRuntimeTracef then
      controller.logRuntimeTracef("[INSPECT] dispatch_paused reason=inspect_frame_open")
    end
    controller.manualInspectPaused = true
    return true
  end
  controller.manualInspectPaused = nil

  local unit = table.remove(controller.inspectQueue, 1)
  if IsUnitInspectable(unit) then
    if controller.logRuntimeTracef then
      controller.logRuntimeTracef(
        "[INSPECT] dispatch unit=%s queueRemaining=%d",
        tostring(unit),
        #controller.inspectQueue
      )
    end
    controller.isInspecting = unit
    controller.lastInspectTime = now
    local okNotify = pcall(NotifyInspect, unit)
    if not okNotify and controller.logRuntimeTracef then
      controller.logRuntimeTracef("[INSPECT] notify_failed unit=%s", tostring(unit))
    end
  else
    if controller.logRuntimeTracef then
      controller.logRuntimeTracef(
        "[INSPECT] dispatch_skipped unit=%s not_inspectable retryIn=%s",
        tostring(unit),
        tostring(controller.retryInterval)
      )
    end
    table.insert(controller.retryQueue, { unit = unit, nextRetry = now + controller.retryInterval })
  end

  return true
end

local function ProcessRetryQueue(controller, now)
  for i = #controller.retryQueue, 1, -1 do
    local entry = controller.retryQueue[i]
    if now >= entry.nextRetry then
      if IsUnitInspectable(entry.unit) then
        table.remove(controller.retryQueue, i)
        table.insert(controller.inspectQueue, 1, entry.unit)
      else
        entry.nextRetry = now + controller.retryInterval
      end
    end
  end
end

local function OnUpdate(controller)
  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0

  if controller.isInspecting then
    if now - controller.lastInspectTime > controller.inspectTimeout then
      OnInspectTimeout(controller, now)
    end
    return
  end

  if TryDispatchInspect(controller, now) then
    return
  end

  ProcessRetryQueue(controller, now)
end

-- Item level reported by another addon (LibOpenRaid), never by our own
-- inspect. Priority, highest first: our own inspect (_localIlvlFresh), an
-- isiLive peer's synced value, LibOpenRaid. The external value therefore only
-- fills an empty field or replaces its own previous value; anything else in
-- the field came from inspect, from isiLive sync (KeySync BackfillStats) or
-- from the reload mirror and is kept. It is NOT marked _localIlvlFresh and NOT
-- written to ilvlCache: both mean "inspected", and claiming that would let a
-- broadcast suppress the sync backfill and the inspect that still owes us the
-- precise value. The inspect queue is untouched, so rio/spec still get fetched.
local function ApplyExternalIlvl(controller, unit, ilvl, roster)
  if type(roster) ~= "table" or unit == "player" then
    return false
  end
  local info = roster[unit]
  if type(info) ~= "table" or info.isGhost or IsGhostRosterUnit(unit, roster) then
    return false
  end
  if not addonTable.Validators.IsFiniteNumber(ilvl) or ilvl <= 0 or info._localIlvlFresh then
    return false
  end
  local guid = GetUnitGUIDSafe(unit)
  if not guid then
    return false
  end
  local previous = controller.externalIlvlCache[guid]
  if info.ilvl ~= nil and info.ilvl ~= previous then
    return false
  end
  controller.externalIlvlCache[guid] = ilvl
  if info.ilvl == ilvl then
    return false
  end
  info.ilvl = ilvl
  if controller.logRuntimeTracefDeep then
    controller.logRuntimeTracefDeep("[INSPECT] external_ilvl unit=%s ilvl=%s", tostring(unit), tostring(ilvl))
  end
  return true
end

function Inspect.CreateController(config)
  local controller = {}
  controller.inspectTimeout = tonumber(config and config.inspectTimeout) or 2
  controller.retryInterval = tonumber(config and config.retryInterval) or 5
  controller.inspectDelay = tonumber(config and config.inspectDelay) or 1
  controller.logRuntimeTracef = type(config and config.logRuntimeTracef) == "function" and config.logRuntimeTracef
    or nil
  controller.logRuntimeTracefDeep = type(config and config.logRuntimeTracefDeep) == "function"
      and config.logRuntimeTracefDeep
    or nil

  -- Local variable instead of a public controller field to prevent accidental
  -- external overwrites.
  local sendOwnKeySnapshot = type(config and config.sendOwnKeySnapshot) == "function" and config.sendOwnKeySnapshot
    or nil
  controller.onWorkQueued = type(config and config.onWorkQueued) == "function" and config.onWorkQueued or nil

  controller.inspectQueue = {}
  controller.retryQueue = {}
  controller.isInspecting = nil
  controller.lastInspectTime = 0
  controller.ilvlCache = {}
  controller.rioCache = {}
  controller.specCache = {}
  controller.specRoleCache = {}
  -- Last item level LibOpenRaid reported per GUID. Provenance for
  -- ApplyExternalIlvl: it tells "the roster value is ours to update" apart from
  -- "the roster value came from inspect, isiLive sync or the reload mirror".
  controller.externalIlvlCache = {}

  function controller.ResetQueues()
    controller.inspectQueue = {}
    controller.retryQueue = {}
    controller.isInspecting = nil
  end

  -- True while a unit is queued, waiting for a retry, or awaiting its
  -- INSPECT_READY / timeout. Without any of these OnUpdate has nothing to do.
  function controller.HasPendingWork()
    return controller.isInspecting ~= nil or #controller.inspectQueue > 0 or #controller.retryQueue > 0
  end

  -- Deferred retries (offline or out-of-range members) wait in the retry
  -- queue for retryInterval seconds. They are due within a small tolerance so
  -- a wake timer firing a frame early does not reschedule itself in a loop.
  local RETRY_DUE_TOLERANCE_SECONDS = 0.05
  local function CurrentTime()
    local getTimeFn = rawget(_G, "GetTime")
    return type(getTimeFn) == "function" and tonumber(getTimeFn()) or 0
  end

  -- True while OnUpdate has something to do right now: a queued unit, an
  -- in-flight inspect (timeout check) or a retry whose time has come.
  function controller.HasDueWork()
    if controller.isInspecting ~= nil or #controller.inspectQueue > 0 then
      return true
    end
    local now = CurrentTime()
    for _, entry in ipairs(controller.retryQueue) do
      if entry.nextRetry - now <= RETRY_DUE_TOLERANCE_SECONDS then
        return true
      end
    end
    return false
  end

  -- Seconds until the earliest deferred retry is due, or nil without retries.
  function controller.GetNextRetryDelay()
    local earliest = nil
    for _, entry in ipairs(controller.retryQueue) do
      if earliest == nil or entry.nextRetry < earliest then
        earliest = entry.nextRetry
      end
    end
    if earliest == nil then
      return nil
    end
    return math.max(earliest - CurrentTime(), RETRY_DUE_TOLERANCE_SECONDS)
  end

  function controller.ResetAll()
    controller.ResetQueues()
    controller.ilvlCache = {}
    controller.rioCache = {}
    controller.specCache = {}
    controller.specRoleCache = {}
    controller.externalIlvlCache = {}
  end

  function controller.QueueForceRefreshData(roster)
    QueueForceRefreshData(controller, roster)
  end

  function controller.EnqueueInspect(unit, roster)
    EnqueueInspect(controller, unit, roster)
  end

  function controller.InvalidateMember(unit, roster)
    return InvalidateMember(controller, unit, roster)
  end

  -- Role of the member's last inspected spec, or nil before an inspect.
  function controller.GetInspectedSpecRole(unit)
    local guid = GetUnitGUIDSafe(unit)
    return guid and controller.specRoleCache[guid] or nil
  end

  function controller.OnInspectReady(
    guid,
    roster,
    getUnitRio,
    getInspectSpecName,
    getPlayerSpecName,
    getOwnAverageItemLevel,
    getInspectSpecRole
  )
    return OnInspectReady(controller, guid, roster, {
      getUnitRio = getUnitRio,
      getInspectSpecName = getInspectSpecName,
      getPlayerSpecName = getPlayerSpecName,
      getOwnAverageItemLevel = getOwnAverageItemLevel,
      getInspectSpecRole = getInspectSpecRole,
    })
  end

  function controller.ApplyExternalIlvl(unit, ilvl, roster)
    return ApplyExternalIlvl(controller, unit, ilvl, roster)
  end

  function controller.OnUpdate()
    OnUpdate(controller)
  end

  function controller.TriggerOwnKeySnapshot(force, source)
    if sendOwnKeySnapshot then
      sendOwnKeySnapshot(force, source)
    end
  end

  return controller
end

-- LibOpenRaid-1.0 (ships with Details!) broadcasts every member's own item
-- level over addon comm, so it reaches us without an inspect, also for members
-- without isiLive and inside M+ where inspect is restricted. Optional: without
-- the library the bridge stays inert.
--
-- The library is resolved lazily (PLAYER_LOGIN or the first sweep), when every
-- addon has loaded, so no OptionalDeps entry is needed. It stores the pair
-- {handler, "OnGearUpdate"} and calls handler["OnGearUpdate"](...) with the
-- payload only (unitId, unitGearInfo, allUnitsGear), no self: the handler is a
-- table held for the whole session with a named member.
local OPEN_RAID_SWEEP_DELAY_SECONDS = 1

local function ReadOpenRaidIlvl(gearInfo)
  -- Secret check first: type() lies about a secret, and indexing a secret
  -- table raises.
  if IsSecretValue(gearInfo) or type(gearInfo) ~= "table" then
    return nil
  end
  local raw = gearInfo.ilevel
  if IsSecretValue(raw) or not addonTable.Validators.IsFiniteNumber(raw) or raw <= 0 then
    return nil
  end
  return raw
end

function Inspect.CreateOpenRaidBridge(config)
  local bridge = {}
  local inspectController = config and config.inspectController
  local getRoster = config and config.getRoster
  local isActive = config and config.isActive
  local onChanged = config and config.onChanged
  local lib = nil -- nil: not resolved yet, false: not installed
  local registered = false
  local sweepPending = false
  local handler = {}

  local function ResolveLib()
    if lib ~= nil then
      return lib or nil
    end
    local libStub = rawget(_G, "LibStub")
    local found = nil
    if type(libStub) == "table" and type(libStub.GetLibrary) == "function" then
      local ok, result = pcall(libStub.GetLibrary, libStub, "LibOpenRaid-1.0", true)
      found = ok and type(result) == "table" and result or nil
    end
    lib = found or false
    return found
  end

  local function CanApply()
    return type(inspectController) == "table"
      and type(getRoster) == "function"
      and (type(isActive) ~= "function" or isActive() == true)
  end

  -- The library resolves unitId from its own id cache, refreshed at the end of
  -- its roster handler, so an early comm can carry a bare name instead of a
  -- token. Unit APIs accept a group member's name; map it to our roster unit
  -- through the GUID.
  local function ResolveRosterUnit(unitId, roster)
    if IsSecretValue(unitId) or type(unitId) ~= "string" or unitId == "" then
      return nil
    end
    if type(roster[unitId]) == "table" then
      return unitId
    end
    local guid = GetUnitGUIDSafe(unitId)
    return guid and FindRosterUnitByGuid(roster, guid) or nil
  end

  local function Apply(unitId, gearInfo, roster)
    local unit = ResolveRosterUnit(unitId, roster)
    local ilvl = unit and ReadOpenRaidIlvl(gearInfo)
    if not ilvl then
      return false
    end
    return inspectController.ApplyExternalIlvl(unit, ilvl, roster) == true
  end

  function handler.OnGearUpdate(unitId, unitGearInfo)
    if not CanApply() then
      return
    end
    local roster = getRoster()
    if type(roster) == "table" and Apply(unitId, unitGearInfo, roster) and type(onChanged) == "function" then
      onChanged()
    end
  end

  function bridge.Attach()
    local openRaidLib = ResolveLib()
    if registered or not openRaidLib or type(openRaidLib.RegisterCallback) ~= "function" then
      return registered
    end
    local ok, result = pcall(openRaidLib.RegisterCallback, handler, "GearUpdate", "OnGearUpdate")
    registered = ok and result == true
    return registered
  end

  -- The callback only fires when a comm arrives. Gear the library received
  -- before we registered, or before the roster had the member, sits in its
  -- store; GetUnitGear(unit) is the public way to drain it.
  function bridge.Sweep()
    bridge.Attach()
    local openRaidLib = ResolveLib()
    if not openRaidLib or type(openRaidLib.GetUnitGear) ~= "function" or not CanApply() then
      return false
    end
    local roster = getRoster()
    if type(roster) ~= "table" then
      return false
    end
    local changed = false
    for unit, info in pairs(roster) do
      if unit ~= "player" and type(info) == "table" and not info.isGhost and IsExistingUnit(unit) then
        -- pcall is required: the library looks the unit up by name and uses
        -- that name as a table key, which raises when the name is secret.
        local ok, gearInfo = pcall(openRaidLib.GetUnitGear, unit)
        if ok and Apply(unit, gearInfo, roster) then
          changed = true
        end
      end
    end
    if changed and type(onChanged) == "function" then
      onChanged()
    end
    return changed
  end

  -- Collapses a burst of roster events into one sweep.
  -- Without the library there is nothing to drain, so no timer either.
  function bridge.ScheduleSweep()
    if sweepPending or not ResolveLib() then
      return
    end
    local timerApi = rawget(_G, "C_Timer")
    if type(timerApi) ~= "table" or type(timerApi.After) ~= "function" then
      bridge.Sweep()
      return
    end
    sweepPending = true
    timerApi.After(OPEN_RAID_SWEEP_DELAY_SECONDS, function()
      sweepPending = false
      bridge.Sweep()
    end)
  end

  return bridge
end
