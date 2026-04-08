---@diagnostic disable: undefined-global
local Harness = {}
local Unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack"))

-- Maps bare filenames to their subdirectory paths.
-- Scenario files and callers pass bare names; the harness resolves the real path.
local FILE_PATHS = {
  -- core
  ["isiLive_validation_helpers.lua"] = "core/isiLive_validation_helpers.lua",
  ["isiLive_string_utils.lua"] = "core/isiLive_string_utils.lua",
  ["isiLive_sound_utils.lua"] = "core/isiLive_sound_utils.lua",
  ["isiLive_event_utils.lua"] = "core/isiLive_event_utils.lua",
  ["isiLive_runtime_state.lua"] = "core/isiLive_runtime_state.lua",
  ["isiLive_bootstrap.lua"] = "core/isiLive_bootstrap.lua",
  ["isiLive_context_helpers.lua"] = "core/isiLive_context_helpers.lua",
  ["isiLive_runtime_setup.lua"] = "core/isiLive_runtime_setup.lua",
  ["isiLive_log_buffer.lua"] = "core/isiLive_log_buffer.lua",
  ["isiLive_runtime_log.lua"] = "core/isiLive_runtime_log.lua",
  ["isiLive_guards.lua"] = "core/isiLive_guards.lua",
  -- locale
  ["realm_language_data.lua"] = "locale/realm_language_data.lua",
  ["isiLive_languages.lua"] = "locale/isiLive_languages.lua",
  ["isiLive_locale.lua"] = "locale/isiLive_locale.lua",
  ["isiLive_texts.lua"] = "locale/isiLive_texts.lua",
  -- game
  ["isiLive_spell_utils.lua"] = "game/isiLive_spell_utils.lua",
  ["isiLive_cd_tracker.lua"] = "game/isiLive_cd_tracker.lua",
  ["isiLive_season_data.lua"] = "game/isiLive_season_data.lua",
  ["isiLive_teleport.lua"] = "game/isiLive_teleport.lua",
  ["isiLive_teleport_debug.lua"] = "ui/isiLive_teleport_debug.lua",
  ["isiLive_units.lua"] = "game/isiLive_units.lua",
  ["isiLive_mplus_timer.lua"] = "game/isiLive_mplus_timer.lua",
  ["isiLive_kick_tracker.lua"] = "game/isiLive_kick_tracker.lua",
  -- ui
  ["isiLive_bindings.lua"] = "ui/isiLive_bindings.lua",
  ["isiLive_ui_common.lua"] = "ui/isiLive_ui_common.lua",
  ["isiLive_teleport_ui.lua"] = "ui/isiLive_teleport_ui.lua",
  ["isiLive_notice.lua"] = "ui/isiLive_notice.lua",
  ["isiLive_status.lua"] = "ui/isiLive_status.lua",
  ["isiLive_roster.lua"] = "ui/isiLive_roster.lua",
  ["isiLive_roster_tooltip.lua"] = "ui/isiLive_roster_tooltip.lua",
  ["isiLive_roster_layout.lua"] = "ui/isiLive_roster_layout.lua",
  ["isiLive_roster_panel.lua"] = "ui/isiLive_roster_panel.lua",
  ["isiLive_ui.lua"] = "ui/isiLive_ui.lua",
  ["isiLive_settings.lua"] = "ui/isiLive_settings.lua",
  -- logic
  ["isiLive_leader_watch.lua"] = "logic/isiLive_leader_watch.lua",
  ["isiLive_demo.lua"] = "logic/isiLive_demo.lua",
  ["isiLive_test_mode.lua"] = "logic/isiLive_test_mode.lua",
  ["isiLive_sync.lua"] = "logic/isiLive_sync.lua",
  ["isiLive_keysync.lua"] = "logic/isiLive_keysync.lua",
  ["isiLive_refresh.lua"] = "logic/isiLive_refresh.lua",
  ["isiLive_highlight.lua"] = "logic/isiLive_highlight.lua",
  ["isiLive_group.lua"] = "logic/isiLive_group.lua",
  ["isiLive_queue.lua"] = "logic/isiLive_queue.lua",
  ["isiLive_queue_debug.lua"] = "logic/isiLive_queue_debug.lua",
  ["isiLive_queue_flow.lua"] = "logic/isiLive_queue_flow.lua",
  ["isiLive_stats.lua"] = "logic/isiLive_stats.lua",
  ["isiLive_inspect.lua"] = "logic/isiLive_inspect.lua",
  ["isiLive_events.lua"] = "logic/isiLive_events.lua",
  ["isiLive_event_handlers_queue.lua"] = "logic/isiLive_event_handlers_queue.lua",
  ["isiLive_event_handlers_challenge.lua"] = "logic/isiLive_event_handlers_challenge.lua",
  ["isiLive_event_handlers_runtime.lua"] = "logic/isiLive_event_handlers_runtime.lua",
  ["isiLive_event_handlers.lua"] = "logic/isiLive_event_handlers.lua",
  ["isiLive_commands.lua"] = "logic/isiLive_commands.lua",
  -- factory
  ["isiLive_controller_wiring.lua"] = "factory/isiLive_controller_wiring.lua",
  ["isiLive_config_builders.lua"] = "factory/isiLive_config_builders.lua",
  ["isiLive_frame_bridge.lua"] = "factory/isiLive_frame_bridge.lua",
  ["isiLive_controller_init.lua"] = "factory/isiLive_controller_init.lua",
  ["isiLive_factory_frame_bridge.lua"] = "factory/isiLive_factory_frame_bridge.lua",
  ["isiLive_factory_controllers.lua"] = "factory/isiLive_factory_controllers.lua",
  ["isiLive_factory.lua"] = "factory/isiLive_factory.lua",
}

local function ResolveFile(file)
  return FILE_PATHS[file] or file
end

-- Modules loaded before any other module in LoadAddonModules (shared utilities).
local UNIVERSAL_DEPENDENCIES = {
  "isiLive_validation_helpers.lua",
  "isiLive_string_utils.lua",
  "isiLive_context_helpers.lua",
}

local IMPLICIT_DEPENDENCIES = {
  ["isiLive_event_handlers.lua"] = {
    "isiLive_event_handlers_queue.lua",
    "isiLive_event_handlers_challenge.lua",
    "isiLive_event_handlers_runtime.lua",
  },
  ["isiLive_roster_panel.lua"] = {
    "isiLive_roster_tooltip.lua",
    "isiLive_roster_layout.lua",
  },
  ["isiLive_factory.lua"] = {
    "isiLive_factory_frame_bridge.lua",
    "isiLive_factory_controllers.lua",
  },
  -- isiLive_languages.lua must be loaded before any module that calls
  -- addonTable.Languages (locale, commands, season_data).
  ["isiLive_locale.lua"] = { "isiLive_languages.lua" },
  ["isiLive_commands.lua"] = { "isiLive_languages.lua" },
  ["isiLive_season_data.lua"] = { "isiLive_languages.lua" },
}

local function Fail(message)
  error(message or "test harness error", 2)
end

function Harness.WithGlobals(stubs, fn)
  stubs = stubs or {}

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

  table.remove(results, 1)
  if Unpack then
    return Unpack(results)
  end
  return nil
end

function Harness.LoadAddonModules(files, seedAddonTable)
  local expandedFiles = {}
  local seenFiles = {}
  local function AddFileWithDependencies(file)
    if seenFiles[file] then
      return
    end

    local dependencies = IMPLICIT_DEPENDENCIES[file]
    if type(dependencies) == "table" then
      for _, dependency in ipairs(dependencies) do
        AddFileWithDependencies(dependency)
      end
    end

    seenFiles[file] = true
    table.insert(expandedFiles, file)
  end

  for _, file in ipairs(files or {}) do
    AddFileWithDependencies(file)
  end

  local addonTable = seedAddonTable or {}

  -- Load universal dependencies first (shared helpers available to all modules).
  for _, universalFile in ipairs(UNIVERSAL_DEPENDENCIES) do
    if not seenFiles[universalFile] then
      seenFiles[universalFile] = true
      local uChunk, uLoadErr = loadfile(ResolveFile(universalFile))
      if not uChunk then
        Fail(string.format("cannot load universal dep %s: %s", universalFile, tostring(uLoadErr)))
      end
      pcall(uChunk, "isiLive", addonTable)
    end
  end

  for _, file in ipairs(expandedFiles) do
    local chunk, loadErr = loadfile(ResolveFile(file))
    if not chunk then
      Fail(string.format("cannot load %s: %s", file, tostring(loadErr)))
    end

    local ok, runErr = pcall(chunk, "isiLive", addonTable)
    if not ok then
      Fail(string.format("cannot execute %s: %s", file, tostring(runErr)))
    end
  end
  return addonTable
end

function Harness.NewRunner()
  local tests = {}
  local runner = {}

  function runner.Test(name, fn)
    table.insert(tests, {
      name = name,
      fn = fn,
    })
  end

  function runner.GetCount()
    return #tests
  end

  function runner.Run()
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
    return passed, failed
  end

  return runner
end

return Harness
