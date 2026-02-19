-- Deterministic usecase validation for critical addon logic.
-- Runs in plain Lua with mocked WoW globals.

local function fail(message)
  error(message, 2)
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    fail(string.format("%s (got=%s expected=%s)", message, tostring(actual), tostring(expected)))
  end
end

local function assert_true(value, message)
  if not value then
    fail(message)
  end
end

local function with_globals(stubs, fn)
  local previous = {}
  local existed = {}
  for key, value in pairs(stubs) do
    existed[key] = rawget(_G, key) ~= nil
    previous[key] = rawget(_G, key)
    _G[key] = value
  end

  local results = { pcall(fn) }

  for key in pairs(stubs) do
    if existed[key] then
      _G[key] = previous[key]
    else
      _G[key] = nil
    end
  end

  if not results[1] then
    error(results[2], 0)
  end
end

local function load_modules(files)
  local addon = {}
  for _, file in ipairs(files) do
    local chunk, load_err = loadfile(file)
    if not chunk then
      fail(string.format("cannot load %s: %s", file, tostring(load_err)))
    end

    local ok, run_err = pcall(chunk, "isiLive", addon)
    if not ok then
      fail(string.format("cannot execute %s: %s", file, tostring(run_err)))
    end
  end
  return addon
end

local tests = {}

local function test(name, fn)
  table.insert(tests, { name = name, fn = fn })
end

local function build_event_handlers_controller(eventHandlersModule, entry_ref, counters)
  return eventHandlersModule.CreateController({
    addonName = "isiLive",
    defaultLocale = "enUS",
    locales = { enUS = {} },
    resolveLocaleTag = function(tag)
      return tag
    end,
    setLocaleTable = function(_table) end,
    isInGroup = function()
      return true
    end,
    isTestMode = function()
      return false
    end,
    isTestAllMode = function()
      return false
    end,
    exitTestMode = function() end,
    handleGroupRosterUpdate = function() end,
    isInChallengeMode = function()
      return false
    end,
    isNegativeApplicationStatusEvent = function()
      return true
    end,
    getNormalizedActiveEntryInfo = function()
      return entry_ref.value
    end,
    setPendingQueueJoinInfo = function(_value) end,
    clearLatestQueueTarget = function()
      counters.clears = counters.clears + 1
    end,
    updateMPlusTeleportButton = function()
      counters.updates = counters.updates + 1
    end,
    captureQueueJoinCandidate = function() end,
    getActiveJoinedKeyMapID = function()
      return nil
    end,
    setActiveJoinedKeyMapID = function(_value) end,
    updateUI = function() end,
    setMainFrameVisible = function(_visible) end,
    updateLeaderButtons = function() end,
    updateStatusLine = function() end,
    sendOwnKeySnapshot = function(_force) end,
    ensureQueueDebugStorage = function() end,
    setQueueDebugEnabled = function(_enabled) end,
    getMainFrame = function()
      return {
        ClearAllPoints = function() end,
        SetPoint = function() end,
      }
    end,
    applyCenterNoticeStoredPosition = function(_position) end,
    registerIsiLiveSyncPrefix = function() end,
    applyHotkeyBindings = function() end,
    startBindingWatchdog = function() end,
    applyLocalizationToUI = function() end,
    updateCountdownCancelButton = function() end,
    getUnitNameAndRealm = function()
      return "player", "realm"
    end,
    markIsiLiveUser = function() end,
    sendIsiLiveHello = function(_force) end,
    maybeShowNonMythicDungeonEntryNotice = function() end,
    checkIfEnteredTargetDungeon = function() end,
    getPendingBindingApply = function()
      return false
    end,
    getPendingMainFrameHeight = function()
      return nil
    end,
    setMainFrameHeightSafe = function(_height) end,
    getPendingMainFrameVisible = function()
      return nil
    end,
    getPendingCenterNoticeVisible = function()
      return nil
    end,
    setCenterNoticeVisible = function(_visible) end,
    tryRestoreCenterNoticeTeleportButton = function() end,
    handleOwnedKeyRefresh = function() end,
    isMainFrameShown = function()
      return true
    end,
    onInspectReady = function(_guid)
      return false
    end,
    processAddonMessage = function(_prefix, _message, _sender)
      return nil
    end,
    sendAck = function(_sender) end,
    forEachRosterInfo = function(_visitor) end,
    isSyncUserKnown = function(_name, _realm)
      return false
    end,
    applyKnownKeyToRosterEntry = function(_info)
      return false
    end,
    runFullRefresh = function() end,
  })
end

test("Queue picks concrete teleport-mapped activity over generic candidate", function()
  with_globals({
    C_LFGList = {
      GetActivityInfoTable = function(activity_id)
        if activity_id == 200 then
          return { mapID = 2441, isMythicPlusActivity = true, categoryID = 2 }
        end
        if activity_id == 201 then
          return { mapID = 2442, isMythicPlusActivity = true, categoryID = 2 }
        end
        return nil
      end,
    },
  }, function()
    local addon = load_modules({ "isiLive_queue.lua" })
    local result = {
      activityID = 200,
      activityIDs = { 201 },
    }

    local resolved_id = addon.Queue.GetSearchResultActivityID(result, function(activity_id)
      if activity_id == 201 then
        return 367416
      end
      if activity_id == 200 then
        return true
      end
      return nil
    end)

    assert_equal(resolved_id, 201, "queue candidate resolution must prefer concrete mapping")
  end)
end)

test("Queue activity name lookup is protected against API errors", function()
  with_globals({
    C_LFGList = {
      GetActivityInfoTable = function(_activity_id)
        error("simulated api failure")
      end,
    },
  }, function()
    local addon = load_modules({ "isiLive_queue.lua" })
    local name = addon.Queue.GetActivityName(123)
    assert_equal(name, nil, "activity name lookup should not crash on API failure")
  end)
end)

test("Highlight keeps active listing for shared spell when map is different", function()
  local current_map_id = nil
  local active_entry = nil

  with_globals({
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return nil
      end,
    },
    C_Map = {
      GetBestMapForUnit = function(_unit)
        return current_map_id
      end,
    },
    C_LFGList = {
      GetActiveEntryInfo = function()
        return active_entry
      end,
      GetActivityInfoTable = function(activity_id)
        if activity_id == 1001 then
          return { mapID = 2442 }
        end
        return nil
      end,
    },
  }, function()
    local addon = load_modules({ "isiLive_highlight.lua" })
    local controller = addon.Highlight.CreateController({
      isInGroup = function()
        return true
      end,
      resolveSeason3TeleportSpellID = function(activity_id, _dungeon_name)
        if activity_id == 1001 then
          return 367416
        end
        return nil
      end,
      resolveSeason3TeleportSpellIDByMapID = function(map_id)
        if map_id == 2441 or map_id == 2442 then
          return 367416
        end
        return nil
      end,
      resolveSeason3MapIDBySpellID = function(_spell_id)
        return nil
      end,
      resolveSeason3MapIDsBySpellID = function(spell_id)
        if spell_id == 367416 then
          return { 2441, 2442 }
        end
        return nil
      end,
    })

    active_entry = { active = true, activityID = 1001, mapID = 2442 }

    current_map_id = 2441
    local different_map_spell = controller.ResolveActiveTeleportSpellID(nil, nil, nil)
    assert_equal(different_map_spell, 367416, "shared spell highlight must stay on different active listing map")

    current_map_id = 2442
    local exact_map_spell = controller.ResolveActiveTeleportSpellID(nil, nil, nil)
    assert_equal(exact_map_spell, nil, "shared spell highlight must clear on exact active listing map")
  end)
end)

test("Highlight queue path uses exact map suppression for shared spell", function()
  local current_map_id = nil

  with_globals({
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return nil
      end,
    },
    C_Map = {
      GetBestMapForUnit = function(_unit)
        return current_map_id
      end,
    },
    C_LFGList = {
      GetActiveEntryInfo = function()
        return nil
      end,
      GetActivityInfoTable = function(activity_id)
        if activity_id == 1001 then
          return { mapID = 2442 }
        end
        return nil
      end,
    },
  }, function()
    local addon = load_modules({ "isiLive_highlight.lua" })
    local controller = addon.Highlight.CreateController({
      isInGroup = function()
        return true
      end,
      resolveSeason3TeleportSpellID = function(activity_id, _dungeon_name)
        if activity_id == 1001 then
          return 367416
        end
        return nil
      end,
      resolveSeason3TeleportSpellIDByMapID = function(map_id)
        if map_id == 2441 or map_id == 2442 then
          return 367416
        end
        return nil
      end,
      resolveSeason3MapIDBySpellID = function(_spell_id)
        return nil
      end,
      resolveSeason3MapIDsBySpellID = function(spell_id)
        if spell_id == 367416 then
          return { 2441, 2442 }
        end
        return nil
      end,
    })

    current_map_id = 2441
    local different_map_spell = controller.ResolveActiveTeleportSpellID(1001, "Tazavesh", nil)
    assert_equal(different_map_spell, 367416, "queue shared spell must stay highlighted on different map")

    current_map_id = 2442
    local exact_map_spell = controller.ResolveActiveTeleportSpellID(1001, "Tazavesh", nil)
    assert_equal(exact_map_spell, nil, "queue shared spell must clear on exact map")
  end)
end)

test("Highlight joined key resolver does not guess ambiguous shared spells", function()
  with_globals({
    C_LFGList = {
      GetActivityInfoTable = function(_activity_id)
        return nil
      end,
    },
  }, function()
    local addon = load_modules({ "isiLive_highlight.lua" })
    local controller = addon.Highlight.CreateController({
      resolveSeason3MapIDBySpellID = function(_spell_id)
        return nil
      end,
      resolveSeason3MapIDsBySpellID = function(spell_id)
        if spell_id == 367416 then
          return { 2441, 2442 }
        end
        if spell_id == 445414 then
          return { 2662 }
        end
        return nil
      end,
    })

    local ambiguous = controller.ResolveJoinedKeyMapID(nil, 367416)
    assert_equal(ambiguous, nil, "joined key map should be nil for ambiguous shared spell")

    local unique = controller.ResolveJoinedKeyMapID(nil, 445414)
    assert_equal(unique, 2662, "joined key map should resolve for unique spell mapping")
  end)
end)

test("Event handlers keep target when active listing is inferred", function()
  local entry_ref = { value = { activityID = 1001 } }
  local counters = { clears = 0, updates = 0 }

  with_globals({}, function()
    local addon = load_modules({ "isiLive_event_handlers.lua" })
    local controller = build_event_handlers_controller(addon.EventHandlers, entry_ref, counters)

    controller.Dispatch({}, "LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
    assert_equal(counters.clears, 0, "target must not clear for inferred active listing")

    entry_ref.value = {}
    controller.Dispatch({}, "LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
    assert_equal(counters.clears, 1, "target must clear when listing info is empty")

    entry_ref.value = { active = false }
    controller.Dispatch({}, "LFG_LIST_APPLICATION_STATUS_UPDATED", 1, "declined")
    assert_equal(counters.clears, 2, "target must clear for explicit inactive listing")
  end)
end)

test("QueueFlow permissive resolver is robust when activity API errors", function()
  with_globals({
    C_LFGList = {
      GetActivityInfoTable = function(_activity_id)
        error("simulated api failure")
      end,
    },
  }, function()
    local addon = load_modules({ "isiLive_queue_flow.lua" })

    local callback_checked = false
    local controller = addon.QueueFlow.CreateController({
      getL = function()
        return {
          UNKNOWN_GROUP = "Unknown",
          INVITE_HINT_GROUP = "Group: %s",
          INVITE_HINT_DUNGEON = "Dungeon: %s",
          INVITE_HINT_UNKNOWN_DUNGEON = "Dungeon: Unknown",
          JOINED_FROM_QUEUE = "Joined from queue: %s",
          JOINED_FROM_QUEUE_DUNGEON = "Joined from queue: %s (%s)",
          CHAT_QUEUE_PREFIX = "Queue Join",
        }
      end,
      getPendingQueueJoinInfo = function()
        return nil
      end,
      setPendingQueueJoinInfo = function(_value) end,
      resolveSeason3TeleportSpellID = function(_activity_id, _dungeon_name)
        return nil
      end,
      resolveSeason3TeleportSpellIDByActivityID = function(_activity_id)
        return nil
      end,
      resolveJoinedKeyMapID = function(_activity_id, _spell_id)
        return nil
      end,
      updateMPlusTeleportButton = function() end,
      showInviteHint = function(_message, _duration) end,
      showCenterNotice = function(_message, _duration, _dungeon_name, _activity_id) end,
      updateUI = function() end,
      printFn = function(_message) end,
      setQueueTargetState = function(_dungeon_name, _activity_id, _spell_id, _map_id) end,
      queueCaptureQueueJoinCandidate = function(_update_pending, permissive_resolver, ...)
        local ok, value = pcall(permissive_resolver, 777, ...)
        assert_true(ok, "permissive resolver must not raise on API failure")
        assert_equal(value, nil, "permissive resolver should return nil on API failure")
        callback_checked = true
      end,
      isInChallengeMode = function()
        return false
      end,
      isPlayerLeader = function()
        return false
      end,
      getTimeFn = function()
        return 0
      end,
    })

    controller.CaptureQueueJoinCandidate("dummy")
    assert_true(callback_checked, "queue capture callback should run")
  end)
end)

test("Spell utils keep teleports recognized during cooldown", function()
  with_globals({
    C_SpellBook = {
      IsSpellKnownOrOverridesKnown = function(_spell_id)
        return false
      end,
      IsSpellKnown = function(_spell_id)
        return false
      end,
    },
    C_Spell = {
      GetSpellCooldown = function(_spell_id)
        return {
          startTime = 100,
          duration = 300,
          isEnabled = true,
        }
      end,
    },
    GetTime = function()
      return 250
    end,
  }, function()
    local addon = load_modules({ "isiLive_spell_utils.lua" })
    local known = addon.SpellUtils.IsSpellKnownSafe(12345)
    assert_true(known, "spell should be treated as known while on real cooldown")

    local remaining = addon.SpellUtils.GetTeleportCooldownRemaining(12345)
    assert_equal(remaining, 150, "cooldown remaining must be computed from start+duration")

    local formatted = addon.SpellUtils.FormatCooldownSeconds(28800)
    assert_equal(formatted, "08:00", "8h cooldown should format as 08:00")
  end)
end)

local passed = 0
local failed = 0

for _, item in ipairs(tests) do
  local ok, err = xpcall(item.fn, debug.traceback)
  if ok then
    passed = passed + 1
    print("[PASS] " .. item.name)
  else
    failed = failed + 1
    print("[FAIL] " .. item.name)
    print(err)
  end
end

print(string.format("Usecase validation complete: %d passed, %d failed", passed, failed))

if failed > 0 then
  os.exit(1)
end

os.exit(0)
