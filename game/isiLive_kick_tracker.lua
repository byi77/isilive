local _, addonTable = ...

addonTable = addonTable or {}

local KickTracker = {}
addonTable.KickTracker = KickTracker
local IsSecretValue = addonTable.Validators.IsSecretValue
local MEANINGFUL_KICK_COOLDOWN_MIN_SECONDS = 1.5
-- Interrupt data lives in data/isiLive_interrupts.lua (package 5 J).
local InterruptManifest = addonTable.InterruptManifest
local NO_INTERRUPT_SPEC_IDS = InterruptManifest.noInterruptSpecs
local SPEC_DATA = InterruptManifest.specs
local CLASS_INTERRUPT_LIST = InterruptManifest.classAlternatives
local EXTRA_KICK_CD = InterruptManifest.extraCooldowns

-- Missed-kick ("Kick ins Leere") evaluation windows, rule 236. After the own
-- interrupt cast a hostile interrupt must be observed within this many
-- seconds, otherwise the kick counts as missed.
-- CALIBRATE IN-GAME: raise a value if real landed kicks raise the alert; lower
-- it if missed kicks slip through because an unrelated interrupt happened to
-- land in the window.
-- Default calibrated on the probe logs of 2026-11-12 to 2026-11-14 (Kick 1766,
-- ~160 kicks): real hits land in the same frame (0 ms), twice one frame later
-- (13 and 16 ms); a teammate's interrupt 39 ms after an own kick the damage
-- meter did not count was the only false "landed". 0.25 s took such teammate
-- interrupts as own hits. Pet kicks and Solar Beam have no data yet.
local MISSED_KICK_WINDOW_DEFAULT_SECONDS = 0.03
-- Pet kicks (Warlock Spell Lock / Axe Toss) travel through the pet first.
local MISSED_KICK_WINDOW_PET_SECONDS = 0.6
-- Per-spell overrides for slow kicks. CALIBRATE IN-GAME.
local MISSED_KICK_WINDOW_BY_SPELL = {
  [78675] = 0.6, -- Solar Beam: ground effect, the interrupt applies when the beam lands
}
-- An interrupt observed BEFORE the own cast belongs to a teammate who was
-- faster: the own kick came late and counts as missed (user decision
-- 2026-11-08; combat log of a +17: 4 of 37 own kicks came 32-231 ms after a
-- teammate's interrupt). GetTime() is constant within one frame, so an
-- interrupt with the same timestamp as the own cast arrived in the same frame;
-- the event order inside a frame is not documented, so that tie counts as
-- landed. Zero tolerance: any earlier frame is a miss.
local MISSED_KICK_PRE_CAST_TOLERANCE_SECONDS = 0
-- Interrupt casts that still do something without a target cast (damage,
-- stun), so an "empty" use is not a wasted kick. VERIFY IN-GAME.
local MISSED_KICK_EXCLUDED_SPELLS = {
  [31935] = true, -- Avenger's Shield (Prot Paladin interrupt talent): damage and silence
  [119914] = true, -- Axe Toss (player-facing ID): stun
  [89766] = true, -- Axe Toss (Felguard pet cast ID): stun
}

local function ResolveMissedKickWindow(spellID, castUnit)
  local override = MISSED_KICK_WINDOW_BY_SPELL[spellID]
  if type(override) == "number" then
    return override
  end
  if castUnit == "pet" then
    return MISSED_KICK_WINDOW_PET_SECONDS
  end
  return MISSED_KICK_WINDOW_DEFAULT_SECONDS
end

-- Talent spell ID → { affects = interruptSpellID, reduction = seconds | pctReduction = % }
local CD_REDUCTION_DEFS = {
  [382297] = { affects = 2139, reduction = 5 }, -- [DE: Geistesgegenwärtig] (Mage: Counterspell 25→20)
  [388039] = { affects = 147362, reduction = 2 }, -- Lone Survivor      (Hunter:  Counter Shot)
  [412713] = { affects = 351338, pctReduction = 10 }, -- Interwoven Threads (Evoker:  Quell)
  [391271] = { affects = 6552, pctReduction = 10 }, -- Seasoned Soldier   (Warrior: Pummel)
}

local function ResolveSpecData()
  local GetSpecialization_ref = rawget(_G, "GetSpecialization")
  local GetSpecializationInfo_ref = rawget(_G, "GetSpecializationInfo")
  if type(GetSpecialization_ref) ~= "function" or type(GetSpecializationInfo_ref) ~= "function" then
    return {
      availabilityResolved = false,
      hasKick = false,
    }
  end
  local okIndex, specIndex = pcall(GetSpecialization_ref)
  if not okIndex or IsSecretValue(specIndex) or type(specIndex) ~= "number" or specIndex <= 0 then
    return {
      availabilityResolved = false,
      hasKick = false,
    }
  end
  local ok, specID = pcall(GetSpecializationInfo_ref, specIndex)
  if not ok or IsSecretValue(specID) or type(specID) ~= "number" then
    return {
      availabilityResolved = false,
      hasKick = false,
    }
  end
  if NO_INTERRUPT_SPEC_IDS[specID] == true then
    return {
      availabilityResolved = true,
      hasKick = false,
      castUnit = "player",
      requireAvailability = false,
      spells = {},
    }
  end
  local specData = SPEC_DATA[specID]
  if type(specData) ~= "table" then
    return {
      availabilityResolved = false,
      hasKick = false,
    }
  end
  if type(specData.spellID) == "number" then
    return {
      availabilityResolved = true,
      hasKick = true,
      castUnit = "player",
      requireAvailability = false,
      spells = {
        { spellID = specData.spellID, cd = specData.cd },
      },
    }
  end
  if type(specData.spells) ~= "table" then
    return {
      availabilityResolved = false,
      hasKick = false,
    }
  end
  return {
    availabilityResolved = true,
    hasKick = true,
    castUnit = specData.castUnit == "pet" and "pet" or "player",
    requireAvailability = specData.requireAvailability == true,
    spells = specData.spells,
  }
end

local function IndexField(info, key)
  return info[key]
end

local function ReadCooldownField(info, key)
  if type(info) ~= "table" then
    return nil, false
  end

  local ok, value = pcall(IndexField, info, key)
  if not ok then
    return nil, false
  end

  if IsSecretValue(value) then
    return nil, false
  end

  if value == nil then
    return nil, false
  end
  return value, true
end

local function ResolveAvailabilityState(spellID)
  if type(spellID) ~= "number" then
    return "unresolved"
  end

  local resolved = false

  local GetSpellBaseCooldown_ref = rawget(_G, "GetSpellBaseCooldown")
  if type(GetSpellBaseCooldown_ref) == "function" then
    local ok, ms = pcall(GetSpellBaseCooldown_ref, spellID)
    if ok then
      resolved = true
      if tonumber(ms) and tonumber(ms) > 0 then
        return "available"
      end
    end
  end

  local C_Spell_ref = rawget(_G, "C_Spell")
  if type(C_Spell_ref) == "table" and type(C_Spell_ref.GetSpellCooldown) == "function" then
    local ok, info = pcall(C_Spell_ref.GetSpellCooldown, spellID)
    if ok then
      resolved = true
      if type(info) == "table" then
        return "available"
      end
    end
  end

  if resolved then
    return "unavailable"
  end

  return "unresolved"
end

local function GetSpellDataByID(specData, spellID)
  if type(specData) ~= "table" or type(specData.spells) ~= "table" then
    return nil
  end
  for _, spellData in ipairs(specData.spells) do
    if type(spellData) == "table" and spellData.spellID == spellID then
      return spellData
    end
    if type(spellData) == "table" and type(spellData.castSpellIDs) == "table" then
      for _, castSpellID in ipairs(spellData.castSpellIDs) do
        if castSpellID == spellID then
          return spellData
        end
      end
    end
  end
  return nil
end

local function ResolveActiveSpellData(specData)
  if type(specData) ~= "table" or specData.availabilityResolved ~= true then
    return {
      availabilityResolved = false,
      hasKick = false,
      castUnit = "player",
      spellData = nil,
    }
  end

  local castUnit = specData.castUnit == "pet" and "pet" or "player"
  if specData.hasKick ~= true then
    return {
      availabilityResolved = true,
      hasKick = false,
      castUnit = castUnit,
      spellData = nil,
    }
  end

  if castUnit == "pet" then
    local UnitExists_ref = rawget(_G, "UnitExists")
    if type(UnitExists_ref) ~= "function" then
      return {
        availabilityResolved = false,
        hasKick = false,
        castUnit = castUnit,
        spellData = nil,
      }
    end
    local ok, exists = pcall(UnitExists_ref, "pet")
    if not ok or IsSecretValue(exists) then
      return {
        availabilityResolved = false,
        hasKick = false,
        castUnit = castUnit,
        spellData = nil,
      }
    end
    if exists ~= true then
      return {
        availabilityResolved = true,
        hasKick = false,
        castUnit = castUnit,
        spellData = nil,
      }
    end
  end

  if specData.requireAvailability ~= true then
    return {
      availabilityResolved = true,
      hasKick = true,
      castUnit = castUnit,
      spellData = specData.spells[1],
    }
  end

  local sawUnresolved = false
  for _, spellData in ipairs(specData.spells) do
    if type(spellData) == "table" then
      local availabilityState = ResolveAvailabilityState(spellData.spellID)
      if availabilityState == "available" then
        return {
          availabilityResolved = true,
          hasKick = true,
          castUnit = castUnit,
          spellData = spellData,
        }
      end
      if availabilityState == "unresolved" then
        sawUnresolved = true
      end
    end
  end

  if sawUnresolved then
    return {
      availabilityResolved = false,
      hasKick = false,
      castUnit = castUnit,
      spellData = nil,
    }
  end

  return {
    availabilityResolved = true,
    hasKick = false,
    castUnit = castUnit,
    spellData = nil,
  }
end

local function ReadExactCooldownStateForSpell(spellID)
  if type(spellID) ~= "number" then
    return nil
  end

  local C_Spell_ref = rawget(_G, "C_Spell")
  if type(C_Spell_ref) ~= "table" or type(C_Spell_ref.GetSpellCooldown) ~= "function" then
    return nil
  end

  local ok, info = pcall(C_Spell_ref.GetSpellCooldown, spellID)
  if not ok or type(info) ~= "table" then
    return nil
  end

  local startRaw, hasStart = ReadCooldownField(info, "startTime")
  local durationRaw, hasDuration = ReadCooldownField(info, "duration")
  local enabledRaw, hasEnabled = ReadCooldownField(info, "isEnabled")
  if not hasStart or not hasDuration or not hasEnabled then
    return nil
  end

  local start = tonumber(startRaw)
  local duration = tonumber(durationRaw)
  if start == nil or duration == nil then
    return nil
  end

  local enabled
  if enabledRaw == true or enabledRaw == false then
    enabled = enabledRaw
  elseif type(enabledRaw) == "number" then
    enabled = enabledRaw ~= 0
  else
    return nil
  end

  if enabled == false or start <= 0 or duration <= MEANINGFUL_KICK_COOLDOWN_MIN_SECONDS then
    return {
      active = false,
      endTime = 0,
      cooldownDuration = duration,
    }
  end

  return {
    active = true,
    endTime = start + duration,
    cooldownDuration = duration,
  }
end

-- Read actual cooldown duration via C_Spell.GetSpellCooldown.
-- Safe to call from C_Timer.After callbacks (untainted context).

-- Pure helpers (no controller state) extracted from CreateController.

local function IsExtraKickSpellForClass(class, primarySpellID, spellID)
  if not class then
    return false
  end
  local list = CLASS_INTERRUPT_LIST[class]
  if type(list) ~= "table" then
    return false
  end
  if spellID == primarySpellID then
    return false -- this is the primary, not an extra
  end
  for _, candidate in ipairs(list) do
    if candidate == spellID then
      return true
    end
  end
  return false
end

local function LookupExtraKickCd(spellID)
  local cd = EXTRA_KICK_CD[spellID]
  if cd and cd > 0 then
    return cd
  end
  -- Fallback: this spell is some other spec's primary in our SPEC_DATA.
  -- E.g. for Demo Warlock with Felhunter, Spell Lock (19647) is the primary
  -- of Aff/Destro -- we look up its CD there to avoid hardcoding twice.
  for _, spec in pairs(SPEC_DATA) do
    if type(spec) == "table" then
      if type(spec.spellID) == "number" and spec.spellID == spellID and type(spec.cd) == "number" then
        return spec.cd
      end
      if type(spec.spells) == "table" then
        for _, s in ipairs(spec.spells) do
          if type(s) == "table" and s.spellID == spellID and type(s.cd) == "number" then
            return s.cd
          end
        end
      end
    end
  end
  return nil
end

local function ApplyTalentCdReduction(base, talent)
  if not base or base <= 0 or not talent then
    return base
  end
  local newCd
  if talent.pctReduction then
    newCd = math.floor(base * (1 - talent.pctReduction / 100) + 0.5)
  else
    newCd = base - talent.reduction
  end
  return math.max(1, newCd)
end

-- Iterate active class-talent nodes and call visit(definitionSpellID) for each.
-- Returns true if iteration ran, false on missing API surface.
local function ForEachActiveTalentDefinition(visit)
  local C_ClassTalents_ref = rawget(_G, "C_ClassTalents")
  if type(C_ClassTalents_ref) ~= "table" then
    return false
  end
  local ok0, cid = pcall(C_ClassTalents_ref.GetActiveConfigID)
  if not ok0 or not cid then
    return false
  end
  local C_Traits_ref = rawget(_G, "C_Traits")
  if type(C_Traits_ref) ~= "table" then
    return false
  end
  local ok1, cfg = pcall(C_Traits_ref.GetConfigInfo, cid)
  if not ok1 or not cfg or not cfg.treeIDs or #cfg.treeIDs == 0 then
    return false
  end
  for _, treeID in ipairs(cfg.treeIDs) do
    local ok2, nodes = pcall(C_Traits_ref.GetTreeNodes, treeID)
    if ok2 and type(nodes) == "table" then
      for _, nodeID in ipairs(nodes) do
        local ok3, node = pcall(C_Traits_ref.GetNodeInfo, cid, nodeID)
        if ok3 and node and node.activeEntry and node.activeRank and node.activeRank > 0 then
          local ok4, entry = pcall(C_Traits_ref.GetEntryInfo, cid, node.activeEntry.entryID)
          if ok4 and entry and entry.definitionID then
            local ok5, def = pcall(C_Traits_ref.GetDefinitionInfo, entry.definitionID)
            if ok5 and def and def.spellID then
              visit(def.spellID)
            end
          end
        end
      end
    end
  end
  return true
end

local function CollectActiveExtras(extras, now)
  local out = nil
  for spellID, data in pairs(extras) do
    if type(data) == "table" and type(data.cdEnd) == "number" and data.cdEnd > now then
      out = out or {}
      out[spellID] = {
        onCooldown = true,
        cooldownRemain = math.max(0, data.cdEnd - now),
        cd = data.cd,
      }
    end
  end
  return out
end

-- Missed-kick state (rule 236): the last own kick waiting for its verdict and
-- the time of the last observed hostile interrupt. Only timestamps are kept;
-- who interrupted is never read or compared.
--
-- It also counts the own interrupt casts of the running key (rule 238): every
-- armed kick is one attempt. Kicks that also work without a cast to stop
-- (MISSED_KICK_EXCLUDED_SPELLS: Avenger's Shield, Axe Toss) are mostly cast for
-- their damage or stun and are not counted. The count is nil until the key
-- start resets it, so a reload mid-key reports "unknown" instead of a short
-- count; a masked cast of the watched unit could have been a kick and makes
-- the count unknown as well.
-- The missed kicks of the run (rule 240) count every "missed" verdict that
-- ResolveMissedKick hands out while the run count is active. A kick whose
-- verdict can no longer come (replaced while it waited, or no timer to wait
-- with) makes the missed count unknown for the run; it shares the masked-cast
-- unknown state with the attempts.
local function CreateMissedKickState(getTime)
  local pending = nil
  local seq = 0
  local lastHostileInterruptAt = nil
  local runAttempts = nil
  local runAttemptsUnknown = false
  local runMissed = nil
  local runMissedUnknown = false
  local state = { api = {} }

  -- A pending kick still waits for its verdict; dropping it loses one
  -- verdict of the run.
  local function DropPending()
    if pending and runMissed then
      runMissedUnknown = true
    end
    pending = nil
  end

  function state.Arm(castSpellID, trackedSpellID, castUnit)
    if MISSED_KICK_EXCLUDED_SPELLS[castSpellID] or MISSED_KICK_EXCLUDED_SPELLS[trackedSpellID] then
      DropPending()
      return
    end
    if runAttempts then
      runAttempts = runAttempts + 1
    end
    DropPending()
    seq = seq + 1
    pending = {
      seq = seq,
      spellID = trackedSpellID,
      castAt = getTime(),
      window = ResolveMissedKickWindow(trackedSpellID, castUnit),
    }
  end

  -- The kick armed by the last OnCast that still waits for its verdict, as
  -- { seq, spellID, window } -- or nil.
  function state.api.GetPendingMissedKick()
    if not pending then
      return nil
    end
    return { seq = pending.seq, spellID = pending.spellID, window = pending.window }
  end

  -- Drops a pending kick without a verdict (neither the alert nor the run
  -- count wants one). It does not touch the run's missed count.
  function state.api.CancelMissedKick()
    pending = nil
  end

  --- True while a run count is active and still known (from the key start on,
  -- rule 238/240), so the factory computes a verdict for every kick.
  -- @return boolean
  function state.api.IsRunKickCounting()
    return runMissed ~= nil and not runAttemptsUnknown and not runMissedUnknown
  end

  --- Marks the run's missed count unknown (a verdict that cannot be computed).
  function state.api.MarkRunMissedUnknown()
    if runMissed then
      runMissedUnknown = true
    end
  end

  -- Records that some hostile cast was interrupted now. Only the moment
  -- counts: by whom is never asked (interruptedBy is secret in keys).
  function state.api.OnHostileInterrupt()
    lastHostileInterruptAt = getTime()
  end

  -- Verdict for the pending kick `kickSeq`: "landed" when the last hostile
  -- interrupt fell into [castAt - tolerance, castAt + window] (tolerance 0:
  -- the same frame as the own cast or later), otherwise "missed". A teammate
  -- kick in the same frame or inside the window therefore also counts as
  -- landed; one in an earlier frame made the own kick late, a miss. Returns
  -- nil for a stale or unknown seq (a newer kick replaced it) and consumes the
  -- pending kick otherwise.
  function state.api.ResolveMissedKick(kickSeq)
    local current = pending
    if not current or current.seq ~= kickSeq then
      return nil
    end
    pending = nil
    local at = lastHostileInterruptAt
    if
      type(at) == "number"
      and at >= current.castAt - MISSED_KICK_PRE_CAST_TOLERANCE_SECONDS
      and at <= current.castAt + current.window
    then
      return "landed"
    end
    if runMissed then
      runMissed = runMissed + 1
    end
    return "missed"
  end

  -- A cast whose spell ID is masked; isWatchedUnit when it came from the unit
  -- whose kicks are tracked. Returns false: OnCast never treats it as a kick.
  function state.OnMaskedCast(isWatchedUnit)
    if isWatchedUnit then
      runAttemptsUnknown = true
    end
    return false
  end

  --- Starts a new run count (CHALLENGE_MODE_START).
  function state.api.ResetRunKickAttempts()
    runAttempts = 0
    runAttemptsUnknown = false
    runMissed = 0
    runMissedUnknown = false
  end

  --- Own interrupt casts since the last key start, or nil when unknown.
  -- @return number|nil
  function state.api.GetRunKickAttempts()
    if runAttemptsUnknown then
      return nil
    end
    return runAttempts
  end

  --- Own missed kicks since the last key start (rule 240), or nil when unknown.
  -- @return number|nil
  function state.api.GetRunKickMissed()
    if runAttemptsUnknown or runMissedUnknown then
      return nil
    end
    return runMissed
  end

  -- Exposes GetPendingMissedKick, CancelMissedKick, OnHostileInterrupt,
  -- ResolveMissedKick and the run-attempt and run-missed accessors on the
  -- kick controller and returns it.
  function state.AttachTo(controller)
    for name, fn in pairs(state.api) do
      controller[name] = fn
    end
    return controller
  end

  return state
end

--- Every interrupt spell ID the tracker knows (spec primaries, class
-- alternatives and extras), sorted and unique. Read by the self test data
-- check (rule 261) so a spell a patch removed shows up on patch day.
function KickTracker.GetInterruptSpellIDs()
  local seen, ids = {}, {}
  local function Add(spellID)
    if type(spellID) == "number" and not seen[spellID] then
      seen[spellID] = true
      ids[#ids + 1] = spellID
    end
  end
  for _, specData in pairs(SPEC_DATA) do
    Add(type(specData) == "table" and specData.spellID or nil)
  end
  for _, spellIDs in pairs(CLASS_INTERRUPT_LIST) do
    for _, spellID in ipairs(spellIDs) do
      Add(spellID)
    end
  end
  for spellID in pairs(EXTRA_KICK_CD) do
    Add(spellID)
  end
  table.sort(ids)
  return ids
end

function KickTracker.CreateController(opts)
  opts = opts or {}
  local getTime = type(opts.getTime) == "function" and opts.getTime or GetTime
  local onCooldownChanged = type(opts.onCooldownChanged) == "function" and opts.onCooldownChanged or nil

  local specData = nil
  local availabilityResolved = false
  local hasKickAvailable = false
  local onCooldown = false
  local cdEndTime = 0
  local cooldownRemain = 0
  local watchedSpellID = nil
  local watchedCastUnit = "player"
  local watchedCd = nil -- pipeline: SPEC_DATA -> ReadBaseCd -> ScanOwnTalents -> CacheCooldown (each may override)
  local talentScanDirty = true -- invalidated on spec/talent change, cleared after ScanOwnTalents
  -- Extras-Map für Multi-Kick (Demo Warlock Inner Demons, Prot Pala Avenger's Shield).
  -- Key = spellID (= class-interrupt-list-member, der NICHT der primary ist).
  -- Value = { cd = baseCd seconds, cdEnd = absolute getTime() when CD expires }.
  local extras = {}
  local cachedPlayerClass = nil
  local lastObservedKickSpellID = nil
  local lastObservedKickWasPrimary = false
  local missedKick = CreateMissedKickState(getTime)

  local function ResolvePlayerClass()
    if cachedPlayerClass then
      return cachedPlayerClass
    end
    local UnitClass_ref = rawget(_G, "UnitClass")
    if type(UnitClass_ref) ~= "function" or not addonTable.Validators.IsExistingUnit("player") then
      return nil
    end
    local ok, _, classToken = pcall(UnitClass_ref, "player")
    if ok and not IsSecretValue(classToken) and type(classToken) == "string" and classToken ~= "" then
      cachedPlayerClass = classToken
    end
    return cachedPlayerClass
  end
  local ReadBaseCd
  local ScanOwnTalents
  local SetCooldown

  local function ClearResolvedKickState()
    extras = {}
    watchedSpellID = nil
    watchedCd = nil
    hasKickAvailable = false
    talentScanDirty = true
    if onCooldown then
      SetCooldown(false, 0)
      return
    end
    cdEndTime = 0
    cooldownRemain = 0
  end

  local function ApplyResolvedKickState(activeSpellData)
    local nextSpellID = type(activeSpellData) == "table" and activeSpellData.spellID or nil
    local nextCastUnit = specData and specData.castUnit or "player"
    local stateChanged = watchedSpellID ~= nextSpellID
      or watchedCastUnit ~= nextCastUnit
      or availabilityResolved ~= true
      or hasKickAvailable ~= true
    watchedCastUnit = nextCastUnit
    availabilityResolved = true
    hasKickAvailable = true
    if not stateChanged then
      return
    end

    extras = {}
    watchedSpellID = nextSpellID
    watchedCd = activeSpellData and activeSpellData.cd or nil
    talentScanDirty = true
    if onCooldown then
      SetCooldown(false, 0)
    end
    if watchedSpellID then
      ReadBaseCd()
      ScanOwnTalents()
    end
  end

  local function RefreshSpec()
    specData = ResolveSpecData()
    local activeResolution = ResolveActiveSpellData(specData)

    watchedCastUnit = type(activeResolution) == "table" and activeResolution.castUnit or "player"
    if type(activeResolution) ~= "table" or activeResolution.availabilityResolved ~= true then
      availabilityResolved = false
      ClearResolvedKickState()
      return
    end

    if activeResolution.hasKick ~= true then
      availabilityResolved = true
      ClearResolvedKickState()
      return
    end

    ApplyResolvedKickState(activeResolution.spellData)
  end

  -- Read base CD via GetSpellBaseCooldown (ms, untainted, works even when spell is ready).
  -- CacheCooldown may refine with the actual talent-reduced value later.
  ReadBaseCd = function()
    if not watchedSpellID then
      return
    end
    local GetSpellBaseCooldown_ref = rawget(_G, "GetSpellBaseCooldown")
    if type(GetSpellBaseCooldown_ref) ~= "function" then
      return
    end
    local ok, ms = pcall(GetSpellBaseCooldown_ref, watchedSpellID)
    if ok and ms then
      local clean = tonumber(string.format("%.0f", ms))
      if clean and clean > 0 then
        watchedCd = clean / 1000
      end
    end
    -- Let cachedCd (from CacheCooldown) override if available.
  end

  -- Iterate active talent nodes and apply CD reductions.
  -- Skipped if talentScanDirty is false (cache still valid).
  ScanOwnTalents = function()
    if not talentScanDirty then
      return
    end
    if not watchedSpellID then
      return
    end
    local ran = ForEachActiveTalentDefinition(function(definitionSpellID)
      local talent = CD_REDUCTION_DEFS[definitionSpellID]
      if talent and talent.affects == watchedSpellID then
        watchedCd = ApplyTalentCdReduction(watchedCd, talent)
      end
    end)
    if ran then
      talentScanDirty = false
    end
  end

  SetCooldown = function(active, endTime)
    onCooldown = active
    cdEndTime = endTime or 0
    cooldownRemain = active and math.max(0, cdEndTime - getTime()) or 0
    if onCooldownChanged then
      onCooldownChanged(onCooldown, cooldownRemain, watchedSpellID)
    end
  end

  local function ApplyCooldownState(active, endTime)
    local nextEndTime = active and tonumber(endTime) or 0
    if not active or not nextEndTime or nextEndTime <= 0 then
      if onCooldown then
        SetCooldown(false, 0)
        return true
      end
      cdEndTime = 0
      cooldownRemain = 0
      return false
    end

    local remain = math.max(0, nextEndTime - getTime())
    if remain <= 0 then
      if onCooldown then
        SetCooldown(false, 0)
        return true
      end
      cdEndTime = 0
      cooldownRemain = 0
      return false
    end

    if onCooldown and math.abs((cdEndTime or 0) - nextEndTime) <= 0.05 then
      cdEndTime = nextEndTime
      cooldownRemain = remain
      return false
    end

    SetCooldown(true, nextEndTime)
    return true
  end

  local function ReadExactCooldownState()
    return ReadExactCooldownStateForSpell(watchedSpellID)
  end

  local function ApplyExactActiveCooldownForPrimary()
    if availabilityResolved ~= true or hasKickAvailable ~= true or not watchedSpellID then
      return false
    end
    local exactState = ReadExactCooldownState()
    if not exactState or exactState.active ~= true then
      return false
    end
    if
      type(exactState.cooldownDuration) == "number"
      and exactState.cooldownDuration > MEANINGFUL_KICK_COOLDOWN_MIN_SECONDS
    then
      watchedCd = exactState.cooldownDuration
    end
    return ApplyCooldownState(true, exactState.endTime)
  end

  local function ApplyExactActiveCooldownForExtra(spellID)
    if type(spellID) ~= "number" or type(extras[spellID]) ~= "table" then
      return false
    end
    local exactState = ReadExactCooldownStateForSpell(spellID)
    if not exactState or exactState.active ~= true or type(exactState.endTime) ~= "number" then
      return false
    end
    if exactState.endTime <= getTime() then
      return false
    end
    if
      type(exactState.cooldownDuration) == "number"
      and exactState.cooldownDuration > MEANINGFUL_KICK_COOLDOWN_MIN_SECONDS
    then
      extras[spellID].cd = exactState.cooldownDuration
    end
    extras[spellID].cdEnd = exactState.endTime
    if onCooldownChanged then
      onCooldownChanged(onCooldown, cooldownRemain, watchedSpellID)
    end
    return true
  end

  RefreshSpec()

  -- Read exact cooldown state from Blizzard spell cooldown data.
  -- This path must never guess a live cooldown when a cast event was missed.
  local function CacheCooldown()
    if availabilityResolved ~= true or hasKickAvailable ~= true or not watchedSpellID then
      return false
    end
    local exactState = ReadExactCooldownState()
    if not exactState then
      return false
    end

    if
      type(exactState.cooldownDuration) == "number"
      and exactState.cooldownDuration > MEANINGFUL_KICK_COOLDOWN_MIN_SECONDS
    then
      watchedCd = exactState.cooldownDuration
    end

    ApplyCooldownState(exactState.active, exactState.endTime)
    return true
  end

  CacheCooldown()
  -- Eagerly cache the player's class while UnitClass is reachable in this
  -- chunk's runtime context. Some test harnesses scope WithGlobals tightly
  -- around CreateController; OnCast may run later when the global is gone.
  -- For the live addon this is just a one-time read during init.
  ResolvePlayerClass()

  local controller = missedKick.AttachTo({})

  -- Without a watched interrupt the state is re-resolved from casts and the
  -- poll, because a pet-bound kick (Warlock) can appear mid-combat while
  -- UNIT_PET and SPELLS_CHANGED are gated out. A spec that has no interrupt at
  -- all can only change through a spec switch -- which re-resolves through
  -- PLAYER_SPECIALIZATION_CHANGED -- so it skips the per-cast resolve that
  -- used to run on every global cooldown of a healer.
  local function RefreshSpecIfUnwatched()
    if watchedSpellID then
      return
    end
    if
      availabilityResolved == true
      and type(specData) == "table"
      and specData.availabilityResolved == true
      and specData.hasKick == false
    then
      return
    end
    RefreshSpec()
  end

  -- Called from UNIT_SPELLCAST_SUCCEEDED for the tracked unit (player or pet).
  function controller.OnCast(unit, spellID)
    -- A masked spell ID (pet casts in restricted content) is rejected before
    -- the spell-data lookups compare it or use it as a table key; the event
    -- forwarder calls this first, so a raise here would also cost CombatEvents
    -- and VipDkAssist the same event.
    if IsSecretValue(spellID) then
      return missedKick.OnMaskedCast(IsSecretValue(unit) or unit == watchedCastUnit)
    end
    RefreshSpecIfUnwatched()
    if unit ~= watchedCastUnit then
      return false
    end

    -- Primary path: this cast is the spec's registered interrupt.
    local spellData = GetSpellDataByID(specData, spellID)
    if spellData then
      if watchedSpellID ~= spellData.spellID then
        watchedSpellID = spellData.spellID
        watchedCd = spellData.cd
        talentScanDirty = true
      end
      watchedCd = watchedCd or spellData.cd
      -- Base cooldown and talent reductions are resolved once per spell or
      -- talent change (ResolveKickState runs them out of combat). Re-reading
      -- the base value on every cast used to reset the talent-reduced
      -- cooldown to the untalented one from the second kick on.
      if talentScanDirty then
        ReadBaseCd()
        ScanOwnTalents()
      end
      local cd = tonumber(watchedCd or spellData.cd)
      if not cd or cd <= 0 then
        return false
      end
      SetCooldown(true, getTime() + cd)
      lastObservedKickSpellID = watchedSpellID
      lastObservedKickWasPrimary = true
      missedKick.Arm(spellID, watchedSpellID, watchedCastUnit)
      ApplyExactActiveCooldownForPrimary()
      return true
    end

    -- Extras path: this cast is a class-interrupt that's NOT the registered
    -- primary slot -- e.g. Demo Warlock with Inner Demons casts both Spell
    -- Lock (Felhunter) AND Axe Toss (Felguard), or Prot Paladin with the
    -- Avenger's Shield interrupt talent. Tracked separately from primary.
    if IsExtraKickSpellForClass(ResolvePlayerClass(), watchedSpellID, spellID) then
      local cd = LookupExtraKickCd(spellID)
      if not cd or cd <= 0 then
        return false
      end
      extras[spellID] = { cd = cd, cdEnd = getTime() + cd }
      lastObservedKickSpellID = spellID
      lastObservedKickWasPrimary = false
      missedKick.Arm(spellID, spellID, watchedCastUnit)
      ApplyExactActiveCooldownForExtra(spellID)
      if onCooldownChanged then
        onCooldownChanged(onCooldown, cooldownRemain, watchedSpellID)
      end
      return true
    end

    return false
  end

  -- Called on SPELL_UPDATE_COOLDOWN and PLAYER_REGEN_ENABLED to refresh cached CD.
  function controller.CacheCooldown()
    return CacheCooldown()
  end

  function controller.ReconcileObservedCooldown()
    if lastObservedKickWasPrimary then
      return ApplyExactActiveCooldownForPrimary()
    end
    return ApplyExactActiveCooldownForExtra(lastObservedKickSpellID)
  end

  function controller.ResolveKickState()
    talentScanDirty = true
    RefreshSpec()
    -- Spec, spell and pet events arrive outside combat: resolve the base
    -- cooldown and walk the talent tree here instead of on the first kick of
    -- the next pull.
    if watchedSpellID and talentScanDirty then
      ReadBaseCd()
      ScanOwnTalents()
    end
    local exactStateKnown = CacheCooldown()
    local info = controller.GetKickInfo()
    return {
      spellID = info.spellID,
      hasKick = info.hasKick == true,
      availabilityResolved = info.availabilityResolved == true,
      onCooldown = info.onCooldown == true,
      cooldownRemain = info.cooldownRemain or 0,
      exactCooldownKnown = info.availabilityResolved == true and info.hasKick == true and exactStateKnown == true,
    }
  end

  -- Called every 0.5s from ticker to detect expiry.
  function controller.Scan()
    RefreshSpecIfUnwatched()
    local now = getTime()
    if onCooldown and cdEndTime > 0 then
      if now >= cdEndTime then
        SetCooldown(false, 0)
      else
        cooldownRemain = cdEndTime - now
      end
    end
    -- Sweep extras: drop any whose CD has expired so GetKickInfo doesn't
    -- emit stale entries.
    for spellID, data in pairs(extras) do
      if type(data) ~= "table" or type(data.cdEnd) ~= "number" or now >= data.cdEnd then
        extras[spellID] = nil
      end
    end
  end

  function controller.GetKickInfo()
    local hasKick = availabilityResolved == true and hasKickAvailable == true and watchedSpellID ~= nil
    local now = getTime()
    local remain = hasKick and (onCooldown and cdEndTime > 0) and math.max(0, cdEndTime - now) or 0
    return {
      spellID = hasKick and watchedSpellID or nil,
      hasKick = hasKick,
      availabilityResolved = availabilityResolved == true,
      onCooldown = hasKick and onCooldown or false,
      cooldownRemain = remain,
      extras = CollectActiveExtras(extras, now),
    }
  end

  return controller
end
