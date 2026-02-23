---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function CreateFrameStub(_frameType)
    local frame = {
      _events = {},
      _scripts = {},
    }
    function frame:SetScript(name, handler)
      self._scripts[name] = handler
    end
    function frame:RegisterEvent(event)
      self._events[event] = true
    end
    function frame:UnregisterEvent(event)
      self._events[event] = nil
    end
    function frame:IsEventRegistered(event)
      return self._events[event] == true
    end
    return frame
  end

  test("Guards validates all required modules are present", function()
    WithGlobals({
      CreateFrame = CreateFrameStub,
    }, function()
      local addon = LoadAddonModules({
        "isiLive_sync.lua",
        "isiLive_keysync.lua",
        "isiLive_refresh.lua",
        "isiLive_highlight.lua",
        "isiLive_group.lua",
        "isiLive_queue.lua",
        "isiLive_queue_flow.lua",
        "isiLive_inspect.lua",
        "isiLive_roster.lua",
        "isiLive_events.lua",
        "isiLive_event_handlers.lua",
        "isiLive_commands.lua",
        "isiLive_locale.lua",
        "isiLive_texts.lua",
        "isiLive_ui.lua",
        "isiLive_season_data.lua",
        "isiLive_teleport.lua",
        "isiLive_teleport_ui.lua",
        "isiLive_teleport_debug.lua",
        "isiLive_notice.lua",
        "isiLive_status.lua",
        "isiLive_units.lua",
        "isiLive_demo.lua",
        "isiLive_test_mode.lua",
        "isiLive_queue_debug.lua",
        "isiLive_runtime_log.lua",
        "isiLive_roster_panel.lua",
        "isiLive_spell_utils.lua",
        "isiLive_bindings.lua",
        "isiLive_event_utils.lua",
        "isiLive_bootstrap.lua",
        "isiLive_controller_wiring.lua",
        "isiLive_leader_watch.lua",
        "isiLive_config_builders.lua",
        "isiLive_frame_bridge.lua",
        "isiLive_context_helpers.lua",
        "isiLive_runtime_setup.lua",
        "isiLive_controller_init.lua",
        "isiLive_guards.lua",
      })

      local ok, err = pcall(addon.Guards.Validate, addon)
      Assert.True(ok, "Guards.Validate must pass with all modules loaded: " .. tostring(err))
    end)
  end)

  test("Guards fails when a required module is missing", function()
    local addon = LoadAddonModules({
      "isiLive_guards.lua",
    })

    local ok, err = pcall(addon.Guards.Validate, addon)
    Assert.False(ok, "Guards.Validate must fail when modules are missing")
    Assert.True(type(err) == "string" and err:find("missing module") ~= nil, "error must mention missing module")
  end)

  test("Guards fails when a required function is missing from module stub", function()
    local addon = LoadAddonModules({
      "isiLive_guards.lua",
    })

    -- Provide a module with missing functions
    addon.Queue = {}
    local ok, err = pcall(addon.Guards.Validate, addon)
    Assert.False(ok, "Guards.Validate must fail with empty module stub")
    Assert.True(type(err) == "string", "error message must be a string")
  end)

  test("Main addon exits gracefully when Guards validation fails", function()
    WithGlobals({
      GetLocale = function()
        return "enUS"
      end,
      print = function(_msg) end,
    }, function()
      local ok, err = pcall(function()
        LoadAddonModules({
          "isiLive.lua",
        }, {
          Guards = {
            Validate = function()
              error("missing module Texts")
            end,
          },
        })
      end)

      Assert.True(ok, "isiLive.lua must not crash when Guards.Validate fails: " .. tostring(err))
    end)
  end)
end
