---@diagnostic disable: undefined-global

-- Builds the minimal WoW global stubs needed to load isiLive_lfg_detect.lua.
-- Returns a fire(event, ...) helper that invokes the captured OnEvent handler.
local function BuildLFGDetectEnv(overrides)
  overrides = overrides or {}

  local onEvent = nil
  local prints = {}

  local globals = {
    CreateFrame = function()
      return {
        RegisterEvent = function() end,
        SetScript = function(_, scriptType, fn)
          if scriptType == "OnEvent" then
            onEvent = fn
          end
        end,
      }
    end,
    C_Timer = {
      -- Suppress the 5s ticker so tests control when CheckActiveGroup runs.
      NewTicker = function() end,
    },
    DEFAULT_CHAT_FRAME = {
      AddMessage = function(_, msg)
        table.insert(prints, tostring(msg))
      end,
    },
    IsInGroup = overrides.IsInGroup or function()
      return false
    end,
    IsInRaid = overrides.IsInRaid or function()
      return false
    end,
    GetNumGroupMembers = overrides.GetNumGroupMembers or function()
      return 0
    end,
  }

  -- Merge any extra globals the caller needs.
  if overrides.globals then
    for k, v in pairs(overrides.globals) do
      globals[k] = v
    end
  end

  return globals,
    function(event, ...)
      local addon = rawget(_G, "__isilive_last_loaded_addon")
      if addon and addon.LFGDetect and type(addon.LFGDetect.HandleEvent) == "function" then
        addon.LFGDetect.HandleEvent(event, ...)
      elseif onEvent then
        onEvent(nil, event, ...)
      end
    end,
    prints
end

-- Builds a minimal C_LFGList stub for invite scenarios.
-- searchResults maps searchResultID -> info table returned by GetSearchResultInfo.
local function BuildC_LFGList(searchResults, activeEntry)
  searchResults = searchResults or {}
  return {
    GetSearchResultInfo = function(id)
      return searchResults[id]
    end,
    GetActiveEntryInfo = function()
      return activeEntry
    end,
    GetActivityFullName = function(_activityID)
      return nil
    end,
    GetActivityInfoTable = function(_activityID)
      return nil
    end,
  }
end

local RegisterLFGDetectOwnListingAndReplayTests

local function RegisterLFGDetectResolutionTests(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  -- ---------------------------------------------------------------------------
  -- Activity-ID resolution
  -- ---------------------------------------------------------------------------

  test("LFGDetect resolves mapID from static ACTIVITY_TO_MAP on invite", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityID = 514 }, -- 514 -> 249 (King's Rest)
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "static ACTIVITY_TO_MAP must resolve 514 -> 249")
    end)
  end)

  test("LFGDetect resolves Temple of Sethraliss after accepted invite", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [4021160] = { activityID = 504, name = "+17 Sethraliss", leaderName = "SethraLead" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local highlightContext = nil
      addon.LFGDetect.SetHighlightCallback(function(soundContext)
        highlightContext = soundContext
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 4021160, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 4021160, "inviteaccepted")

      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 250, "activityID 504 must resolve to Algethar mapID 250")
      Assert.Equal(highlightContext, "invite", "accepted Academy invite must trigger the invite highlight path")
    end)
  end)

  test("LFGDetect keeps unknown invite activity unresolved instead of guessing from dungeon name", function()
    -- activityID 9999 is not in ACTIVITY_TO_MAP; name text must not be used as a fallback.
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityID = 9999, name = "King's Rest" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local callbackCount = 0
      addon.LFGDetect.SetHighlightCallback(function()
        callbackCount = callbackCount + 1
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "unknown activityID must stay unresolved without name fallback")
      Assert.Equal(callbackCount, 0, "unresolved invite must not trigger a highlight update")
    end)
  end)

  test("LFGDetect keeps conflicting invite activity maps unresolved", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityIDs = { 514, 182 }, name = "King's Rest" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local callbackCount = 0
      addon.LFGDetect.SetHighlightCallback(function()
        callbackCount = callbackCount + 1
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "conflicting activity maps must stay unresolved")
      Assert.Equal(callbackCount, 0, "ambiguous invite must not trigger a highlight update")
    end)
  end)

  test("LFGDetect keeps partially unresolved invite activity maps unresolved", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityID = 514, activityIDs = { 514, 9999 }, name = "King's Rest" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local callbackCount = 0
      addon.LFGDetect.SetHighlightCallback(function()
        callbackCount = callbackCount + 1
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "partially unresolved activity maps must stay unresolved")
      Assert.Equal(callbackCount, 0, "partially unresolved invite must not trigger a highlight update")
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- Status normalization (BUG-3)
  -- ---------------------------------------------------------------------------

  test("LFGDetect normalizes uppercase Invited status", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "Invited") -- uppercase
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "uppercase Invited must be normalized and processed")
    end)
  end)

  test("LFGDetect normalizes mixed-case InviteAccepted status", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "InviteAccepted") -- mixed case

      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "mixed-case InviteAccepted must be normalized and accepted")
    end)
  end)

  test("LFGDetect removes pending invite on declined status", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return false
      end,
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
      -- inviteaccepted arrives after decline â€” pendingInvites is empty, must be no-op
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "declined invite must not produce a detectedMapID")
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- Invite callback behavior (BUG-1, ARCH-1)
  -- ---------------------------------------------------------------------------

  test("LFGDetect exact invite stays pending until inviteaccepted and then highlights without sound", function()
    -- Incoming invites must stay pending until the exact activity data is confirmed.
    local callbackSoundContexts = {}

    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      addon.LFGDetect.SetHighlightCallback(function(soundContext)
        table.insert(callbackSoundContexts, soundContext)
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")

      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "invite must stay pending until inviteaccepted")
      Assert.Equal(#callbackSoundContexts, 0, "pending invite must not trigger a highlight update yet")

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "inviteaccepted must set detectedMapID from the pending invite"
      )
      Assert.Equal(#callbackSoundContexts, 1, "highlight callback must fire once on inviteaccepted")
      Assert.Equal(
        callbackSoundContexts[1],
        "invite",
        "inviteaccepted callback must use soundContext='invite' to suppress portal sound"
      )

      -- Key start must not clear the confirmed invite highlight any more.
      fire("CHALLENGE_MODE_START")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "CHALLENGE_MODE_START must not clear a confirmed invite highlight before dungeon entry"
      )
      Assert.Equal(#callbackSoundContexts, 1, "CHALLENGE_MODE_START must not retrigger the highlight")

      addon.LFGDetect.ClearAllState()

      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "explicit clear must still reset detectedMapID")
      Assert.Equal(#callbackSoundContexts, 2, "explicit clear must trigger a second callback")
      Assert.Equal(callbackSoundContexts[2], "queue", "explicit clear callback must pass soundContext='queue'")
    end)
  end)

  test("Highlight invite-accepted state survives transient non-group roster updates", function()
    local callbackSoundContexts = {}
    local inGroup = false
    local groupMemberCount = 5

    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return inGroup
      end,
      GetNumGroupMembers = function()
        return groupMemberCount
      end,
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      addon.LFGDetect.SetHighlightCallback(function(soundContext)
        table.insert(callbackSoundContexts, soundContext)
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "inviteaccepted must set detectedMapID")
      Assert.Equal(#callbackSoundContexts, 1, "inviteaccepted must trigger one highlight update")

      fire("GROUP_ROSTER_UPDATE")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "transient not-in-group roster updates must not clear a confirmed invite highlight"
      )
      Assert.Equal(
        #callbackSoundContexts,
        1,
        "transient not-in-group roster updates must not retrigger or clear the confirmed highlight"
      )

      inGroup = true
      fire("GROUP_ROSTER_UPDATE")

      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "confirmed invite highlight must survive group join")
      Assert.Equal(
        #callbackSoundContexts,
        1,
        "group join settlement must not emit an extra highlight update for an unchanged invite target"
      )
    end)
  end)

  test(
    "Highlight invite-accepted state survives transient zero-member roster updates before the group settles",
    function()
      local callbackSoundContexts = {}
      local inGroup = false
      local groupMemberCount = 0

      local globals, fire = BuildLFGDetectEnv({
        IsInGroup = function()
          return inGroup
        end,
        GetNumGroupMembers = function()
          return groupMemberCount
        end,
        globals = {
          C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
        },
      })

      WithGlobals(globals, function()
        local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
        addon.LFGDetect.SetHighlightCallback(function(soundContext)
          table.insert(callbackSoundContexts, soundContext)
        end)

        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

        Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "inviteaccepted must set detectedMapID")
        Assert.Equal(#callbackSoundContexts, 1, "inviteaccepted must trigger one highlight update")

        fire("GROUP_ROSTER_UPDATE")

        Assert.Equal(
          addon.LFGDetect.GetDetectedMapID(),
          249,
          "transient zero-member roster updates must not clear a confirmed invite highlight before group settle"
        )
        Assert.Equal(
          #callbackSoundContexts,
          1,
          "transient zero-member roster updates must not retrigger or clear the confirmed highlight"
        )

        inGroup = true
        groupMemberCount = 5
        fire("GROUP_ROSTER_UPDATE")

        Assert.Equal(
          addon.LFGDetect.GetDetectedMapID(),
          249,
          "confirmed invite highlight must survive the eventual group join"
        )
        Assert.Equal(#callbackSoundContexts, 1, "settled group join must not emit an extra highlight update")
      end)
    end
  )

  test(
    "Highlight invite-accepted state survives late roster false negatives while group members are still present",
    function()
      local callbackSoundContexts = {}
      local inGroup = true
      local groupMemberCount = 5

      local globals, fire = BuildLFGDetectEnv({
        IsInGroup = function()
          return inGroup
        end,
        GetNumGroupMembers = function()
          return groupMemberCount
        end,
        globals = {
          C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
        },
      })

      WithGlobals(globals, function()
        local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
        addon.LFGDetect.SetHighlightCallback(function(soundContext)
          table.insert(callbackSoundContexts, soundContext)
        end)

        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

        Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "inviteaccepted must set detectedMapID")
        Assert.Equal(#callbackSoundContexts, 1, "inviteaccepted must trigger one highlight update")

        inGroup = false
        fire("GROUP_ROSTER_UPDATE")

        Assert.Equal(
          addon.LFGDetect.GetDetectedMapID(),
          249,
          "late roster false negatives must not clear a confirmed invite while group members are still present"
        )
        Assert.Equal(
          #callbackSoundContexts,
          1,
          "late roster false negatives must not retrigger or clear the confirmed highlight while group members remain"
        )

        groupMemberCount = 0
        fire("GROUP_ROSTER_UPDATE")

        Assert.Nil(
          addon.LFGDetect.GetDetectedMapID(),
          "actual group leave must still clear the confirmed invite highlight"
        )
        Assert.Equal(#callbackSoundContexts, 2, "actual group leave must clear the confirmed highlight exactly once")
        Assert.Equal(callbackSoundContexts[2], "queue", "group leave clear must keep sound suppression")
      end)
    end
  )

  RegisterLFGDetectOwnListingAndReplayTests(test, ctx)
end

local function RegisterLFGDetectInviteAcceptRaceTests(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  test("Highlight invite-accepted state survives own-listing drop before GROUP_ROSTER_UPDATE settles", function()
    -- Race condition: after LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted the
    -- own LFG application is still briefly visible in C_LFGList.GetActiveEntryInfo
    -- (so lastQueueMapID gets set by CheckActiveGroup), and a second
    -- LFG_LIST_ACTIVE_ENTRY_UPDATE immediately drops it. In that window IsInGroup()
    -- can still return false because GROUP_ROSTER_UPDATE fires ~300ms later. The
    -- ClearDetectedState path must not clear the invite-set highlight while
    -- pendingAcceptedInviteMapID is still waiting for the roster to settle.
    local callbackSoundContexts = {}
    local inGroup = false
    local groupMemberCount = 0
    local currentActiveEntry = { activityIDs = { 514 } }

    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return inGroup
      end,
      GetNumGroupMembers = function()
        return groupMemberCount
      end,
      globals = {
        C_LFGList = {
          GetSearchResultInfo = function(id)
            if id == 1 then
              return { activityID = 514 }
            end
            return nil
          end,
          GetActiveEntryInfo = function()
            return currentActiveEntry
          end,
          GetActivityFullName = function()
            return nil
          end,
          GetActivityInfoTable = function()
            return nil
          end,
        },
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      addon.LFGDetect.SetHighlightCallback(function(soundContext)
        table.insert(callbackSoundContexts, soundContext)
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "inviteaccepted must set detectedMapID=249")

      -- Own application still present (activityIDs=[514]) -> lastQueueMapID=249.
      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "queue listing matching the accepted invite must keep detectedMapID=249"
      )

      -- Own application gets dropped between the two event firings and IsInGroup()
      -- still reports false because GROUP_ROSTER_UPDATE has not yet arrived.
      currentActiveEntry = nil

      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "transient own-listing drop before GROUP_ROSTER_UPDATE must not clear the invite-set highlight"
      )

      -- Roster finally settles with the accepted group present.
      inGroup = true
      groupMemberCount = 5
      fire("GROUP_ROSTER_UPDATE")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "GROUP_ROSTER_UPDATE with the joined group must preserve detectedMapID=249"
      )
    end)
  end)
end

RegisterLFGDetectOwnListingAndReplayTests = function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  test("LFGDetect replays an already resolved highlight when the callback is wired late", function()
    local callbackSoundContexts = {}

    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "resolved invite must keep detectedMapID even without callback"
      )

      addon.LFGDetect.SetHighlightCallback(function(soundContext)
        table.insert(callbackSoundContexts, soundContext)
      end)

      Assert.Equal(#callbackSoundContexts, 1, "late callback wiring must replay the current highlight state once")
      Assert.Equal(
        callbackSoundContexts[1],
        "queue",
        "late replay must suppress portal sound the same way as other state-sync updates"
      )
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- Own listing flow (BUG-1)
  -- ---------------------------------------------------------------------------

  test("LFGDetect own listing sets detectedMapID and calls callback with queue soundContext", function()
    local callbackSoundContexts = {}

    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({}, { activityID = 514 }),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      addon.LFGDetect.SetHighlightCallback(function(soundContext)
        table.insert(callbackSoundContexts, soundContext)
      end)

      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")

      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "own listing must set detectedMapID")
      Assert.Equal(#callbackSoundContexts, 1, "highlight callback must fire once")
      Assert.Equal(
        callbackSoundContexts[1],
        "queue",
        "own-listing callback must pass soundContext='queue' to suppress portal sound"
      )
    end)
  end)

  test("LFGDetect active listing stays unresolved when only dungeon name text is available", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({}, { activityID = 9999, name = "King's Rest" }),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local callbackCount = 0
      addon.LFGDetect.SetHighlightCallback(function()
        callbackCount = callbackCount + 1
      end)

      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")

      Assert.Nil(
        addon.LFGDetect.GetDetectedMapID(),
        "active listing must stay unresolved without exact activity mapping"
      )
      Assert.Equal(callbackCount, 0, "unresolved active listing must not trigger a highlight update")
    end)
  end)
end

local function RegisterLFGDetectQueueStateTests(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  -- ---------------------------------------------------------------------------
  -- pendingInvites survive ticker (BUG-2)
  -- ---------------------------------------------------------------------------

  test("LFGDetect pending invites survive CheckActiveGroup when no listing exists", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      -- Simulate ticker: LFG_LIST_ACTIVE_ENTRY_UPDATE with no listing
      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE") -- GetActiveEntryInfo returns nil
      -- Now inviteaccepted arrives after the tick
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "pendingInvites must survive CheckActiveGroup so late inviteaccepted still resolves"
      )
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- Invite-set detectedMapID survives ticker (BUG-LFG-4)
  -- ---------------------------------------------------------------------------

  test("LFGDetect invite-set detectedMapID survives CheckActiveGroup when no listing exists", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "detectedMapID must be set after invite accept")

      -- Simulate the 5s ticker: no active listing found
      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE") -- GetActiveEntryInfo returns nil

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "invite-set detectedMapID must survive CheckActiveGroup (BUG-LFG-4 guard)"
      )
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- Queue-set detectedMapID IS cleared when listing goes away
  -- ---------------------------------------------------------------------------

  test("LFGDetect queue-set detectedMapID is cleared when listing is removed", function()
    local activeEntry = { activityID = 514, name = "+11 weekly" }

    local globals, fire = BuildLFGDetectEnv({
      globals = {
        UnitExists = function()
          return true
        end,
        UnitFullName = function(unit)
          if unit == "player" then
            return "Isi", "Blackmoore"
          end
          return nil
        end,
        C_LFGList = {
          GetSearchResultInfo = function()
            return nil
          end,
          GetActiveEntryInfo = function()
            return activeEntry
          end,
          GetActivityFullName = function()
            return nil
          end,
          GetActivityInfoTable = function()
            return nil
          end,
        },
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE") -- listing present
      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "queue listing must set detectedMapID")
      Assert.Equal(
        addon.LFGDetect.GetActiveQueueListingGroupName(),
        "+11 weekly",
        "setup: queue listing title must be exposed"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveQueueListingLeaderName(),
        "Isi-Blackmoore",
        "setup: queue listing leader must be exposed"
      )

      activeEntry = nil -- listing removed
      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE") -- no listing

      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "queue-set detectedMapID must be cleared when listing is removed")
      Assert.Nil(
        addon.LFGDetect.GetActiveQueueListingGroupName(),
        "queue listing title must be cleared when listing is removed"
      )
      Assert.Nil(
        addon.LFGDetect.GetActiveQueueListingLeaderName(),
        "queue listing leader must be cleared when listing is removed"
      )
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- GetActiveInviteLeader: leader hint captured on inviteaccepted
  -- ---------------------------------------------------------------------------

  test("LFGDetect GetActiveInviteLeader returns leaderName after invite accepted", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityID = 514, leaderName = "Mematiwow-Blackmoore" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      Assert.Nil(addon.LFGDetect.GetActiveInviteLeader(), "pending invite must not expose leader yet")

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "Mematiwow-Blackmoore",
        "inviteaccepted must capture the LFG leaderName"
      )
    end)
  end)

  test("LFGDetect GetActiveInviteLeader is nil for queue-set detectedMapID", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({}, { activityID = 514 }),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "own listing must set detectedMapID")
      Assert.Nil(addon.LFGDetect.GetActiveInviteLeader(), "own queue path must not produce an invite leader hint")
    end)
  end)

  test("LFGDetect own queue listing exposes verified group title and local leader", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        UnitExists = function()
          return true
        end,
        UnitFullName = function(unit)
          if unit == "player" then
            return "Isi", "Blackmoore"
          end
          return nil
        end,
        C_LFGList = BuildC_LFGList({}, { activityID = 514, name = "+11 weekly" }),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")

      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "own listing must set detectedMapID")
      Assert.Equal(addon.LFGDetect.GetActiveQueueListingGroupName(), "+11 weekly", "own listing title must be exposed")
      Assert.Equal(
        addon.LFGDetect.GetActiveQueueListingLeaderName(),
        "Isi-Blackmoore",
        "own listing leader must come from the verified local unit name"
      )
    end)
  end)

  test("LFGDetect GetActiveInviteLeader clears after ClearAllState", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityID = 514, leaderName = "Leader-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetActiveInviteLeader(), "Leader-Realm", "setup: leader captured")

      addon.LFGDetect.ClearAllState()
      Assert.Nil(addon.LFGDetect.GetActiveInviteLeader(), "ClearAllState must drop the leader hint")
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- Fix 1: OnInviteDeclined must only clear active state for the accepted
  -- searchResultID. Parallel listings ("+12/+13/+14" of the same dungeon)
  -- delisting after invite-accept must not destroy activeInviteTitleLevel.
  -- ---------------------------------------------------------------------------

  test("LFGDetect OnInviteDeclined for a different searchResultID keeps active invite state", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityID = 514, name = "+13 KR", leaderName = "Other-Realm" },
          [2] = { activityID = 514, name = "+14 KR push", leaderName = "Pusher-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 2, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 2, "inviteaccepted")

      Assert.Equal(addon.LFGDetect.GetActiveInviteTitleLevel(), 14, "setup: +14 listing was accepted")
      Assert.Equal(
        addon.LFGDetect.GetAcceptedInviteSearchResultID(),
        2,
        "setup: acceptedInviteSearchResultID points at the +14 listing"
      )

      -- Listing 1 ("+13 KR") delists in parallel. Same dungeon mapID, but a
      -- different searchResultID — must not erase the +14 invite state.
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined_delisted")

      Assert.Equal(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        14,
        "delisting a different parallel listing must not null out activeInviteTitleLevel"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "Pusher-Realm",
        "delisting a different parallel listing must not null out activeInviteLeader"
      )
      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "delisting a different parallel listing must not null out detectedMapID"
      )
    end)
  end)

  -- 0.9.237 follow-up: Blizzard fires `declined_delisted` for the ACCEPTED
  -- searchResultID the moment the LFG group fills after our join. Without the
  -- post-accept guard, that event nulled activeInviteTitleLevel and the
  -- deferred chat target-dungeon announce fell back to the player's own key
  -- (wrong "+N"). The accepted-invite state must stay until the player
  -- actually leaves the group (ClearAllStateImpl).
  test("LFGDetect OnInviteDeclined for the ACCEPTED searchResultID keeps active invite state", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [42] = { activityID = 514, name = "+12 Relaxed", leaderName = "Pinto-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 42, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 42, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetActiveInviteTitleLevel(), 12, "setup: +12 listing was accepted")
      Assert.Equal(addon.LFGDetect.GetAcceptedInviteSearchResultID(), 42, "setup: accepted searchResultID is 42")

      -- The accepted listing itself delists once the group fills.
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 42, "declined_delisted")

      Assert.Equal(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        12,
        "delisting of the accepted listing after join must not null out activeInviteTitleLevel"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "Pinto-Realm",
        "delisting of the accepted listing after join must not null out activeInviteLeader"
      )
      Assert.Equal(
        addon.LFGDetect.GetAcceptedInviteSearchResultID(),
        42,
        "acceptedInviteSearchResultID must survive the post-accept delisting"
      )

      -- ClearAllState (group-leave) is the only thing allowed to drop it.
      addon.LFGDetect.ClearAllState()
      Assert.Nil(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        "ClearAllState must still drop activeInviteTitleLevel on group-leave"
      )
      Assert.Nil(addon.LFGDetect.GetActiveInviteLeader(), "ClearAllState must drop activeInviteLeader on group-leave")
    end)
  end)

  -- Same flow with declined_full (group hit max capacity at the moment of
  -- accept rather than via a separate delist event). Both negative statuses
  -- route through OnInviteDeclined and must be ignored for the accepted ID.
  test("LFGDetect OnInviteDeclined declined_full for the accepted searchResultID keeps state", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [77] = { activityID = 514, name = "+15 push", leaderName = "Push-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 77, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 77, "inviteaccepted")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 77, "declined_full")

      Assert.Equal(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        15,
        "declined_full on the accepted listing must keep activeInviteTitleLevel"
      )
    end)
  end)

  test("LFGDetect OnInviteDeclined still clears state when no accept ever happened", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [99] = { activityID = 514, name = "+13 push", leaderName = "Push-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 99, "invited")
      Assert.Nil(addon.LFGDetect.GetAcceptedInviteSearchResultID(), "setup: no accept yet")

      -- Listing gets declined / delisted before we ever accepted. The state
      -- never got promoted to "accepted", so the regular detected-map clear
      -- path still runs.
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 99, "declined_delisted")
      Assert.Nil(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        "declined of a never-accepted invite must still clear state"
      )
    end)
  end)

  -- 0.9.238 follow-up: the accepted-invite identity (leader / title-level /
  -- detectedMapID / acceptedInviteSearchResultID) used to survive across an
  -- entire group lifetime — through key completions and through leader
  -- handoffs — and surface stale "+N" values on subsequent keys. CHALLENGE_-
  -- MODE_COMPLETED / CHALLENGE_MODE_RESET and PARTY_LEADER_CHANGED now drop
  -- the accepted-invite identity (but keep pendingInvites so a separately
  -- queued application can still resolve).

  test("LFGDetect CHALLENGE_MODE_COMPLETED clears the accepted-invite identity", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [501] = { activityID = 514, name = "+13 KR", leaderName = "Leader-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 501, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 501, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetActiveInviteTitleLevel(), 13, "setup: accept captures the +13 listing")
      Assert.Equal(addon.LFGDetect.GetActiveInviteLeader(), "Leader-Realm", "setup: accept captures the leader")
      Assert.Equal(addon.LFGDetect.GetAcceptedInviteSearchResultID(), 501, "setup: accept captures the searchResultID")

      fire("CHALLENGE_MODE_COMPLETED")

      Assert.Nil(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        "CHALLENGE_MODE_COMPLETED must drop activeInviteTitleLevel so the next key's +N is not stale"
      )
      Assert.Nil(addon.LFGDetect.GetActiveInviteLeader(), "CHALLENGE_MODE_COMPLETED must drop activeInviteLeader")
      Assert.Nil(
        addon.LFGDetect.GetAcceptedInviteSearchResultID(),
        "CHALLENGE_MODE_COMPLETED must drop acceptedInviteSearchResultID"
      )
      Assert.Nil(
        addon.LFGDetect.GetDetectedMapID(),
        "CHALLENGE_MODE_COMPLETED must drop detectedMapID so the next key drives its own highlight"
      )
    end)
  end)

  test("LFGDetect CHALLENGE_MODE_RESET clears the accepted-invite identity", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [502] = { activityID = 514, name = "+15 push", leaderName = "Leader-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 502, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 502, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetActiveInviteTitleLevel(), 15, "setup: accept captures the +15 listing")

      -- Aborted run (CHALLENGE_MODE_RESET) must clear the same slots as
      -- CHALLENGE_MODE_COMPLETED — the listing identity is gone either way.
      fire("CHALLENGE_MODE_RESET")

      Assert.Nil(addon.LFGDetect.GetActiveInviteTitleLevel(), "CHALLENGE_MODE_RESET drops activeInviteTitleLevel")
      Assert.Nil(addon.LFGDetect.GetActiveInviteLeader(), "CHALLENGE_MODE_RESET drops activeInviteLeader")
    end)
  end)

  test("LFGDetect PARTY_LEADER_CHANGED clears the stale activeInviteLeader / -TitleLevel", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [503] = { activityID = 514, name = "+12 chill", leaderName = "OldLeader-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 503, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 503, "inviteaccepted")
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "OldLeader-Realm",
        "setup: accept captures the original listing leader"
      )

      -- Group form-up completes — GROUP_ROSTER_UPDATE reports inGroup=true.
      -- This flips rosterEstablishedSinceAccept and arms the next PLC as a
      -- genuine handoff (not the initial convert-to-party-lead).
      fire("GROUP_ROSTER_UPDATE")

      -- The original leader hands off / drops group; PARTY_LEADER_CHANGED
      -- fires. The captured listing identity belongs to the previous leader,
      -- so it must be dropped — the new leader is its own authority.
      fire("PARTY_LEADER_CHANGED")

      Assert.Nil(
        addon.LFGDetect.GetActiveInviteLeader(),
        "PARTY_LEADER_CHANGED must drop the stale activeInviteLeader hint"
      )
      Assert.Nil(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        "PARTY_LEADER_CHANGED must drop the stale activeInviteTitleLevel hint"
      )
      Assert.Nil(
        addon.LFGDetect.GetAcceptedInviteSearchResultID(),
        "PARTY_LEADER_CHANGED must drop the stale acceptedInviteSearchResultID"
      )
    end)
  end)

  -- Regression for the initial-convert race: WoW fires PARTY_LEADER_CHANGED
  -- when the listing owner forms the freshly accepted group, BEFORE the
  -- first GROUP_ROSTER_UPDATE reports inGroup=true. That PLC is the owner
  -- taking the lead they already have — not a handoff away from them — and
  -- the captured listing identity (leader / titleLevel / searchResultID)
  -- must stay intact so the status resolver chain can still find the +N
  -- after the form-up. Before the fix every PLC dropped the identity
  -- unconditionally.
  test("LFGDetect PARTY_LEADER_CHANGED keeps the listing identity during the initial convert-to-party-lead", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [777] = { activityID = 514, name = "+13 KR", leaderName = "Listing-Owner" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 777, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 777, "inviteaccepted")
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "Listing-Owner",
        "setup: accept captures the listing leader"
      )
      Assert.Equal(addon.LFGDetect.GetActiveInviteTitleLevel(), 13, "setup: accept captures the listing +N")

      -- Initial convert-to-party-lead: PLC fires BEFORE the first
      -- GROUP_ROSTER_UPDATE. The listing owner becomes the party leader,
      -- the captured identity still describes them, and must stay intact.
      fire("PARTY_LEADER_CHANGED")

      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "Listing-Owner",
        "initial-convert PLC must not drop activeInviteLeader"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        13,
        "initial-convert PLC must not drop activeInviteTitleLevel"
      )
      Assert.Equal(
        addon.LFGDetect.GetAcceptedInviteSearchResultID(),
        777,
        "initial-convert PLC must not drop acceptedInviteSearchResultID"
      )

      -- After the roster establishes, the SAME identity must still be
      -- there — the convert keep-path is a one-shot bypass, not a
      -- permanent immunity.
      fire("GROUP_ROSTER_UPDATE")
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "Listing-Owner",
        "post-form-up GROUP_ROSTER_UPDATE must not retroactively drop the identity"
      )

      -- A genuine handoff THEN fires: now the identity must clear.
      fire("PARTY_LEADER_CHANGED")
      Assert.Nil(
        addon.LFGDetect.GetActiveInviteLeader(),
        "second PLC after form-up is a real handoff and must clear the identity"
      )
    end)
  end)

  -- 0.9.240: direct-push hook fires with the listing's entry.titleLevel so
  -- the chat Target-Dungeon line surfaces the exact same "+N" the Center
  -- Notice rendered, without going through the status resolver chain.
  test("LFGDetect OnInviteAccepted fires the target-dungeon-chat callback with the listing payload", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [601] = { activityID = 514, name = "+13 Relaxed", leaderName = "Leader-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetTargetDungeonChatCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetTargetDungeonChatEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 601, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 601, "inviteaccepted")

      Assert.Equal(#payloads, 1, "target-dungeon-chat callback fires exactly once on accept")
      Assert.Equal(
        payloads[1].level,
        13,
        "callback payload carries entry.titleLevel — same field as the Center Notice"
      )
      Assert.Equal(payloads[1].leaderName, "Leader-Realm", "callback payload carries the leader name")
      Assert.Equal(payloads[1].groupName, "+13 Relaxed", "callback payload carries the listing title")
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteGroupName(),
        "+13 Relaxed",
        "active invite group title stays available"
      )
      Assert.Equal(payloads[1].activityID, 514, "callback payload carries the accepted activityID")
      Assert.Equal(payloads[1].searchResultID, 601, "callback payload carries the accepted searchResultID")
    end)
  end)

  test("LFGDetect inviteaccepted refreshes incomplete invited listing before direct-push", function()
    local searchInfoCalls = 0
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = {
          GetSearchResultInfo = function(id)
            if id ~= 605 then
              return nil
            end
            searchInfoCalls = searchInfoCalls + 1
            if searchInfoCalls == 1 then
              return { activityID = 514, leaderName = "Leader-Realm" }
            end
            return { activityID = 514, name = "+14 Kompetitiv", leaderName = "Leader-Realm" }
          end,
          GetActiveEntryInfo = function()
            return nil
          end,
          GetActivityFullName = function(_activityID)
            return nil
          end,
          GetActivityInfoTable = function(_activityID)
            return nil
          end,
        },
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local chatPayloads = {}
      local noticePayloads = {}
      addon.LFGDetect.SetTargetDungeonChatCallback(function(payload)
        chatPayloads[#chatPayloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        noticePayloads[#noticePayloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 605, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 605, "inviteaccepted")

      Assert.Equal(searchInfoCalls, 2, "inviteaccepted must re-read the accepted search result")
      Assert.Equal(addon.LFGDetect.GetActiveInviteTitleLevel(), 14, "fresh accept title level must become active")
      Assert.Equal(#chatPayloads, 1, "direct-push must fire once")
      Assert.Equal(chatPayloads[1].level, 14, "direct-push must use the refreshed title level")
      Assert.Equal(chatPayloads[1].groupName, "+14 Kompetitiv", "direct-push must use the refreshed group title")
      Assert.Equal(#noticePayloads, 1, "accepted notice must fire once")
      Assert.Equal(noticePayloads[1].level, 14, "accepted notice must use the refreshed title level")
      Assert.Equal(noticePayloads[1].groupName, "+14 Kompetitiv", "accepted notice must use the refreshed group title")
    end)
  end)

  test("LFGDetect direct-push respects the enabled gate", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [602] = { activityID = 514, name = "+14 chill", leaderName = "Leader-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetTargetDungeonChatCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetTargetDungeonChatEnabledFn(function()
        return false
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 602, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 602, "inviteaccepted")

      Assert.Equal(#payloads, 0, "callback must not fire when the enabled gate returns false")
    end)
  end)

  test("LFGDetect direct-push surfaces level=nil when the listing has no +N marker", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [603] = { activityID = 514, name = "casual run", leaderName = "Z-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetTargetDungeonChatCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetTargetDungeonChatEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 603, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 603, "inviteaccepted")

      Assert.Equal(#payloads, 1, "callback still fires even when titleLevel is nil")
      Assert.Nil(payloads[1].level, "missing +N in the listing title surfaces as nil")
      Assert.Nil(payloads[1].levelText, "free-form titles must not become renderable chat level text")
    end)
  end)

  test("LFGDetect direct-push carries exact Blizzard keystone level markup", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [603] = { activityID = 514, name = "|Kk584|k", leaderName = "Z-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetTargetDungeonChatCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetTargetDungeonChatEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 603, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 603, "inviteaccepted")

      Assert.Equal(#payloads, 1, "callback must fire for exact Blizzard keystone markup")
      Assert.Nil(payloads[1].level, "opaque Blizzard markup must not be parsed as a synthetic numeric level")
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteTitleLevelText(),
        "|Kk584|k",
        "exact Blizzard keystone markup must remain available after accept"
      )
      Assert.Equal(
        payloads[1].levelText,
        "|Kk584|k",
        "exact Blizzard keystone markup must be forwarded for chat-frame rendering"
      )
    end)
  end)

  test(
    "LFGDetect direct-push uses accepted listing before GROUP_ROSTER_UPDATE when IsInGroup is transient false",
    function()
      -- Reproduces the LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted
      -- race: Blizzard sends the accept event before the matching
      -- GROUP_ROSTER_UPDATE, so IsInGroup() can still return false in this
      -- window. The chat line must still use the same accepted-listing payload
      -- as the Center Notice; waiting for the later roster settle lets owner /
      -- sync status sources surface a different key level.
      local grouped = false
      local globals, fire = BuildLFGDetectEnv({
        IsInGroup = function()
          return grouped
        end,
        GetNumGroupMembers = function()
          return grouped and 5 or 0
        end,
        globals = {
          C_LFGList = BuildC_LFGList({
            [604] = { activityID = 514, name = "+13 quick", leaderName = "L-Realm" },
          }, nil),
        },
      })

      WithGlobals(globals, function()
        local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
        local payloads = {}
        addon.LFGDetect.SetTargetDungeonChatCallback(function(payload)
          payloads[#payloads + 1] = payload
        end)
        -- No SetTargetDungeonChatEnabledFn: matches the production wiring
        -- after the IsInGroup gate was removed.

        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 604, "invited")
        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 604, "inviteaccepted")

        Assert.Equal(#payloads, 1, "direct-push must fire from the accepted listing immediately")
        Assert.Equal(payloads[1].level, 13, "payload carries entry.titleLevel from the accepted listing")
        grouped = true
        fire("GROUP_ROSTER_UPDATE")
        Assert.Equal(#payloads, 1, "group settle must not replay the accepted-listing direct-push")
      end)
    end
  )

  test("LFGDetect ResolveEntryTitleLevel recovers level from groupName when titleLevel is nil", function()
    -- Pin the in-the-wild divergence: even when an entry lands at the
    -- consumers with titleLevel=nil (whatever post-resolve race produced
    -- that), as long as groupName still encodes "+N", the helper must
    -- recover the level. This is the contract that keeps Center Notice
    -- and chat line in sync with the Blizzard popup when the LFG title
    -- carries the level.
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local resolve = addon.LFGDetect.ResolveEntryTitleLevel

      Assert.Equal(
        resolve({ titleLevel = nil, groupName = "+13 Competitive" }),
        13,
        "nil titleLevel + parsable groupName must recover the level"
      )
      Assert.Equal(
        resolve({ titleLevel = 14, groupName = "+13" }),
        14,
        "stored titleLevel wins over groupName parse — no false downgrade"
      )
      Assert.Equal(
        resolve({ titleLevel = "12", groupName = "+13" }),
        12,
        "numeric-string titleLevel is honoured before falling back"
      )
      Assert.Nil(
        resolve({ titleLevel = nil, groupName = "Sitz des Triumvirats" }),
        "groupName without +N stays nil — no level invented"
      )
      Assert.Nil(resolve({ titleLevel = nil, groupName = "" }), "empty groupName stays nil")
      Assert.Nil(resolve({ titleLevel = nil }), "missing groupName stays nil")
      Assert.Nil(resolve(nil), "non-table input stays nil")
      Assert.Equal(
        resolve({ titleLevel = 0, groupName = "+13 fallback" }),
        13,
        "titleLevel=0 is treated as invalid and falls through to the groupName parse"
      )
      Assert.Equal(
        resolve({ titleLevel = nil, groupName = "+\194\16013 NBSP" }),
        13,
        "non-breaking space between + and digits still parses (extended parser pattern)"
      )
      Assert.Equal(resolve({ titleLevel = nil, groupName = "(+13) push" }), 13, "parenthesised + still parses")
      -- Vorfall 2026-05-15: Modern WoW (12.0+) replaces a leader-typed "+N"
      -- listing title with the opaque pipe-markup "|Kk<sessionID>|k" where
      -- <sessionID> is a client-side lookup index — NOT the level. The
      -- chat frame renders it client-side; raw string ops cannot derive
      -- the level. The parser must return nil for the encoded form (no
      -- false level), and the chat-line passes the raw markup through as
      -- rawTitle instead so the chat frame can render the user-visible
      -- "+12 Entspannt" text.
      local blizzardMarkup = string.char(124, 75, 107, 53, 56, 52, 124, 107) -- |Kk584|k
      Assert.Nil(
        resolve({ titleLevel = nil, groupName = blizzardMarkup }),
        "Blizzard pipe-markup |Kk584|k must NOT be parsed as a level — the digit is an opaque lookup ID"
      )
      Assert.Equal(
        resolve({ titleLevel = nil, groupName = "+12 |Kk999|k" }),
        12,
        "mixed plain '+N' + markup still picks the plain-text level (markup is ignored)"
      )
    end)
  end)

  test("LFGDetect PARTY_LEADER_CHANGED is a no-op when no listing identity was captured", function()
    -- Pre-formed-group case: never went through an LFG accept, so the
    -- accepted-invite identity slots are nil to begin with. The event must
    -- not raise and must not produce spurious clear-state log entries.
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({}, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      local ok, err = pcall(function()
        fire("PARTY_LEADER_CHANGED")
      end)
      Assert.True(ok, "PARTY_LEADER_CHANGED without prior accept must not raise: " .. tostring(err))
      Assert.Nil(addon.LFGDetect.GetActiveInviteLeader(), "still nil after the no-op")
    end)
  end)

  test("LFGDetect.OnInvited keeps pre-accept invite hint removed", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [42] = { activityID = 514, name = "+14 KR", leaderName = "Pusher-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local hintCalls = 0
      addon.LFGDetect.SetInviteHintCallback(function()
        hintCalls = hintCalls + 1
      end)
      addon.LFGDetect.SetInviteHintEnabledFn(function()
        return true
      end)
      addon.LFGDetect.SetInviteHintLocaleFn(function()
        return { INVITE_HINT_GROUP = "Group: %s", INVITE_HINT_UNKNOWN_DUNGEON = "Unknown" }
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 42, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 42, "inviteaccepted")
      Assert.Equal(hintCalls, 0, "removed pre-accept invite hint must not render on invited")
      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "removed invite hint must not break pending invite resolution for accepted notices"
      )
    end)
  end)
end

local function RegisterLFGDetectResetTests(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  -- ---------------------------------------------------------------------------
  -- ClearAllState paths
  -- ---------------------------------------------------------------------------

  -- ClearAllState resets every neighbouring identity field; the suppressed
  -- bucket used to be the one exception, so decline state survived group-leave
  -- and grew for the whole session. Search result IDs come from the LFG system
  -- and can be reused, so a leftover flag could silence a later, unrelated
  -- accept that arrives without a preceding "invited" event.
  test("LFGDetect ClearAllState drops suppressed invite accepts", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [4021160] = { activityID = 504, name = "+17 Sethraliss", leaderName = "SethraLead" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      -- Decline parks the ID in the suppressed bucket.
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 4021160, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 4021160, "declined")

      addon.LFGDetect.ClearAllState()

      -- Same ID reused for a later listing, accepted without a fresh "invited"
      -- event. With the suppression flag still set this resolved to nothing.
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 4021160, "inviteaccepted")
      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        250,
        "a reused search result ID must resolve again after ClearAllState"
      )
    end)
  end)

  test(
    "LFGDetect GROUP_ROSTER_UPDATE not in group clears pending invites but allows late accept to re-resolve",
    function()
      -- Behavior change (BUG-RAID-LEAVE-M+-INVITE): ClearAllStateImpl no longer
      -- promotes pending invites into the suppressed bucket. A late
      -- inviteaccepted that arrives after group-leave must therefore re-resolve
      -- via ResolveInviteEntry (which calls back into C_LFGList) and surface
      -- detectedMapID. This is the desired path: when the user holds two
      -- parallel LFG applications, the group-leave from group A must not
      -- silently kill the legitimate accept of group B.
      local callbackCount = 0

      local globals, fire = BuildLFGDetectEnv({
        IsInGroup = function()
          return false
        end,
        globals = {
          C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
        },
      })

      WithGlobals(globals, function()
        local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
        addon.LFGDetect.SetHighlightCallback(function()
          callbackCount = callbackCount + 1
        end)

        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
        -- Leave group before accepting — ClearAllStateImpl runs.
        fire("GROUP_ROSTER_UPDATE")

        -- pendingInvites is wiped, but the late inviteaccepted still resolves
        -- via the API fallback (the suppressed bucket no longer blocks it).
        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

        Assert.Equal(
          addon.LFGDetect.GetDetectedMapID(),
          249,
          "late inviteaccepted after a group-leave reset must re-resolve via the API fallback"
        )
      end)
    end
  )

  test("LFGDetect CHALLENGE_MODE_START keeps confirmed invite highlight until explicit clear", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "setup: detectedMapID must be set before key start")

      fire("CHALLENGE_MODE_START")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "CHALLENGE_MODE_START must not clear the confirmed invite highlight"
      )

      addon.LFGDetect.ClearAllState()

      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "explicit clear must still reset the confirmed invite highlight")
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- GROUP_ROSTER_UPDATE fallback path
  -- ---------------------------------------------------------------------------

  test("LFGDetect GROUP_ROSTER_UPDATE applies pendingInvites when detectedMapID is unset", function()
    -- Race: GROUP_ROSTER_UPDATE fires before inviteaccepted. The handler must apply
    -- pendingInvites immediately so detectedMapID is set without waiting for the event.
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      -- GROUP_ROSTER_UPDATE fires before inviteaccepted (race condition path)
      fire("GROUP_ROSTER_UPDATE")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "GROUP_ROSTER_UPDATE fallback must apply pendingInvites when detectedMapID is unset"
      )
    end)
  end)

  test("LFGDetect GROUP_ROSTER_UPDATE preserves pending invite title level", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityID = 514, name = "+13 vault", leaderName = "Leader-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("GROUP_ROSTER_UPDATE")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "GROUP_ROSTER_UPDATE fallback must apply pending invite map"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        13,
        "GROUP_ROSTER_UPDATE fallback must preserve the LFG title level"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "Leader-Realm",
        "GROUP_ROSTER_UPDATE fallback must preserve the LFG leader hint"
      )
    end)
  end)

  test("LFGDetect GROUP_ROSTER_UPDATE recovery fires target-dungeon-chat callback once", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityID = 514, name = "+13 vault", leaderName = "Leader-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetTargetDungeonChatCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetTargetDungeonChatEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("GROUP_ROSTER_UPDATE")

      Assert.Equal(#payloads, 1, "GROUP_ROSTER_UPDATE recovery must fire the chat direct-push once")
      Assert.Equal(payloads[1].mapID, 249, "chat payload must carry the recovered invite map")
      Assert.Equal(payloads[1].level, 13, "chat payload must carry the recovered invite title level")
      Assert.Equal(payloads[1].leaderName, "Leader-Realm", "chat payload must carry the recovered leader hint")
      Assert.Equal(payloads[1].searchResultID, 1, "chat payload must carry the recovered searchResultID")

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Equal(#payloads, 1, "late inviteaccepted must not duplicate the recovered chat direct-push")
    end)
  end)

  test("LFGDetect inviteaccepted preserves title level when own listing already set the same map", function()
    local currentActiveEntry = { activityID = 514 }
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return false
      end,
      globals = {
        C_LFGList = {
          GetSearchResultInfo = function(id)
            if id == 1 then
              return { activityID = 514, name = "+13 vault", leaderName = "Leader-Realm" }
            end
            return nil
          end,
          GetActiveEntryInfo = function()
            return currentActiveEntry
          end,
          GetActivityInfoTable = function()
            return nil
          end,
        },
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local callbackCount = 0
      local lastSoundContext = nil
      addon.LFGDetect.SetHighlightCallback(function(soundContext)
        callbackCount = callbackCount + 1
        lastSoundContext = soundContext
      end)

      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "own listing must set detectedMapID first")

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "same-map invite must keep the detected map")
      Assert.Equal(callbackCount, 2, "same-map inviteaccepted must refresh consumers after capturing invite metadata")
      Assert.Equal(lastSoundContext, "invite", "same-map inviteaccepted refresh must use invite sound context")
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        13,
        "same-map inviteaccepted must still capture the LFG title level"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "Leader-Realm",
        "same-map inviteaccepted must still capture the LFG leader hint"
      )

      currentActiveEntry = nil
      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "same-map inviteaccepted must protect the target when the listing drops before group settle"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        13,
        "same-map inviteaccepted must keep the title level across the pre-settle listing drop"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "Leader-Realm",
        "same-map inviteaccepted must keep the leader hint across the pre-settle listing drop"
      )
    end)
  end)

  test("LFGDetect inviteaccepted resolves search result when invited event was missed", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityID = 514, name = "Nexuspunkt Xenas +10", leaderName = "Leader-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "inviteaccepted must resolve mapID directly from search result"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteTitleLevel(),
        10,
        "inviteaccepted must parse the key level directly from the LFG title"
      )
      Assert.Equal(
        addon.LFGDetect.GetActiveInviteLeader(),
        "Leader-Realm",
        "inviteaccepted must capture the LFG leader directly from the search result"
      )
    end)
  end)

  test("LFGDetect CheckActiveGroup keeps detectedMapID while grouped even when no active listing exists", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      GetNumGroupMembers = function()
        return 5
      end,
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "setup: detectedMapID must be set before settle")

      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")

      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "grouped no-listing checks must keep detectedMapID until dungeon entry or group leave"
      )
    end)
  end)

  test("LFGDetect GROUP_ROSTER_UPDATE emits diagnostic snapshot for group-settle highlight debugging", function()
    local snapshots = {}

    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      GetNumGroupMembers = function()
        return 5
      end,
      globals = {
        C_LFGList = BuildC_LFGList({ [1] = { activityID = 514 } }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      addon.LFGDetect.SetGroupRosterTraceLogger(function(snapshot)
        table.insert(snapshots, snapshot)
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")
      fire("GROUP_ROSTER_UPDATE")

      Assert.Equal(#snapshots, 1, "group roster update must emit one diagnostic snapshot")
      Assert.Equal(snapshots[1].event, "GROUP_ROSTER_UPDATE", "diagnostic snapshot must record the source event")
      Assert.Equal(snapshots[1].members, 5, "diagnostic snapshot must record the settled group size")
      Assert.Equal(snapshots[1].detectedBefore, 249, "diagnostic snapshot must capture detectedMapID before settle")
      Assert.Equal(snapshots[1].detectedAfter, 249, "diagnostic snapshot must keep detectedMapID after settle")
      Assert.Nil(snapshots[1].pendingAccept, "diagnostic snapshot must reflect the cleared pending accept")
    end)
  end)

  test("LFGDetect runtime trace logger passes a lazy builder to runtime logging", function()
    local capturedBuilder = nil

    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({}, { activityID = 514 }),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      addon.LFGDetect.SetTraceLogger(function(builder)
        capturedBuilder = capturedBuilder or builder
      end)

      fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")

      capturedBuilder = Assert.NotNil(capturedBuilder, "LFG trace logger must receive a lazy message builder")
      Assert.Equal(type(capturedBuilder), "function", "LFG trace logger must receive a lazy message builder")
      Assert.True(
        (capturedBuilder() or ""):find("%[LFG%] queue_listing_detected mapID=249 lastQueueMapID=nil") ~= nil,
        "LFG trace builder must format on demand"
      )
    end)
  end)
end

local function RegisterLFGDetectInviteHintTests(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  test("LFGDetect.OnInvited ignores removed pre-accept invite hint callbacks", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [1] = { activityID = 514, name = "+12 NW Push, no jail", leaderName = "Tankadin-Realm" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local hintCalls = 0
      addon.LFGDetect.SetInviteHintCallback(function()
        hintCalls = hintCalls + 1
      end)
      addon.LFGDetect.SetInviteHintEnabledFn(function()
        return true
      end)
      addon.LFGDetect.SetInviteHintLocaleFn(function()
        return {}
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "inviteaccepted")
      Assert.Equal(hintCalls, 0, "removed pre-accept invite hint callback must never be invoked")
      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "removed hint path must leave the accepted-invite target chain intact"
      )
    end)
  end)
end

-- Branch coverage for ParseTitleKeyLevel pattern-B ("N+" trailing-plus form),
-- the Log/LogDeep helpers when a logger is wired, MapIDFromActivityIDs cache
-- population, and ResolveInviteEntry early returns.
local function RegisterLFGDetectBranchCoverageTests(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  test("LFGDetect ParseTitleKeyLevel resolves 'N+' trailing-plus form via OnInvited title", function()
    -- activityID 514 → mapID 249 (King's Rest) is statically mapped, so
    -- the invite resolves and the title level is promoted on inviteaccepted.
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [42] = {
            -- Pattern A "+N" intentionally absent; only trailing-plus form.
            activityID = 514,
            name = "12+ KR gogo",
            leaderName = "Pusher-Realm",
          },
        }, nil),
      },
    })
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 42, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 42, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetActiveInviteTitleLevel(), 12, "pattern B '12+' must resolve to 12")
    end)
  end)

  test("LFGDetect ParseTitleKeyLevel rejects out-of-range numbers (>40)", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [43] = { activityID = 514, name = "+99 farm", leaderName = "X" },
        }, nil),
      },
    })
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 43, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 43, "inviteaccepted")
      Assert.Nil(addon.LFGDetect.GetActiveInviteTitleLevel(), "+99 must be rejected as out of [1,40]")
    end)
  end)

  test("LFGDetect ParseTitleKeyLevel picks the highest level when multiple +N tags appear", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [44] = { activityID = 514, name = "+10/+12/+14 KR", leaderName = "Push" },
        }, nil),
      },
    })
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 44, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 44, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetActiveInviteTitleLevel(), 14, "must select the highest +N tag")
    end)
  end)

  test("LFGDetect Log helpers route through wired logger and trace-logger callbacks", function()
    local logCalls = {}
    local traceCalls = {}
    local deepTraceCalls = {}
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return false
      end,
    })
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      addon.LFGDetect.SetLogger(function(msg)
        table.insert(logCalls, msg)
      end)
      addon.LFGDetect.SetTraceLogger(function(msg)
        table.insert(traceCalls, msg)
      end)
      addon.LFGDetect.SetDeepTraceLogger(function(msg)
        table.insert(deepTraceCalls, msg)
      end)

      -- Drive any event that flows through Log; GROUP_ROSTER_UPDATE always fires.
      fire("GROUP_ROSTER_UPDATE")
    end)
    Assert.True(#logCalls + #traceCalls + #deepTraceCalls > 0, "at least one logger callback must receive a line")
  end)

  test("LFGDetect MapIDFromActivityIDs caches the resolved mapID for repeat lookups", function()
    local activityCalls = 0
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = {
        C_LFGList = {
          GetSearchResultInfo = function(id)
            if id == 50 then
              return {
                activityID = nil, -- not directly resolvable
                activityIDs = { 9001 },
                name = "+15 SH",
                leaderName = "Lead",
              }
            end
            return nil
          end,
          GetActiveEntryInfo = function()
            return nil
          end,
          GetActivityFullName = function()
            return nil
          end,
          GetActivityInfoTable = function(activityID)
            activityCalls = activityCalls + 1
            if activityID == 9001 then
              return { mapID = 2773, isMythicPlusActivity = true }
            end
            return nil
          end,
        },
      },
    })
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 50, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 50, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 2773, "first lookup must populate cache and resolve")
      local callsAfterFirst = activityCalls
      -- Trigger a second resolve-path entry: clear and re-invite.
      addon.LFGDetect.ClearAllState()
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 50, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 50, "inviteaccepted")
      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 2773, "cached lookup must still resolve")
      Assert.Equal(activityCalls, callsAfterFirst, "GetActivityInfoTable must NOT be called again (cache hit)")
    end)
  end)

  test("LFGDetect ResolveInviteEntry returns nil when C_LFGList global is absent", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = { C_LFGList = false }, -- explicit nil-out
    })
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 99, "invited")
      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "no C_LFGList → invite cannot resolve")
    end)
  end)
end

-- Tests for the post-accept Center Notice trigger. The notice is rendered
-- exclusively from the pendingInvites entry of the accepted searchResultID:
-- sibling listings (other searchResultIDs) must not influence the payload,
-- and missing data (no "+N" in title) must surface as nil rather than be
-- inferred from roster/sync state.
local function RegisterLFGDetectAcceptedInviteNoticeTests(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  -- Test A: multiple pendingInvites for the SAME dungeon at different levels.
  -- Accepting the higher-level listing must not let the lower-level sibling
  -- bleed into the notice payload.
  test("AcceptedInviteNotice picks the level of the accepted listing among same-dungeon parallel invites", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [101] = { activityID = 514, name = "+12 spire chill", leaderName = "Tank-A" },
          [102] = { activityID = 514, name = "+15 spire push", leaderName = "Tank-B" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 101, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 102, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 102, "inviteaccepted")

      Assert.Equal(#payloads, 1, "AcceptedInviteNotice must fire exactly once on inviteaccepted")
      Assert.Equal(payloads[1].level, 15, "level must be the +15 of the accepted listing, not the +12 sibling")
      Assert.Equal(payloads[1].mapID, 249, "mapID must resolve from accepted listing")
      Assert.Equal(payloads[1].activityID, 514, "activityID must propagate for teleport-button wiring")
      Assert.Equal(payloads[1].searchResultID, 102, "searchResultID must be the accepted one")
      Assert.Equal(payloads[1].leaderName, "Tank-B", "leaderName must be from accepted listing")
    end)
  end)

  -- Test B: parallel invites for DIFFERENT dungeons. Accepting one must
  -- surface its mapID and level; the unaccepted sibling must not contribute.
  test(
    "AcceptedInviteNotice surfaces the dungeon of the accepted listing among different-dungeon parallel invites",
    function()
      local globals, fire = BuildLFGDetectEnv({
        globals = {
          C_LFGList = BuildC_LFGList({
            [201] = { activityID = 514, name = "+13 spire", leaderName = "S" }, -- mapID 249
            [202] = { activityID = 1950, name = "+10 row", leaderName = "K" }, -- mapID 587
          }, nil),
        },
      })

      WithGlobals(globals, function()
        local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
        local payloads = {}
        addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
          payloads[#payloads + 1] = payload
        end)
        addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
          return true
        end)

        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 201, "invited")
        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 202, "invited")
        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 202, "inviteaccepted")

        Assert.Equal(#payloads, 1, "exactly one notice on accept")
        Assert.Equal(payloads[1].mapID, 587, "mapID must be from the Murder Row listing the player accepted")
        Assert.Equal(payloads[1].level, 10, "level must be Murder Row's +10, not the other listing's +13")
        Assert.Equal(payloads[1].activityID, 1950, "activityID must be Murder Row's, for the teleport button")
      end)
    end
  )

  -- Test C: a sibling listing is delisted/declined AFTER the accept fires.
  -- The notice must not re-fire and must not have its content mutated.
  test("AcceptedInviteNotice ignores sibling-listing declines after the accept fired", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [301] = { activityID = 514, name = "+12 spire", leaderName = "A" },
          [302] = { activityID = 514, name = "+14 spire", leaderName = "B" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 301, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 302, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 302, "inviteaccepted")
      -- Sibling listing 301 gets delisted after our accept landed.
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 301, "declined_delisted")

      Assert.Equal(#payloads, 1, "decline of a sibling listing must not re-trigger the notice")
      Assert.Equal(payloads[1].level, 14, "accepted listing's level must remain unchanged after sibling decline")
    end)
  end)

  -- Test D: group title without "+N" suffix. The notice must surface
  -- level=nil rather than guess from defaults or sibling data.
  test("AcceptedInviteNotice surfaces level=nil when the group title has no '+N' marker", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [401] = { activityID = 514, name = "chill spire run", leaderName = "Z" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 401, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 401, "inviteaccepted")

      Assert.Equal(#payloads, 1, "notice must still fire even without a level")
      Assert.Nil(payloads[1].level, "level must stay nil rather than be inferred")
      Assert.Equal(payloads[1].mapID, 249, "mapID must still resolve")
      Assert.Equal(payloads[1].groupName, "chill spire run", "raw group title must propagate for the subline")
    end)
  end)

  -- Test D2: listing comment ("Beschreibung" row in the notice) propagates
  -- through the payload when present, and stays nil when absent — never
  -- defaulted to a placeholder string.
  test("AcceptedInviteNotice forwards info.comment as payload.comment when present", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [250] = {
            activityID = 514,
            name = "+13 spire push",
            leaderName = "C",
            comment = "Achiever 2.5k io, no afks",
          },
          [403] = { activityID = 514, name = "+10 chill", leaderName = "D" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 250, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 250, "inviteaccepted")
      Assert.Equal(payloads[1].comment, "Achiever 2.5k io, no afks", "comment must propagate from info.comment")

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 403, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 403, "inviteaccepted")
      Assert.Nil(payloads[2].comment, "missing info.comment must surface as nil, never a placeholder")
    end)
  end)

  -- Test E: when the toggle is off, the callback must not be invoked.
  test("AcceptedInviteNotice stays silent when the enabled-fn returns false", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [501] = { activityID = 514, name = "+11 spire", leaderName = "X" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return false
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 501, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 501, "inviteaccepted")

      Assert.Equal(#payloads, 0, "disabled toggle must suppress the notice callback entirely")
    end)
  end)

  -- Test F: when only the enabled-fn is wired (no callback), MaybeShow must
  -- early-return without crashing — i.e. callback wiring is independent of
  -- enabled-fn wiring.
  test("AcceptedInviteNotice early-returns cleanly when callback is unwired", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [601] = { activityID = 514, name = "+9", leaderName = "Q" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)
      -- No callback set.
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 601, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 601, "inviteaccepted")
      Assert.Equal(
        addon.LFGDetect.GetDetectedMapID(),
        249,
        "missing notice callback must not break the existing pipeline"
      )
    end)
  end)

  -- Test F2 (BUG-DUPLICATE-FIRE): Blizzard has historically replayed
  -- LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted for the same
  -- searchResultID. The Status controller dedupes the chat path via its
  -- lock-in; this regression pins the notice-side dedup added in the same
  -- audit. A legitimate next-cycle accept (after ClearAllState) for the
  -- same listing must still render.
  test("AcceptedInviteNotice dedupes duplicate inviteaccepted for the same searchResultID", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [701] = { activityID = 514, name = "+13 spire", leaderName = "Tank" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 701, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 701, "inviteaccepted")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 701, "inviteaccepted") -- Blizzard replay
      Assert.Equal(#payloads, 1, "duplicate inviteaccepted for same searchResultID must render once")

      -- After a group-leave reset, the SAME searchResultID must render again
      -- (a legitimate next cycle, not a replay).
      addon.LFGDetect.ClearAllState()
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 701, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 701, "inviteaccepted")
      Assert.Equal(#payloads, 2, "after ClearAllState the same searchResultID renders again")
    end)
  end)

  test("AcceptedInviteNotice does not replay after challenge start", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = BuildC_LFGList({
          [702] = { activityID = 514, name = "+13 spire", leaderName = "Tank" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 702, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 702, "inviteaccepted")
      fire("CHALLENGE_MODE_START")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 702, "inviteaccepted")

      Assert.Equal(#payloads, 1, "key-start must close the accepted-invite notice window")
      Assert.Equal(addon.LFGDetect.GetDetectedMapID(), 249, "key-start must not clear the detected invite map")
    end)
  end)

  test("AcceptedInviteNotice does not replay via GROUP_ROSTER_UPDATE recovery after ClearAllState", function()
    -- The closing line of the key-start sequence is ClearAllState (driven
    -- by CheckIfEnteredTargetDungeon once currentMapID == targetMapID).
    -- It wipes pendingInvites, lastShownNoticeSearchResultID AND the
    -- acceptedInviteNoticeBlockedUntilReset flag. If a late
    -- GROUP_ROSTER_UPDATE re-enters the recovery branch, the live LFG
    -- API can still hand back a "stale" inviteaccepted searchResultID
    -- and ResolveInviteEntry would rebuild the entry from scratch. The
    -- recovery branch must therefore refuse to fall back to the API
    -- without at least one cached pendingInvites table entry to anchor
    -- the resolution; otherwise the Center Notice would re-render for
    -- an accept cycle that was already consumed.
    local lfgList = BuildC_LFGList({
      [802] = { activityID = 514, name = "+13 spire", leaderName = "Tank" },
    }, nil)
    -- Live-API stub: the application is still reported as
    -- "inviteaccepted" for resultID 802 even after the local accept
    -- cycle was consumed (this is what FindAcceptedSearchResultID can
    -- legitimately hit in production for a short window).
    lfgList.GetApplications = function()
      return { 1001 }
    end
    lfgList.GetApplicationInfo = function(applicationID)
      if applicationID == 1001 then
        return 802, "inviteaccepted"
      end
      return nil
    end

    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return true
      end,
      globals = { C_LFGList = lfgList },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 802, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 802, "inviteaccepted")
      Assert.Equal(#payloads, 1, "setup: invite accepted emits the notice exactly once")

      -- Simulate CheckIfEnteredTargetDungeon's terminal step: a full reset
      -- including pendingInvites and the new acceptedInviteNoticeBlocked
      -- flag. After this, only the live API still remembers the listing.
      addon.LFGDetect.ClearAllState()
      Assert.Nil(
        addon.LFGDetect.GetDetectedMapID(),
        "setup: full reset clears the accepted-invite state, including pendingInvites and the notice blocker"
      )

      -- Late GROUP_ROSTER_UPDATE (sub-zone settle / roster refresh after
      -- entering the dungeon). The live LFG stub still reports 802 as the
      -- accepted searchResultID; without the new guard the recovery
      -- branch would rebuild the entry via ResolveInviteEntry and fire
      -- the notice a second time.
      fire("GROUP_ROSTER_UPDATE")

      Assert.Equal(
        #payloads,
        1,
        "post-reset GROUP_ROSTER_UPDATE recovery must not rebuild a notice from the live API alone"
      )
      Assert.Nil(
        addon.LFGDetect.GetDetectedMapID(),
        "post-reset recovery must not silently rehydrate detectedMapID either"
      )
    end)
  end)

  -- Test G (BUG-RAID): an LFG activityID that is NOT a Mythic+ activity
  -- (Raid, PvP, Scenario, ...) must not flow through MapIDFromActivityID's
  -- API fallback, so the invite never lands in pendingInvites and the
  -- post-accept notice / chat announce / teleport highlight never fire for
  -- non-M+ content.
  test("AcceptedInviteNotice ignores Raid LFG invites (isMythicPlusActivity=false)", function()
    -- activityID 9999 is intentionally outside the static ACTIVITY_TO_MAP so
    -- the API fallback is exercised. The mock GetActivityInfoTable returns a
    -- valid mapID + isMythicPlusActivity=false (Raid LFG case).
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = {
          GetSearchResultInfo = function(id)
            if id == 701 then
              return { activityID = 9999, name = "+0 Vault Raid", leaderName = "RaidLead" }
            end
          end,
          GetActiveEntryInfo = function()
            return nil
          end,
          GetActivityFullName = function()
            return nil
          end,
          GetActivityInfoTable = function(activityID)
            if activityID == 9999 then
              return { mapID = 2657, isMythicPlusActivity = false }
            end
          end,
        },
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 701, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 701, "inviteaccepted")

      Assert.Equal(#payloads, 0, "Raid LFG invite must not trigger the M+ notice")
      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "Raid mapID must not be promoted into detectedMapID")
    end)
  end)

  -- Raid invites stay silent. The separate Raid resolver only consumes the
  -- accepted listing so the M+ pipeline (detectedMapID / activeInviteLeader /
  -- activeInviteTitleLevel / TriggerHighlightUpdate / chat announce) stays
  -- untouched. Legacy Raid-notice callbacks remain no-op compatibility hooks.

  test("AcceptedRaidInviteNotice stays silent for a Raid LFG listing with categoryID=3", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = {
          GetSearchResultInfo = function(id)
            if id == 801 then
              return {
                activityID = 9999,
                name = "AOTC Manaforge",
                leaderName = "RaidLead",
                comment = "exp only",
              }
            end
          end,
          GetActiveEntryInfo = function()
            return nil
          end,
          GetActivityFullName = function()
            return nil
          end,
          GetActivityInfoTable = function(activityID)
            if activityID == 9999 then
              return { mapID = 2657, isMythicPlusActivity = false, categoryID = 3 }
            end
          end,
        },
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local mplusPayloads = {}
      local raidPayloads = {}
      local highlightCalls = 0
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        mplusPayloads[#mplusPayloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)
      addon.LFGDetect.SetAcceptedRaidInviteNoticeCallback(function(payload)
        raidPayloads[#raidPayloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedRaidInviteNoticeEnabledFn(function()
        return true
      end)
      addon.LFGDetect.SetHighlightCallback(function()
        highlightCalls = highlightCalls + 1
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 801, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 801, "inviteaccepted")

      Assert.Equal(#mplusPayloads, 0, "Raid invite must not trigger the M+ accepted-invite callback")
      Assert.Equal(#raidPayloads, 0, "Raid invite must not trigger the removed Raid accepted-invite callback")

      -- The whole point of the separate pipeline: the M+ state must stay clean.
      Assert.Nil(addon.LFGDetect.GetDetectedMapID(), "Raid accept must NOT set detectedMapID")
      Assert.Nil(addon.LFGDetect.GetActiveInviteLeader(), "Raid accept must NOT set activeInviteLeader")
      Assert.Nil(addon.LFGDetect.GetActiveInviteTitleLevel(), "Raid accept must NOT set activeInviteTitleLevel")
      Assert.Equal(highlightCalls, 0, "Raid accept must NOT trigger the highlight callback")
    end)
  end)

  test("AcceptedRaidInviteNotice ignores non-Raid categories even when isMythicPlusActivity is false", function()
    -- categoryID 4 (PvP), 6 (Scenarios) etc must fall through both pipelines.
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = {
          GetSearchResultInfo = function(id)
            if id == 802 then
              return { activityID = 9998, name = "PvP brawl", leaderName = "PvPLead" }
            end
          end,
          GetActiveEntryInfo = function()
            return nil
          end,
          GetActivityFullName = function()
            return nil
          end,
          GetActivityInfoTable = function(activityID)
            if activityID == 9998 then
              -- PvP-style activity: non-M+ AND non-Raid (categoryID 4).
              return { mapID = 1234, isMythicPlusActivity = false, categoryID = 4 }
            end
          end,
        },
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local mplusPayloads = {}
      local raidPayloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        mplusPayloads[#mplusPayloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)
      addon.LFGDetect.SetAcceptedRaidInviteNoticeCallback(function(payload)
        raidPayloads[#raidPayloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedRaidInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 802, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 802, "inviteaccepted")

      Assert.Equal(#mplusPayloads, 0, "non-M+/non-Raid invite must not trigger the M+ notice")
      Assert.Equal(#raidPayloads, 0, "non-Raid category must not trigger the Raid notice")
    end)
  end)

  test("AcceptedRaidInviteNotice remains silent even when the legacy enabled gate returns true", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = {
          GetSearchResultInfo = function(id)
            if id == 803 then
              return { activityID = 9997, name = "Heroic Manaforge", leaderName = "HRaidLead" }
            end
          end,
          GetActiveEntryInfo = function()
            return nil
          end,
          GetActivityFullName = function()
            return nil
          end,
          GetActivityInfoTable = function(activityID)
            if activityID == 9997 then
              return { mapID = 2657, isMythicPlusActivity = false, categoryID = 3 }
            end
          end,
        },
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local raidPayloads = {}
      addon.LFGDetect.SetAcceptedRaidInviteNoticeCallback(function(payload)
        raidPayloads[#raidPayloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedRaidInviteNoticeEnabledFn(function()
        return true
      end)

      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 803, "invited")
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 803, "inviteaccepted")

      Assert.Equal(#raidPayloads, 0, "removed Raid notice must stay silent even when legacy gate returns true")
    end)
  end)

  test("AcceptedRaidInviteNotice stays silent when the callback was never registered", function()
    local globals, fire = BuildLFGDetectEnv({
      globals = {
        C_LFGList = {
          GetSearchResultInfo = function(id)
            if id == 804 then
              return { activityID = 9996, name = "LFR run", leaderName = "LFRLead" }
            end
          end,
          GetActiveEntryInfo = function()
            return nil
          end,
          GetActivityFullName = function()
            return nil
          end,
          GetActivityInfoTable = function(activityID)
            if activityID == 9996 then
              return { mapID = 2657, isMythicPlusActivity = false, categoryID = 3 }
            end
          end,
        },
      },
    })

    WithGlobals(globals, function()
      LoadAddonModules({ "isiLive_lfg_detect.lua" })
      -- Intentionally do NOT call SetAcceptedRaidInviteNoticeCallback.
      -- Must not raise even though the resolver finds a valid Raid entry.
      local ok, err = pcall(function()
        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 804, "invited")
        fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 804, "inviteaccepted")
      end)
      Assert.True(ok, "unregistered Raid callback must not raise: " .. tostring(err))
    end)
  end)

  -- Test H (BUG-RAID-LEAVE-M+): real-world sequence — Raid invite accepted,
  -- joined, then left; a parallel M+ application gets its invite afterwards.
  -- Previously ClearAllStateImpl on raid-leave swept all pendingInvites into
  -- the suppressed bucket, blocking the next ResolveInviteEntry fallback and
  -- silently killing the M+ accept path.
  test("AcceptedInviteNotice fires after a ClearAllState reset between two invites", function()
    local globals, fire = BuildLFGDetectEnv({
      IsInGroup = function()
        return false
      end,
      IsInRaid = function()
        return false
      end,
      GetNumGroupMembers = function()
        return 0
      end,
      globals = {
        C_LFGList = BuildC_LFGList({
          [801] = { activityID = 514, name = "+12 spire", leaderName = "M+Lead" },
        }, nil),
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_detect.lua" })
      local payloads = {}
      addon.LFGDetect.SetAcceptedInviteNoticeCallback(function(payload)
        payloads[#payloads + 1] = payload
      end)
      addon.LFGDetect.SetAcceptedInviteNoticeEnabledFn(function()
        return true
      end)

      -- Pre-state: a pending invite exists when the user leaves the previous
      -- group. Simulate the OnInvited that populated pendingInvites[801]
      -- before the group-leave; then the leave triggers ClearAllStateImpl
      -- via GROUP_ROSTER_UPDATE with no members.
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 801, "invited")
      fire("GROUP_ROSTER_UPDATE")

      -- Now the actual M+ inviteaccepted lands. Must still resolve via the
      -- ResolveInviteEntry fallback (suppressed bucket must not block it).
      fire("LFG_LIST_APPLICATION_STATUS_UPDATED", 801, "inviteaccepted")

      Assert.Equal(#payloads, 1, "M+ accept after ClearAllState must still fire the notice")
      Assert.Equal(payloads[1].mapID, 249, "mapID must resolve via ResolveInviteEntry after the reset")
      Assert.Equal(payloads[1].level, 12, "title level must be parsed from the LFG group name")
    end)
  end)
end

return function(test, ctx)
  RegisterLFGDetectResolutionTests(test, ctx)
  RegisterLFGDetectInviteAcceptRaceTests(test, ctx)
  RegisterLFGDetectQueueStateTests(test, ctx)
  RegisterLFGDetectResetTests(test, ctx)
  RegisterLFGDetectInviteHintTests(test, ctx)
  RegisterLFGDetectAcceptedInviteNoticeTests(test, ctx)
  RegisterLFGDetectBranchCoverageTests(test, ctx)
end
