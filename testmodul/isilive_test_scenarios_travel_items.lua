---@diagnostic disable: undefined-global

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function ToSet(list)
    local set = {}
    for _, value in ipairs(list or {}) do
      set[value] = true
    end
    return set
  end

  -- Expected gates, taken over unchanged from the former per-toy functions.
  local COVENANT_TOYS = {
    { toyID = 184353, covenantID = 1, renownCriteria = 1 }, -- Kyrian
    { toyID = 183716, covenantID = 2, renownCriteria = 4 }, -- Venthyr
    { toyID = 180290, covenantID = 3, renownCriteria = 3 }, -- Night Fae
    { toyID = 182773, covenantID = 4, renownCriteria = 2 }, -- Necrolord
  }
  local DRAENIC_HOLOGEM = 210455

  local function CollectWith(state)
    local owned
    WithGlobals({
      UnitExists = function()
        return true
      end,
      PlayerHasToy = function()
        return true
      end,
      GetAchievementCriteriaInfo = function(achievementID, criteriaIndex)
        local completed = achievementID == 15646 and criteriaIndex == state.completedCriteria
        return nil, nil, completed
      end,
      C_Covenants = {
        GetActiveCovenantID = function()
          return state.activeCovenantID or 0
        end,
      },
      UnitRace = function()
        return nil, nil, state.raceID or 1
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_game_menu_travel.lua" })
      owned = ToSet(addon.UIGameMenuTravel.CollectOwnedHearthstoneToys())
    end)
    return owned
  end

  test("Travel requires blocks keep the covenant gate per toy for active covenant and renown criteria", function()
    for _, expected in ipairs(COVENANT_TOYS) do
      local byCovenant = CollectWith({ activeCovenantID = expected.covenantID })
      local byCriteria = CollectWith({ completedCriteria = expected.renownCriteria })
      for _, other in ipairs(COVENANT_TOYS) do
        local unlocked = other.toyID == expected.toyID
        Assert.Equal(
          byCovenant[other.toyID] == true,
          unlocked,
          string.format("active covenant %d must unlock only toy %d", expected.covenantID, expected.toyID)
        )
        Assert.Equal(
          byCriteria[other.toyID] == true,
          unlocked,
          string.format("renown criteria %d must unlock only toy %d", expected.renownCriteria, expected.toyID)
        )
      end
    end
    local none = CollectWith({})
    for _, expected in ipairs(COVENANT_TOYS) do
      Assert.Nil(none[expected.toyID], "covenant toy without verified access must stay hidden")
    end
    Assert.True(none[64488] == true, "ungated owned toys must stay in the pool")
  end)

  test("Travel requires blocks keep the Draenic Hologem race gate", function()
    Assert.True(CollectWith({ raceID = 11 })[DRAENIC_HOLOGEM] == true, "Draenei must unlock the Draenic Hologem")
    Assert.True(CollectWith({ raceID = 30 })[DRAENIC_HOLOGEM] == true, "Lightforged must unlock the Draenic Hologem")
    Assert.Nil(CollectWith({ raceID = 1 })[DRAENIC_HOLOGEM], "other races must not unlock the Draenic Hologem")
  end)

  test("Travel hearthstone selection resolves explicit, random and default choices from one place", function()
    local owned = { [64488] = true, [93672] = true }
    WithGlobals({
      PlayerHasToy = function(itemID)
        return owned[itemID] == true
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_game_menu_travel.lua" })
      local resolve = addon.UIGameMenuTravel.ResolveHearthstoneSelection

      local explicitToy = resolve("toy:64488")
      Assert.True(explicitToy.isExplicit, "an owned toy choice is explicit")
      Assert.Equal(explicitToy.type, "toy", "explicit toy binds a toy action")
      Assert.Equal(explicitToy.value, 64488, "explicit toy binds the chosen toy")
      Assert.Equal(explicitToy.pool[1], 64488, "explicit toy pool holds only the chosen toy")

      local explicitItem = resolve("item:6948")
      Assert.True(explicitItem.isExplicit, "the default item choice is explicit")
      Assert.Equal(explicitItem.type, "item", "explicit item binds an item action")
      Assert.Equal(explicitItem.value, "item:6948", "explicit item binds the default hearthstone")
      Assert.Nil(explicitItem.pool, "explicit item has no toy pool")

      local unknownToy = resolve("toy:99999")
      Assert.False(unknownToy.isExplicit, "an unknown toy choice falls back to the random pool")
      Assert.Equal(unknownToy.type, "toy", "fallback random pool binds a toy")

      local reroll = resolve("random", { pool = { 64488, 93672 }, current = 64488 })
      Assert.Equal(reroll.value, 93672, "a re-roll avoids the current toy")
      Assert.Equal(#reroll.pool, 2, "a non-empty cached pool is reused")

      owned = {}
      local empty = resolve("random")
      Assert.False(empty.isExplicit, "random without owned toys is not explicit")
      Assert.Equal(empty.type, "item", "random without owned toys binds the default item")
      Assert.Equal(empty.value, "item:6948", "random without owned toys binds the default hearthstone")
      Assert.Nil(empty.pool, "random without owned toys has no pool")
    end)
  end)

  local function LoadTravelGate()
    local chunk = assert(loadfile("tools/check_travel_items.lua"))
    return chunk()
  end

  local function WriteFixture(path, content)
    local file = assert(io.open(path, "wb"))
    file:write(content)
    file:close()
  end

  local VALID_DATA = [[
local _, addonTable = ...
addonTable.TravelItemManifest = {
  covenantRenownAchievementID = 15646,
  defaultHearthstoneItemID = 6948,
  defaultHearthstoneVerification = { status = "legacy", source = "test" },
  dalaranHearthstoneToyID = 140192,
  dalaranHearthstoneVerification = { status = "legacy", source = "test" },
  arcantinaKeyItemID = 253629,
  arcantinaKeyVerification = { status = "legacy", source = "test" },
  hearthstoneToys = {
    { id = 64488, englishName = "The Innkeeper's Daughter", verification = { status = "legacy", source = "test" } },
    {
      id = 111111,
      englishName = "Fixture Hearthstone",
      requires = REQUIRES,
      verification = { status = "verified", source = "fixture", verifiedAt = "2026-10-20" },
    },
  },
  mountSpells = { repair = { spellID = 122708, verification = { status = "legacy", source = "test" } } },
}
]]

  local function Intake(toyRows)
    return "# Reise-Intake\n\n## Ruhestein-Intake\n\n"
      .. "| Patch | Name | ToyID | Source | VerifiedAt | Status | Notiz |\n"
      .. "| --- | --- | --- | --- | --- | --- | --- |\n"
      .. toyRows
      .. "\n## Mount-Intake\n\n| Patch | Name | SpellID | Source | VerifiedAt | Status | Notiz |\n"
      .. "| --- | --- | --- | --- | --- | --- | --- |\n"
      .. "| unresolved | unresolved | unresolved | unresolved | unresolved | unresolved | test |\n"
  end

  local VERIFIED_ROW = "| 12.0.5 | Fixture Hearthstone | 111111 | fixture | 2026-10-20 | verified | test |\n"

  local function RunGate(requires, toyRows)
    local dataPath = "tools/cache/test_travel_items_data.lua"
    local intakePath = "tools/cache/test_travel_items_intake.md"
    WriteFixture(dataPath, (VALID_DATA:gsub("REQUIRES", requires)))
    WriteFixture(intakePath, Intake(toyRows))
    return LoadTravelGate().Check({ dataPath = dataPath, intakePath = intakePath })
  end

  test("Travel items gate accepts the shipped data file and intake", function()
    local ok, result = LoadTravelGate().Check({})
    Assert.True(ok, "shipped travel items must pass the gate: " .. tostring(result.summary))
    Assert.True(result.counts.verified >= 1, "the verified Arcantina key must be counted")
  end)

  test("Travel items gate cross-checks verified data entries against verified intake rows", function()
    local ok = RunGate("{ raceIDs = { 11 } }", VERIFIED_ROW)
    Assert.True(ok, "matching verified data entry and intake row must pass")

    local okMissingRow, missingRow = RunGate("{ raceIDs = { 11 } }", "")
    Assert.False(okMissingRow, "a verified data entry without intake row must fail")
    Assert.True(
      missingRow.summary:find("has no verified intake row", 1, true) ~= nil,
      "the failure must name the missing intake row"
    )

    local okDrift, drift = RunGate(
      "{ raceIDs = { 11 } }",
      VERIFIED_ROW .. "| 12.0.5 | Ghost | 222222 | fixture | 2026-10-20 | verified | test |\n"
    )
    Assert.False(okDrift, "a verified intake row without data entry must fail")
    Assert.True(drift.summary:find("missing from the data file", 1, true) ~= nil, "the failure must name the drift")

    local okSource, noSource =
      RunGate("{ raceIDs = { 11 } }", "| 12.0.5 | Fixture | 111111 | unresolved | unresolved | candidate | test |\n")
    Assert.False(okSource, "a candidate row without source must fail")
    Assert.True(noSource.summary:find("without Source", 1, true) ~= nil, "the failure must name the missing source")
  end)

  test("Travel items gate rejects malformed requires blocks", function()
    local okMixed, mixed = RunGate("{ covenantID = 1, renownCriteria = 1, raceIDs = { 11 } }", VERIFIED_ROW)
    Assert.False(okMixed, "mixed covenant and race requirements must fail")
    Assert.True(mixed.summary:find("requires exactly one of", 1, true) ~= nil, "the failure must name the shape")

    local okUnknown, unknown = RunGate("{ raceIDs = { 11 }, faction = 1 }", VERIFIED_ROW)
    Assert.False(okUnknown, "unknown requires keys must fail")
    Assert.True(unknown.summary:find("unknown requires key", 1, true) ~= nil, "the failure must name the key")
  end)

  test("Settings hearthstone option builder uses the client toy name for a French addon on a French client", function()
    local function BuildFor(addonLocale, clientLocale)
      local options
      WithGlobals({
        GetLocale = function()
          return clientLocale
        end,
        C_ToyBox = {
          GetToyInfo = function(itemID)
            return itemID, "Pierre de foyer des Faë nocturnes", nil
          end,
        },
      }, function()
        local addon = LoadAddonModules({ "isiLive_settings_hearthstone.lua" }, {
          UI = {
            CollectOwnedHearthstoneToys = function()
              return { 180290 }
            end,
            GetHearthstoneToyEnglishName = function()
              return "Night Fae Hearthstone"
            end,
          },
        })
        options = addon.SettingsHearthstone.BuildOptions({
          getCurrentLocale = function()
            return addonLocale
          end,
        }, {})
      end)
      for _, option in ipairs(options) do
        if option.value == "toy:180290" then
          return option.fallback
        end
      end
      return nil
    end

    Assert.Equal(
      BuildFor("frFR", "frFR"),
      "Pierre de foyer des Faë nocturnes",
      "frFR addon on frFR client uses the API"
    )
    Assert.Equal(BuildFor("frFR", "deDE"), "Night Fae Hearthstone", "frFR addon on deDE client uses the English name")
    Assert.Equal(
      BuildFor("enUS", "enGB"),
      "Pierre de foyer des Faë nocturnes",
      "enGB client resolves to the enUS addon language"
    )
  end)

  test("Travel item manifest drives the mount strip spell IDs", function()
    local addon = LoadAddonModules({ "isiLive_ui_game_menu_mounts.lua" })
    local spells = addon.TravelItemManifest.mountSpells
    local byID = {}
    for _, entry in ipairs(addon.UIGameMenuMounts.MOUNT_PANEL_UI_ENTRIES) do
      byID[entry.id] = entry.spellID
    end
    Assert.Equal(byID.favorite_mount, spells.randomFavorite.spellID, "favorite mount spell comes from the manifest")
    Assert.Equal(byID.auction_house_mount, spells.auctionHouse.spellID, "AH mount spell comes from the manifest")
    Assert.Equal(byID.repair_mount, spells.repair.spellID, "repair mount spell comes from the manifest")
  end)
end
