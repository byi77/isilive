local _, addonTable = ...

addonTable = addonTable or {}

-- Player UNIT_AURA filter and the shared spell-cooldown / CD-tracker
-- coalescer, split out of logic/isiLive_event_handlers_runtime.lua. The
-- runtime lifecycle keeps the event entry points (SPELL_UPDATE_COOLDOWN,
-- SPELL_UPDATE_CHARGES, UNIT_AURA) and the raid gate; it hands the raid check
-- to the coalescer as a callback.
local CdCoalescer = {}
addonTable.EventHandlersCdCoalescer = CdCoalescer
local IsSecretField = addonTable.Validators.IsSecretField
local ReadPlainField = addonTable.Validators.ReadPlainField
local ReadPlainBoolean = addonTable.Validators.ReadPlainBoolean
local ReadPlainNumber = addonTable.Validators.ReadPlainNumber

-- Sated/Exhaustion debuff IDs that CdTracker.ScanLust matches against the
-- player's HARMFUL aura list. Mirrors LUST_SATED_IDS in game/isiLive_cd_tracker.lua;
-- kept in sync so the event-side filter knows which UNIT_AURA payloads are
-- actually load-bearing for the CD-tracker scan.
local LUST_SATED_AURA_IDS = {
  [57723] = true,
  [57724] = true,
  [80354] = true,
  [264689] = true,
  [390435] = true,
  [95809] = true,
}

-- UNIT_AURA for "player" fires many times per second in combat (DoT ticks,
-- proc refreshes, stack changes). The CD-tracker only cares about the six
-- Sated/Exhaustion IDs above. Use the unitAuraUpdateInfo payload to skip the
-- 40-slot HARMFUL pcall scan when no Sated-relevant change is in this event.
-- Aura removals and instance updates do not reliably include spellId, only
-- aura instance IDs, so those payloads must scan to detect natural
-- Sated/Exhaustion expiry.
-- Conservative fallback: scan whenever the payload is missing or signals a
-- full update, so /reload and zone transitions still resync.
--
-- Secret-Value note: in WoW 12.0+ M+ / boss restriction zones, aura fields
-- on the payload can be Secret Values. `type(secret)` lies and returns
-- "number", but using the value as a table key raises "attempted to index a
-- table that cannot be indexed with secret keys". Since 12.1 the payload's own
-- `isFullUpdate` flag is masked as well, and comparing it raises. Every field
-- read therefore goes through Validators.ReadPlain*, which rejects masked
-- values before anything is compared, indexed or calculated with.
local UNIT_AURA_DELTA_KEYS = {
  "addedAuras",
  "updatedAuraInstanceIDs",
  "removedAuraInstanceIDs",
  "removedAuras",
}

-- Delta lists whose mere presence forces a scan: removals and instance updates
-- do not reliably carry a spellId, so Sated/Exhaustion expiry is only visible
-- by re-scanning.
local UNIT_AURA_SCAN_TRIGGER_KEYS = {
  "removedAuraInstanceIDs",
  "updatedAuraInstanceIDs",
  "removedAuras",
}

local function ReadAuraDeltaList(updateInfo, key)
  local list = ReadPlainField(updateInfo, key)
  if type(list) ~= "table" then
    return nil
  end
  return list
end

local function HasAnyAuraDeltaList(updateInfo)
  for index = 1, #UNIT_AURA_DELTA_KEYS do
    if ReadAuraDeltaList(updateInfo, UNIT_AURA_DELTA_KEYS[index]) then
      return true
    end
  end
  return false
end

local function UnitAuraUpdateRequiresCdScan(updateInfo)
  if type(updateInfo) ~= "table" then
    return true
  end
  local isFullUpdate = ReadPlainBoolean(updateInfo, "isFullUpdate")
  if isFullUpdate == true then
    return true
  end
  -- ReadAuraDeltaList already rejected masked values, so `#` and the numeric
  -- index below only ever touch a plain table -- no pcall needed on a path that
  -- runs many times per second.
  for index = 1, #UNIT_AURA_SCAN_TRIGGER_KEYS do
    local list = ReadAuraDeltaList(updateInfo, UNIT_AURA_SCAN_TRIGGER_KEYS[index])
    if list and #list > 0 then
      return true
    end
  end
  local added = ReadAuraDeltaList(updateInfo, "addedAuras")
  if added then
    for i = 1, #added do
      local spellID = ReadPlainNumber(ReadPlainField(added, i), "spellId")
      if spellID and LUST_SATED_AURA_IDS[spellID] then
        return true
      end
    end
  end
  -- 12.1 masks `isFullUpdate` inside restricted instances: the flag is present
  -- but unreadable. A payload that then carries no delta list at all has the
  -- shape of a full update, so resync rather than dropping the /reload +
  -- zone-transition hydration. An absent flag keeps the pre-12.1 answer.
  return IsSecretField(updateInfo, "isFullUpdate") and not HasAnyAuraDeltaList(updateInfo)
end

-- SPELL_UPDATE_COOLDOWN and SPELL_UPDATE_CHARGES fire many times per second
-- during combat (every GCD start/end, every charge regen, every item CD).
-- Coalesce bursts into one trailing handler call ~100ms later so the
-- kick-tracker cache and teleport-button refresh do not run 20+ times/sec
-- for state that only changes at most once per cast. Each call to
-- BuildSpellCooldownCoalescer returns a fresh closure set so per-controller
-- state stays isolated (one controller per session in production, one per
-- test in the harness).
--
-- Sated-relevant player UNIT_AURA payloads share the CD-tracker bucket with
-- SPELL_UPDATE_CHARGES: in combat nearly every player aura payload carries an
-- updated or removed instance ID, so an uncoalesced pass ran the 40-slot
-- HARMFUL scan, the row refresh and -- while the main UI is hidden in a key --
-- a full roster pre-render for every proc and stack change. One trailing pass
-- per window serves both triggers; the Bloodlust start sound flag and the
-- Bloodlust button-warning refresh ride along whenever an aura event
-- contributed to the window.
local SPELL_COOLDOWN_COALESCE_SECONDS = 0.1
local function BuildSpellCooldownCoalescer(ctx, isRaidActive)
  local pendingCooldown = false
  local pendingCdPass = false
  local pendingAuraScan = false

  local function DispatchCooldown()
    pendingCooldown = false
    if isRaidActive() then
      return
    end
    ctx.handleKickTrackerEvent("SPELL_UPDATE_COOLDOWN")
    ctx.updateMPlusTeleportButton()
  end

  local function DispatchCdPass()
    pendingCdPass = false
    local auraScan = pendingAuraScan
    pendingAuraScan = false
    if isRaidActive() then
      return
    end
    if auraScan then
      ctx.handleBloodlustButtonWarningEvent("UNIT_AURA", "player")
      ctx.updateCdTracker({ playLustSoundOnStart = true })
      return
    end
    ctx.updateCdTracker()
  end

  local function Schedule(dispatch)
    local timer = rawget(_G, "C_Timer")
    local after = type(timer) == "table" and timer.After or nil
    if type(after) == "function" then
      after(SPELL_COOLDOWN_COALESCE_SECONDS, dispatch)
      return true
    end
    return false
  end

  local function HandleCooldown(_self)
    if isRaidActive() or pendingCooldown then
      return
    end
    pendingCooldown = true
    if not Schedule(DispatchCooldown) then
      DispatchCooldown()
    end
  end

  local function ScheduleCdPass()
    if pendingCdPass then
      return
    end
    pendingCdPass = true
    if not Schedule(DispatchCdPass) then
      DispatchCdPass()
    end
  end

  local function HandleCharges(_self)
    if isRaidActive() then
      return
    end
    ScheduleCdPass()
  end

  local function HandlePlayerAuraCdScan()
    if isRaidActive() then
      return
    end
    pendingAuraScan = true
    ScheduleCdPass()
  end

  return HandleCooldown, HandleCharges, HandlePlayerAuraCdScan
end

CdCoalescer.UnitAuraUpdateRequiresCdScan = UnitAuraUpdateRequiresCdScan
CdCoalescer.BuildSpellCooldownCoalescer = BuildSpellCooldownCoalescer
