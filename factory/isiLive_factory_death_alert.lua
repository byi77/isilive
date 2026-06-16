local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local DEATH_ALERT_DUPLICATE_WINDOW_SECONDS = 1

local function IsMplusTimerRunning()
  local mplusTimer = addonTable.MplusTimer
  if type(mplusTimer) ~= "table" or type(mplusTimer.GetTimerData) ~= "function" then
    return false
  end
  local data = mplusTimer.GetTimerData()
  return type(data) == "table" and data.running == true
end

-- Static WAV only. The bundled death WAVs exist for tank and healer; damage
-- dealer deaths keep their DeathWatch counting path but have no audio asset.
local function PlayRoleDeathSound(role, opts)
  if type(opts) == "table" and opts.suppressAudio == true then
    return
  end
  local soundUtils = addonTable.SoundUtils
  if type(soundUtils) ~= "table" then
    return
  end
  if role == "TANK" and type(soundUtils.PlayTankDied) == "function" then
    soundUtils.PlayTankDied()
  elseif role == "HEALER" and type(soundUtils.PlayHealerDied) == "function" then
    soundUtils.PlayHealerDied()
  end
end

local function InitializeFactoryDeathAlertControllers(ctx)
  local lastRoleAlertAt = {}
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
  ctx.ShowRoleDeathAlert = function(role, _unit, opts)
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
    PlayRoleDeathSound(role, opts)
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
