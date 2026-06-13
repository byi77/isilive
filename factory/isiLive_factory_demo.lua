local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local FactoryDemo = {}
FI.FactoryDemo = FactoryDemo

local DEMO_FEATURE_NIL = {}
local DEMO_FEATURE_TARGET_DUNGEON_NAME = "Nexus-Point Xenas"
local DEMO_FEATURE_TARGET_MAP_ID = 559
local DEMO_FEATURE_NON_MYTHIC_DUNGEON_NAME = "Priorei der Heiligen Flamme"
local DEMO_FEATURE_NON_MYTHIC_NOTICE_DELAY_SECONDS = 8
local DEMO_FEATURE_READY_CHECK_HOLD_SECONDS = 20
local DEMO_FEATURE_SHARE_KEYS_COOLDOWN_SECONDS = 18
local SIMULATION_TABLET_SHARE_KEYS_COOLDOWN_SECONDS = 30
local DEMO_FEATURE_PORTAL_NAVIGATOR_MAP_IDS = {
  left = 161,
  half_left = 556,
  half_right = 402,
  right = 239,
}
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
  "ttsAnnouncementsEnabled",
  "ttsAnnounceName",
  "ttsAnnounceClass",
}

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

local function ApplyDemoFeatureDbOverrides(ctx)
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return nil
  end

  if type(ctx._demoFeatureSnapshot) ~= "table" then
    ctx._demoFeatureSnapshot = CaptureDemoFeatureSnapshot(db)
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
  db.ttsAnnouncementsEnabled = true
  db.ttsAnnounceName = true
  db.ttsAnnounceClass = false

  return db
end

local function ApplyDemoStatsBox(ctx)
  local statsBox = ctx.addonTable and ctx.addonTable.StatsBox
  if type(statsBox) ~= "table" then
    return
  end

  if type(statsBox.SetDemoData) == "function" then
    statsBox.SetDemoData({
      { key = "strength", label = "Str", value = 4210 },
      { key = "stamina", label = "Stam", value = 6812 },
      { key = "crit", label = "Crit", value = 1824, percent = 24.85 },
      { key = "haste", label = "Haste", value = 1492, percent = 18.42 },
      { key = "mastery", label = "Mast", value = 2108, percent = 37.66 },
      { key = "versatility", label = "Vers", value = 1154, percent = 14.12 },
      { key = "leech", label = "Leech", value = 238, percent = 3.27 },
      { key = "speed", label = "Speed", value = 326, percent = 6.44 },
      { key = "durability", label = "Dur", valueText = "483", percent = 96.60 },
      { key = "avoidance", label = "Avoid", value = 412, percent = 5.18 },
    })
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
    mobNameplate.SetTestMode(true, "12.34", { activeMapID = DEMO_FEATURE_TARGET_MAP_ID })
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

local function ApplyDemoAlertAndSoundPreview(ctx, L)
  if type(ctx.ShowRoleDeathAlert) == "function" then
    ctx.ShowRoleDeathAlert("TANK", "party1")
    ctx.ShowRoleDeathAlert("DAMAGER", "party3")
  end

  local soundUtils = ctx.addonTable and ctx.addonTable.SoundUtils
  if type(soundUtils) ~= "table" then
    return
  end
  if type(soundUtils.PlayReadyCheckComplete) == "function" then
    soundUtils.PlayReadyCheckComplete()
  end
  if type(soundUtils.SpeakTts) == "function" then
    soundUtils.SpeakTts(L.TTS_PREVIEW_TEXT or "isiLive text to speech is active.", {
      spamScope = "preview:demo",
    })
  end
end

local function ApplyDemoPortalNavigatorTeleportInfo(ctx, entry, mapID)
  entry.mapID = mapID
  local teleport = ctx.modules and ctx.modules.teleport
  if type(teleport) ~= "table" or type(teleport.GetTeleportInfoByMapID) ~= "function" then
    return
  end

  local ok, info = pcall(teleport.GetTeleportInfoByMapID, mapID)
  if not ok or type(info) ~= "table" then
    return
  end

  local spellID = tonumber(info.spellID)
  if spellID and spellID > 0 then
    entry.spellID = math.floor(spellID)
  end
  if type(info.icon) == "string" or type(info.icon) == "number" then
    entry.icon = info.icon
  end
end

local function BuildDemoPortalNavigatorEntry(ctx, slot, direction, destination, opts)
  local entry = {
    slot = slot,
    direction = direction,
    destination = destination,
  }
  if type(opts) == "table" then
    entry.detail = opts.detail
    entry.isEmpty = opts.isEmpty == true
  end

  local mapID = DEMO_FEATURE_PORTAL_NAVIGATOR_MAP_IDS[slot]
  if mapID then
    ApplyDemoPortalNavigatorTeleportInfo(ctx, entry, mapID)
  end
  return entry
end

local function ShowDemoPortalNavigator(ctx, L)
  if type(ctx.ShowPortalNavigatorNotice) ~= "function" then
    return
  end

  ctx.ShowPortalNavigatorNotice({
    eyebrow = L.PORTAL_NAVIGATOR_EYEBROW or "Portal - Navigation",
    title = L.PORTAL_NAVIGATOR_TITLE or "Timeways Portal Navigator",
    entries = {
      BuildDemoPortalNavigatorEntry(
        ctx,
        "left",
        L.PORTAL_NAVIGATOR_LEFT or "Left",
        L.PORTAL_NAVIGATOR_SKYREACH or "Skyreach"
      ),
      BuildDemoPortalNavigatorEntry(
        ctx,
        "half_left",
        L.PORTAL_NAVIGATOR_HALF_LEFT or "Half-left",
        L.PORTAL_NAVIGATOR_PIT_OF_SARON or "Pit of Saron"
      ),
      BuildDemoPortalNavigatorEntry(
        ctx,
        "center",
        L.PORTAL_NAVIGATOR_CENTER or "Straight ahead",
        L.PORTAL_NAVIGATOR_HEAVEN or "Heaven",
        { detail = L.PORTAL_NAVIGATOR_UNOCCUPIED or "Unoccupied", isEmpty = true }
      ),
      BuildDemoPortalNavigatorEntry(
        ctx,
        "half_right",
        L.PORTAL_NAVIGATOR_HALF_RIGHT or "Half-right",
        L.PORTAL_NAVIGATOR_ALGETHAR or "Algeth'ar Academy"
      ),
      BuildDemoPortalNavigatorEntry(
        ctx,
        "right",
        L.PORTAL_NAVIGATOR_RIGHT or "Right",
        L.PORTAL_NAVIGATOR_TRIUMVIRATE or "Seat of the Triumvirate"
      ),
    },
  })
end

local function BuildDemoAcceptedInviteNoticePayload(L)
  return {
    message = nil,
    durationSeconds = nil,
    dungeonName = DEMO_FEATURE_TARGET_DUNGEON_NAME,
    activityID = nil,
    showOptions = {
      eyebrow = L.INVITE_ACCEPTED_NOTICE_EYEBROW or "M+ Target",
      title = L.INVITE_ACCEPTED_NOTICE_TITLE or "isiLive - Invite accepted",
      fields = {
        { label = L.INVITE_ACCEPTED_NOTICE_LABEL_DUNGEON or "Dungeon:", value = "Nexus-Point Xenas +15" },
        { label = L.INVITE_ACCEPTED_NOTICE_LABEL_GROUP or "Title:", value = "+15 Demo Preview" },
        { label = L.INVITE_ACCEPTED_NOTICE_LABEL_LEADER or "Leader:", value = "isiLive-Demo" },
        {
          label = L.INVITE_ACCEPTED_NOTICE_LABEL_SOURCE or "Source:",
          value = L.INVITE_ACCEPTED_NOTICE_SOURCE_LFG_ACCEPTED or "LFG accepted invite",
        },
      },
      teleportMapID = DEMO_FEATURE_TARGET_MAP_ID,
      frameWidth = 680,
      persistent = true,
    },
  }
end

local function ShowDemoAcceptedInviteNotice(ctx, L)
  if type(ctx.ShowCenterNotice) ~= "function" then
    return
  end

  local payload = BuildDemoAcceptedInviteNoticePayload(L)
  ctx.ShowCenterNotice(
    payload.message,
    payload.durationSeconds,
    payload.dungeonName,
    payload.activityID,
    payload.showOptions
  )
end

local function BuildDemoNonMythicDungeonNoticePayload(L)
  return {
    message = string.format(
      L.NON_MYTHIC_ENTERED or "Warning: Entered non-Mythic dungeon (%s).",
      L.DUNGEON_DIFF_NORMAL or "Normal"
    ),
    durationSeconds = 120,
    dungeonName = nil,
    activityID = nil,
    showOptions = {
      eyebrow = L.NON_MYTHIC_NOTICE_DUNGEON_EYEBROW or "Dungeon",
      title = L.NON_MYTHIC_NOTICE_DUNGEON_TITLE or "isiLive - Dungeon entered",
      fields = {
        {
          label = L.NON_MYTHIC_NOTICE_LABEL_DUNGEON or "Dungeon:",
          value = L.NON_MYTHIC_NOTICE_DEMO_DUNGEON or DEMO_FEATURE_NON_MYTHIC_DUNGEON_NAME,
        },
        {
          label = L.NON_MYTHIC_NOTICE_LABEL_DIFFICULTY or "Difficulty:",
          value = L.DUNGEON_DIFF_NORMAL or "Normal",
        },
        {
          label = L.NON_MYTHIC_NOTICE_LABEL_HINT or "Hint:",
          value = L.NON_MYTHIC_NOTICE_HINT_NON_MYTHIC or "Not a Mythic+ dungeon",
          warning = true,
          blink = true,
        },
        {
          label = L.NON_MYTHIC_NOTICE_LABEL_SOURCE or "Source:",
          value = L.NON_MYTHIC_NOTICE_SOURCE_INSTANCE_ENTERED or "Instance entered",
        },
      },
      frameWidth = 680,
      persistent = true,
    },
  }
end

local function ShowDemoNonMythicDungeonNotice(ctx, L)
  if type(ctx.ShowCenterNotice) ~= "function" then
    return
  end

  local payload = BuildDemoNonMythicDungeonNoticePayload(L)
  ctx.ShowCenterNotice(
    payload.message,
    payload.durationSeconds,
    payload.dungeonName,
    payload.activityID,
    payload.showOptions
  )
end

local function ShowSimulationGroupFullNotice(ctx, L)
  if type(ctx.ShowCenterNotice) ~= "function" then
    return
  end

  ctx.ShowCenterNotice(nil, 120, nil, nil, {
    eyebrow = L.SIM_GROUP_FULL_EYEBROW or "LFG simulation",
    title = L.SIM_GROUP_FULL_TITLE or "isiLive - Group is full",
    fields = {
      { label = L.SIM_NOTICE_LABEL_STATE or "State:", value = L.SIM_GROUP_FULL_VALUE or "Group full" },
      {
        label = L.SIM_NOTICE_LABEL_SOURCE or "Source:",
        value = L.SIM_NOTICE_SOURCE_TABLET or "Simulation tablet",
      },
      {
        label = L.SIM_NOTICE_LABEL_HINT or "Hint:",
        value = L.SIM_GROUP_FULL_HINT or "No group action and no chat post were sent.",
        warning = true,
      },
    },
    frameWidth = 680,
    persistent = true,
  })
end

local function ShowSimulationJoinedTargetNotice(ctx, L)
  if type(ctx.ShowCenterNotice) ~= "function" then
    return
  end

  ctx.ShowCenterNotice(nil, 120, DEMO_FEATURE_TARGET_DUNGEON_NAME, nil, {
    eyebrow = L.SIM_JOINED_TARGET_EYEBROW or "Group joined",
    title = L.SIM_JOINED_TARGET_TITLE or "isiLive - Joined target group",
    fields = {
      { label = L.INVITE_ACCEPTED_NOTICE_LABEL_DUNGEON or "Dungeon:", value = "Nexus-Point Xenas +15" },
      {
        label = L.SIM_NOTICE_LABEL_SOURCE or "Source:",
        value = L.SIM_NOTICE_SOURCE_TABLET or "Simulation tablet",
      },
      {
        label = L.SIM_NOTICE_LABEL_HINT or "Hint:",
        value = L.SIM_JOINED_TARGET_HINT or "Local center notice only; no real chat post was sent.",
      },
    },
    teleportMapID = DEMO_FEATURE_TARGET_MAP_ID,
    frameWidth = 680,
    persistent = true,
  })
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
  if type(ctx.ShowDemoCenterNotices) == "function" then
    ctx.ShowDemoCenterNotices({
      BuildDemoAcceptedInviteNoticePayload(L),
      BuildDemoNonMythicDungeonNoticePayload(L),
    })
  else
    ShowDemoAcceptedInviteNotice(ctx, L)
    if C_Timer and C_Timer.After then
      C_Timer.After(DEMO_FEATURE_NON_MYTHIC_NOTICE_DELAY_SECONDS, function()
        if ctx._demoFeatureActive == true then
          ShowDemoNonMythicDungeonNotice(ctx, ctx.GetL and ctx.GetL() or L)
        end
      end)
    else
      ShowDemoNonMythicDungeonNotice(ctx, L)
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
  local db = rawget(_G, "IsiLiveDB")
  local snapshot = ctx._demoFeatureSnapshot
  if type(db) == "table" and type(snapshot) == "table" then
    RestoreDemoFeatureSnapshot(db, snapshot)
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

local function SetDemoTimerData(ctx, runtimeState)
  local MplusTimer = ctx.addonTable and ctx.addonTable.MplusTimer
  if type(MplusTimer) == "table" and type(MplusTimer.SetDemoData) == "function" then
    MplusTimer.SetDemoData({
      running = true,
      completed = false,
      timer = 780,
      timeLimit = 1800,
      keyLevel = 15,
      timeRemaining1 = 1020,
      timeRemaining2 = 660,
      timeRemaining3 = 300,
      deaths = 2,
      deathTimeLost = 8,
    })
  end
  if type(runtimeState.SetLatestQueueState) == "function" then
    runtimeState.SetLatestQueueState(DEMO_FEATURE_TARGET_DUNGEON_NAME, nil, nil, DEMO_FEATURE_TARGET_MAP_ID)
  end
  local KillTrack = ctx.addonTable and ctx.addonTable.KillTrack
  if type(KillTrack) == "table" and type(KillTrack.SetDemoData) == "function" then
    KillTrack.SetDemoData({
      active = true,
      percent = 47.34,
      rawCount = 204,
      total = 431,
      mapID = DEMO_FEATURE_TARGET_MAP_ID,
      inCombat = true,
      pullPercent = 3.21,
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
          bres = { charges = 0, maxCharges = 1, cooldownRemain = 112 },
          lust = { remain = 23, icon = nil },
        })
      end
      if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshCdTracker) == "function" then
        ctx.rosterPanelController.RefreshCdTracker()
      end
    end)
  end
end

local function ClearDemoTimerData(ctx)
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
      status = "red",
      title = "Incoming group invite",
      description = "Blocked: the pre-accept invite hint was intentionally removed by rule 73.",
    },
    {
      id = "A1",
      status = "green",
      title = "Accepted invite notice",
      description = "Shows the safe accepted-invite center notice for the demo dungeon.",
      run = function()
        ShowDemoAcceptedInviteNotice(ctx, L())
        return done("SIM_ACTION_A1_DONE")
      end,
    },
    {
      id = "A2",
      status = "yellow",
      title = "Group is full",
      description = "Shows a synthetic group-full notice without sending chat or group actions.",
      run = function()
        ShowSimulationGroupFullNotice(ctx, L())
        return done("SIM_ACTION_A2_DONE")
      end,
    },
    {
      id = "A3",
      status = "yellow",
      title = "Joined target group",
      description = "Shows a local joined-target notice using the verified demo dungeon.",
      run = function()
        ShowSimulationJoinedTargetNotice(ctx, L())
        return done("SIM_ACTION_A3_DONE")
      end,
    },
    {
      id = "A4",
      status = "green",
      title = "Non-Mythic dungeon warning",
      description = "Shows the non-Mythic dungeon center notice preview.",
      run = function()
        ShowDemoNonMythicDungeonNotice(ctx, L())
        return done("SIM_ACTION_A4_DONE")
      end,
    },
    {
      id = "A5",
      status = "green",
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
      status = "green",
      title = "Full feature preview",
      description = "Re-applies all demo feature data: stats, flags, nameplates, alerts, cooldowns and notices.",
      run = function()
        ApplyDemoFeatureData(ctx)
        return done("SIM_ACTION_B1_DONE")
      end,
    },
    {
      id = "B2",
      status = "green",
      title = "Ready-check active",
      description = "Simulates an active ready-check waiting state in the roster UI.",
      run = function()
        ApplyReadyCheckActivePreview(ctx)
        return done("SIM_ACTION_B2_DONE")
      end,
    },
    {
      id = "B3",
      status = "green",
      title = "Ready-check result hold",
      description = "Simulates held ready and declined markers after a ready-check finishes.",
      run = function()
        ApplyDemoReadyCheckPreview(ctx)
        return done("SIM_ACTION_B3_DONE")
      end,
    },
    {
      id = "B4",
      status = "green",
      title = "Clear ready-check",
      description = "Clears active and held ready-check markers.",
      run = function()
        ClearDemoReadyCheckPreview(ctx)
        return done("SIM_ACTION_B4_DONE")
      end,
    },
    {
      id = "C1",
      status = "green",
      title = "M+ timer and pull",
      description = "Simulates the M+ timer, death time and kill-count pull row.",
      run = function()
        SetDemoTimerData(ctx, ctx._demoRuntimeState or {})
        return done("SIM_ACTION_C1_DONE")
      end,
    },
    {
      id = "C2",
      status = "green",
      title = "Combat cooldown tracker",
      description = "Simulates battle resurrection and lust cooldown tracker states.",
      run = function()
        if ctx.cdTrackerController and type(ctx.cdTrackerController.SetDemoData) == "function" then
          ctx.cdTrackerController.SetDemoData({
            bres = { charges = 0, maxCharges = 1, cooldownRemain = 112 },
            lust = { remain = 23, icon = nil },
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
      status = "green",
      title = "Portal navigator",
      description = "Shows the Timeways portal navigator preview with demo map slots.",
      run = function()
        ShowDemoPortalNavigator(ctx, L())
        return done("SIM_ACTION_C3_DONE")
      end,
    },
    {
      id = "C4",
      status = "green",
      title = "Nameplate and tooltip forces",
      description = "Enables the M+ mob forces tooltip/nameplate test values.",
      run = function()
        ApplyDemoMobForces(ctx)
        return done("SIM_ACTION_C4_DONE")
      end,
    },
    {
      id = "D1",
      status = "green",
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
      status = "green",
      title = "Clear Share Keys cooldown",
      description = "Clears the Share Keys cooldown preview.",
      run = function()
        ClearDemoShareKeysCooldown(ctx)
        return done("SIM_ACTION_D2_DONE")
      end,
    },
    {
      id = "E1",
      status = "green",
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
      status = "green",
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
      status = "green",
      title = "Sound and TTS preview",
      description = "Runs the ready-check sound and text-to-speech preview hooks.",
      run = function()
        ApplyDemoAlertAndSoundPreview(ctx, L())
        return done("SIM_ACTION_E3_DONE")
      end,
    },
    {
      id = "F1",
      status = "green",
      title = "Stats box preview",
      description = "Populates the movable stats box with deterministic demo values.",
      run = function()
        ApplyDemoStatsBox(ctx)
        return done("SIM_ACTION_F1_DONE")
      end,
    },
    {
      id = "F2",
      status = "green",
      title = "LFG flags and bonus markers",
      description = "Enables LFG flags and class bonus marker previews.",
      run = function()
        ApplyDemoLfgFlags(ctx)
        return done("SIM_ACTION_F2_DONE")
      end,
    },
    {
      id = "F3",
      status = "green",
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

function FactoryDemo.InitializeSimulationTablet(ctx)
  local module = ctx.addonTable and ctx.addonTable.SimulationTablet
  if type(module) ~= "table" or type(module.CreateController) ~= "function" then
    return
  end

  local controller = module.CreateController({
    getL = ctx.GetL,
    getActions = function()
      if type(ctx._simulationTabletActions) ~= "table" then
        ctx._simulationTabletActions = BuildSimulationTabletActions(ctx)
      end
      return ctx._simulationTabletActions
    end,
  })
  ctx.simulationTabletController = controller

  ctx.ShowSimulationTablet = function()
    if controller and type(controller.Show) == "function" then
      controller.Show()
    end
  end
  ctx.HideSimulationTablet = function()
    if controller and type(controller.Hide) == "function" then
      controller.Hide()
    end
  end
  ctx.ToggleSimulationTablet = function()
    if controller and type(controller.Toggle) == "function" then
      controller.Toggle()
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
