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

-- One stored key is not enough state for this: two priests infusing different
-- targets in the same window would evict each other, and an A -> B -> A
-- sequence would let the repeat of A through. Keep every announce still inside
-- the window instead. The list cannot grow meaningfully -- it is pruned by the
-- window on every call and hard-capped below.
local POWER_INFUSION_ANNOUNCE_HISTORY_LIMIT = 8

-- Name matching has to tolerate three different levels of knowledge about the
-- same player:
--   * the local aura scan resolves a unit token, often to a bare "Name"
--   * the sync payload carries the priest's own "Name-Realm"
--   * either side may fail to resolve the caster at all -- 12.1 masks the aura
--     source unit inside instances, which is exactly where this runs
-- So: two names with a realm each are compared in full, which keeps same-named
-- priests from different realms apart. If only one carries a realm, the base
-- names decide. An unresolved name matches anything, because a duplicate we
-- cannot name is still a duplicate -- and a silent double announce is what
-- this whole latch exists to prevent.
local function SplitAnnounceName(name)
  if type(name) ~= "string" or name == "" then
    return nil, nil
  end
  local lowered = string.lower(name)
  local dash = string.find(lowered, "-", 1, true)
  if not dash then
    return lowered, nil
  end
  return string.sub(lowered, 1, dash - 1), string.sub(lowered, dash + 1)
end

-- A wildcard match is a one-time concession, not a permanent property of the
-- history entry. Once the peer payload names the priest the local scan could
-- not resolve, the entry has to adopt that identity -- otherwise it keeps
-- absorbing every later cast on the same target, and a second priest's
-- infusion disappears silently. The same applies to a name that gains its
-- realm segment.
local function RefineAnnounceName(stored, incoming)
  local storedBase, storedRealm = SplitAnnounceName(stored)
  local incomingBase, incomingRealm = SplitAnnounceName(incoming)
  if not incomingBase then
    return stored
  end
  if not storedBase then
    return incoming
  end
  if storedRealm == nil and incomingRealm ~= nil then
    return incoming
  end
  return stored
end

local function AnnounceNamesMatch(left, right)
  local leftBase, leftRealm = SplitAnnounceName(left)
  local rightBase, rightRealm = SplitAnnounceName(right)
  if not leftBase or not rightBase then
    return true
  end
  if leftBase ~= rightBase then
    return false
  end
  if leftRealm and rightRealm then
    return leftRealm == rightRealm
  end
  return true
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
  local recentPowerInfusionAnnounces = {}

  -- Fails open: without a usable clock the announce goes out. A missed Power
  -- Infusion call is worse than a repeated one.
  local function IsDuplicatePowerInfusionAnnounce(casterName, recipientName)
    local now = ReadAnnounceTime()
    if not now then
      return false
    end

    local kept = {}
    local matched = nil
    for _, entry in ipairs(recentPowerInfusionAnnounces) do
      if now - entry.at < POWER_INFUSION_ANNOUNCE_DEDUPE_SECONDS then
        kept[#kept + 1] = entry
        if
          not matched
          and AnnounceNamesMatch(entry.recipient, recipientName)
          and AnnounceNamesMatch(entry.caster, casterName)
        then
          matched = entry
        end
      end
    end

    if matched then
      matched.caster = RefineAnnounceName(matched.caster, casterName)
      matched.recipient = RefineAnnounceName(matched.recipient, recipientName)
    else
      kept[#kept + 1] = { caster = casterName, recipient = recipientName, at = now }
      while #kept > POWER_INFUSION_ANNOUNCE_HISTORY_LIMIT do
        table.remove(kept, 1)
      end
    end
    recentPowerInfusionAnnounces = kept
    return matched ~= nil
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
