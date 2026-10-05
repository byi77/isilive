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
