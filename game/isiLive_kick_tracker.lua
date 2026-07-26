local _, addonTable = ...

addonTable = addonTable or {}

local KickTracker = {}
addonTable.KickTracker = KickTracker
local IsSecretValue = addonTable.Validators.IsSecretValue
local MEANINGFUL_KICK_COOLDOWN_MIN_SECONDS = 1.5
local NO_INTERRUPT_SPEC_IDS = {
  [105] = true, -- Restoration Druid
  [256] = true, -- Discipline Priest
  [257] = true, -- Holy Priest
  [65] = true, -- Holy Paladin (no Rebuke)
  [270] = true, -- Mistweaver Monk (no Spear Hand Strike)
}

-- Spec-keyed interrupt data (spec ID → { spellID, cd }).
local SPEC_DATA = {
  -- Death Knight
  [250] = { spellID = 47528, cd = 15 }, -- Blood
  [251] = { spellID = 47528, cd = 15 }, -- Frost
  [252] = { spellID = 47528, cd = 15 }, -- Unholy
  -- Demon Hunter -- all three specs share the class baseline interrupt.
  -- Verified on a live client 2026-07-26: C_Spell.GetSpellName(183752) resolves
  -- on every spec, and the tooltip reads 15s on each. Spec 1480 was confirmed
  -- via GetSpecializationInfoByID as a Demon Hunter damage spec.
  --
  -- Naming trap for future audits: 183752 is Disrupt in English but reads
  -- "Unterbrechen" on a German client -- which is also the generic German word
  -- for "interrupt". Do not conclude from a spell NAME that a spec lacks this
  -- ability; resolve the ID via C_Spell.GetSpellName instead.
  [577] = { spellID = 183752, cd = 15 }, -- Havoc
  [581] = { spellID = 183752, cd = 15 }, -- Vengeance
  [1480] = { spellID = 183752, cd = 15 }, -- Devourer (Midnight third spec)
  -- Druid
  [102] = { spellID = 78675, cd = 45 }, -- Balance: Solar Beam (45s in Midnight)
  [103] = { spellID = 106839, cd = 15 }, -- Feral: Skull Bash
  [104] = { spellID = 106839, cd = 15 }, -- Guardian: Skull Bash
  [105] = nil, -- Restoration: no interrupt
  -- Evoker
  [1467] = { spellID = 351338, cd = 18 }, -- Devastation: Quell
  [1468] = { spellID = 351338, cd = 18 }, -- Preservation: Quell
  [1473] = { spellID = 351338, cd = 18 }, -- Augmentation: Quell
  -- Hunter
  [253] = { spellID = 147362, cd = 24 }, -- BM: Counter Shot
  [254] = { spellID = 147362, cd = 24 }, -- MM: Counter Shot
  [255] = { spellID = 187707, cd = 15 }, -- Survival: Muzzle
  -- Mage
  [62] = { spellID = 2139, cd = 25 }, -- Counterspell (25s base; talent 382297 reduces to 20)
  [63] = { spellID = 2139, cd = 25 },
  [64] = { spellID = 2139, cd = 25 },
  -- Monk
  [268] = { spellID = 116705, cd = 15 }, -- Brewmaster: Spear Hand Strike
  [269] = { spellID = 116705, cd = 15 }, -- Windwalker: Spear Hand Strike
  [270] = nil, -- Mistweaver: no interrupt
  -- Paladin
  [65] = nil, -- Holy: no Rebuke
  [66] = { spellID = 96231, cd = 15 }, -- Protection: Rebuke
  [70] = { spellID = 96231, cd = 15 }, -- Retribution: Rebuke
  -- Priest
  [256] = nil, -- Discipline
  [257] = nil, -- Holy
  [258] = { spellID = 15487, cd = 30 }, -- Shadow: Silence
  -- Rogue
  [259] = { spellID = 1766, cd = 15 },
  [260] = { spellID = 1766, cd = 15 },
  [261] = { spellID = 1766, cd = 15 },
  -- Shaman
  [262] = { spellID = 57994, cd = 12 },
  [263] = { spellID = 57994, cd = 12 },
  [264] = { spellID = 57994, cd = 30 }, -- Resto: 30s
  -- Warlock
  [265] = {
    castUnit = "pet",
    requireAvailability = true,
    spells = {
      { spellID = 19647, cd = 24 }, -- Spell Lock
    },
  },
  [266] = {
    castUnit = "pet",
    requireAvailability = true,
    spells = {
      { spellID = 119914, cd = 30, castSpellIDs = { 89766 } }, -- Axe Toss (player-facing ID; pet cast uses 89766)
      { spellID = 19647, cd = 24 }, -- Spell Lock (e.g. Fel Ravager path)
    },
  },
  [267] = {
    castUnit = "pet",
    requireAvailability = true,
    spells = {
      { spellID = 19647, cd = 24 }, -- Spell Lock
    },
  },
  -- Warrior
  [71] = { spellID = 6552, cd = 15 },
  [72] = { spellID = 6552, cd = 15 },
  [73] = { spellID = 6552, cd = 15 },
}

-- Class-level whitelist of all known interrupt spell IDs (across specs/talents).
-- Used by OnCast to detect a cast that is "an interrupt of my class but NOT
-- the registered primary slot" -- e.g. Demo Warlock with Inner Demons casts
-- both Spell Lock (Felhunter) and Axe Toss (Felguard) in the same key, or
-- Prot Paladin with the Avenger's Shield interrupt talent.
--
-- Classes with only one interrupt-spell across all specs are intentionally
-- not listed -- spec-switching for them is handled via RefreshSpec on
-- PLAYER_SPECIALIZATION_CHANGED, not through OnCast detection.
local CLASS_INTERRUPT_LIST = {
  WARLOCK = { 19647, 119914 }, -- Spell Lock + Axe Toss (player-facing)
  PALADIN = { 96231, 31935 }, -- Rebuke + Avenger's Shield (talent-as-interrupt)
}

-- CDs for spells that appear ONLY as extras (not as a spec's primary in
-- SPEC_DATA). Primary spells take their CD from SPEC_DATA, extras need this
-- because there's no spec-slot to read from.
local EXTRA_KICK_CD = {
  -- Verified in-game 2026-07-26 on a Protection Paladin with the interrupt
  -- talent active: the spell tooltip reads a flat 13s. Not haste-scaled --
  -- Rebuke read exactly 15s on the same character at 13.03% haste, so a fixed
  -- constant is the right model here.
  --
  -- Caveat: 13s is the value WITH that character's talent build. The
  -- Protection tree also carries cooldown reductions for this spell, and
  -- whether the reading already includes one cannot be separated without
  -- respeccing. Left unmodelled in CD_REDUCTION_DEFS rather than guessed --
  -- this constant only seeds the extras slot until the exact live cooldown
  -- lands (see ApplyExactActiveCooldownForExtra), and serves as the fallback
  -- when a Secret Value blocks that read.
  [31935] = 13, -- Avenger's Shield (Prot Paladin interrupt talent)
}

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

local function ReadCooldownField(info, key)
  if type(info) ~= "table" then
    return nil, false
  end

  local ok, value = pcall(function()
    return info[key]
  end)
  if not ok then
    return nil, false
  end

  local isSecretValue = rawget(_G, "issecretvalue")
  if type(isSecretValue) == "function" then
    local okSecret, isSecret = pcall(isSecretValue, value)
    if okSecret and isSecret then
      return nil, false
    end
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

  local controller = {}

  -- Called from UNIT_SPELLCAST_SUCCEEDED for the tracked unit (player or pet).
  function controller.OnCast(unit, spellID)
    if not watchedSpellID then
      RefreshSpec()
    end
    if unit ~= watchedCastUnit then
      return false
    end

    -- Primary path: this cast is the spec's registered interrupt.
    local spellData = GetSpellDataByID(specData, spellID)
    if spellData then
      watchedSpellID = spellData.spellID
      watchedCd = watchedCd or spellData.cd
      ReadBaseCd()
      ScanOwnTalents()
      local cd = tonumber(watchedCd or spellData.cd)
      if not cd or cd <= 0 then
        return false
      end
      SetCooldown(true, getTime() + cd)
      lastObservedKickSpellID = watchedSpellID
      lastObservedKickWasPrimary = true
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
    if not watchedSpellID then
      RefreshSpec()
    end
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
