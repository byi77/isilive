local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local DEATH_ALERT_DUPLICATE_WINDOW_SECONDS = 1
-- Death announcements play one after another instead of overlapping: the
-- longest bundled death WAV (TankDied.wav / HealerDied.wav) runs 1.1 s, so the
-- next one starts 1.25 s after the previous one began.
local DEATH_SOUND_SPACING_SECONDS = 1.25

local OWN_DEATH_SOUND_SETTINGS = {
  TANK = "soundOwnTankDiedEnabled",
  HEALER = "soundOwnHealerDiedEnabled",
}

local ContextHelpers = addonTable.ContextHelpers or {}
local IsMplusTimerRunning = ContextHelpers.IsMplusTimerRunning
local IsTrackedPartyRunActive = ContextHelpers.IsTrackedPartyRunActive

local ROLE_DEATH_SOUND_KEYS = {
  TANK = "tank_died",
  HEALER = "healer_died",
}

-- True when a death announcement will actually play, so only those take a
-- slot in the sequential queue (damage-dealer deaths have no WAV).
local function WillPlayRoleDeathSound(role, unit)
  local soundKey = ROLE_DEATH_SOUND_KEYS[role]
  if not soundKey then
    return false
  end
  if unit == "player" then
    local db = rawget(_G, "IsiLiveDB")
    local settingKey = OWN_DEATH_SOUND_SETTINGS[role]
    if type(db) == "table" and db[settingKey] == false then
      return false
    end
  end
  local soundUtils = addonTable.SoundUtils
  if type(soundUtils) ~= "table" then
    return false
  end
  return type(soundUtils.IsEnabled) ~= "function" or soundUtils.IsEnabled(soundKey) == true
end

-- Static WAV only. The bundled death WAVs exist for tank and healer; damage
-- dealer deaths keep their DeathWatch counting path but have no audio asset.
local function PlayRoleDeathSound(role, opts)
  if type(opts) == "table" and opts.unit == "player" then
    local settingKey = OWN_DEATH_SOUND_SETTINGS[role]
    local db = rawget(_G, "IsiLiveDB")
    if type(settingKey) == "string" and type(db) == "table" and db[settingKey] == false then
      return
    end
  end
  local soundUtils = addonTable.SoundUtils
  if type(soundUtils) ~= "table" then
    return
  end
  local played = nil
  if role == "TANK" and type(soundUtils.PlayTankDied) == "function" then
    played = soundUtils.PlayTankDied()
  elseif role == "HEALER" and type(soundUtils.PlayHealerDied) == "function" then
    played = soundUtils.PlayHealerDied()
  end
  if played == false and (role == "TANK" or role == "HEALER") and type(soundUtils.GetLastPlayResult) == "function" then
    local result = soundUtils.GetLastPlayResult()
    local path = type(result) == "table" and result.path or nil
    local channel = type(result) == "table" and result.channel or nil
    local reason = type(result) == "table" and result.reason or "unknown"
    local printFn = rawget(_G, "print")
    if type(printFn) == "function" then
      printFn(
        string.format(
          "|cffffd200isiLive|r death sound failed role=%s reason=%s channel=%s path=%s",
          tostring(role),
          tostring(reason),
          tostring(channel),
          tostring(path)
        )
      )
    end
  end
end

local function InitializeFactoryDeathAlertControllers(ctx)
  local lastRoleAlertAt = {}
  -- GetTime at which the death-sound slot is free again.
  local deathSoundFreeAt = 0

  -- A tank death followed by a healer death plays both announcements, the
  -- second once the first has finished.
  local function QueueRoleDeathSound(role, opts, now)
    if not WillPlayRoleDeathSound(role, opts.unit) then
      return
    end
    local timer = rawget(_G, "C_Timer")
    local delay = now and (deathSoundFreeAt - now) or 0
    if delay <= 0 or type(timer) ~= "table" or type(timer.After) ~= "function" then
      if now then
        deathSoundFreeAt = now + DEATH_SOUND_SPACING_SECONDS
      end
      PlayRoleDeathSound(role, opts)
      return
    end
    deathSoundFreeAt = deathSoundFreeAt + DEATH_SOUND_SPACING_SECONDS
    timer.After(delay, function()
      PlayRoleDeathSound(role, opts)
    end)
  end
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
  -- shows the role-only text without a name; damage-dealer deaths have no
  -- bundled WAV asset and stay audio-silent.
  ctx.ShowRoleDeathAlert = function(role, unit, opts)
    local GetTime_ref = rawget(_G, "GetTime")
    local now = type(GetTime_ref) == "function" and tonumber(GetTime_ref()) or nil
    if now and (role == "TANK" or role == "HEALER") then
      local last = lastRoleAlertAt[role]
      if last and (now - last) < DEATH_ALERT_DUPLICATE_WINDOW_SECONDS then
        return
      end
      lastRoleAlertAt[role] = now
    end

    if
      (role == "TANK" or role == "HEALER")
      and type(deathAlert) == "table"
      and type(deathAlert.ShowRoleDeath) == "function"
    then
      deathAlert.ShowRoleDeath(role)
    end
    opts = type(opts) == "table" and opts or {}
    opts.unit = unit
    QueueRoleDeathSound(role, opts, now)
  end

  -- Rule 168: on a key start (death alerts enabled) the alert frame is built
  -- one second later from a timer callback -- outside the protected
  -- CHALLENGE_MODE_START dispatch and only when not in combat. A pull inside
  -- that second simply leaves the lazy build in ShowAlertKind as fallback.
  local function ScheduleDeathAlertPrebuild()
    if type(deathAlert) ~= "table" or type(deathAlert.Prebuild) ~= "function" then
      return
    end
    local timer = rawget(_G, "C_Timer")
    if type(timer) ~= "table" or type(timer.After) ~= "function" then
      return
    end
    timer.After(1, function()
      local inCombat = rawget(_G, "InCombatLockdown")
      if type(inCombat) == "function" and inCombat() then
        return
      end
      deathAlert.Prebuild()
    end)
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
        if IsTrackedPartyRunActive(ctx) then
          return true
        end
        -- secret-value-ok: ctx wrapper is pcall-protected.
        return type(ctx.GetActiveChallengeMapID) == "function" and ctx.GetActiveChallengeMapID() ~= nil
      end,
      getUnitRole = type(ctx.getUnitRole) == "function" and ctx.getUnitRole or nil,
      getUnitNameAndRealm = type(ctx.GetUnitNameAndRealm) == "function" and ctx.GetUnitNameAndRealm or nil,
      onRoleDeath = ctx.ShowRoleDeathAlert,
      onChallengeStart = ScheduleDeathAlertPrebuild,
    })
  end
end

FI.InitializeFactoryDeathAlertControllers = InitializeFactoryDeathAlertControllers

return {
  InitializeFactoryDeathAlertControllers = InitializeFactoryDeathAlertControllers,
}
