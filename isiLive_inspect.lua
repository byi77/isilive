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

local function IsExistingUnit(unit)
  if type(unit) ~= "string" or unit == "" then
    return false
  end

  local unitExists = rawget(_G, "UnitExists")
  if type(unitExists) ~= "function" then
    return false
  end

  local ok, exists = pcall(unitExists, unit)
  return ok and exists == true
end

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

local function OnInspectReady(controller, guid, roster, getUnitRio, getInspectSpecName, getPlayerSpecName)
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
  local ilvlChanged = false
  if roster[inspectedUnit] then
    if roster[inspectedUnit].ilvl ~= ilvl then
      ilvlChanged = true
    end
    roster[inspectedUnit].ilvl = ilvl
    if ilvl and ilvl > 0 then
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

  if roster[inspectedUnit] then
    roster[inspectedUnit]._refreshQueued = nil
  end
  controller.isInspecting = nil
  controller.lastInspectTime = GetTime()

  local dataChanged = ilvlChanged or rioChanged or specChanged
  if inspectedUnit == "player" and dataChanged and controller.TriggerOwnKeySnapshot then
    controller.TriggerOwnKeySnapshot(false)
  end

  return dataChanged
end

local function OnInspectTimeout(controller, now)
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
    controller.isInspecting = unit
    controller.lastInspectTime = now
    NotifyInspect(unit)
  else
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
  local now = GetTime()

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

  -- Lokale Variable statt öffentlichem Controller-Feld, um versehentliches
  -- Überschreiben von außen zu verhindern.
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

  function controller.OnInspectReady(guid, roster, getUnitRio, getInspectSpecName, getPlayerSpecName)
    return OnInspectReady(controller, guid, roster, getUnitRio, getInspectSpecName, getPlayerSpecName)
  end

  function controller.OnUpdate()
    OnUpdate(controller)
  end

  function controller.TriggerOwnKeySnapshot(force)
    if sendOwnKeySnapshot then
      sendOwnKeySnapshot(force)
    end
  end

  return controller
end
