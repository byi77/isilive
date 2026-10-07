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
end
