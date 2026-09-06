-- Standalone CLI tool: walks the full group-leader-handoff cascade and verifies
-- that the addon's status-announce + LFG-invite state survive a mid-key
-- leadership transfer without firing duplicate chat lines, dropping the
-- accepted invite's metadata, or replaying the post-invite announce.
--
-- Real-world scenario this guards against:
--   * Player accepts a +14 KR invite from leader Alice. First "Ziel-Dungeon"
--     announce fires with "+14".
--   * Alice leaves the group mid-key (DC, ragequit, vote-kick).
--   * Leadership transfers to Bob; Blizzard fires PARTY_LEADER_CHANGED +
--     GROUP_ROSTER_UPDATE in quick succession.
--   * Production bug class: any of these events re-running the status
--     announce path with a flickering level source (LFG-title hint cleared,
--     owner-key resync incomplete) would print a second/third "Ziel-Dungeon"
--     line — the same family as the multi-invite race fixed in e39f98c.
--
-- This simulator wires together:
--   * isiLive_lfg_detect.lua (real)         — verifies activeInvite* survives
--   * isiLive_leader_watch.lua (real)       — verifies center-notice on gain
--   * isiLive_status.lua (real)             — verifies Fix 2 lock-in holds
--                                             across leader changes
--   * isiLive_factory_controllers.lua (real) — drives ctx.GetStatusTargetDungeonInfo
--                                              so the level-resolver chain
--                                              (LFG-title hint -> owner-key ->
--                                              synced-target) is exercised
--                                              end-to-end across the cascade.
---@diagnostic disable: undefined-global
local io = io
---@diagnostic disable-next-line: undefined-global
local load = load

local function LoadLocal(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  assert(chunk, err)
  return chunk()
end

local Harness = LoadLocal("testmodul/isilive_test_harness.lua")

local failures = 0

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

local function BuildC_LFGList(searchResults)
  return {
    GetSearchResultInfo = function(id)
      return searchResults[id]
    end,
    GetActiveEntryInfo = function()
      return nil
    end,
    GetActivityFullName = function()
      return nil
    end,
    GetActivityInfoTable = function()
      return nil
    end,
  }
end

local function BuildSimGlobals(searchResults, groupRef)
  local capturedOnEvent
  return {
    CreateFrame = function()
      return {
        RegisterEvent = function() end,
        SetScript = function(_, scriptType, fn)
          if scriptType == "OnEvent" then
            capturedOnEvent = fn
          end
        end,
      }
    end,
    C_Timer = {
      NewTicker = function() end,
    },
    DEFAULT_CHAT_FRAME = {
      AddMessage = function() end,
    },
    C_LFGList = BuildC_LFGList(searchResults),
    IsInGroup = function()
      return groupRef.inGroup
    end,
    IsInRaid = function()
      return false
    end,
    GetNumGroupMembers = function()
      return groupRef.members
    end,
    GetInstanceInfo = function()
      return "Outside", "none", 0, "Unknown"
    end,
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return nil
      end,
    },
  }, function(event, ...)
    local addon = rawget(_G, "__isilive_last_loaded_addon")
    if addon and addon.LFGDetect and type(addon.LFGDetect.HandleEvent) == "function" then
      addon.LFGDetect.HandleEvent(event, ...)
    elseif capturedOnEvent then
      capturedOnEvent(nil, event, ...)
    end
  end
end

local function Run()
  print("========== Group-leader-handoff cascade simulator ==========\n")

  local groupRef = { inGroup = false, members = 0 }
  local searchResults = {
    [3] = { activityID = 514, name = "+14 KR push", leaderName = "Alice-Realm" },
  }
  local globals, fire = BuildSimGlobals(searchResults, groupRef)

  Harness.WithGlobals(globals, function()
    local addon = Harness.LoadAddonModules({
      "isiLive_runtime_state.lua",
      "isiLive_lfg_detect.lua",
      "isiLive_status.lua",
      "isiLive_sound_utils.lua",
      "isiLive_leader_watch.lua",
      "isiLive_factory_controllers.lua",
    })

    -- ----------------------------------------------------------------------
    -- Real ctx.GetStatusTargetDungeonInfo from factory_controllers.lua —
    -- replaces the previous statusModel.target poke. The resolver chain
    -- (LFG-title hint > owner-key > synced-target) runs end-to-end so the
    -- post-leader-change assertions exercise the same code path as production.
    -- ----------------------------------------------------------------------
    local resolverScenario = {
      roster = {},
      ownerUnit = nil,
    }
    local runtimeState = addon.RuntimeState.CreateController({})
    local ctx = {
      modules = {
        sync = {
          NormalizePlayerKey = function(name, realm)
            return (name or "") .. "-" .. (realm or "")
          end,
          GetPlayerTargetInfo = function()
            return nil
          end,
        },
        teleport = {
          GetTeleportInfoByMapID = function(mapID)
            if mapID == 249 then
              return { mapName = "King's Rest" }
            end
            return nil
          end,
        },
        queue = {
          GetActivityName = function()
            return nil
          end,
        },
      },
      runtimeState = runtimeState,
      locale = "enUS",
      L = {
        UNKNOWN_GROUP = "unknown",
        CHAT_QUEUE_PREFIX = "ISI-Q",
        JOINED_FROM_QUEUE = "joined %s",
      },
      GetRoster = function()
        return resolverScenario.roster
      end,
      IsPlayerLeader = function()
        return false
      end,
      Print = function() end,
      UpdateStatusLine = function() end,
      ResolveMapIDByActivityID = function(activityID)
        if activityID == 514 then
          return 249
        end
        return nil
      end,
    }
    ctx.GetL = function()
      return ctx.L
    end
    addon._FactoryInternal.InitializeFactoryRuntimeHelpers(ctx)
    ctx.ResolveActiveKeyOwnerUnit = function()
      return resolverScenario.ownerUnit
    end

    local statusModel = { prints = {} }
    local statusController = addon.Status.CreateController({
      getL = function()
        return {
          STATUS_TARGET_DUNGEON_TEXT = "Target Dungeon: %s",
          STATUS_TARGET_DUNGEON_NONE = "Target Dungeon: -",
        }
      end,
      isInGroup = function()
        return groupRef.inGroup
      end,
      getTargetDungeonInfo = ctx.GetStatusTargetDungeonInfo,
      printFn = function(message)
        table.insert(statusModel.prints, tostring(message))
      end,
    })

    -- ----------------------------------------------------------------------
    -- LeaderWatch controller — drives the leader-gain center-notice path.
    -- ----------------------------------------------------------------------
    local leaderModel = {
      isLeader = false,
      wasGroupLeader = nil,
      centerNotices = {},
      leadLostPrints = {},
      mainFrameShown = true,
      leaderButtonUpdates = 0,
    }
    local leaderController = addon.LeaderWatch.CreateController({
      isPlayerLeader = function()
        return leaderModel.isLeader
      end,
      getWasGroupLeader = function()
        return leaderModel.wasGroupLeader
      end,
      setWasGroupLeader = function(value)
        leaderModel.wasGroupLeader = value
      end,
      isStopped = function()
        return false
      end,
      isMainFrameShown = function()
        return leaderModel.mainFrameShown
      end,
      showCenterNotice = function(message, duration)
        table.insert(leaderModel.centerNotices, { message = message, duration = duration })
      end,
      printFn = function(message)
        table.insert(leaderModel.leadLostPrints, tostring(message))
      end,
      getL = function()
        return {
          LEAD_LOST = "You are no longer the group leader.",
          LEAD_TRANSFERRED_CENTER = "You are now the group leader!",
        }
      end,
      updateLeaderButtons = function()
        leaderModel.leaderButtonUpdates = leaderModel.leaderButtonUpdates + 1
      end,
    })
    leaderController.Start()

    -- ----------------------------------------------------------------------
    -- Phase 1: Player accepts +14 KR invite from Alice. First announce fires.
    -- ----------------------------------------------------------------------
    print("---- Phase 1: invite-accept + first announce ----")
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 3, "invited")
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 3, "inviteaccepted")
    groupRef.inGroup = true
    groupRef.members = 5
    fire("GROUP_ROSTER_UPDATE")

    Check(addon.LFGDetect.GetActiveInviteTitleLevel() == 14, "post-accept: activeInviteTitleLevel == 14")
    Check(addon.LFGDetect.GetActiveInviteLeader() == "Alice-Realm", "post-accept: activeInviteLeader points at Alice")
    Check(addon.LFGDetect.GetAcceptedInviteSearchResultID() == 3, "post-accept: acceptedInviteSearchResultID captured")

    -- Drive the REAL ctx.GetStatusTargetDungeonInfo. With LFGDetect.GetActiveInviteTitleLevel()
    -- already set to 14 from the accept above, the resolver yields
    -- {name="King's Rest", level=14} via the title-priority branch.
    local resolved1 = ctx.GetStatusTargetDungeonInfo()
    Check(
      type(resolved1) == "table" and resolved1.level == 14,
      "Phase 1: real GetStatusTargetDungeonInfo yields level=14 from LFG-title hint"
    )
    statusController.MaybeAnnounceTargetDungeonChat()
    Check(#statusModel.prints == 1, "Phase 1: first announce fires once")
    Check(
      statusModel.prints[1] == "Target Dungeon: |cffffd200King's Rest +14|r",
      "Phase 1: announce carries the +14 level"
    )

    -- ----------------------------------------------------------------------
    -- Phase 2: Alice (the original leader / +14 key owner) leaves mid-key.
    -- Leadership transfers to Bob (a non-isiLive user). The player remains
    -- a member, just with a different leader. Multiple events fire in close
    -- sequence: PARTY_LEADER_CHANGED, GROUP_ROSTER_UPDATE.
    -- ----------------------------------------------------------------------
    print("\n---- Phase 2: original leader leaves, Bob promoted ----")
    groupRef.members = 4
    -- LFGDetect should keep the in-group state — player is still grouped.
    fire("GROUP_ROSTER_UPDATE")
    Check(
      addon.LFGDetect.GetActiveInviteTitleLevel() == 14,
      "leader leaves: LFGDetect keeps activeInviteTitleLevel (player still in group)"
    )
    Check(
      addon.LFGDetect.GetAcceptedInviteSearchResultID() == 3,
      "leader leaves: acceptedInviteSearchResultID survives roster update"
    )

    -- LeaderWatch: player still NOT leader (Bob is), so wasGroupLeader stays false.
    leaderController.UpdateLeaderState("PARTY_LEADER_CHANGED")
    Check(#leaderModel.centerNotices == 0, "leader-change to Bob: no center-notice (player not promoted)")

    -- Inject an owner-key resync for the same dungeon at level 13 — the
    -- pre-Fix-1 bug class would have downgraded the announce. With the real
    -- resolver, LFG-title hint=14 wins and the lock-in suppresses re-announce.
    resolverScenario.roster = {
      party1 = { name = "Bob", realm = "Realm", keyLevel = 13, isGhost = false },
    }
    resolverScenario.ownerUnit = "party1"
    local resolvedAfterLeaderChange = ctx.GetStatusTargetDungeonInfo()
    Check(
      type(resolvedAfterLeaderChange) == "table" and resolvedAfterLeaderChange.level == 14,
      "leader-change: resolver still returns level=14 even with owner-key=13 in roster (Fix 1)"
    )
    statusController.MaybeAnnounceTargetDungeonChat()
    Check(#statusModel.prints == 1, "leader-change: same +14 must NOT re-announce (Fix 2 lock-in)")

    -- ----------------------------------------------------------------------
    -- Phase 3: Bob also leaves; player gets promoted to leader.
    -- Leader-gain center notice MUST fire, but status announce must not.
    -- ----------------------------------------------------------------------
    print("\n---- Phase 3: player promoted to leader ----")
    groupRef.members = 3
    leaderModel.isLeader = true
    fire("GROUP_ROSTER_UPDATE")
    leaderController.UpdateLeaderState("PARTY_LEADER_CHANGED")

    Check(#leaderModel.centerNotices == 1, "leader-gain: center notice fires exactly once")
    Check(
      leaderModel.centerNotices[1].message == "You are now the group leader!",
      "leader-gain: notice carries the LEAD_TRANSFERRED_CENTER text"
    )
    Check(leaderModel.wasGroupLeader == true, "leader-gain: wasGroupLeader updated")
    Check(leaderModel.leaderButtonUpdates >= 1, "leader-gain: leader buttons re-rendered")

    -- Resolver still yields +14 (LFG-title hint unchanged across leader change).
    statusController.MaybeAnnounceTargetDungeonChat()
    Check(
      #statusModel.prints == 1,
      "post-promotion: status lock-in still holds; no fourth announce for the same dungeon"
    )

    Check(
      addon.LFGDetect.GetActiveInviteLeader() == "Alice-Realm",
      "post-promotion: activeInviteLeader still tracks the LFG-listing leader (not the current group leader)"
    )

    -- ----------------------------------------------------------------------
    -- Phase 4: player leaves the group entirely (e.g. dungeon completed,
    -- /reload, or vote-kick). All LFG-detect state must clear, and the
    -- status lock-in must reset so the next key cycle can announce again.
    -- ----------------------------------------------------------------------
    print("\n---- Phase 4: player leaves group, then joins a fresh +14 ----")
    groupRef.inGroup = false
    groupRef.members = 0
    leaderModel.isLeader = false
    fire("GROUP_ROSTER_UPDATE")
    leaderController.UpdateLeaderState("PARTY_LEADER_CHANGED")

    Check(
      addon.LFGDetect.GetActiveInviteTitleLevel() == nil,
      "leave-group: ClearAllStateImpl drops activeInviteTitleLevel"
    )
    Check(addon.LFGDetect.GetActiveInviteLeader() == nil, "leave-group: ClearAllStateImpl drops activeInviteLeader")
    Check(
      addon.LFGDetect.GetAcceptedInviteSearchResultID() == nil,
      "leave-group: ClearAllStateImpl drops acceptedInviteSearchResultID"
    )
    Check(#leaderModel.leadLostPrints == 1, "leave-group: 'lead lost' message printed")

    -- ResetTargetDungeonChatState: solo + nil-target, then fresh accept.
    resolverScenario.roster = {}
    resolverScenario.ownerUnit = nil
    statusController.MaybeAnnounceTargetDungeonChat() -- triggers ResetTargetDungeonChatState

    -- New cycle: same dungeon name, fresh accept. Lock-in must be cleared.
    groupRef.inGroup = true
    groupRef.members = 5
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 3, "invited")
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 3, "inviteaccepted")
    statusController.MaybeAnnounceTargetDungeonChat()
    Check(#statusModel.prints == 2, "fresh cycle: same dungeon name announces again because lock-in was reset")
  end)

  if failures > 0 then
    print(string.format("\nLeader-handoff cascade simulator failed: %d check(s) failed", failures))
    os.exit(1)
  end

  print("\nLeader-handoff cascade simulator passed.")
end

Run()
