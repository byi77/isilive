local _, addonTable = ...

addonTable = addonTable or {}

local KickTracker = {}
addonTable.KickTracker = KickTracker
local MEANINGFUL_KICK_COOLDOWN_MIN_SECONDS = 1.5
local NO_INTERRUPT_SPEC_IDS = {
  [105] = true,
  [256] = true,
  [257] = true,
}

-- Spec-keyed interrupt data (spec ID → { spellID, cd }).
local SPEC_DATA = {
  -- Death Knight
  [250] = { spellID = 47528, cd = 15 }, -- Blood
  [251] = { spellID = 47528, cd = 15 }, -- Frost
  [252] = { spellID = 47528, cd = 15 }, -- Unholy
  -- Demon Hunter
  [577] = { spellID = 183752, cd = 15 },
  [581] = { spellID = 183752, cd = 15 },
  [1480] = { spellID = 183752, cd = 15 },
  -- Druid
  [102] = { spellID = 78675, cd = 60 }, -- Balance: Solar Beam
  [103] = { spellID = 106839, cd = 15 }, -- Feral: Skull Bash
  [104] = { spellID = 106839, cd = 15 }, -- Guardian: Skull Bash
  [105] = nil, -- Restoration: no interrupt
  -- Evoker
  [1467] = { spellID = 351338, cd = 20 },
  [1468] = { spellID = 351338, cd = 20 },
  [1473] = { spellID = 351338, cd = 20 },
  -- Hunter
  [253] = { spellID = 147362, cd = 24 }, -- BM: Counter Shot
  [254] = { spellID = 147362, cd = 24 }, -- MM: Counter Shot
  [255] = { spellID = 187707, cd = 15 }, -- Survival: Muzzle
  -- Mage
  [62] = { spellID = 2139, cd = 25 },
  [63] = { spellID = 2139, cd = 25 },
  [64] = { spellID = 2139, cd = 25 },
  -- Monk
  [268] = { spellID = 116705, cd = 15 },
  [269] = { spellID = 116705, cd = 15 },
  [270] = { spellID = 116705, cd = 15 },
  -- Paladin
  [65] = { spellID = 96231, cd = 15 }, -- Holy: Rebuke
  [66] = { spellID = 96231, cd = 15 }, -- Prot
  [70] = { spellID = 96231, cd = 15 }, -- Ret
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
      { spellID = 89766, cd = 30 }, -- Axe Toss
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
  local specIndex = GetSpecialization_ref()
  if not specIndex then
    return {
      availabilityResolved = false,
      hasKick = false,
    }
  end
  local ok, specID = pcall(GetSpecializationInfo_ref, specIndex)
  if not ok or type(specID) ~= "number" then
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
    if not ok then
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
  local ReadBaseCd
  local ScanOwnTalents
  local SetCooldown

  local function ClearResolvedKickState()
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
    local C_ClassTalents_ref = rawget(_G, "C_ClassTalents")
    if type(C_ClassTalents_ref) ~= "table" then
      return
    end
    local ok0, cid = pcall(C_ClassTalents_ref.GetActiveConfigID)
    if not ok0 or not cid then
      return
    end
    local C_Traits_ref = rawget(_G, "C_Traits")
    if type(C_Traits_ref) ~= "table" then
      return
    end
    local ok1, cfg = pcall(C_Traits_ref.GetConfigInfo, cid)
    if not ok1 or not cfg or not cfg.treeIDs or #cfg.treeIDs == 0 then
      return
    end
    local ok2, nodes = pcall(C_Traits_ref.GetTreeNodes, cfg.treeIDs[1])
    if not ok2 or not nodes then
      return
    end
    for _, nodeID in ipairs(nodes) do
      local ok3, node = pcall(C_Traits_ref.GetNodeInfo, cid, nodeID)
      if ok3 and node and node.activeEntry and node.activeRank and node.activeRank > 0 then
        local ok4, entry = pcall(C_Traits_ref.GetEntryInfo, cid, node.activeEntry.entryID)
        if ok4 and entry and entry.definitionID then
          local ok5, def = pcall(C_Traits_ref.GetDefinitionInfo, entry.definitionID)
          if ok5 and def and def.spellID then
            local talent = CD_REDUCTION_DEFS[def.spellID]
            if talent and talent.affects == watchedSpellID then
              local base = watchedCd
              if base and base > 0 then
                local newCd
                if talent.pctReduction then
                  newCd = math.floor(base * (1 - talent.pctReduction / 100) + 0.5)
                else
                  newCd = base - talent.reduction
                end
                watchedCd = math.max(1, newCd)
              end
            end
          end
        end
      end
    end
    talentScanDirty = false
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

  local controller = {}

  -- Called from UNIT_SPELLCAST_SUCCEEDED for the tracked unit (player or pet).
  function controller.OnCast(unit, spellID)
    if not watchedSpellID then
      RefreshSpec()
    end
    if unit ~= watchedCastUnit then
      return false
    end

    local spellData = GetSpellDataByID(specData, spellID)
    if not spellData then
      return false
    end

    watchedSpellID = spellData.spellID
    watchedCd = watchedCd or spellData.cd
    ReadBaseCd()
    ScanOwnTalents()
    local cd = watchedCd or 15
    SetCooldown(true, getTime() + cd)
    return true
  end

  -- Called on SPELL_UPDATE_COOLDOWN and PLAYER_REGEN_ENABLED to refresh cached CD.
  function controller.CacheCooldown()
    return CacheCooldown()
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
    if onCooldown and cdEndTime > 0 then
      local now = getTime()
      if now >= cdEndTime then
        SetCooldown(false, 0)
      else
        cooldownRemain = cdEndTime - now
      end
    end
  end

  function controller.GetKickInfo()
    local hasKick = availabilityResolved == true and hasKickAvailable == true and watchedSpellID ~= nil
    local remain = hasKick and (onCooldown and cdEndTime > 0) and math.max(0, cdEndTime - getTime()) or 0
    return {
      spellID = hasKick and watchedSpellID or nil,
      hasKick = hasKick,
      availabilityResolved = availabilityResolved == true,
      onCooldown = hasKick and onCooldown or false,
      cooldownRemain = remain,
    }
  end

  return controller
end
