local _, addonTable = ...

addonTable = addonTable or {}

local SpellUtils = {}
addonTable.SpellUtils = SpellUtils
local TELEPORT_MEANINGFUL_COOLDOWN_MIN_SECONDS = 2

function SpellUtils.GetSpellCooldownSafe(spellID)
  if not spellID or not (C_Spell and C_Spell.GetSpellCooldown) then
    return 0, 0, true
  end
  local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
  if not ok or type(info) ~= "table" then
    return 0, 0, true
  end
  local start = info.startTime or 0
  local duration = info.duration or 0
  local enabled = info.isEnabled

  -- WoW internal bug workaround: GetSpellCooldown can return opaque
  -- "SecretValue" types in some builds that bypass normal Lua type checks.
  -- issecretvalue() detects these and replaces them with safe defaults.
  if _G.issecretvalue then
    ---@diagnostic disable-next-line: param-type-mismatch
    if _G.issecretvalue(enabled) then
      enabled = true
    end
    ---@diagnostic disable-next-line: param-type-mismatch
    if _G.issecretvalue(start) then
      start = 0
    end
    ---@diagnostic disable-next-line: param-type-mismatch
    if _G.issecretvalue(duration) then
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

  if C_SpellBook and C_SpellBook.IsSpellKnownOrOverridesKnown then
    local ok, known = pcall(C_SpellBook.IsSpellKnownOrOverridesKnown, spellID)
    if ok and known == true then
      return true
    end
  end
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
    if ok and known == true then
      return true
    end
  end

  -- Fallback: If the spell has a duration > 2s (ignoring GCD), it must be known/active.
  -- This fixes highlighting disappearing when the spell is on cooldown.
  local _, duration = SpellUtils.GetSpellCooldownSafe(spellID)
  if duration and duration > TELEPORT_MEANINGFUL_COOLDOWN_MIN_SECONDS then
    return true
  end

  return false
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
  local remaining = (start + duration) - GetTime()
  if remaining < 0 then
    remaining = 0
  end
  return remaining
end

function SpellUtils.FormatCooldownSeconds(sec)
  sec = math.ceil(sec or 0)
  local totalMinutes = math.floor(sec / 60)
  local h = math.floor(totalMinutes / 60)
  local m = totalMinutes % 60
  return string.format("%02d:%02d", h, m)
end
