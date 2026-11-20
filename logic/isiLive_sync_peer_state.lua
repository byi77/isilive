local _, addonTable = ...

addonTable = addonTable or {}

-- Session store for everything received from sync peers: known users,
-- HELLO/ACK versions, the timestamped KEY/STATS/DPS/LOC/TARGET buckets with
-- their monotonic watermarks, kick state and run kicks. Module-level
-- singleton, like the Sync facade (logic/isiLive_sync.lua): the facade binds
-- it once at load and re-exports its functions, so every caller keeps using
-- Sync.*.
--
-- Dependency contract (SyncPeerState.Bind, all required):
--   deps.normalizePlayerKey(name, realm) -> string  canonical peer key
-- Wire normalization comes from addonTable.SyncCodec (loaded before).
local SyncPeerState = {}
addonTable.SyncPeerState = SyncPeerState
local PeerState = SyncPeerState

local StringUtils = addonTable.StringUtils
local codec = addonTable.SyncCodec
local ToFiniteNumber = codec.ToFiniteNumber
local GetSyncTimestamp = codec.GetSyncTimestamp
local NormalizeSyncSource = codec.NormalizeSyncSource
local NormalizeSyncAddonVersion = codec.NormalizeSyncAddonVersion
local NormalizeSyncProtocolVersion = codec.NormalizeSyncProtocolVersion
local NormalizeKeyPayload = codec.NormalizeKeyPayload
local NormalizeStatsPayload = codec.NormalizeStatsPayload
local NormalizeDpsPayload = codec.NormalizeDpsPayload
local NormalizeRunKicksSuffix = codec.NormalizeRunKicksSuffix
local NormalizeRunKicksMissedSuffix = codec.NormalizeRunKicksMissedSuffix
local NormalizeLocPayload = codec.NormalizeLocPayload
local NormalizeTargetPayload = codec.NormalizeTargetPayload

local normalizePlayerKey = nil

local function NormalizePlayerKey(name, realm)
  return normalizePlayerKey(name, realm)
end

--- Binds the canonical peer key. Called once by the Sync facade at load.
-- @param deps table {normalizePlayerKey = function(name, realm) -> string}
function SyncPeerState.Bind(deps)
  assert(type(deps) == "table", "SyncPeerState.Bind: deps required")
  assert(type(deps.normalizePlayerKey) == "function", "SyncPeerState.Bind: normalizePlayerKey required")
  normalizePlayerKey = deps.normalizePlayerKey
end

local isiLiveUsersByKey = {}
local helloInfoByPlayerKey = {}
local keyInfoByPlayerKey = {}
local statsInfoByPlayerKey = {}
local dpsInfoByPlayerKey = {}
local locInfoByPlayerKey = {}
local targetInfoByPlayerKey = {}
local kickInfoByPlayerKey = {}
local runKicksCastByPlayerKey = {}
local kickInfoGeneration = 0
local snapshotWatermarks = {}

--- Records that a player has sent at least one sync message this session.
-- @param name string Player name.
-- @param realm string|nil Realm name.
function PeerState.MarkUser(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if key and key ~= "" then
    isiLiveUsersByKey[key] = true
  end
end

--- Returns whether a player is a known sync peer (has sent at least one message this session).
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return boolean
function PeerState.IsUserKnown(name, realm)
  local key = NormalizePlayerKey(name, realm)
  return key and isiLiveUsersByKey[key] == true or false
end

--- Returns whether the given WoW unit belongs to a known sync peer.
-- @param getUnitNameAndRealm function Callback returning (name, realm) for a unit token.
-- @param unit string WoW unit token (e.g. "party1").
-- @return boolean
function PeerState.IsUnitKnown(getUnitNameAndRealm, unit)
  if type(getUnitNameAndRealm) ~= "function" then
    return false
  end
  local name, realm = getUnitNameAndRealm(unit)
  return PeerState.IsUserKnown(name, realm)
end

local function GetEntrySyncStamp(entry)
  if type(entry) ~= "table" then
    return nil
  end

  local capturedAt = ToFiniteNumber(entry.capturedAt)
  local receivedAt = ToFiniteNumber(entry.receivedAt)
  return capturedAt or receivedAt
end

local function SetEntryPreviousSyncStamp(entry, previousStamp)
  if type(entry) ~= "table" then
    return
  end

  previousStamp = ToFiniteNumber(previousStamp)
  local nextStamp = GetEntrySyncStamp(entry)
  if previousStamp and nextStamp and nextStamp >= previousStamp then
    entry.previousSyncStamp = previousStamp
  else
    entry.previousSyncStamp = nil
  end
end

--- Stores a received HELLO payload for a peer.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param addonVersion string Peer's addon version string.
-- @param protocolVersion number|nil Peer's declared protocol version.
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label (e.g. "refresh", "local").
-- @return boolean true if this is the first HELLO from this peer; false if updated in-place.
function PeerState.SetPlayerHelloInfo(name, realm, addonVersion, protocolVersion, capturedAt, source)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local normalizedProtocolVersion = NormalizeSyncProtocolVersion(protocolVersion)
  local normalizedCapturedAt = ToFiniteNumber(capturedAt)
  if not normalizedCapturedAt or normalizedCapturedAt <= 0 then
    normalizedCapturedAt = GetSyncTimestamp() or 0
  end
  local normalizedSource = NormalizeSyncSource(source) or "local"
  local previous = helloInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  local nextValue = {
    addonVersion = NormalizeSyncAddonVersion(addonVersion) or "?",
    protocolVersion = normalizedProtocolVersion,
    capturedAt = math.floor(normalizedCapturedAt),
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)

  if previous then
    previous.addonVersion = nextValue.addonVersion
    previous.protocolVersion = nextValue.protocolVersion
    previous.capturedAt = nextValue.capturedAt
    previous.source = nextValue.source
    previous.receivedAt = nextValue.receivedAt
    SetEntryPreviousSyncStamp(previous, previousStamp)
    return false
  end

  helloInfoByPlayerKey[key] = nextValue
  return true
end

--- Stores a received ACK (version-only hello acknowledgement) for a peer.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param addonVersion string Peer's addon version string.
-- @return boolean true if the stored version changed; false if unchanged or empty.
function PeerState.SetPlayerHelloAckInfo(name, realm, addonVersion)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local normalizedAddonVersion = NormalizeSyncAddonVersion(addonVersion)
  if not normalizedAddonVersion then
    return false
  end

  local previous = helloInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)

  if previous then
    local changed = previous.addonVersion ~= normalizedAddonVersion
    previous.addonVersion = normalizedAddonVersion
    previous.source = "ack"
    previous.receivedAt = GetSyncTimestamp()
    -- An ACK carries no capture time, so a stamped hello keeps its interval.
    if ToFiniteNumber(previous.capturedAt) == nil then
      SetEntryPreviousSyncStamp(previous, previousStamp)
    end
    return changed
  end

  local nextValue = {
    addonVersion = normalizedAddonVersion,
    protocolVersion = nil,
    capturedAt = nil,
    source = "ack",
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)
  helloInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored HELLO/ACK info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {addonVersion, protocolVersion, capturedAt, source, receivedAt, previousSyncStamp}
function PeerState.GetPlayerHelloInfo(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return helloInfoByPlayerKey[key]
end

-- Monotonic per-peer gate for timestamped snapshots. Only stamps supplied by the
-- peer move the watermark, and only an older stamp is refused: stamps have
-- one-second resolution, so equal stamps keep their arrival order. An unstamped
-- snapshot carries no capture time and applies in arrival order, also after a
-- stamped clear, because LibKeystone data of a peer whose stamped sends are gated
-- is real. ClearKnownUsers drops all marks with the session.
-- A mark also records that the peer reported this bucket in the session.
-- @return boolean true when the snapshot may be applied.
-- @return boolean true when an unstamped snapshot arrives over a verified stamp;
--   an identical payload must then keep the stored capture metadata.
local function AdmitSnapshot(kind, key, capturedAt)
  local marks = snapshotWatermarks[kind]
  if not marks then
    marks = {}
    snapshotWatermarks[kind] = marks
  end
  local mark = marks[key] or 0
  local incomingStamp = ToFiniteNumber(capturedAt)
  if not incomingStamp or incomingStamp <= 0 then
    marks[key] = mark
    return true, mark > 0
  end
  if incomingStamp < mark then
    return false, false
  end
  marks[key] = incomingStamp
  return true, false
end

-- An identical payload only refreshes metadata. Over a verified stamp the
-- capture metadata stays, so the entry keeps its real sync interval.
local function RefreshUnchangedEntry(entry, keepsVerifiedStamp, capturedAt, source, previousStamp)
  entry.receivedAt = GetSyncTimestamp()
  if keepsVerifiedStamp then
    return
  end
  entry.capturedAt = capturedAt
  entry.source = source
  SetEntryPreviousSyncStamp(entry, previousStamp)
end

--- Returns whether a peer reported a sync bucket since the last ClearKnownUsers.
-- @param kind string "key", "stats", "dps", "loc" or "target".
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return boolean
function PeerState.HasPeerReported(kind, name, realm)
  local marks = snapshotWatermarks[kind]
  local key = NormalizePlayerKey(name, realm)
  return marks ~= nil and key ~= nil and marks[key] ~= nil
end

--- Stores a received keystone payload for a peer. Clears the entry when mapID or level is invalid.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param mapID number|nil Dungeon map ID; 0 or nil clears the entry.
-- @param level number|nil Key level; 0 or nil clears the entry.
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label.
-- @return boolean true if the stored key changed; false if deduplicated or cleared unchanged.
function PeerState.SetPlayerKeyInfo(name, realm, mapID, level, capturedAt, source)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local _, numericMapID, numericLevel, normalizedCapturedAt, normalizedSource =
    NormalizeKeyPayload(mapID, level, capturedAt, source)
  local previous = keyInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  local isAdmitted, keepsVerifiedStamp = AdmitSnapshot("key", key, capturedAt)
  if not isAdmitted then
    return false
  end
  if not numericMapID or not numericLevel then
    local hadValue = type(previous) == "table"
    keyInfoByPlayerKey[key] = nil
    return hadValue
  end

  if previous and previous.mapID == numericMapID and previous.level == numericLevel then
    RefreshUnchangedEntry(previous, keepsVerifiedStamp, normalizedCapturedAt, normalizedSource, previousStamp)
    return false
  end

  local nextValue = {
    mapID = numericMapID,
    level = numericLevel,
    capturedAt = normalizedCapturedAt,
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)
  keyInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored keystone info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {mapID, level, capturedAt, source, receivedAt, previousSyncStamp}
function PeerState.GetPlayerKeyInfo(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return keyInfoByPlayerKey[key]
end

--- Stores a received stats payload (spec/ilvl/rio) for a peer. Clears the entry when all fields are invalid.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param specID number|nil Specialization ID (0 treated as missing).
-- @param ilvl number|nil Average item level (<=0 treated as missing).
-- @param rio number|nil Mythic+ rating (<0 treated as missing).
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label.
-- @return boolean true if stored stats changed; false if deduplicated or cleared unchanged.
function PeerState.SetPlayerStatsInfo(name, realm, specID, ilvl, rio, capturedAt, source)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local _, numericSpecID, numericIlvl, numericRio, normalizedCapturedAt, normalizedSource =
    NormalizeStatsPayload(specID, ilvl, rio, capturedAt, source)
  local previous = statsInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  local isAdmitted, keepsVerifiedStamp = AdmitSnapshot("stats", key, capturedAt)
  if not isAdmitted then
    return false
  end
  local nextValue = {
    specID = numericSpecID > 0 and numericSpecID or nil,
    ilvl = numericIlvl > 0 and numericIlvl or nil,
    rio = numericRio >= 0 and numericRio or nil,
    capturedAt = normalizedCapturedAt,
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)

  if nextValue.specID == nil and nextValue.ilvl == nil and nextValue.rio == nil then
    local hadValue = type(statsInfoByPlayerKey[key]) == "table"
    statsInfoByPlayerKey[key] = nil
    return hadValue
  end

  if
    previous
    and previous.specID == nextValue.specID
    and previous.ilvl == nextValue.ilvl
    and previous.rio == nextValue.rio
  then
    RefreshUnchangedEntry(previous, keepsVerifiedStamp, nextValue.capturedAt, nextValue.source, previousStamp)
    return false
  end

  statsInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored stats info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {specID, ilvl, rio, capturedAt, source, receivedAt, previousSyncStamp}
function PeerState.GetPlayerStatsInfo(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return statsInfoByPlayerKey[key]
end

--- Stores a received DPS payload for a peer. Clears the entry when dps <= 0.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param dps number Damage per second (rounded to nearest integer).
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label.
-- @return boolean true if stored DPS changed; false if deduplicated or cleared unchanged.
function PeerState.SetPlayerDpsInfo(name, realm, dps, capturedAt, source)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local _, numericDps, normalizedCapturedAt, normalizedSource = NormalizeDpsPayload(dps, capturedAt, source)
  local previous = dpsInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  local isAdmitted, keepsVerifiedStamp = AdmitSnapshot("dps", key, capturedAt)
  if not isAdmitted then
    return false
  end
  if not numericDps or numericDps <= 0 then
    local hadValue = type(dpsInfoByPlayerKey[key]) == "table"
    dpsInfoByPlayerKey[key] = nil
    return hadValue
  end

  if previous and previous.dps == numericDps then
    RefreshUnchangedEntry(previous, keepsVerifiedStamp, normalizedCapturedAt, normalizedSource, previousStamp)
    return false
  end

  local nextValue = {
    dps = numericDps,
    capturedAt = normalizedCapturedAt,
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)
  dpsInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored DPS info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {dps, capturedAt, source, receivedAt, previousSyncStamp}
function PeerState.GetPlayerDpsInfo(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return dpsInfoByPlayerKey[key]
end

--- Stores a peer's own interrupt casts of its last run (KC suffix, rule 238)
-- and its own missed kicks (KM suffix, rule 240).
-- Out-of-bounds or incomplete casts are rejected and leave the entry as it
-- was; an invalid or missing missed count is stored as unknown (nil).
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param cast number Own interrupt casts of the run.
-- @param mapID number Challenge map ID of the run.
-- @param level number Key level of the run.
-- @param missed number|nil Own missed kicks of the run.
-- @return boolean true if the stored value changed.
function PeerState.SetPlayerRunKicksCast(name, realm, cast, mapID, level, missed)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end
  local suffix, numericCast, numericMapID, numericLevel = NormalizeRunKicksSuffix(cast, mapID, level)
  if suffix == "" then
    return false
  end
  local _, numericMissed = NormalizeRunKicksMissedSuffix(missed, numericCast)
  local previous = runKicksCastByPlayerKey[key]
  if
    previous
    and previous.cast == numericCast
    and previous.mapID == numericMapID
    and previous.level == numericLevel
    and previous.missed == numericMissed
  then
    return false
  end
  runKicksCastByPlayerKey[key] =
    { cast = numericCast, mapID = numericMapID, level = numericLevel, missed = numericMissed }
  return true
end

--- Returns a peer's synced interrupt casts of its last run, or nil.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {cast, mapID, level, missed}
function PeerState.GetPlayerRunKicksCast(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return runKicksCastByPlayerKey[key]
end

--- Stores a received kick/interrupt availability payload for a peer.
-- Rejected (returns false) when hasKick or onCooldown are not explicit booleans,
-- or when hasKick==true and cooldownRemain is nil or negative.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param onCooldown boolean Whether the kick spell is currently on cooldown.
-- @param cooldownRemain number Remaining cooldown seconds; required when hasKick==true.
-- @param capturedAt number|nil Timestamp from the payload.
-- @param hasKick boolean Whether the player has a kick spell at all.
-- @param extras table|nil Extra kick cooldowns keyed by spellID.
-- @param spellID number|nil Primary kick spell ID when explicitly synced.
-- @return boolean true if stored kick state changed; false if unchanged or rejected.
function PeerState.SetPlayerKickInfo(name, realm, onCooldown, cooldownRemain, capturedAt, hasKick, extras, spellID)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end
  if hasKick ~= true and hasKick ~= false then
    return false
  end
  if onCooldown ~= true and onCooldown ~= false then
    return false
  end
  local now = GetSyncTimestamp()
  local prev = kickInfoByPlayerKey[key]
  local newOnCooldown = onCooldown == true
  local newHasKick = hasKick == true
  local numericRemain = ToFiniteNumber(cooldownRemain)
  if newHasKick then
    if numericRemain == nil or numericRemain < 0 then
      return false
    end
  elseif newOnCooldown then
    return false
  end
  local prevRemain = ToFiniteNumber(prev and prev.cooldownRemain) or 0
  local remainChanged = newHasKick and newOnCooldown and math.abs(prevRemain - numericRemain) > 0.05
  local numericSpellID = newHasKick and ToFiniteNumber(spellID) or nil
  if numericSpellID then
    if numericSpellID <= 0 then
      return false
    end
    numericSpellID = math.floor(numericSpellID)
  end
  -- Extras: sanitize input map; only pass through {[spellID]={cooldownRemain}}
  -- entries with a positive remain. Caller may pass nil to clear.
  local sanitizedExtras = nil
  if type(extras) == "table" then
    for extraSpellID, data in pairs(extras) do
      local sid = ToFiniteNumber(extraSpellID)
      local r = type(data) == "table" and ToFiniteNumber(data.cooldownRemain) or nil
      if sid and r and r > 0 then
        sanitizedExtras = sanitizedExtras or {}
        sanitizedExtras[sid] = { cooldownRemain = r }
      end
    end
  end
  local extrasChanged = false
  local prevExtras = prev and prev.extras or nil
  if (prevExtras == nil) ~= (sanitizedExtras == nil) then
    extrasChanged = true
  elseif sanitizedExtras and prevExtras then
    -- Compare keys + remains; small drift (<0.6s) treated as unchanged.
    for sid, d in pairs(sanitizedExtras) do
      local pd = prevExtras[sid]
      if not pd or math.abs((pd.cooldownRemain or 0) - d.cooldownRemain) > 0.6 then
        extrasChanged = true
        break
      end
    end
    if not extrasChanged then
      for sid in pairs(prevExtras) do
        if not sanitizedExtras[sid] then
          extrasChanged = true
          break
        end
      end
    end
  end
  local changed = not prev
    or prev.onCooldown ~= newOnCooldown
    or prev.hasKick ~= newHasKick
    or prev.spellID ~= numericSpellID
    or remainChanged
    or extrasChanged
  local getTime = rawget(_G, "GetTime")
  kickInfoByPlayerKey[key] = {
    hasKick = newHasKick,
    spellID = numericSpellID,
    onCooldown = newOnCooldown,
    cooldownRemain = newHasKick and numericRemain or 0,
    extras = sanitizedExtras,
    capturedAt = ToFiniteNumber(capturedAt) or now,
    receivedAt = now,
    receivedAtGetTime = type(getTime) == "function" and getTime() or nil,
  }
  return changed
end

--- Returns stored kick info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {hasKick, onCooldown, cooldownRemain, capturedAt, receivedAt, receivedAtGetTime}
function PeerState.GetPlayerKickInfo(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return kickInfoByPlayerKey[key]
end

--- Clears stored kick info for a peer (e.g. when the player leaves the group).
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return boolean true if an entry existed and was removed.
function PeerState.ClearPlayerKickInfo(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end
  local hadValue = type(kickInfoByPlayerKey[key]) == "table"
  kickInfoByPlayerKey[key] = nil
  if hadValue then
    kickInfoGeneration = kickInfoGeneration + 1
  end
  return hadValue
end

--- Counter that moves whenever stored kick entries are dropped (ClearKnownUsers,
-- ClearPlayerKickInfo). Lets the local kick poll skip rewriting an unchanged
-- own entry without missing that the entry itself was removed.
-- @return number
function PeerState.GetKickInfoGeneration()
  return kickInfoGeneration
end

--- Stores a received location (map) payload for a peer. Clears the entry when mapID is invalid.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param mapID number|nil Legacy UiMapID (wire field 2); never used for the target-dungeon marker.
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label.
-- @param instanceID number|nil Party instance ID from the "IN" suffix (rule 194).
--   The entry is cleared only when both mapID and instanceID are nil or 0.
-- @return boolean true if stored location changed; false if deduplicated or cleared unchanged.
function PeerState.SetPlayerLocInfo(name, realm, mapID, capturedAt, source, instanceID)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local _, numericMapID, normalizedCapturedAt, normalizedSource, numericInstanceID =
    NormalizeLocPayload(mapID, capturedAt, source, instanceID)
  local previous = locInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  local isAdmitted, keepsVerifiedStamp = AdmitSnapshot("loc", key, capturedAt)
  if not isAdmitted then
    return false
  end
  if not numericMapID and not numericInstanceID then
    local hadValue = type(locInfoByPlayerKey[key]) == "table"
    locInfoByPlayerKey[key] = nil
    return hadValue
  end

  if previous and previous.mapID == numericMapID and previous.instanceID == numericInstanceID then
    RefreshUnchangedEntry(previous, keepsVerifiedStamp, normalizedCapturedAt, normalizedSource, previousStamp)
    return false
  end

  local nextValue = {
    mapID = numericMapID,
    instanceID = numericInstanceID,
    capturedAt = normalizedCapturedAt,
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)
  locInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored location info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {mapID, instanceID, capturedAt, source, receivedAt, previousSyncStamp}
function PeerState.GetPlayerLocInfo(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return locInfoByPlayerKey[key]
end

--- Stores a received target-keystone payload for a peer. Clears the entry when mapID is invalid.
-- @param name string Sender name.
-- @param realm string|nil Sender realm.
-- @param mapID number|nil Target dungeon map ID; nil or 0 clears the entry.
-- @param level number|nil Target key level (nil when unknown).
-- @param capturedAt number|nil Timestamp from the payload.
-- @param source string|nil Sync source label.
-- @param levelText string|nil Verified opaque Blizzard keystone level markup.
-- @return boolean true if stored target changed; false if deduplicated or cleared unchanged.
function PeerState.SetPlayerTargetInfo(name, realm, mapID, level, capturedAt, source, levelText)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return false
  end

  local _, numericMapID, numericLevel, normalizedCapturedAt, normalizedSource, normalizedLevelText =
    NormalizeTargetPayload(mapID, level, capturedAt, source, levelText)
  local previous = targetInfoByPlayerKey[key]
  local previousStamp = GetEntrySyncStamp(previous)
  local isAdmitted, keepsVerifiedStamp = AdmitSnapshot("target", key, capturedAt)
  if not isAdmitted then
    return false
  end
  if not numericMapID then
    local hadValue = type(targetInfoByPlayerKey[key]) == "table"
    targetInfoByPlayerKey[key] = nil
    return hadValue
  end

  if
    previous
    and previous.mapID == numericMapID
    and previous.level == numericLevel
    and previous.levelText == normalizedLevelText
  then
    RefreshUnchangedEntry(previous, keepsVerifiedStamp, normalizedCapturedAt, normalizedSource, previousStamp)
    return false
  end

  local nextValue = {
    mapID = numericMapID,
    level = numericLevel,
    levelText = normalizedLevelText,
    capturedAt = normalizedCapturedAt,
    source = normalizedSource,
    receivedAt = GetSyncTimestamp(),
  }
  SetEntryPreviousSyncStamp(nextValue, previousStamp)
  targetInfoByPlayerKey[key] = nextValue
  return true
end

--- Returns stored target info for a peer, or nil if none received.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {mapID, level, levelText, capturedAt, source, receivedAt, previousSyncStamp}
function PeerState.GetPlayerTargetInfo(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  return targetInfoByPlayerKey[key]
end

--- Returns a summary of the most recently received sync bucket for a peer.
-- Picks the bucket with the highest capturedAt/receivedAt timestamp across all data types.
-- Used to compute approximate sync intervals for tooltip display.
-- @param name string Player name.
-- @param realm string|nil Realm name.
-- @return table|nil {kind, capturedAt, receivedAt, previousSyncStamp,
--   intervalSeconds, source, addonVersion, protocolVersion}
function PeerState.GetPlayerSyncSummary(name, realm)
  local key = NormalizePlayerKey(name, realm)
  if StringUtils.IsBlank(key) then
    return nil
  end
  local candidates = {
    { kind = "hello", data = helloInfoByPlayerKey[key] },
    { kind = "key", data = keyInfoByPlayerKey[key] },
    { kind = "stats", data = statsInfoByPlayerKey[key] },
    { kind = "dps", data = dpsInfoByPlayerKey[key] },
    { kind = "loc", data = locInfoByPlayerKey[key] },
    { kind = "target", data = targetInfoByPlayerKey[key] },
  }

  local best = nil
  for _, candidate in ipairs(candidates) do
    local data = candidate.data
    if type(data) == "table" then
      local capturedAt = ToFiniteNumber(data.capturedAt)
      local receivedAt = ToFiniteNumber(data.receivedAt)
      local previousSyncStamp = ToFiniteNumber(data.previousSyncStamp)
      local sortStamp = capturedAt or receivedAt
      if sortStamp then
        local summary = {
          kind = candidate.kind,
          capturedAt = capturedAt,
          receivedAt = receivedAt,
          previousSyncStamp = previousSyncStamp,
          intervalSeconds = previousSyncStamp and sortStamp >= previousSyncStamp and (sortStamp - previousSyncStamp)
            or nil,
          source = data.source,
          addonVersion = data.addonVersion,
          protocolVersion = data.protocolVersion,
          sortStamp = sortStamp,
        }
        if not best or summary.sortStamp > best.sortStamp then
          best = summary
        end
      end
    end
  end

  if best then
    best.sortStamp = nil
  end

  return best
end

--- Drops every stored peer entry and watermark; part of Sync.ClearKnownUsers.
-- Moves the kick generation so the local kick poll rewrites its own entry.
function PeerState.Reset()
  isiLiveUsersByKey = {}
  helloInfoByPlayerKey = {}
  keyInfoByPlayerKey = {}
  statsInfoByPlayerKey = {}
  dpsInfoByPlayerKey = {}
  locInfoByPlayerKey = {}
  targetInfoByPlayerKey = {}
  kickInfoByPlayerKey = {}
  runKicksCastByPlayerKey = {}
  kickInfoGeneration = kickInfoGeneration + 1
  snapshotWatermarks = {}
end
