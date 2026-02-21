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

local function HandleNoGroup(deps, wasInGroupBefore)
  deps.setWasGroupLeader(nil)
  deps.setWasRaidGroup(false)
  deps.clearRioBaselineSnapshot()
  local leftGroupNow = wasInGroupBefore and not deps.isInGroup()
  if leftGroupNow then
    deps.clearLatestQueueTarget()
    deps.clearKnownUsers()
  end
  deps.setRoster({})
  deps.resetInspectAll()
  deps.updateUI()
  deps.updateMPlusTeleportButton()
  deps.setMainFrameVisible(false)
  deps.updateLeaderButtons()
end

local function AddPlayerToRoster(deps, roster)
  local name, realm = deps.getUnitNameAndRealm("player")
  local _, class = deps.getUnitClass("player")
  local language = deps.getUnitServerLanguage("player", realm)
  local ownKeyMapID, ownKeyLevel = deps.getOwnedKeystoneSnapshot()
  deps.markIsiLiveUser(name, realm)
  deps.setPlayerKeyInfo(name, realm, ownKeyMapID, ownKeyLevel)
  roster.player = {
    name = name,
    realm = realm,
    language = language,
    class = class,
    role = deps.getUnitRole("player"),
    spec = deps.getPlayerSpecName(),
    ilvl = nil,
    rio = deps.getUnitRio("player"),
    hasIsiLive = true,
    keyMapID = ownKeyMapID,
    keyLevel = ownKeyLevel,
  }
  deps.enqueueInspect("player")
end

local function AddPartyMembersToRoster(deps, roster)
  local members = deps.getNumGroupMembers()
  for i = 1, members - 1 do
    local unit = "party" .. i
    local memberName, memberRealm = deps.getUnitNameAndRealm(unit)
    if memberName then
      local _, memberClass = deps.getUnitClass(unit)
      local memberLanguage = deps.getUnitServerLanguage(unit, memberRealm)
      roster[unit] = {
        name = memberName,
        realm = memberRealm,
        language = memberLanguage,
        class = memberClass,
        role = deps.getUnitRole(unit),
        spec = nil,
        ilvl = nil,
        rio = nil,
        hasIsiLive = deps.unitHasIsiLive(unit),
        keyMapID = nil,
        keyLevel = nil,
      }
      deps.applyKnownKeyToRosterEntry(roster[unit])
      deps.enqueueInspect(unit)
    end
  end
end

local function HandleGroupRosterUpdate(deps)
  local wasInGroupBefore = deps.getWasInGroup() and true or false
  local inGroupNow = deps.isInGroup() and true or false

  if inGroupNow and not wasInGroupBefore then
    deps.captureQueueJoinCandidate()
    deps.announceQueuedGroupJoin()
  end
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
    end
    deps.setWasRaidGroup(true)
    deps.setMainFrameVisible(false)
    deps.updateLeaderButtons()
    return
  end

  deps.setWasRaidGroup(false)
  deps.setMainFrameVisible(true)
  deps.setRoster({})
  deps.resetInspectQueues()

  local roster = deps.getRoster()
  AddPlayerToRoster(deps, roster)
  AddPartyMembersToRoster(deps, roster)

  deps.sendOwnKeySnapshot(false)
  deps.updateUI()
  deps.updateLeaderButtons()
  deps.sendIsiLiveHello(false)
end

function Group.CreateController(opts)
  local deps = BuildDeps(opts)

  local controller = {}

  function controller.HandleGroupRosterUpdate()
    HandleGroupRosterUpdate(deps)
  end

  return controller
end
