---@diagnostic disable: undefined-global
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")
return function(test, ctx)
  test("R6 Lust unknown scans never manufacture ready sounds or display", function()
    for _, visibility in ipairs({ "visible", "hidden" }) do
      local secret, secretGlobals = ctx.fixtures.MakeStrictSecret("number")
      local mode = "active"
      Stress.WithKey(ctx, Fixture, function(session)
        if visibility == "hidden" then
          session.runtime.mainFrame:Hide()
        end
        local sounds = 0
        session.addon.SoundUtils.PlayBloodlustReady = function()
          sounds = sounds + 1
        end
        local function Scan(nextMode)
          mode = nextMode
          session.Dispatch("UNIT_AURA", "player", { isFullUpdate = true })
          session.Advance(0.1)
        end
        for _, unknown in ipairs({ "expiry", "id", "container", "error", "cap" }) do
          Scan("active")
          Scan(unknown)
          ctx.assert.Nil(session.runtime.cdTrackerController.GetLustInfo(), "unknown scan hides the timer")
          ctx.assert.False(session.runtime.cdTrackerController.IsLustScanResolved(), "unknown cannot prove ready")
          session.Advance(61)
          ctx.assert.Equal(sounds, 0, "unknown scan and reminders stay silent")
        end
        Scan("active")
        Scan("empty")
        ctx.assert.Equal(sounds, 1, "confirmed removal completes the observed cycle")
        Scan("error")
        session.Advance(61)
        -- Sated is on the never-secret aura list: after a confirmed ready an
        -- unreadable slot cannot be a new Sated, so the reminder keeps running.
        ctx.assert.Equal(sounds, 2, "a confirmed ready cycle keeps reminding through unreadable slots")
      end, function(globals)
        for key, value in pairs(secretGlobals) do
          globals[key] = value
        end
        globals.C_UnitAuras.GetAuraDataByIndex = function(_, index)
          if mode == "error" then
            error("unreadable aura")
          end
          if mode == "empty" then
            return nil
          end
          if mode == "cap" then
            return { spellId = 1 }
          end
          if index > 1 then
            return nil
          end
          if mode == "container" then
            return secret
          end
          return {
            spellId = mode == "id" and secret or 57723,
            expirationTime = mode == "expiry" and secret or 10000,
            duration = 600,
          }
        end
      end)
    end
  end)
  test("R6 fixture visibility follows parents and only delivers effective transitions", function()
    local globals, session = Stress.BuildGlobals(Fixture.buildGlobals)
    local parent = globals.CreateFrame("Frame", nil, globals.UIParent)
    local child = globals.CreateFrame("Frame", nil, parent)
    local grandchild = globals.CreateFrame("Frame", nil, child)
    local hidden = globals.CreateFrame("Frame", nil, parent)
    local shows, hides, hiddenShows = 0, 0, 0
    grandchild:SetScript("OnShow", function()
      shows = shows + 1
    end)
    grandchild:SetScript("OnHide", function()
      hides = hides + 1
    end)
    hidden:SetScript("OnShow", function()
      hiddenShows = hiddenShows + 1
    end)
    child:Show()
    grandchild:Show()
    ctx.assert.True(child:IsShown(), "local shown flag survives a hidden parent")
    ctx.assert.False(grandchild:IsVisible(), "ancestor hides descendants")
    session.FireChildrenOnShow(parent)
    ctx.assert.Equal(shows, 0, "hidden ancestor cannot trigger OnShow")
    parent:Show()
    parent:Show()
    session.FireChildrenOnShow(parent)
    ctx.assert.Equal(shows, 1, "only one effective show transition")
    ctx.assert.Equal(hiddenShows, 0, "explicitly hidden children stay hidden")
    parent:Hide()
    parent:Hide()
    ctx.assert.Equal(hides, 1, "one propagated hide transition")
    child:SetParent(globals.UIParent)
    ctx.assert.Equal(child:GetParent(), globals.UIParent, "reparent updates ownership")
    ctx.assert.True(grandchild:IsVisible(), "reparenting restores effective visibility")
    ctx.assert.Equal(shows, 2, "reparenting delivers one effective show")
    parent:Show()
    ctx.assert.Equal(shows, 2, "former parent no longer propagates callbacks")
  end)
  test("R6 Teleport prefers verified season activity mappings and refreshes portal resolution", function()
    ctx.with_globals(
      { C_LFGList = {
        GetActivityInfoTable = function()
          error("unavailable")
        end,
      } },
      function()
        local addon = ctx.load_modules({ "isiLive_season_data.lua", "isiLive_teleport.lua" })
        ctx.assert.Equal(addon.Teleport.ResolveMapIDByActivityID(514), 249, "verified manifest map remains available")
        ctx.assert.Equal(
          addon.Teleport.ResolveTeleportSpellByActivityID(514),
          1286831,
          "verified manifest portal remains available"
        )
        ctx.assert.Nil(addon.Teleport.ResolveMapIDByActivityID(999999), "unknown activity remains unresolved")
        local original = addon.SeasonData.GetMapIDByActivityID
        addon.SeasonData.GetMapIDByActivityID = function()
          return nil
        end
        addon.SeasonData.ACTIVE_SEASON_ID = 999999
        ctx.assert.Nil(
          addon.Teleport.ResolveTeleportSpellByActivityID(514),
          "old portal cannot survive a changed season"
        )
        addon.SeasonData.GetMapIDByActivityID = original
      end
    )
  end)

  test("Group-full sound plays when a fifth member joins through the real roster dispatch", function()
    for _, variant in ipairs({ "readable", "late-name", "solo-invite", "slot-shift" }) do
      local hideParty4 = false
      local shifted = false
      Stress.WithParty(ctx, Fixture, function(session)
        local sounds = 0
        session.addon.SoundUtils.PlayGroupJoin = function()
          sounds = sounds + 1
          return true
        end
        local runtimeLog = session.runtime.runtimeLogController
        runtimeLog.SetEnabled(true)
        if variant == "solo-invite" then
          -- Invited as the fourth member: login happened solo.
          session.grouped = true
        end
        session.Dispatch("GROUP_ROSTER_UPDATE")
        session.Advance(1)
        ctx.assert.Equal(sounds, 0, variant .. ": four members stay silent")
        session.members = 5
        hideParty4 = variant == "late-name"
        shifted = variant == "slot-shift"
        session.Dispatch("GROUP_ROSTER_UPDATE")
        session.Advance(1)
        hideParty4 = false
        session.Dispatch("GROUP_ROSTER_UPDATE")
        session.Advance(1)
        ctx.assert.Equal(sounds, 1, variant .. ": the fifth join plays the group-full sound once")
        -- The group controller's traces must reach the runtime log; a dropped
        -- logRuntimeTracef once left the whole roster path invisible in-game.
        local logText = table.concat(runtimeLog.GetLogTail(100), "\n")
        ctx.assert.True(logText:find("[GROUP] event=roster_update", 1, true) ~= nil, variant .. ": roster trace logged")
        ctx.assert.True(logText:find("[ROSTER] event=member_joined", 1, true) ~= nil, variant .. ": join trace logged")
        ctx.assert.True(
          logText:find("[ROSTER] event=group_full_sound played=true", 1, true) ~= nil,
          variant .. ": sound result logged"
        )
      end, function(globals, session)
        session.members = 4
        session.grouped = variant ~= "solo-invite"
        -- slot-shift: the newcomer takes party1 and the others move up a slot.
        local shiftMap = { party1 = "party4", party2 = "party1", party3 = "party2", party4 = "party3" }
        local function Source(unit)
          return shifted and shiftMap[unit] or unit
        end
        local unitName = globals.UnitName
        globals.UnitName = function(unit)
          if unit == "party4" and (hideParty4 or (session.members or 5) < 5) then
            return nil
          end
          return unitName(Source(unit))
        end
        globals.UnitFullName = globals.UnitName
        local unitExists = globals.UnitExists
        globals.UnitExists = function(unit)
          if unit == "party4" and (session.members or 5) < 5 then
            return false
          end
          return unitExists(unit)
        end
      end)
    end
  end)

  test("Bloodlust alerts: 10-second warning, ready and 60-second reminder run inside a key", function()
    for _, visibility in ipairs({ "visible", "hidden" }) do
      local satedExpiry = nil
      Stress.WithKey(ctx, Fixture, function(session)
        if visibility == "hidden" then
          session.runtime.mainFrame:Hide()
        end
        local soon, ready = 0, 0
        session.addon.SoundUtils.PlayBloodlustSoon = function()
          soon = soon + 1
        end
        session.addon.SoundUtils.PlayBloodlustReady = function()
          ready = ready + 1
        end
        local function CastLust(duration)
          satedExpiry = session.now + duration
          session.Dispatch("UNIT_AURA", "player", { isFullUpdate = true })
          session.Advance(0.1)
        end
        CastLust(30)
        session.Advance(15)
        ctx.assert.Equal(soon, 0, visibility .. ": no warning while more than 10 seconds remain")
        session.Advance(6)
        ctx.assert.Equal(soon, 1, visibility .. ": warning once 10 seconds remain")
        ctx.assert.Equal(ready, 0, visibility .. ": not ready before Sated expires")
        session.Advance(10)
        ctx.assert.Equal(soon, 1, visibility .. ": the warning plays once per cycle")
        ctx.assert.Equal(ready, 1, visibility .. ": ready once Sated expired, despite unreadable slots")
        session.Advance(60)
        ctx.assert.Equal(ready, 2, visibility .. ": first 60-second reminder")
        session.Advance(60)
        ctx.assert.Equal(ready, 3, visibility .. ": reminder keeps looping while Lust is unused")
        CastLust(600)
        session.Advance(180)
        ctx.assert.Equal(ready, 3, visibility .. ": using Lust again stops the reminder loop")
        ctx.assert.Equal(soon, 1, visibility .. ": no warning early in the new cycle")
      end, function(globals, session)
        globals.C_UnitAuras.GetAuraDataByIndex = function(_, index, filter)
          if filter ~= "HARMFUL" then
            return nil
          end
          if index == 1 then
            if satedExpiry and session.now < satedExpiry then
              return { spellId = 57723, expirationTime = satedExpiry, duration = 600, icon = 132114 }
            end
            -- Another debuff that is secret in the key: the client throws.
            error("Auras cannot be accessed when secret")
          end
          return nil
        end
      end)
    end
  end)
end
