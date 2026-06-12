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

local function PlayRoleDeathSound(role)
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
  local deathAlert = addonTable.DeathAlert
  if type(deathAlert) == "table" and type(deathAlert.SetDependencies) == "function" then
    deathAlert.SetDependencies({
      getL = function()
        return ctx.GetL and ctx.GetL() or {}
      end,
    })
  end

  -- Local-only render: each isiLive client observes UNIT_HEALTH for its own
  -- party units, so a tank / healer death needs no addon-message broadcast.
  ctx.ShowRoleDeathAlert = function(role, _unit)
    if type(deathAlert) == "table" and type(deathAlert.ShowRoleDeath) == "function" then
      deathAlert.ShowRoleDeath(role)
    end
    PlayRoleDeathSound(role)
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
      onRoleDeath = ctx.ShowRoleDeathAlert,
    })
  end
end

FI.InitializeFactoryDeathAlertControllers = InitializeFactoryDeathAlertControllers

return {
  InitializeFactoryDeathAlertControllers = InitializeFactoryDeathAlertControllers,
}
