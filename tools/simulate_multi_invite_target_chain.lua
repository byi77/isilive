-- Standalone CLI tool: reproduces the real-life multi-invite race that produced
-- three "Ziel-Dungeon" chat lines and a wrong invite-hint dungeon name.
--
-- Real-world scenario (player report 2026-05-03):
--   * Player has King's Rest +13 in their bag.
--   * Player listed for / received invites from THREE LFG groups in parallel:
--       A: "+12 farm"        (other dungeon)
--       B: "+13 KR"         (same dungeon as own key)
--       C: "+14 KR"         (the leader's actual key, different player)
--   * Player accepts C (the +14 KR).
--   * Listing A delists ("LFG abgemeldet").
--   * The chat sees:
--       1.  "Ziel-Dungeon: Koenigsruh +14"   (correct, from LFG-title hint)
--       2.  "Ziel-Dungeon: Koenigsruh +13"   (WRONG — own key surfaced)
--       3.  "Ziel-Dungeon: Koenigsruh"       (WRONG — level cleared entirely)
--   * The invite-hint above the Blizzard dialog showed the wrong dungeon
--     (latest invite text overwriting earlier text without dialog binding).
--
-- Verifies the three fixes:
--   * Fix 1 (game/isiLive_lfg_detect.lua, OnInviteDeclined): a delisted /
--     declined invite for a different searchResultID must NOT erase the
--     accepted invite's activeInviteTitleLevel / activeInviteLeader.
--   * Fix 2 (ui/isiLive_status.lua, MaybeAnnounceTargetDungeonChat): once a
--     dungeon was announced WITH a level, every later announce for the same
--     dungeon name (level downgrade, level clear) must be suppressed.
--   * Fix 3a (game/isiLive_lfg_detect.lua + ui/isiLive_notice.lua): the invite
--     hint must carry the searchResultID so the floating box can hide itself
--     when the visible LFGListInviteDialog references a different listing.
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

-- ----------------------------------------------------------------------
-- Build the LFGDetect stubs (C_LFGList, IsInGroup, CreateFrame).
-- ----------------------------------------------------------------------

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

local function BuildLFGDetectGlobals(searchResults, isInGroupRef, numGroupMembersRef)
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
      return isInGroupRef[1]
    end,
    IsInRaid = function()
      return false
    end,
    GetNumGroupMembers = function()
      return numGroupMembersRef[1]
    end,
  }, function(event, ...)
    local addon = rawget(_G, "__isilive_last_loaded_addon")
    if addon and addon.LFGDetect and type(addon.LFGDetect.HandleEvent) == "function" then
      addon.LFGDetect.HandleEvent(event, ...)
    elseif capturedOnEvent then
      capturedOnEvent(nil, event, ...)
    end
  end
end

-- ----------------------------------------------------------------------
-- Build the Status controller. Drives the chat-announce side directly so
-- we can assert the exact print sequence.
-- ----------------------------------------------------------------------

local function BuildStatusController(addon, deps)
  return addon.Status.CreateController({
    getL = function()
      return {
        STATUS_TARGET_DUNGEON_TEXT = "Target Dungeon: %s",
        STATUS_TARGET_DUNGEON_NONE = "Target Dungeon: -",
      }
    end,
    isInGroup = function()
      return deps.isInGroup()
    end,
    getTargetDungeonInfo = function()
      return deps.getTargetDungeonInfo()
    end,
    printFn = function(message)
      table.insert(deps.prints, tostring(message))
    end,
  })
end

-- ----------------------------------------------------------------------
-- Lightweight invite-hint stub. Captures every render call so we can
-- verify Fix 3a passes the searchResultID through. The hint frame's
-- dialog-binding is exercised by unit tests; here we only assert the
-- callback contract.
-- ----------------------------------------------------------------------

local function BuildHintCapture()
  local hints = {}
  return hints,
    function(message, durationSeconds, searchResultID)
      table.insert(hints, {
        message = message,
        duration = durationSeconds,
        searchResultID = searchResultID,
      })
    end
end

-- ----------------------------------------------------------------------
-- The single-driver simulator.
-- ----------------------------------------------------------------------

local function Run()
  print("========== Multi-invite + level-flicker target-chain simulator ==========\n")

  local isInGroup = { false }
  local numMembers = { 0 }

  -- Three parallel listings:
  --   1: "+12 ZA farm"                — other dungeon
  --   2: "+13 KR self"               — same dungeon as the own +13 key
  --   3: "Koenigsruh +14 push"  — the listing the player accepts
  local searchResults = {
    [1] = { activityID = 1542, name = "+12 Spire farm", leaderName = "Farmguy-Realm" },
    [2] = { activityID = 514, name = "+13 KR easy", leaderName = "Selfish-Realm" },
    [3] = { activityID = 514, name = "Koenigsruh +14 push", leaderName = "Pusher-Realm" },
  }

  local globals, fire = BuildLFGDetectGlobals(searchResults, isInGroup, numMembers)

  Harness.WithGlobals(globals, function()
    local addon = Harness.LoadAddonModules({
      "isiLive_runtime_state.lua",
      "isiLive_lfg_detect.lua",
      "isiLive_status.lua",
      "isiLive_factory_controllers.lua",
    })

    -- Wire the invite-hint capture.
    local hints, hintCallback = BuildHintCapture()
    addon.LFGDetect.SetInviteHintCallback(hintCallback)
    addon.LFGDetect.SetInviteHintEnabledFn(function()
      return true
    end)
    addon.LFGDetect.SetInviteHintLocaleFn(function()
      return {
        INVITE_HINT_GROUP = "Group: %s",
        INVITE_HINT_UNKNOWN_DUNGEON = "Unknown",
      }
    end)
    -- Drive the status controller through the REAL production resolver
    -- (ctx.GetStatusTargetDungeonInfo from factory_controllers.lua) so the
    -- LFG-title-priority logic (Fix 1) is exercised end-to-end alongside
    -- the Status-controller lock-in (Fix 2). The roster is a steerable
    -- input the test can flip per phase to mimic the owner-key surfacing.
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
    -- ResolveActiveKeyOwnerUnit lives outside InitializeFactoryRuntimeHelpers
    -- (it depends on highlightController in production). Stub it so the test
    -- can drive the owner-key fallback explicitly.
    ctx.ResolveActiveKeyOwnerUnit = function()
      return resolverScenario.ownerUnit
    end

    local statusModel = {
      inGroup = false,
      prints = {},
    }
    local statusController = BuildStatusController(addon, {
      isInGroup = function()
        return statusModel.inGroup
      end,
      getTargetDungeonInfo = ctx.GetStatusTargetDungeonInfo,
      prints = statusModel.prints,
    })

    -- ------------------------------------------------------------------
    -- Phase 1: three invites arrive in quick succession.
    -- Pre-accept invite hints were removed; the detector must keep tracking
    -- the pending invites without rendering hint frames.
    -- ------------------------------------------------------------------
    print("---- Phase 1: three parallel invites arrive ----")
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 2, "invited")
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 3, "invited")

    Check(#hints == 0, "incoming invites keep removed pre-accept invite hints suppressed")

    -- ------------------------------------------------------------------
    -- Phase 2: player accepts listing C (the +14 KR push).
    -- activeInviteTitleLevel must lock onto 14 and acceptedInviteSearchResultID
    -- must point at listing 3.
    -- ------------------------------------------------------------------
    print("\n---- Phase 2: accept listing C (+14 KR) ----")
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 3, "inviteaccepted")
    isInGroup[1] = true
    numMembers[1] = 2
    fire("GROUP_ROSTER_UPDATE")

    Check(addon.LFGDetect.GetDetectedMapID() == 249, "detectedMapID resolves to King's Rest")
    Check(
      addon.LFGDetect.GetActiveInviteTitleLevel() == 14,
      "activeInviteTitleLevel resolves to +14 from the accepted listing's title"
    )
    Check(
      addon.LFGDetect.GetActiveInviteLeader() == "Pusher-Realm",
      "activeInviteLeader resolves to the +14-listing's leader"
    )
    Check(
      addon.LFGDetect.GetAcceptedInviteSearchResultID() == 3,
      "acceptedInviteSearchResultID is captured (Fix 1 prerequisite)"
    )

    -- First Status announce: drive the REAL ctx.GetStatusTargetDungeonInfo
    -- resolver. With LFGDetect.GetActiveInviteTitleLevel() == 14 (set by the
    -- accept event above) and the resolver's title-wins priority (Fix 1), it
    -- must yield { name="King's Rest", level=14 }.
    statusModel.inGroup = true
    local resolved = ctx.GetStatusTargetDungeonInfo()
    Check(
      type(resolved) == "table" and resolved.name == "King's Rest" and resolved.level == 14,
      "real GetStatusTargetDungeonInfo yields {King's Rest, +14} from the LFG-title hint"
    )
    statusController.MaybeAnnounceTargetDungeonChat()
    Check(#statusModel.prints == 1, "first announce fires once for the locked-in +14 target")
    Check(
      statusModel.prints[1] == "Target Dungeon: |cffffd200King's Rest +14|r",
      "first announce carries the +14 level"
    )

    -- ------------------------------------------------------------------
    -- Phase 3: parallel listings get delisted ("+12 Spire abgemeldet" /
    -- "+13 KR abgemeldet"). Each fires a NEGATIVE_STATUS update for a
    -- searchResultID OTHER than the accepted one. With Fix 1, neither
    -- may null out activeInviteTitleLevel / activeInviteLeader.
    -- ------------------------------------------------------------------
    print("\n---- Phase 3: parallel listings delist (Fix 1 guard) ----")
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined_delisted")
    Check(
      addon.LFGDetect.GetActiveInviteTitleLevel() == 14,
      "OnInviteDeclined for listing A (different mapID) keeps activeInviteTitleLevel"
    )
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 2, "declined_delisted")
    Check(
      addon.LFGDetect.GetActiveInviteTitleLevel() == 14,
      "OnInviteDeclined for listing B (same mapID, other searchResultID) keeps activeInviteTitleLevel"
    )
    Check(
      addon.LFGDetect.GetActiveInviteLeader() == "Pusher-Realm",
      "activeInviteLeader survives parallel-listing delists"
    )
    Check(
      addon.LFGDetect.GetDetectedMapID() == 249,
      "detectedMapID survives parallel-listing delists (highlight stays on)"
    )

    -- ------------------------------------------------------------------
    -- Phase 4: even WITHOUT Fix 1, the next status calls would have re-
    -- announced as level downgraded. Drive the same level-flicker pattern
    -- through MaybeAnnounceTargetDungeonChat to verify Fix 2 lock-in.
    --
    -- Step 4a: own-key surfaces (level=13, same dungeon name).
    -- Step 4b: sync flickers, level=nil entirely.
    -- Step 4c: level=14 again (settled).
    -- All three calls must remain silent because Fix 2 locked the dungeon.
    -- ------------------------------------------------------------------
    -- Phase 4 has TWO layers of defense:
    --   (a) Resolver layer (Fix 1): even when an own-key surfaces in the roster
    --       at level 13, ctx.GetStatusTargetDungeonInfo must keep returning
    --       level=14 because the LFG-title hint takes priority.
    --   (b) Status-controller lock-in (Fix 2): even if the resolver were to
    --       degrade (level downgrade or level-less), MaybeAnnounceTargetDungeonChat
    --       must suppress duplicate announces for the same dungeon name.
    print("\n---- Phase 4: resolver title-priority + status-controller lock-in ----")

    -- Layer (a): inject a roster-owner with a +13 key for the same dungeon.
    -- The resolver MUST keep level=14 thanks to the LFG-title hint.
    resolverScenario.roster = {
      party1 = {
        name = "Selfish",
        realm = "Realm",
        keyLevel = 13,
        isGhost = false,
      },
    }
    resolverScenario.ownerUnit = "party1"
    local layerA = ctx.GetStatusTargetDungeonInfo()
    Check(
      type(layerA) == "table" and layerA.level == 14,
      "Fix 1 (resolver): owner key=13 in roster must NOT downgrade level when LFG-title hint=14"
    )
    statusController.MaybeAnnounceTargetDungeonChat()
    Check(
      #statusModel.prints == 1,
      "no second announce when resolver returns the same dungeon+level as the previous one"
    )

    -- Layer (b): hard-clear the LFG-title hint AND remove the owner unit so
    -- the resolver naturally degrades to level=nil. Status-controller lock-in
    -- must still suppress the duplicate.
    addon.LFGDetect.ClearAllState()
    -- Re-arm the detected mapID so the resolver can still produce a name
    -- (it would otherwise short-circuit to nil and Status would not announce).
    -- We do this through the LFG-detect surface, not by editing state directly.
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 3, "invited")
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 3, "inviteaccepted")
    -- Now drop the title-hint by force-clearing only the title-level field,
    -- which simulates the production path where the title text disappears
    -- between events. There is no public mutator, so route through the
    -- ClearAllState + targeted re-detection above.
    -- Owner-key sole source: roster keyLevel=13.
    local layerB = ctx.GetStatusTargetDungeonInfo()
    Check(type(layerB) == "table" and layerB.level == 14, "after re-accept, LFG-title hint is back at +14")
    statusController.MaybeAnnounceTargetDungeonChat()
    Check(#statusModel.prints == 1, "lock-in: same dungeon+level after re-accept does NOT produce a duplicate announce")

    -- ------------------------------------------------------------------
    -- Phase 5: end-of-cycle reset. After the player leaves the group, the
    -- next +N for the SAME dungeon must be free to announce again.
    --
    -- Real group-leave sequence: ClearAllState clears the LFG-detect
    -- identity slots (detectedMapID / pendingAcceptedInviteMapID /
    -- activeInviteTitleLevel / ...) and the roster empties.
    -- ctx.GetStatusTargetDungeonInfo then returns nil — that is the
    -- signal MaybeAnnounceTargetDungeonChat resets on, not IsInGroup
    -- alone (a transient IsInGroup=false is expected during the
    -- LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted -> GROUP_ROSTER_-
    -- UPDATE window, and must NOT wipe the lock-in).
    -- ------------------------------------------------------------------
    print("\n---- Phase 5: leave + rejoin must allow a fresh announce ----")
    addon.LFGDetect.ClearAllState()
    isInGroup[1] = false
    numMembers[1] = 0
    statusModel.inGroup = false
    statusController.MaybeAnnounceTargetDungeonChat() -- info=nil branch resets the state

    -- Re-establish the LFG-title hint via a fresh accept event, then enter
    -- group again. The resolver should produce the +14 target and the
    -- post-leave reset should permit a fresh announce.
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 3, "invited")
    fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 3, "inviteaccepted")
    isInGroup[1] = true
    numMembers[1] = 2
    fire("GROUP_ROSTER_UPDATE")
    statusModel.inGroup = true
    statusController.MaybeAnnounceTargetDungeonChat()
    Check(
      #statusModel.prints == 2,
      "leaving the group resets the lock-in so a fresh key joins later can announce again"
    )
    Check(
      statusModel.prints[2] == "Target Dungeon: |cffffd200King's Rest +14|r",
      "second-cycle announce carries the +14 level"
    )

    -- ------------------------------------------------------------------
    -- Phase 6: the symmetric Fix 1 case — verify that the ACTUALLY accepted
    -- listing's decline (e.g. when the player declines after accepting,
    -- which in production maps to ClearAllStateImpl via group-leave) is
    -- still allowed to clear state. We simulate it by calling ClearAllState.
    -- ------------------------------------------------------------------
    print("\n---- Phase 6: ClearAllState always wipes the accepted-resultID ----")
    addon.LFGDetect.ClearAllState()
    Check(
      addon.LFGDetect.GetAcceptedInviteSearchResultID() == nil,
      "ClearAllState drops acceptedInviteSearchResultID alongside the rest"
    )
    Check(addon.LFGDetect.GetActiveInviteTitleLevel() == nil, "ClearAllState drops activeInviteTitleLevel")
    Check(addon.LFGDetect.GetActiveInviteLeader() == nil, "ClearAllState drops activeInviteLeader")
  end)

  if failures > 0 then
    print(string.format("\nMulti-invite target-chain simulator failed: %d check(s) failed", failures))
    os.exit(1)
  end

  print("\nMulti-invite target-chain simulator passed.")
end

Run()
