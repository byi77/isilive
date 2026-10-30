---@diagnostic disable: undefined-global

-- Branch-coverage scenarios for game/isiLive_teleport.lua. The main
-- isilive_test_scenarios_teleport.lua file boots the real season_data
-- and exercises the happy paths (number-mapped spells, deDE locale,
-- alias resolution). This file targets the still-uncovered defensive
-- branches by seeding tiny SeasonData / SpellUtils stubs directly into
-- addonTable so the loader does not pull in the production season data.

local function NewCreateFrameStub()
  local frames = {}
  return function(_frameType)
    local frame = {
      _events = {},
      _scripts = {},
    }
    function frame:RegisterEvent(event)
      self._events[event] = true
    end
    function frame:UnregisterEvent(event)
      self._events[event] = nil
    end
    function frame:IsEventRegistered(event)
      return self._events[event] == true
    end
    function frame:SetScript(name, fn)
      self._scripts[name] = fn
    end
    function frame:FireEvent(event)
      local handler = self._scripts.OnEvent
      if handler then
        handler(self, event)
      end
    end
    table.insert(frames, frame)
    return frame
  end,
    frames
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  -- WithTeleport seeds SeasonData / SpellUtils with the supplied stubs
  -- (so we can exercise table-mapped spells, missing C_LFGList, and the
  -- MAP_SHORT_CODES fallback) and runs `body(addon, frames)` while the
  -- WoW-API stubs are still installed in _G. Tests that hit
  -- C_LFGList / C_Spell / InCombatLockdown at call time MUST use this
  -- helper instead of LoadTeleport, otherwise WithGlobals strips the
  -- stubs back to nil after the loader returns.
  local function WithTeleport(stubs, body)
    stubs = stubs or {}
    local createFrame, frames = NewCreateFrameStub()
    local seed = {}
    seed.SeasonData = stubs.SeasonData or {}
    seed.SpellUtils = stubs.SpellUtils or {
      IsSpellKnownSafe = function()
        return false
      end,
    }
    WithGlobals({
      CreateFrame = createFrame,
      C_LFGList = stubs.C_LFGList,
      C_Spell = stubs.C_Spell,
      C_ChallengeMode = stubs.C_ChallengeMode,
      InCombatLockdown = stubs.InCombatLockdown,
      GetLocale = stubs.GetLocale,
    }, function()
      local addon = LoadAddonModules({ "isiLive_teleport.lua" }, seed)
      body(addon, frames)
    end)
  end

  -- LoadTeleport is the older shape kept for tests that don't read any
  -- WoW global at call time; it loads the module under the same stubs
  -- and then returns the addon table after WithGlobals tore the stubs
  -- back down. Used only for non-API resolver branches (MAP_TO_TELEPORT
  -- fallback, table-mapped spell IDs, ApplySecureSpellToButton input
  -- guards, BuildTeleportEntries ordering).
  local function LoadTeleport(stubs)
    local capturedAddon, capturedFrames
    WithTeleport(stubs, function(addon, frames)
      capturedAddon, capturedFrames = addon, frames
    end)
    return capturedAddon, capturedFrames
  end

  -- GetMapToTeleport: SeasonData.MAP_TO_TELEPORT fallback ----------------------

  test("ResolveTeleportSpellIDByMapID falls back to SeasonData.MAP_TO_TELEPORT", function()
    local addon = LoadTeleport({
      SeasonData = {
        MAP_TO_TELEPORT = { [501] = 12345 },
      },
    })
    Assert.Equal(addon.Teleport.ResolveTeleportSpellIDByMapID(501), 12345, "must use MAP_TO_TELEPORT fallback")
  end)

  test("ResolveTeleportSpellIDByMapID returns nil for unknown map", function()
    local addon = LoadTeleport({
      SeasonData = {
        MAP_TO_TELEPORT = { [501] = 12345 },
      },
    })
    Assert.Nil(addon.Teleport.ResolveTeleportSpellIDByMapID(9999), "unknown mapID must yield nil")
  end)

  -- ResolveMappedSpellID: table-form mapped, no known spell ---------------------

  test("ResolveMapIDsBySpellID handles table-form mapped IDs (table -> first candidate fallback)", function()
    -- Two candidate spells, none are known -> ResolveMappedSpellID returns
    -- firstCandidate. CollectMapIDsForSpell iterates and matches against
    -- both candidates via IterateMappedSpellIDs (the table-form branch).
    local addon = LoadTeleport({
      SeasonData = {
        MAP_TO_TELEPORT = { [200] = { 111, 222 } },
      },
    })
    local mapIDs = addon.Teleport.ResolveMapIDsBySpellID(222)
    Assert.NotNil(mapIDs, "table-mapped spellID must resolve")
    Assert.Equal(#mapIDs, 1, "exactly one map should match")
    Assert.Equal(mapIDs[1], 200, "matched map id must be 200")
  end)

  test("ResolveMappedSpellID picks the first known spell from a table-mapped list", function()
    local known = { [222] = true }
    local addon = LoadTeleport({
      SeasonData = {
        MAP_TO_TELEPORT = { [300] = { 111, 222, 333 } },
      },
      SpellUtils = {
        IsSpellKnownSafe = function(spellID)
          return known[spellID] == true
        end,
      },
    })
    Assert.Equal(addon.Teleport.ResolveTeleportSpellIDByMapID(300), 222, "first known spellID must win")
  end)

  -- ResolveMapIDsBySpellID / ResolveMapIDBySpellID edge cases ------------------

  test("ResolveMapIDsBySpellID returns nil when no map matches", function()
    local addon = LoadTeleport({
      SeasonData = {
        MAP_TO_TELEPORT = { [101] = 555 },
      },
    })
    Assert.Nil(addon.Teleport.ResolveMapIDsBySpellID(999), "unmatched spell must yield nil")
  end)

  test("ResolveMapIDsBySpellID returns nil for non-numeric spell input", function()
    local addon = LoadTeleport({
      SeasonData = {
        MAP_TO_TELEPORT = { [101] = 555 },
      },
    })
    Assert.Nil(addon.Teleport.ResolveMapIDsBySpellID("not-a-number"), "non-numeric must yield nil")
  end)

  test("ResolveMapIDBySpellID returns the first map id from the resolved list", function()
    local addon = LoadTeleport({
      SeasonData = {
        MAP_TO_TELEPORT = { [10] = 1, [20] = 1 },
      },
    })
    Assert.Equal(addon.Teleport.ResolveMapIDBySpellID(1), 10, "first map (sorted) must win")
  end)

  test("ResolveMapIDBySpellID returns nil when ResolveMapIDsBySpellID yields nil", function()
    local addon = LoadTeleport({
      SeasonData = { MAP_TO_TELEPORT = {} },
    })
    Assert.Nil(addon.Teleport.ResolveMapIDBySpellID(999), "no candidates must yield nil")
  end)

  -- ResolveMapIDByActivityID: defensive returns --------------------------------

  test("ResolveMapIDByActivityID returns nil for non-positive activity id", function()
    local addon = LoadTeleport({})
    Assert.Nil(addon.Teleport.ResolveMapIDByActivityID(0), "zero activityID must yield nil")
    Assert.Nil(addon.Teleport.ResolveMapIDByActivityID(-5), "negative activityID must yield nil")
    Assert.Nil(addon.Teleport.ResolveMapIDByActivityID("not-a-number"), "non-numeric activityID must yield nil")
  end)

  test("ResolveMapIDByActivityID returns nil when C_LFGList is missing", function()
    local addon = LoadTeleport({}) -- C_LFGList stays nil through WithGlobals
    Assert.Nil(addon.Teleport.ResolveMapIDByActivityID(123), "no C_LFGList must yield nil")
  end)

  test("ResolveMapIDByActivityID returns nil when GetActivityInfoTable raises", function()
    WithTeleport({
      C_LFGList = {
        GetActivityInfoTable = function()
          error("boom")
        end,
      },
    }, function(addon)
      Assert.Nil(addon.Teleport.ResolveMapIDByActivityID(123), "pcall failure must yield nil")
    end)
  end)

  test("ResolveMapIDByActivityID returns nil when activityInfo is not a table", function()
    WithTeleport({
      C_LFGList = {
        GetActivityInfoTable = function()
          return false
        end,
      },
    }, function(addon)
      Assert.Nil(addon.Teleport.ResolveMapIDByActivityID(123), "non-table info must yield nil")
    end)
  end)

  test("ResolveMapIDByActivityID accepts the snake-case mapId field", function()
    WithTeleport({
      SeasonData = {
        GetMapIDByInstanceID = function(instanceID)
          return instanceID == 777 and 501 or nil
        end,
      },
      C_LFGList = {
        GetActivityInfoTable = function()
          return { mapId = 777 } -- WoW-style alternate casing
        end,
      },
    }, function(addon)
      Assert.Equal(addon.Teleport.ResolveMapIDByActivityID(123), 501, "mapId fallback must resolve")
    end)
  end)

  -- ResolveTeleportSpellByActivityID -------------------------------------------

  test("ResolveTeleportSpellByActivityID returns nil for non-positive activity", function()
    local addon = LoadTeleport({})
    Assert.Nil(addon.Teleport.ResolveTeleportSpellByActivityID(0), "zero must yield nil")
    Assert.Nil(addon.Teleport.ResolveTeleportSpellByActivityID(-1), "negative must yield nil")
  end)

  -- GetTeleportInfoByMapID -----------------------------------------------------

  test("GetTeleportInfoByMapID returns nil for non-numeric mapID", function()
    local addon = LoadTeleport({})
    Assert.Nil(addon.Teleport.GetTeleportInfoByMapID("not-a-number"), "non-numeric must yield nil")
  end)

  test("GetTeleportInfoByMapID returns nil when no spell is mapped", function()
    local addon = LoadTeleport({
      SeasonData = { MAP_TO_TELEPORT = {} },
    })
    Assert.Nil(addon.Teleport.GetTeleportInfoByMapID(123), "no mapping must yield nil")
  end)

  test("GetTeleportInfoByMapID falls back to question-mark icon when C_Spell is missing", function()
    local addon = LoadTeleport({
      SeasonData = { MAP_TO_TELEPORT = { [42] = 999 } },
    })
    local info = addon.Teleport.GetTeleportInfoByMapID(42)
    Assert.NotNil(info, "info must be returned")
    Assert.Equal(info.icon, "Interface\\Icons\\INV_Misc_QuestionMark", "fallback icon must be used without C_Spell")
  end)

  -- GetDungeonShortCode --------------------------------------------------------

  test("GetDungeonShortCode returns nil for non-numeric mapID", function()
    local addon = LoadTeleport({
      SeasonData = { MAP_SHORT_CODES = { [1] = "X" } },
    })
    Assert.Nil(addon.Teleport.GetDungeonShortCode("nope"), "non-numeric must yield nil")
  end)

  test("GetDungeonShortCode falls back to MAP_SHORT_CODES table", function()
    local addon = LoadTeleport({
      SeasonData = {
        -- No GetDungeonShortCode function -> fallback to MAP_SHORT_CODES.
        MAP_SHORT_CODES = { [501] = "ABC" },
      },
    })
    Assert.Equal(addon.Teleport.GetDungeonShortCode(501), "ABC", "MAP_SHORT_CODES fallback must hit")
  end)

  test("GetDungeonShortCode returns nil when MAP_SHORT_CODES has no entry", function()
    local addon = LoadTeleport({
      SeasonData = { MAP_SHORT_CODES = {} },
    })
    Assert.Nil(addon.Teleport.GetDungeonShortCode(501), "missing short code must yield nil")
  end)

  -- GetDungeonName -------------------------------------------------------------

  test("GetDungeonName returns nil for non-numeric mapID", function()
    local addon = LoadTeleport({})
    Assert.Nil(addon.Teleport.GetDungeonName("nope"), "non-numeric must yield nil")
  end)

  -- ApplySecureSpellToButton ---------------------------------------------------

  test("ApplySecureSpellToButton returns false for missing button or spellID", function()
    local addon = LoadTeleport({})
    Assert.False(addon.Teleport.ApplySecureSpellToButton(nil, 123), "no button must return false")
    Assert.False(addon.Teleport.ApplySecureSpellToButton({}, nil), "no spellID must return false")
  end)

  -- BuildTeleportEntries: orderedMapIDs fallbacks ------------------------------

  test("BuildTeleportEntries derives ordered map IDs when SeasonData has none", function()
    -- SeasonData has no GetOrderedMapIDs and no displayOrder, so the
    -- function must build the ordered list itself from MAP_TO_TELEPORT.
    local addon = LoadTeleport({
      SeasonData = {
        MAP_TO_TELEPORT = { [3] = 11, [1] = 22, [2] = 33 },
      },
    })
    local entries = addon.Teleport.BuildTeleportEntries()
    Assert.Equal(#entries, 3, "must produce one entry per mapped spell")
    -- Entries are produced in the sorted order of mapIDs.
    Assert.Equal(entries[1].mapID, 1, "first entry must be lowest mapID")
    Assert.Equal(entries[2].mapID, 2, "second entry must be next mapID")
    Assert.Equal(entries[3].mapID, 3, "third entry must be highest mapID")
  end)

  test("BuildTeleportEntries fills empty SeasonData.GetOrderedMapIDs result with MAP_TO_TELEPORT keys", function()
    local addon = LoadTeleport({
      SeasonData = {
        MAP_TO_TELEPORT = { [10] = 100, [20] = 200 },
        GetOrderedMapIDs = function()
          return {} -- explicit empty table -> fallback path
        end,
      },
    })
    local entries = addon.Teleport.BuildTeleportEntries()
    Assert.Equal(#entries, 2, "must fall back to MAP_TO_TELEPORT keys when GetOrderedMapIDs is empty")
  end)

  -- Combat retry frame: OnEvent early returns ----------------------------------

  test("Combat retry frame OnEvent ignores non-PLAYER_REGEN_ENABLED events", function()
    local addon, frames = LoadTeleport({
      SeasonData = { MAP_TO_TELEPORT = {} },
    })
    Assert.NotNil(addon, "module must load")
    Assert.True(#frames >= 1, "combat retry frame must be created")
    -- Firing an unrelated event must not crash and must not touch the
    -- (empty) pending queue.
    frames[1]:FireEvent("SOME_OTHER_EVENT")
  end)

  test("Combat retry frame OnEvent is a no-op when pending queue is empty", function()
    local _, frames = LoadTeleport({
      SeasonData = { MAP_TO_TELEPORT = {} },
    })
    -- Pending queue starts empty -> first branch of OnEvent returns early.
    frames[1]:FireEvent("PLAYER_REGEN_ENABLED")
  end)
end
