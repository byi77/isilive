local _, addonTable = ...

addonTable = addonTable or {}

local Inspect = {}
addonTable.Inspect = Inspect

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

  local function IsUnitInInspectQueue(unit)
    for i = 1, #controller.inspectQueue do
      if controller.inspectQueue[i] == unit then
        return true
      end
    end
    return false
  end

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
        if not IsUnitInInspectQueue(unit) then
          table.insert(controller.inspectQueue, unit)
        end
      end
    end
  end

  function controller.EnqueueInspect(unit, roster)
    local guid = UnitGUID(unit)
    if guid and controller.ilvlCache[guid] then
      if roster[unit] then
        roster[unit].ilvl = controller.ilvlCache[guid]
      end
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

  function controller.OnInspectReady(guid, roster, getUnitRio, getInspectSpecName, getPlayerSpecName)
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

  function controller.OnUpdate()
    local now = GetTime()

    if controller.isInspecting then
      if now - controller.lastInspectTime > controller.inspectTimeout then
        table.insert(controller.retryQueue, {
          unit = controller.isInspecting,
          nextRetry = now + controller.retryInterval,
        })
        controller.isInspecting = nil
      end
      return
    end

    if #controller.inspectQueue > 0 then
      if now - controller.lastInspectTime < controller.inspectDelay then
        return
      end

      local unit = table.remove(controller.inspectQueue, 1)
      if UnitIsVisible(unit) and CanInspect(unit) then
        controller.isInspecting = unit
        controller.lastInspectTime = now
        NotifyInspect(unit)
      else
        table.insert(controller.retryQueue, { unit = unit, nextRetry = now + controller.retryInterval })
      end
      return
    end

    for i = #controller.retryQueue, 1, -1 do
      local entry = controller.retryQueue[i]
      if now >= entry.nextRetry then
        if UnitIsVisible(entry.unit) and CheckInteractDistance(entry.unit, 1) then
          table.remove(controller.retryQueue, i)
          table.insert(controller.inspectQueue, 1, entry.unit)
        else
          entry.nextRetry = now + controller.retryInterval
        end
      end
    end
  end

  return controller
end
