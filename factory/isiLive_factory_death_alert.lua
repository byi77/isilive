local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local function IsMplusTimerRunning()
  local mplusTimer = addonTable.MplusTimer
  if type(mplusTimer) ~= "table" or type(mplusTimer.GetTimerData) ~= "function" then
    return false
  end
  local data = mplusTimer.GetTimerData()
  return type(data) == "table" and data.running == true
end

local function IsSecretValue(value)
  local issecretvalue = rawget(_G, "issecretvalue")
  return type(issecretvalue) == "function" and issecretvalue(value) == true
end

-- Resolves the plain unit name for a TTS announcement. Secret-value-guarded:
-- masked names (Blizzard's protected-data system) and blanks yield nil so the
-- caller falls back to a nameless announcement instead of speaking garbage.
local function ResolveUnitDisplayName(unit)
  if type(unit) ~= "string" or unit == "" then
    return nil
  end
  local unitName = rawget(_G, "UnitName")
  if type(unitName) ~= "function" then
    return nil
  end
  local ok, name = pcall(unitName, unit)
  if not ok or IsSecretValue(name) or type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

local ROLE_WORD_KEY = {
  TANK = "TTS_ROLE_TANK",
  HEALER = "TTS_ROLE_HEALER",
  DAMAGER = "TTS_ROLE_DAMAGER",
}

-- Resolves the localized class name (e.g. "Hunter" / "Jaeger") for a spoken
-- class announcement. Secret-value-guarded like the name lookup.
local function ResolveUnitClassName(unit)
  if type(unit) ~= "string" or unit == "" then
    return nil
  end
  local unitClass = rawget(_G, "UnitClass")
  if type(unitClass) ~= "function" then
    return nil
  end
  local ok, localizedClass = pcall(unitClass, unit)
  if not ok or IsSecretValue(localizedClass) or type(localizedClass) ~= "string" or localizedClass == "" then
    return nil
  end
  return localizedClass
end

-- The "who" part of the announcement: the class name when class announcements
-- are on (and resolvable), otherwise the localized role word. Falls back to
-- the role word when the class cannot be read.
local function ResolveDescriptor(role, unit, L, announceClass)
  if announceClass or role == "DAMAGER" then
    local className = ResolveUnitClassName(unit)
    if className then
      return className
    end
  end
  local key = ROLE_WORD_KEY[role]
  if key and type(L[key]) == "string" and L[key] ~= "" then
    return L[key]
  end
  return nil
end

-- Builds the spoken death text from two locale templates and the resolved
-- descriptor: "<name>, <descriptor>, died" when names are on and the name
-- resolves, otherwise "<descriptor> died" (e.g. "Tank died" / "Hunter died").
local function BuildRoleDeathTtsText(role, unit, getL, announceName, announceClass)
  local L = type(getL) == "function" and getL() or {}
  local descriptor = ResolveDescriptor(role, unit, L, announceClass)
  if not descriptor then
    return nil
  end
  if announceName then
    local name = ResolveUnitDisplayName(unit)
    if name and type(L.TTS_NAMED_DIED_FMT) == "string" and L.TTS_NAMED_DIED_FMT ~= "" then
      return string.format(L.TTS_NAMED_DIED_FMT, name, descriptor)
    end
  end
  if type(L.TTS_DIED_FMT) == "string" and L.TTS_DIED_FMT ~= "" then
    return string.format(L.TTS_DIED_FMT, descriptor)
  end
  return nil
end

-- Spoken-TTS-first, WAV fallback. When TTS announcements are enabled and the
-- engine speaks the configured text, no recorded file is played. The recorded
-- WAV only exists for tank/healer, so a damage-dealer death is silent unless
-- TTS speaks it. The deathAlertEnabled gate already passed upstream in
-- DeathWatch, so this only chooses the audio form.
local function PlayRoleDeathSound(role, unit, getL, opts)
  local soundUtils = addonTable.SoundUtils
  if type(soundUtils) ~= "table" then
    return
  end
  local suppressTts = type(opts) == "table" and opts.suppressTts == true
  local isSelfDeath = unit == "player"
  if
    type(soundUtils.IsTtsEnabled) == "function"
    and soundUtils.IsTtsEnabled()
    and type(soundUtils.SpeakTts) == "function"
  then
    if suppressTts or isSelfDeath then
      return
    end
    local announceName = type(soundUtils.ShouldAnnounceName) ~= "function" or soundUtils.ShouldAnnounceName()
    local announceClass = type(soundUtils.ShouldAnnounceClass) == "function" and soundUtils.ShouldAnnounceClass()
    local text = BuildRoleDeathTtsText(role, unit, getL, announceName, announceClass)
    if text and soundUtils.SpeakTts(text, { spamScope = "death:" .. tostring(role) }) then
      return
    end
  end
  if role == "TANK" and type(soundUtils.PlayTankDied) == "function" then
    soundUtils.PlayTankDied()
  elseif role == "HEALER" and type(soundUtils.PlayHealerDied) == "function" then
    soundUtils.PlayHealerDied()
  end
end

local function InitializeFactoryDeathAlertControllers(ctx)
  local deathAlert = addonTable.DeathAlert
  if type(deathAlert) == "table" and type(deathAlert.SetDependencies) == "function" then
    deathAlert.SetDependencies({
      getL = function()
        return ctx.GetL and ctx.GetL() or {}
      end,
    })
  end

  -- Local-only render: each isiLive client observes UNIT_HEALTH for its own
  -- party units, so a death needs no addon-message broadcast. The big red
  -- on-screen warning is intentionally limited to tank/healer and always
  -- shows the role-only text without a name; damage-dealer deaths only ever
  -- produce a spoken announcement.
  ctx.ShowRoleDeathAlert = function(role, unit, opts)
    if
      (role == "TANK" or role == "HEALER")
      and type(deathAlert) == "table"
      and type(deathAlert.ShowRoleDeath) == "function"
    then
      deathAlert.ShowRoleDeath(role)
    end
    PlayRoleDeathSound(role, unit, ctx.GetL, opts)
  end

  local deathWatch = addonTable.DeathWatch
  if type(deathWatch) == "table" and type(deathWatch.SetDependencies) == "function" then
    deathWatch.SetDependencies({
      getDB = function()
        return rawget(_G, "IsiLiveDB") or {}
      end,
      isInKey = function()
        if IsMplusTimerRunning() then
          return true
        end
        -- secret-value-ok: ctx wrapper is pcall-protected.
        return type(ctx.GetActiveChallengeMapID) == "function" and ctx.GetActiveChallengeMapID() ~= nil
      end,
      getUnitRole = type(ctx.getUnitRole) == "function" and ctx.getUnitRole or nil,
      getUnitNameAndRealm = type(ctx.GetUnitNameAndRealm) == "function" and ctx.GetUnitNameAndRealm or nil,
      onRoleDeath = ctx.ShowRoleDeathAlert,
    })
  end
end

FI.InitializeFactoryDeathAlertControllers = InitializeFactoryDeathAlertControllers

return {
  InitializeFactoryDeathAlertControllers = InitializeFactoryDeathAlertControllers,
}
