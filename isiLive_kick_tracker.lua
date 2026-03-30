local _, addonTable = ...

addonTable = addonTable or {}

local KickTracker = {}
addonTable.KickTracker = KickTracker

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
  [382297] = { affects = 2139, reduction = 5 }, -- Quick Witted       (Mage:    Counterspell 25→20)
  [388039] = { affects = 147362, reduction = 2 }, -- Lone Survivor      (Hunter:  Counter Shot)
  [412713] = { affects = 351338, pctReduction = 10 }, -- Interwoven Threads (Evoker:  Quell)
  [391271] = { affects = 6552, pctReduction = 10 }, -- Seasoned Soldier   (Warrior: Pummel)
}

local function ResolveSpecData()
  local GetSpecialization_ref = rawget(_G, "GetSpecialization")
  local GetSpecializationInfo_ref = rawget(_G, "GetSpecializationInfo")
  if type(GetSpecialization_ref) ~= "function" or type(GetSpecializationInfo_ref) ~= "function" then
    return nil
  end
  local specIndex = GetSpecialization_ref()
  if not specIndex then
    return nil
  end
  local ok, specID = pcall(GetSpecializationInfo_ref, specIndex)
  if not ok or type(specID) ~= "number" then
    return nil
  end
  local specData = SPEC_DATA[specID]
  if type(specData) ~= "table" then
    return nil
  end
  if type(specData.spellID) == "number" then
    return {
      castUnit = "player",
      requireAvailability = false,
      spells = {
        { spellID = specData.spellID, cd = specData.cd },
      },
    }
  end
  if type(specData.spells) ~= "table" then
    return nil
  end
  return {
    castUnit = specData.castUnit == "pet" and "pet" or "player",
    requireAvailability = specData.requireAvailability == true,
    spells = specData.spells,
  }
end

-- Read actual cooldown duration via C_Spell.GetSpellCooldown.
-- Safe to call from C_Timer.After callbacks (untainted context).
-- Pass requireOutOfCombat=true to skip during combat lockdown.

function KickTracker.CreateController(opts)
  opts = opts or {}
  local getTime = type(opts.getTime) == "function" and opts.getTime or GetTime
  local onCooldownChanged = type(opts.onCooldownChanged) == "function" and opts.onCooldownChanged or nil

  local specData = nil
  local onCooldown = false
  local cdEndTime = 0
  local cooldownRemain = 0
  local watchedSpellID = nil
  local watchedCastUnit = "player"
  local watchedCd = nil -- may be refined by CacheCooldown or ScanOwnTalents

  local function SpellAppearsAvailable(spellID)
    if type(spellID) ~= "number" then
      return false
    end

    local GetSpellBaseCooldown_ref = rawget(_G, "GetSpellBaseCooldown")
    if type(GetSpellBaseCooldown_ref) == "function" then
      local ok, ms = pcall(GetSpellBaseCooldown_ref, spellID)
      if ok and tonumber(ms) and tonumber(ms) > 0 then
        return true
      end
    end

    local C_Spell_ref = rawget(_G, "C_Spell")
    if type(C_Spell_ref) == "table" and type(C_Spell_ref.GetSpellCooldown) == "function" then
      local ok, info = pcall(C_Spell_ref.GetSpellCooldown, spellID)
      if ok and info ~= nil then
        return true
      end
    end

    return false
  end

  local function GetSpellDataByID(spellID)
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

  local function ResolveActiveSpellData()
    if type(specData) ~= "table" or type(specData.spells) ~= "table" then
      return nil
    end

    for _, spellData in ipairs(specData.spells) do
      if type(spellData) == "table" and SpellAppearsAvailable(spellData.spellID) then
        return spellData
      end
    end

    if specData.requireAvailability == true then
      return nil
    end

    return specData.spells[1]
  end

  -- Read base CD via GetSpellBaseCooldown (ms, untainted, works even when spell is ready).
  -- CacheCooldown may refine with the actual talent-reduced value later.
  local function ReadBaseCd()
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
  local function ScanOwnTalents()
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
  end

  local function SetCooldown(active, endTime)
    onCooldown = active
    cdEndTime = endTime or 0
    cooldownRemain = active and math.max(0, cdEndTime - getTime()) or 0
    if onCooldownChanged then
      onCooldownChanged(onCooldown, cooldownRemain, watchedSpellID)
    end
  end

  local function RefreshSpec()
    local prevSpellID = watchedSpellID
    local prevCastUnit = watchedCastUnit
    specData = ResolveSpecData()
    watchedCastUnit = specData and specData.castUnit or "player"
    local activeSpellData = ResolveActiveSpellData()
    watchedSpellID = activeSpellData and activeSpellData.spellID or nil
    if watchedSpellID ~= prevSpellID or watchedCastUnit ~= prevCastUnit then
      watchedCd = activeSpellData and activeSpellData.cd or nil
      -- Clear any active cooldown from the previous spec's spell.
      if onCooldown then
        SetCooldown(false, 0)
      end
      if watchedSpellID then
        ReadBaseCd()
        ScanOwnTalents()
      end
    end
  end

  RefreshSpec()

  -- Cache the real (talent-reduced) CD from GetSpellCooldown. Only outside combat.
  -- Only caches when spell is on CD (duration > 1.5); called on SPELL_UPDATE_COOLDOWN
  -- while CD is active but outside combat, and on PLAYER_REGEN_ENABLED after combat ends.
  local function CacheCooldown()
    if not watchedSpellID then
      return
    end
    local InCombatLockdown_ref = rawget(_G, "InCombatLockdown")
    if type(InCombatLockdown_ref) == "function" and InCombatLockdown_ref() then
      return
    end
    local C_Spell_ref = rawget(_G, "C_Spell")
    if type(C_Spell_ref) ~= "table" then
      return
    end
    local ok, info = pcall(C_Spell_ref.GetSpellCooldown, watchedSpellID)
    if not ok or not info then
      return
    end
    local ok2, dur = pcall(function()
      return info.duration
    end)
    if not ok2 or not dur then
      return
    end
    -- Strip taint: tostring in its own pcall, then tonumber on the resulting string.
    local ok3, durStr = pcall(tostring, dur)
    if not ok3 or not durStr then
      return
    end
    local clean = tonumber(durStr)
    if clean and clean > 1.5 then
      watchedCd = clean
      -- Only correct cdEndTime if CD was just started (remaining ≈ full duration).
      -- Do NOT reset cdEndTime mid-CD (duration is always the full CD, not remaining).
      if onCooldown and cdEndTime > 0 then
        local remaining = cdEndTime - getTime()
        if remaining > 0 and remaining > clean - 1 and math.abs(remaining - clean) > 1 then
          cdEndTime = getTime() + clean
        end
      end
    end
  end

  -- Called outside combat when CD ends: compute real talent-reduced duration from
  CacheCooldown()

  local controller = {}

  -- Called from UNIT_SPELLCAST_SUCCEEDED for the tracked unit (player or pet).
  function controller.OnCast(unit, spellID)
    if not watchedSpellID then
      RefreshSpec()
    end
    if unit ~= watchedCastUnit then
      return
    end

    local spellData = GetSpellDataByID(spellID)
    if not spellData then
      return
    end

    watchedSpellID = spellData.spellID
    watchedCd = spellData.cd or watchedCd
    if watchedSpellID then
      local cd = watchedCd or 15
      SetCooldown(true, getTime() + cd)
    end
  end

  -- Called on SPELL_UPDATE_COOLDOWN and PLAYER_REGEN_ENABLED to refresh cached CD.
  function controller.CacheCooldown()
    CacheCooldown()
  end

  -- Called on SPELLS_CHANGED / PLAYER_SPECIALIZATION_CHANGED.
  function controller.ResolveSpellID()
    RefreshSpec()
    CacheCooldown()
    return watchedSpellID
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
    if onCooldown and cdEndTime > 0 then
      cooldownRemain = math.max(0, cdEndTime - getTime())
    end
    return {
      spellID = watchedSpellID,
      onCooldown = onCooldown,
      cooldownRemain = cooldownRemain,
    }
  end

  return controller
end
