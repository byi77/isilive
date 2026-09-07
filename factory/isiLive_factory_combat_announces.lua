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

local function PlayPowerInfusionReceivedSound()
  local soundUtils = addonTable.SoundUtils
  if type(soundUtils) == "table" and type(soundUtils.PlayPowerInfusionReceived) == "function" then
    soundUtils.PlayPowerInfusionReceived()
  end
end

-- A recipient learns about the same Power Infusion twice: their own aura scan
-- sees the buff, and the casting priest's addon-message arrives a few frames
-- later. PiTracker's latch only covers its own two local detection paths, so
-- the sync arrival announced a second time -- same line, same sound.
-- Every path funnels through ShowPowerInfusionAnnounce, so the latch belongs
-- here rather than in one of the producers.
--
-- The window sits between the buff duration (20s) and the spell cooldown
-- (2min): a genuine second Power Infusion on the same target from the same
-- priest cannot land inside it.
local POWER_INFUSION_ANNOUNCE_DEDUPE_SECONDS = 25

-- The two paths disagree about name format: the local scan resolves the caster
-- from a unit token (often bare "Name"), the sync payload carries whatever the
-- priest's client produced (often "Name-Realm"). Comparing them raw would miss
-- every cross-realm duplicate, which is precisely where groups mix realms. The
-- realm segment is therefore dropped for the key only -- the rendered text
-- still uses the name as received. Two priests whose base names match exactly,
-- in one group, within 25 seconds, would collapse into one announce; that is
-- rarer than the format mismatch this avoids.
local function BuildPowerInfusionAnnounceKey(casterName, recipientName)
  local function KeyPart(name)
    if type(name) ~= "string" or name == "" then
      return ""
    end
    local dash = string.find(name, "-", 1, true)
    local base = dash and string.sub(name, 1, dash - 1) or name
    return string.lower(base)
  end
  return KeyPart(casterName) .. ">" .. KeyPart(recipientName)
end

local function ReadAnnounceTime()
  local fn = rawget(_G, "GetTime")
  if type(fn) ~= "function" then
    return nil
  end
  local ok, now = pcall(fn)
  if not ok then
    return nil
  end
  now = tonumber(now)
  if not now or now <= 0 then
    return nil
  end
  return now
end

local ContextHelpers = addonTable.ContextHelpers or {}
local IsMplusTimerRunning = ContextHelpers.IsMplusTimerRunning
local IsTrackedPartyRunActive = ContextHelpers.IsTrackedPartyRunActive

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

  -- Latch state for the cross-path duplicate above. Per context, so a demo or
  -- a test that builds a fresh context starts clean.
  local lastPowerInfusionAnnounceKey = nil
  local lastPowerInfusionAnnounceAt = nil

  -- Fails open: without a usable clock the announce goes out. A missed Power
  -- Infusion call is worse than a repeated one.
  local function IsDuplicatePowerInfusionAnnounce(casterName, recipientName)
    local now = ReadAnnounceTime()
    if not now then
      return false
    end
    local key = BuildPowerInfusionAnnounceKey(casterName, recipientName)
    if
      lastPowerInfusionAnnounceKey == key
      and lastPowerInfusionAnnounceAt
      and now - lastPowerInfusionAnnounceAt < POWER_INFUSION_ANNOUNCE_DEDUPE_SECONDS
    then
      return true
    end
    lastPowerInfusionAnnounceKey = key
    lastPowerInfusionAnnounceAt = now
    return false
  end

  ctx.ShowPowerInfusionAnnounce = function(infoOrCasterName, recipientName, isLocalRecipient, bypassDedupe)
    local casterName = infoOrCasterName
    if type(infoOrCasterName) == "table" then
      casterName = infoOrCasterName.caster
      recipientName = infoOrCasterName.recipient
      isLocalRecipient = infoOrCasterName.isLocalRecipient == true
    end
    if bypassDedupe ~= true and IsDuplicatePowerInfusionAnnounce(casterName, recipientName) then
      return
    end
    if isLocalRecipient == true then
      PlayPowerInfusionReceivedSound()
    end

    local db = rawget(_G, "IsiLiveDB")
    if type(db) ~= "table" or db.powerInfusionTextEnabled ~= false then
      local L = ctx.GetL and ctx.GetL() or {}
      local template = L.COMBAT_CHAT_PI_RECEIVED or "%s empowered %s with PI"
      ctx.Print(string.format(template, FormatDisplayName(casterName), FormatDisplayName(recipientName)))
    end

    if isLocalRecipient == true and (type(db) ~= "table" or db.powerInfusionTextEnabled ~= false) then
      local deathAlert = addonTable.DeathAlert
      if type(deathAlert) == "table" and type(deathAlert.ShowPowerInfusion) == "function" then
        deathAlert.ShowPowerInfusion()
      end
    end
  end

  ctx.BroadcastPowerInfusionAnnounce = function(casterName, recipientName, isLocalRecipient)
    ctx.ShowPowerInfusionAnnounce(casterName, recipientName, isLocalRecipient)
    if ctx.modules and ctx.modules.sync and type(ctx.modules.sync.SendPowerInfusionAnnounce) == "function" then
      ctx.modules.sync.SendPowerInfusionAnnounce({
        caster = casterName,
        recipient = recipientName,
        spellID = 10060,
      })
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
        if IsTrackedPartyRunActive(ctx) then
          return true
        end
        -- secret-value-ok: ctx wrapper is pcall-protected.
        return type(ctx.GetActiveChallengeMapID) == "function" and ctx.GetActiveChallengeMapID() ~= nil
      end,
      broadcastCombatAnnounce = ctx.BroadcastCombatAnnounce,
    })
  end

  local piTracker = addonTable.PiTracker
  if type(piTracker) == "table" and type(piTracker.SetDependencies) == "function" then
    piTracker.SetDependencies({
      announcePowerInfusion = function(casterName, recipientName, isLocalRecipient, isLocalCaster)
        if isLocalCaster == true then
          ctx.BroadcastPowerInfusionAnnounce(casterName, recipientName, isLocalRecipient)
        else
          ctx.ShowPowerInfusionAnnounce(casterName, recipientName, isLocalRecipient)
        end
      end,
    })
  end

  local vipDkAssist = addonTable.VipDkAssist
  if type(vipDkAssist) == "table" and type(vipDkAssist.SetDependencies) == "function" then
    vipDkAssist.SetDependencies({
      getDB = function()
        return rawget(_G, "IsiLiveDB") or {}
      end,
      getL = ctx.GetL,
    })
  end

  local bloodlustWarning = addonTable.BloodlustButtonWarning
  if type(bloodlustWarning) == "table" and type(bloodlustWarning.SetDependencies) == "function" then
    bloodlustWarning.SetDependencies({
      getDB = function()
        return rawget(_G, "IsiLiveDB") or {}
      end,
    })
  end
end

FI.InitializeFactoryCombatAnnounceControllers = InitializeFactoryCombatAnnounceControllers

return {
  InitializeFactoryCombatAnnounceControllers = InitializeFactoryCombatAnnounceControllers,
}
