---@diagnostic disable: undefined-global

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  -- SetKickCellText branch coverage. Exposed via _RosterInternal because the
  -- function is local to the render module; its only observable surface is
  -- the cell:SetText side effect, which we capture with a stub cell.
  local function MakeCellStub()
    local cell = { texts = {} }
    cell.SetText = function(_, text)
      table.insert(cell.texts, text)
    end
    return cell
  end

  test("SetKickCellText writes dash for nil cell guard (no-op)", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    -- Must not throw on nil cell.
    RI.SetKickCellText(nil, { syncHasKick = true })
  end)

  test("SetKickCellText writes dash when info is missing or class lacks a kick", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local cell = MakeCellStub()

    RI.SetKickCellText(cell, nil)
    RI.SetKickCellText(cell, { syncHasKick = false })

    Assert.Equal(#cell.texts, 2, "two writes expected")
    Assert.Equal(cell.texts[1], "|cff666666-|r", "non-table info must render dash")
    Assert.Equal(cell.texts[2], "|cff666666-|r", "syncHasKick=false must render dash")
  end)

  test("SetKickCellText renders red countdown when interrupt is on cooldown with remaining seconds", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local cell = MakeCellStub()

    RI.SetKickCellText(cell, { syncHasKick = true, syncKickOnCooldown = true, syncKickRemain = 4.2 })

    Assert.Equal(cell.texts[1], "|cffff4040" .. "5s|r", "ceil(4.2) = 5; red color code")
  end)

  test("SetKickCellText renders dash when on cooldown but ceil(remain) hits zero", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local cell = MakeCellStub()

    RI.SetKickCellText(cell, { syncHasKick = true, syncKickOnCooldown = true, syncKickRemain = 0 })

    Assert.Equal(cell.texts[1], "|cff666666-|r", "zero remaining must collapse to dash")
  end)

  test("SetKickCellText renders compact green ready marker using locale string when available", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local cell = MakeCellStub()

    RI.SetKickCellText(cell, { syncHasKick = true, syncKickOnCooldown = false }, function()
      return { SYNC_KICK_READY_SHORT = "OK" }
    end)

    Assert.Equal(cell.texts[1], "|cff44ff44OK|r", "compact ready marker must render in green")
  end)

  test("SetKickCellText falls back to compact ready marker when getL returns no string", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local cell = MakeCellStub()

    RI.SetKickCellText(cell, { syncHasKick = true, syncKickOnCooldown = false })

    Assert.Equal(cell.texts[1], "|cff44ff44OK|r", "missing getL must fall back to compact ready marker")
  end)

  test("SetKickCellText renders dash when syncKickOnCooldown is unresolved (nil)", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local cell = MakeCellStub()

    RI.SetKickCellText(cell, { syncHasKick = true })

    Assert.Equal(cell.texts[1], "|cff666666-|r", "unresolved cooldown state must render dash")
  end)

  -- HasReadyCheckHoldInRoster branch coverage. Pure function over a state
  -- table + roster array; exposed via _RosterInternal.
  local function MakeReadyState(opts)
    opts = opts or {}
    return {
      buildOrderedRoster = opts.buildOrderedRoster or function(roster)
        return roster
      end,
      getTime = opts.getTime or function()
        return 100
      end,
      getReadyCheckReadyUntil = opts.getReadyCheckReadyUntil,
      getReadyCheckDeclinedUntil = opts.getReadyCheckDeclinedUntil,
    }
  end

  test("HasReadyCheckHoldInRoster returns false when getTime is missing", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local state = MakeReadyState({
      getTime = function()
        return nil
      end,
    })
    Assert.False(RI.HasReadyCheckHoldInRoster(state, { { unit = "party1" } }), "no time → no hold")
  end)

  test("HasReadyCheckHoldInRoster returns false when buildOrderedRoster is missing", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local state = {
      getTime = function()
        return 100
      end,
    }
    Assert.False(RI.HasReadyCheckHoldInRoster(state, {}), "no roster builder → no hold")
  end)

  test("HasReadyCheckHoldInRoster returns true when at least one unit's ready stamp is in the future", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local state = MakeReadyState({
      getReadyCheckReadyUntil = function(unit)
        return unit == "party2" and 150 or 0
      end,
    })
    local roster = { { unit = "party1" }, { unit = "party2" }, { unit = "" } }
    Assert.True(RI.HasReadyCheckHoldInRoster(state, roster), "one future ready stamp must trigger hold")
  end)

  test("HasReadyCheckHoldInRoster returns true when a unit has a future declined stamp", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local state = MakeReadyState({
      getReadyCheckDeclinedUntil = function(unit)
        return unit == "party3" and 200 or nil
      end,
    })
    Assert.True(
      RI.HasReadyCheckHoldInRoster(state, { { unit = "party3" } }),
      "future declined stamp must also count as hold"
    )
  end)

  test("HasReadyCheckHoldInRoster returns false when all stamps are stale", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local state = MakeReadyState({
      getReadyCheckReadyUntil = function()
        return 50
      end,
      getReadyCheckDeclinedUntil = function()
        return 80
      end,
    })
    Assert.False(
      RI.HasReadyCheckHoldInRoster(state, { { unit = "party1" }, { unit = "party2" } }),
      "all stamps in the past → no hold"
    )
  end)

  test("HasReadyCheckHoldInRoster ignores entries without a unit string", function()
    local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
    local RI = addon._RosterInternal
    local state = MakeReadyState({
      getReadyCheckReadyUntil = function()
        return 999
      end,
    })
    Assert.False(
      RI.HasReadyCheckHoldInRoster(state, { { unit = nil }, { unit = "" }, {} }),
      "entries without a unit must be skipped"
    )
  end)
end
