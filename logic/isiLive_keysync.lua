local _, addonTable = ...

addonTable = addonTable or {}

local KeySync = {}
addonTable.KeySync = KeySync

local SeasonData = addonTable.SeasonData or {}
local IsSecretValue = addonTable.Validators.IsSecretValue
local GetInstanceInfoSafe = addonTable.Validators.GetInstanceInfoSafe

-- Module-level diagnostics counters. These are write-only from inside
-- KeySync internals and read-only from outside via KeySync.GetDiagnostics().
-- The unique-owner guard in ResolveActiveKeyOwnerUnit fails closed when a
-- single-match roster lacks a hint, which is silent by design — surfacing
-- the skip count lets `/dump` / debug code distinguish "guard never fired"
-- from "guard suppressing X resolutions per session" without spamming the
-- runtime log on the hot path.
local diagnostics = {
  uniqueOwnerGuardSkips = 0,
}

local KICK_PEER_STALE_SECONDS = 45

function KeySync.GetDiagnostics()
  return {
    uniqueOwnerGuardSkips = diagnostics.uniqueOwnerGuardSkips,
  }
end

function KeySync.ResetDiagnostics()
  diagnostics.uniqueOwnerGuardSkips = 0
end

-- Fallback for when C_MythicPlus.GetOwnedKeystone* returns nil/0 (observed
-- on receivers after SHAREKEYS broadcast: API is present but returns empty
-- because the per-client cache has not been populated yet). The bag link
-- itself carries mapID and level: |Hkeystone:180653:<mapID>:<level>:...|h.
-- C_Container.GetContainerItemLink is "AllowedWhenUntainted" — safe to call
-- in combat and during M+ keystones from untainted callers (button click,
-- CHAT_MSG_ADDON dispatch).
local function ScanBagsForKeystoneSnapshot()
  local containerApi = rawget(_G, "C_Container")
  if
    not containerApi
    or type(containerApi.GetContainerNumSlots) ~= "function"
    or type(containerApi.GetContainerItemID) ~= "function"
    or type(containerApi.GetContainerItemLink) ~= "function"
  then
    return nil, nil
  end
  for bagID = 0, 5 do
    local okSlots, numSlots = pcall(containerApi.GetContainerNumSlots, bagID)
    if okSlots and type(numSlots) == "number" and numSlots > 0 then
      for slotID = 1, numSlots do
        local okID, itemID = pcall(containerApi.GetContainerItemID, bagID, slotID)
        if okID and itemID == 180653 then
          local okLink, link = pcall(containerApi.GetContainerItemLink, bagID, slotID)
          if okLink and type(link) == "string" then
            local mapID, level = link:match("|Hkeystone:180653:(%d+):(%d+)")
            mapID = tonumber(mapID)
            level = tonumber(level)
            if mapID and level and mapID > 0 and level > 0 then
              return mapID, level
            end
          end
        end
      end
    end
  end
  return nil, nil
end

local function GetOwnedKeystoneSnapshot()
  local mapID, level = nil, nil

  local mythicPlusApi = rawget(_G, "C_MythicPlus")
  if mythicPlusApi then
    local okLevel, apiLevel = pcall(mythicPlusApi.GetOwnedKeystoneLevel)
    local okMapID, apiMapID = pcall(mythicPlusApi.GetOwnedKeystoneChallengeMapID)
    if okLevel and okMapID then
      level = tonumber(apiLevel)
      mapID = tonumber(apiMapID)
    end
  end

  if not level or level <= 0 or not mapID or mapID <= 0 then
    mapID, level = ScanBagsForKeystoneSnapshot()
  end

  if not mapID or not level then
    return nil, nil
  end

  -- Apply NormalizeMapID on read; sync.lua NormalizeKeyPayload applies it again
  -- (idempotent) to normalize incoming messages uniformly.
  if type(SeasonData.NormalizeMapID) == "function" then
    mapID = SeasonData.NormalizeMapID(mapID)
  end
  if not level or level <= 0 or not mapID or mapID <= 0 then
    return nil, nil
  end

  return mapID, level
end

local function ResolveAverageItemLevel()
  local cItem = rawget(_G, "C_Item")
  if type(cItem) == "table" and type(cItem.GetAverageItemLevel) == "function" then
    local ok, avgIlvl, equippedIlvl = pcall(cItem.GetAverageItemLevel)
    if not ok or IsSecretValue(avgIlvl) or IsSecretValue(equippedIlvl) then
      return nil
    end
    local resolved = tonumber(equippedIlvl) or tonumber(avgIlvl)
    if resolved and resolved > 0 then
      return math.floor(resolved)
    end
  else
    local getAverageItemLevel = rawget(_G, "GetAverageItemLevel")
    if type(getAverageItemLevel) ~= "function" then
      return nil
    end
    local ok, avgIlvl, equippedIlvl = pcall(getAverageItemLevel)
    if not ok or IsSecretValue(avgIlvl) or IsSecretValue(equippedIlvl) then
      return nil
    end
    local resolved = tonumber(equippedIlvl) or tonumber(avgIlvl)
    if resolved and resolved > 0 then
      return math.floor(resolved)
    end
  end
  return nil
end

-- Exposed so the group module can populate the player row's ilvl directly:
-- CanInspect("player") is unreliable (often false for self) and NotifyInspect
-- on "player" is restricted during M+ keystones under 12.0, so the inspect
-- pipeline never fills roster.player.ilvl. C_Item.GetAverageItemLevel works
-- for the local player without any inspect dance.
KeySync.ResolveAverageItemLevel = ResolveAverageItemLevel

local function GetOwnedStatsSnapshot(getUnitRio)
  local specID = nil
  local getSpecialization = rawget(_G, "GetSpecialization")
  local getSpecializationInfo = rawget(_G, "GetSpecializationInfo")
  if type(getSpecialization) == "function" and type(getSpecializationInfo) == "function" then
    local okIndex, specIndex = pcall(getSpecialization)
    if okIndex and not IsSecretValue(specIndex) and type(specIndex) == "number" and specIndex > 0 then
      local okInfo, resolvedSpecID = pcall(getSpecializationInfo, specIndex)
      if not okInfo or IsSecretValue(resolvedSpecID) then
        resolvedSpecID = nil
      end
      resolvedSpecID = tonumber(resolvedSpecID)
      if resolvedSpecID and resolvedSpecID > 0 then
        specID = math.floor(resolvedSpecID)
      end
    end
  end

  local ilvl = ResolveAverageItemLevel()

  local rio = nil
  if type(getUnitRio) == "function" then
    local okRio, rawRio = pcall(getUnitRio, "player")
    local resolvedRio = okRio and not IsSecretValue(rawRio) and tonumber(rawRio) or nil
    if resolvedRio then
      rio = math.max(0, math.floor(resolvedRio))
    end
  end

  return specID, ilvl, rio
end

local function SendIsiLiveHello(sync, isFrameVisible, getAddonVersionRaw, force, source)
  sync.SendHello({
    force = not not force,
    isVisible = isFrameVisible(),
    allowHidden = true,
    version = getAddonVersionRaw(),
    protocolVersion = type(sync.GetProtocolVersion) == "function" and sync.GetProtocolVersion() or nil,
    source = source,
  })
end

local function SendRefreshRequest(sync, force)
  sync.SendRefreshRequest({
    force = not not force,
  })
  if type(sync.SendLibKeystoneRequest) == "function" then
    sync.SendLibKeystoneRequest({
      force = not not force,
    })
  end
end

local function SendLibKeystonePartyData(sync, getUnitRio, force)
  if type(sync.SendLibKeystonePartyData) ~= "function" then
    return false
  end

  local mapID, level = GetOwnedKeystoneSnapshot()
  local _, _, rio = GetOwnedStatsSnapshot(getUnitRio)
  return sync.SendLibKeystonePartyData({
    force = not not force,
    mapID = mapID,
    level = level,
    rio = rio,
  })
end

local function GetOwnedLocMapID()
  if type(GetInstanceInfoSafe) ~= "function" then
    return nil
  end
  local ok, instanceInfo = GetInstanceInfoSafe()
  if not ok or instanceInfo.instanceType ~= "party" then
    return nil
  end
  local mapApi = rawget(_G, "C_Map")
  local getBestMapForUnit = mapApi and mapApi.GetBestMapForUnit
  if type(getBestMapForUnit) ~= "function" or not addonTable.Validators.IsExistingUnit("player") then
    return nil
  end
  local okMap, mapID = pcall(getBestMapForUnit, "player")
  mapID = okMap and not IsSecretValue(mapID) and tonumber(mapID) or nil
  if not mapID or mapID <= 0 then
    return nil
  end
  return math.floor(mapID)
end

local function SendOwnStateSnapshot(sync, isFrameVisible, getUnitRio, getPlayerLastRunDps, getUnitNameAndRealm, opts)
  opts = opts or {}

  local isVisible = isFrameVisible()
  local force = not not opts.force
  local source = opts.source
  local allowHidden = opts.allowHidden == true
  local onlyIfChanged = opts.onlyIfChanged == true
  local includeDps = opts.includeDps ~= false

  local mapID, level = GetOwnedKeystoneSnapshot()
  sync.SendKey({
    force = force,
    isVisible = isVisible,
    allowHidden = allowHidden,
    onlyIfChanged = onlyIfChanged,
    mapID = mapID,
    level = level,
    source = source,
  })

  local specID, ilvl, rio = GetOwnedStatsSnapshot(getUnitRio)
  sync.SendStats({
    force = force,
    isVisible = isVisible,
    allowHidden = allowHidden,
    onlyIfChanged = onlyIfChanged,
    specID = specID,
    ilvl = ilvl,
    rio = rio,
    source = source,
  })

  if includeDps then
    local dps = nil
    if type(getPlayerLastRunDps) == "function" and type(getUnitNameAndRealm) == "function" then
      local name, realm = getUnitNameAndRealm("player")
      if name then
        dps = getPlayerLastRunDps(name, realm)
      end
    end
    sync.SendDps({
      force = force,
      isVisible = isVisible,
      allowHidden = allowHidden,
      onlyIfChanged = onlyIfChanged,
      dps = dps,
      source = source,
    })
  end

  local locMapID = GetOwnedLocMapID()
  sync.SendLoc({
    force = force,
    isVisible = isVisible,
    allowHidden = allowHidden,
    onlyIfChanged = onlyIfChanged,
    mapID = locMapID,
    source = source,
  })
end

local function SendRefreshResponse(
  sync,
  isFrameVisible,
  getUnitRio,
  getPlayerLastRunDps,
  getUnitNameAndRealm,
  canRespondToRefreshRequest
)
  if type(canRespondToRefreshRequest) == "function" and not canRespondToRefreshRequest() then
    return false
  end

  SendOwnStateSnapshot(sync, isFrameVisible, getUnitRio, getPlayerLastRunDps, getUnitNameAndRealm, {
    force = true,
    source = "reqsync",
    allowHidden = true,
    onlyIfChanged = false,
    includeDps = true,
  })
  return true
end

local function ResolveSpecName(specID)
  local numericSpecID = tonumber(specID)
  if not numericSpecID or numericSpecID <= 0 then
    return nil
  end
  local getSpecializationInfoByID = rawget(_G, "GetSpecializationInfoByID")
  if type(getSpecializationInfoByID) ~= "function" then
    return nil
  end
  local ok, _, specName = pcall(getSpecializationInfoByID, numericSpecID)
  if not ok or IsSecretValue(specName) then
    return nil
  end
  return specName
end

local function CanBackfillPendingInspectValue(info, currentValue)
  if type(info) ~= "table" then
    return false
  end
  if not info._refreshQueued then
    return true
  end
  return currentValue == nil
end

local function BackfillKey(sync, info)
  local keyInfo = sync.GetPlayerKeyInfo(info.name, info.realm)
  local newMapID = keyInfo and keyInfo.mapID or nil
  local newLevel = keyInfo and keyInfo.level or nil
  if info.keyMapID == newMapID and info.keyLevel == newLevel then
    return false
  end
  info.keyMapID = newMapID
  info.keyLevel = newLevel
  return true
end

local function BackfillStats(sync, info)
  local statsInfo = sync.GetPlayerStatsInfo(info.name, info.realm)
  if type(statsInfo) ~= "table" then
    return false
  end
  local changed = false
  if not info._localSpecFresh and statsInfo.specID then
    local specName = ResolveSpecName(statsInfo.specID)
    if specName and CanBackfillPendingInspectValue(info, info.spec) and info.spec ~= specName then
      info.spec = specName
      changed = true
    end
  end
  if
    not info._localIlvlFresh
    and statsInfo.ilvl
    and CanBackfillPendingInspectValue(info, info.ilvl)
    and info.ilvl ~= statsInfo.ilvl
  then
    info.ilvl = statsInfo.ilvl
    changed = true
  end
  if
    not info._localRioFresh
    and statsInfo.rio ~= nil
    and CanBackfillPendingInspectValue(info, info.rio)
    and info.rio ~= statsInfo.rio
  then
    info.rio = statsInfo.rio
    changed = true
  end
  return changed
end

local function BackfillDps(sync, info)
  local dpsInfo = sync.GetPlayerDpsInfo(info.name, info.realm)
  if type(dpsInfo) == "table" then
    if info.syncDps ~= dpsInfo.dps then
      info.syncDps = dpsInfo.dps
      return true
    end
    return false
  end
  -- Ghosts must keep their last-known syncDps so the UI keeps showing it after
  -- a group disband (clearKnownUsers wipes the sync cache, but the ghost row
  -- still represents historical state — symmetric to how ilvl/rio are handled
  -- above: no reset branch, so they stick when the sync cache returns nil).
  if info.syncDps ~= nil and not info.isGhost then
    info.syncDps = nil
    return true
  end
  return false
end

local function BackfillLoc(sync, info)
  local locInfo = sync.GetPlayerLocInfo(info.name, info.realm)
  if type(locInfo) == "table" then
    if info.syncLocMapID ~= locInfo.mapID then
      info.syncLocMapID = locInfo.mapID
      return true
    end
    return false
  end
  if info.syncLocMapID ~= nil and not info.isGhost then
    info.syncLocMapID = nil
    return true
  end
  return false
end

local function ResolveElapsedSinceReceived(receivedAtGetTime)
  if not receivedAtGetTime then
    return 0
  end
  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return 0
  end
  return getTime() - receivedAtGetTime
end

local function DecayKickRemain(kickInfo)
  if not (kickInfo.onCooldown and kickInfo.receivedAtGetTime) then
    return kickInfo.cooldownRemain
  end
  local elapsed = ResolveElapsedSinceReceived(kickInfo.receivedAtGetTime)
  return math.max(0, kickInfo.cooldownRemain - elapsed)
end

-- Decay extras the same way: subtract elapsed time off each entry's remain.
-- Drop entries whose remain has expired.
local function DecayKickExtras(kickInfo)
  if type(kickInfo.extras) ~= "table" then
    return nil
  end
  local elapsed = ResolveElapsedSinceReceived(kickInfo.receivedAtGetTime)
  local result = nil
  for spellID, data in pairs(kickInfo.extras) do
    local remain = type(data) == "table" and tonumber(data.cooldownRemain) or nil
    if remain then
      local adjusted = math.max(0, remain - elapsed)
      if adjusted > 0 then
        result = result or {}
        result[spellID] = { cooldownRemain = adjusted }
      end
    end
  end
  return result
end

-- Drift threshold for extras is intentionally larger than the primary
-- (0.6 s vs 0.05 s for syncKickRemain). Extras are talent / pet-swap
-- interrupts (typically 30 s CDs); a sub-second drift is below visual
-- perception in the tooltip and not worth a full re-render burst.
-- Primary cooldowns drive the bright Kick column and need tighter sync so
-- the displayed countdown ticks smoothly second-by-second.
local function DidExtrasChange(prev, next)
  if (prev == nil) ~= (next == nil) then
    return true
  end
  if not prev or not next then
    return false
  end
  for sid, d in pairs(next) do
    local pd = prev[sid]
    if not pd or math.abs((pd.cooldownRemain or 0) - d.cooldownRemain) > 0.6 then
      return true
    end
  end
  for sid in pairs(prev) do
    if not next[sid] then
      return true
    end
  end
  return false
end

local function ClearKickFields(info)
  if
    info.syncHasKick == nil
    and info.syncKickOnCooldown == nil
    and info.syncKickRemain == nil
    and info.syncKickSpellID == nil
    and info.syncKickExtras == nil
  then
    return false
  end
  info.syncHasKick = nil
  info.syncKickOnCooldown = nil
  info.syncKickRemain = nil
  info.syncKickSpellID = nil
  info.syncKickExtras = nil
  return true
end

local function ApplyHasNoKick(info)
  if
    info.syncHasKick == false
    and info.syncKickOnCooldown == nil
    and info.syncKickRemain == nil
    and info.syncKickSpellID == nil
    and info.syncKickExtras == nil
  then
    return false
  end
  info.syncHasKick = false
  info.syncKickOnCooldown = nil
  info.syncKickRemain = nil
  info.syncKickSpellID = nil
  info.syncKickExtras = nil
  return true
end

local function IsKickInfoStale(kickInfo)
  if type(kickInfo) ~= "table" or kickInfo.receivedAtGetTime == nil then
    return false
  end
  local elapsed = ResolveElapsedSinceReceived(kickInfo.receivedAtGetTime)
  return elapsed > KICK_PEER_STALE_SECONDS
end

local function ApplyActiveKick(info, kickInfo)
  local decayedRemain = DecayKickRemain(kickInfo)
  local decayedExtras = DecayKickExtras(kickInfo)
  local spellID = tonumber(kickInfo.spellID)
  if spellID and spellID <= 0 then
    spellID = nil
  end
  local extrasChanged = DidExtrasChange(info.syncKickExtras, decayedExtras)
  if
    info.syncHasKick == true
    and info.syncKickOnCooldown == kickInfo.onCooldown
    and math.abs((info.syncKickRemain or 0) - decayedRemain) <= 0.05
    and info.syncKickSpellID == spellID
    and not extrasChanged
  then
    return false
  end
  info.syncHasKick = true
  info.syncKickOnCooldown = kickInfo.onCooldown
  info.syncKickRemain = decayedRemain
  info.syncKickSpellID = spellID
  info.syncKickExtras = decayedExtras
  return true
end

local function BackfillKick(sync, info)
  local kickInfo = type(sync.GetPlayerKickInfo) == "function" and sync.GetPlayerKickInfo(info.name, info.realm)
  if type(kickInfo) ~= "table" then
    return ClearKickFields(info)
  end
  if IsKickInfoStale(kickInfo) then
    return ClearKickFields(info)
  end
  if kickInfo.hasKick == false then
    return ApplyHasNoKick(info)
  end
  return ApplyActiveKick(info, kickInfo)
end

local function ApplyKnownKeyToRosterEntry(sync, info)
  if type(info) ~= "table" or info.isDemoEntry then
    return false
  end
  local changed = false
  if BackfillKey(sync, info) then
    changed = true
  end
  if BackfillStats(sync, info) then
    changed = true
  end
  if BackfillDps(sync, info) then
    changed = true
  end
  if BackfillLoc(sync, info) then
    changed = true
  end
  if BackfillKick(sync, info) then
    changed = true
  end
  return changed
end

local function RealmKeyFromPlayerKey(playerKey)
  if type(playerKey) ~= "string" then
    return nil
  end
  return playerKey:match("%-([^-]+)$")
end

local function RegisterVerifiedSyncAliasForRoster(sync, roster, sender)
  if type(sync.RegisterVerifiedAlias) ~= "function" or type(sync.NormalizePlayerKey) ~= "function" then
    return false
  end
  if type(roster) ~= "table" or type(sender) ~= "string" or sender == "" then
    return false
  end

  local senderKey = sync.NormalizePlayerKey(sender)
  local senderRealmKey = RealmKeyFromPlayerKey(senderKey)
  if not senderRealmKey then
    return false
  end

  local candidate = nil
  local candidateCount = 0
  for _, info in pairs(roster) do
    if type(info) == "table" and not info.isDemoEntry then
      local rosterKey = sync.NormalizePlayerKey(info.name, info.realm)
      if rosterKey == senderKey then
        return false
      end
      if RealmKeyFromPlayerKey(rosterKey) == senderRealmKey then
        candidate = info
        candidateCount = candidateCount + 1
      end
    end
  end

  if candidateCount ~= 1 or type(candidate) ~= "table" then
    return false
  end
  return sync.RegisterVerifiedAlias(sender, nil, candidate.name, candidate.realm)
end

local function RefreshLocalPlayerKey(sync, roster)
  local playerInfo = roster and roster.player
  if type(playerInfo) ~= "table" then
    return false
  end

  local mapID, level = GetOwnedKeystoneSnapshot()
  sync.SetPlayerKeyInfo(playerInfo.name, playerInfo.realm, mapID, level)
  if playerInfo.keyMapID == mapID and playerInfo.keyLevel == level then
    return false
  end
  playerInfo.keyMapID = mapID
  playerInfo.keyLevel = level
  return true
end

local function ForceRefreshSyncState(sync, getUnitNameAndRealm, roster)
  if not roster then
    return
  end

  if sync.ClearKnownUsers then
    sync.ClearKnownUsers()
  end

  local playerName, playerRealm = getUnitNameAndRealm("player")
  sync.MarkUser(playerName, playerRealm)

  -- Non-player entries are cleared; the player entry is then set directly
  -- to the current keystone and does not need an intermediate clear.
  for unit, info in pairs(roster) do
    if type(info) == "table" then
      info.hasIsiLive = (unit == "player")
      info.syncDps = nil
      info.syncLocMapID = nil
      if unit ~= "player" then
        info.keyMapID = nil
        info.keyLevel = nil
        sync.SetPlayerKeyInfo(info.name, info.realm, nil, nil)
      end
      if type(sync.SetPlayerStatsInfo) == "function" then
        sync.SetPlayerStatsInfo(info.name, info.realm, nil, nil, nil)
      end
      if type(sync.SetPlayerDpsInfo) == "function" then
        sync.SetPlayerDpsInfo(info.name, info.realm, nil)
      end
      if type(sync.SetPlayerLocInfo) == "function" then
        sync.SetPlayerLocInfo(info.name, info.realm, nil)
      end
    end
  end

  local ownKeyMapID, ownKeyLevel = GetOwnedKeystoneSnapshot()
  if roster.player and type(roster.player) == "table" then
    roster.player.keyMapID = ownKeyMapID
    roster.player.keyLevel = ownKeyLevel
  end
  sync.SetPlayerKeyInfo(playerName, playerRealm, ownKeyMapID, ownKeyLevel)
end

-- Parses a Blizzard LFG name field like "Mematiwow" or "Mematiwow-Blackmoore"
-- into (name, realm). realm is nil when the hint only contains a bare name
-- (Blizzard strips the realm when it matches the local player's realm).
local function SplitNameRealm(nameRealm)
  if type(nameRealm) ~= "string" or nameRealm == "" then
    return nil, nil
  end
  local dash = string.find(nameRealm, "-", 1, true)
  if not dash then
    return nameRealm, nil
  end
  local name = string.sub(nameRealm, 1, dash - 1)
  local realmPart = string.sub(nameRealm, dash + 1)
  if name == "" then
    return nil, nil
  end
  if realmPart == "" then
    return name, nil
  end
  return name, realmPart
end

-- Returns the roster unit whose (name[, realm]) matches the LFG-style hint, or
-- nil when no entry matches. The hint's realm is optional — if absent, name
-- alone is enough because Blizzard's API omits the realm for same-realm names.
local function FindRosterUnitByHint(roster, preferredOwnerName)
  local hintName, hintRealm = SplitNameRealm(preferredOwnerName)
  if not hintName then
    return nil
  end
  for unit, info in pairs(roster or {}) do
    if type(info) == "table" and info.name == hintName then
      if hintRealm == nil or info.realm == nil or info.realm == hintRealm then
        return unit
      end
    end
  end
  return nil
end

-- preferredOwnerName is an optional LFG-leader hint (e.g. "Mematiwow-Blackmoore"
-- from C_LFGList.GetSearchResultInfo). When provided and the hinted roster
-- member holds a key for targetMapID, that unit wins over the generic ambiguity
-- guard — this disambiguates the case where multiple group members happen to
-- own a key for the same dungeon.
--
-- Fail-closed guard: if the hinted unit is in the roster but does not expose
-- a matching keyMapID (e.g. the leader has no isiLive / LibKeystone sync),
-- we must NOT fall back to the unique-owner search. Doing so would highlight
-- another member who happens to carry a key for the same dungeon as the
-- "active" key owner — a confidently wrong answer. Only when the hint points
-- to no roster entry at all (e.g. boost runs where the applicant is not the
-- key owner) do we let the unique-owner fallback run.
local function ResolveActiveKeyOwnerUnit(roster, activeJoinedKeyMapID, preferredOwnerName)
  local targetMapID = tonumber(activeJoinedKeyMapID)
  if not targetMapID then
    return nil
  end

  local hintedUnit = FindRosterUnitByHint(roster, preferredOwnerName)
  if hintedUnit then
    local hintedInfo = roster[hintedUnit]
    if type(hintedInfo) == "table" and tonumber(hintedInfo.keyMapID) == targetMapID then
      return hintedUnit
    end
    return nil
  end

  -- Unique-owner fallback. Behaviour split by whether the caller supplied
  -- a hint:
  --
  --   * Hint present + hint not found in roster (boost case): the listing
  --     owner is not in the roster at all (the applicant got accepted onto
  --     a leader who is no longer the group leader, weird relistings, etc.).
  --     Falling through to a single-match search is the documented deterministic
  --     answer here.
  --
  --   * Hint absent (preferredOwnerName == nil): both the LFG-leader source
  --     and the group-leader-via-UnitIsGroupLeader fallback returned
  --     nothing. In a multi-member group that is the GROUP_ROSTER_UPDATE
  --     race window — sync has only published the locally instant data
  --     (the player's own key and whatever another addon already mirrored,
  --     e.g. LibKeystone) while the actual listing-owner's key has not
  --     made the roundtrip yet. Returning the lone match would surface
  --     whichever member happens to carry a matching key (the player's own
  --     SOT +15, or another member's POS +14 instead of the listing's
  --     POS +13). Stay nil and let the deferred consumer wait for a real
  --     source. Solo / 1-man rosters still resolve normally.
  local noHintProvided = not (type(preferredOwnerName) == "string" and preferredOwnerName ~= "")

  local ownerUnit = nil
  local rosterSize = 0
  local matches = 0
  for unit, info in pairs(roster or {}) do
    if type(info) == "table" and not info.isGhost then
      rosterSize = rosterSize + 1
      if tonumber(info.keyMapID) == targetMapID then
        matches = matches + 1
        ownerUnit = unit
        if matches > 1 then
          return nil
        end
      end
    end
  end

  if matches == 1 then
    if rosterSize > 1 and noHintProvided then
      diagnostics.uniqueOwnerGuardSkips = diagnostics.uniqueOwnerGuardSkips + 1
      return nil
    end
    return ownerUnit
  end
  return nil
end

function KeySync.CreateController(opts)
  opts = opts or {}
  local sync = opts.sync or {}
  local getUnitNameAndRealm = opts.getUnitNameAndRealm or function(_unit)
    return nil, nil
  end
  local getAddonVersionRaw = opts.getAddonVersionRaw or function()
    return "?"
  end
  local getUnitRio = opts.getUnitRio or function(_unit)
    return nil
  end
  local isFrameVisible = opts.isFrameVisible or function()
    return false
  end
  local canRespondToRefreshRequest = opts.canRespondToRefreshRequest or function()
    return true
  end
  local getPlayerLastRunDps = opts.getPlayerLastRunDps or nil
  local logRuntimeTracef = type(opts.logRuntimeTracef) == "function" and opts.logRuntimeTracef or nil
  assert(type(sync.MarkUser) == "function", "isiLive: KeySync requires sync.MarkUser")
  assert(type(sync.IsUnitKnown) == "function", "isiLive: KeySync requires sync.IsUnitKnown")
  assert(type(sync.RegisterPrefix) == "function", "isiLive: KeySync requires sync.RegisterPrefix")
  assert(type(sync.SendHello) == "function", "isiLive: KeySync requires sync.SendHello")
  assert(type(sync.SendKey) == "function", "isiLive: KeySync requires sync.SendKey")
  assert(type(sync.SendStats) == "function", "isiLive: KeySync requires sync.SendStats")
  assert(type(sync.SendDps) == "function", "isiLive: KeySync requires sync.SendDps")
  assert(type(sync.SendLoc) == "function", "isiLive: KeySync requires sync.SendLoc")
  assert(type(sync.SendRefreshRequest) == "function", "isiLive: KeySync requires sync.SendRefreshRequest")
  assert(type(sync.SendLibKeystoneRequest) == "function", "isiLive: KeySync requires sync.SendLibKeystoneRequest")
  assert(type(sync.SendLibKeystonePartyData) == "function", "isiLive: KeySync requires sync.SendLibKeystonePartyData")
  assert(type(sync.GetPlayerKeyInfo) == "function", "isiLive: KeySync requires sync.GetPlayerKeyInfo")
  assert(type(sync.GetPlayerStatsInfo) == "function", "isiLive: KeySync requires sync.GetPlayerStatsInfo")
  assert(type(sync.GetPlayerDpsInfo) == "function", "isiLive: KeySync requires sync.GetPlayerDpsInfo")
  assert(type(sync.GetPlayerLocInfo) == "function", "isiLive: KeySync requires sync.GetPlayerLocInfo")
  assert(type(sync.SetPlayerKeyInfo) == "function", "isiLive: KeySync requires sync.SetPlayerKeyInfo")

  local controller = {}

  function controller.MarkIsiLiveUser(name, realm)
    sync.MarkUser(name, realm)
  end

  function controller.UnitHasIsiLive(unit)
    return sync.IsUnitKnown(getUnitNameAndRealm, unit)
  end

  function controller.RegisterIsiLiveSyncPrefix()
    sync.RegisterPrefix()
  end

  function controller.SendIsiLiveHello(force, source)
    SendIsiLiveHello(sync, isFrameVisible, getAddonVersionRaw, force, source)
  end

  function controller.SendRefreshRequest(force)
    SendRefreshRequest(sync, force)
  end

  function controller.SendLibKeystonePartyData(force)
    return SendLibKeystonePartyData(sync, getUnitRio, force)
  end

  function controller.GetOwnedKeystoneSnapshot()
    return GetOwnedKeystoneSnapshot()
  end

  function controller.SendOwnKeySnapshot(force, source, allowHidden, onlyIfChanged, includeDps)
    SendOwnStateSnapshot(sync, isFrameVisible, getUnitRio, getPlayerLastRunDps, getUnitNameAndRealm, {
      force = force,
      source = source,
      allowHidden = allowHidden,
      onlyIfChanged = onlyIfChanged,
      includeDps = includeDps,
    })
  end

  function controller.SendOwnBackgroundSnapshot(source)
    local visible = isFrameVisible()
    SendOwnStateSnapshot(sync, isFrameVisible, getUnitRio, getPlayerLastRunDps, getUnitNameAndRealm, {
      force = false,
      source = source,
      allowHidden = not visible,
      onlyIfChanged = not visible,
      includeDps = true,
    })
  end

  function controller.SendRefreshResponse()
    return SendRefreshResponse(
      sync,
      isFrameVisible,
      getUnitRio,
      getPlayerLastRunDps,
      getUnitNameAndRealm,
      canRespondToRefreshRequest
    )
  end

  function controller.ApplyKnownKeyToRosterEntry(info)
    local changed = ApplyKnownKeyToRosterEntry(sync, info)
    if changed and logRuntimeTracef then
      local keyInfo = type(info) == "table" and sync.GetPlayerKeyInfo(info.name, info.realm)
      logRuntimeTracef(
        "[KEYSYNC] applied unit=%s mapID=%s level=%s",
        tostring(info and info.name or "?"),
        tostring(keyInfo and keyInfo.mapID or "nil"),
        tostring(keyInfo and keyInfo.level or "nil")
      )
    end
    return changed
  end

  function controller.RegisterVerifiedSyncAliasForRoster(roster, sender)
    return RegisterVerifiedSyncAliasForRoster(sync, roster, sender)
  end

  function controller.RefreshLocalPlayerKey(roster)
    return RefreshLocalPlayerKey(sync, roster)
  end

  function controller.ForceRefreshSyncState(roster)
    ForceRefreshSyncState(sync, getUnitNameAndRealm, roster)
  end

  function controller.ResolveActiveKeyOwnerUnit(roster, activeJoinedKeyMapID, preferredOwnerName)
    return ResolveActiveKeyOwnerUnit(roster, activeJoinedKeyMapID, preferredOwnerName)
  end

  return controller
end
