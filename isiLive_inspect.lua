local addonName, addonTable = ...

addonTable = addonTable or {}

local Inspect = {}
addonTable.Inspect = Inspect

function Inspect.CreateController(config)
    local self = {}
    self.inspectTimeout = tonumber(config and config.inspectTimeout) or 2
    self.retryInterval = tonumber(config and config.retryInterval) or 5
    self.inspectDelay = tonumber(config and config.inspectDelay) or 1

    self.inspectQueue = {}
    self.retryQueue = {}
    self.isInspecting = nil
    self.lastInspectTime = 0
    self.ilvlCache = {}
    self.rioCache = {}
    self.specCache = {}

    local function IsUnitInInspectQueue(unit)
        for i = 1, #self.inspectQueue do
            if self.inspectQueue[i] == unit then
                return true
            end
        end
        return false
    end

    function self:ResetQueues()
        self.inspectQueue = {}
        self.retryQueue = {}
        self.isInspecting = nil
    end

    function self:ResetAll()
        self:ResetQueues()
        self.ilvlCache = {}
        self.rioCache = {}
        self.specCache = {}
    end

    function self:QueueForceRefreshData(roster)
        self:ResetQueues()
        for unit, info in pairs(roster or {}) do
            if UnitExists(unit) then
                local guid = UnitGUID(unit)
                if guid then
                    self.ilvlCache[guid] = nil
                    self.rioCache[guid] = nil
                    self.specCache[guid] = nil
                end
                info.spec = nil
                info.ilvl = nil
                info.rio = nil
                if not IsUnitInInspectQueue(unit) then
                    table.insert(self.inspectQueue, unit)
                end
            end
        end
    end

    function self:EnqueueInspect(unit, roster)
        local guid = UnitGUID(unit)
        if guid and self.ilvlCache[guid] then
            if roster[unit] then
                roster[unit].ilvl = self.ilvlCache[guid]
            end
        end
        if guid and self.rioCache[guid] and roster[unit] then
            roster[unit].rio = self.rioCache[guid]
        end
        if guid and self.specCache[guid] and roster[unit] then
            roster[unit].spec = self.specCache[guid]
        end
        if guid and self.ilvlCache[guid] and self.rioCache[guid] and self.specCache[guid] then
            return
        end

        if roster[unit] and (not roster[unit].ilvl or not roster[unit].rio or not roster[unit].spec) then
            table.insert(self.inspectQueue, unit)
        end
    end

    function self:OnInspectReady(guid, roster, getUnitRio, getInspectSpecName, getPlayerSpecName)
        if not (self.isInspecting and UnitGUID(self.isInspecting) == guid) then
            return false
        end

        local ilvl = C_PaperDollInfo.GetInspectItemLevel(self.isInspecting)
        if roster[self.isInspecting] then
            roster[self.isInspecting].ilvl = ilvl
        end
        if ilvl and ilvl > 0 then
            self.ilvlCache[guid] = ilvl
        end

        local rio = getUnitRio and getUnitRio(self.isInspecting) or nil
        if roster[self.isInspecting] then
            roster[self.isInspecting].rio = rio
        end
        if rio and rio > 0 then
            self.rioCache[guid] = rio
        end

        local specName = getInspectSpecName and getInspectSpecName(self.isInspecting) or nil
        if not specName and self.isInspecting == "player" and getPlayerSpecName then
            specName = getPlayerSpecName()
        end
        if roster[self.isInspecting] then
            roster[self.isInspecting].spec = specName
        end
        if specName and specName ~= "" then
            self.specCache[guid] = specName
        end

        self.isInspecting = nil
        self.lastInspectTime = GetTime()
        return true
    end

    function self:OnUpdate()
        local now = GetTime()

        if self.isInspecting then
            if now - self.lastInspectTime > self.inspectTimeout then
                table.insert(self.retryQueue, { unit = self.isInspecting, nextRetry = now + self.retryInterval })
                self.isInspecting = nil
            end
            return
        end

        if #self.inspectQueue > 0 then
            if now - self.lastInspectTime < self.inspectDelay then
                return
            end

            local unit = table.remove(self.inspectQueue, 1)
            if UnitIsVisible(unit) and CanInspect(unit) then
                self.isInspecting = unit
                self.lastInspectTime = now
                NotifyInspect(unit)
            else
                table.insert(self.retryQueue, { unit = unit, nextRetry = now + self.retryInterval })
            end
            return
        end

        for i = #self.retryQueue, 1, -1 do
            local entry = self.retryQueue[i]
            if now >= entry.nextRetry then
                if UnitIsVisible(entry.unit) and CheckInteractDistance(entry.unit, 1) then
                    table.remove(self.retryQueue, i)
                    table.insert(self.inspectQueue, 1, entry.unit)
                else
                    entry.nextRetry = now + self.retryInterval
                end
            end
        end
    end

    return self
end

