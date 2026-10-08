---@diagnostic disable: undefined-global
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

return function(test, ctx, fixtures)
  local Assert = ctx.assert

  test("Mplus stress: 20000 cooldown events coalesce without full roster renders", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local beforeAfter, beforeHarmful = session.afterCalls, session.harmfulReads
      Stress.Measure("key cooldown burst", 20000, function()
        for _ = 1, 10000 do
          session.Dispatch("SPELL_UPDATE_COOLDOWN")
          session.Dispatch("SPELL_UPDATE_CHARGES")
        end
      end)
      Assert.Equal(session.afterCalls - beforeAfter, 2, "each cooldown bucket must schedule only one trailing callback")
      Assert.Equal(session.harmfulReads, beforeHarmful, "coalesced events must not scan synchronously")
      session.Advance(0.1)
      Assert.True(session.harmfulReads > beforeHarmful, "the trailing charge callback must read live CD data")
      Assert.True(
        session.harmfulReads - beforeHarmful <= 80,
        "one charge callback must not amplify into repeated scans"
      )
      Assert.Equal(session.fullRenders, 0, "cooldown bursts must refresh only their relevant rows")
      Assert.True(session.addon.MplusTimer.GetTimerData().running, "cooldown traffic must not stop the key")
    end)
  end)

  test("Mplus stress: 30000 irrelevant combat events avoid CD scans and announces", function()
    Stress.WithKey(ctx, fixtures, function(session)
      session.combat = true
      session.Dispatch("PLAYER_REGEN_DISABLED")
      local beforeHarmful, beforeMessages = session.harmfulReads, #session.messages
      local payload = { addedAuras = { { spellId = 133 } } }
      Stress.Measure("key combat burst", 30000, function()
        for _ = 1, 10000 do
          session.Dispatch("UNIT_AURA", "player", payload)
          session.Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "test-cast", 133)
          session.Dispatch("UNIT_HEALTH", "nameplate1")
        end
      end)
      Assert.Equal(session.harmfulReads, beforeHarmful, "irrelevant aura additions must not scan Sated slots")
      Assert.Equal(#session.messages, beforeMessages, "irrelevant casts must not generate addon announces")
      Assert.Equal(session.fullRenders, 0, "combat noise must not rebuild the roster")
      Assert.True(session.addon.MplusTimer.GetTimerData().running, "the running key must survive the burst")
    end)
  end)

  test("Mplus stress: 1000 hidden player aura updates coalesce into one CD pass", function()
    Stress.WithKey(ctx, fixtures, function(session)
      session.runtime.mainFrame:Hide()
      session.Advance(1)
      session.combat = true
      session.Dispatch("PLAYER_REGEN_DISABLED")
      local beforeHarmful, beforeRenders, beforeAfter = session.harmfulReads, session.fullRenders, session.afterCalls
      -- Proc refreshes and stack changes: every payload carries an updated
      -- instance ID, which is exactly the shape that must still trigger a
      -- Sated rescan -- only no longer once per event.
      local payload = { updatedAuraInstanceIDs = { 7 } }
      Stress.Measure("key hidden player aura burst", 1000, function()
        for _ = 1, 1000 do
          session.Dispatch("UNIT_AURA", "player", payload)
          session.Dispatch("SPELL_UPDATE_CHARGES")
        end
      end)
      Assert.Equal(session.harmfulReads, beforeHarmful, "aura bursts must not scan Sated slots synchronously")
      Assert.Equal(session.fullRenders, beforeRenders, "aura bursts must not pre-render synchronously")
      Assert.Equal(
        session.afterCalls - beforeAfter,
        1,
        "player auras and charge updates must share one trailing CD pass"
      )
      session.Advance(0.1)
      Assert.True(session.harmfulReads > beforeHarmful, "the trailing pass must still rescan the Sated slots")
      Assert.True(session.harmfulReads - beforeHarmful <= 40, "the burst must collapse into a single 40-slot scan")
      Assert.True(
        session.fullRenders - beforeRenders <= 1,
        "the hidden key pre-render must run at most once per coalesced pass"
      )
      Assert.True(session.addon.MplusTimer.GetTimerData().running, "the running key must survive the burst")
    end)
  end)

  test("Mplus stress: player aura updates outside a running key resolve the runtime profile once", function()
    Stress.WithKey(ctx, fixtures, function(session)
      -- Pre-insert / M0 shape: mythic party instance, no running key timer.
      -- This is the context in which every CD-tracker pass has to fall back
      -- to the live instance data instead of the key-timer short cut.
      session.active = false
      session.Dispatch("CHALLENGE_MODE_RESET")
      session.Advance(1)
      Assert.False(session.addon.MplusTimer.GetTimerData().running, "the reset must stop the key timer")
      local originalGetInstanceInfo = _G.GetInstanceInfo
      local instanceReads = 0
      _G.GetInstanceInfo = function(...)
        instanceReads = instanceReads + 1
        return originalGetInstanceInfo(...)
      end
      local payload = { updatedAuraInstanceIDs = { 7 } }
      local events = 100
      local ok, err = pcall(function()
        for _ = 1, events do
          session.Dispatch("UNIT_AURA", "player", payload)
        end
      end)
      _G.GetInstanceInfo = originalGetInstanceInfo
      assert(ok, err)
      io.write(string.format("[STRESS] profile instance reads per player aura update=%.2f\n", instanceReads / events))
      Assert.True(
        instanceReads <= events,
        "one CD-tracker pass must resolve the runtime profile at most once, not once per helper"
      )
    end)
  end)

  test("Mplus stress: five minutes hidden keep kick sync bounded and CD polling stopped", function()
    Stress.WithKey(ctx, fixtures, function(session)
      session.runtime.mainFrame:Hide()
      session.Advance(1)
      Assert.Equal(session.CountTickers(1), 0, "hidden UI must cancel its CD ticker")
      local beforeMessages, beforeHarmful = #session.messages, session.harmfulReads
      Stress.Measure("key hidden 300 seconds", 600, function()
        session.Advance(300)
      end)
      local kicks = 0
      for index = beforeMessages + 1, #session.messages do
        if session.messages[index].payload:find("KICK:", 1, true) == 1 then
          kicks = kicks + 1
        end
      end
      Assert.True(
        kicks >= 19 and kicks <= 22,
        "15-second hidden kick heartbeats must stay active without per-tick spam"
      )
      Assert.Equal(session.harmfulReads, beforeHarmful, "hidden time passage must not poll the CD aura slots")
      Assert.Equal(session.fullRenders, 0, "hidden tickers must not render the complete roster")
      Assert.True(session.addon.MplusTimer.GetTimerData().running, "hidden tickers must retain the key timer")
    end)
  end)

  test("Mplus stress: 10000 real sender key packets converge with one roster update", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local sender = ctx.load_modules({ "isiLive_sync.lua" })
      sender.Sync.SendKey({
        mapID = 2662,
        level = 12,
        capturedAt = session.now,
        source = "stress",
        isVisible = true,
        force = true,
      })
      local wire = session.messages[#session.messages]
      Assert.True(wire.payload:find("KEY:", 1, true) == 1, "wire bytes must come from the production key sender")
      Stress.Measure("key peer duplicate burst", 10000, function()
        for _ = 1, 10000 do
          session.Dispatch("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, "Peer1-Realm")
        end
      end)
      local key = session.addon.Sync.GetPlayerKeyInfo("Peer1", "Realm")
      Assert.Equal(key.mapID, 2662, "the receiver must converge to the sender's exact map")
      Assert.Equal(key.level, 12, "the receiver must converge to the sender's exact key level")
      Assert.Equal(session.runtime.GetRoster().party1.keyLevel, 12, "the real roster must apply the peer packet")
      Assert.Equal(session.fullRenders, 1, "duplicates must not repeat the first roster update")
    end)
  end)

  test("Mplus stress: peer kick cooldown packets refresh only the kick column", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local sender = ctx.load_modules({ "isiLive_sync.lua" })
      local panel = session.runtime.rosterPanelController
      local originalRefreshKickColumn = panel.RefreshKickColumn
      local kickRefreshes = 0
      panel.RefreshKickColumn = function(...)
        kickRefreshes = kickRefreshes + 1
        return originalRefreshKickColumn(...)
      end
      local function DeliverKick(remain, senderName)
        -- Production sender cadence: one packet per second while on cooldown,
        -- each carrying ceil(remain), so every payload differs.
        sender.Sync.SendKick({
          hasKick = true,
          onCooldown = remain > 0,
          cooldownRemain = remain,
          spellID = 2139,
          force = true,
        })
        local wire = session.messages[#session.messages]
        Assert.True(wire.payload:find("KICK:", 1, true) == 1, "wire bytes must come from the production kick sender")
        session.Dispatch("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, senderName)
      end

      -- The first packet may mark the peer as an isiLive user (full refresh).
      DeliverKick(15, "Peer1-Realm")
      session.Advance(1)
      local rendersBefore, kickRefreshesBefore = session.fullRenders, kickRefreshes
      for remain = 14, 0, -1 do
        DeliverKick(remain, "Peer1-Realm")
        session.Advance(1)
      end
      Assert.Equal(session.fullRenders, rendersBefore, "peer kick countdown packets must not rebuild the roster")
      Assert.True(kickRefreshes - kickRefreshesBefore >= 15, "every peer kick change must refresh the kick column")
      local peerRow = session.runtime.GetRoster().party1
      Assert.True(peerRow.syncHasKick, "the real roster must apply the peer kick state")
      Assert.False(peerRow.syncKickOnCooldown, "the final ready packet must converge the peer kick to usable")

      -- Own echo: CHAT_MSG_ADDON on PARTY reflects the sender's own packet.
      local ownBefore = session.addon.Sync.GetPlayerKickInfo("Tester", "Realm")
      DeliverKick(9, "Tester-Realm")
      Assert.Equal(
        session.addon.Sync.GetPlayerKickInfo("Tester", "Realm"),
        ownBefore,
        "the own KICK echo must not overwrite the locally polled kick state"
      )
      Assert.Equal(session.fullRenders, rendersBefore, "the own KICK echo must not rebuild the roster")
    end)
  end)

  test("Mplus stress: an idle minute in a key reads forces but repaints nothing unchanged", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local panel = session.runtime.rosterPanelController
      local originalRefreshKillTrackRow = panel.RefreshKillTrackRow
      local rowRefreshes = 0
      panel.RefreshKillTrackRow = function(...)
        rowRefreshes = rowRefreshes + 1
        return originalRefreshKillTrackRow(...)
      end
      local seasonData = session.addon.SeasonData
      local originalForces = seasonData.GetMatchingForcesData
      local forcesReads = 0
      seasonData.GetMatchingForcesData = function(...)
        forcesReads = forcesReads + 1
        return originalForces(...)
      end
      local deathWatch = session.addon.DeathWatch
      local originalSummaries = deathWatch.GetAllDeathSummaries
      local summaryCopies = 0
      deathWatch.GetAllDeathSummaries = function(...)
        summaryCopies = summaryCopies + 1
        return originalSummaries(...)
      end
      local scenarioReadsBefore = session.scenarioReads

      -- Between pulls: the 0.5 s ticker keeps reading live forces (rule 60),
      -- but nothing on the row can change while the forces stand still.
      session.Advance(60)
      local ticksRead = session.scenarioReads - scenarioReadsBefore
      Assert.True(ticksRead >= 100, "the ticker must keep reading live scenario data for the whole key")
      io.write(
        string.format(
          "[STRESS] idle key minute: scenario reads=%d row refreshes=%d forces DB reads=%d death summary copies=%d\n",
          ticksRead,
          rowRefreshes,
          forcesReads,
          summaryCopies
        )
      )
      Assert.Equal(rowRefreshes, 0, "unchanged forces must not repaint the kill row")
      Assert.True(forcesReads <= 1, "the forces DB must be resolved once per run, not per tick")
      Assert.Equal(summaryCopies, 0, "the death count must not copy and sort every death summary")

      -- A real forces change still reaches the row on the next tick.
      session.forces = 25
      session.Advance(0.5)
      Assert.True(rowRefreshes >= 1, "a forces change must repaint the kill row")
      Assert.Equal(session.addon.KillTrack.GetData().rawCount, 25, "the row must read the new raw count")
      panel.RefreshKillTrackRow = originalRefreshKillTrackRow
      seasonData.GetMatchingForcesData = originalForces
      deathWatch.GetAllDeathSummaries = originalSummaries
    end)
  end)

  test("Mplus stress: hidden roster renders are deferred until the window is shown", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local sender = ctx.load_modules({ "isiLive_sync.lua" })
      local panel = session.runtime.rosterPanelController
      session.runtime.mainFrame:Hide()
      session.Advance(1)
      -- UnitIsConnected is read once per rendered roster row.
      local rowRenders = 0
      local originalUnitIsConnected = _G.UnitIsConnected
      _G.UnitIsConnected = function()
        rowRenders = rowRenders + 1
        return true
      end
      local ok, err = pcall(function()
        for level = 2, 101 do
          sender.Sync.SendKey({
            mapID = 2662,
            level = level,
            capturedAt = session.now + level,
            source = "stress",
            isVisible = true,
            force = true,
          })
          local wire = session.messages[#session.messages]
          session.Dispatch("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, "Peer1-Realm")
        end
        io.write(string.format("[STRESS] hidden roster: 100 peer key changes rendered %d rows\n", rowRenders))
        Assert.Equal(rowRenders, 0, "a hidden window must not render roster rows for incoming sync data")
        Assert.Equal(session.runtime.GetRoster().party1.keyLevel, 101, "hidden sync must still update the roster data")
        Assert.True(panel.IsHiddenRenderPending(), "the hidden roster must be marked stale")

        -- Opening through a plain Show (the path the queue join, raid return
        -- and LFG highlight take without show callbacks) must render once.
        session.runtime.mainFrame:Show()
        Assert.True(rowRenders > 0, "opening the window must render the deferred roster")
        Assert.False(panel.IsHiddenRenderPending(), "the deferred render must clear the stale mark")
      end)
      _G.UnitIsConnected = originalUnitIsConnected
      assert(ok, err)
    end)
  end)

  test("Mplus stress: hidden teleport button updates are deferred until the window is shown", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local sender = ctx.load_modules({ "isiLive_sync.lua" })
      local teleportUI = session.runtime.teleportUIController
      local updates = 0
      local originalUpdateButtons = teleportUI.UpdateButtons
      teleportUI.UpdateButtons = function(...)
        updates = updates + 1
        return originalUpdateButtons(...)
      end
      session.runtime.mainFrame:Hide()
      session.Advance(1)
      local ok, err = pcall(function()
        updates = 0
        for level = 2, 51 do
          sender.Sync.SendKey({
            mapID = 2662,
            level = level,
            capturedAt = session.now + level,
            source = "stress",
            isVisible = true,
            force = true,
          })
          local wire = session.messages[#session.messages]
          session.Dispatch("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, "Peer1-Realm")
        end
        Assert.Equal(updates, 0, "a hidden window must not rebuild teleport buttons for incoming sync data")

        session.runtime.mainFrame:Show()
        Assert.True(updates >= 1, "opening the window must bring the deferred teleport buttons up to date")
        local afterShow = updates
        session.runtime.mainFrame:Hide()
        session.runtime.mainFrame:Show()
        Assert.Equal(updates, afterShow, "a show without a pending update must not rebuild the buttons again")

        -- A queue or invite highlight carries a sound context and must still
        -- run while hidden: it is what opens the window in the first place.
        session.runtime.mainFrame:Hide()
        updates = 0
        session.runtime.UpdateMPlusTeleportButton("queue")
        Assert.True(updates >= 1, "a queue highlight must not be deferred")
      end)
      teleportUI.UpdateButtons = originalUpdateButtons
      assert(ok, err)
    end)
  end)

  test("Mplus stress: 10000 foreign addon messages are dropped before any sync work", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local raidChecks, nameReads = 0, 0
      local originalIsInRaid, originalUnitFullName = _G.IsInRaid, _G.UnitFullName
      _G.IsInRaid = function(...)
        raidChecks = raidChecks + 1
        return originalIsInRaid(...)
      end
      _G.UnitFullName = function(...)
        nameReads = nameReads + 1
        return originalUnitFullName(...)
      end
      local ok, err = pcall(function()
        Stress.Measure("key foreign addon traffic", 10000, function()
          for i = 1, 10000 do
            session.Dispatch("CHAT_MSG_ADDON", "BigWigs", "V^Timer^" .. (i % 7), "PARTY", "Peer1-Realm")
          end
        end)
      end)
      _G.IsInRaid, _G.UnitFullName = originalIsInRaid, originalUnitFullName
      assert(ok, err)
      io.write(
        string.format("[STRESS] foreign addon traffic: raid checks=%d player name reads=%d\n", raidChecks, nameReads)
      )
      Assert.Equal(raidChecks, 0, "foreign prefixes must be dropped before the raid check")
      Assert.Equal(nameReads, 0, "foreign prefixes must be dropped before the player-name lookup")
      Assert.Equal(session.fullRenders, 0, "foreign prefixes must not touch the roster")
    end)
  end)

  test("Mplus stress: roster churn inside a running raid skips the party-only handlers", function()
    Stress.WithKey(ctx, fixtures, function(session)
      session.raid = true
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(0.1)
      local guidReads = 0
      local originalUnitGUID = _G.UnitGUID
      _G.UnitGUID = function(...)
        guidReads = guidReads + 1
        return originalUnitGUID(...)
      end
      local ok, err = pcall(function()
        for _ = 1, 100 do
          session.Dispatch("GROUP_ROSTER_UPDATE")
        end
      end)
      _G.UnitGUID = originalUnitGUID
      assert(ok, err)
      io.write(string.format("[STRESS] raid roster churn: 100 updates read %d unit GUIDs\n", guidReads))
      Assert.Equal(guidReads, 0, "a running raid must not run the death-watch roster sweep on every roster update")

      session.raid = false
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(0.1)
      Assert.Equal(session.CountTickers(0.5) >= 1, true, "leaving the raid must resume the key tickers")
    end)
  end)

  test("Mplus stress: a raid shrinking to five members stays a raid until it really ends", function()
    Stress.WithParty(ctx, fixtures, function(session)
      local runtime = session.runtime
      Assert.True(runtime.mainFrame:IsShown(), "the fresh party must open the main frame through the real dispatcher")

      session.raid, session.members = true, 6
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(0.1)
      Assert.False(runtime.mainFrame:IsShown(), "raid entry must hide the main frame")
      Assert.True(runtime.GetWasRaidGroup() == true, "raid entry must record the raid state")

      -- One member leaves: the client still reports a raid, now with five members.
      local mark = #session.messages
      session.members = 5
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(1)
      Assert.False(runtime.mainFrame:IsShown(), "a raid with five members must keep the main frame closed")
      Assert.True(runtime.GetWasRaidGroup() == true, "a raid with five members must still count as a raid")
      Assert.Equal(next(runtime.GetRoster()), nil, "a raid with five members must not rebuild the party roster")
      Assert.Equal(#session.messages, mark, "a raid with five members must send no hello and no snapshot")

      -- The raid is converted back to a party: the restore armed at raid entry fires now.
      session.raid = false
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(1)
      Assert.True(runtime.mainFrame:IsShown(), "leaving the raid must reopen the frame that was open before it")
      Assert.False(runtime.GetWasRaidGroup() == true, "leaving the raid must clear the raid state")
    end)
  end)

  test("Mplus stress: the manual refresh rescans the bags for a key swapped in combat", function()
    -- The client API reports no owned key, so the bag link is the only source.
    local bagKey = { mapID = 2649, level = 14 }
    Stress.WithParty(ctx, fixtures, function(session)
      local runtime = session.runtime
      session.Dispatch("BAG_UPDATE_DELAYED")
      Assert.Equal(runtime.GetRoster().player.keyLevel, 14, "the bag event must read key A from the bags")

      -- Key B replaces key A in combat; the gate discards the bag event there.
      session.combat = true
      session.Dispatch("PLAYER_REGEN_DISABLED")
      bagKey = { mapID = 2660, level = 9 }
      session.Dispatch("BAG_UPDATE_DELAYED")
      session.combat = false
      session.Dispatch("PLAYER_REGEN_ENABLED")
      session.Advance(1)
      Assert.Equal(runtime.GetRoster().player.keyLevel, 14, "without a bag event key A is still cached")

      local mark = #session.messages
      runtime.refreshButton:GetScript("OnClick")(runtime.refreshButton)
      Assert.Equal(runtime.GetRoster().player.keyMapID, 2660, "the manual refresh must rescan the bags for key B")
      Assert.Equal(runtime.GetRoster().player.keyLevel, 9, "the manual refresh must report key B's level")
      local sentKeyB = false
      for i = mark + 1, #session.messages do
        local payload = session.messages[i].payload
        if payload:find("^KEY:2660:9") then
          sentKeyB = true
        end
      end
      Assert.True(sentKeyB, "the refresh snapshot must publish key B")
    end, function(globals)
      globals.C_MythicPlus.GetOwnedKeystoneLevel = function()
        return nil
      end
      globals.C_MythicPlus.GetOwnedKeystoneChallengeMapID = function()
        return nil
      end
      globals.C_Container = {
        GetContainerNumSlots = function(bagID)
          return bagID == 0 and 4 or 0
        end,
        GetContainerItemID = function(bagID, slotID)
          return (bagID == 0 and slotID == 2) and 180653 or nil
        end,
        GetContainerItemLink = function(bagID, slotID)
          if bagID == 0 and slotID == 2 then
            return string.format(
              "|cffa335ee|Hkeystone:180653:%d:%d:10:0:0:0|h[Keystone]|h|r",
              bagKey.mapID,
              bagKey.level
            )
          end
          return nil
        end,
        GetContainerItemInfo = function()
          return nil
        end,
      }
    end)
  end)

  test("Mplus stress: peer state fan-outs answer new peers but not every repeated hello", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local sender = ctx.load_modules({ "isiLive_sync.lua" })
      local function FanOutsSince(index)
        local count = 0
        for i = index + 1, #session.messages do
          local payload = session.messages[i].payload
          if payload:find("^HELLO:") and (payload:find(":hello%-ack") or payload:find(":reqsync%-ack")) then
            count = count + 1
          end
        end
        return count
      end
      local function DeliverHello(peer)
        sender.Sync.SendHello({ force = true, isVisible = true, version = "0.9.1", source = "group" })
        local wire = session.messages[#session.messages]
        Assert.True(wire.payload:find("HELLO:", 1, true) == 1, "wire bytes must come from the production HELLO sender")
        session.Dispatch("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, peer)
      end

      local mark = #session.messages
      DeliverHello("Peer2-Realm")
      Assert.Equal(FanOutsSince(mark), 1, "a hello from a peer never synced with must get a fan-out")

      session.Advance(2)
      mark = #session.messages
      for _ = 1, 4 do
        DeliverHello("Peer2-Realm")
      end
      Assert.Equal(FanOutsSince(mark), 0, "repeated hellos from a known peer inside the window must not fan out")

      mark = #session.messages
      session.Dispatch("CHAT_MSG_ADDON", "ISILIVE", "REQSYNC", "PARTY", "Peer2-Realm")
      Assert.Equal(FanOutsSince(mark), 0, "a REQSYNC right after a fan-out must not trigger a second one")

      mark = #session.messages
      DeliverHello("Peer3-Realm")
      Assert.Equal(FanOutsSince(mark), 1, "a new peer must still be answered inside the window")

      session.Advance(11)
      mark = #session.messages
      DeliverHello("Peer2-Realm")
      Assert.Equal(FanOutsSince(mark), 1, "a known peer is answered again once the window has passed")

      mark = #session.messages
      for _ = 1, 5 do
        session.Dispatch("CHAT_MSG_ADDON", "LibKS", "R", "PARTY", "Peer4-Realm")
      end
      local libReplies = 0
      for i = mark + 1, #session.messages do
        if session.messages[i].prefix == "LibKS" then
          libReplies = libReplies + 1
        end
      end
      Assert.True(libReplies <= 1, "five LibKeystone requests inside two seconds must draw at most one reply")
    end)
  end)

  test("Mplus stress: the post-run refresh keeps known peers and answers their hellos once", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local sender = ctx.load_modules({ "isiLive_sync.lua" })
      local peers = { "Peer1-Realm", "Peer2-Realm", "Peer3-Realm", "Peer4-Realm" }
      local function HelloWire(source)
        sender.Sync.SendHello({ force = true, isVisible = true, version = "0.9.1", source = source })
        return session.messages[#session.messages]
      end
      local function FanOutsSince(index)
        local count = 0
        for n = index + 1, #session.messages do
          local payload = session.messages[n].payload
          if payload:find("^HELLO:") and payload:find(":hello%-ack") then
            count = count + 1
          end
        end
        return count
      end
      local groupWire = HelloWire("group")
      for _, peer in ipairs(peers) do
        session.Dispatch("CHAT_MSG_ADDON", groupWire.prefix, groupWire.payload, groupWire.channel, peer)
      end
      local sync = session.addon.Sync
      for _, peer in ipairs(peers) do
        Assert.True(sync.IsUserKnown(peer), peer .. " must be known before the key ends")
      end

      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      session.Advance(6)
      local roster = session.runtime.GetRoster()
      for _, peer in ipairs(peers) do
        Assert.True(sync.IsUserKnown(peer), peer .. " must stay known through the post-run refresh")
      end
      Assert.True(roster.party1.hasIsiLive == true, "a known peer must keep its isiLive marker after the key")

      local refreshWire = HelloWire("refresh")
      sender.Sync.SendRefreshRequest({ force = true })
      local reqsyncWire = session.messages[#session.messages]
      Assert.Equal(reqsyncWire.payload, "REQSYNC", "wire bytes must come from the production REQSYNC sender")
      local mark = #session.messages
      -- Every peer's post-run refresh sends its HELLO and its REQSYNC together.
      for _, peer in ipairs(peers) do
        session.Dispatch("CHAT_MSG_ADDON", refreshWire.prefix, refreshWire.payload, refreshWire.channel, peer)
        session.Dispatch("CHAT_MSG_ADDON", reqsyncWire.prefix, reqsyncWire.payload, reqsyncWire.channel, peer)
      end
      Assert.True(FanOutsSince(mark) <= 1, "four post-run hellos from known peers draw at most one fan-out")
      local reqsyncFanOuts = 0
      for n = mark + 1, #session.messages do
        if session.messages[n].payload:find("^HELLO:") and session.messages[n].payload:find(":reqsync%-ack") then
          reqsyncFanOuts = reqsyncFanOuts + 1
        end
      end
      Assert.True(
        FanOutsSince(mark) + reqsyncFanOuts <= 1,
        "four post-run hello and REQSYNC pairs from known peers draw at most one fan-out in total"
      )

      -- The manual refresh still starts from a clean slate.
      session.Advance(11)
      Assert.True(session.runtime.refreshController.RunFullRefresh(), "the manual refresh must run")
      Assert.False(sync.IsUserKnown("Peer1-Realm"), "a manual refresh still forgets known peers")
      Assert.False(roster.party1.hasIsiLive == true, "a manual refresh still clears the isiLive markers")
    end)
  end)

  test("Mplus stress: a peer reloading through another peer's fan-out still gets the state on its REQSYNC", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local sender = ctx.load_modules({ "isiLive_sync.lua" })
      local function Wire(send)
        send()
        return session.messages[#session.messages]
      end
      local groupWire = Wire(function()
        sender.Sync.SendHello({ force = true, isVisible = true, version = "0.9.1", source = "group" })
      end)
      local reqsyncWire = Wire(function()
        sender.Sync.SendRefreshRequest({ force = true })
      end)
      Assert.Equal(reqsyncWire.payload, "REQSYNC", "wire bytes must come from the production REQSYNC sender")
      local function Deliver(wire, peer)
        session.Dispatch("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, peer)
      end
      local function FanOutsSince(index)
        local count = 0
        for n = index + 1, #session.messages do
          local payload = session.messages[n].payload
          if payload:find("^HELLO:") and (payload:find(":hello%-ack") or payload:find(":reqsync%-ack")) then
            count = count + 1
          end
        end
        return count
      end

      Deliver(groupWire, "Peer2-Realm")
      Deliver(groupWire, "Peer3-Realm")
      session.Advance(20)

      -- Peer2 reloads. While it sits on the loading screen, a new peer joins
      -- and this client fans out to the group -- Peer2 cannot receive that.
      local mark = #session.messages
      Deliver(groupWire, "Peer5-Realm")
      Assert.Equal(FanOutsSince(mark), 1, "the joining peer must get a fan-out")

      session.Advance(1)
      mark = #session.messages
      Deliver(groupWire, "Peer2-Realm")
      Assert.Equal(FanOutsSince(mark), 0, "the reloaded known peer's hello stays inside the known-peer window")
      session.Advance(0.5)
      Deliver(reqsyncWire, "Peer2-Realm")
      Assert.Equal(FanOutsSince(mark), 1, "the reloaded peer's REQSYNC must be answered: it missed the last fan-out")

      -- The mid-key reload path sends a second REQSYNC; the answer above served it.
      mark = #session.messages
      Deliver(reqsyncWire, "Peer2-Realm")
      Deliver(reqsyncWire, "Peer3-Realm")
      Assert.Equal(FanOutsSince(mark), 0, "REQSYNCs right after the answering fan-out must stay throttled")

      -- A peer that was online for the fan-out keeps the plain 3-second window.
      session.Advance(1)
      mark = #session.messages
      Deliver(groupWire, "Peer3-Realm")
      session.Advance(0.5)
      Deliver(reqsyncWire, "Peer3-Realm")
      Assert.Equal(FanOutsSince(mark), 0, "a peer seen after the last fan-out must not bypass the window")
    end)
  end)

  test("Mplus stress: a re-sync click right after the key ends does not block the post-run refresh", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local runtime = session.runtime
      local state = runtime.runtimeState
      Assert.True(state.HasRioBaselineSnapshot(), "the key start must capture a RIO baseline")

      session.active = false
      session.Dispatch("CHALLENGE_MODE_COMPLETED")
      -- The player presses Re-Sync before the delayed post-run refresh is due.
      session.Advance(2)
      runtime.refreshButton:GetScript("OnClick")(runtime.refreshButton)
      Assert.False(state.IsRioDeltaDisplayEnabled(), "the early manual refresh alone must not enable the delta")

      -- The post-run refresh and its retries all fall inside the manual
      -- refresh's debounce window; it must still run and enable the delta.
      session.Advance(15)
      Assert.True(state.IsRioDeltaDisplayEnabled(), "the delayed post-run refresh must enable the RIO delta")
    end, function(globals)
      globals.C_PlayerInfo = {
        GetPlayerMythicPlusRatingSummary = function()
          return { currentSeasonScore = 2500 }
        end,
      }
    end)
  end)

  -- Also run by tools/simulate_role_marker_macro.lua (scenario 12); keep the name in sync.
  test("Mplus stress: a role macro left stale in combat is rewritten when a closed window reopens", function()
    local partyNames = { player = "Tester", party1 = "Anna", party2 = "Peer2", party3 = "Peer3", party4 = "Peer4" }
    local function FindRoleButtons(session, name)
      local wanted = "\n/target " .. name .. "\n"
      local found = {}
      for _, frame in ipairs(session.frames) do
        local macro = type(frame.GetAttribute) == "function" and frame:GetAttribute("macrotext1") or nil
        if type(macro) == "string" and macro:find(wanted, 1, true) then
          found[#found + 1] = frame
        end
      end
      return found
    end
    Stress.WithParty(ctx, fixtures, function(session)
      local runtime = session.runtime
      Assert.True(runtime.mainFrame:IsShown(), "the fresh party must open the main frame")
      Assert.Equal(#FindRoleButtons(session, "Anna"), 1, "the healer row must carry Anna's marker macro")

      -- Combat: Anna leaves and Zara takes the healer slot while the window is
      -- open. The render runs, but the secure macro cannot be rewritten.
      session.combat = true
      session.Dispatch("PLAYER_REGEN_DISABLED")
      partyNames.party1 = "Zara"
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(1)
      Assert.Equal(#FindRoleButtons(session, "Zara"), 0, "no secure attribute is written in combat")
      -- The stale mark is set by the combat render itself. Today the post-combat
      -- kill-track repaint also marks the hidden roster stale, which alone would
      -- hide this bug; the guarantee must not hang on that side effect.
      Assert.True(
        runtime.rosterPanelController.IsHiddenRenderPending(),
        "a render in combat lockdown must leave the roster marked stale"
      )

      -- The player closes the window in combat; the hide lands after combat.
      runtime.SetMainFrameVisible(false)
      session.combat = false
      session.Dispatch("PLAYER_REGEN_ENABLED")
      session.Advance(1)
      Assert.False(runtime.mainFrame:IsShown(), "the deferred hide must apply after combat")

      -- A queue highlight reopens the window without its show callbacks.
      runtime.SetMainFrameVisible(true, { reason = "lfg-highlight", skipShowCallbacks = true })
      Assert.True(runtime.mainFrame:IsShown(), "the highlight must reopen the window")
      Assert.Equal(#FindRoleButtons(session, "Anna"), 0, "no role button may still target the departed Anna")
      Assert.Equal(#FindRoleButtons(session, "Zara"), 1, "the healer row must target its current occupant Zara")
    end, function(globals)
      globals.UnitName = function(unit)
        return partyNames[unit], "Realm"
      end
      globals.UnitFullName = globals.UnitName
      globals.GetUnitName = function(unit)
        return partyNames[unit] and (partyNames[unit] .. "-Realm") or nil
      end
      globals.UnitGUID = function(unit)
        return partyNames[unit] and ("Player-1-" .. partyNames[unit]) or nil
      end
      globals.UnitGroupRolesAssigned = function(unit)
        return unit == "party1" and "HEALER" or "DAMAGER"
      end
    end)
  end)

  test("Mplus stress: the hello acknowledgement honors the sync setting", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local sender = ctx.load_modules({ "isiLive_sync.lua" })
      sender.Sync.SendHello({ force = true, isVisible = true, version = "0.9.1", source = "group" })
      local wire = session.messages[#session.messages]
      Assert.True(wire.payload:find("HELLO:", 1, true) == 1, "wire bytes must come from the production HELLO sender")
      local function AcksSince(index)
        local count = 0
        for n = index + 1, #session.messages do
          local message = session.messages[n]
          if message.payload:find("^ACK:") and message.channel == "WHISPER" then
            count = count + 1
          end
        end
        return count
      end

      _G.IsiLiveDB.syncEnabled = false
      local mark = #session.messages
      session.Dispatch("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, "Peer2-Realm")
      Assert.Equal(AcksSince(mark), 0, "with sync switched off no acknowledgement may be whispered")
      Assert.Equal(#session.messages, mark, "with sync switched off nothing at all may be sent")

      _G.IsiLiveDB.syncEnabled = true
      mark = #session.messages
      session.Dispatch("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, "Peer3-Realm")
      Assert.Equal(AcksSince(mark), 1, "with sync on a new peer's hello is acknowledged once")
    end)
  end)

  test("Mplus stress: 10000 unavailable scenario reads preserve the verified key snapshot", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local timer = session.addon.MplusTimer.GetTimerData()
      session.scenarioUnavailable = true
      session.elapsedUnavailable = true
      Stress.Measure("key unavailable API burst", 10000, function()
        for _ = 1, 10000 do
          session.Dispatch("SCENARIO_CRITERIA_UPDATE")
          session.addon.MplusTimer.GetTimerData()
        end
      end)
      local forces = session.addon.KillTrack.GetData()
      Assert.Equal(forces.percent, 10, "unavailable reads must preserve the last verified forces percent")
      Assert.Equal(forces.rawCount, 10, "unavailable reads must preserve the verified raw count")
      Assert.Equal(forces.total, 100, "unavailable reads must preserve the matching denominator")
      Assert.Equal(
        session.addon.MplusTimer.GetTimerData().timer,
        timer.timer,
        "unavailable elapsed reads must preserve the timer"
      )
      Assert.Equal(session.fullRenders, 0, "scenario failures must not rebuild the roster")
    end)
  end)

  test("Mplus stress: visible five minute key refreshes forces without full roster renders", function()
    Stress.WithKey(ctx, fixtures, function(session)
      session.forces = 75
      Stress.Measure("key visible 300 seconds", 600, function()
        session.Advance(300)
      end)
      Assert.Equal(session.addon.KillTrack.GetData().percent, 75, "periodic reads must apply changed live forces")
      Assert.Equal(session.addon.MplusTimer.GetTimerData().timer, 305, "timer must follow elapsed API time")
      Assert.Equal(session.fullRenders, 0, "periodic key refreshes must not rebuild the roster")
    end)
  end)

  test("Mplus stress: 10000 malformed peer packets leave key and roster unresolved", function()
    Stress.WithKey(ctx, fixtures, function(session)
      Stress.Measure("key malformed peer burst", 10000, function()
        for _ = 1, 10000 do
          session.Dispatch("CHAT_MSG_ADDON", "ISILIVE", "KEY:2662:not-a-level:105:stress", "PARTY", "Peer1-Realm")
        end
      end)
      Assert.Nil(session.addon.Sync.GetPlayerKeyInfo("Peer1", "Realm"), "malformed values must remain unresolved")
      Assert.Nil(session.runtime.GetRoster().party1.keyLevel, "malformed traffic must not invent a roster key")
      Assert.Equal(session.fullRenders, 0, "rejected traffic must not rebuild the roster")
    end)
  end)

  test("Mplus stress: queued cooldown bursts stop processing on raid entry", function()
    Stress.WithKey(ctx, fixtures, function(session)
      for _ = 1, 10000 do
        session.Dispatch("SPELL_UPDATE_COOLDOWN")
        session.Dispatch("SPELL_UPDATE_CHARGES")
      end
      session.raid = true
      session.Dispatch("GROUP_ROSTER_UPDATE")
      local beforeHarmful, beforeMessages = session.harmfulReads, #session.messages
      local beforeScenario = session.scenarioReads
      session.Advance(60)
      Assert.Equal(session.scenarioReads, beforeScenario, "raid must stop scenario polling")
      Assert.Equal(session.harmfulReads, beforeHarmful, "raid must suppress queued and periodic CD reads")
      Assert.Equal(#session.messages, beforeMessages, "raid must stop background sync")
      Assert.Equal(session.CountTickers(0.5), 0, "raid must stop kick and forces polling")
      Assert.Equal(session.CountTickers(1), 0, "raid must stop CD polling")
      Assert.Nil(session.runtime.mainFrame:GetScript("OnUpdate"), "raid must stop inspection")
      session.raid = false
      session.forces = 80
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.Advance(0.5)
      Assert.Equal(session.addon.KillTrack.GetData().percent, 80, "party return must resume live forces reads")
    end)
  end)

  test("Mplus stress: twenty raid returns resume exactly one visible CD ticker", function()
    Stress.WithKey(ctx, fixtures, function(session)
      for cycle = 1, 20 do
        for _ = 1, 100 do
          session.Dispatch("SPELL_UPDATE_COOLDOWN")
          session.Dispatch("SPELL_UPDATE_CHARGES")
        end
        session.raid = true
        session.Dispatch("GROUP_ROSTER_UPDATE")
        local reads, messages = session.scenarioReads, #session.messages
        session.Advance(1)
        Assert.Equal(session.CountTickers(0.5), 0, "raid must cancel kick and forces tickers")
        Assert.Equal(session.CountTickers(1), 0, "raid must cancel CD polling")
        Assert.Equal(session.scenarioReads, reads, "raid must not read scenario data")
        Assert.Equal(#session.messages, messages, "raid must not send background sync")
        session.raid = false
        session.forces = cycle
        session.Dispatch("GROUP_ROSTER_UPDATE")
        Assert.True(session.runtime.mainFrame:IsShown(), "raid return must restore the previously visible UI")
        Assert.True(session.addon.MplusTimer.GetTimerData().running, "raid return must retain the active key")
        Assert.Equal(session.CountTickers(1), 1, "visible active key must resume CD polling without an extra event")
        session.Advance(1)
        Assert.Equal(session.CountTickers(1), 1, "repeated returns must not accumulate CD tickers")
        Assert.Equal(session.CountTickers(0.5), 2, "return must own exactly one forces and one kick ticker")
        Assert.True(
          math.abs(session.addon.KillTrack.GetData().percent - cycle) < 0.000001,
          "forces ticker must apply the current verified fixture value"
        )
      end
      session.runtime.mainFrame:Hide()
      Assert.Equal(session.CountTickers(1), 0, "hiding must cancel CD polling immediately")
      session.runtime.mainFrame:Show()
      Assert.Equal(session.CountTickers(1), 1, "showing an active key must resume exactly one CD ticker")
      session.runtime.mainFrame:Hide()
      session.Advance(1)
      Assert.Equal(session.CountTickers(1), 0, "hidden return must not retain CD polling")
      session.raid = true
      session.Dispatch("GROUP_ROSTER_UPDATE")
      session.raid = false
      session.Dispatch("GROUP_ROSTER_UPDATE")
      Assert.False(session.runtime.mainFrame:IsShown(), "a previously hidden UI must stay hidden after raid")
      Assert.Equal(session.CountTickers(1), 0, "hidden raid return must not start CD polling")
    end)
  end)

  local function AssertEndedKey(session, endEvent)
    for _ = 1, 10000 do
      session.Dispatch("SPELL_UPDATE_CHARGES")
    end
    session.active = false
    session.Dispatch(endEvent)
    local beforeHarmful = session.harmfulReads
    session.Advance(0.1)
    Assert.False(session.addon.MplusTimer.GetTimerData().running, "late callbacks must not revive the key timer")
    Assert.False(session.addon.KillTrack.GetData().active, "late callbacks must not revive forces tracking")
    Assert.Nil(session.runtime.cdTrackerController.GetBResInfo(), "reset must keep BR data cleared")
    Assert.Nil(session.runtime.cdTrackerController.GetLustInfo(), "reset must keep Bloodlust data cleared")
    Assert.Equal(session.harmfulReads, beforeHarmful, "late charge callback must not scan an ended key")
    session.grouped = false
    session.Dispatch("GROUP_ROSTER_UPDATE")
    session.Advance(30)
    Assert.Equal(session.CountTickers(0.5), 0, "leaving the group must stop kick and forces tickers")
    Assert.Equal(session.CountTickers(1), 0, "ended key must retain no CD polling")
    Assert.Nil(session.runtime.mainFrame:GetScript("OnUpdate"), "solo transition must stop inspection")
  end

  test("Mplus stress: pending cooldown burst stays cleared after key reset and group exit", function()
    Stress.WithKey(ctx, fixtures, function(session)
      AssertEndedKey(session, "CHALLENGE_MODE_RESET")
    end)
  end)

  test("Mplus stress: pending cooldown burst stays cleared after key completion and group exit", function()
    Stress.WithKey(ctx, fixtures, function(session)
      AssertEndedKey(session, "CHALLENGE_MODE_COMPLETED")
    end)
  end)

  test("Mplus stress: an M0 dungeon entry opens the tracked party run through the real wiring", function()
    Stress.WithKey(ctx, fixtures, function(session)
      session.active = false
      session.Dispatch("CHALLENGE_MODE_RESET")
      -- The factory's own runtime state is the store every M0 consumer reads
      -- (CD tracker, DeathWatch, BR/Lust announces); it has no event surface.
      local runtimeState = session.runtime.runtimeState
      local originalGetInstanceInfo = _G.GetInstanceInfo
      local function EnterZone(instanceType, difficultyID)
        _G.GetInstanceInfo = function()
          return "Test zone", instanceType, difficultyID, "", 5, false, false, 2662
        end
        session.Dispatch("ZONE_CHANGED_NEW_AREA")
        return runtimeState.IsTrackedPartyRunActive()
      end
      local ok, err = pcall(function()
        Assert.True(EnterZone("party", 23), "entering an M0 dungeon must open the tracked party run")
        Assert.False(EnterZone("none", 0), "leaving the dungeon must close the tracked party run")
      end)
      _G.GetInstanceInfo = originalGetInstanceInfo
      assert(ok, err)
    end)
  end)

  test("Mplus stress: the inspect loop detaches once its queue drains and wakes on new work", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local frame = session.runtime.mainFrame
      local inspector = session.runtime.inspectController
      -- Reads the controller's own queue fields, so the scenario also runs
      -- against a controller without HasPendingWork.
      local function HasPendingWork()
        return inspector.isInspecting ~= nil or #inspector.inspectQueue > 0 or #inspector.retryQueue > 0
      end
      local notified = {}
      local answer = true
      _G.UnitIsVisible = function()
        return true
      end
      _G.CanInspect = function()
        return true
      end
      _G.NotifyInspect = function(unit)
        notified[#notified + 1] = unit
      end
      -- One rendered frame: 0.3 s passes the 0.25 s loop throttle. The WoW
      -- client calls the frame's current OnUpdate script, nothing else.
      local handlerCalls = 0
      local function RunFrames(count)
        for _ = 1, count do
          session.Advance(0.3)
          local onUpdate = frame:GetScript("OnUpdate")
          if onUpdate then
            handlerCalls = handlerCalls + 1
            local before = #notified
            onUpdate(frame, 0.3)
            if answer and #notified > before then
              session.Dispatch("INSPECT_READY", _G.UnitGUID(notified[#notified]))
            end
          end
        end
      end
      local ok, err = pcall(function()
        Assert.True(HasPendingWork(), "the key-start roster must queue its members for inspection")
        Assert.Equal(type(frame:GetScript("OnUpdate")), "function", "queued inspect work must attach the loop")

        -- Combat pause: the loop keeps its work but dispatches nothing.
        session.combat = true
        RunFrames(20)
        Assert.Equal(#notified, 0, "combat must pause inspect dispatch")
        Assert.True(HasPendingWork(), "combat must keep the queued inspect work")
        session.combat = false

        RunFrames(200)
        Assert.True(#notified >= 1, "out of combat the queued members must be inspected")
        Assert.False(HasPendingWork(), "every answered inspect must drain the queue")

        local idleBefore = handlerCalls
        RunFrames(600)
        io.write(
          string.format("[STRESS] inspect loop: idle handler calls in 600 frames=%d\n", handlerCalls - idleBefore)
        )
        Assert.Equal(handlerCalls - idleBefore, 0, "an idle grouped window must not run the inspect loop per frame")
        Assert.Nil(frame:GetScript("OnUpdate"), "a drained inspect queue must detach the per-frame loop")

        -- New work wakes the loop through the real enqueue path (the roster
        -- rebuild after the key); an unanswered inspect still times out and
        -- is retried.
        answer = false
        local notifiedBefore = #notified
        session.active = false
        session.Dispatch("CHALLENGE_MODE_COMPLETED")
        session.Dispatch("GROUP_ROSTER_UPDATE")
        Assert.True(HasPendingWork(), "the roster update must queue fresh inspect work")
        Assert.Equal(type(frame:GetScript("OnUpdate")), "function", "new inspect work must re-attach the loop")
        RunFrames(10)
        Assert.True(#notified > notifiedBefore, "the woken loop must dispatch the new inspect")
        RunFrames(40)
        Assert.True(#notified >= notifiedBefore + 2, "an unanswered inspect must time out and be retried")

        -- Hiding stops processing as before.
        frame:Hide()
        Assert.Nil(frame:GetScript("OnUpdate"), "hiding must detach the loop")
        Assert.False(HasPendingWork(), "hiding must clear the inspect work")
      end)
      _G.UnitIsVisible, _G.CanInspect, _G.NotifyInspect = nil, nil, nil
      assert(ok, err)
    end)
  end)

  test("Mplus stress: deferred inspect retries detach the loop and still reach a returning member", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local frame = session.runtime.mainFrame
      local notified = {}
      local outOfRange = { party2 = true }
      _G.UnitIsVisible = function(unit)
        return not outOfRange[unit]
      end
      _G.CanInspect = function()
        return true
      end
      _G.NotifyInspect = function(unit)
        notified[#notified + 1] = unit
      end
      -- One rendered frame: 0.3 s passes the 0.25 s loop throttle. The WoW
      -- client calls the frame's current OnUpdate script, nothing else.
      local handlerCalls = 0
      local function RunFrames(count)
        for _ = 1, count do
          session.Advance(0.3)
          local onUpdate = frame:GetScript("OnUpdate")
          if onUpdate then
            handlerCalls = handlerCalls + 1
            local before = #notified
            onUpdate(frame, 0.3)
            if #notified > before then
              session.Dispatch("INSPECT_READY", _G.UnitGUID(notified[#notified]))
            end
          end
        end
      end
      local function WasInspected(unit)
        for _, notifiedUnit in ipairs(notified) do
          if notifiedUnit == unit then
            return true
          end
        end
        return false
      end
      local ok, err = pcall(function()
        Assert.Equal(type(frame:GetScript("OnUpdate")), "function", "queued inspect work must attach the loop")
        RunFrames(100)
        Assert.True(#notified >= 1, "the reachable members must be inspected")
        Assert.False(WasInspected("party2"), "an out-of-range member cannot be inspected")
        Assert.True(
          #session.runtime.inspectController.retryQueue > 0,
          "the out-of-range member must wait in the retry queue"
        )

        -- 180 seconds with one member out of range: one retry check per
        -- 5-second retry interval instead of one handler call per frame.
        local before = handlerCalls
        RunFrames(600)
        local idleCalls = handlerCalls - before
        io.write(
          string.format("[STRESS] inspect loop: handler calls in 600 frames with a deferred retry=%d\n", idleCalls)
        )
        Assert.True(idleCalls <= 80, "deferred retries alone must not run the inspect loop on every frame")
        Assert.Nil(frame:GetScript("OnUpdate"), "between retries the per-frame loop must stay detached")

        -- The member comes back into range: the next due retry inspects it.
        outOfRange.party2 = nil
        RunFrames(30)
        Assert.True(WasInspected("party2"), "a member back in range must still be inspected")
      end)
      _G.UnitIsVisible, _G.CanInspect, _G.NotifyInspect = nil, nil, nil
      assert(ok, err)
    end)
  end)

  test("Mplus stress: the system option toggles follow CVAR_UPDATE without a polling ticker", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local frame = session.runtime.mainFrame
      local cvars = { advancedCombatLogging = "0", damageMeterResetOnNewInstance = "0" }
      local reads = 0
      local originalCVar = _G.C_CVar
      _G.C_CVar = {
        GetCVar = function(name)
          reads = reads + 1
          return cvars[name]
        end,
      }
      local ok, err = pcall(function()
        Assert.True(frame:IsShown(), "the key fixture keeps the main window visible")
        session.FireChildrenOnShow(frame)
        session.Advance(60)
        io.write(string.format("[STRESS] system option toggles: visible idle minute CVar reads=%d\n", reads))
        Assert.Equal(reads, 0, "an idle visible minute must not poll the CVars on a ticker")

        cvars.advancedCombatLogging = "1"
        local delivered = session.DispatchToFrames("CVAR_UPDATE", "advancedCombatLogging", "1")
        Assert.True(delivered >= 1, "the toggle watcher must be registered for CVAR_UPDATE")
        Assert.True(reads >= 1, "a watched CVar change must refresh the visible toggles")

        local before = reads
        session.DispatchToFrames("CVAR_UPDATE", "nameplateShowAll", "1")
        Assert.Equal(reads, before, "an unrelated CVar change must not refresh the toggles")

        frame:Hide()
        before = reads
        session.DispatchToFrames("CVAR_UPDATE", "damageMeterResetOnNewInstance", "1")
        Assert.Equal(reads, before, "a hidden window must ignore CVar changes")
        frame:Show()
        Assert.True(reads > before, "showing the window must refresh the toggles once")
      end)
      _G.C_CVar = originalCVar
      assert(ok, err)
    end)
  end)

  test("Mplus stress: visible roster renders resize the main frame only when its size changes", function()
    Stress.WithKey(ctx, fixtures, function(session)
      local sender = ctx.load_modules({ "isiLive_sync.lua" })
      local frame = session.runtime.mainFrame
      local heightWrites = 0
      local originalSetHeight = frame.SetHeight
      frame.SetHeight = function(self, height)
        heightWrites = heightWrites + 1
        return originalSetHeight(self, height)
      end
      local ok, err = pcall(function()
        local rendersBefore = session.fullRenders
        for level = 2, 101 do
          sender.Sync.SendKey({
            mapID = 2662,
            level = level,
            capturedAt = session.now + level,
            source = "stress",
            isVisible = true,
            force = true,
          })
          local wire = session.messages[#session.messages]
          session.Dispatch("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, "Peer1-Realm")
        end
        local renders = session.fullRenders - rendersBefore
        io.write(
          string.format(
            "[STRESS] main frame size: %d visible renders wrote the height %d times\n",
            renders,
            heightWrites
          )
        )
        Assert.True(renders >= 100, "every changed peer key must render the visible roster")
        Assert.Equal(heightWrites, 0, "renders with an unchanged roster height must not resize the frame")

        -- Another path resizes the frame directly; the next render must
        -- notice through the live frame size and restore the roster height.
        local rosterHeight = frame:GetHeight()
        originalSetHeight(frame, rosterHeight + 40)
        sender.Sync.SendKey({
          mapID = 2662,
          level = 2,
          capturedAt = session.now + 500,
          source = "stress",
          isVisible = true,
          force = true,
        })
        local wire = session.messages[#session.messages]
        session.Dispatch("CHAT_MSG_ADDON", wire.prefix, wire.payload, wire.channel, "Peer1-Realm")
        Assert.Equal(heightWrites, 1, "a frame resized elsewhere must be restored by the next render")
        Assert.Equal(frame:GetHeight(), rosterHeight, "the render must restore the roster-derived height")
      end)
      frame.SetHeight = nil
      assert(ok, err)
    end)
  end)

  test("Mplus stress: the key start pre-builds the death alert so the first death creates no frame", function()
    Stress.WithKey(ctx, fixtures, function(session)
      -- The fixture's CHALLENGE_MODE_START plus five seconds already ran the
      -- real key start; the first tank death follows mid-combat.
      local deathAlert = session.addon.DeathAlert
      local originals = {
        UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned,
        UnitIsConnected = _G.UnitIsConnected,
        UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost,
        ShowRoleDeath = deathAlert.ShowRoleDeath,
        Prebuild = deathAlert.Prebuild,
      }
      local dead = {}
      _G.UnitGroupRolesAssigned = function(unit)
        return unit == "party1" and "TANK" or "DAMAGER"
      end
      _G.UnitIsConnected = function()
        return true
      end
      _G.UnitIsDeadOrGhost = function(unit)
        return dead[unit] == true
      end
      local shown = {}
      deathAlert.ShowRoleDeath = function(role)
        local result = originals.ShowRoleDeath(role)
        shown[#shown + 1] = { role = role, result = result }
        return result
      end
      local ok, err = pcall(function()
        session.combat = true
        session.Dispatch("PLAYER_REGEN_DISABLED")
        local framesBefore = #session.frames
        dead.party1 = true
        session.Dispatch("UNIT_HEALTH", "party1")
        local created = #session.frames - framesBefore
        io.write(string.format("[STRESS] death alert: frames created by the first death=%d\n", created))
        Assert.Equal(#shown, 1, "the tank death must reach the real death alert")
        Assert.True(shown[1].role == "TANK" and shown[1].result == true, "the death alert must show the tank text")
        Assert.Equal(created, 0, "the first death of a key must not create the alert frame mid-combat")

        -- The pre-build is gated by the setting and skipped in combat.
        session.combat = false
        session.Dispatch("PLAYER_REGEN_ENABLED")
        local prebuilds = 0
        deathAlert.Prebuild = function()
          prebuilds = prebuilds + 1
          return originals.Prebuild()
        end
        local function RestartKey()
          session.active = false
          session.Dispatch("CHALLENGE_MODE_RESET")
          session.active = true
          session.Dispatch("CHALLENGE_MODE_START")
        end
        _G.IsiLiveDB.deathAlertEnabled = false
        RestartKey()
        session.Advance(2)
        Assert.Equal(prebuilds, 0, "disabled death alerts must not pre-build the frame")
        _G.IsiLiveDB.deathAlertEnabled = nil
        RestartKey()
        session.combat = true
        session.Advance(2)
        Assert.Equal(prebuilds, 0, "a pull right after the key start must leave the lazy build in place")
        session.combat = false
        RestartKey()
        session.Advance(2)
        Assert.Equal(prebuilds, 1, "an enabled key start out of combat must pre-build the frame")
      end)
      _G.UnitGroupRolesAssigned = originals.UnitGroupRolesAssigned
      _G.UnitIsConnected = originals.UnitIsConnected
      _G.UnitIsDeadOrGhost = originals.UnitIsDeadOrGhost
      deathAlert.ShowRoleDeath = originals.ShowRoleDeath
      deathAlert.Prebuild = originals.Prebuild
      assert(ok, err)
    end)
  end)

  test("Mplus stress: Bloodlust announce follows the instance after a zone change without a key event", function()
    Stress.WithKey(ctx, fixtures, function(session)
      session.active = false
      session.Dispatch("CHALLENGE_MODE_RESET")
      local originalGetInstanceInfo = _G.GetInstanceInfo
      local function CountLustAnnounces()
        local count = 0
        for _, message in ipairs(session.messages) do
          if tostring(message.payload):find("^BRLUST:LUST:") then
            count = count + 1
          end
        end
        return count
      end
      local function CastInZone(instanceType, difficultyID)
        _G.GetInstanceInfo = function()
          return "Test zone", instanceType, difficultyID, "", 5, false, false, 2662
        end
        session.Dispatch("ZONE_CHANGED_NEW_AREA")
        -- Past the 3 s per-caster dedup window, so only the context decides.
        session.Advance(5)
        local before = CountLustAnnounces()
        session.Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "lust-cast", 2825)
        return CountLustAnnounces() - before
      end
      local ok, err = pcall(function()
        Assert.Equal(CastInZone("none", 0), 0, "the open world must not announce Bloodlust")
        Assert.Equal(CastInZone("party", 23), 1, "a mythic dungeon entered later must announce Bloodlust")
        Assert.Equal(CastInZone("none", 0), 0, "leaving the dungeon must stop the Bloodlust announce")
      end)
      _G.GetInstanceInfo = originalGetInstanceInfo
      assert(ok, err)
    end)
  end)

  -- RUNTIME HALF: the masked stand-in cannot make a table-key lookup or an
  -- `==` raise (plain Lua never consults a metamethod there), so this half
  -- only pins the observable contract through the real dispatcher -- no
  -- dispatch error, no announce, no kick cooldown, and a later plain cast
  -- still reaches CombatEvents behind KickTracker. The ordering itself is
  -- pinned by "UNIT_SPELLCAST_SUCCEEDED handlers reject a masked spell ID first".
  test("Mplus stress: masked pet and player cast spell IDs are dropped by every cast handler", function()
    local secret, secretGlobals = ctx.fixtures.MakeStrictSecret()
    Stress.WithKey(ctx, fixtures, function(session)
      local function CountLustAnnounces()
        local count = 0
        for _, message in ipairs(session.messages) do
          if tostring(message.payload):find("^BRLUST:LUST:") then
            count = count + 1
          end
        end
        return count
      end
      local kickController = session.runtime.kickTrackerController
      local kickBefore = kickController and kickController.GetKickInfo and kickController.GetKickInfo()
      local onCooldownBefore = type(kickBefore) == "table" and kickBefore.onCooldown or nil
      local messagesBefore = #session.messages

      for _ = 1, 200 do
        session.Dispatch("UNIT_SPELLCAST_SUCCEEDED", "pet", "pet-cast", secret)
        session.Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "player-cast", secret)
      end
      Assert.Equal(#session.messages, messagesBefore, "masked cast spell IDs must not produce any addon message")
      local kickAfter = kickController and kickController.GetKickInfo and kickController.GetKickInfo()
      Assert.Equal(
        type(kickAfter) == "table" and kickAfter.onCooldown or nil,
        onCooldownBefore,
        "masked cast spell IDs must not start a kick cooldown"
      )

      session.Advance(5)
      local before = CountLustAnnounces()
      session.Dispatch("UNIT_SPELLCAST_SUCCEEDED", "player", "lust-cast", 2825)
      Assert.Equal(CountLustAnnounces() - before, 1, "a plain cast after the masked ones must still announce")
    end, function(globals)
      for key, value in pairs(secretGlobals) do
        globals[key] = value
      end
    end)
  end)
end
