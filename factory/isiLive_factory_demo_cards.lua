local _, addonTable = ...
addonTable = addonTable or {}

local FI = addonTable._FactoryInternal or {}
addonTable._FactoryInternal = FI

-- Card triggers of the simulation tablet. Every card goes through the live
-- builder or renderer with the loaded player's real data; only what cannot
-- exist without a group is simulated (the invite itself, its leader and
-- title, a raid outside a raid). Without an own keystone the target is the
-- active season's first dungeon at +15.
local FactoryDemoCards = {}
FI.FactoryDemoCards = FactoryDemoCards

-- Test harnesses may load this file without Validators; treat nothing as secret there.
local IsSecretValue = addonTable.Validators and addonTable.Validators.IsSecretValue
  or function(_value)
    return false
  end

local DEMO_TARGET_KEY_LEVEL = 15
local DEMO_PI_CASTER_NAME = "Velindra-Hyjal"
local DEMO_INVITE_LEADER_NAME = "isiLive-Demo"
local DEMO_RAID_GROUP_NAME = "isiLive Raid Demo"

local function PlainCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d = pcall(fn, ...)
  if not ok or IsSecretValue(a) or IsSecretValue(b) or IsSecretValue(c) or IsSecretValue(d) then
    return nil
  end
  return a, b, c, d
end

local function GetL(ctx)
  return ctx.GetL and ctx.GetL() or {}
end

local function GetSeasonData(ctx)
  return (ctx.modules and ctx.modules.seasonData) or (ctx.addonTable and ctx.addonTable.SeasonData)
end

local function ResolveSeasonDungeonName(ctx, mapID)
  local seasonData = GetSeasonData(ctx)
  local name = nil
  if type(seasonData) == "table" and type(seasonData.GetDungeonName) == "function" then
    name = seasonData.GetDungeonName(mapID, ctx.locale)
  end
  if (type(name) ~= "string" or name == "") and type(ctx.GetDungeonName) == "function" then
    name = ctx.GetDungeonName(mapID)
  end
  return type(name) == "string" and name ~= "" and name or nil
end

local function ReadOwnedKeystone()
  local mythicPlus = rawget(_G, "C_MythicPlus")
  if type(mythicPlus) ~= "table" then
    return nil, nil
  end
  local mapID = PlainCall(mythicPlus.GetOwnedKeystoneChallengeMapID)
  local level = PlainCall(mythicPlus.GetOwnedKeystoneLevel)
  if type(mapID) ~= "number" or mapID <= 0 or type(level) ~= "number" or level <= 0 then
    return nil, nil
  end
  return mapID, level
end

--- Target of the previews: the player's own keystone (map and level), else
--- the active season's first dungeon at +15. Without an active season there
--- is no verified target and the previews render without a dungeon.
--- @return number|nil mapID, string|nil name, number level
function FactoryDemoCards.ResolveTarget(ctx)
  local ownMapID, ownLevel = ReadOwnedKeystone()
  local ownName = ownMapID and ResolveSeasonDungeonName(ctx, ownMapID) or nil
  if ownName then
    return ownMapID, ownName, ownLevel
  end
  local seasonData = GetSeasonData(ctx)
  if type(seasonData) ~= "table" or type(seasonData.GetOrderedMapIDs) ~= "function" then
    return nil, nil, DEMO_TARGET_KEY_LEVEL
  end
  local orderedMapIDs = seasonData.GetOrderedMapIDs()
  local mapID = type(orderedMapIDs) == "table" and orderedMapIDs[1] or nil
  local name = type(mapID) == "number" and ResolveSeasonDungeonName(ctx, mapID) or nil
  if not name then
    return nil, nil, DEMO_TARGET_KEY_LEVEL
  end
  return mapID, name, DEMO_TARGET_KEY_LEVEL
end

local function ReadPlayerFullName()
  local name, realm = PlainCall(rawget(_G, "UnitFullName"), "player")
  if type(name) ~= "string" or name == "" then
    return nil
  end
  if type(realm) ~= "string" or realm == "" then
    realm = PlainCall(rawget(_G, "GetNormalizedRealmName"))
  end
  if type(realm) == "string" and realm ~= "" then
    return name .. "-" .. realm
  end
  return name
end

-- Simulated M+ invite for the live accepted-invite card. `ownListing` turns
-- it into the joined-own-listing variant (the player leads the search).
local function BuildInvitePayload(ctx, ownListing)
  local L = GetL(ctx)
  local mapID, name, level = FactoryDemoCards.ResolveTarget(ctx)
  local payload = {
    mapID = mapID,
    level = level,
    leaderName = DEMO_INVITE_LEADER_NAME,
    groupName = name and string.format("+%d %s", level, name) or nil,
    sourceText = L.SIM_NOTICE_SOURCE_TABLET or "Simulation tablet",
  }
  if ownListing then
    payload.leaderName = ReadPlayerFullName() or DEMO_INVITE_LEADER_NAME
    payload.sourceText = L.INVITE_ACCEPTED_NOTICE_SOURCE_OWN_LFG_LISTING or "Own LFG key search"
    payload.title = L.INVITE_ACCEPTED_NOTICE_TITLE_OWN_LFG_LISTING or "isiLive - LFG key search"
  end
  return payload
end

--- Center-notice payload of the accepted-invite card for the stacked full
--- preview: { message, durationSeconds, dungeonName, activityID, showOptions }.
function FactoryDemoCards.BuildAcceptedInviteNotice(ctx, ownListing)
  local build = FI.BuildAcceptedInviteNoticeArgs
  if type(build) ~= "function" then
    return nil
  end
  local args = build(ctx, ctx.modules or {}, BuildInvitePayload(ctx, ownListing))
  return {
    message = nil,
    durationSeconds = nil,
    dungeonName = args.dungeonName,
    activityID = args.activityID,
    showOptions = args.options,
  }
end

local function ShowNotice(ctx, notice)
  if notice and type(ctx.ShowCenterNotice) == "function" then
    ctx.ShowCenterNotice(
      notice.message,
      notice.durationSeconds,
      notice.dungeonName,
      notice.activityID,
      notice.showOptions
    )
  end
end

function FactoryDemoCards.ShowAcceptedInvite(ctx)
  ShowNotice(ctx, FactoryDemoCards.BuildAcceptedInviteNotice(ctx, false))
end

function FactoryDemoCards.ShowJoinedOwnListing(ctx)
  ShowNotice(ctx, FactoryDemoCards.BuildAcceptedInviteNotice(ctx, true))
end

-- Raid invite: the raid and its title are simulated, the role is the
-- player's own.
function FactoryDemoCards.ShowAcceptedRaidInvite(ctx)
  local render = FI.RenderAcceptedRaidInviteNotice
  if type(render) ~= "function" then
    return
  end
  local L = GetL(ctx)
  render(ctx, ctx.modules or {}, {
    mapName = L.SIM_RAID_NAME or "Raid (simulated)",
    groupName = DEMO_RAID_GROUP_NAME,
  }, false)
end

local function ReadCurrentInstance()
  local name, instanceType, difficultyID = PlainCall(rawget(_G, "GetInstanceInfo"))
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return { name = name, instanceType = instanceType, difficultyID = difficultyID }
end

local RAID_DIFFICULTY_KEYS = {
  [14] = "DUNGEON_DIFF_RAID_NORMAL",
  [15] = "DUNGEON_DIFF_RAID_HEROIC",
  [16] = "DUNGEON_DIFF_RAID_MYTHIC",
  [17] = "DUNGEON_DIFF_RAID_LFR",
}

--- Center-notice payload of the instance-entry card ("party" or "raid"),
--- built by the live Status builder. Inside a matching instance it names that
--- instance; otherwise the dungeon is the preview target on Normal and the raid
--- is simulated.
function FactoryDemoCards.BuildInstanceEntryNotice(ctx, instanceType)
  local status = ctx.addonTable and ctx.addonTable.Status
  if type(status) ~= "table" or type(status.BuildInstanceEntryNotice) ~= "function" then
    return nil
  end
  local L = GetL(ctx)
  local current = ReadCurrentInstance()
  local name, difficultyText
  if current and current.instanceType == instanceType then
    name = current.name
    local raidKey = instanceType == "raid" and RAID_DIFFICULTY_KEYS[current.difficultyID] or nil
    difficultyText = raidKey and L[raidKey] or nil
  end
  if instanceType == "raid" then
    name = name or L.SIM_RAID_NAME or "Raid (simulated)"
    difficultyText = difficultyText or L.DUNGEON_DIFF_RAID_HEROIC or "Heroic"
  else
    name = name or select(2, FactoryDemoCards.ResolveTarget(ctx))
    difficultyText = difficultyText or L.DUNGEON_DIFF_NORMAL or "Normal"
  end
  local template, showOptions = status.BuildInstanceEntryNotice(L, instanceType, difficultyText, name)
  return {
    message = string.format(template, difficultyText),
    durationSeconds = 120,
    dungeonName = nil,
    activityID = nil,
    showOptions = showOptions,
  }
end

function FactoryDemoCards.ShowInstanceEntry(ctx, instanceType)
  ShowNotice(ctx, FactoryDemoCards.BuildInstanceEntryNotice(ctx, instanceType))
end

-- Same call as the live leader watch.
function FactoryDemoCards.ShowLeadTransferred(ctx)
  if type(ctx.ShowCenterNotice) == "function" then
    ctx.ShowCenterNotice(GetL(ctx).LEAD_TRANSFERRED_CENTER, 20)
  end
end

-- Has no live counterpart: the tablet's own group-full card.
function FactoryDemoCards.ShowGroupFull(ctx)
  if type(ctx.ShowCenterNotice) ~= "function" then
    return
  end
  local L = GetL(ctx)
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

--- The real talent & loot check for the preview target: the player's own
--- loadouts and loot spec; its buttons really switch (out of combat).
function FactoryDemoCards.ShowLoadoutCheck(ctx)
  local loadoutCheck = ctx.addonTable and ctx.addonTable.LoadoutCheck
  if type(loadoutCheck) ~= "table" or type(loadoutCheck.ShowPreview) ~= "function" then
    return false
  end
  local mapID, name = FactoryDemoCards.ResolveTarget(ctx)
  return loadoutCheck.ShowPreview(mapID, name)
end

function FactoryDemoCards.HideLoadoutCheck(ctx)
  local loadoutCheck = ctx.addonTable and ctx.addonTable.LoadoutCheck
  if type(loadoutCheck) == "table" and type(loadoutCheck.HidePreview) == "function" then
    loadoutCheck.HidePreview()
  end
end

-- Power Infusion on the loaded player from a simulated party priest. The
-- preview bypasses the duplicate latch so it renders on every replay.
function FactoryDemoCards.ShowPowerInfusion(ctx)
  if type(ctx.ShowPowerInfusionAnnounce) == "function" then
    ctx.ShowPowerInfusionAnnounce(DEMO_PI_CASTER_NAME, ReadPlayerFullName() or "Player", true, true)
  end
end

return FactoryDemoCards
