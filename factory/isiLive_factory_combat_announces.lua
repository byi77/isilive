local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- Strips the "-Realm" suffix from a player name so the chat output reads
-- naturally on the local realm. Cross-realm names keep their realm segment.
local function FormatDisplayName(name)
  if type(name) ~= "string" or name == "" then
    return "?"
  end
  local dash = string.find(name, "-", 1, true)
  if not dash then
    return name
  end
  return string.sub(name, 1, dash - 1)
end

local function PlayCombatAnnounceSound(kind)
  local soundUtils = addonTable.SoundUtils
  if type(soundUtils) ~= "table" then
    return
  end
  if kind == "BR" and type(soundUtils.PlayBattleRes) == "function" then
    soundUtils.PlayBattleRes()
  elseif kind == "LUST" and type(soundUtils.PlayBloodlust) == "function" then
    soundUtils.PlayBloodlust()
  end
end

local function IsMplusTimerRunning()
  local mplusTimer = addonTable.MplusTimer
  if type(mplusTimer) ~= "table" or type(mplusTimer.GetTimerData) ~= "function" then
    return false
  end
  local data = mplusTimer.GetTimerData()
  return type(data) == "table" and data.running == true
end

local function InitializeFactoryCombatAnnounceControllers(ctx)
  -- Renders a BR/Lust combat announcement locally via ctx.Print. Used both for
  -- the local self-cast and for incoming addon-message broadcasts from isiLive
  -- peers. Locale-resolved so each receiver renders in its own client locale.
  ctx.ShowCombatAnnounce = function(info)
    if type(info) ~= "table" then
      return
    end
    local L = ctx.GetL and ctx.GetL() or {}
    local template
    if info.kind == "BR" then
      template = L.COMBAT_CHAT_BR_USED or "%s used BR"
    elseif info.kind == "LUST" then
      template = L.COMBAT_CHAT_LUST_STARTED or "%s started Bloodlust"
    else
      return
    end
    PlayCombatAnnounceSound(info.kind)
    ctx.Print(string.format(template, FormatDisplayName(info.caster)))
  end

  -- Self-cast detected by combat_events: render locally and broadcast to all
  -- isiLive peers via the addon-message channel. Non-isiLive players see
  -- nothing; 12.0 protected chat zones must not go through SendChatMessage.
  ctx.BroadcastCombatAnnounce = function(kind, sourceName, spellID)
    local info = { kind = kind, caster = sourceName, spellID = spellID }
    ctx.ShowCombatAnnounce(info)
    if ctx.modules and ctx.modules.sync and type(ctx.modules.sync.SendCombatAnnounce) == "function" then
      ctx.modules.sync.SendCombatAnnounce(info)
    end
  end

  local combatEvents = addonTable.CombatEvents
  if type(combatEvents) == "table" and type(combatEvents.SetDependencies) == "function" then
    combatEvents.SetDependencies({
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
      broadcastCombatAnnounce = ctx.BroadcastCombatAnnounce,
    })
  end
end

FI.InitializeFactoryCombatAnnounceControllers = InitializeFactoryCombatAnnounceControllers

return {
  InitializeFactoryCombatAnnounceControllers = InitializeFactoryCombatAnnounceControllers,
}
