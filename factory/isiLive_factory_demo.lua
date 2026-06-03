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
    mobNameplate.SetTestMode(true, "12.34")
  elseif type(mobNameplate.SetEnabled) == "function" then
    mobNameplate.SetEnabled(true)
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

local function ApplyDemoFeatureData(ctx)
  ctx._demoFeatureActive = true
  ApplyDemoFeatureDbOverrides(ctx)
  ApplyDemoStatsBox(ctx)
  ApplyDemoLfgFlags(ctx)
  ApplyDemoMobForces(ctx)

  local L = ctx.GetL and ctx.GetL() or {}
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

function FactoryDemo.BuildTestModeControllerCallbacks(ctx, runtimeState)
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
