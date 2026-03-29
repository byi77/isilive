local _, addonTable = ...

addonTable = addonTable or {}

local KickTracker = {}
addonTable.KickTracker = KickTracker

-- Spec-keyed interrupt data (spec ID → { spellID, cd }).
-- Source: BliZzi_Interrupts SPEC_REGISTRY (cross-referenced).
local SPEC_DATA = {
  -- Death Knight
  [250] = { spellID = 47528, cd = 15 }, -- Blood
  [251] = { spellID = 47528, cd = 15 }, -- Frost
  [252] = { spellID = 47528, cd = 15 }, -- Unholy
  -- Demon Hunter
  [577]  = { spellID = 183752, cd = 15 },
  [581]  = { spellID = 183752, cd = 15 },
  [1480] = { spellID = 183752, cd = 15 },
  -- Druid
  [102] = { spellID = 78675,  cd = 60 }, -- Balance: Solar Beam
  [103] = { spellID = 106839, cd = 15 }, -- Feral: Skull Bash
  [104] = { spellID = 106839, cd = 15 }, -- Guardian: Skull Bash
  [105] = nil,                           -- Restoration: no interrupt
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
  [65] = nil,                            -- Holy: no interrupt
  [66] = { spellID = 96231, cd = 15 },   -- Prot
  [70] = { spellID = 96231, cd = 15 },   -- Ret
  -- Priest
  [256] = nil,                           -- Discipline
  [257] = nil,                           -- Holy
  [258] = { spellID = 15487, cd = 30 },  -- Shadow: Silence
  -- Rogue
  [259] = { spellID = 1766, cd = 15 },
  [260] = { spellID = 1766, cd = 15 },
  [261] = { spellID = 1766, cd = 15 },
  -- Shaman
  [262] = { spellID = 57994, cd = 12 },
  [263] = { spellID = 57994, cd = 12 },
  [264] = { spellID = 57994, cd = 30 }, -- Resto: 30s
  -- Warlock
  [265] = { spellID = 19647, cd = 24 },
  [266] = nil,                           -- Demo: Axe Toss (pet, skip)
  [267] = { spellID = 19647, cd = 24 },
  -- Warrior
  [71] = { spellID = 6552, cd = 15 },
  [72] = { spellID = 6552, cd = 15 },
  [73] = { spellID = 6552, cd = 15 },
}

-- Talent spell ID → { affects = interruptSpellID, reduction = seconds }
-- Mirrors BliZzi CD_REDUCTION_DEFS.
-- Talent spell ID → { affects = interruptSpellID, reduction = seconds | pctReduction = % }
-- Source: BliZzi_Interrupts CD_REDUCTION_DEFS + Quick Witted (Mage).
local CD_REDUCTION_DEFS = {
  [382297] = { affects = 2139,   reduction = 5  }, -- Quick Witted       (Mage:    Counterspell 25→20)
  [388039] = { affects = 147362, reduction = 2  }, -- Lone Survivor      (Hunter:  Counter Shot)
  [412713] = { affects = 351338, pctReduction = 10 }, -- Interwoven Threads (Evoker:  Quell)
  [391271] = { affects = 6552,   pctReduction = 10 }, -- Seasoned Soldier   (Warrior: Pummel)
}

local function ResolveSpecData()
  local GetSpecialization_ref = rawget(_G, "GetSpecialization")
  local GetSpecializationInfo_ref = rawget(_G, "GetSpecializationInfo")
  if type(GetSpecialization_ref) ~= "function" or type(GetSpecializationInfo_ref) ~= "function" then
    return nil
  end
  local specIndex = GetSpecialization_ref()
  if not specIndex then return nil end
  local ok, specID = pcall(GetSpecializationInfo_ref, specIndex)
  if not ok or type(specID) ~= "number" then return nil end
  return SPEC_DATA[specID]
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
  local watchedCd = nil  -- may be refined by CacheCooldown or ScanOwnTalents

  -- Read base CD via GetSpellBaseCooldown (ms, untainted, works even when spell is ready).
  -- Mirrors BliZzi ReadBaseCd. Then let CacheCooldown refine with talent-reduced value.
  local function ReadBaseCd()
    if not watchedSpellID then return end
    local GetSpellBaseCooldown_ref = rawget(_G, "GetSpellBaseCooldown")
    if type(GetSpellBaseCooldown_ref) ~= "function" then return end
    local ok, ms = pcall(GetSpellBaseCooldown_ref, watchedSpellID)
    if ok and ms then
      local clean = tonumber(string.format("%.0f", ms))
      if clean and clean > 0 then
        watchedCd = clean / 1000
      end
    end
    -- Let cachedCd (from CacheCooldown) override if available.
  end

  -- Mirrors BliZzi ScanOwnTalents: iterate active talent nodes, apply CD reductions.
  local function ScanOwnTalents()
    if not watchedSpellID then return end
    local C_ClassTalents_ref = rawget(_G, "C_ClassTalents")
    if type(C_ClassTalents_ref) ~= "table" then return end
    local ok0, cid = pcall(C_ClassTalents_ref.GetActiveConfigID)
    if not ok0 or not cid then return end
    local C_Traits_ref = rawget(_G, "C_Traits")
    if type(C_Traits_ref) ~= "table" then return end
    local ok1, cfg = pcall(C_Traits_ref.GetConfigInfo, cid)
    if not ok1 or not cfg or not cfg.treeIDs or #cfg.treeIDs == 0 then return end
    local ok2, nodes = pcall(C_Traits_ref.GetTreeNodes, cfg.treeIDs[1])
    if not ok2 or not nodes then return end
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

  local function RefreshSpec()
    local prevSpellID = watchedSpellID
    specData = ResolveSpecData()
    watchedSpellID = specData and specData.spellID or nil
    if watchedSpellID ~= prevSpellID then
      watchedCd = specData and specData.cd or nil
      ReadBaseCd()
      ScanOwnTalents()
    end
  end

  RefreshSpec()

  -- Cache the real (talent-reduced) CD from GetSpellCooldown. Only outside combat.
  -- Mirrors BliZzi_Interrupts CacheCooldown exactly: only caches when spell is on CD
  -- (duration > 1.5), so this is called on SPELL_UPDATE_COOLDOWN while CD is active
  -- but outside combat, and on PLAYER_REGEN_ENABLED after combat ends.
  local function CacheCooldown()
    if not watchedSpellID then return end
    local InCombatLockdown_ref = rawget(_G, "InCombatLockdown")
    if type(InCombatLockdown_ref) == "function" and InCombatLockdown_ref() then return end
    local C_Spell_ref = rawget(_G, "C_Spell")
    if type(C_Spell_ref) ~= "table" then return end
    local ok, info = pcall(C_Spell_ref.GetSpellCooldown, watchedSpellID)
    if not ok or not info then return end
    local ok2, dur = pcall(function() return info.duration end)
    if not ok2 or not dur then return end
    -- Strip taint: tostring in its own pcall, then tonumber on the resulting string.
    local ok3, durStr = pcall(tostring, dur)
    if not ok3 or not durStr then return end
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

  local function SetCooldown(active, endTime)
    onCooldown = active
    cdEndTime = endTime or 0
    cooldownRemain = active and math.max(0, cdEndTime - getTime()) or 0
    if onCooldownChanged then
      onCooldownChanged(onCooldown, cooldownRemain, watchedSpellID)
    end
  end

  local controller = {}

  -- Called from UNIT_SPELLCAST_SUCCEEDED for "player" (untainted event handler context).
  -- castCd: real CD duration read in the same untainted event handler, may be nil.
  function controller.OnPlayerCast(spellID)
    if not watchedSpellID then RefreshSpec() end
    if watchedSpellID and spellID == watchedSpellID then
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
    if not watchedSpellID then RefreshSpec() end
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
