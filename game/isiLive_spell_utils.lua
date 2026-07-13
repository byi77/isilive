local _, addonTable = ...

addonTable = addonTable or {}

local SpellUtils = {}
addonTable.SpellUtils = SpellUtils
local TELEPORT_MEANINGFUL_COOLDOWN_MIN_SECONDS = 2

local function IsConfiguredTeleportSpellID(spellID)
  local numericSpellID = tonumber(spellID)
  local seasonData = addonTable.SeasonData
  local seasons = type(seasonData) == "table" and seasonData.SEASONS or nil
  if not numericSpellID or type(seasons) ~= "table" then
    return false
  end

  for _, season in pairs(seasons) do
    local mapToTeleport = type(season) == "table" and season.mapToTeleport or nil
    if type(mapToTeleport) == "table" then
      for _, mapped in pairs(mapToTeleport) do
        if type(mapped) == "number" and mapped == numericSpellID then
          return true
        end
        if type(mapped) == "table" then
          for _, candidate in ipairs(mapped) do
            if tonumber(candidate) == numericSpellID then
              return true
            end
          end
        end
      end
    end
  end
  return false
end

local function GetVerifiedAccountTeleportSpells()
  local db = rawget(_G, "IsiLiveDB")
  local verified = type(db) == "table" and db.verifiedAccountTeleportSpells or nil
  if type(verified) ~= "table" then
    return nil
  end
  return verified
end

local function RecordVerifiedAccountTeleportSpell(spellID)
  if not IsConfiguredTeleportSpellID(spellID) then
    return
  end
  local verified = GetVerifiedAccountTeleportSpells()
  if verified then
    verified[spellID] = true
  end
end

local function IsPersistedAccountTeleportSpell(spellID)
  if not IsConfiguredTeleportSpellID(spellID) then
    return false
  end
  local verified = GetVerifiedAccountTeleportSpells()
  return verified and verified[spellID] == true or false
end

function SpellUtils.NormalizeTeleportCooldownRemaining(remaining, duration)
  if type(remaining) ~= "number" or type(duration) ~= "number" then
    return remaining
  end
  if duration <= TELEPORT_MEANINGFUL_COOLDOWN_MIN_SECONDS then
    return remaining
  end
  if remaining <= duration then
    return remaining
  end
  local normalizedRemaining = remaining % duration
  if normalizedRemaining <= 0 then
    normalizedRemaining = duration
  end
  return normalizedRemaining
end

function SpellUtils.GetCooldownFrameStartForRemaining(remaining)
  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  return now, remaining
end

function SpellUtils.GetSpellCooldownSafe(spellID)
  local cSpell = rawget(_G, "C_Spell")
  if not spellID or type(cSpell) ~= "table" or type(cSpell.GetSpellCooldown) ~= "function" then
    return 0, 0, true
  end
  local ok, info = pcall(cSpell.GetSpellCooldown, spellID)
  if not ok or type(info) ~= "table" then
    return 0, 0, true
  end
  local start = info.startTime or 0
  local duration = info.duration or 0
  local enabled = info.isEnabled

  -- WoW internal bug workaround: GetSpellCooldown can return opaque
  -- "SecretValue" types in some builds that bypass normal Lua type checks.
  -- issecretvalue() detects these and replaces them with safe defaults.
  local issecretvalue = rawget(_G, "issecretvalue")
  if type(issecretvalue) == "function" then
    if issecretvalue(enabled) then
      enabled = true
    end
    if issecretvalue(start) then
      start = 0
    end
    if issecretvalue(duration) then
      duration = 0
    end
  end

  return start, duration, enabled
end

function SpellUtils.ApplyCooldownFrameSafe(cooldownFrame, start, duration, enabled)
  if not cooldownFrame then
    return
  end

  -- Preferred path: SetCooldownFromDurationObject is the only cooldown setter
  -- that Blizzard guarantees to work with secret values post-12.0.1 hotfix.
  -- If it exists and the frame exposes it, use it exclusively.
  if cooldownFrame.SetCooldownFromDurationObject then
    if enabled == false or enabled == 0 or not duration or duration <= 0 then
      local zeroDur = rawget(_G, "CreateCooldownDuration")
      if type(zeroDur) == "function" then
        local ok, dur = pcall(zeroDur)
        if ok and dur then
          pcall(cooldownFrame.SetCooldownFromDurationObject, cooldownFrame, dur)
          return
        end
      end
      -- Cannot build a zero duration object — fall through to legacy path.
    else
      local createDur = rawget(_G, "CreateCooldownDuration")
      if type(createDur) == "function" then
        local ok, dur = pcall(createDur, start, duration)
        if ok and dur then
          pcall(cooldownFrame.SetCooldownFromDurationObject, cooldownFrame, dur)
          return
        end
      end
      -- Duration object creation failed — fall through to legacy path.
    end
  end

  -- Legacy path: CooldownFrame_Set (may route through ActionButton_ApplyCooldown).
  local cooldownFrameSet = rawget(_G, "CooldownFrame_Set")
  if type(cooldownFrameSet) == "function" then
    cooldownFrameSet(cooldownFrame, start, duration, enabled)
    return
  end

  -- Last-resort fallback: direct SetCooldown with non-secret values only.
  if cooldownFrame.SetCooldown then
    if enabled == false or enabled == 0 or not duration or duration <= 0 then
      cooldownFrame:SetCooldown(0, 0)
    else
      cooldownFrame:SetCooldown(start or 0, duration or 0)
    end
  end
end

function SpellUtils.IsSpellKnownSafe(spellID)
  if not spellID then
    return false
  end

  local cSpellBook = rawget(_G, "C_SpellBook")
  if type(cSpellBook) == "table" then
    if type(cSpellBook.IsSpellInSpellBook) == "function" then
      local ok, known = pcall(cSpellBook.IsSpellInSpellBook, spellID)
      if ok and known == true then
        RecordVerifiedAccountTeleportSpell(spellID)
        return true
      end
    end
    if type(cSpellBook.IsSpellKnownOrOverridesKnown) == "function" then
      local ok, known = pcall(cSpellBook.IsSpellKnownOrOverridesKnown, spellID)
      if ok and known == true then
        RecordVerifiedAccountTeleportSpell(spellID)
        return true
      end
    end
    if type(cSpellBook.IsSpellKnown) == "function" then
      local ok, known = pcall(cSpellBook.IsSpellKnown, spellID)
      if ok and known == true then
        RecordVerifiedAccountTeleportSpell(spellID)
        return true
      end
    end
  end

  -- Fallback: If the spell has a duration > 2s (ignoring GCD), it must be known/active.
  -- This fixes highlighting disappearing when the spell is on cooldown.
  local _, duration = SpellUtils.GetSpellCooldownSafe(spellID)
  if duration and duration > TELEPORT_MEANINGFUL_COOLDOWN_MIN_SECONDS then
    return true
  end

  return IsPersistedAccountTeleportSpell(spellID)
end

function SpellUtils.GetTeleportCooldownRemaining(spellID)
  local start, duration, enabled = SpellUtils.GetSpellCooldownSafe(spellID)
  if enabled == false or enabled == 0 then
    return 0
  end
  if duration <= TELEPORT_MEANINGFUL_COOLDOWN_MIN_SECONDS then
    return 0
  end
  if duration <= 0 or start <= 0 then
    return 0
  end
  local getTimeFn = rawget(_G, "GetTime")
  local now = type(getTimeFn) == "function" and getTimeFn() or 0
  local remaining = (start + duration) - now
  if remaining < 0 then
    remaining = 0
  end
  remaining = SpellUtils.NormalizeTeleportCooldownRemaining(remaining, duration)
  return remaining
end

function SpellUtils.FormatCooldownSeconds(sec)
  sec = math.ceil(sec or 0)
  local totalMinutes = math.floor(sec / 60)
  local h = math.floor(totalMinutes / 60)
  local m = totalMinutes % 60
  return string.format("%02d:%02d", h, m)
end
