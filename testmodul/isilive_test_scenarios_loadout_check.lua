---@diagnostic disable: undefined-global, undefined-field

-- Deterministic scenarios for the pre-key talent / loot spec check
-- (game/isiLive_loadout_check.lua). Events go through the module's real
-- dispatcher (LoadoutCheck.HandleEvent); only the WoW API surface and the card
-- are stubbed. The default-API tests at the end drive the real Blizzard-facing
-- adapters through stubbed globals.

local FROST_MAGE = 64
local FIRE_MAGE = 63
local ARCANE_MAGE = 62
local MAP_ID = 525
local INSTANCE_ID = 2773

local function BuildWorld(opts)
  opts = opts or {}
  local world = {
    db = opts.db or {},
    specID = FROST_MAGE,
    specName = "Frost",
    specs = {
      { id = ARCANE_MAGE, name = "Arcane" },
      { id = FIRE_MAGE, name = "Fire" },
      { id = FROST_MAGE, name = "Frost" },
    },
    loadouts = {
      [FROST_MAGE] = {
        { id = 101, name = "M+ AoE" },
        { id = 102, name = "M+ Single" },
      },
    },
    selectedLoadoutID = 101,
    lootSpecID = 0,
    inCombat = false,
    inGroup = true,
    raid = false,
    challengeActive = false,
    dungeon = { mapID = MAP_ID, name = "Operation: Floodgate", instanceID = INSTANCE_ID },
    pending = {},
    loads = {},
    lootSets = {},
    printed = {},
    shows = {},
    hides = 0,
  }

  world.card = {
    Show = function(_, model, controller)
      world.shows[#world.shows + 1] = model
      world.cardController = controller
      world.cardShown = true
      return true
    end,
    Hide = function()
      world.hides = world.hides + 1
      world.cardShown = false
    end,
  }

  world.deps = {
    getDB = function()
      return world.db
    end,
    getL = function()
      return {}
    end,
    print = function(message)
      world.printed[#world.printed + 1] = message
    end,
    card = world.card,
    -- Remembering targets is off by default; the judged path stays covered here.
    rememberTargets = true,
    getCurrentSpec = function()
      return world.specID, world.specName
    end,
    getClassSpecs = function()
      return world.specs
    end,
    getSavedLoadouts = function(specID)
      return world.loadouts[specID] or {}
    end,
    getSelectedLoadoutID = function()
      return world.selectedLoadoutID
    end,
    loadLoadout = function(specID, configID)
      world.loads[#world.loads + 1] = { specID = specID, configID = configID }
      world.selectedLoadoutID = configID
      return true
    end,
    getLootSpecID = function()
      return world.lootSpecID
    end,
    setLootSpecID = function(specID)
      world.lootSets[#world.lootSets + 1] = specID
      world.lootSpecID = specID
      return true
    end,
    isInCombat = function()
      return world.inCombat
    end,
    getCharacterKey = function()
      return "Player-1-0000AAAA"
    end,
    isChallengeActive = function()
      return world.challengeActive
    end,
    isInGroup = function()
      return world.inGroup
    end,
    isRaidContext = function()
      return world.raid
    end,
    resolveSeasonDungeon = function()
      local dungeon = world.dungeon
      if not dungeon then
        return nil
      end
      return dungeon.mapID, dungeon.name, dungeon.instanceID
    end,
    after = function(_, callback)
      world.pending[#world.pending + 1] = callback
    end,
  }

  function world.FlushTimers()
    local pending = world.pending
    world.pending = {}
    for _, callback in ipairs(pending) do
      callback()
    end
  end

  function world.LastModel()
    return world.shows[#world.shows]
  end

  return world
end

local function RegisterLoadoutCheckTests(test, Assert, WithGlobals, LoadAddonModules)
  local function LoadModule()
    return LoadAddonModules({ "isiLive_loadout_check.lua" }).LoadoutCheck
  end

  local function Enter(LoadoutCheck, world)
    LoadoutCheck.HandleEvent("PLAYER_ENTERING_WORLD")
    world.FlushTimers()
  end

  local function StoreTarget(world, target)
    world.db.loadoutCheck = {
      ["Player-1-0000AAAA"] = {
        [FROST_MAGE] = {
          [MAP_ID] = target,
        },
      },
    }
  end

  test("LoadoutCheck shows the current state without a target and remembers it on confirm", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)

      Enter(LoadoutCheck, world)

      Assert.Equal(#world.shows, 1, "entering a season dungeon must show the card once")
      local model = world.LastModel()
      Assert.Equal(model.mapID, MAP_ID, "model must carry the resolved challenge map")
      Assert.Equal(model.dungeonName, "Operation: Floodgate", "model must carry the dungeon name")
      Assert.False(model.hasTarget, "no stored target means nothing is judged")
      Assert.False(model.allOk, "without a target the card must not claim all OK")
      Assert.Equal(model.talents.status, "unknown", "talent status must stay unknown without a target")
      Assert.Equal(model.loot.status, "unknown", "loot status must stay unknown without a target")
      Assert.Equal(model.talents.currentName, "M+ AoE", "current loadout name must come from the selected config")
      Assert.Equal(#model.talents.options, 2, "every saved loadout of the spec is offered")
      Assert.Equal(#model.loot.options, 4, "current-spec default plus every class spec is offered")
      Assert.True(model.loot.options[1].isCurrentSpec, "first loot option is the current-spec default")

      Assert.True(world.cardController.Confirm(), "confirm must store the current state")
      local stored = world.db.loadoutCheck["Player-1-0000AAAA"][FROST_MAGE][MAP_ID]
      Assert.Equal(stored.configID, 101, "confirm must store the selected loadout")
      Assert.Equal(stored.configName, "M+ AoE", "confirm must store the loadout name")
      Assert.Equal(stored.lootSpecID, 0, "confirm must store the loot spec as read")
      Assert.False(world.cardShown, "confirm must close the card")
    end)
  end)

  test("LoadoutCheck flags a different loadout and loot spec and switches both with one click", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      StoreTarget(world, { configID = 102, configName = "M+ Single", lootSpecID = FIRE_MAGE })
      LoadoutCheck.SetDependencies(world.deps)

      Enter(LoadoutCheck, world)

      local model = world.LastModel()
      Assert.True(model.hasTarget, "a stored target must be judged")
      Assert.False(model.allOk, "a different loadout must not be all OK")
      Assert.Equal(model.talents.status, "mismatch", "selected 101 against target 102 is a mismatch")
      Assert.Equal(model.talents.targetName, "M+ Single", "target name must come from the live loadout list")
      Assert.True(model.talents.options[2].target, "the target loadout option must be marked")
      Assert.True(model.talents.options[1].active, "the active loadout option must be marked")
      Assert.Equal(model.loot.status, "mismatch", "current-spec loot (Frost) against Fire is a mismatch")
      Assert.Equal(model.loot.targetName, "Fire", "loot target name must resolve")

      local controller = LoadoutCheck.GetController()
      Assert.True(controller.SelectLoadout(102), "a saved loadout must be loadable")
      Assert.Equal(world.loads[1].specID, FROST_MAGE, "the loadout must load for the current spec")
      Assert.Equal(world.loads[1].configID, 102, "the clicked loadout must be loaded")
      LoadoutCheck.HandleEvent("TRAIT_CONFIG_UPDATED")
      Assert.Equal(world.LastModel().talents.status, "ok", "after loading the target loadout talents are OK")

      Assert.True(controller.SelectLootSpec(FIRE_MAGE), "a class spec must be selectable as loot spec")
      Assert.Equal(world.lootSets[1], FIRE_MAGE, "the clicked loot spec must be applied")
      LoadoutCheck.HandleEvent("PLAYER_LOOT_SPEC_UPDATED")
      local fixed = world.LastModel()
      Assert.Equal(fixed.loot.status, "ok", "after switching the loot spec loot is OK")
      Assert.True(fixed.allOk, "with both fixed the card reports all OK")
    end)
  end)

  test("LoadoutCheck rejects unknown loadouts and loot specs and refuses switches in combat", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)
      local controller = LoadoutCheck.GetController()

      Assert.False(controller.SelectLoadout(999), "a config ID outside the spec's loadouts must be rejected")
      Assert.False(controller.SelectLootSpec(250), "a spec outside the class must be rejected")
      Assert.Equal(#world.loads, 0, "no load call for a rejected loadout")
      Assert.Equal(#world.lootSets, 0, "no loot call for a rejected spec")

      world.inCombat = true
      LoadoutCheck.HandleEvent("PLAYER_REGEN_DISABLED")
      Assert.True(world.LastModel().inCombat, "the card must learn about combat")
      Assert.False(controller.SelectLoadout(102), "loading talents in combat must be refused")
      Assert.False(controller.SelectLootSpec(FIRE_MAGE), "changing loot spec in combat must be refused")
      Assert.Equal(#world.loads, 0, "no load call in combat")
      Assert.Equal(#world.lootSets, 0, "no loot call in combat")
      Assert.Equal(#world.printed, 2, "each refused click explains itself in chat")
    end)
  end)

  test("LoadoutCheck treats loot spec 0 and the explicit current spec as the same loot", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local live = {
        specID = FROST_MAGE,
        specName = "Frost",
        loadouts = { { id = 101, name = "M+ AoE" } },
        selectedLoadoutID = 101,
        specs = { { id = FROST_MAGE, name = "Frost" }, { id = FIRE_MAGE, name = "Fire" } },
        lootSpecID = FROST_MAGE,
      }
      local model = LoadoutCheck.BuildModel(live, { configID = 101, lootSpecID = 0 })
      Assert.Equal(model.loot.status, "ok", "explicit Frost equals the current-spec default while Frost")
      Assert.True(model.allOk, "matching loadout and effective loot spec is all OK")

      live.lootSpecID = 0
      model = LoadoutCheck.BuildModel(live, { configID = 101, lootSpecID = FROST_MAGE })
      Assert.Equal(model.loot.status, "ok", "current-spec default equals explicit Frost while Frost")

      live.selectedLoadoutID = nil
      model = LoadoutCheck.BuildModel(live, { configID = 101, lootSpecID = 0 })
      Assert.Equal(model.talents.status, "mismatch", "starter build / no loadout against a target is a mismatch")
      Assert.Equal(model.talents.targetName, "M+ AoE", "target name resolves from the live list")
    end)
  end)

  test("LoadoutCheck stays silent outside a season dungeon, in a key, in a raid, solo or when disabled", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local cases = {
        {
          label = "outside a season dungeon",
          setup = function(world)
            world.dungeon = nil
          end,
        },
        {
          label = "running key",
          setup = function(world)
            world.challengeActive = true
          end,
        },
        {
          label = "raid",
          setup = function(world)
            world.raid = true
          end,
        },
        {
          label = "solo",
          setup = function(world)
            world.inGroup = false
          end,
        },
        {
          label = "disabled",
          setup = function(world)
            world.db.loadoutCheckEnabled = false
          end,
        },
      }
      for _, case in ipairs(cases) do
        local world = BuildWorld()
        case.setup(world)
        LoadoutCheck.SetDependencies(world.deps)
        Enter(LoadoutCheck, world)
        Assert.Equal(#world.shows, 0, "no card " .. case.label)
      end

      local world = BuildWorld()
      world.db.loadoutCheckEnabled = true
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)
      Assert.Equal(#world.shows, 1, "an explicit true setting still shows the card")
    end)
  end)

  test("LoadoutCheck shows once per instance entry, hides on key start and checks again after re-entry", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)

      Enter(LoadoutCheck, world)
      Assert.Equal(#world.shows, 1, "first entry shows the card")
      world.cardController.Dismiss()
      Assert.False(world.cardShown, "dismiss closes the card")
      Assert.Nil(world.db.loadoutCheck, "dismiss must not store a target")

      Enter(LoadoutCheck, world)
      Assert.Equal(#world.shows, 1, "a second world entry in the same instance must not show it again")
      LoadoutCheck.HandleEvent("TRAIT_CONFIG_UPDATED")
      Assert.Equal(#world.shows, 1, "trait updates after dismiss must not reopen the card")

      world.dungeon = nil
      Enter(LoadoutCheck, world)
      world.dungeon = { mapID = MAP_ID, name = "Operation: Floodgate", instanceID = INSTANCE_ID }
      Enter(LoadoutCheck, world)
      Assert.Equal(#world.shows, 2, "re-entering after leaving checks again")

      LoadoutCheck.HandleEvent("CHALLENGE_MODE_START")
      Assert.False(world.cardShown, "key start must close the card")
      LoadoutCheck.HandleEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
      Assert.Equal(#world.shows, 2, "after key start no event may reopen the card")
    end)
  end)

  test("LoadoutCheck ignores a stale entry timer and party spec changes", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)

      LoadoutCheck.HandleEvent("PLAYER_ENTERING_WORLD")
      LoadoutCheck.HandleEvent("PLAYER_ENTERING_WORLD")
      world.FlushTimers()
      Assert.Equal(#world.shows, 1, "only the latest entry timer evaluates")

      world.specID = FIRE_MAGE
      world.specName = "Fire"
      LoadoutCheck.HandleEvent("PLAYER_SPECIALIZATION_CHANGED", "party1")
      Assert.Equal(#world.shows, 1, "a party member's spec change must not refresh the card")
      LoadoutCheck.HandleEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
      Assert.Equal(#world.shows, 2, "the player's spec change refreshes the open card")
      Assert.Equal(world.LastModel().specID, FIRE_MAGE, "the refreshed card judges the new spec")
    end)
  end)

  test("LoadoutCheck prints one green chat line instead of the card when everything matches", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      StoreTarget(world, { configID = 101, configName = "M+ AoE", lootSpecID = FROST_MAGE })
      LoadoutCheck.SetDependencies(world.deps)

      Enter(LoadoutCheck, world)

      Assert.Equal(#world.shows, 0, "a full match must not show the card")
      Assert.Equal(#world.printed, 1, "a full match prints exactly one chat line")
      Assert.True(world.printed[1]:find("M+ AoE", 1, true) ~= nil, "the chat line names the loadout")
      Assert.True(world.printed[1]:find("Operation: Floodgate", 1, true) ~= nil, "the chat line names the dungeon")
      Assert.True(world.printed[1]:find("|cff33ff99", 1, true) == 1, "the chat line is green")
      Assert.False(LoadoutCheck.GetController().IsActive(), "no card state stays active")

      LoadoutCheck.HandleEvent("TRAIT_CONFIG_UPDATED")
      Enter(LoadoutCheck, world)
      Assert.Equal(#world.printed, 1, "the same instance entry does not repeat the chat line")
      Assert.Equal(#world.shows, 0, "the same instance entry does not show the card later")
    end)
  end)

  -- A talent switch whose commit only started: LoadConfig answers
  -- LoadInProgress, the selection moves only after the commit succeeded.
  local function WithPendingLoads(world)
    world.marked = {}
    world.deps.loadLoadout = function(specID, configID)
      world.loads[#world.loads + 1] = { specID = specID, configID = configID }
      return "pending"
    end
    world.deps.markLoadoutSelected = function(_, configID)
      world.marked[#world.marked + 1] = configID
      world.selectedLoadoutID = configID
    end
  end

  test("LoadoutCheck marks a talent switch selected only after its commit succeeded", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      WithPendingLoads(world)
      StoreTarget(world, { configID = 102, configName = "M+ Single", lootSpecID = 0 })
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)

      Assert.True(world.cardController.SelectLoadout(102), "the switch starts")
      local model = world.LastModel()
      Assert.Equal(model.talents.status, "pending", "a running commit is not judged yet")
      Assert.Equal(model.talents.pendingName, "M+ Single", "the card names the loadout being loaded")
      Assert.Equal(world.selectedLoadoutID, 101, "the old loadout stays selected while the commit runs")
      Assert.False(world.cardController.SelectLoadout(101), "no second switch while one commits")
      Assert.False(world.cardController.Confirm(), "confirming mid-switch would remember the old loadout")

      LoadoutCheck.HandleEvent("TRAIT_CONFIG_UPDATED")
      Assert.Equal(world.marked[1], 102, "the commit marks the new loadout selected")
      Assert.Equal(world.LastModel().talents.status, "ok", "after the commit the card judges the new loadout")
      world.FlushTimers()
      Assert.Equal(#world.marked, 1, "the timeout of a finished switch does nothing")
    end)
  end)

  test("LoadoutCheck finishes a talent switch whose commit event fires inside LoadConfig", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      WithPendingLoads(world)
      world.deps.loadLoadout = function(specID, configID)
        world.loads[#world.loads + 1] = { specID = specID, configID = configID }
        LoadoutCheck.HandleEvent("TRAIT_CONFIG_UPDATED")
        return "pending"
      end
      StoreTarget(world, { configID = 102, configName = "M+ Single", lootSpecID = 0 })
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)

      Assert.True(world.cardController.SelectLoadout(102), "the switch starts")
      Assert.Equal(world.marked[1], 102, "the early commit event still marks the loadout selected")
      Assert.Equal(world.LastModel().talents.status, "ok", "the card judges the new loadout at once")
      Assert.True(world.cardController.SelectLoadout(101), "no switch is left pending")
    end)
  end)

  test("LoadoutCheck reports an interrupted talent switch and keeps the old loadout", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      WithPendingLoads(world)
      StoreTarget(world, { configID = 102, configName = "M+ Single", lootSpecID = 0 })
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)

      world.cardController.SelectLoadout(102)
      LoadoutCheck.HandleEvent("CONFIG_COMMIT_FAILED")
      Assert.Equal(#world.marked, 0, "a failed commit selects nothing")
      Assert.True(world.printed[#world.printed]:find("M+ Single", 1, true) ~= nil, "the chat names the loadout")
      Assert.Equal(world.LastModel().talents.status, "mismatch", "the card shows the unchanged old loadout")
    end)
  end)

  test("LoadoutCheck counts a silent talent switch as done after the timeout", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      WithPendingLoads(world)
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)

      world.cardController.SelectLoadout(102)
      world.FlushTimers()
      Assert.Equal(world.marked[1], 102, "without any result event the switch counts as done")
      Assert.Equal(#world.printed, 0, "a silent switch reports nothing")
    end)
  end)

  test("LoadoutCheck writes [LOADOUT] runtime-log lines for entry, switches, commit and confirm", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      WithPendingLoads(world)
      local lines = {}
      world.deps.trace = function(buildMessage)
        lines[#lines + 1] = buildMessage()
      end
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)
      world.cardController.SelectLoadout(102)
      LoadoutCheck.HandleEvent("CONFIG_COMMIT_FAILED")
      world.cardController.SelectLootSpec(FIRE_MAGE)
      world.cardController.Confirm()

      Assert.Equal(
        lines[1],
        "[LOADOUT] event=evaluate mapID="
          .. MAP_ID
          .. " instanceID="
          .. INSTANCE_ID
          .. " spec="
          .. FROST_MAGE
          .. " loadout=M+ AoE loot=Frost result=card",
        "the entry logs dungeon, active loadout, loot spec and outcome"
      )
      Assert.Equal(lines[2], "[LOADOUT] event=select_loadout configID=102 result=pending pending=true", "switch start")
      Assert.Equal(
        lines[3],
        "[LOADOUT] event=commit configID=102 ok=false source=CONFIG_COMMIT_FAILED",
        "the commit result names its source"
      )
      Assert.Equal(lines[4], "[LOADOUT] event=select_loot lootSpecID=" .. FIRE_MAGE .. " ok=true", "loot switch")
      Assert.Equal(lines[5], "[LOADOUT] event=confirm mapID=" .. MAP_ID .. " remember=true", "confirm")
    end)
  end)

  test("LoadoutCheck by default shows the active state without remembering or judging", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      world.deps.rememberTargets = nil
      StoreTarget(world, { configID = 102, configName = "M+ Single", lootSpecID = FIRE_MAGE })
      LoadoutCheck.SetDependencies(world.deps)

      Enter(LoadoutCheck, world)
      local model = world.LastModel()
      Assert.NotNil(model, "the card shows on every dungeon entry")
      Assert.False(model.remembers, "the card knows nothing is remembered")
      Assert.Equal(model.talents.status, "unknown", "a stored target is not judged against")
      Assert.Equal(model.talents.currentName, "M+ AoE", "the active loadout is shown")

      local text = LoadoutCheck.GetSummary(MAP_ID)
      Assert.Equal(text, "Talents: M+ AoE · Loot: Current spec (Frost)", "the invite row names the active state")
      local subFields = LoadoutCheck.GetSummaryFields(MAP_ID)
      Assert.Equal(#subFields, 2, "one sub-row for the talents, one for the loot spec")
      Assert.Equal(subFields[1].label, "Talents:", "the talents label sits in the label column")
      Assert.Equal(subFields[1].value, "|cffffd659M+ AoE|r", "the active loadout name stands out in gold")
      Assert.Equal(subFields[2].label, "Loot:", "the loot label sits in the label column")
      Assert.Equal(subFields[2].value, "Current spec (Frost)", "the active loot spec, no verdict")
      Assert.False(subFields[1].warning or subFields[2].warning, "the active state is never a warning")

      local stored = world.db.loadoutCheck["Player-1-0000AAAA"][FROST_MAGE][MAP_ID]
      Assert.True(world.cardController.Confirm(), "OK closes the card")
      Assert.False(world.cardShown, "OK hides the card")
      Assert.True(
        world.db.loadoutCheck["Player-1-0000AAAA"][FROST_MAGE][MAP_ID] == stored,
        "OK stores nothing and leaves the stored data untouched"
      )
    end)
  end)

  test("LoadoutCheck summary for the accepted-invite card reports only judged parts", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)

      StoreTarget(world, { configID = 102, configName = "M+ Single", lootSpecID = FIRE_MAGE })
      local text, allOk = LoadoutCheck.GetSummary(MAP_ID)
      Assert.Equal(text, "Talents: M+ Single expected · Loot: Fire expected", "both mismatches name the target")
      Assert.False(allOk, "a mismatch is not all OK")

      StoreTarget(world, { configID = 101, configName = "M+ AoE", lootSpecID = 0 })
      text, allOk = LoadoutCheck.GetSummary(MAP_ID)
      Assert.Equal(text, "Talents OK · Loot OK", "matching parts read OK")
      Assert.True(allOk, "both matching is all OK")

      StoreTarget(world, { lootSpecID = ARCANE_MAGE })
      text = LoadoutCheck.GetSummary(MAP_ID)
      Assert.Equal(text, "Loot: Arcane expected", "an unjudged talent part is left out")

      world.db.loadoutCheckEnabled = false
      Assert.Nil(LoadoutCheck.GetSummary(MAP_ID), "the disabled setting hides the summary")
    end)
  end)

  test("LoadoutCheck summary field marks every part with its status icon at a glance", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)

      StoreTarget(world, { configID = 101, configName = "M+ AoE", lootSpecID = 0 })
      local subFields = LoadoutCheck.GetSummaryFields(MAP_ID)
      Assert.True(subFields[1].value:find("ReadyCheck-Ready", 1, true) ~= nil, "matching parts carry the ready icon")
      Assert.True(subFields[1].value:find("M+ AoE", 1, true) ~= nil, "a matching loadout names itself")
      Assert.False(subFields[1].warning or subFields[2].warning, "an all-OK block stays off the warning strip")

      StoreTarget(world, { configID = 102, configName = "M+ Single", lootSpecID = 0 })
      subFields = LoadoutCheck.GetSummaryFields(MAP_ID)
      Assert.True(subFields[1].value:find("NotReady", 1, true) ~= nil, "a mismatch carries the not-ready icon")
      Assert.True(subFields[1].warning, "a mismatch puts only its own sub-row on the warning strip")
      Assert.False(subFields[2].warning, "the matching loot sub-row stays plain")

      world.db.loadoutCheck = nil
      subFields = LoadoutCheck.GetSummaryFields(MAP_ID)
      Assert.Nil(subFields[1].value:find("ReadyCheck", 1, true), "an unjudged state carries no status icon")

      world.db.loadoutCheckEnabled = false
      Assert.Nil(LoadoutCheck.GetSummaryFields(MAP_ID), "the disabled setting hides the block")
    end)
  end)

  test("LoadoutCheck invite summary shows the unjudged state without any target for the spec", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)

      local text, allOk = LoadoutCheck.GetSummary(MAP_ID)
      Assert.Equal(
        text,
        "Talents: M+ AoE · Loot: Current spec (Frost)",
        "without any target the current state is shown unjudged"
      )
      Assert.False(allOk, "an unjudged state is never all OK")

      world.selectedLoadoutID = nil
      world.lootSpecID = FIRE_MAGE
      text = LoadoutCheck.GetSummary(MAP_ID)
      Assert.Equal(text, "Talents: no saved loadout · Loot: Fire", "the starter build reads as no saved loadout")

      world.db.loadoutCheck = {
        ["Player-1-0000AAAA"] = { [FIRE_MAGE] = { [MAP_ID] = { configID = 101, lootSpecID = 0 } } },
      }
      text = LoadoutCheck.GetSummary(MAP_ID)
      Assert.Equal(text, "Talents: no saved loadout · Loot: Fire", "a target of another spec is never used")
    end)
  end)

  test("LoadoutCheck invite summary suggests the latest target of the same spec from another dungeon", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      local now = 1000
      world.deps.now = function()
        return now
      end
      local dungeonNames = { [500] = "Old Dungeon", [501] = "Newest Dungeon" }
      world.deps.getDungeonName = function(mapID)
        return dungeonNames[mapID]
      end
      world.db.loadoutCheck = {
        ["Player-1-0000AAAA"] = {
          [FROST_MAGE] = {
            [499] = { configID = 102, lootSpecID = ARCANE_MAGE },
            [500] = { configID = 102, lootSpecID = FIRE_MAGE, confirmedAt = 100 },
            [501] = { configID = 101, lootSpecID = 0, confirmedAt = 200 },
          },
        },
      }
      LoadoutCheck.SetDependencies(world.deps)

      local text, allOk = LoadoutCheck.GetSummary(MAP_ID)
      Assert.Equal(text, "Talents OK · Loot OK (as Newest Dungeon)", "the latest confirmation of the spec is used")
      Assert.True(allOk, "a matching suggestion is all OK")

      world.db.loadoutCheck["Player-1-0000AAAA"][FROST_MAGE][501] = nil
      text = LoadoutCheck.GetSummary(MAP_ID)
      Assert.Equal(
        text,
        "Talents: M+ Single expected · Loot: Fire expected (as Old Dungeon)",
        "a timestamped entry wins over one without timestamp"
      )

      dungeonNames = {}
      text = LoadoutCheck.GetSummary(MAP_ID)
      Assert.True(text:find("(as another dungeon)", 1, true) ~= nil, "an unknown source name still marks the source")

      world.db.loadoutCheck["Player-1-0000AAAA"][FROST_MAGE][MAP_ID] = { configID = 101, lootSpecID = 0 }
      text = LoadoutCheck.GetSummary(MAP_ID)
      Assert.Equal(text, "Talents OK · Loot OK", "an own target for the dungeon wins over every suggestion")

      Enter(LoadoutCheck, world)
      Assert.Equal(#world.printed, 1, "the entry check uses the own target only")
      world.db.loadoutCheck["Player-1-0000AAAA"][FROST_MAGE][MAP_ID] = nil
    end)
  end)

  test("LoadoutCheck entry card ignores targets confirmed in other dungeons and stamps the confirm time", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      world.deps.now = function()
        return 4242
      end
      world.db.loadoutCheck = {
        ["Player-1-0000AAAA"] = { [FROST_MAGE] = { [500] = { configID = 101, lootSpecID = 0, confirmedAt = 1 } } },
      }
      LoadoutCheck.SetDependencies(world.deps)

      Enter(LoadoutCheck, world)
      Assert.Equal(#world.shows, 1, "a suggestion from another dungeon never replaces the card")
      Assert.False(world.LastModel().hasTarget, "the entry card judges only the own dungeon target")

      world.cardController.Confirm()
      local stored = world.db.loadoutCheck["Player-1-0000AAAA"][FROST_MAGE][MAP_ID]
      Assert.Equal(stored.confirmedAt, 4242, "confirm stores the confirmation time")
    end)
  end)

  -- Same test name as before the move (rule 215 lists it); it now runs the
  -- real LoadoutCheck summary instead of a stubbed module.
  test("factory_controllers: RenderAcceptedInviteNotice adds the loadout check summary as last row", function()
    WithGlobals({}, function()
      local addon = LoadAddonModules({ "isiLive_factory_controllers.lua", "isiLive_loadout_check.lua" })
      local render = addon._FactoryInternal.RenderAcceptedInviteNotice
      local world = BuildWorld()
      StoreTarget(world, { configID = 102, configName = "M+ Single", lootSpecID = 0 })
      addon.LoadoutCheck.SetDependencies(world.deps)
      local captured
      local ctx = {
        GetL = function()
          return {
            INVITE_ACCEPTED_NOTICE_LABEL_SOURCE = "Quelle-DE:",
            INVITE_ACCEPTED_NOTICE_LABEL_LOADOUT = "Loadout-DE:",
          }
        end,
        GetDungeonName = function()
          return "Floodgate"
        end,
        ShowCenterNotice = function(_, _, _, _, opts)
          captured = opts
        end,
      }

      render(ctx, {}, { mapID = MAP_ID })
      local count = #captured.fields
      local header, talents, loot = captured.fields[count - 2], captured.fields[count - 1], captured.fields[count]
      Assert.Equal(header.label, "Loadout-DE:", "the Loadout block closes the card")
      Assert.Equal(header.value, "", "the Loadout label row carries no value of its own")
      Assert.Equal(talents.label, "Talents:", "Talents sits below Loadout in the label column")
      Assert.True(talents.grouped and loot.grouped, "both sub-rows are grouped under Loadout")
      Assert.Equal(
        talents.value,
        "|cffff2429|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:14:14:0:0|t Talents: M+ Single expected|r",
        "the talents sub-row carries the real summary with its status icon and colour"
      )
      Assert.Equal(
        loot.value,
        "|cff33d94d|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14:14:0:0|t Loot OK|r",
        "the loot sub-row carries its own status"
      )
      Assert.True(talents.warning, "a mismatch puts its sub-row on the warning strip")
      Assert.False(loot.warning, "the matching loot sub-row stays plain")
      Assert.Equal(captured.noticeKind, "action", "the row warning does not turn the whole card into a warning")

      world.db.loadoutCheckEnabled = false
      render(ctx, {}, { mapID = MAP_ID })
      Assert.Equal(captured.fields[#captured.fields].label, "Quelle-DE:", "the disabled setting omits the row")

      world.db.loadoutCheckEnabled = true
      addon.LoadoutCheck.GetSummaryFields = function()
        error("boom")
      end
      render(ctx, {}, { mapID = MAP_ID })
      Assert.Equal(captured.fields[#captured.fields].label, "Quelle-DE:", "a failing summary must omit the row")
    end)
  end)

  test("LoadoutCheck default dungeon resolver matches the season instance only on Mythic difficulty", function()
    local instance = { name = "Operation: Floodgate", type = "party", difficultyID = 23, instanceID = 0 }
    local seasonMapIDs = {}
    WithGlobals({
      GetInstanceInfo = function()
        return instance.name,
          instance.type,
          instance.difficultyID,
          "Mythic",
          5,
          0,
          false,
          instance.instanceID,
          nil,
          nil,
          nil,
          nil
      end,
      C_ChallengeMode = {
        GetMapUIInfo = function(mapID)
          return "Dungeon", mapID, 1800, nil, nil, 10000 + mapID
        end,
        IsChallengeModeActive = function()
          return false
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_season_data.lua", "isiLive_loadout_check.lua" })
      seasonMapIDs = addon.SeasonData.GetOrderedMapIDs()
      Assert.True(#seasonMapIDs > 0, "the active season must list dungeons")
      local mapID = seasonMapIDs[1]
      instance.instanceID = 10000 + mapID

      local world = BuildWorld()
      world.deps.resolveSeasonDungeon = nil
      world.deps.isChallengeActive = nil
      addon.LoadoutCheck.SetDependencies(world.deps)
      local controller = addon.LoadoutCheck.GetController()

      Assert.True(controller.Evaluate(), "Mythic season dungeon must qualify")
      Assert.Equal(world.LastModel().mapID, mapID, "the instance ID must resolve to its challenge map")
      Assert.Equal(world.LastModel().dungeonName, "Operation: Floodgate", "dungeon name comes from the instance")

      for _, difficultyID in ipairs({ 1, 2, 8 }) do
        instance.difficultyID = difficultyID
        Assert.False(controller.Evaluate(), "difficulty " .. difficultyID .. " must not qualify")
      end
      instance.difficultyID = 23
      instance.instanceID = 1
      Assert.False(controller.Evaluate(), "a non-season instance must not qualify")
    end)
  end)

  test("LoadoutCheck default talent and loot adapters load, sync the selection and fail closed", function()
    local updates = {}
    local loadResult = 2
    local lootSet = nil
    WithGlobals({
      C_ClassTalents = {
        LoadConfig = function(configID, autoApply)
          updates[#updates + 1] = { call = "load", configID = configID, autoApply = autoApply }
          return loadResult
        end,
        UpdateLastSelectedSavedConfigID = function(specID, configID)
          updates[#updates + 1] = { call = "select", specID = specID, configID = configID }
        end,
        GetConfigIDsBySpecID = function()
          return { 101, 102 }
        end,
        GetLastSelectedSavedConfigID = function()
          return 101
        end,
        GetStarterBuildActive = function()
          return false
        end,
      },
      C_Traits = {
        GetConfigInfo = function(configID)
          return { name = configID == 101 and "M+ AoE" or "M+ Single" }
        end,
      },
      GetLootSpecialization = function()
        return 0
      end,
      SetLootSpecialization = function(specID)
        lootSet = specID
      end,
    }, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      world.deps.getSavedLoadouts = nil
      world.deps.getSelectedLoadoutID = nil
      world.deps.loadLoadout = nil
      world.deps.getLootSpecID = nil
      world.deps.setLootSpecID = nil
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)

      local model = world.LastModel()
      Assert.Equal(#model.talents.options, 2, "saved loadouts come from C_ClassTalents + C_Traits")
      Assert.Equal(model.talents.currentName, "M+ AoE", "selection comes from GetLastSelectedSavedConfigID")
      Assert.Equal(model.loot.currentID, 0, "loot spec comes from GetLootSpecialization")

      local controller = LoadoutCheck.GetController()
      Assert.True(controller.SelectLoadout(102), "an accepted LoadConfig result succeeds")
      Assert.Equal(updates[1].call, "load", "LoadConfig runs first")
      Assert.Equal(updates[1].configID, 102, "LoadConfig receives the clicked loadout")
      Assert.True(updates[1].autoApply, "LoadConfig applies right away")
      Assert.Equal(#updates, 1, "LoadInProgress: no selection sync before the commit went through")
      LoadoutCheck.HandleEvent("TRAIT_CONFIG_UPDATED")
      Assert.Equal(updates[2].call, "select", "the talent frame selection is synced after the commit")
      Assert.Equal(updates[2].specID, FROST_MAGE, "selection sync uses the current spec")

      loadResult = 3
      Assert.True(controller.SelectLoadout(101), "a Ready result succeeds at once")
      Assert.Equal(updates[4].call, "select", "a finished load syncs the selection right away")

      loadResult = 0
      Assert.False(controller.SelectLoadout(101), "LoadConfig error must fail closed")
      Assert.Equal(#updates, 5, "no selection sync after an error")
      Assert.Equal(#world.printed, 1, "a failed load explains itself in chat")

      Assert.True(controller.SelectLootSpec(FIRE_MAGE), "SetLootSpecialization accepts a class spec")
      Assert.Equal(lootSet, FIRE_MAGE, "SetLootSpecialization receives the clicked spec")
    end)
  end)

  test("LoadoutCheck shows the card in the same instance once a missing spec resolves", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      world.specID = nil
      LoadoutCheck.SetDependencies(world.deps)

      Enter(LoadoutCheck, world)
      local controller = LoadoutCheck.GetController()
      Assert.Equal(#world.shows, 0, "without a spec no model exists, so no card")
      Assert.False(controller.IsActive(), "an unresolved evaluation must not count as an open card")

      world.specID = FROST_MAGE
      LoadoutCheck.HandleEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
      Assert.Equal(#world.shows, 1, "the spec event must show the card in the same instance")
      Assert.True(controller.IsActive(), "the recovered card must be active")

      world.FlushTimers()
      Assert.Equal(#world.shows, 1, "the outstanding retry must not show the card a second time")
    end)
  end)

  test("LoadoutCheck retries a missing spec a bounded number of times without any event", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      world.specID = nil
      LoadoutCheck.SetDependencies(world.deps)

      Enter(LoadoutCheck, world)
      local rounds = 0
      while #world.pending > 0 do
        rounds = rounds + 1
        Assert.True(rounds <= 3, "retries must stay bounded")
        world.FlushTimers()
      end
      Assert.Equal(rounds, 3, "a spec that never resolves gets exactly three timer retries")

      local recovering = BuildWorld()
      recovering.specID = nil
      LoadoutCheck.SetDependencies(recovering.deps)
      Enter(LoadoutCheck, recovering)
      recovering.specID = FROST_MAGE
      recovering.FlushTimers()
      Assert.Equal(#recovering.shows, 1, "a spec resolving before the retry must show the card without an event")
      Assert.Equal(#recovering.pending, 0, "a resolved evaluation must stop retrying")
    end)
  end)

  test("LoadoutCheck keeps a closed card closed until the next instance entry", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)

      Enter(LoadoutCheck, world)
      local controller = LoadoutCheck.GetController()
      controller.Dismiss()
      LoadoutCheck.HandleEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
      Assert.False(controller.Evaluate(), "the same instance must not evaluate again after closing")
      Assert.Equal(#world.shows, 1, "a closed card must not reopen on a spec event")

      local dungeon = world.dungeon
      world.dungeon = nil
      Enter(LoadoutCheck, world)
      world.dungeon = dungeon
      Enter(LoadoutCheck, world)
      Assert.Equal(#world.shows, 2, "leaving and entering again must show the card")
    end)
  end)

  test("LoadoutCheck stops retrying a missing spec after leaving the dungeon", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      world.specID = nil
      LoadoutCheck.SetDependencies(world.deps)

      Enter(LoadoutCheck, world)
      world.dungeon = nil
      world.specID = FROST_MAGE
      world.FlushTimers()
      LoadoutCheck.HandleEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
      Assert.Equal(#world.shows, 0, "outside the dungeon the recovery must not show a card")
      Assert.Equal(#world.pending, 0, "outside the dungeon no retry may stay scheduled")
    end)
  end)

  test("LoadoutCheck brings an open card back after the spec was unreadable for one refresh", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)
      local controller = LoadoutCheck.GetController()
      Assert.True(world.cardShown, "setup: the card must be open")

      world.specID = nil
      LoadoutCheck.HandleEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
      Assert.False(world.cardShown, "without a model the card cannot stay up")

      world.specID = FROST_MAGE
      LoadoutCheck.HandleEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
      Assert.True(world.cardShown, "the player never closed the card, so it must come back")
      Assert.True(controller.IsActive(), "the recovered card must be active")
    end)
  end)

  test("LoadoutCheck spends its retries on timers and not on event bursts", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      world.specID = nil
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)

      LoadoutCheck.HandleEvent("TRAIT_CONFIG_LIST_UPDATED")
      LoadoutCheck.HandleEvent("PLAYER_LOOT_SPEC_UPDATED")
      LoadoutCheck.HandleEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
      Assert.Equal(#world.pending, 1, "a burst must not stack retry timers")

      world.FlushTimers()
      world.FlushTimers()
      world.specID = FROST_MAGE
      world.FlushTimers()
      Assert.Equal(#world.shows, 1, "the third timer retry must still run after the burst")
    end)
  end)

  test("LoadoutCheck ignores a config update of another config while a talent switch runs", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      local marked = {}
      world.deps.loadLoadout = function()
        return "pending"
      end
      world.deps.markLoadoutSelected = function(_, configID)
        marked[#marked + 1] = configID
      end
      world.deps.getActiveConfigID = function()
        return 900
      end
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)
      local controller = LoadoutCheck.GetController()

      Assert.True(controller.SelectLoadout(102), "setup: the switch must start")
      LoadoutCheck.HandleEvent("TRAIT_CONFIG_UPDATED", 555)
      Assert.Equal(#marked, 0, "an update of another config proves nothing about this commit")

      LoadoutCheck.HandleEvent("CONFIG_COMMIT_FAILED")
      Assert.Equal(#marked, 0, "the failed commit must not count as selected")

      Assert.True(controller.SelectLoadout(102), "setup: the second switch must start")
      LoadoutCheck.HandleEvent("TRAIT_CONFIG_UPDATED", 900)
      Assert.Equal(marked[1], 102, "the update of the active config finishes the switch")
    end)
  end)

  test("LoadoutCheck hides an open card and blocks its actions once switched off", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)
      local controller = LoadoutCheck.GetController()
      Assert.True(world.cardShown, "the card must be open before switching off")

      world.db.loadoutCheckEnabled = false
      Assert.False(controller.SelectLoadout(102), "a stale loadout click must do nothing")
      Assert.Equal(#world.loads, 0, "a stale loadout click must not reach LoadConfig")
      Assert.False(world.cardShown, "a stale click must close the card")

      Assert.False(controller.SelectLootSpec(FIRE_MAGE), "a stale loot click must do nothing")
      Assert.Equal(#world.lootSets, 0, "a stale loot click must not change the loot spec")

      Assert.False(controller.Confirm(), "a stale confirm must do nothing")
      Assert.Nil(world.db.loadoutCheck, "a stale confirm must not store a target")
    end)
  end)

  test("LoadoutCheck hides the card on the next refresh when the setting is off", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)

      world.db.loadoutCheckEnabled = false
      LoadoutCheck.HandleEvent("PLAYER_REGEN_ENABLED")

      Assert.False(world.cardShown, "a refresh must hide the card of a disabled check")
      Assert.False(LoadoutCheck.GetController().IsActive(), "a disabled check must not stay active")
      Assert.False(LoadoutCheck.GetController().SelectLoadout(102), "no loadout switch after switching off")
      Assert.Equal(#world.loads, 0, "LoadConfig must stay untouched")
    end)
  end)

  test("LoadoutCheck switch-off cancels a scheduled evaluation and re-enabling waits for the next one", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      LoadoutCheck.SetDependencies(world.deps)

      LoadoutCheck.HandleEvent("PLAYER_ENTERING_WORLD")
      world.db.loadoutCheckEnabled = false
      LoadoutCheck.ApplyEnabledSetting()
      world.db.loadoutCheckEnabled = true
      LoadoutCheck.ApplyEnabledSetting()
      world.FlushTimers()
      Assert.Equal(#world.shows, 0, "the evaluation scheduled before switching off must stay dead")

      Enter(LoadoutCheck, world)
      Assert.Equal(#world.shows, 1, "the next valid evaluation must show the card again")

      world.db.loadoutCheckEnabled = false
      LoadoutCheck.ApplyEnabledSetting()
      Assert.False(world.cardShown, "switching off must hide an open card at once")
      world.db.loadoutCheckEnabled = true
      LoadoutCheck.ApplyEnabledSetting()
      Assert.False(world.cardShown, "switching on must not reopen the card by itself")
      Enter(LoadoutCheck, world)
      Assert.Equal(#world.shows, 2, "after switching on the same instance is evaluated again")
    end)
  end)

  test("LoadoutCheck finishes a running talent switch after being switched off", function()
    WithGlobals({}, function()
      local LoadoutCheck = LoadModule()
      local world = BuildWorld()
      local marked = {}
      world.deps.loadLoadout = function()
        return "pending"
      end
      world.deps.markLoadoutSelected = function(_, configID)
        marked[#marked + 1] = configID
      end
      LoadoutCheck.SetDependencies(world.deps)
      Enter(LoadoutCheck, world)
      local controller = LoadoutCheck.GetController()

      Assert.True(controller.SelectLoadout(102), "the switch must start while enabled")
      world.db.loadoutCheckEnabled = false
      LoadoutCheck.ApplyEnabledSetting()
      LoadoutCheck.HandleEvent("TRAIT_CONFIG_UPDATED")
      Assert.Equal(marked[1], 102, "the real commit must still mark the loadout selected")
      Assert.False(world.cardShown, "the finished switch must not bring the card back")

      world.db.loadoutCheckEnabled = true
      Enter(LoadoutCheck, world)
      Assert.True(controller.SelectLoadout(101), "the second switch must start")
      world.db.loadoutCheckEnabled = false
      LoadoutCheck.ApplyEnabledSetting()
      local printedBefore = #world.printed
      LoadoutCheck.HandleEvent("CONFIG_COMMIT_FAILED")
      Assert.Equal(#world.printed, printedBefore + 1, "a failed commit must still be reported")
      Assert.Equal(#marked, 1, "a failed commit must not count as selected")
    end)
  end)
end

return function(test, ctx)
  RegisterLoadoutCheckTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
