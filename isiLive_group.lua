local _, addonTable = ...

addonTable = addonTable or {}

local Group = {}
addonTable.Group = Group

function Group.CreateController(opts)
  opts = opts or {}

  local isInGroup = opts.isInGroup or function()
    return false
  end
  local getNumGroupMembers = opts.getNumGroupMembers or function()
    return 0
  end
  local getActiveChallengeMapID = opts.getActiveChallengeMapID or function()
    return nil
  end
  local getWasInGroup = opts.getWasInGroup or function()
    return false
  end
  local setWasInGroup = opts.setWasInGroup or function(_value) end
  local setWasGroupLeader = opts.setWasGroupLeader or function(_value) end
  local getRoster = opts.getRoster or function()
    return {}
  end
  local setRoster = opts.setRoster or function(_value) end
  local captureQueueJoinCandidate = opts.captureQueueJoinCandidate or function() end
  local announceQueuedGroupJoin = opts.announceQueuedGroupJoin or function() end
  local setMainFrameVisible = opts.setMainFrameVisible or function(_visible) end
  local updateLeaderButtons = opts.updateLeaderButtons or function() end
  local clearLatestQueueTarget = opts.clearLatestQueueTarget or function() end
  local clearKnownUsers = opts.clearKnownUsers or function() end
  local resetInspectAll = opts.resetInspectAll or function() end
  local resetInspectQueues = opts.resetInspectQueues or function() end
  local updateUI = opts.updateUI or function() end
  local updateMPlusTeleportButton = opts.updateMPlusTeleportButton or function() end
  local getUnitNameAndRealm = opts.getUnitNameAndRealm or function(_unit)
    return nil, nil
  end
  local getUnitClass = opts.getUnitClass or function(_unit)
    return nil, nil
  end
  local getUnitServerLanguage = opts.getUnitServerLanguage or function(_unit, _realm)
    return "??"
  end
  local getOwnedKeystoneSnapshot = opts.getOwnedKeystoneSnapshot or function()
    return nil, nil
  end
  local markIsiLiveUser = opts.markIsiLiveUser or function(_name, _realm) end
  local setPlayerKeyInfo = opts.setPlayerKeyInfo or function(_name, _realm, _mapID, _level) end
  local getUnitRole = opts.getUnitRole or function(_unit)
    return nil
  end
  local getPlayerSpecName = opts.getPlayerSpecName or function()
    return nil
  end
  local getUnitRio = opts.getUnitRio or function(_unit)
    return nil
  end
  local unitHasIsiLive = opts.unitHasIsiLive or function(_unit)
    return false
  end
  local applyKnownKeyToRosterEntry = opts.applyKnownKeyToRosterEntry or function(_info)
    return false
  end
  local enqueueInspect = opts.enqueueInspect or function(_unit) end
  local sendOwnKeySnapshot = opts.sendOwnKeySnapshot or function(_force) end
  local sendIsiLiveHello = opts.sendIsiLiveHello or function(_force) end

  local controller = {}

  function controller.HandleGroupRosterUpdate()
    local wasInGroupBefore = getWasInGroup() and true or false
    local inGroupNow = isInGroup() and true or false

    if inGroupNow and not wasInGroupBefore then
      -- Recovery path: if an invite status event was missed, rescan applications on group join.
      captureQueueJoinCandidate()
      announceQueuedGroupJoin()
    end
    setWasInGroup(inGroupNow)

    if getActiveChallengeMapID() then
      -- M+ active: freeze updates but allow visibility.
      updateUI()
      updateLeaderButtons()
      return
    end

    if not inGroupNow then
      setWasGroupLeader(nil)
      local leftGroupNow = wasInGroupBefore and not inGroupNow
      if leftGroupNow then
        clearLatestQueueTarget()
        clearKnownUsers()
      end
      setRoster({})
      resetInspectAll()
      updateUI() -- Clear visual list.
      updateMPlusTeleportButton()
      setMainFrameVisible(false) -- Hide frame when not in a group.
      updateLeaderButtons()
      return
    end

    local numMembers = getNumGroupMembers()
    if numMembers > 5 then
      -- Raid detected (or > 5 members), hide addon.
      setMainFrameVisible(false)
      updateLeaderButtons()
      return
    end

    setMainFrameVisible(true) -- Show frame when in a group.
    setRoster({})
    resetInspectQueues()

    local roster = getRoster()

    -- Add player.
    local name, realm = getUnitNameAndRealm("player")
    local _, class = getUnitClass("player")
    local language = getUnitServerLanguage("player", realm)
    local ownKeyMapID, ownKeyLevel = getOwnedKeystoneSnapshot()
    markIsiLiveUser(name, realm)
    setPlayerKeyInfo(name, realm, ownKeyMapID, ownKeyLevel)
    roster.player = {
      name = name,
      realm = realm,
      language = language,
      class = class,
      role = getUnitRole("player"),
      spec = getPlayerSpecName(),
      ilvl = nil,
      rio = getUnitRio("player"),
      hasIsiLive = true,
      keyMapID = ownKeyMapID,
      keyLevel = ownKeyLevel,
    }
    enqueueInspect("player")

    -- Add party members.
    local members = getNumGroupMembers()
    for i = 1, members - 1 do
      local unit = "party" .. i
      local memberName, memberRealm = getUnitNameAndRealm(unit)
      if memberName then
        local _, memberClass = getUnitClass(unit)
        local memberLanguage = getUnitServerLanguage(unit, memberRealm)
        roster[unit] = {
          name = memberName,
          realm = memberRealm,
          language = memberLanguage,
          class = memberClass,
          role = getUnitRole(unit),
          spec = nil,
          ilvl = nil,
          rio = nil,
          hasIsiLive = unitHasIsiLive(unit),
          keyMapID = nil,
          keyLevel = nil,
        }
        applyKnownKeyToRosterEntry(roster[unit])
        enqueueInspect(unit)
      end
    end
    sendOwnKeySnapshot(false)
    updateUI()
    updateLeaderButtons()
    sendIsiLiveHello(false)
  end

  return controller
end
