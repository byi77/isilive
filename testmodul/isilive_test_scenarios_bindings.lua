---@diagnostic disable: undefined-global

-- Scenarios for ui/isiLive_bindings.lua - covers the binding controller
-- lifecycle, including combat-lockdown deferral, the hidden click-button
-- routing, and the watchdog ticker that reapplies bindings when WoW has
-- dropped them.

local function BuildFrameStub(state)
  local f = {
    _scripts = {},
    _attrs = {},
    _size = { 0, 0 },
    _alpha = 1,
    _points = {},
    _clicks = nil,
    _mouseEnabled = false,
  }
  function f:SetSize(w, h)
    self._size = { w, h }
  end
  function f:SetPoint(...)
    table.insert(self._points, { ... })
  end
  function f:SetAlpha(a)
    self._alpha = a
  end
  function f:EnableMouse(v)
    self._mouseEnabled = v
  end
  function f:RegisterForClicks(...)
    self._clicks = { ... }
  end
  function f:SetScript(name, fn)
    self._scripts[name] = fn
  end
  function f:GetScript(name)
    return self._scripts[name]
  end
  state.createdFrames = state.createdFrames or {}
  table.insert(state.createdFrames, f)
  return f
end

local function BuildBindingsEnv(overrides)
  overrides = overrides or {}
  local state = {
    createdFrames = {},
    overrideBindings = {},
    cleared = 0,
    tickerFn = nil,
    tickerInterval = nil,
    tickerCancelCalls = 0,
    inCombat = overrides.inCombat or false,
    bindingActions = overrides.bindingActions or {},
  }

  local globals = {
    CreateFrame = function(_type, name, _parent)
      local f = BuildFrameStub(state)
      f._name = name
      return f
    end,
    UIParent = {},
    ClearOverrideBindings = function(_frame)
      state.cleared = state.cleared + 1
    end,
    SetOverrideBindingClick = function(frame, _, key, button, click)
      state.overrideBindings[key] = { frame = frame, button = button, click = click }
    end,
    InCombatLockdown = function()
      return state.inCombat
    end,
    C_Timer = {
      NewTicker = function(interval, fn)
        state.tickerInterval = interval
        state.tickerFn = fn
        local ticker = {}
        function ticker:Cancel()
          state.tickerCancelCalls = state.tickerCancelCalls + 1
        end
        return ticker
      end,
    },
    GetBindingAction = function(key)
      return state.bindingActions[key]
    end,
  }

  return globals, state
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function Load()
    return LoadAddonModules({ "isiLive_bindings.lua" })
  end

  test("bindings: CreateController requires onToggleMainFrame and onToggleTestMode", function()
    local globals = BuildBindingsEnv()
    WithGlobals(globals, function()
      local addon = Load()
      local okMissing = pcall(addon.Bindings.CreateController, {})
      Assert.Equal(okMissing, false, "missing both callbacks must fail the Require guards")
    end)
  end)

  test("bindings: ApplyHotkeyBindings installs three override binding clicks", function()
    local globals, state = BuildBindingsEnv()
    WithGlobals(globals, function()
      local addon = Load()
      local controller = addon.Bindings.CreateController({
        onToggleMainFrame = function() end,
        onToggleTestMode = function() end,
      })
      controller.ApplyHotkeyBindings()
      Assert.Equal(state.cleared, 1, "old override bindings must be cleared first")
      Assert.Equal(state.overrideBindings["CTRL-F9"].button, "isiLiveToggleBindingButton")
      Assert.Equal(state.overrideBindings["CTRL-ALT-F9"].button, "isiLiveTestModeBindingButton")
      Assert.Equal(state.overrideBindings["ALT-CTRL-F9"].button, "isiLiveTestModeBindingButton")
      Assert.Equal(controller.GetPendingBindingApply(), false, "successful apply must clear the pending flag")
    end)
  end)

  test("bindings: ApplyHotkeyBindings defers when InCombatLockdown is true", function()
    local globals, state = BuildBindingsEnv({ inCombat = true })
    WithGlobals(globals, function()
      local addon = Load()
      local controller = addon.Bindings.CreateController({
        onToggleMainFrame = function() end,
        onToggleTestMode = function() end,
      })
      controller.ApplyHotkeyBindings()
      Assert.Equal(controller.GetPendingBindingApply(), true, "combat lockdown must defer + set the pending flag")
      Assert.Equal(state.cleared, 0, "deferred apply must not clear override bindings")
      Assert.Nil(state.overrideBindings["CTRL-F9"])
    end)
  end)

  test("bindings: hidden button OnClick forwards to the configured callback only on key-up", function()
    local globals, state = BuildBindingsEnv()
    local toggleCalls = 0
    local testCalls = 0
    WithGlobals(globals, function()
      local addon = Load()
      addon.Bindings.CreateController({
        onToggleMainFrame = function()
          toggleCalls = toggleCalls + 1
        end,
        onToggleTestMode = function()
          testCalls = testCalls + 1
        end,
      })
      -- createdFrames: [1]=owner frame, [2]=toggle button, [3]=testmode button
      local toggleBtn = state.createdFrames[2]
      local testBtn = state.createdFrames[3]
      Assert.Equal(toggleBtn._name, "isiLiveToggleBindingButton")
      Assert.Equal(testBtn._name, "isiLiveTestModeBindingButton")

      toggleBtn._scripts.OnClick(toggleBtn, "LeftButton", false)
      Assert.Equal(toggleCalls, 0, "key-down event must be ignored")
      toggleBtn._scripts.OnClick(toggleBtn, "LeftButton", true)
      Assert.Equal(toggleCalls, 1, "key-up fires the toggle callback")

      testBtn._scripts.OnClick(testBtn, "LeftButton", true)
      Assert.Equal(testCalls, 1)
    end)
  end)

  test("bindings: StartBindingWatchdog registers a single ticker and reapplies when bindings are missing", function()
    local globals, state = BuildBindingsEnv()
    WithGlobals(globals, function()
      local addon = Load()
      local controller = addon.Bindings.CreateController({
        onToggleMainFrame = function() end,
        onToggleTestMode = function() end,
      })
      controller.StartBindingWatchdog()
      Assert.Equal(state.tickerInterval, 5, "watchdog ticks every 5s")
      Assert.NotNil(state.tickerFn)

      -- Second call must not replace the ticker.
      local firstFn = state.tickerFn
      controller.StartBindingWatchdog()
      Assert.Equal(state.tickerFn, firstFn, "existing ticker must not be replaced")

      -- Tick with no registered bindings -> must reapply.
      state.bindingActions = {}
      state.tickerFn()
      Assert.NotNil(state.overrideBindings["CTRL-F9"], "missing binding must trigger reapply via ticker")

      -- Tick with all bindings present -> must be a no-op.
      state.bindingActions = {
        ["CTRL-F9"] = "CLICK isiLiveToggleBindingButton:LeftButton",
        ["CTRL-ALT-F9"] = "CLICK isiLiveTestModeBindingButton:LeftButton",
        ["ALT-CTRL-F9"] = "CLICK isiLiveTestModeBindingButton:LeftButton",
      }
      state.cleared = 0
      state.tickerFn()
      Assert.Equal(state.cleared, 0, "present bindings must not re-clear override state")
    end)
  end)

  test("bindings: watchdog tick during combat only flags pending reapply", function()
    local globals, state = BuildBindingsEnv()
    WithGlobals(globals, function()
      local addon = Load()
      local controller = addon.Bindings.CreateController({
        onToggleMainFrame = function() end,
        onToggleTestMode = function() end,
      })
      controller.StartBindingWatchdog()
      -- No registered bindings, combat active -> only sets pending flag.
      state.inCombat = true
      state.bindingActions = {}
      state.tickerFn()
      Assert.Equal(controller.GetPendingBindingApply(), true)
      Assert.Equal(state.cleared, 0, "combat tick must not clear bindings")
    end)
  end)

  test("bindings: StopBindingWatchdog cancels ownership and allows a clean restart", function()
    local globals, state = BuildBindingsEnv()
    WithGlobals(globals, function()
      local addon = Load()
      local controller = addon.Bindings.CreateController({
        onToggleMainFrame = function() end,
        onToggleTestMode = function() end,
      })
      controller.StartBindingWatchdog()
      local firstTicker = state.tickerFn
      controller.StopBindingWatchdog()
      Assert.Equal(state.tickerCancelCalls, 1, "stop must cancel the owned ticker exactly once")
      controller.StartBindingWatchdog()
      Assert.True(state.tickerFn ~= firstTicker, "restart must create a fresh ticker callback")
    end)
  end)

  test("bindings: StartBindingWatchdog is a no-op when C_Timer.NewTicker is missing", function()
    local globals, state = BuildBindingsEnv()
    globals.C_Timer = nil
    WithGlobals(globals, function()
      local addon = Load()
      local controller = addon.Bindings.CreateController({
        onToggleMainFrame = function() end,
        onToggleTestMode = function() end,
      })
      controller.StartBindingWatchdog()
      Assert.Nil(state.tickerFn, "no C_Timer means no watchdog ticker")
    end)
  end)
end
