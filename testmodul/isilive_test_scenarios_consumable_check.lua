---@diagnostic disable: undefined-global

-- Rule 246 (K4 stage 1): consumable check on dungeon entry. The real factory
-- runs in a party (stress helpers); PLAYER_ENTERING_WORLD reaches the frames
-- that registered it, the check waits for its delay on the simulated clock and
-- the card goes through the real ctx.ShowCenterNotice, which the test only
-- records on the way. Instance state, weapon enchants and own auras are
-- client stubs.
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
    session.inDungeon = false
    globals.IsInInstance = function()
      return session.inDungeon, session.inDungeon and "party" or "none"
    end
    globals.GetInstanceInfo = function()
      return session.inDungeon and "Windrunner Spire" or "Silvermoon"
    end
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

-- Walks out of the dungeon and back in (two loading screens) and lets the
-- check's delay pass.
local function EnterDungeon(session)
  session.inDungeon = false
  session.DispatchToFrames("PLAYER_ENTERING_WORLD", false, false)
  session.inDungeon = true
  session.DispatchToFrames("PLAYER_ENTERING_WORLD", false, false)
  session.Advance(2.5)
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

  test("Consumable check shows a card on dungeon entry when weapon oil is missing or ends soon", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      -- Weapon oil only: no season buff lists in this flow.
      session.addon.ConsumableData.sets = {}
      local cards = RecordCards(session)
      EnterDungeon(session)
      Assert.Equal(#cards, 1, "a missing main-hand oil shows one card")
      Assert.Equal(cards[1].seconds, 25, "for 25 seconds")
      Assert.Equal(cards[1].options.title, "isiLive - Consumables", "the consumables card")
      Assert.Equal(cards[1].options.eyebrow, "Windrunner Spire", "named after the dungeon")
      session.DispatchToFrames("PLAYER_ENTERING_WORLD", false, false)
      session.Advance(3)
      Assert.Equal(#cards, 1, "a loading screen inside the dungeon is no new entry")
      Assert.Equal(FieldText(cards[1]), "Weapon oil (main hand): missing !", "the missing oil is a warning row")

      session.weapon = { true, 35 * 60000, 0, 7495, true, 45 * 60000, 0, 7495 }
      EnterDungeon(session)
      Assert.Equal(
        FieldText(cards[2]),
        "Weapon oil (main hand): 35 min left ! | Weapon oil (off hand): 45 min left",
        "an oil ending within 40 minutes is flagged, one with 45 minutes is only listed"
      )

      session.weapon = { true, 50 * 60000, 0, 7495, false, nil, 0, nil }
      EnterDungeon(session)
      Assert.Equal(#cards, 2, "everything fine: no card, and no off hand without oil is a finding")
    end, Prepare())
  end)

  test("Consumable check finds a buff set for every season of the manifest", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      local data = session.addon.ConsumableData
      local seasons = session.addon.SeasonData.GetAvailableSeasonIDs()
      Assert.True(#seasons > 0, "the manifest lists seasons")
      for _, seasonID in ipairs(seasons) do
        Assert.NotNil(
          data.ResolveSet(seasonID),
          "a buff set for " .. tostring(seasonID) .. " (new expansion: add a set)"
        )
      end
      Assert.Equal(data.ResolveSet("midnight_s7"), data.sets.midnight, "a later season of the expansion needs no entry")
      Assert.Nil(data.ResolveSet("unknown_s1"), "an expansion without a set has none")
      local midnight = data.sets.midnight
      Assert.Equal(#midnight.food, 2, "Well Fed and Hearty Well Fed")
      Assert.Equal(#midnight.flask, 4, "one buff per Midnight flask stat")
      Assert.Equal(#midnight.augmentRune, 1, "the Midnight augment rune")

      local active = data.ResolveSet(session.addon.SeasonData.GetActiveSeasonID())
      session.auras[active.food[1]] = { spellId = active.food[1], expirationTime = 0 }
      session.auras[active.flask[3]] = { spellId = active.flask[3], expirationTime = 0 }
      session.auras[active.augmentRune[1]] = { spellId = active.augmentRune[1], expirationTime = 0 }
      local cards = RecordCards(session)
      EnterDungeon(session)
      Assert.Equal(#cards, 0, "food, any flask, rune and oil present: no card")
      session.auras[active.flask[3]] = nil
      EnterDungeon(session)
      Assert.True(FieldText(cards[1]):find("Flask: missing !", 1, true) ~= nil, "a missing flask is flagged")
    end, Prepare({ mainMs = 60 * 60000 }))
  end)

  test("Consumable check uses the season's buff IDs and stays quiet in combat, in a key or when off", function()
    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      local seasonID = session.addon.SeasonData.GetActiveSeasonID()
      session.addon.ConsumableData.sets.test = { food = { FOOD_ID } }
      session.addon.ConsumableData.seasonSets[seasonID] = "test"
      local cards = RecordCards(session)
      EnterDungeon(session)
      Assert.Equal(FieldText(cards[1]), "Weapon oil (main hand): 60 min left | Food: missing !", "food without buff")
      session.auras[FOOD_ID] = { spellId = FOOD_ID, expirationTime = 0 }
      EnterDungeon(session)
      Assert.Equal(#cards, 1, "food present and oil fine: no card")

      session.auras[FOOD_ID] = nil
      session.combat = true
      EnterDungeon(session)
      Assert.Equal(#cards, 1, "no check during combat")
      session.combat = false
      session.active = true
      EnterDungeon(session)
      Assert.Equal(#cards, 1, "no check when walking back into a running key")
    end, Prepare({ mainMs = 60 * 60000 }))

    Stress.WithParty(ctx, FixtureWithSchema, function(session)
      local cards = RecordCards(session)
      EnterDungeon(session)
      Assert.Equal(#cards, 0, "switched off: no card")
    end, Prepare({ enabled = false }))
  end)
end
