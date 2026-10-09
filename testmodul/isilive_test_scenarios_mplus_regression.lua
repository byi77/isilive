---@diagnostic disable: undefined-global
local Regression = dofile("testmodul/isilive_test_mplus_regression.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")

return function(test, ctx)
  test("R5 regression: visible integrated pull stays within work and lifecycle budgets", function()
    Regression.Run(ctx, "visible")
  end)
  test("R5 regression: hidden integrated pull stays within work and lifecycle budgets", function()
    Regression.Run(ctx, "hidden")
  end)
  test("R5 regression: budget gates reject injected frame and protected-call amplification", function()
    for _, kind in ipairs({ "frames", "pcalls" }) do
      local ok, err = pcall(function()
        Regression.Run(ctx, "visible", function(session)
          local frame = session.runtime.eventFrame
          local original = frame:GetScript("OnEvent")
          frame:SetScript("OnEvent", function(self, event, ...)
            if event == "UNIT_AURA" then
              if kind == "frames" then
                CreateFrame("Frame")
              else
                pcall(function() end)
              end
            end
            original(self, event, ...)
          end)
        end)
      end)
      ctx.assert.False(ok, "injected amplification must fail its budget")
      ctx.assert.True(
        tostring(err):find(kind .. " exceeds budget", 1, true) ~= nil,
        "fail the relevant measured budget"
      )
    end
  end)
  test("R5 fixture: client event delivery respects registered unit filters", function()
    local globals, session = Stress.BuildGlobals(Fixture.buildGlobals)
    local player, party, broadcast = 0, 0, 0
    local frame = globals.CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_AURA", "player")
    frame:SetScript("OnEvent", function()
      player = player + 1
    end)
    frame = globals.CreateFrame("Frame")
    frame:RegisterUnitEvent("UNIT_AURA", "party1", "party2")
    frame:SetScript("OnEvent", function()
      party = party + 1
    end)
    frame = globals.CreateFrame("Frame")
    frame:RegisterEvent("UNIT_AURA")
    frame:SetScript("OnEvent", function()
      broadcast = broadcast + 1
    end)
    for _, unit in ipairs({ "player", "party1", "party2", "nameplate1" }) do
      session.DispatchToFrames("UNIT_AURA", unit)
    end
    ctx.assert.Equal(player, 1, "player-only frame receives one event")
    ctx.assert.Equal(party, 2, "party frame receives exactly its registered units")
    ctx.assert.Equal(broadcast, 4, "broadcast frame receives every unit event")
    frame:UnregisterAllEvents()
    session.DispatchToFrames("UNIT_AURA", "nameplate1")
    ctx.assert.Equal(broadcast, 4, "unregistered frames receive no further events")
  end)
end
