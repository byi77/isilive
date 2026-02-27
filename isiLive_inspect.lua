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

local function QueueForceRefreshData(controller, roster)
  controller.ResetQueues()
  for unit, info in pairs(roster or {}) do
    if UnitExists(unit) then
      local guid = UnitGUID(unit)
      if guid then
        controller.ilvlCache[guid] = nil
        controller.rioCache[guid] = nil
        controller.specCache[guid] = nil
      end
      info.spec = nil
      info.ilvl = nil
      info.rio = nil
      if not IsUnitInInspectQueue(controller, unit) then
        table.insert(controller.inspectQueue, unit)
      end
    end
  end
end

local function EnqueueInspect(controller, unit, roster)
  local guid = UnitGUID(unit)
  if guid and controller.ilvlCache[guid] and roster[unit] then
    roster[unit].ilvl = controller.ilvlCache[guid]
  end
  if guid and controller.rioCache[guid] and roster[unit] then
    roster[unit].rio = controller.rioCache[guid]
  end
  if guid and controller.specCache[guid] and roster[unit] then
    roster[unit].spec = controller.specCache[guid]
  end
  if guid and controller.ilvlCache[guid] and controller.rioCache[guid] and controller.specCache[guid] then
    return
  end

  if roster[unit] and (not roster[unit].ilvl or not roster[unit].rio or not roster[unit].spec) then
    table.insert(controller.inspectQueue, unit)
  end
end

local function OnInspectReady(controller, guid, roster, getUnitRio, getInspectSpecName, getPlayerSpecName)
  if not (controller.isInspecting and UnitGUID(controller.isInspecting) == guid) then
    return false
  end

  local ilvl = C_PaperDollInfo.GetInspectItemLevel(controller.isInspecting)
  if roster[controller.isInspecting] then
    roster[controller.isInspecting].ilvl = ilvl
  end
  if ilvl and ilvl > 0 then
    controller.ilvlCache[guid] = ilvl
  end

  local rio = getUnitRio and getUnitRio(controller.isInspecting) or nil
  if roster[controller.isInspecting] then
    roster[controller.isInspecting].rio = rio
  end
  if rio and rio > 0 then
    controller.rioCache[guid] = rio
  end

  local specName = getInspectSpecName and getInspectSpecName(controller.isInspecting) or nil
  if not specName and controller.isInspecting == "player" and getPlayerSpecName then
    specName = getPlayerSpecName()
  end
  if roster[controller.isInspecting] then
    roster[controller.isInspecting].spec = specName
  end
  if specName and specName ~= "" then
    controller.specCache[guid] = specName
  end

  controller.isInspecting = nil
  controller.lastInspectTime = GetTime()
  return true
end

local function OnInspectTimeout(controller, now)
  table.insert(controller.retryQueue, {
    unit = controller.isInspecting,
    nextRetry = now + controller.retryInterval,
  })
  controller.isInspecting = nil
end

local function IsUnitInspectable(unit)
  return UnitIsVisible(unit) and CanInspect(unit)
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

  return controller
end
