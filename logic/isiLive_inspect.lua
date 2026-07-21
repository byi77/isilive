local _, addonTable = ...

addonTable = addonTable or {}

local Inspect = {}
addonTable.Inspect = Inspect

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
  if ok then
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

local function OnInspectReady(
  controller,
  guid,
  roster,
  getUnitRio,
  getInspectSpecName,
  getPlayerSpecName,
  getOwnAverageItemLevel,
  getInspectSpecRole
)
  local inspectedUnit = controller.isInspecting
  if not (inspectedUnit and GetUnitGUIDSafe(inspectedUnit) == guid) then
    return false
  end

  local ilvl = nil
  if C_PaperDollInfo and type(C_PaperDollInfo.GetInspectItemLevel) == "function" then
    local ok, ilvlResult = pcall(C_PaperDollInfo.GetInspectItemLevel, inspectedUnit)
    if ok then
      ilvl = ilvlResult
    end
  end
  -- GetInspectItemLevel("player") returns 0/nil in most contexts (in M+ under
  -- 12.0 the inspect path is restricted entirely). Fall back to the local
  -- C_Item.GetAverageItemLevel for own player so we never write a useless 0.
  if (not ilvl or ilvl <= 0) and inspectedUnit == "player" and type(getOwnAverageItemLevel) == "function" then
    local ownIlvl = getOwnAverageItemLevel()
    if type(ownIlvl) == "number" and ownIlvl > 0 then
      ilvl = ownIlvl
    end
  end
  local ilvlChanged = false
  if roster[inspectedUnit] then
    -- Only write a real value: do NOT overwrite a previously-good ilvl with a
    -- transient 0/nil from a partial inspect response. Preserves data both for
    -- player (our local-API fallback above) and for party members between
    -- successful inspects.
    if ilvl and ilvl > 0 then
      if roster[inspectedUnit].ilvl ~= ilvl then
        ilvlChanged = true
      end
      roster[inspectedUnit].ilvl = ilvl
      roster[inspectedUnit]._localIlvlFresh = true
    end
  end
  if ilvl and ilvl > 0 then
    controller.ilvlCache[guid] = ilvl
  end

  local rio = getUnitRio and getUnitRio(inspectedUnit) or nil
  local rioChanged = false
  if roster[inspectedUnit] then
    if roster[inspectedUnit].rio ~= rio then
      rioChanged = true
    end
    roster[inspectedUnit].rio = rio
    if rio and rio >= 0 then
      roster[inspectedUnit]._localRioFresh = true
    end
  end
  if rio and rio > 0 then
    controller.rioCache[guid] = rio
  end

  local specName = getInspectSpecName and getInspectSpecName(inspectedUnit) or nil
  if not specName and inspectedUnit == "player" and getPlayerSpecName then
    specName = getPlayerSpecName()
  end
  local specChanged = false
  if roster[inspectedUnit] then
    if roster[inspectedUnit].spec ~= specName then
      specChanged = true
    end
    roster[inspectedUnit].spec = specName
    if specName and specName ~= "" then
      roster[inspectedUnit]._localSpecFresh = true
    end
  end
  if specName and specName ~= "" then
    controller.specCache[guid] = specName
  end

  local specRole = type(getInspectSpecRole) == "function" and getInspectSpecRole(inspectedUnit) or nil
  local roleChanged = false
  if
    roster[inspectedUnit]
    and (specRole == "TANK" or specRole == "HEALER" or specRole == "DAMAGER")
    and roster[inspectedUnit].role ~= specRole
  then
    roster[inspectedUnit].role = specRole
    roleChanged = true
  end

  if roster[inspectedUnit] then
    roster[inspectedUnit]._refreshQueued = nil
  end
  controller.isInspecting = nil
  local getTimeFn = rawget(_G, "GetTime")
  controller.lastInspectTime = type(getTimeFn) == "function" and getTimeFn() or 0

  local dataChanged = ilvlChanged or rioChanged or specChanged or roleChanged
  if controller.logRuntimeTracef then
    controller.logRuntimeTracef(
      "[INSPECT] result unit=%s ilvl=%s rio=%s spec=%s role=%s "
        .. "ilvlChanged=%s rioChanged=%s specChanged=%s roleChanged=%s",
      tostring(inspectedUnit),
      tostring(ilvl),
      tostring(rio),
      tostring(specName),
      tostring(specRole),
      tostring(ilvlChanged),
      tostring(rioChanged),
      tostring(specChanged),
      tostring(roleChanged)
    )
  end
  if inspectedUnit == "player" and dataChanged and controller.TriggerOwnKeySnapshot then
    controller.TriggerOwnKeySnapshot(false, "inspect")
  end

  return dataChanged
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
  if not okVisible or not isVisible then
    return false
  end

  local canInspectFn = rawget(_G, "CanInspect")
  if type(canInspectFn) ~= "function" then
    return false
  end

  local okCanInspect, canInspect = pcall(canInspectFn, unit)
  if not okCanInspect or not canInspect then
    return false
  end
  return true
end

local function TryDispatchInspect(controller, now)
  if #controller.inspectQueue == 0 then
    return false
  end

  if now - controller.lastInspectTime < controller.inspectDelay then
    return true
  end

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

  controller.inspectQueue = {}
  controller.retryQueue = {}
  controller.isInspecting = nil
  controller.lastInspectTime = 0
  controller.ilvlCache = {}
  controller.rioCache = {}
  controller.specCache = {}

  function controller.ResetQueues()
    controller.inspectQueue = {}
    controller.retryQueue = {}
    controller.isInspecting = nil
  end

  function controller.ResetAll()
    controller.ResetQueues()
    controller.ilvlCache = {}
    controller.rioCache = {}
    controller.specCache = {}
  end

  function controller.QueueForceRefreshData(roster)
    QueueForceRefreshData(controller, roster)
  end

  function controller.EnqueueInspect(unit, roster)
    EnqueueInspect(controller, unit, roster)
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
    return OnInspectReady(
      controller,
      guid,
      roster,
      getUnitRio,
      getInspectSpecName,
      getPlayerSpecName,
      getOwnAverageItemLevel,
      getInspectSpecRole
    )
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
