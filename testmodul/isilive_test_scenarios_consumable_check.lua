---@diagnostic disable: undefined-global

-- Rule 246 (K4 stage 1): ready-check consumable check. The real factory runs
-- in a party (stress helpers); READY_CHECK reaches the frames that registered
-- it and the card goes through the real ctx.ShowCenterNotice, which the test
-- only records on the way. Weapon enchants and own auras are client stubs.
local Fixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local Stress = dofile("testmodul/isilive_test_mplus_stress_helpers.lua")

local FixtureWithSchema = {
  buildGlobals = Fixture.buildGlobals,
  moduleFiles = function()
    local files = Fixture.moduleFiles()
    table.insert(files, 1, "isiLive_db_schema.lua")
    return files
  end,
}

local FOOD_ID = 461000

-- opts: { enabled, mainMs, offMs }
local function Prepare(opts)
  opts = opts or {}
  return function(globals, session)
    session.weapon = { opts.mainMs ~= nil, opts.mainMs, 0, 7495, opts.offMs ~= nil, opts.offMs, 0, 7495 }
    session.auras = {}
    globals.IsiLiveDB.consumableCheckEnabled = opts.enabled ~= false
    globals.GetWeaponEnchantInfo = function()
      return unpack(session.weapon, 1, 8)
    end
    globals.C_UnitAuras = globals.C_UnitAuras or {}
    globals.C_UnitAuras.GetPlayerAuraBySpellID = function(spellID)
      return session.auras[spellID]
    end
  end
end

-- Records every card on its way through the real ShowCenterNotice.
local function RecordCards(session)
  local cards = {}
  local original = session.runtime.ShowCenterNotice
  session.runtime.ShowCenterNotice = function(message, seconds, dungeonName, activityID, options)
    cards[#cards + 1] = { seconds = seconds, options = options }
    return original(message, seconds, dungeonName, activityID, options)
  end
  return cards
end

local function ReadyCheck(session)
  session.DispatchToFrames("READY_CHECK", "Tester", 35)
end

local function FieldText(card)
  local parts = {}
  for _, field in ipairs(card.options.fields) do
    parts[#parts + 1] = field.label .. " " .. field.value .. (field.warning and " !" or "")
  end
  return table.concat(parts, " | ")
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Consumable check shows a card on a ready check when weapon oil is missing or ends soon", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      local cards = RecordCards(session)
      ReadyCheck(session)
      Assert.Equal(#cards, 1, "a missing main-hand oil shows one card")
      Assert.Equal(cards[1].seconds, 25, "for 25 seconds")
      Assert.Equal(cards[1].options.title, "isiLive - Consumables", "the consumables card")
      Assert.Equal(FieldText(cards[1]), "Weapon oil (main hand): missing !", "the missing oil is a warning row")

      session.weapon = { true, 5 * 60000, 0, 7495, true, 45 * 60000, 0, 7495 }
      ReadyCheck(session)
      Assert.Equal(
        FieldText(cards[2]),
        "Weapon oil (main hand): 5 min left ! | Weapon oil (off hand): 45 min left",
        "an oil ending within 10 minutes is flagged, the other one listed"
      )

      session.weapon = { true, 50 * 60000, 0, 7495, false, nil, 0, nil }
      ReadyCheck(session)
      Assert.Equal(#cards, 2, "everything fine: no card, and no off hand without oil is a finding")
    end, Prepare())
  end)

  test("Consumable check uses the season's buff IDs and stays quiet in combat or when off", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      local seasonID = session.addon.SeasonData.GetActiveSeasonID()
      session.addon.ConsumableData.seasons[seasonID] = { food = { FOOD_ID } }
      local cards = RecordCards(session)
      ReadyCheck(session)
      Assert.Equal(FieldText(cards[1]), "Weapon oil (main hand): 60 min left | Food: missing !", "food without buff")
      session.auras[FOOD_ID] = { spellId = FOOD_ID, expirationTime = 0 }
      ReadyCheck(session)
      Assert.Equal(#cards, 1, "food present and oil fine: no card")

      session.auras[FOOD_ID] = nil
      session.combat = true
      ReadyCheck(session)
      Assert.Equal(#cards, 1, "no check during combat")
    end, Prepare({ mainMs = 60 * 60000 }))

    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      local cards = RecordCards(session)
      ReadyCheck(session)
      Assert.Equal(#cards, 0, "switched off: no card")
    end, Prepare({ enabled = false }))
  end)
end
