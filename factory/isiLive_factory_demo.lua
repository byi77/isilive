local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local FactoryDemo = {}
FI.FactoryDemo = FactoryDemo

-- Test harnesses may load this file without Validators; treat nothing as secret there.
local IsSecretValue = addonTable.Validators and addonTable.Validators.IsSecretValue
  or function(_value)
    return false
  end

-- Card triggers with live builders and real player data, see
-- isiLive_factory_demo_cards.lua.
local function Cards()
  return FI.FactoryDemoCards or {}
end

local DEMO_FEATURE_NIL = {}
local DEMO_FEATURE_NON_MYTHIC_NOTICE_DELAY_SECONDS = 8
local DEMO_FEATURE_READY_CHECK_HOLD_SECONDS = 20
-- Simulated M+ run: 13 minutes in; the limit comes from the target dungeon.
local DEMO_TIMER_ELAPSED_SECONDS = 780
local DEMO_TIMER_DEFAULT_LIMIT_SECONDS = 1800
local DEMO_FEATURE_SHARE_KEYS_COOLDOWN_SECONDS = 18
local SIMULATION_TABLET_SHARE_KEYS_COOLDOWN_SECONDS = 30
local DEMO_FEATURE_DB_KEYS = {
  "acceptedInviteNoticeEnabled",
  "groupJoinNoticeEnabled",
  "statsBoxEnabled",
  "statsBoxBgAlpha",
  "statsBoxFontSizeOffset",
  "lfgFlagsEnabled",
  "lfgGroupBonusesEnabled",
  "mobNameplateEnabled",
  "mplusForcesEstimate",
  "mobNameplateShowPercent",
  "mobNameplateShowRemaining",
  "mobNameplateFontSize",
  "mobNameplatePosition",
  "mobNameplateXOffset",
  "mobNameplateYOffset",
  "soundReadyCheckCompleteEnabled",
  "deathAlertEnabled",
  "powerInfusionTextEnabled",
  "timePaceEnabled",
}

-- Preview target: the player's own keystone, else the active season's first
-- dungeon at +15 (see FactoryDemoCards.ResolveTarget). Returns mapID, name and
-- key level; without an active season the previews render without a dungeon.
local function ResolveDemoTarget(ctx)
  local resolve = Cards().ResolveTarget
  if type(resolve) ~= "function" then
    return nil, nil, 15
  end
  return resolve(ctx)
end

local function CaptureDemoFeatureSnapshot(db)
  local snapshot = {}
  for _, key in ipairs(DEMO_FEATURE_DB_KEYS) do
    local value = db[key]
    if value == nil then
      snapshot[key] = DEMO_FEATURE_NIL
    else
      snapshot[key] = value
    end
  end
  return snapshot
end

local function RestoreDemoFeatureSnapshot(db, snapshot)
  for _, key in ipairs(DEMO_FEATURE_DB_KEYS) do
    local value = snapshot[key]
    if value == DEMO_FEATURE_NIL then
      db[key] = nil
    elseif value ~= nil then
      db[key] = value
    end
  end
end

-- The demo writes its overrides into the saved IsiLiveDB. A /reload, logout
-- or crash during the preview saved them for good: the in-memory snapshot was
-- gone, and the both-on forces flags made ApplyDBSettings migrate the user's
-- nameplate mode to "tooltip" on the next load. The pre-demo values therefore
-- also live in the DB until the preview ends normally.
local DEMO_FEATURE_SNAPSHOT_DB_KEY = "demoFeatureSnapshot"

local function PersistDemoFeatureSnapshot(db, snapshot)
  local values = {}
  local nilKeys = {}
  for _, key in ipairs(DEMO_FEATURE_DB_KEYS) do
    local value = snapshot[key]
    if value == DEMO_FEATURE_NIL then
      nilKeys[key] = true
    elseif value ~= nil then
      values[key] = value
    end
  end
  db[DEMO_FEATURE_SNAPSHOT_DB_KEY] = { values = values, nilKeys = nilKeys }
end

--- Restores pre-demo values a preview left in the saved DB (reload, logout or
--- crash while it ran). Runs on ADDON_LOADED before the schema pass; only the
--- demo-owned keys are written. Returns true when a snapshot was restored.
function FactoryDemo.RestorePersistedDemoSnapshot(db)
  if type(db) ~= "table" then
    return false
  end
  local persisted = db[DEMO_FEATURE_SNAPSHOT_DB_KEY]
  db[DEMO_FEATURE_SNAPSHOT_DB_KEY] = nil
  if type(persisted) ~= "table" then
    return false
  end
  local values = type(persisted.values) == "table" and persisted.values or {}
  local nilKeys = type(persisted.nilKeys) == "table" and persisted.nilKeys or {}
  for _, key in ipairs(DEMO_FEATURE_DB_KEYS) do
    if nilKeys[key] == true then
      db[key] = nil
    elseif values[key] ~= nil then
      db[key] = values[key]
    end
  end
  return true
end

local function ApplyDemoFeatureDbOverrides(ctx)
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return nil
  end

  if type(ctx._demoFeatureSnapshot) ~= "table" then
    ctx._demoFeatureSnapshot = CaptureDemoFeatureSnapshot(db)
    PersistDemoFeatureSnapshot(db, ctx._demoFeatureSnapshot)
  end

  db.statsBoxEnabled = true
  db.statsBoxBgAlpha = 0.35
  db.acceptedInviteNoticeEnabled = true
  db.groupJoinNoticeEnabled = true
  db.lfgFlagsEnabled = true
  db.lfgGroupBonusesEnabled = true
  db.mobNameplateEnabled = true
  db.mplusForcesEstimate = true
  db.soundReadyCheckCompleteEnabled = true
  db.deathAlertEnabled = true
  db.powerInfusionTextEnabled = true
  -- The spent-time strip on the forces bar is the only time display left
  -- besides the timer texts, so the preview always shows it.
  db.timePaceEnabled = true

  return db
end

local function ApplyDemoStatsBox(ctx)
  local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
  if type(statsBox) ~= "table" then
    return
  end

  -- The loaded character's own stats: no demo values are injected.
  if type(statsBox.ClearDemoData) == "function" then
    statsBox.ClearDemoData()
  end
  if type(statsBox.SetEnabled) == "function" then
    statsBox.SetEnabled(true)
  end
end

local function ApplyDemoLfgFlags(ctx)
  local lfgFlags = ctx.addonTable and ctx.addonTable.LFGFlags
  if type(lfgFlags) ~= "table" then
    return
  end

  if type(lfgFlags.SetEnabled) == "function" then
    lfgFlags.SetEnabled(true)
  end
  if type(lfgFlags.SetGroupBonusesEnabled) == "function" then
    lfgFlags.SetGroupBonusesEnabled(true)
  end
end

local function ApplyDemoMobForces(ctx)
  local mobTooltip = ctx.addonTable and ctx.addonTable.MobTooltip
  if type(mobTooltip) == "table" and type(mobTooltip.SetEnabled) == "function" then
    mobTooltip.SetEnabled(true)
  end

  local mobNameplate = ctx.addonTable and ctx.addonTable.MobNameplate
  if type(mobNameplate) ~= "table" then
    return
  end

  if type(mobNameplate.SetTestMode) == "function" then
    local targetMapID = ResolveDemoTarget(ctx)
    mobNameplate.SetTestMode(true, "12.34", { activeMapID = targetMapID })
  elseif type(mobNameplate.SetEnabled) == "function" then
    mobNameplate.SetEnabled(true)
  end
end

local function ApplyDemoReadyCheckPreview(ctx)
  local getTime = rawget(_G, "GetTime")
  local now = type(getTime) == "function" and tonumber(getTime()) or 0
  local holdUntil = now + DEMO_FEATURE_READY_CHECK_HOLD_SECONDS

  if type(ctx.SetReadyCheckActive) == "function" then
    ctx.SetReadyCheckActive(false)
  end
  if type(ctx.ClearAllReadyCheckReady) == "function" then
    ctx.ClearAllReadyCheckReady()
  end
  if type(ctx.ClearAllReadyCheckDeclined) == "function" then
    ctx.ClearAllReadyCheckDeclined()
  end
  if type(ctx.SetReadyCheckReadyUntil) == "function" then
    ctx.SetReadyCheckReadyUntil("player", holdUntil)
    ctx.SetReadyCheckReadyUntil("party1", holdUntil)
  end
  if type(ctx.SetReadyCheckDeclinedUntil) == "function" then
    ctx.SetReadyCheckDeclinedUntil("party2", holdUntil)
  end
  if type(ctx.RefreshReadyCheckUI) == "function" then
    ctx.RefreshReadyCheckUI()
  end
end

local function ClearDemoReadyCheckPreview(ctx)
  if type(ctx.SetReadyCheckActive) == "function" then
    ctx.SetReadyCheckActive(false)
  end
  if type(ctx.ClearAllReadyCheckReady) == "function" then
    ctx.ClearAllReadyCheckReady()
  end
  if type(ctx.ClearAllReadyCheckDeclined) == "function" then
    ctx.ClearAllReadyCheckDeclined()
  end
  if type(ctx.RefreshReadyCheckUI) == "function" then
    ctx.RefreshReadyCheckUI()
  end
end

local function ApplyDemoShareKeysCooldown(ctx)
  if type(ctx.TriggerShareKeysCooldown) == "function" then
    ctx.TriggerShareKeysCooldown(DEMO_FEATURE_SHARE_KEYS_COOLDOWN_SECONDS)
  end
end

local function ClearDemoShareKeysCooldown(ctx)
  if type(ctx.ClearShareKeysCooldown) == "function" then
    ctx.ClearShareKeysCooldown()
  end
end

local function ApplyReadyCheckActivePreview(ctx)
  if type(ctx.SetReadyCheckActive) == "function" then
    ctx.SetReadyCheckActive(true)
  end
  if type(ctx.ClearAllReadyCheckReady) == "function" then
    ctx.ClearAllReadyCheckReady()
  end
  if type(ctx.ClearAllReadyCheckDeclined) == "function" then
    ctx.ClearAllReadyCheckDeclined()
  end
  if type(ctx.RefreshReadyCheckUI) == "function" then
    ctx.RefreshReadyCheckUI()
  end
end

local function ApplyDemoAlertAndSoundPreview(ctx, _L)
  if type(ctx.ShowRoleDeathAlert) == "function" then
    ctx.ShowRoleDeathAlert("TANK", "party1")
    ctx.ShowRoleDeathAlert("DAMAGER", "party3")
  end

  if Cards().ShowPowerInfusion then
    Cards().ShowPowerInfusion(ctx)
  end

  local soundUtils = ctx.addonTable and ctx.addonTable.SoundUtils
  if type(soundUtils) ~= "table" then
    return
  end
  if type(soundUtils.PlayReadyCheckComplete) == "function" then
    soundUtils.PlayReadyCheckComplete()
  end
end

-- The demo navigator reuses the live layout builder, so it mirrors the active
-- season's portal-room slots (including unoccupied ones) and fails closed the
-- same way when the season has no complete navigator config.
local function ShowDemoPortalNavigator(ctx, L)
  if type(ctx.ShowPortalNavigatorNotice) ~= "function" then
    return
  end

  local status = ctx.addonTable and ctx.addonTable.Status
  if type(status) ~= "table" or type(status.BuildPortalNavigatorLayout) ~= "function" then
    return
  end

  local teleport = ctx.modules and ctx.modules.teleport
  local layout = status.BuildPortalNavigatorLayout({
    getL = function()
      return L
    end,
    getLocaleTag = function()
      return ctx.GetActiveLocaleTag()
    end,
    getTeleportInfoByMapID = type(teleport) == "table" and teleport.GetTeleportInfoByMapID or nil,
  })
  if type(layout) == "table" then
    ctx.ShowPortalNavigatorNotice(layout)
  end
end

local function ApplyDemoFeatureData(ctx)
  ctx._demoFeatureActive = true
  ApplyDemoFeatureDbOverrides(ctx)
  ApplyDemoStatsBox(ctx)
  ApplyDemoLfgFlags(ctx)
  ApplyDemoMobForces(ctx)
  ApplyDemoReadyCheckPreview(ctx)
  ApplyDemoShareKeysCooldown(ctx)

  local L = ctx.GetL and ctx.GetL() or {}
  ApplyDemoAlertAndSoundPreview(ctx, L)
  ShowDemoPortalNavigator(ctx, L)
  -- The talent & loot check stays behind tablet action C6: at its live
  -- position it would cover the portal navigator. The invite card below
  -- still carries its live "Loadout" row.
  local cards = Cards()
  if type(ctx.ShowDemoCenterNotices) == "function" and cards.BuildAcceptedInviteNotice then
    ctx.ShowDemoCenterNotices({
      cards.BuildAcceptedInviteNotice(ctx, false),
      cards.BuildInstanceEntryNotice(ctx, "party"),
    })
  elseif cards.ShowAcceptedInvite then
    cards.ShowAcceptedInvite(ctx)
    local timer = rawget(_G, "C_Timer")
    if type(timer) == "table" and type(timer.After) == "function" then
      timer.After(DEMO_FEATURE_NON_MYTHIC_NOTICE_DELAY_SECONDS, function()
        if ctx._demoFeatureActive == true then
          cards.ShowInstanceEntry(ctx, "party")
        end
      end)
    else
      cards.ShowInstanceEntry(ctx, "party")
    end
  end
  if type(ctx.ShowSimulationTablet) == "function" then
    ctx.ShowSimulationTablet()
  end
end

local function RestoreDemoStatsBox(ctx)
  local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
  if type(statsBox) ~= "table" then
    return
  end

  if type(statsBox.ClearDemoData) == "function" then
    statsBox.ClearDemoData()
  end
  if type(statsBox.ApplySettings) == "function" then
    statsBox.ApplySettings()
  end
end

local function RestoreDemoMobForces(ctx, db)
  local mobTooltip = ctx.addonTable and ctx.addonTable.MobTooltip
  if type(mobTooltip) == "table" and type(mobTooltip.SetEnabled) == "function" then
    mobTooltip.SetEnabled(type(db) == "table" and db.mplusForcesEstimate == true)
  end

  local mobNameplate = ctx.addonTable and ctx.addonTable.MobNameplate
  if type(mobNameplate) ~= "table" then
    return
  end

  if type(mobNameplate.SetTestMode) == "function" then
    mobNameplate.SetTestMode(false)
  end
  if type(mobNameplate.SetFormat) == "function" then
    mobNameplate.SetFormat({
      showPercent = type(db) ~= "table" or db.mobNameplateShowPercent ~= false,
      showRemaining = type(db) == "table" and db.mobNameplateShowRemaining == true,
    })
  end
  if type(mobNameplate.SetAppearance) == "function" then
    mobNameplate.SetAppearance({
      fontSize = type(db) == "table" and tonumber(db.mobNameplateFontSize) or 14,
      position = type(db) == "table" and db.mobNameplatePosition or "RIGHT",
      xOffset = type(db) == "table" and tonumber(db.mobNameplateXOffset) or 0,
      yOffset = type(db) == "table" and tonumber(db.mobNameplateYOffset) or 0,
    })
  end
  if type(mobNameplate.SetEnabled) == "function" then
    mobNameplate.SetEnabled(type(db) == "table" and db.mobNameplateEnabled == true)
  end
end

local function RestoreDemoLfgFlags(ctx, db)
  local lfgFlags = ctx.addonTable and ctx.addonTable.LFGFlags
  if type(lfgFlags) ~= "table" then
    return
  end

  if type(lfgFlags.SetEnabled) == "function" then
    lfgFlags.SetEnabled(type(db) ~= "table" or db.lfgFlagsEnabled ~= false)
  end
  if type(lfgFlags.SetGroupBonusesEnabled) == "function" then
    lfgFlags.SetGroupBonusesEnabled(type(db) ~= "table" or db.lfgGroupBonusesEnabled ~= false)
  end
end

local function ClearDemoFeatureData(ctx)
  ctx._demoFeatureActive = false
  local soundUtils = ctx.addonTable and ctx.addonTable.SoundUtils
  if type(soundUtils) == "table" and type(soundUtils.StopAllActiveSounds) == "function" then
    soundUtils.StopAllActiveSounds()
  end
  if type(ctx.HideSimulationTablet) == "function" then
    ctx.HideSimulationTablet()
  end
  if type(ctx.SetDemoCenterNoticesVisible) == "function" then
    ctx.SetDemoCenterNoticesVisible(false)
  end
  if Cards().HideLoadoutCheck then
    Cards().HideLoadoutCheck(ctx)
  end
  local db = rawget(_G, "IsiLiveDB")
  local snapshot = ctx._demoFeatureSnapshot
  if type(db) == "table" and type(snapshot) == "table" then
    RestoreDemoFeatureSnapshot(db, snapshot)
  end
  if type(db) == "table" then
    db[DEMO_FEATURE_SNAPSHOT_DB_KEY] = nil
  end
  ctx._demoFeatureSnapshot = nil

  RestoreDemoStatsBox(ctx)
  RestoreDemoLfgFlags(ctx, db)
  RestoreDemoMobForces(ctx, db)
  ClearDemoReadyCheckPreview(ctx)
  ClearDemoShareKeysCooldown(ctx)

  if type(ctx.SetPortalNavigatorVisible) == "function" then
    ctx.SetPortalNavigatorVisible(false)
  end
end

-- Time limit of the target dungeon from the game; 30 minutes without one.
local function ResolveDemoTimeLimit(mapID)
  local challengeMode = rawget(_G, "C_ChallengeMode")
  local getMapUIInfo = type(challengeMode) == "table" and challengeMode.GetMapUIInfo or nil
  if mapID and type(getMapUIInfo) == "function" then
    local ok, _, _, timeLimit = pcall(getMapUIInfo, mapID)
    if ok and not IsSecretValue(timeLimit) and type(timeLimit) == "number" and timeLimit > 0 then
      return timeLimit
    end
  end
  return DEMO_TIMER_DEFAULT_LIMIT_SECONDS
end

local function SetDemoTimerData(ctx, runtimeState)
  local targetMapID, targetName, targetLevel = ResolveDemoTarget(ctx)
  local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
  if type(MplusTimer) == "table" and type(MplusTimer.SetDemoData) == "function" then
    -- Simulated run state (elapsed time, deaths) on the target's real time
    -- limit; the chest thresholds follow it (+2 at 80 %, +3 at 60 %).
    local timeLimit = ResolveDemoTimeLimit(targetMapID)
    local elapsed = DEMO_TIMER_ELAPSED_SECONDS
    MplusTimer.SetDemoData({
      running = true,
      completed = false,
      timer = elapsed,
      timeLimit = timeLimit,
      keyLevel = targetLevel,
      timeRemaining1 = timeLimit - elapsed,
      timeRemaining2 = math.floor(timeLimit * 0.8) - elapsed,
      timeRemaining3 = math.floor(timeLimit * 0.6) - elapsed,
      deaths = 2,
      deathTimeLost = 8,
    })
  end
  if targetMapID and type(runtimeState.SetLatestQueueState) == "function" then
    runtimeState.SetLatestQueueState(targetName, nil, nil, targetMapID)
  end
  local KillTrack = ctx.addonTable and ctx.addonTable.KillTrack
  if type(KillTrack) == "table" and type(KillTrack.SetDemoData) == "function" then
    KillTrack.SetDemoData({
      active = true,
      percent = 47.34,
      rawCount = 204,
      total = 431,
      mapID = targetMapID,
      inCombat = true,
      pullPercent = 3.21,
      -- Forces target for the next boss above the demo percent: shows the pace
      -- tick and the missing forces next to the TTK. The
      -- live pull keeps the text slot, as it does in a real run.
      paceTarget = 52.5,
      paceLaterTargets = { 72.4 },
      -- Time pace delta on the bar: ahead of the slowest timed +12.
      timePace = { mode = "reference", delta = -72, keyLevel = 12 },
    })
  end
  if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshKillTrackRow) == "function" then
    ctx.rosterPanelController.RefreshKillTrackRow()
  end
  -- cdTrackerController is created after testModeController, so always defer.
  local C_Timer_ref = rawget(_G, "C_Timer")
  if type(C_Timer_ref) == "table" and type(C_Timer_ref.After) == "function" then
    C_Timer_ref.After(0.2, function()
      if ctx.cdTrackerController and type(ctx.cdTrackerController.SetDemoData) == "function" then
        ctx.cdTrackerController.SetDemoData({
          bres = { charges = 0, maxCharges = 1, cooldownRemain = 112, cooldownDuration = 600 },
          lust = { remain = 23, duration = 600, icon = nil },
        })
      end
      if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
        ctx.rosterPanelController.RefreshCdTracker()
      end
    end)
  end
end

-- Killtracker before the key starts: the demo target stays set, the M+ timer
-- and forces go idle, so the row shows the gold empty bar with the light
-- sweep and the pulsing target. C1 brings the running key back.
local function SetDemoPreKeyData(ctx, runtimeState)
  local targetMapID, targetName, targetLevel = ResolveDemoTarget(ctx)
  if targetMapID and type(runtimeState.SetLatestQueueState) == "function" then
    runtimeState.SetLatestQueueState(targetName, nil, nil, targetMapID)
  end
  ctx._demoTargetKey = targetMapID and { mapID = targetMapID, level = targetLevel } or nil
  local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
  if type(MplusTimer) == "table" and type(MplusTimer.ClearDemoData) == "function" then
    MplusTimer.ClearDemoData()
  end
  local KillTrack = ctx.addonTable and ctx.addonTable.KillTrack
  if type(KillTrack) == "table" and type(KillTrack.SetDemoData) == "function" then
    KillTrack.SetDemoData({ active = false, percent = 0, mapID = targetMapID })
  end
  if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshKillTrackRow) == "function" then
    ctx.rosterPanelController.RefreshKillTrackRow()
  end
  if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
    ctx.rosterPanelController.RefreshCdTracker()
  end
end

local function ClearDemoTimerData(ctx)
  ctx._demoTargetKey = nil
  local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
  if type(MplusTimer) == "table" and type(MplusTimer.ClearDemoData) == "function" then
    MplusTimer.ClearDemoData()
  end
  local KillTrack = ctx.addonTable and ctx.addonTable.KillTrack
  if type(KillTrack) == "table" and type(KillTrack.ClearDemoData) == "function" then
    KillTrack.ClearDemoData()
  end
  if ctx.cdTrackerController and type(ctx.cdTrackerController.ClearDemoData) == "function" then
    ctx.cdTrackerController.ClearDemoData()
  end
  if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
    ctx.rosterPanelController.RefreshCdTracker()
  end
end

local function BuildSimulationTabletActions(ctx)
  local function L()
    return ctx.GetL and ctx.GetL() or {}
  end
  local function done(key)
    local locale = L()
    return locale[key] or locale.SIM_ACTION_DONE or "Simulation applied."
  end

  return {
    {
      id = "A0",
      category = "group",
      status = "red",
      titleKey = "SIM_ACTION_A0_TITLE",
      descKey = "SIM_ACTION_A0_DESC",
      title = "Incoming group invite",
      description = "Blocked: the pre-accept invite hint was intentionally removed by rule 73.",
    },
    {
      id = "A1",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_A1_TITLE",
      descKey = "SIM_ACTION_A1_DESC",
      title = "Accepted invite notice",
      description = "Live accepted-invite card for a simulated invite to your own key or the season target.",
      run = function()
        Cards().ShowAcceptedInvite(ctx)
        return done("SIM_ACTION_A1_DONE")
      end,
    },
    {
      id = "A2",
      category = "group",
      status = "yellow",
      titleKey = "SIM_ACTION_A2_TITLE",
      descKey = "SIM_ACTION_A2_DESC",
      title = "Group is full",
      description = "Shows a synthetic group-full notice without sending chat or group actions.",
      run = function()
        Cards().ShowGroupFull(ctx)
        return done("SIM_ACTION_A2_DONE")
      end,
    },
    {
      id = "A3",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_A3_TITLE",
      descKey = "SIM_ACTION_A3_DESC",
      title = "Joined own key search",
      description = "Live card for joining your own LFG key search, with you as the leader.",
      run = function()
        Cards().ShowJoinedOwnListing(ctx)
        return done("SIM_ACTION_A3_DONE")
      end,
    },
    {
      id = "A4",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_A4_TITLE",
      descKey = "SIM_ACTION_A4_DESC",
      title = "Non-Mythic dungeon warning",
      description = "Live dungeon-entry card: your current dungeon, else the target dungeon on Normal.",
      run = function()
        Cards().ShowInstanceEntry(ctx, "party")
        return done("SIM_ACTION_A4_DONE")
      end,
    },
    {
      id = "A6",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_A6_TITLE",
      descKey = "SIM_ACTION_A6_DESC",
      title = "Raid invite",
      description = "Live raid-invite card for a simulated raid group, with your own role.",
      run = function()
        Cards().ShowAcceptedRaidInvite(ctx)
        return done("SIM_ACTION_A6_DONE")
      end,
    },
    {
      id = "A7",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_A7_TITLE",
      descKey = "SIM_ACTION_A7_DESC",
      title = "Raid entered",
      description = "Live raid-entry card: your current raid, else a simulated raid on Heroic.",
      run = function()
        Cards().ShowInstanceEntry(ctx, "raid")
        return done("SIM_ACTION_A7_DONE")
      end,
    },
    {
      id = "A8",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_A8_TITLE",
      descKey = "SIM_ACTION_A8_DESC",
      title = "Lead transferred",
      description = "Live notice shown when group lead passes to you.",
      run = function()
        Cards().ShowLeadTransferred(ctx)
        return done("SIM_ACTION_A8_DONE")
      end,
    },
    {
      id = "A5",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_A5_TITLE",
      descKey = "SIM_ACTION_A5_DESC",
      title = "Incoming summon sound",
      description = "Plays the local incoming-summon preview sound only; no summon event is faked.",
      run = function()
        local soundUtils = ctx.addonTable and ctx.addonTable.SoundUtils
        if type(soundUtils) == "table" and type(soundUtils.PlayIncomingSummon) == "function" then
          soundUtils.PlayIncomingSummon()
        end
        return done("SIM_ACTION_A5_DONE")
      end,
    },
    {
      id = "B1",
      kind = "primary",
      status = "green",
      titleKey = "SIM_ACTION_B1_TITLE",
      descKey = "SIM_ACTION_B1_DESC",
      title = "Full feature preview",
      description = "Re-applies all demo feature data: stats, flags, nameplates, alerts, cooldowns and notices.",
      run = function()
        ApplyDemoFeatureData(ctx)
        return done("SIM_ACTION_B1_DONE")
      end,
    },
    {
      id = "B2",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_B2_TITLE",
      descKey = "SIM_ACTION_B2_DESC",
      title = "Ready-check active",
      description = "Simulates an active ready-check waiting state in the roster UI.",
      run = function()
        ApplyReadyCheckActivePreview(ctx)
        return done("SIM_ACTION_B2_DONE")
      end,
    },
    {
      id = "B3",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_B3_TITLE",
      descKey = "SIM_ACTION_B3_DESC",
      title = "Ready-check result hold",
      description = "Simulates held ready and declined markers after a ready-check finishes.",
      run = function()
        ApplyDemoReadyCheckPreview(ctx)
        return done("SIM_ACTION_B3_DONE")
      end,
    },
    {
      id = "B4",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_B4_TITLE",
      descKey = "SIM_ACTION_B4_DESC",
      title = "Clear ready-check",
      description = "Clears active and held ready-check markers.",
      run = function()
        ClearDemoReadyCheckPreview(ctx)
        return done("SIM_ACTION_B4_DONE")
      end,
    },
    {
      id = "C1",
      category = "mplus",
      status = "green",
      titleKey = "SIM_ACTION_C1_TITLE",
      descKey = "SIM_ACTION_C1_DESC",
      title = "M+ timer and pull",
      description = "Simulates the M+ timer, death time and kill-count pull row.",
      run = function()
        SetDemoTimerData(ctx, ctx._demoRuntimeState or {})
        return done("SIM_ACTION_C1_DONE")
      end,
    },
    {
      id = "C5",
      category = "mplus",
      status = "green",
      titleKey = "SIM_ACTION_C5_TITLE",
      descKey = "SIM_ACTION_C5_DESC",
      title = "Before key start",
      description = "Shows the killtracker before the key starts: gold bar, light sweep, pulsing target.",
      run = function()
        SetDemoPreKeyData(ctx, ctx._demoRuntimeState or {})
        return done("SIM_ACTION_C5_DONE")
      end,
    },
    {
      id = "C6",
      category = "mplus",
      status = "green",
      titleKey = "SIM_ACTION_C6_TITLE",
      descKey = "SIM_ACTION_C6_DESC",
      title = "Talents & loot check",
      description = "Real talent and loot check for the target dungeon; its buttons really switch.",
      run = function()
        Cards().ShowLoadoutCheck(ctx)
        return done("SIM_ACTION_C6_DONE")
      end,
    },
    {
      id = "C2",
      category = "mplus",
      status = "green",
      titleKey = "SIM_ACTION_C2_TITLE",
      descKey = "SIM_ACTION_C2_DESC",
      title = "Combat cooldown tracker",
      description = "Simulates battle resurrection and lust cooldown tracker states.",
      run = function()
        if ctx.cdTrackerController and type(ctx.cdTrackerController.SetDemoData) == "function" then
          ctx.cdTrackerController.SetDemoData({
            bres = { charges = 0, maxCharges = 1, cooldownRemain = 112, cooldownDuration = 600 },
            lust = { remain = 23, duration = 600, icon = nil },
          })
        end
        if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
          ctx.rosterPanelController.RefreshCdTracker()
        end
        return done("SIM_ACTION_C2_DONE")
      end,
    },
    {
      id = "C3",
      category = "mplus",
      status = "green",
      titleKey = "SIM_ACTION_C3_TITLE",
      descKey = "SIM_ACTION_C3_DESC",
      title = "Portal navigator",
      description = "Shows the Timeways portal navigator preview with demo map slots.",
      run = function()
        ShowDemoPortalNavigator(ctx, L())
        return done("SIM_ACTION_C3_DONE")
      end,
    },
    {
      id = "C4",
      category = "mplus",
      status = "green",
      titleKey = "SIM_ACTION_C4_TITLE",
      descKey = "SIM_ACTION_C4_DESC",
      title = "Nameplate and tooltip forces",
      description = "Enables the M+ mob forces tooltip/nameplate test values.",
      run = function()
        ApplyDemoMobForces(ctx)
        return done("SIM_ACTION_C4_DONE")
      end,
    },
    {
      id = "D1",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_D1_TITLE",
      descKey = "SIM_ACTION_D1_DESC",
      title = "Share Keys cooldown",
      description = "Starts the local Share Keys cooldown preview.",
      run = function()
        if type(ctx.TriggerShareKeysCooldown) == "function" then
          ctx.TriggerShareKeysCooldown(SIMULATION_TABLET_SHARE_KEYS_COOLDOWN_SECONDS)
        end
        return done("SIM_ACTION_D1_DONE")
      end,
    },
    {
      id = "D2",
      category = "group",
      status = "green",
      titleKey = "SIM_ACTION_D2_TITLE",
      descKey = "SIM_ACTION_D2_DESC",
      title = "Clear Share Keys cooldown",
      description = "Clears the Share Keys cooldown preview.",
      run = function()
        ClearDemoShareKeysCooldown(ctx)
        return done("SIM_ACTION_D2_DONE")
      end,
    },
    {
      id = "E1",
      category = "alerts",
      status = "green",
      titleKey = "SIM_ACTION_E1_TITLE",
      descKey = "SIM_ACTION_E1_DESC",
      title = "Tank death alert",
      description = "Shows the tank death alert preview.",
      run = function()
        if type(ctx.ShowRoleDeathAlert) == "function" then
          ctx.ShowRoleDeathAlert("TANK", "party1")
        end
        return done("SIM_ACTION_E1_DONE")
      end,
    },
    {
      id = "E2",
      category = "alerts",
      status = "green",
      titleKey = "SIM_ACTION_E2_TITLE",
      descKey = "SIM_ACTION_E2_DESC",
      title = "Healer death alert",
      description = "Shows the healer death alert preview.",
      run = function()
        if type(ctx.ShowRoleDeathAlert) == "function" then
          ctx.ShowRoleDeathAlert("HEALER", "party2")
        end
        return done("SIM_ACTION_E2_DONE")
      end,
    },
    {
      id = "E3",
      category = "alerts",
      status = "green",
      titleKey = "SIM_ACTION_E3_TITLE",
      descKey = "SIM_ACTION_E3_DESC",
      title = "Power Infusion alert",
      description = "Power Infusion on you from a simulated party priest: chat and center alert.",
      run = function()
        Cards().ShowPowerInfusion(ctx)
        return done("SIM_ACTION_E3_DONE")
      end,
    },
    {
      id = "E4",
      category = "alerts",
      status = "green",
      titleKey = "SIM_ACTION_E4_TITLE",
      descKey = "SIM_ACTION_E4_DESC",
      title = "Sound preview",
      description = "Runs the ready-check sound preview hook.",
      run = function()
        ApplyDemoAlertAndSoundPreview(ctx, L())
        return done("SIM_ACTION_E4_DONE")
      end,
    },
    {
      id = "F1",
      category = "extras",
      status = "green",
      titleKey = "SIM_ACTION_F1_TITLE",
      descKey = "SIM_ACTION_F1_DESC",
      title = "Stats box preview",
      description = "Shows the movable stats box with your character's own stats.",
      run = function()
        ApplyDemoStatsBox(ctx)
        return done("SIM_ACTION_F1_DONE")
      end,
    },
    {
      id = "F2",
      category = "extras",
      status = "green",
      titleKey = "SIM_ACTION_F2_TITLE",
      descKey = "SIM_ACTION_F2_DESC",
      title = "LFG flags and bonus markers",
      description = "Enables LFG flags and class bonus marker previews.",
      run = function()
        ApplyDemoLfgFlags(ctx)
        return done("SIM_ACTION_F2_DONE")
      end,
    },
    {
      id = "F3",
      kind = "reset",
      status = "green",
      titleKey = "SIM_ACTION_F3_TITLE",
      descKey = "SIM_ACTION_F3_DESC",
      title = "Clear simulation state",
      description = "Clears timer and feature preview state, then keeps the tablet open.",
      run = function()
        ClearDemoTimerData(ctx)
        ClearDemoFeatureData(ctx)
        if type(ctx.ShowSimulationTablet) == "function" then
          ctx.ShowSimulationTablet()
        end
        return done("SIM_ACTION_F3_DONE")
      end,
    },
  }
end

-- The tablet frame is only reachable through `/isilive sim` and the demo
-- preview, so the controller (frame, buttons, action palette) is created on
-- the first Show/Toggle instead of during addon initialization.
function FactoryDemo.InitializeSimulationTablet(ctx)
  local module = ctx.addonTable and ctx.addonTable.SimulationTablet
  if type(module) ~= "table" or type(module.CreateController) ~= "function" then
    return
  end

  local controller = nil
  local function EnsureController()
    if controller == nil then
      controller = module.CreateController({
        anchorFrame = ctx.mainFrame,
        getL = ctx.GetL,
        getActions = function()
          if type(ctx._simulationTabletActions) ~= "table" then
            ctx._simulationTabletActions = BuildSimulationTabletActions(ctx)
          end
          return ctx._simulationTabletActions
        end,
      })
      ctx.simulationTabletController = controller
    end
    return controller
  end

  -- Docking only matters for a tablet that exists; before the first open
  -- there is nothing to anchor.
  ctx.RefreshSimulationTabletDock = function()
    if controller and type(controller.RefreshDock) == "function" then
      controller.RefreshDock()
    end
  end
  if ctx.mainUI and type(ctx.mainUI.SetPositionChangedHandler) == "function" then
    ctx.mainUI.SetPositionChangedHandler(ctx.RefreshSimulationTabletDock)
  end

  ctx.ShowSimulationTablet = function()
    local current = EnsureController()
    if current and type(current.Show) == "function" then
      current.Show()
    end
  end
  ctx.HideSimulationTablet = function()
    if controller and type(controller.Hide) == "function" then
      controller.Hide()
    end
  end
  ctx.ToggleSimulationTablet = function()
    local current = EnsureController()
    if current and type(current.Toggle) == "function" then
      current.Toggle()
      return true
    end
    return false
  end
end

function FactoryDemo.BuildTestModeControllerCallbacks(ctx, runtimeState)
  ctx._demoRuntimeState = runtimeState
  return {
    setDemoTimerData = function()
      SetDemoTimerData(ctx, runtimeState)
    end,
    clearDemoTimerData = function()
      ClearDemoTimerData(ctx)
    end,
    setDemoFeatureData = function()
      ApplyDemoFeatureData(ctx)
    end,
    clearDemoFeatureData = function()
      ClearDemoFeatureData(ctx)
    end,
  }
end

return FactoryDemo
