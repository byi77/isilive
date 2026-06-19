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
    isMainFrameVisible = opts.isMainFrameVisible or falsefn,
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
    getOwnAverageItemLevel = opts.getOwnAverageItemLevel or function()
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
    getReloadRosterMirror = opts.getReloadRosterMirror or function()
      return nil
    end,
    setReloadRosterMirror = opts.setReloadRosterMirror or emptyfn,
    clearReloadRosterMirror = opts.clearReloadRosterMirror or emptyfn,
    getReloadRosterTargetSnapshot = opts.getReloadRosterTargetSnapshot or function()
      return nil
    end,
    restoreReloadRosterTargetSnapshot = opts.restoreReloadRosterTargetSnapshot or emptyfn,
    onGroupJoined = opts.onGroupJoined or function() end,
    onMemberJoinedGroup = opts.onMemberJoinedGroup or emptyfn,
    timerAfter = opts.timerAfter or function(_, cb)
      cb()
    end,
    shouldAutoCloseOnSoloChange = opts.shouldAutoCloseOnSoloChange or falsefn,
    getRaidTransitionBehavior = opts.getRaidTransitionBehavior or function()
      return "hide"
    end,
    autoCloseMainFrame = opts.autoCloseMainFrame or emptyfn,
    logRuntimeTrace = type(opts.logRuntimeTrace) == "function" and opts.logRuntimeTrace or emptyfn,
    logRuntimeTracef = type(opts.logRuntimeTracef) == "function" and opts.logRuntimeTracef or emptyfn,
    restoreMainFrameAfterRaid = false,
  }
end

local GHOST_KEY_PREFIX = "ghost:"

local function MemberKey(name, realm)
  return (name or "Unknown") .. "-" .. (realm or "")
end

local function IsConcreteMemberName(name)
  return type(name) == "string" and name ~= "" and name ~= "Unknown"
end

local function ReadCurrentGroupMembers(deps)
  if deps.isInGroup() ~= true then
    return nil
  end
  local members = deps.getNumGroupMembers()
  if type(members) ~= "number" or members <= 0 or members > 5 then
    return nil
  end

  local current = {}
  local playerName, playerRealm = deps.getUnitNameAndRealm("player")
  if not IsConcreteMemberName(playerName) then
    return nil
  end
  current[#current + 1] = {
    unit = "player",
    key = MemberKey(playerName, playerRealm),
    name = playerName,
    realm = playerRealm,
  }

  for i = 1, members - 1 do
    local unit = "party" .. i
    local name, realm = deps.getUnitNameAndRealm(unit)
    if not IsConcreteMemberName(name) then
      return nil
    end
    current[#current + 1] = {
      unit = unit,
      key = MemberKey(name, realm),
      name = name,
      realm = realm,
    }
  end

  return current
end

local function BuildGroupSignatureFromMembers(members)
  if type(members) ~= "table" or #members == 0 then
    return nil
  end
  local keys = {}
  for _, member in ipairs(members) do
    if type(member) ~= "table" or type(member.key) ~= "string" or member.key == "" then
      return nil
    end
    keys[#keys + 1] = member.key
  end
  table.sort(keys)
  return table.concat(keys, "|")
end

local function CopyMirrorValue(value)
  local valueType = type(value)
  if valueType == "string" or valueType == "number" or valueType == "boolean" then
    return value
  end
  return nil
end

local MIRROR_ENTRY_FIELDS = {
  "name",
  "realm",
  "language",
  "class",
  "role",
  "isLeader",
  "spec",
  "ilvl",
  "rio",
  "hasIsiLive",
  "keyMapID",
  "keyLevel",
  "syncDps",
  "syncLocMapID",
  "syncTargetMapID",
  "syncTargetLevel",
}

local function CloneRosterEntryForMirror(info)
  if type(info) ~= "table" or info.isGhost == true or not IsConcreteMemberName(info.name) then
    return nil
  end
  local entry = {}
  for _, field in ipairs(MIRROR_ENTRY_FIELDS) do
    local copied = CopyMirrorValue(info[field])
    if copied ~= nil then
      entry[field] = copied
    end
  end
  if not IsConcreteMemberName(entry.name) then
    return nil
  end
  entry.realm = type(entry.realm) == "string" and entry.realm or nil
  entry.isGhost = false
  entry._reloadMirrorRestored = true
  return entry
end

local function CloneReloadRosterTargetSnapshot(source)
  if type(source) ~= "table" then
    return nil
  end
  local mapID = tonumber(source.mapID)
  if not mapID or mapID <= 0 then
    return nil
  end
  local name = CopyMirrorValue(source.name)
  if type(name) ~= "string" or name == "" then
    return nil
  end

  local snapshot = {
    mapID = math.floor(mapID),
    name = name,
  }

  local level = tonumber(source.level)
  if level and level > 0 then
    snapshot.level = math.floor(level)
  end

  local levelText = CopyMirrorValue(source.levelText)
  if type(levelText) == "string" and levelText ~= "" then
    snapshot.levelText = levelText
  end

  return snapshot
end

local function SaveReloadRosterMirror(deps, roster)
  local members = ReadCurrentGroupMembers(deps)
  local signature = BuildGroupSignatureFromMembers(members)
  if not signature then
    deps.clearReloadRosterMirror()
    return false
  end

  local byKey = {}
  for _, info in pairs(roster or {}) do
    local entry = CloneRosterEntryForMirror(info)
    if entry then
      byKey[MemberKey(entry.name, entry.realm)] = entry
    end
  end

  for _, member in ipairs(members) do
    if type(byKey[member.key]) ~= "table" then
      deps.clearReloadRosterMirror()
      return false
    end
  end

  local snapshot = {
    signature = signature,
    members = byKey,
  }
  local targetSnapshot = CloneReloadRosterTargetSnapshot(deps.getReloadRosterTargetSnapshot())
  if targetSnapshot then
    snapshot.targetKey = targetSnapshot
  end

  deps.setReloadRosterMirror(snapshot)
  return true
end

local function TryRestoreReloadRosterMirror(deps)
  local mirror = deps.getReloadRosterMirror()
  if type(mirror) ~= "table" or type(mirror.members) ~= "table" or type(mirror.signature) ~= "string" then
    deps.clearReloadRosterMirror()
    return false
  end

  local members = ReadCurrentGroupMembers(deps)
  local signature = BuildGroupSignatureFromMembers(members)
  if not signature or signature ~= mirror.signature then
    deps.clearReloadRosterMirror()
    return false
  end

  local restored = {}
  for _, member in ipairs(members) do
    local source = mirror.members[member.key]
    if type(source) ~= "table" then
      deps.clearReloadRosterMirror()
      return false
    end
    local entry = CloneRosterEntryForMirror(source)
    if not entry then
      deps.clearReloadRosterMirror()
      return false
    end
    entry.name = member.name
    entry.realm = member.realm
    entry.isGhost = false
    entry._reloadMirrorRestored = true
    restored[member.unit] = entry
  end

  deps.setRoster(restored)
  local targetSnapshot = CloneReloadRosterTargetSnapshot(mirror.targetKey)
  if targetSnapshot then
    deps.restoreReloadRosterTargetSnapshot(targetSnapshot)
  end
  deps.logRuntimeTracef("[ROSTER] reload_mirror_restored members=%s", tostring(#members))
  return true
end

local function GhostKey(name, realm)
  return GHOST_KEY_PREFIX .. MemberKey(name, realm)
end

local SetIfNotNil
local UpdatePlayerEntry

local function RestoreMainFrameAfterRaidIfNeeded(deps, reason)
  if deps.restoreMainFrameAfterRaid ~= true then
    deps.restoreMainFrameAfterRaid = false
    return
  end
  deps.restoreMainFrameAfterRaid = false
  deps.setMainFrameVisible(true, {
    reason = reason or "raid-return",
    skipShowCallbacks = true,
  })
end

local function HandleNoGroup(deps, wasInGroupBefore, wasRaidGroupBefore)
  local leftGroupNow = wasInGroupBefore and not deps.isInGroup()
  deps.logRuntimeTracef(
    "[GROUP] handle_no_group wasInGroupBefore=%s leftGroupNow=%s",
    tostring(wasInGroupBefore),
    tostring(leftGroupNow)
  )
  deps.setWasGroupLeader(nil)
  deps.setWasRaidGroup(false)
  if wasRaidGroupBefore then
    RestoreMainFrameAfterRaidIfNeeded(deps, "raid-return")
  else
    deps.restoreMainFrameAfterRaid = false
  end
  deps.clearRioBaselineSnapshot()
  if leftGroupNow then
    deps.clearReloadRosterMirror()
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
  if leftGroupNow and deps.shouldAutoCloseOnSoloChange() and type(deps.autoCloseMainFrame) == "function" then
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
  end

  -- Read own ilvl directly via C_Item.GetAverageItemLevel. Runs even when
  -- _refreshQueued is true: the inspect path cannot reliably fill this for
  -- "player" (CanInspect("player") often false; in M+ under 12.0 NotifyInspect
  -- is restricted; even when INSPECT_READY fires GetInspectItemLevel("player")
  -- frequently returns 0). The local API is always authoritative for self.
  local ownIlvl = deps.getOwnAverageItemLevel()
  if ownIlvl then
    playerEntry.ilvl = ownIlvl
    playerEntry._localIlvlFresh = true
  elseif
    not playerEntry._refreshQueued
    and not preserveIlvl
    and not playerEntry._localIlvlFresh
    and not playerEntry._reloadMirrorRestored
  then
    playerEntry.ilvl = nil
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
  local fullGroupJoinSoundPlayed = false
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
    deps.logRuntimeTracef(
      "[ROSTER] member_left unit=%s name=%s",
      tostring(conversion.partyUnit),
      tostring(conversion.info.name)
    )
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
      local syncDps = existing and existing.syncDps
      local syncLocMapID = existing and existing.syncLocMapID
      local syncTargetMapID = existing and existing.syncTargetMapID
      local syncTargetLevel = existing and existing.syncTargetLevel

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
        hasIsiLive = deps.unitHasIsiLive(unit) or (existing and existing.hasIsiLive == true),
        keyMapID = keyMapID,
        keyLevel = keyLevel,
        syncDps = syncDps,
        syncLocMapID = syncLocMapID,
        syncTargetMapID = syncTargetMapID,
        syncTargetLevel = syncTargetLevel,
        isGhost = false,
        _refreshQueued = refreshQueued,
        _localSpecFresh = localSpecFresh,
        _localIlvlFresh = localIlvlFresh,
        _localRioFresh = localRioFresh,
        _localDpsFresh = localDpsFresh,
        _reloadMirrorRestored = existing and existing._reloadMirrorRestored or nil,
      }

      -- Fire the join sound once when a genuine join makes the 5-player group complete.
      local ghostKey = GhostKey(memberName, memberRealm)
      local shouldPlayJoinSound = false
      if callbacks and type(callbacks.onMemberJoinedGroup) == "function" then
        shouldPlayJoinSound = members == 5
          and not fullGroupJoinSoundPlayed
          and (not existing or existing.isGhost == true)
      end
      if shouldPlayJoinSound then
        fullGroupJoinSoundPlayed = true
        deps.logRuntimeTracef(
          "[ROSTER] member_joined unit=%s name=%s class=%s",
          tostring(unit),
          tostring(memberName),
          tostring(memberClass)
        )
        callbacks.onMemberJoinedGroup()
      end

      -- If we pulled data from a ghost slot (resurrected player), clear the ghost entry
      if roster[ghostKey] then
        roster[ghostKey] = nil
      end

      if not roster[unit]._reloadMirrorRestored then
        deps.applyKnownKeyToRosterEntry(roster[unit])
      end
      deps.enqueueInspect(unit)
    end
  end

  PruneGhosts(roster)
end

local function HandleGroupRosterUpdate(deps)
  local wasInGroupBefore = deps.getWasInGroup() == true
  local inGroupNow = deps.isInGroup() == true
  local joinedNow = inGroupNow and not wasInGroupBefore
  local wasRaidGroupBefore = deps.getWasRaidGroup() and true or false
  deps.logRuntimeTracef(
    "[GROUP] roster_update wasInGroup=%s inGroupNow=%s joinedNow=%s",
    tostring(wasInGroupBefore),
    tostring(inGroupNow),
    tostring(joinedNow)
  )
  deps.setWasInGroup(inGroupNow)

  if deps.getActiveChallengeMapID() then
    -- Inside an active key we do not rebuild the roster on every GROUP_ROSTER_UPDATE
    -- so that per-member state (spec, ilvl, rio, keys) is preserved. But after a /reload
    -- the Lua state is fresh and the roster is empty; joinedNow signals exactly that
    -- case during an active key (no one joins a group mid-dungeon).
    if joinedNow then
      local roster = deps.getRoster()
      if TryRestoreReloadRosterMirror(deps) then
        roster = deps.getRoster()
      end
      AddPlayerToRoster(deps, roster)
      UpdatePartyMembersInRoster(deps, roster, nil)
      SaveReloadRosterMirror(deps, roster)
    end
    deps.updateUI()
    deps.updateLeaderButtons()
    return
  end

  if not inGroupNow then
    HandleNoGroup(deps, wasInGroupBefore, wasRaidGroupBefore)
    return
  end

  local numMembers = deps.getNumGroupMembers()
  if numMembers > 5 then
    if not wasRaidGroupBefore then
      deps.restoreMainFrameAfterRaid = deps.isMainFrameVisible() == true
      deps.clearPendingQueueJoinInfo()
      deps.clearLatestQueueTarget()
      deps.clearRioBaselineSnapshot()
      deps.resetInspectAll()
      deps.resetInspectQueues()
      deps.setRoster({})
      deps.clearReloadRosterMirror()
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
    RestoreMainFrameAfterRaidIfNeeded(deps, "raid-return")
  else
    deps.restoreMainFrameAfterRaid = false
  end
  local restoredFromReloadMirror = false
  if joinedNow then
    deps.setRoster({})
    restoredFromReloadMirror = TryRestoreReloadRosterMirror(deps)
    if not restoredFromReloadMirror then
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
  end

  local roster = deps.getRoster()
  deps.resetInspectQueues()

  AddPlayerToRoster(deps, roster)
  UpdatePartyMembersInRoster(deps, roster, joinedNow and not restoredFromReloadMirror and nil or deps)

  deps.sendOwnKeySnapshot(joinedNow and not restoredFromReloadMirror, "group")
  SaveReloadRosterMirror(deps, roster)
  deps.updateUI()
  deps.updateMPlusTeleportButton()
  deps.updateLeaderButtons()
  deps.sendIsiLiveHello(joinedNow and not restoredFromReloadMirror, "group")
  if joinedNow then
    -- Delay to ensure IsInGroup() has settled before sending addon messages.
    -- Reload-mirror restores are not fresh joins, but still need one live
    -- refresh request so restored peer data is verified after /reload.
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

  function controller.SaveReloadRosterMirror()
    return SaveReloadRosterMirror(deps, deps.getRoster())
  end

  return controller
end
