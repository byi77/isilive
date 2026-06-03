local _, addonTable = ...

addonTable = addonTable or {}

local Status = {}
addonTable.Status = Status
local StringUtils = addonTable.StringUtils

local MYTHIC_DIFFICULTY_IDS = {
  [8] = true,
  [23] = true,
  [24] = true,
  [167] = true,
}

local HEROIC_DIFFICULTY_IDS = {
  [2] = true,
  [174] = true,
}

-- Raid difficulty IDs -> localized label key. Covers the four current Blizzard
-- raid difficulties (LFR / Normal / Heroic / Mythic) which all carry their
-- own difficulty ID in `select(3, GetInstanceInfo())`. Legacy IDs (10-man /
-- 25-man split, original LFR=7) are intentionally not mapped: those raids
-- are no longer reachable through the current group finder, and adding them
-- would dilute the label table without a real user-visible benefit.
local RAID_DIFFICULTY_LABEL_KEYS = {
  [14] = "DUNGEON_DIFF_RAID_NORMAL",
  [15] = "DUNGEON_DIFF_RAID_HEROIC",
  [16] = "DUNGEON_DIFF_RAID_MYTHIC",
  [17] = "DUNGEON_DIFF_RAID_LFR",
}

local function BuildDungeonContextSignature(instanceType, difficultyID, instanceName, isMythic)
  if instanceType ~= "party" and instanceType ~= "raid" then
    return nil
  end

  return table.concat({
    tostring(instanceType or ""),
    tostring(instanceName or ""),
    tostring(difficultyID or ""),
    tostring(isMythic and 1 or 0),
  }, "|")
end

local PORTAL_NAVIGATOR_ZONE_NAMES = {
  jahrhunderschwelle = true,
  ["die jahrhunderschwelle"] = true,
  ["millennia's threshold"] = true,
  timeways = true,
  ["the timeways"] = true,
}

local PORTAL_NAVIGATOR_MAP_IDS = {
  [2266] = true,
}

local PORTAL_NAVIGATOR_ENTRY_MAP_IDS = {
  left = 161,
  half_left = 556,
  half_right = 402,
  right = 239,
}

local function NormalizeZoneText(value)
  if type(value) ~= "string" then
    return nil
  end

  local normalized = StringUtils.Trim(value)
  if normalized == "" then
    return nil
  end
  return string.lower(normalized)
end

local function SafeCallTextProvider(provider)
  if type(provider) ~= "function" then
    return nil
  end

  local ok, text = pcall(provider)
  if not ok then
    return nil
  end
  return text
end

local function SafeCallNumberProvider(provider)
  if type(provider) ~= "function" then
    return nil
  end

  local ok, value = pcall(provider)
  if not ok then
    return nil
  end

  local numericValue = tonumber(value)
  if not numericValue or numericValue <= 0 then
    return nil
  end
  return math.floor(numericValue)
end

local function ResolvePortalNavigatorZoneSignature(deps)
  local playerMapID = SafeCallNumberProvider(deps.getPlayerMapID)
  if playerMapID and PORTAL_NAVIGATOR_MAP_IDS[playerMapID] then
    return "map:" .. tostring(playerMapID), true
  end

  local mapInfoName = nil
  if playerMapID then
    mapInfoName = SafeCallTextProvider(function()
      return deps.getMapInfoName(playerMapID)
    end)
  end

  local zoneText = SafeCallTextProvider(deps.getZoneText)
  local subZoneText = SafeCallTextProvider(deps.getSubZoneText)
  local realZoneText = SafeCallTextProvider(deps.getRealZoneText)
  local sawZoneText = false

  local candidates = {}
  if type(mapInfoName) == "string" then
    local normalizedMapInfoName = NormalizeZoneText(mapInfoName)
    if normalizedMapInfoName then
      sawZoneText = true
      table.insert(candidates, normalizedMapInfoName)
    end
  end
  if type(zoneText) == "string" then
    local normalizedZoneText = NormalizeZoneText(zoneText)
    if normalizedZoneText then
      sawZoneText = true
      table.insert(candidates, normalizedZoneText)
    end
  end
  if type(subZoneText) == "string" then
    local normalizedSubZoneText = NormalizeZoneText(subZoneText)
    if normalizedSubZoneText then
      sawZoneText = true
      table.insert(candidates, normalizedSubZoneText)
    end
  end
  if type(realZoneText) == "string" and realZoneText ~= subZoneText then
    local normalizedRealZoneText = NormalizeZoneText(realZoneText)
    if normalizedRealZoneText then
      sawZoneText = true
      table.insert(candidates, normalizedRealZoneText)
    end
  end

  for _, candidateZoneText in ipairs(candidates) do
    if PORTAL_NAVIGATOR_ZONE_NAMES[candidateZoneText] then
      return candidateZoneText, true
    end
  end

  return nil, sawZoneText
end

local function ApplyPortalNavigatorTeleportInfo(deps, entry, mapID)
  entry.mapID = mapID
  if type(deps.getTeleportInfoByMapID) ~= "function" then
    return
  end

  local ok, info = pcall(deps.getTeleportInfoByMapID, mapID)
  if not ok or type(info) ~= "table" then
    return
  end

  local spellID = tonumber(info.spellID)
  if spellID and spellID > 0 then
    entry.spellID = math.floor(spellID)
  end
  if type(info.icon) == "string" or type(info.icon) == "number" then
    entry.icon = info.icon
  end
end

local function BuildPortalNavigatorLayout(deps)
  local L = deps.getL()
  local title = L.PORTAL_NAVIGATOR_TITLE
  if type(title) ~= "string" or title == "" then
    return nil
  end
  local eyebrow = L.PORTAL_NAVIGATOR_EYEBROW
  if type(eyebrow) ~= "string" or eyebrow == "" then
    return nil
  end
  local entries = {
    {
      slot = "left",
      direction = L.PORTAL_NAVIGATOR_LEFT,
      destination = L.PORTAL_NAVIGATOR_SKYREACH,
    },
    {
      slot = "half_left",
      direction = L.PORTAL_NAVIGATOR_HALF_LEFT,
      destination = L.PORTAL_NAVIGATOR_PIT_OF_SARON,
    },
    {
      slot = "center",
      direction = L.PORTAL_NAVIGATOR_CENTER,
      destination = L.PORTAL_NAVIGATOR_HEAVEN,
      detail = L.PORTAL_NAVIGATOR_UNOCCUPIED,
      isEmpty = true,
    },
    {
      slot = "half_right",
      direction = L.PORTAL_NAVIGATOR_HALF_RIGHT,
      destination = L.PORTAL_NAVIGATOR_ALGETHAR,
    },
    {
      slot = "right",
      direction = L.PORTAL_NAVIGATOR_RIGHT,
      destination = L.PORTAL_NAVIGATOR_TRIUMVIRATE,
    },
  }

  for _, entry in ipairs(entries) do
    local mapID = PORTAL_NAVIGATOR_ENTRY_MAP_IDS[entry.slot]
    if mapID then
      ApplyPortalNavigatorTeleportInfo(deps, entry, mapID)
    end
    if type(entry.direction) ~= "string" or entry.direction == "" then
      return nil
    end
    if type(entry.destination) ~= "string" or entry.destination == "" then
      return nil
    end
    if entry.detail ~= nil and type(entry.detail) ~= "string" then
      return nil
    end
  end

  return {
    eyebrow = eyebrow,
    title = title,
    entries = entries,
  }
end

local function GetAddonStateText(getL, flags)
  flags = flags or {}
  local L = getL()
  if flags.isStopped then
    return L.STATUS_STATE_STOPPED
  end
  if flags.isPaused then
    return L.STATUS_STATE_PAUSED
  end
  if flags.isTestMode then
    return L.STATUS_STATE_TEST
  end
  return L.STATUS_STATE_RUNNING
end

local function BuildTargetDungeonText(deps)
  local L = deps.getL()
  local template = L.STATUS_TARGET_DUNGEON_TEXT or "Target Dungeon: %s"
  local emptyText = L.STATUS_TARGET_DUNGEON_NONE or string.format(template, "-")

  local info = deps.getTargetDungeonInfo and deps.getTargetDungeonInfo() or nil
  if type(info) ~= "table" then
    if type(deps.hasActiveDungeons) == "function" and deps.hasActiveDungeons() == false then
      local seasonLabel = type(deps.getActiveSeasonLabel) == "function" and deps.getActiveSeasonLabel() or nil
      if type(seasonLabel) == "string" and seasonLabel ~= "" then
        local preSeasonTemplate = L.STATUS_TARGET_DUNGEON_PRESEASON or template
        return string.format(preSeasonTemplate, seasonLabel)
      end
    end
    return emptyText
  end

  local name = tostring(info.name or "")
  name = StringUtils.Trim(name)
  if name == "" then
    return emptyText
  end

  local level = tonumber(info.level)
  local targetText = name
  if level and level > 0 then
    targetText = string.format("%s +%d", name, level)
  elseif type(info.levelText) == "string" and info.levelText ~= "" then
    targetText = string.format("%s %s", name, info.levelText)
  end

  return string.format(template, targetText)
end

local function ResolveConcreteTargetDungeonInfo(deps)
  local info = deps.getTargetDungeonInfo and deps.getTargetDungeonInfo() or nil
  if type(info) ~= "table" then
    return nil
  end

  local name = tostring(info.name or "")
  name = StringUtils.Trim(name)
  if name == "" then
    return nil
  end

  local level = tonumber(info.level)
  if not level or level <= 0 then
    level = nil
  else
    level = math.floor(level)
  end

  return {
    name = name,
    level = level,
    levelText = (not level and type(info.levelText) == "string" and info.levelText ~= "") and info.levelText or nil,
  }
end

local function BuildTargetDungeonAnnouncementText(deps, info)
  if type(info) ~= "table" or type(info.name) ~= "string" then
    return nil
  end

  local level = tonumber(info.level)
  if level and level <= 0 then
    level = nil
  end

  local L = deps.getL()
  local template = L.STATUS_TARGET_DUNGEON_TEXT or "Target Dungeon: %s"
  -- Highlight dungeon name + (optional) level in yellow so it stands out in
  -- chat. The blue "isiLive" brand prefix is supplied by PrintHighlighted.
  -- The level is omitted when no key info is known yet (e.g. the invite was
  -- just accepted but no peer has synced their key); a re-announce with
  -- "+level" fires later once the level resolves via the sync flow.
  local highlighted
  if level then
    highlighted = string.format("|cffffd200%s +%d|r", info.name, math.floor(level))
  elseif type(info.levelText) == "string" and info.levelText ~= "" then
    highlighted = string.format("|cffffd200%s %s|r", info.name, info.levelText)
  else
    highlighted = string.format("|cffffd200%s|r", info.name)
  end
  return string.format(template, highlighted)
end

-- Deferred-announce window: how long the chat announce waits for the LFG
-- title hint / roster owner / peer sync to resolve a key level before
-- falling back to a level-less line. 3 s covers the typical 100–500 ms LFG
-- payload, plus enough headroom for the peer-sync roundtrip on slow
-- connections. Out of an abundance of caution capped well below 5 s so the
-- user never perceives the announce as "missing".
local TARGET_DUNGEON_LEVEL_WAIT_SECONDS = 3.0

local function ResetTargetDungeonChatState(state)
  state.lastObservedTargetDungeonName = nil
  state.lastTargetDungeonChatSignature = nil
  state.pendingTargetDungeonAnnouncementName = nil
  state.pendingTargetDungeonAnnouncementAt = nil
  state.levelAnnouncedTargetDungeonName = nil
end

local function EmitTargetDungeonAnnouncement(state, deps, info)
  local announcementText = BuildTargetDungeonAnnouncementText(deps, info)
  if type(announcementText) ~= "string" or announcementText == "" then
    return false
  end
  local signature = table.concat({ info.name, tostring(info.level) }, "|")
  if state.lastTargetDungeonChatSignature == signature then
    return false
  end
  state.lastObservedTargetDungeonName = info.name
  state.lastTargetDungeonChatSignature = signature
  -- Single lock-in for BOTH level-with and level-less branches: once we
  -- announce a name, no further announces for the same name until
  -- ResetTargetDungeonChatState (group-leave / no-target) clears it.
  state.levelAnnouncedTargetDungeonName = info.name
  state.pendingTargetDungeonAnnouncementName = nil
  state.pendingTargetDungeonAnnouncementAt = nil
  local sink = deps.printHighlighted or deps.printFn
  sink(announcementText)
  return true
end

-- Defer-then-announce flow:
--   1. First sighting WITH level    -> announce immediately with "+N".
--   2. First sighting WITHOUT level -> record the time, schedule a forced
--      re-evaluation TARGET_DUNGEON_LEVEL_WAIT_SECONDS in the future, stay
--      silent. If a later status update arrives WITH the level before that
--      timer fires, path 1 takes over and the deferred fallback is skipped
--      because the lock-in flag is set.
--   3. Re-entry without level and the deferred wait has elapsed -> announce
--      level-less as the fallback.
-- The Center Notice for the invite is independent: it always renders the
-- level it received via the LFG payload, so the user still sees "+N" at
-- the moment of acceptance even when the chat waits.
local function MaybeAnnounceTargetDungeonChat(state, deps)
  -- info-first ordering: a real group-leave collapses GetStatusTarget-
  -- DungeonInfo to nil (no roster / queue / synced target left), which
  -- ResetTargetDungeonChatState handles below. Resolving info before
  -- the IsInGroup guard ensures that real leave-paths still reset the
  -- lock-in even when the IsInGroup guard would otherwise short-circuit
  -- the function.
  local info = ResolveConcreteTargetDungeonInfo(deps)
  if type(info) ~= "table" then
    ResetTargetDungeonChatState(state)
    return
  end

  if type(deps.isInGroup) == "function" and deps.isInGroup() ~= true then
    -- Lock-in protection: the LFG-accept direct push
    -- (AnnounceTargetDungeonFromPayload) fires *before*
    -- GROUP_ROSTER_UPDATE flips IsInGroup() to true. The queue
    -- handler runs ctx.updateStatusLine() synchronously right after
    -- the accept event, so an unconditional reset here would erase
    -- the lock-in that the direct push just set — a subsequent
    -- GROUP_ROSTER_UPDATE pass would then re-fire the announce, often
    -- without the "+N" because the LFG-title hint may have aged out.
    -- When the lock-in is set, only the deferred-announce bookkeeping
    -- gets cleared; the lock-in itself survives the transient flicker.
    -- True group-leave is handled above (info=nil) — the lock-in
    -- clears via ResetTargetDungeonChatState there.
    if state.levelAnnouncedTargetDungeonName == nil then
      ResetTargetDungeonChatState(state)
    else
      state.pendingTargetDungeonAnnouncementName = nil
      state.pendingTargetDungeonAnnouncementAt = nil
    end
    return
  end

  if state.levelAnnouncedTargetDungeonName == info.name then
    return
  end

  -- Local-trigger gate: a non-LFG manual /invite gives the player no
  -- own LFG-listing and no own LFG-accept; ResolveLocalStatusTargetMapID
  -- then returns nil and GetStatusTargetDungeonInfo falls back to the
  -- synced-target consensus across the roster. That consensus is fine
  -- for the status frame (informational), but it is NOT a semantic
  -- "this is the dungeon the group has decided to play" signal — it
  -- merely reflects whichever member happens to currently sync a
  -- mapID. Without this gate, a manual /invite drops chat lines like
  -- `Ziel-Dungeon: Maisarakavernen` purely because some other member
  -- carries that key, and the line flips whenever that member leaves.
  -- The chat announce therefore fires only when the local player has
  -- a concrete trigger of their own (own queue, key actively running,
  -- accepted LFG invite). The direct-push lock-in is set via
  -- AnnounceTargetDungeonFromPayload separately, so the LFG-accept
  -- path never depends on this branch.
  if type(deps.hasLocalTargetSource) == "function" and deps.hasLocalTargetSource() ~= true then
    state.pendingTargetDungeonAnnouncementName = nil
    state.pendingTargetDungeonAnnouncementAt = nil
    return
  end

  if info.level then
    EmitTargetDungeonAnnouncement(state, deps, info)
    return
  end

  local now = type(deps.getTime) == "function" and tonumber(deps.getTime()) or nil
  local pendingName = state.pendingTargetDungeonAnnouncementName
  local pendingAt = tonumber(state.pendingTargetDungeonAnnouncementAt)

  if pendingName ~= info.name then
    state.pendingTargetDungeonAnnouncementName = info.name
    state.pendingTargetDungeonAnnouncementAt = now
    if type(deps.timerAfter) == "function" then
      deps.timerAfter(TARGET_DUNGEON_LEVEL_WAIT_SECONDS, function()
        MaybeAnnounceTargetDungeonChat(state, deps)
      end)
    end
    return
  end

  if not now or not pendingAt or (now - pendingAt) < TARGET_DUNGEON_LEVEL_WAIT_SECONDS then
    return
  end

  EmitTargetDungeonAnnouncement(state, deps, info)
end

local function GetDungeonDifficultyLabel(getL)
  local L = getL()
  local okInstance, instanceName, instanceType, difficultyID = pcall(GetInstanceInfo)
  if not okInstance then
    return L.DUNGEON_DIFF_UNKNOWN, false, false, nil, nil, nil
  end
  -- Raid branch: independent from the party / Mythic+ flow. Reports a raid
  -- label for the four current difficulties; `isMythic` stays false so the
  -- non-mythic-entry notice path (which gates on `not cMythic`) fires for
  -- every raid difficulty including Mythic Raid — the user expectation here
  -- is "show me which raid difficulty I just walked into" rather than the
  -- M+-specific "non-mythic warning". `inDungeon` is true so the same
  -- enter/leave bookkeeping the dungeon path uses applies to raids too.
  if instanceType == "raid" then
    local labelKey = difficultyID and RAID_DIFFICULTY_LABEL_KEYS[difficultyID]
    local text = (labelKey and L[labelKey]) or L.DUNGEON_DIFF_RAID_UNKNOWN or L.DUNGEON_DIFF_UNKNOWN
    return text, false, true, instanceType, difficultyID, instanceName
  end
  if instanceType ~= "party" then
    return L.DUNGEON_DIFF_OUTSIDE, false, false, instanceType, difficultyID, instanceName
  end

  -- secret-value-ok: existence-guarded short-circuit chain on C_ChallengeMode
  local challengeMode = rawget(_G, "C_ChallengeMode")
  if type(challengeMode) == "table" and type(challengeMode.GetActiveChallengeMapID) == "function" then
    local okMap, activeMapID = pcall(challengeMode.GetActiveChallengeMapID)
    if okMap and activeMapID then
      return L.DUNGEON_DIFF_MYTHIC, true, true, instanceType, difficultyID, instanceName
    end
  end

  if difficultyID == 1 then
    return L.DUNGEON_DIFF_NORMAL, false, true, instanceType, difficultyID, instanceName
  end
  if HEROIC_DIFFICULTY_IDS[difficultyID] then
    return L.DUNGEON_DIFF_HEROIC, false, true, instanceType, difficultyID, instanceName
  end
  if MYTHIC_DIFFICULTY_IDS[difficultyID] then
    return L.DUNGEON_DIFF_MYTHIC, true, true, instanceType, difficultyID, instanceName
  end

  return L.DUNGEON_DIFF_UNKNOWN, false, true, instanceType, difficultyID, instanceName
end

local function MaybeShowNonMythicDungeonEntryNotice(state, deps)
  local L = deps.getL()
  local isMythic, inDungeon, instanceType, difficultyID, instanceName = select(2, GetDungeonDifficultyLabel(deps.getL))
  local dungeonContextSignature = BuildDungeonContextSignature(instanceType, difficultyID, instanceName, isMythic)

  if state.wasInDungeon == nil then
    state.wasInDungeon = inDungeon
    state.lastDungeonContextSignature = dungeonContextSignature
    return
  end

  if not inDungeon then
    state.nonMythicNoticeToken = state.nonMythicNoticeToken + 1
    state.lastAnnouncedNonMythicSignature = nil
    -- Only hide the shared center notice when THIS controller actually owns
    -- the currently visible content. Otherwise we silently kill the
    -- Accepted-Invite / Lead-Transfer / Test-Mode notices on every
    -- non-dungeon INSTANCE_CONTEXT_CHANGED.
    if state.nonMythicNoticeShown then
      deps.hideCenterNotice()
      state.nonMythicNoticeShown = false
    end
  end

  local contextChanged = inDungeon and dungeonContextSignature ~= state.lastDungeonContextSignature
  local enteredDungeon = inDungeon and not state.wasInDungeon
  if enteredDungeon or contextChanged then
    state.nonMythicNoticeToken = state.nonMythicNoticeToken + 1
    local token = state.nonMythicNoticeToken

    local function ConfirmAndShowNotice()
      if token ~= state.nonMythicNoticeToken then
        return
      end
      -- Call GetDungeonDifficultyLabel once and unpack all 6 return values.
      local cText, cMythic, cInDungeon, cInstanceType, cDifficultyID, cInstanceName =
        GetDungeonDifficultyLabel(deps.getL)
      if not cInDungeon then
        return
      end
      -- M+ keystone in a party dungeon already has its own UI surfaces
      -- (timer, kill track, roster) — suppress the entry notice for that
      -- one case only. Every other in-dungeon difficulty (party normal /
      -- heroic, every raid difficulty including Mythic Raid) shows the
      -- notice so the player can confirm the instance they just entered.
      if cInstanceType == "party" and cMythic then
        return
      end
      if cText == L.DUNGEON_DIFF_UNKNOWN or cText == L.DUNGEON_DIFF_RAID_UNKNOWN then
        return
      end
      local confirmedSignature = BuildDungeonContextSignature(cInstanceType, cDifficultyID, cInstanceName, cMythic)
      if confirmedSignature == state.lastAnnouncedNonMythicSignature then
        return
      end
      state.lastAnnouncedNonMythicSignature = confirmedSignature
      local template
      local showOpts
      if cInstanceType == "raid" then
        template = L.RAID_ENTERED or "Raid: %s"
        showOpts = {
          eyebrow = L.NON_MYTHIC_NOTICE_RAID_EYEBROW or "Raid",
          title = L.NON_MYTHIC_NOTICE_RAID_TITLE or "isiLive - Raid entered",
          fields = {
            {
              label = L.NON_MYTHIC_NOTICE_LABEL_RAID or "Raid:",
              value = cInstanceName or L.DUNGEON_DIFF_RAID_UNKNOWN or "Raid",
            },
            { label = L.NON_MYTHIC_NOTICE_LABEL_DIFFICULTY or "Difficulty:", value = cText },
            {
              label = L.NON_MYTHIC_NOTICE_LABEL_SOURCE or "Source:",
              value = L.NON_MYTHIC_NOTICE_SOURCE_INSTANCE_ENTERED or "Instance entered",
            },
          },
          frameWidth = 680,
        }
      else
        template = L.NON_MYTHIC_ENTERED or "Non-Mythic: %s"
        showOpts = {
          eyebrow = L.NON_MYTHIC_NOTICE_DUNGEON_EYEBROW or "Dungeon",
          title = L.NON_MYTHIC_NOTICE_DUNGEON_TITLE or "isiLive - Dungeon entered",
          fields = {
            {
              label = L.NON_MYTHIC_NOTICE_LABEL_DUNGEON or "Dungeon:",
              value = cInstanceName or L.INVITE_HINT_UNKNOWN_DUNGEON or "Unknown dungeon",
            },
            { label = L.NON_MYTHIC_NOTICE_LABEL_DIFFICULTY or "Difficulty:", value = cText },
            {
              label = L.NON_MYTHIC_NOTICE_LABEL_HINT or "Hint:",
              value = L.NON_MYTHIC_NOTICE_HINT_NON_MYTHIC or "Not a Mythic+ dungeon",
              warning = true,
              blink = true,
            },
            {
              label = L.NON_MYTHIC_NOTICE_LABEL_SOURCE or "Source:",
              value = L.NON_MYTHIC_NOTICE_SOURCE_INSTANCE_ENTERED or "Instance entered",
            },
          },
          frameWidth = 680,
        }
      end
      deps.showCenterNotice(string.format(template, cText), 120, nil, nil, showOpts)
      -- Mark ownership so the leave-dungeon path knows it may hide this
      -- specific notice. Cleared on dungeon-leave / token-bumped pending
      -- show.
      state.nonMythicNoticeShown = true
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(3, function()
        pcall(ConfirmAndShowNotice)
      end)
    else
      ConfirmAndShowNotice()
    end
  end

  state.wasInDungeon = inDungeon
  state.lastDungeonContextSignature = dungeonContextSignature
end

local function MaybeShowPortalNavigatorNotice(state, deps)
  if type(deps.isPortalNavigatorEnabled) == "function" and deps.isPortalNavigatorEnabled() == false then
    state.portalNavigatorRetryToken = (state.portalNavigatorRetryToken or 0) + 1
    state.portalNavigatorRetryScheduledToken = nil
    if state.wasInPortalRoom == true or state.lastPortalNavigatorSignature ~= nil then
      deps.hidePortalNavigatorNotice()
    end
    state.wasInPortalRoom = false
    state.lastPortalNavigatorSignature = nil
    return
  end

  local zoneSignature, hasZoneText = ResolvePortalNavigatorZoneSignature(deps)
  if hasZoneText ~= true then
    if type(deps.timerAfter) == "function" then
      state.portalNavigatorRetryToken = (state.portalNavigatorRetryToken or 0) + 1
      local token = state.portalNavigatorRetryToken
      if state.portalNavigatorRetryScheduledToken ~= token then
        state.portalNavigatorRetryScheduledToken = token
        deps.timerAfter(1, function()
          if state.portalNavigatorRetryScheduledToken ~= token then
            return
          end
          state.portalNavigatorRetryScheduledToken = nil
          MaybeShowPortalNavigatorNotice(state, deps)
        end)
      end
    end
    return
  end
  local inPortalRoom = zoneSignature ~= nil

  if state.wasInPortalRoom == nil then
    state.wasInPortalRoom = inPortalRoom
    state.lastPortalNavigatorSignature = zoneSignature
    if inPortalRoom then
      local layout = BuildPortalNavigatorLayout(deps)
      if layout then
        deps.showPortalNavigatorNotice(layout)
      end
    end
    return
  end

  if not inPortalRoom then
    if state.wasInPortalRoom then
      deps.hidePortalNavigatorNotice()
    end
    state.wasInPortalRoom = false
    state.lastPortalNavigatorSignature = nil
    return
  end

  if (not state.wasInPortalRoom) or state.lastPortalNavigatorSignature ~= zoneSignature then
    local layout = BuildPortalNavigatorLayout(deps)
    if layout then
      deps.showPortalNavigatorNotice(layout)
    end
    state.lastPortalNavigatorSignature = zoneSignature
  end

  state.wasInPortalRoom = true
end

local function BuildStatusLineText(deps, flags)
  local L = deps.getL()
  local leadText = deps.isPlayerLeader() and L.STATUS_LEAD_YES or L.STATUS_LEAD_NO
  local hasActiveChallenge = false
  local challengeMode = rawget(_G, "C_ChallengeMode")
  if type(challengeMode) == "table" and type(challengeMode.GetActiveChallengeMapID) == "function" then
    local ok, mapID = pcall(challengeMode.GetActiveChallengeMapID)
    hasActiveChallenge = ok and mapID and true or false
  end
  local mplusText = hasActiveChallenge and L.STATUS_MPLUS_YES or L.STATUS_MPLUS_NO
  local targetDungeonText = BuildTargetDungeonText(deps)
  local stateText = GetAddonStateText(deps.getL, flags)
  local difficultyText = select(1, GetDungeonDifficultyLabel(deps.getL))
  return leadText
    .. " | "
    .. mplusText
    .. " | "
    .. stateText
    .. " | "
    .. string.format(L.DUNGEON_DIFF_TEXT, difficultyText)
    .. "\n"
    .. targetDungeonText
end

function Status.CreateController(opts)
  opts = opts or {}
  local deps = {
    getL = opts.getL or function()
      return {}
    end,
    getTime = opts.getTime or function()
      local getTimeFn = rawget(_G, "GetTime")
      if type(getTimeFn) ~= "function" then
        return nil
      end
      local ok, t = pcall(getTimeFn)
      if not ok then
        return nil
      end
      return t
    end,
    getSubZoneText = opts.getSubZoneText or function()
      local getSubZoneText = rawget(_G, "GetSubZoneText")
      if type(getSubZoneText) ~= "function" then
        return nil
      end
      local ok, text = pcall(getSubZoneText)
      if not ok then
        return nil
      end
      return text
    end,
    getZoneText = opts.getZoneText or function()
      local getZoneText = rawget(_G, "GetZoneText")
      if type(getZoneText) ~= "function" then
        return nil
      end
      local ok, text = pcall(getZoneText)
      if not ok then
        return nil
      end
      return text
    end,
    getPlayerMapID = opts.getPlayerMapID or function()
      local mapApi = rawget(_G, "C_Map")
      local getBestMapForUnit = mapApi and rawget(mapApi, "GetBestMapForUnit")
      if type(getBestMapForUnit) ~= "function" then
        return nil
      end
      local ok, mapID = pcall(getBestMapForUnit, "player")
      mapID = ok and tonumber(mapID) or nil
      if not mapID or mapID <= 0 then
        return nil
      end
      return math.floor(mapID)
    end,
    getMapInfoName = opts.getMapInfoName or function(mapID)
      local numericMapID = tonumber(mapID)
      if not numericMapID or numericMapID <= 0 then
        return nil
      end
      local mapApi = rawget(_G, "C_Map")
      local getMapInfo = mapApi and rawget(mapApi, "GetMapInfo")
      if type(getMapInfo) ~= "function" then
        return nil
      end
      local ok, mapInfo = pcall(getMapInfo, numericMapID)
      if not ok or type(mapInfo) ~= "table" then
        return nil
      end
      if type(mapInfo.name) ~= "string" then
        return nil
      end
      return mapInfo.name
    end,
    getTeleportInfoByMapID = opts.getTeleportInfoByMapID,
    getRealZoneText = opts.getRealZoneText or function()
      local getRealZoneText = rawget(_G, "GetRealZoneText")
      if type(getRealZoneText) ~= "function" then
        return nil
      end
      local ok, text = pcall(getRealZoneText)
      if not ok then
        return nil
      end
      return text
    end,
    showCenterNotice = opts.showCenterNotice
      or function(_message, _durationSeconds, _dungeonName, _activityID, _showOptions) end,
    hideCenterNotice = opts.hideCenterNotice or function() end,
    showPortalNavigatorNotice = opts.showPortalNavigatorNotice or function(_message) end,
    hidePortalNavigatorNotice = opts.hidePortalNavigatorNotice or function() end,
    isPortalNavigatorEnabled = opts.isPortalNavigatorEnabled or function()
      return true
    end,
    timerAfter = opts.timerAfter or function(_seconds, _callback) end,
    isPlayerLeader = opts.isPlayerLeader or function()
      return false
    end,
    isInGroup = opts.isInGroup or function()
      return false
    end,
    getTargetDungeonInfo = opts.getTargetDungeonInfo or function()
      return nil
    end,
    hasActiveDungeons = opts.hasActiveDungeons or function()
      return true
    end,
    getActiveSeasonLabel = opts.getActiveSeasonLabel or function()
      return nil
    end,
    printFn = opts.printFn or print,
    printHighlighted = opts.printHighlighted or opts.printFn or print,
  }

  local state = {
    wasInDungeon = nil,
    nonMythicNoticeToken = 0,
    -- Tracks whether THIS controller currently has a Non-Mythic-Entry notice
    -- visible in the shared center-notice frame. Guards the leave-dungeon
    -- hide path from killing notices that other code paths (Accepted-Invite,
    -- Lead-Transfer, Test-Mode, ...) own. Without this flag, every
    -- INSTANCE_CONTEXT_CHANGED / PLAYER_ENTERING_WORLD / OWNED_KEY_CONTEXT
    -- outside a dungeon called deps.hideCenterNotice() unconditionally and
    -- closed any active notice after ~1 second.
    nonMythicNoticeShown = false,
    lastDungeonContextSignature = nil,
    lastAnnouncedNonMythicSignature = nil,
    wasInPortalRoom = nil,
    lastPortalNavigatorSignature = nil,
    portalNavigatorRetryToken = 0,
    portalNavigatorRetryScheduledToken = nil,
    lastObservedTargetDungeonName = nil,
    lastTargetDungeonChatSignature = nil,
  }

  local controller = {}

  function controller.GetAddonStateText(flags)
    return GetAddonStateText(deps.getL, flags)
  end

  function controller.GetDungeonDifficultyLabel()
    return GetDungeonDifficultyLabel(deps.getL)
  end

  function controller.MaybeShowNonMythicDungeonEntryNotice()
    return MaybeShowNonMythicDungeonEntryNotice(state, deps)
  end

  function controller.MaybeShowPortalNavigatorNotice()
    return MaybeShowPortalNavigatorNotice(state, deps)
  end

  function controller.BuildStatusLineText(flags)
    return BuildStatusLineText(deps, flags)
  end

  function controller.MaybeAnnounceTargetDungeonChat()
    return MaybeAnnounceTargetDungeonChat(state, deps)
  end

  -- Direct-push entry point for the LFG-accept trigger. Bypasses the
  -- resolver chain inside MaybeAnnounceTargetDungeonChat — the payload here
  -- comes straight from the listing the player just accepted (the same
  -- payload the Center Notice already rendered), so name + level are
  -- authoritative without needing the LFG-title-hint / roster-owner /
  -- synced-target fallbacks. Sets the levelAnnouncedTargetDungeonName
  -- lock-in so a subsequent resolver-driven re-evaluation (triggered by
  -- the next UpdateStatusLine event) does not re-emit the line.
  --
  -- Group-presence check intentionally omitted: by the time the LFG-accept
  -- callback fires we are joining or already in the group, but IsInGroup()
  -- can transiently return false right after the accept event. The notice
  -- shows regardless, and the chat line should follow.
  --
  -- level=nil semantics (deliberate): when the listing carries no "+N"
  -- marker, the announce emits level-less AND still arms the lock-in.
  -- That means a later resolver-driven re-evaluation cannot upgrade the
  -- announce to "+N" even if a roster-owner or peer-sync source produces
  -- a level mid-cycle. This is intentional — the LFG payload is the
  -- authoritative source for the accept path; downstream resolver hits
  -- are less reliable and have produced wrong-level / wrong-dungeon
  -- regressions before (cf. 0.9.236 → 0.9.240 changelog). Two cycles
  -- on the same dungeon name remain possible after a group-leave reset.
  function controller.AnnounceTargetDungeonFromPayload(payload)
    if type(payload) ~= "table" then
      return
    end
    local name = type(payload.name) == "string" and StringUtils.Trim(payload.name) or nil
    if not name or name == "" then
      return
    end
    local level = tonumber(payload.level)
    if level and level <= 0 then
      level = nil
    end
    local levelText = nil
    if not level and type(payload.levelText) == "string" and string.match(payload.levelText, "^|Kk%d+|k$") then
      levelText = payload.levelText
    end
    -- Vorfall 2026-05-15: modern WoW encodes the LFG title as opaque pipe
    -- markup ("|Kk<id>|k") whose <id> is a client-side lookup, NOT the
    -- level. ParseTitleKeyLevel correctly returns nil for that shape, so
    -- payload.level arrives nil. If LFGDetect can still provide the exact
    -- opaque Blizzard keystone markup as levelText, the chat frame can render
    -- that observed value as "+N"; otherwise we must NOT emit a level-less
    -- direct-push line.
    if not level and not levelText then
      return
    end
    if state.levelAnnouncedTargetDungeonName == name then
      return
    end
    EmitTargetDungeonAnnouncement(state, deps, { name = name, level = level, levelText = levelText })
  end

  return controller
end
