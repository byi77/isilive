local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

local FactoryNotices = {}
FI.FactoryNotices = FactoryNotices

local function ResolveAcceptedInviteRoleName(ctx, role)
  if type(role) ~= "string" or role == "" or role == "NONE" then
    return nil
  end
  local L = ctx.GetL and ctx.GetL() or {}
  if role == "TANK" then
    return L.ROLE_NAME_TANK
  end
  if role == "HEALER" then
    return L.ROLE_NAME_HEALER
  end
  if role == "DAMAGER" then
    return L.ROLE_NAME_DAMAGE
  end
  return nil
end

local function ResolveAcceptedInviteDungeonName(ctx, modules, mapID)
  if modules.teleport and type(modules.teleport.GetTeleportInfoByMapID) == "function" and mapID then
    local info = modules.teleport.GetTeleportInfoByMapID(mapID)
    if type(info) == "table" then
      if type(info.mapName) == "string" and info.mapName ~= "" then
        return info.mapName
      end
      if type(info.name) == "string" and info.name ~= "" then
        return info.name
      end
    end
  end
  local L = ctx.GetL and ctx.GetL() or {}
  return L.INVITE_HINT_UNKNOWN_DUNGEON or "Unknown dungeon"
end

local function BuildAcceptedInviteFields(ctx, mapName, payload)
  local L = ctx.GetL and ctx.GetL() or {}
  local fields = {}

  local level = tonumber(payload.level)
  local dungeonValue
  if level and level > 0 then
    dungeonValue = string.format(L.INVITE_ACCEPTED_NOTICE_HEADLINE_WITH_LEVEL or "%s +%d", mapName, math.floor(level))
  else
    dungeonValue = string.format(L.INVITE_ACCEPTED_NOTICE_HEADLINE_NO_LEVEL or "%s", mapName)
  end
  fields[#fields + 1] = { label = L.INVITE_ACCEPTED_NOTICE_LABEL_DUNGEON or "Dungeon:", value = dungeonValue }

  if type(payload.groupName) == "string" and payload.groupName ~= "" then
    fields[#fields + 1] = { label = L.INVITE_ACCEPTED_NOTICE_LABEL_GROUP or "Group:", value = payload.groupName }
  end

  if type(payload.leaderName) == "string" and payload.leaderName ~= "" then
    fields[#fields + 1] = { label = L.INVITE_ACCEPTED_NOTICE_LABEL_LEADER or "Leader:", value = payload.leaderName }
  end

  fields[#fields + 1] = {
    label = L.INVITE_ACCEPTED_NOTICE_LABEL_SOURCE or "Source:",
    value = payload.sourceText or L.INVITE_ACCEPTED_NOTICE_SOURCE_LFG_ACCEPTED or "LFG accepted invite",
  }

  return fields
end

local function IsAcceptedInviteNoticeEnabled()
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return true
  end
  return db.acceptedInviteNoticeEnabled ~= false
end

local function IsGroupJoinNoticeEnabled()
  local db = rawget(_G, "IsiLiveDB")
  if type(db) ~= "table" then
    return true
  end
  return db.groupJoinNoticeEnabled ~= false
end

local function RenderAcceptedInviteNotice(ctx, modules, payload, useAcceptedNoticeGate)
  if type(payload) ~= "table" or type(ctx.ShowCenterNotice) ~= "function" then
    return
  end
  if useAcceptedNoticeGate ~= false and not IsAcceptedInviteNoticeEnabled() then
    return
  end
  local L = ctx.GetL and ctx.GetL() or {}

  local mapName = ResolveAcceptedInviteDungeonName(ctx, modules, payload.mapID)
  local fields = BuildAcceptedInviteFields(ctx, mapName, payload)
  local activityID = tonumber(payload.activityID)
  if activityID and activityID <= 0 then
    activityID = nil
  end
  local mapID = tonumber(payload.mapID)
  if mapID and mapID <= 0 then
    mapID = nil
  end
  local hasTeleportContext = activityID ~= nil or mapID ~= nil

  ctx.ShowCenterNotice(nil, nil, hasTeleportContext and mapName or nil, activityID, {
    eyebrow = L.INVITE_ACCEPTED_NOTICE_EYEBROW or "M+ Target",
    title = payload.title or L.INVITE_ACCEPTED_NOTICE_TITLE or "isiLive - Invite accepted",
    fields = fields,
    teleportMapID = mapID,
    frameWidth = 680,
    persistent = true,
  })
end

local function ShowJoinedTargetNotice(ctx, modules)
  if type(ctx) ~= "table" then
    return
  end
  if ctx.acceptedInviteNoticeRenderedForCurrentJoin == true then
    ctx.acceptedInviteNoticeRenderedForCurrentJoin = false
    return
  end
  if type(ctx.ResolveLocalStatusTargetMapID) ~= "function" or type(ctx.GetStatusTargetDungeonInfo) ~= "function" then
    return
  end
  if not IsGroupJoinNoticeEnabled() then
    return
  end

  local mapID = tonumber(ctx.ResolveLocalStatusTargetMapID())
  if not mapID or mapID <= 0 then
    return
  end

  local targetInfo = ctx.GetStatusTargetDungeonInfo()
  if type(targetInfo) ~= "table" or type(targetInfo.name) ~= "string" or targetInfo.name == "" then
    return
  end

  local activityID = nil
  if ctx.runtimeState and type(ctx.runtimeState.GetLatestQueueState) == "function" then
    local _, latestQueueActivityID = ctx.runtimeState.GetLatestQueueState()
    activityID = latestQueueActivityID
  end
  local lfgDetect = addonTable.LFGDetect
  local leaderName = nil
  local groupName = nil
  local sourceText = nil
  local title = nil
  local usedQueueListingIdentity = false
  if type(lfgDetect) == "table" then
    if type(lfgDetect.GetActiveInviteLeader) == "function" then
      leaderName = lfgDetect.GetActiveInviteLeader()
    end
    if type(lfgDetect.GetActiveInviteGroupName) == "function" then
      groupName = lfgDetect.GetActiveInviteGroupName()
    end
    if not leaderName and type(lfgDetect.GetActiveQueueListingLeaderName) == "function" then
      leaderName = lfgDetect.GetActiveQueueListingLeaderName()
      usedQueueListingIdentity = leaderName ~= nil
    end
    if not groupName and type(lfgDetect.GetActiveQueueListingGroupName) == "function" then
      groupName = lfgDetect.GetActiveQueueListingGroupName()
      usedQueueListingIdentity = usedQueueListingIdentity or groupName ~= nil
    end
  end
  if usedQueueListingIdentity then
    local L = ctx.GetL and ctx.GetL() or {}
    sourceText = L.INVITE_ACCEPTED_NOTICE_SOURCE_OWN_LFG_LISTING or "Own LFG key search"
    title = L.INVITE_ACCEPTED_NOTICE_TITLE_OWN_LFG_LISTING or "isiLive - LFG key search"
  end

  RenderAcceptedInviteNotice(ctx, modules, {
    mapID = math.floor(mapID),
    activityID = activityID,
    level = targetInfo.level,
    leaderName = leaderName,
    groupName = groupName,
    sourceText = sourceText,
    title = title,
  }, false)
end

local function BuildAcceptedRaidInviteFields(ctx, mapName, payload)
  local L = ctx.GetL and ctx.GetL() or {}
  local fields = {}
  fields[#fields + 1] = {
    label = L.INVITE_ACCEPTED_NOTICE_LABEL_DUNGEON or "Dungeon:",
    value = mapName,
  }
  if type(payload.groupName) == "string" and payload.groupName ~= "" then
    fields[#fields + 1] = { label = L.INVITE_ACCEPTED_NOTICE_LABEL_GROUP or "Group:", value = payload.groupName }
  end
  if type(payload.comment) == "string" and payload.comment ~= "" then
    fields[#fields + 1] =
      { label = L.INVITE_ACCEPTED_NOTICE_LABEL_DESCRIPTION or "Description:", value = payload.comment }
  end
  local role = type(ctx.GetUnitRole) == "function" and ctx.GetUnitRole("player") or nil
  local roleName = ResolveAcceptedInviteRoleName(ctx, role)
  if roleName then
    fields[#fields + 1] = { label = L.INVITE_ACCEPTED_NOTICE_LABEL_ROLE or "Role:", value = roleName }
  end
  return fields
end

local function RenderAcceptedRaidInviteNotice(ctx, modules, payload)
  if type(payload) ~= "table" or type(ctx.ShowCenterNotice) ~= "function" then
    return
  end
  if not IsAcceptedInviteNoticeEnabled() then
    return
  end
  local L = ctx.GetL and ctx.GetL() or {}
  local mapName = ResolveAcceptedInviteDungeonName(ctx, modules, payload.mapID)
  local fields = BuildAcceptedRaidInviteFields(ctx, mapName, payload)
  ctx.ShowCenterNotice(nil, nil, nil, nil, {
    eyebrow = L.INVITE_ACCEPTED_RAID_NOTICE_EYEBROW or "Raid Target",
    title = L.INVITE_ACCEPTED_RAID_NOTICE_TITLE or "isiLive - Raid invite accepted",
    fields = fields,
    frameWidth = 540,
    persistent = true,
  })
end

local function WireAcceptedInviteNoticeCallbacks(ctx, modules, lfgDetect)
  local function noticeEnabled()
    return IsAcceptedInviteNoticeEnabled()
  end
  if type(lfgDetect.SetAcceptedInviteNoticeCallback) == "function" then
    lfgDetect.SetAcceptedInviteNoticeCallback(function(payload)
      ctx.acceptedInviteNoticeRenderedForCurrentJoin = true
      RenderAcceptedInviteNotice(ctx, modules, payload)
    end)
  end
  if type(lfgDetect.SetAcceptedInviteNoticeEnabledFn) == "function" then
    lfgDetect.SetAcceptedInviteNoticeEnabledFn(noticeEnabled)
  end
  if type(lfgDetect.SetAcceptedRaidInviteNoticeCallback) == "function" then
    lfgDetect.SetAcceptedRaidInviteNoticeCallback(function(payload)
      RenderAcceptedRaidInviteNotice(ctx, modules, payload)
    end)
  end
  if type(lfgDetect.SetAcceptedRaidInviteNoticeEnabledFn) == "function" then
    lfgDetect.SetAcceptedRaidInviteNoticeEnabledFn(noticeEnabled)
  end
end

local function HandleTargetDungeonChatPayload(ctx, modules, statusController, payload)
  if type(payload) ~= "table" then
    return
  end
  local mapID = tonumber(payload.mapID)
  if not mapID or mapID <= 0 then
    return
  end
  local resolvedName = ResolveAcceptedInviteDungeonName(ctx, modules, mapID)
  if type(resolvedName) ~= "string" or resolvedName == "" then
    return
  end
  if ctx.runtimeState and type(ctx.runtimeState.SetLatestQueueState) == "function" then
    ctx.runtimeState.SetLatestQueueState(resolvedName, payload.activityID, nil, mapID)
  end
  local logRuntimeTracef = ctx.runtimeLogController and ctx.runtimeLogController.Logf or nil
  if logRuntimeTracef then
    logRuntimeTracef(
      "[TARGET_DUNGEON_CHAT] direct_push mapID=%s level=%s leader=%s group=%s searchResultID=%s",
      tostring(mapID),
      tostring(payload.level),
      tostring(payload.leaderName),
      tostring(payload.groupName),
      tostring(payload.searchResultID)
    )
  end
  statusController.AnnounceTargetDungeonFromPayload({
    name = resolvedName,
    level = payload.level,
    levelText = payload.levelText,
  })
  if ctx.rosterPanelController and type(ctx.rosterPanelController.RefreshKillTrackRow) == "function" then
    ctx.rosterPanelController.RefreshKillTrackRow()
  end
end

local function InitializeInviteControllers(_ctx, _modules)
  -- Disabled: there is no proven stable Blizzard multi-invite list surface.
end

FactoryNotices.ResolveAcceptedInviteRoleName = ResolveAcceptedInviteRoleName
FactoryNotices.ResolveAcceptedInviteDungeonName = ResolveAcceptedInviteDungeonName
FactoryNotices.BuildAcceptedInviteFields = BuildAcceptedInviteFields
FactoryNotices.RenderAcceptedInviteNotice = RenderAcceptedInviteNotice
FactoryNotices.ShowJoinedTargetNotice = ShowJoinedTargetNotice
FactoryNotices.BuildAcceptedRaidInviteFields = BuildAcceptedRaidInviteFields
FactoryNotices.RenderAcceptedRaidInviteNotice = RenderAcceptedRaidInviteNotice
FactoryNotices.WireAcceptedInviteNoticeCallbacks = WireAcceptedInviteNoticeCallbacks
FactoryNotices.HandleTargetDungeonChatPayload = HandleTargetDungeonChatPayload
FactoryNotices.InitializeInviteControllers = InitializeInviteControllers

FI.ResolveAcceptedInviteRoleName = ResolveAcceptedInviteRoleName
FI.ResolveAcceptedInviteDungeonName = ResolveAcceptedInviteDungeonName
FI.BuildAcceptedInviteFields = BuildAcceptedInviteFields
FI.RenderAcceptedInviteNotice = RenderAcceptedInviteNotice
FI.ShowJoinedTargetNotice = ShowJoinedTargetNotice
FI.BuildAcceptedRaidInviteFields = BuildAcceptedRaidInviteFields
FI.RenderAcceptedRaidInviteNotice = RenderAcceptedRaidInviteNotice
FI.WireAcceptedInviteNoticeCallbacks = WireAcceptedInviteNoticeCallbacks
FI.HandleTargetDungeonChatPayload = HandleTargetDungeonChatPayload
FI.InitializeInviteControllers = InitializeInviteControllers

return FactoryNotices
