local _, addonTable = ...

addonTable = addonTable or {}

-- Defensive / external cooldown store (rule 267, vorhaben V1 stage 1).
--
-- The one place that holds defensive state per player:
--   * own   - the local player's state, read from the live client by
--             game/isiLive_defensive_tracker.lua (SetOwn); a `hidden` entry
--             (masked cooldown) has a state but no countdown
--   * sync  - an isiLive peer's state from its DEF sync message (SetPeer)
-- Nothing else feeds it: no estimate, no default, no carried-over value. A
-- player without a valid record reads as source "none".
--
-- Countdown: every record keeps the remain seconds as of its timestamp
-- (receivedAt for peers, the read time for the own state); GetForPlayer
-- counts them down locally from there. While frozen (own addon chat locked
-- down, rule 267) peer records do not count down: they show the state as of
-- the freeze, with their age. Thaw resumes the clock; a peer record older
-- than STALE_SECONDS then reads as "none" until the peer sends again.
--
-- Stale expiry: outside a freeze a record without a fresh message or own read
-- for STALE_SECONDS (60, four missed 15 s heartbeats) is dropped (fail-closed).
-- In a raid the store answers "none" for everyone (rule 11).
--
-- Session-wide singleton like the Sync facade: Sync.ClearKnownUsers clears
-- the peers, the factory clears everything when the feature or its profile
-- turns off.
local DefensiveStore = {}
addonTable.DefensiveStore = DefensiveStore

local IsFiniteNumber = addonTable.Validators.IsFiniteNumber

local STALE_SECONDS = 60
local MAX_REMAIN_SECONDS = 3600
local MAX_CHARGES = 9
local VALID_STATES = { ready = true, cd = true, active = true }

DefensiveStore.STALE_SECONDS = STALE_SECONDS
DefensiveStore.MAX_REMAIN_SECONDS = MAX_REMAIN_SECONDS

local own = nil -- { entries, at }
local ownKey = nil
local peers = {} -- [playerKey] = { entries, receivedAt }
local frozenAt = nil
local listeners = {}
local peerGate = nil

local function Manifest()
  local manifest = addonTable.DefensiveManifest
  return type(manifest) == "table" and type(manifest.spells) == "table" and manifest or nil
end

local function KindRank(kind)
  local manifest = Manifest()
  local order = manifest and manifest.kindOrder or nil
  return type(order) == "table" and order[kind] or 99
end

local function SortEntries(entries)
  table.sort(entries, function(a, b)
    local rankA, rankB = KindRank(a.kind), KindRank(b.kind)
    if rankA ~= rankB then
      return rankA < rankB
    end
    return a.spellID < b.spellID
  end)
  return entries
end

-- Copies the valid entries of `entries` (manifest spell, known state, remain
-- 0..3600, optional charges 0..9) with the manifest kind. Returns nil when any
-- entry is invalid: a half-valid list is rejected as a whole.
local function NormalizeEntries(entries, allowHidden)
  local manifest = Manifest()
  if not manifest or type(entries) ~= "table" then
    return nil
  end
  local out, seen = {}, {}
  for _, entry in ipairs(entries) do
    if type(entry) ~= "table" then
      return nil
    end
    local spellID, state, remain, charges = entry.spellID, entry.state, entry.remain, entry.charges
    local record = IsFiniteNumber(spellID) and manifest.spells[spellID] or nil
    if not record or seen[spellID] or not VALID_STATES[state] then
      return nil
    end
    if not IsFiniteNumber(remain) or remain < 0 or remain > MAX_REMAIN_SECONDS then
      return nil
    end
    if charges ~= nil and (not IsFiniteNumber(charges) or charges < 0 or charges > MAX_CHARGES or charges % 1 ~= 0) then
      return nil
    end
    if entry.hidden == true and not allowHidden then
      return nil
    end
    seen[spellID] = true
    out[#out + 1] = {
      spellID = spellID,
      kind = record.kind,
      state = state,
      remain = remain,
      charges = charges,
      hidden = entry.hidden == true or nil,
    }
  end
  return SortEntries(out)
end

local function SameEntries(a, b)
  if #a ~= #b then
    return false
  end
  for index, left in ipairs(a) do
    local right = b[index]
    if
      left.spellID ~= right.spellID
      or left.state ~= right.state
      or left.charges ~= right.charges
      or left.hidden ~= right.hidden
      or math.abs(left.remain - right.remain) > 0.5
    then
      return false
    end
  end
  return true
end

local function Notify(reason, playerKey)
  for _, callback in ipairs(listeners) do
    pcall(callback, reason, playerKey)
  end
end

local function IsRaid()
  local runtimeMode = addonTable.RuntimeMode
  if type(runtimeMode) ~= "table" or type(runtimeMode.IsRaidContext) ~= "function" then
    return false
  end
  local ok, isRaid = pcall(runtimeMode.IsRaidContext)
  return ok and isRaid == true
end

-- One entry `elapsed` seconds after its timestamp; a cooldown that ran out
-- reads as ready.
local function EntryAt(entry, elapsed)
  if entry.hidden then
    -- No number to count down: the state holds until the next client read.
    return { spellID = entry.spellID, kind = entry.kind, state = entry.state, remain = 0, hidden = true }
  end
  local remain = entry.remain - elapsed
  local state = entry.state
  if remain <= 0 then
    remain = 0
    if state ~= "ready" then
      state = "ready"
    end
  end
  return { spellID = entry.spellID, kind = entry.kind, state = state, remain = remain, charges = entry.charges }
end

local function BuildView(record, source, reference, now, frozen)
  local elapsed = math.max(0, reference - record.at)
  local entries = {}
  for index, entry in ipairs(record.entries) do
    entries[index] = EntryAt(entry, elapsed)
  end
  return {
    source = source,
    frozenAt = frozen and frozenAt or nil,
    ageSeconds = math.max(0, now - record.at),
    entries = entries,
  }
end

local function NoneView()
  return { source = "none", frozenAt = nil, ageSeconds = nil, entries = {} }
end

--- Sets the local player's key (Sync.NormalizePlayerKey form); GetForPlayer
-- answers it from the own state.
function DefensiveStore.SetOwnKey(playerKey)
  ownKey = type(playerKey) == "string" and playerKey ~= "" and playerKey or nil
end

--- The local player's key, or nil before the factory set it.
function DefensiveStore.GetOwnKey()
  return ownKey
end

--- Stores the own state read from the live client at `now`. Invalid input
-- clears the own state (fail-closed). Returns true when the stored state
-- changed.
function DefensiveStore.SetOwn(entries, now)
  local normalized = IsFiniteNumber(now) and NormalizeEntries(entries, true) or nil
  if not normalized then
    if own == nil then
      return false
    end
    own = nil
    Notify("own", ownKey)
    return true
  end
  local changed = own == nil or not SameEntries(BuildView(own, "own", now, now, false).entries, normalized)
  own = { entries = normalized, at = now }
  if changed then
    Notify("own", ownKey)
  end
  return changed
end

--- Registers the gate that decides whether peer records are accepted (the
-- factory wires the settings, profile and raid checks). Without a gate no
-- peer record is accepted.
function DefensiveStore.SetPeerGate(gate)
  peerGate = type(gate) == "function" and gate or nil
end

--- Stores a peer's synced state (empty list = the peer tracks nothing).
-- Returns true when the record was accepted.
function DefensiveStore.SetPeer(playerKey, entries, receivedAt)
  if type(playerKey) ~= "string" or playerKey == "" or not IsFiniteNumber(receivedAt) then
    return false
  end
  if peerGate == nil then
    return false
  end
  local okGate, allowed = pcall(peerGate)
  if not okGate or allowed ~= true then
    return false
  end
  local normalized = NormalizeEntries(entries)
  if not normalized then
    return false
  end
  peers[playerKey] = { entries = normalized, at = receivedAt }
  Notify("peer", playerKey)
  return true
end

--- Freezes the peer countdowns at `now` (own addon chat locked down).
function DefensiveStore.Freeze(now)
  if frozenAt ~= nil or not IsFiniteNumber(now) then
    return false
  end
  frozenAt = now
  Notify("freeze", nil)
  return true
end

--- Resumes the peer countdowns; records older than STALE_SECONDS expire on
-- the next read.
function DefensiveStore.Thaw()
  if frozenAt == nil then
    return false
  end
  frozenAt = nil
  Notify("thaw", nil)
  return true
end

function DefensiveStore.IsFrozen()
  return frozenAt ~= nil
end

--- Drops every peer record (group change, Sync.ClearKnownUsers).
function DefensiveStore.ClearPeers()
  if next(peers) == nil then
    return false
  end
  peers = {}
  Notify("clear", nil)
  return true
end

--- Drops everything: own state, peers and the freeze.
function DefensiveStore.Clear()
  local hadData = own ~= nil or next(peers) ~= nil or frozenAt ~= nil
  own = nil
  peers = {}
  frozenAt = nil
  if hadData then
    Notify("clear", nil)
  end
  return hadData
end

local function IsStale(record, now)
  return now - record.at > STALE_SECONDS
end

--- Removes stale records (outside a freeze). Returns the number removed.
function DefensiveStore.Prune(now)
  if not IsFiniteNumber(now) then
    return 0
  end
  local removed = 0
  if own and IsStale(own, now) then
    own = nil
    removed = removed + 1
    Notify("own", ownKey)
  end
  if frozenAt ~= nil then
    return removed
  end
  for playerKey, record in pairs(peers) do
    if IsStale(record, now) then
      peers[playerKey] = nil
      removed = removed + 1
      Notify("expired", playerKey)
    end
  end
  return removed
end

--- The defensive state of one player at `now`:
-- { source = "own"|"sync"|"none", frozenAt = number|nil, ageSeconds = number|nil,
--   entries = { { spellID, kind, state = "ready"|"cd"|"active", remain, charges } } }
-- Entries are sorted external > raid > personal, then by spell ID.
function DefensiveStore.GetForPlayer(playerKey, now)
  if type(playerKey) ~= "string" or not IsFiniteNumber(now) or IsRaid() then
    return NoneView()
  end
  if ownKey ~= nil and playerKey == ownKey then
    if own == nil or IsStale(own, now) then
      return NoneView()
    end
    return BuildView(own, "own", now, now, false)
  end
  local record = peers[playerKey]
  if record == nil then
    return NoneView()
  end
  if frozenAt ~= nil then
    if frozenAt - record.at > STALE_SECONDS then
      return NoneView()
    end
    return BuildView(record, "sync", math.max(frozenAt, record.at), now, true)
  end
  if IsStale(record, now) then
    return NoneView()
  end
  return BuildView(record, "sync", now, now, false)
end

--- Registers a change listener: callback(reason, playerKey|nil) with reason
-- "own", "peer", "expired", "freeze", "thaw" or "clear". Returns a function
-- that removes the listener.
function DefensiveStore.OnChanged(callback)
  if type(callback) ~= "function" then
    return function() end
  end
  listeners[#listeners + 1] = callback
  return function()
    for index, registered in ipairs(listeners) do
      if registered == callback then
        table.remove(listeners, index)
        return
      end
    end
  end
end
