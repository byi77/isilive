local _, addonTable = ...

addonTable = addonTable or {}

local Group = {}
addonTable.Group = Group

local function falsefn()
  return false
end
local function nilpairfn()
  return nil, nil
end
local function emptyfn() end

local function BuildDeps(opts)
  opts = opts or {}

  return {
    printFn = opts.printFn or print,
    getL = opts.getL or function()
      return {}
    end,
    isRosterCollapsed = opts.isRosterCollapsed or falsefn,
    isInGroup = opts.isInGroup or falsefn,
    getNumGroupMembers = opts.getNumGroupMembers or function()
      return 0
    end,
    getActiveChallengeMapID = opts.getActiveChallengeMapID or function()
      return nil
    end,
    getWasInGroup = opts.getWasInGroup or falsefn,
    setWasInGroup = opts.setWasInGroup or emptyfn,
    getWasRaidGroup = opts.getWasRaidGroup or falsefn,
    setWasRaidGroup = opts.setWasRaidGroup or emptyfn,
    setWasGroupLeader = opts.setWasGroupLeader or emptyfn,
    getRoster = opts.getRoster or function()
      return {}
    end,
    setRoster = opts.setRoster or emptyfn,
    captureQueueJoinCandidate = opts.captureQueueJoinCandidate or emptyfn,
    announceQueuedGroupJoin = opts.announceQueuedGroupJoin or emptyfn,
    setMainFrameVisible = opts.setMainFrameVisible or emptyfn,
    updateLeaderButtons = opts.updateLeaderButtons or emptyfn,
    clearLatestQueueTarget = opts.clearLatestQueueTarget or emptyfn,
    clearRioBaselineSnapshot = opts.clearRioBaselineSnapshot or emptyfn,
    clearKnownUsers = opts.clearKnownUsers or emptyfn,
    resetInspectAll = opts.resetInspectAll or emptyfn,
    resetInspectQueues = opts.resetInspectQueues or emptyfn,
    updateUI = opts.updateUI or function() end,
    updateMPlusTeleportButton = opts.updateMPlusTeleportButton or function() end,
    clearPendingQueueJoinInfo = opts.clearPendingQueueJoinInfo or function() end,
    getUnitNameAndRealm = opts.getUnitNameAndRealm or function(_unit)
      return nil, nil
    end,
    getUnitClass = opts.getUnitClass or function(_unit)
      return nil, nil
    end,
    getUnitServerLanguage = opts.getUnitServerLanguage or function(_unit, _realm)
      return "??"
    end,
    getOwnedKeystoneSnapshot = opts.getOwnedKeystoneSnapshot or nilpairfn,
    markIsiLiveUser = opts.markIsiLiveUser or emptyfn,
    setPlayerKeyInfo = opts.setPlayerKeyInfo or emptyfn,
    getUnitRole = opts.getUnitRole or function()
      return nil
    end,
    getPlayerSpecName = opts.getPlayerSpecName or function()
      return nil
    end,
    getUnitRio = opts.getUnitRio or function()
      return nil
    end,
    unitIsGroupLeader = opts.unitIsGroupLeader or function(_unit)
      return false
    end,
    unitHasIsiLive = opts.unitHasIsiLive or falsefn,
    applyKnownKeyToRosterEntry = opts.applyKnownKeyToRosterEntry or falsefn,
    enqueueInspect = opts.enqueueInspect or emptyfn,
    sendOwnKeySnapshot = opts.sendOwnKeySnapshot or emptyfn,
    sendIsiLiveHello = opts.sendIsiLiveHello or emptyfn,
    sendRefreshRequest = opts.sendRefreshRequest or emptyfn,
    onGroupJoined = opts.onGroupJoined or function() end,
    onMemberJoinedGroup = opts.onMemberJoinedGroup or emptyfn,
    timerAfter = opts.timerAfter or function(_, cb)
      cb()
    end,
    shouldAutoCloseMainFrame = opts.shouldAutoCloseMainFrame or falsefn,
    getRaidTransitionBehavior = opts.getRaidTransitionBehavior or function()
      return "hide"
    end,
    autoCloseMainFrame = opts.autoCloseMainFrame or emptyfn,
  }
end

local GHOST_KEY_PREFIX = "ghost:"

local function MemberKey(name, realm)
  return (name or "Unknown") .. "-" .. (realm or "")
end

local function GhostKey(name, realm)
  return GHOST_KEY_PREFIX .. MemberKey(name, realm)
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
        info.isLeader = false
        newRoster[GhostKey(info.name, info.realm)] = info
      end
    end
    deps.setRoster(newRoster)
  end
  deps.resetInspectAll()
  deps.updateUI()
  deps.updateMPlusTeleportButton()
  deps.updateLeaderButtons()

  -- Optional runtime auto-close on solo transition
  if leftGroupNow and deps.shouldAutoCloseMainFrame() and type(deps.autoCloseMainFrame) == "function" then
    deps.autoCloseMainFrame()
  end
end

-- Ghosts are only removed when the group has 5 or more active members.
-- With fewer than 5 active members ghosts are kept as visible history.
-- Intentional design: a 4-person group should still show previous compositions.
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
  playerEntry.isLeader = deps.unitIsGroupLeader("player") == true
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

local function UpdatePartyMembersInRoster(deps, roster, callbacks)
  -- 1. Identify current group members to protect them from ghosting
  local currentMemberKeys = {}
  local unreadablePartySlots = {}
  local name, realm = deps.getUnitNameAndRealm("player")
  if name then
    currentMemberKeys[MemberKey(name, realm)] = true
  end

  local members = deps.getNumGroupMembers()
  for i = 1, members - 1 do
    local unit = "party" .. i
    local memberName, memberRealm = deps.getUnitNameAndRealm(unit)
    if memberName then
      currentMemberKeys[MemberKey(memberName, memberRealm)] = true
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
        local key = MemberKey(info.name, info.realm)
        if not currentMemberKeys[key] then
          table.insert(ghostConversions, {
            partyUnit = unit,
            ghostKey = GhostKey(info.name, info.realm),
            info = info,
          })
        end
      end
    end
  end

  for _, conversion in ipairs(ghostConversions) do
    conversion.info.isGhost = true
    conversion.info.isLeader = false
    roster[conversion.ghostKey] = conversion.info
    roster[conversion.partyUnit] = nil
  end

  -- 3. Update slots with current group data (preserving data across slot shifts)
  -- Build a lookup for existing data by name to handle slot swaps
  local existingDataByName = {}
  local slotsToClear = {}
  for unit, info in pairs(roster) do
    if info.name then
      existingDataByName[MemberKey(info.name, info.realm)] = info
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
      local existing = existingDataByName[MemberKey(memberName, memberRealm)]

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
        isLeader = deps.unitIsGroupLeader(unit) == true,
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

      -- Fire sound if this is a genuinely new member (not seen before, not a ghost resurrection)
      local ghostKey = GhostKey(memberName, memberRealm)
      local shouldPlayJoinSound = false
      if callbacks and type(callbacks.onMemberJoinedGroup) == "function" then
        shouldPlayJoinSound = not existing or existing.isGhost == true
      end
      if shouldPlayJoinSound then
        callbacks.onMemberJoinedGroup()
      end

      -- If we pulled data from a ghost slot (resurrected player), clear the ghost entry
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
  local wasInGroupBefore = deps.getWasInGroup() == true
  local inGroupNow = deps.isInGroup() == true
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
      deps.clearPendingQueueJoinInfo()
      deps.clearLatestQueueTarget()
      deps.clearRioBaselineSnapshot()
      deps.resetInspectAll()
      deps.resetInspectQueues()
      deps.setRoster({})
    end
    deps.setWasRaidGroup(true)
    deps.setMainFrameVisible(false, {
      reason = "raid",
      skipShowCallbacks = true,
    })
    return
  end

  deps.setWasRaidGroup(false)
  if wasRaidGroupBefore then
    deps.clearKnownUsers()
  end
  if joinedNow then
    deps.setRoster({})
    deps.setMainFrameVisible(true, {
      reason = "queue",
      skipShowCallbacks = true,
    })
    -- Pre-sync leader state so PARTY_LEADER_CHANGED does not trigger a
    -- "you are now leader" notification when the player created the group.
    if deps.unitIsGroupLeader("player") then
      deps.setWasGroupLeader(true)
    end
    deps.captureQueueJoinCandidate()
    deps.announceQueuedGroupJoin()
    deps.onGroupJoined()
  end

  local roster = deps.getRoster()
  deps.resetInspectQueues()

  AddPlayerToRoster(deps, roster)
  UpdatePartyMembersInRoster(deps, roster, joinedNow and nil or deps)

  deps.sendOwnKeySnapshot(joinedNow, "group")
  deps.updateUI()
  deps.updateLeaderButtons()
  deps.sendIsiLiveHello(joinedNow, "group")
  if joinedNow then
    -- Delay to ensure IsInGroup() has settled before sending addon messages.
    deps.timerAfter(0.5, function()
      deps.sendRefreshRequest(true)
    end)
  end
end

function Group.CreateController(opts)
  local deps = BuildDeps(opts)

  local controller = {}

  function controller.HandleGroupRosterUpdate()
    HandleGroupRosterUpdate(deps)
  end

  return controller
end
