local _, addonTable = ...

addonTable = addonTable or {}

local Group = {}
addonTable.Group = Group

local function BuildDeps(opts)
  opts = opts or {}

  return {
    printFn = opts.printFn or print,
    getL = opts.getL or function()
      return {}
    end,
    isRosterCollapsed = opts.isRosterCollapsed or function()
      return false
    end,
    isInGroup = opts.isInGroup or function()
      return false
    end,
    getNumGroupMembers = opts.getNumGroupMembers or function()
      return 0
    end,
    getActiveChallengeMapID = opts.getActiveChallengeMapID or function()
      return nil
    end,
    getWasInGroup = opts.getWasInGroup or function()
      return false
    end,
    setWasInGroup = opts.setWasInGroup or function(_value) end,
    getWasRaidGroup = opts.getWasRaidGroup or function()
      return false
    end,
    setWasRaidGroup = opts.setWasRaidGroup or function(_value) end,
    setWasGroupLeader = opts.setWasGroupLeader or function(_value) end,
    getRoster = opts.getRoster or function()
      return {}
    end,
    setRoster = opts.setRoster or function(_value) end,
    captureQueueJoinCandidate = opts.captureQueueJoinCandidate or function() end,
    announceQueuedGroupJoin = opts.announceQueuedGroupJoin or function() end,
    setMainFrameVisible = opts.setMainFrameVisible or function(_visible) end,
    switchToRaidMode = opts.switchToRaidMode or function() end,
    updateLeaderButtons = opts.updateLeaderButtons or function() end,
    clearLatestQueueTarget = opts.clearLatestQueueTarget or function() end,
    clearRioBaselineSnapshot = opts.clearRioBaselineSnapshot or function() end,
    clearKnownUsers = opts.clearKnownUsers or function() end,
    resetInspectAll = opts.resetInspectAll or function() end,
    resetInspectQueues = opts.resetInspectQueues or function() end,
    updateUI = opts.updateUI or function() end,
    updateMPlusTeleportButton = opts.updateMPlusTeleportButton or function() end,
    getUnitNameAndRealm = opts.getUnitNameAndRealm or function(_unit)
      return nil, nil
    end,
    getUnitClass = opts.getUnitClass or function(_unit)
      return nil, nil
    end,
    getUnitServerLanguage = opts.getUnitServerLanguage or function(_unit, _realm)
      return "??"
    end,
    getOwnedKeystoneSnapshot = opts.getOwnedKeystoneSnapshot or function()
      return nil, nil
    end,
    markIsiLiveUser = opts.markIsiLiveUser or function(_name, _realm) end,
    setPlayerKeyInfo = opts.setPlayerKeyInfo or function(_name, _realm, _mapID, _level) end,
    getUnitRole = opts.getUnitRole or function(_unit)
      return nil
    end,
    getPlayerSpecName = opts.getPlayerSpecName or function()
      return nil
    end,
    getUnitRio = opts.getUnitRio or function(_unit)
      return nil
    end,
    unitHasIsiLive = opts.unitHasIsiLive or function(_unit)
      return false
    end,
    applyKnownKeyToRosterEntry = opts.applyKnownKeyToRosterEntry or function(_info)
      return false
    end,
    enqueueInspect = opts.enqueueInspect or function(_unit) end,
    sendOwnKeySnapshot = opts.sendOwnKeySnapshot or function(_force) end,
    sendIsiLiveHello = opts.sendIsiLiveHello or function(_force) end,
  }
end

local SetIfNotNil
local UpdatePlayerEntry

local function HandleNoGroup(deps, wasInGroupBefore)
  deps.setWasGroupLeader(nil)
  deps.setWasRaidGroup(false)
  deps.clearRioBaselineSnapshot()
  local leftGroupNow = wasInGroupBefore and not deps.isInGroup()
  if leftGroupNow then
    deps.clearLatestQueueTarget()
    deps.clearKnownUsers()

    local roster = deps.getRoster()
    local newRoster = {}
    newRoster.player = UpdatePlayerEntry(deps, roster.player, true)

    for unit, info in pairs(roster) do
      if unit ~= "player" then
        info.isGhost = true
        local key = "ghost:" .. (info.name or "Unknown") .. "-" .. (info.realm or "")
        newRoster[key] = info
      end
    end
    deps.setRoster(newRoster)
  end
  deps.resetInspectAll()
  deps.updateUI()
  deps.updateMPlusTeleportButton()
  deps.updateLeaderButtons()

  -- Auto-hide when solo if enabled
  if leftGroupNow and type(deps.autoHideSolo) == "function" then
    deps.autoHideSolo()
  end
end

-- Ghosts werden nur entfernt, wenn die Gruppe voll besetzt ist (5 aktive Mitglieder).
-- Bei weniger als 5 aktiven Mitgliedern bleiben Ghosts als sichtbare Historie erhalten.
-- Intentionelles Design: Eine 4er-Gruppe soll frühere Zusammensetzungen noch zeigen.
local function PruneGhosts(roster)
  local activeCount = 0
  local ghosts = {}
  for unit, info in pairs(roster) do
    if not info.isGhost then
      activeCount = activeCount + 1
    else
      table.insert(ghosts, unit)
    end
  end

  for _, ghostUnit in ipairs(ghosts) do
    if activeCount >= 5 then
      roster[ghostUnit] = nil
    end
  end
end

SetIfNotNil = function(entry, key, value)
  if value ~= nil then
    entry[key] = value
  end
end

UpdatePlayerEntry = function(deps, playerEntry, preserveIlvl)
  if type(playerEntry) ~= "table" then
    playerEntry = {}
  end

  local name, realm = deps.getUnitNameAndRealm("player")
  local _, class = deps.getUnitClass("player")
  local language = deps.getUnitServerLanguage("player", realm)
  local ownKeyMapID, ownKeyLevel = deps.getOwnedKeystoneSnapshot()

  deps.markIsiLiveUser(name, realm)
  deps.setPlayerKeyInfo(name, realm, ownKeyMapID, ownKeyLevel)

  SetIfNotNil(playerEntry, "name", name)
  SetIfNotNil(playerEntry, "realm", realm)
  SetIfNotNil(playerEntry, "language", language)
  SetIfNotNil(playerEntry, "class", class)
  SetIfNotNil(playerEntry, "role", deps.getUnitRole("player"))
  SetIfNotNil(playerEntry, "keyMapID", ownKeyMapID)
  SetIfNotNil(playerEntry, "keyLevel", ownKeyLevel)
  playerEntry.hasIsiLive = true
  playerEntry.isGhost = false

  if not playerEntry._refreshQueued then
    SetIfNotNil(playerEntry, "spec", deps.getPlayerSpecName())
    SetIfNotNil(playerEntry, "rio", deps.getUnitRio("player"))
    if not preserveIlvl and not playerEntry._localIlvlFresh then
      playerEntry.ilvl = nil
    end
  end

  return playerEntry
end

local function AddPlayerToRoster(deps, roster)
  roster.player = UpdatePlayerEntry(deps, roster.player, false)
  deps.enqueueInspect("player")
end

local function UpdatePartyMembersInRoster(deps, roster)
  -- 1. Identify current group members to protect them from ghosting
  local currentMemberKeys = {}
  local unreadablePartySlots = {}
  local name, realm = deps.getUnitNameAndRealm("player")
  if name then
    currentMemberKeys[name .. "-" .. (realm or "")] = true
  end

  local members = deps.getNumGroupMembers()
  for i = 1, members - 1 do
    local unit = "party" .. i
    local memberName, memberRealm = deps.getUnitNameAndRealm(unit)
    if memberName then
      currentMemberKeys[memberName .. "-" .. (memberRealm or "")] = true
    else
      -- A transient UnitExists race should not turn a still-occupied slot into a ghost.
      unreadablePartySlots[unit] = true
    end
  end

  -- 2. Convert missing members to ghosts BEFORE overwriting slots
  local ghostConversions = {}
  for unit, info in pairs(roster) do
    if unit ~= "player" and string.find(unit, "^party") and not info.isGhost then
      if not unreadablePartySlots[unit] then
        local key = info.name .. "-" .. (info.realm or "")
        if not currentMemberKeys[key] then
          table.insert(ghostConversions, {
            partyUnit = unit,
            ghostKey = "ghost:" .. key,
            info = info,
          })
        end
      end
    end
  end

  for _, conversion in ipairs(ghostConversions) do
    conversion.info.isGhost = true
    roster[conversion.ghostKey] = conversion.info
    roster[conversion.partyUnit] = nil
  end

  -- 3. Update slots with current group data (preserving data across slot shifts)
  -- Build a lookup for existing data by name to handle slot swaps
  local existingDataByName = {}
  local slotsToClear = {}
  for unit, info in pairs(roster) do
    if info.name then
      existingDataByName[info.name .. "-" .. (info.realm or "")] = info
    end
    -- Clear all party slots to avoid duplicates/stale entries when group shrinks or shifts
    if string.find(unit, "^party") and not unreadablePartySlots[unit] then
      table.insert(slotsToClear, unit)
    end
  end
  for _, unit in ipairs(slotsToClear) do
    roster[unit] = nil
  end

  for i = 1, members - 1 do
    local unit = "party" .. i
    local memberName, memberRealm = deps.getUnitNameAndRealm(unit)
    if memberName then
      local _, memberClass = deps.getUnitClass(unit)
      local memberLanguage = deps.getUnitServerLanguage(unit, memberRealm)

      -- Try to find existing data for this PLAYER, not just this SLOT
      local existing = existingDataByName[memberName .. "-" .. (memberRealm or "")]

      local keyMapID = existing and existing.keyMapID
      local keyLevel = existing and existing.keyLevel
      local spec = existing and existing.spec
      local ilvl = existing and existing.ilvl
      local rio = existing and existing.rio
      local refreshQueued = existing and existing._refreshQueued
      local localSpecFresh = existing and existing._localSpecFresh
      local localIlvlFresh = existing and existing._localIlvlFresh
      local localRioFresh = existing and existing._localRioFresh
      local localDpsFresh = existing and existing._localDpsFresh

      roster[unit] = {
        name = memberName,
        realm = memberRealm,
        language = memberLanguage,
        class = memberClass,
        role = deps.getUnitRole(unit),
        spec = spec,
        ilvl = ilvl,
        rio = rio,
        hasIsiLive = deps.unitHasIsiLive(unit),
        keyMapID = keyMapID,
        keyLevel = keyLevel,
        isGhost = false,
        _refreshQueued = refreshQueued,
        _localSpecFresh = localSpecFresh,
        _localIlvlFresh = localIlvlFresh,
        _localRioFresh = localRioFresh,
        _localDpsFresh = localDpsFresh,
      }

      -- If we pulled data from a ghost slot (resurrected player), clear the ghost entry
      local ghostKey = "ghost:" .. memberName .. "-" .. (memberRealm or "")
      if roster[ghostKey] then
        roster[ghostKey] = nil
      end

      deps.applyKnownKeyToRosterEntry(roster[unit])
      deps.enqueueInspect(unit)
    end
  end

  PruneGhosts(roster)
end

local function HandleGroupRosterUpdate(deps)
  local wasInGroupBefore = deps.getWasInGroup() and true or false
  local inGroupNow = deps.isInGroup() and true or false
  local joinedNow = inGroupNow and not wasInGroupBefore
  deps.setWasInGroup(inGroupNow)

  if deps.getActiveChallengeMapID() then
    deps.updateUI()
    deps.updateLeaderButtons()
    return
  end

  if not inGroupNow then
    HandleNoGroup(deps, wasInGroupBefore)
    return
  end

  local numMembers = deps.getNumGroupMembers()
  local wasRaidGroupBefore = deps.getWasRaidGroup() and true or false
  if numMembers > 5 then
    if not wasRaidGroupBefore then
      local L = deps.getL()
      if L.RAID_GROUP_HIDDEN then
        deps.printFn(L.RAID_GROUP_HIDDEN)
      end
      deps.switchToRaidMode()
    end
    deps.setWasRaidGroup(true)
    deps.setMainFrameVisible(true)
    deps.updateLeaderButtons()
    return
  end

  deps.setWasRaidGroup(false)
  if joinedNow then
    deps.setRoster({})
    deps.setMainFrameVisible(true, "queue")
    deps.captureQueueJoinCandidate()
    deps.announceQueuedGroupJoin()
  end

  local roster = deps.getRoster()
  deps.resetInspectQueues()

  AddPlayerToRoster(deps, roster)
  UpdatePartyMembersInRoster(deps, roster)

  deps.sendOwnKeySnapshot(false, "group")
  deps.updateUI()
  deps.updateLeaderButtons()
  deps.sendIsiLiveHello(false, "group")
end

function Group.CreateController(opts)
  local deps = BuildDeps(opts)

  local controller = {}

  function controller.HandleGroupRosterUpdate()
    HandleGroupRosterUpdate(deps)
  end

  return controller
end
