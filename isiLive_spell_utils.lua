local _, addonTable = ...

addonTable = addonTable or {}

local SpellUtils = {}
addonTable.SpellUtils = SpellUtils

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

  -- WoW-interner Bug-Workaround: GetSpellCooldown kann in manchen Builds
  -- undurchsichtige "SecretValue"-Typen zurückgeben, die normale Lua-
  -- Typprüfungen umgehen. issecretvalue() erkennt diese und ersetzt sie
  -- durch sichere Standardwerte.
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

  local cooldownFrameSet = rawget(_G, "CooldownFrame_Set")
  if type(cooldownFrameSet) == "function" then
    cooldownFrameSet(cooldownFrame, start, duration, enabled)
    return
  end

  if cooldownFrame.SetCooldown then
    if enabled == false or enabled == 0 or duration <= 0 then
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
    if C_SpellBook.IsSpellKnownOrOverridesKnown(spellID) == true then
      return true
    end
  end
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    if C_SpellBook.IsSpellKnown(spellID) == true then
      return true
    end
  end

  -- Fallback: If the spell has a duration > 2s (ignoring GCD), it must be known/active.
  -- This fixes highlighting disappearing when the spell is on cooldown.
  local _, duration = SpellUtils.GetSpellCooldownSafe(spellID)
  if duration and duration > 2 then
    return true
  end

  return false
end

function SpellUtils.GetTeleportCooldownRemaining(spellID)
  local start, duration, enabled = SpellUtils.GetSpellCooldownSafe(spellID)
  if enabled == false or enabled == 0 then
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
