---@diagnostic disable: undefined-global

-- Time to kill of the target (rule 209).
--
-- End-to-end through the real modules: MplusTimer decides whether a key runs,
-- TTK receives its events through the real OnEvent script of its own frame and
-- renders through the real ticker callback. Blizzard's curve evaluation is the
-- one stand-in: the curve stub interpolates its points linearly, as the client
-- does, and UnitHealthPercent evaluates it at the stubbed health share. The
-- evaluated value is wrapped in a Secret stand-in that raises on comparison
-- and arithmetic, so a test fails if TTK ever inspects it.

local helpersChunk, helpersErr = loadfile("testmodul/isilive_test_ui_helpers.lua")
if not helpersChunk then
  error("cannot load UI helpers: " .. tostring(helpersErr))
end
local helpers = helpersChunk()
local BuildCreateFrameStub = helpers.BuildCreateFrameStub

local SECRET_MT = {
  __eq = function()
    error("TTK compared a secret value")
  end,
  __lt = function()
    error("TTK compared a secret value")
  end,
  __le = function()
    error("TTK compared a secret value")
  end,
  __add = function()
    error("TTK did arithmetic on a secret value")
  end,
  __sub = function()
    error("TTK did arithmetic on a secret value")
  end,
  __mul = function()
    error("TTK did arithmetic on a secret value")
  end,
  __div = function()
    error("TTK did arithmetic on a secret value")
  end,
}

local function Secret(value)
  return setmetatable({ value = value }, SECRET_MT)
end

local function IsSecret(v)
  return getmetatable(v) == SECRET_MT
end

local function NewCurveStub()
  local curve = { points = {} }
  function curve.ClearPoints(self)
    self.points = {}
  end
  function curve.AddPoint(self, x, y)
    self.points[#self.points + 1] = { x, y }
  end
  function curve.Evaluate(self, x)
    local pts = self.points
    for i = 2, #pts do
      if x <= pts[i][1] then
        local x0, y0, x1, y1 = pts[i - 1][1], pts[i - 1][2], pts[i][1], pts[i][2]
        return y0 + (y1 - y0) * ((x - x0) / (x1 - x0))
      end
    end
    return pts[#pts][2]
  end
  return curve
end

-- Display stub: SetFormattedText unwraps the Secret stand-in only to build
-- the visible text, like the client's renderer.
local function NewDisplayText()
  local fs = { _text = "" }
  function fs.SetText(self, text)
    self._text = text
  end
  function fs.SetFormattedText(self, format, value)
    self._lastValueWasSecret = IsSecret(value)
    self._text = string.format(format, IsSecret(value) and value.value or value)
  end
  return fs
end

local function BuildEnv(opts)
  opts = opts or {}
  local env = {
    now = 100,
    hp = 0.5,
    -- Default target: a miniboss (elite one level above the player).
    target = {
      exists = true,
      canAttack = true,
      dead = false,
      plateToken = "nameplate1",
      isBoss = false,
      classification = "elite",
      level = 91,
      lieutenant = false,
      mana = false,
    },
    db = opts.db or {},
    keyRunning = opts.keyRunning ~= false,
    tickers = {},
    curves = {},
    after = {},
    inCombat = false,
    inRaid = false,
  }
  local createFrameStub, createdFrames = BuildCreateFrameStub()
  env.createdFrames = createdFrames
  env.globals = {
    IsiLiveDB = env.db,
    CreateFrame = createFrameStub,
    UIParent = {},
    GetTime = function()
      return env.now
    end,
    UnitAffectingCombat = function(unit)
      return unit == "player" and env.inCombat
    end,
    IsInRaid = function()
      return env.inRaid
    end,
    issecretvalue = IsSecret,
    UnitExists = function(unit)
      return unit == "target" and env.target.exists
    end,
    UnitCanAttack = function(_, unit)
      return unit == "target" and env.target.canAttack
    end,
    UnitIsDead = function(unit)
      return unit == "target" and env.target.dead
    end,
    UnitClassification = function(unit)
      return unit == "target" and env.target.classification or "normal"
    end,
    UnitEffectiveLevel = function(unit)
      if unit == "player" then
        return 90
      end
      return unit == "target" and env.target.level or 0
    end,
    UnitIsLieutenant = function(unit)
      return unit == "target" and env.target.lieutenant
    end,
    UnitHasPowerType = function(unit)
      return unit == "target" and env.target.mana
    end,
    UnitIsUnit = function(a, b)
      if a ~= "target" then
        return false
      end
      if b == "boss1" then
        return env.target.isBoss
      end
      return b == env.target.plateToken
    end,
    UnitHealthPercent = function(unit, _usePredicted, curve)
      assert(unit == "target", "TTK must evaluate the target")
      return Secret(curve:Evaluate(env.hp))
    end,
    C_CurveUtil = {
      CreateCurve = function()
        local curve = NewCurveStub()
        env.curves[#env.curves + 1] = curve
        return curve
      end,
    },
    C_NamePlate = {
      GetNamePlateForUnit = function(unit)
        if unit == "target" and env.target.plateToken and not env.targetLookupEmpty then
          return { namePlateUnitToken = env.target.plateToken }
        end
        return nil
      end,
    },
    C_Timer = {
      NewTicker = function(_, callback)
        local t = { callback = callback }
        function t.Cancel(self)
          self.cancelled = true
        end
        env.tickers[#env.tickers + 1] = t
        return t
      end,
      After = function(_, callback)
        env.after[#env.after + 1] = callback
      end,
    },
    C_ChallengeMode = {
      GetActiveChallengeMapID = function()
        return env.keyRunning and 2649 or nil
      end,
      GetActiveKeystoneInfo = function()
        return 12
      end,
      GetMapUIInfo = function()
        return "Dungeon", 1, 1800
      end,
    },
    GetWorldElapsedTime = function()
      return 1, 0
    end,
  }
  return env
end

local function FindTtkFrame(env)
  for _, frame in ipairs(env.createdFrames) do
    if frame._events and frame._events.PLAYER_REGEN_DISABLED and type(frame._scripts.OnEvent) == "function" then
      return frame
    end
  end
  return nil
end

-- Loads the modules, installs TTK, starts the key (when wanted) and returns a
-- dispatcher for the TTK frame's real OnEvent script.
local function Setup(env, LoadAddonModules, extraFiles)
  local files = { "isiLive_mplus_timer.lua", "isiLive_ttk.lua" }
  for _, file in ipairs(extraFiles or {}) do
    files[#files + 1] = file
  end
  local addon = LoadAddonModules(files)
  addon.TTK.Install()
  if env.keyRunning then
    addon.MplusTimer.HandleEvent("CHALLENGE_MODE_START")
  end
  local frame = assert(FindTtkFrame(env), "TTK must create its own event frame")
  local function Fire(event, arg1)
    if event == "PLAYER_REGEN_DISABLED" then
      env.inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
      env.inCombat = false
    end
    frame._scripts.OnEvent(frame, event, arg1)
  end
  local function Tick()
    local ticker = env.tickers[#env.tickers]
    if ticker and not ticker.cancelled then
      ticker.callback()
    end
  end
  return addon, Fire, Tick, frame
end

local function RegisterClockTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TTK curve points follow t * p / (1 - p) and cap near full health", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon = Setup(env, LoadAddonModules)
      local points = addon.TTK.BuildPoints(10)
      local byP = {}
      for _, pt in ipairs(points) do
        byP[pt[1]] = pt[2]
      end
      Assert.Equal(byP[0], 0, "a dead-even target has no time left")
      Assert.Equal(byP[0.5], 10, "half health after 10 s leaves 10 s")
      Assert.True(math.abs(byP[0.9] - 90) < 1e-9, "90% health after 10 s leaves 90 s")
      Assert.Equal(byP[0.99], 999, "near full health is capped")
      Assert.Equal(byP[1], 999, "an untouched target is capped")
    end)
  end)

  test("TTK uses the nameplate clock from the mob's first damage", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules)
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "TTK %.0fs", placeholder = "TTK …" })

      env.now = 100
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 110
      Fire("UNIT_HEALTH", "nameplate1")
      env.now = 111
      Fire("UNIT_HEALTH", "nameplate1")
      env.now = 112
      Tick()
      Assert.Equal(text._text, "TTK …", "under three seconds of damage history the mob shows the placeholder")

      env.now = 120
      Fire("UNIT_HEALTH", "nameplate1")
      Tick()
      Assert.Equal(text._text, "TTK 10s", "half health 10 s after its first damage leaves 10 s")
      Assert.True(text._lastValueWasSecret, "the value reaches the FontString as the secret it is")

      env.now = 124
      Tick()
      Assert.Equal(text._text, "TTK 6s", "between hits the estimate counts down evenly instead of creeping up")

      env.now = 125
      env.hp = 0.25
      Fire("UNIT_HEALTH", "nameplate1")
      Tick()
      Assert.Equal(text._text, "TTK 5s", "a new hit re-measures the pace: 15 s for 75% leaves 5 s")
    end)
  end)

  test("TTK finds the target's nameplate through UnitIsUnit when the target lookup is empty", function()
    local env = BuildEnv()
    env.targetLookupEmpty = true
    env.target.plateToken = "nameplate3"
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules)
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "%.0f" })
      Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
      Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
      env.now = 100
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 110
      Fire("UNIT_HEALTH", "nameplate1")
      Fire("UNIT_HEALTH", "nameplate3")
      Fire("PLAYER_TARGET_CHANGED")
      Assert.Equal(addon.TTK.GetTargetPlateToken(), "nameplate3", "the visible plate matching the target is found")
      env.now = 130
      Fire("UNIT_HEALTH", "nameplate3")
      Tick()
      Assert.Equal(text._text, "20", "the target's own nameplate clock is used")

      -- Like the client: a removed plate's token no longer matches the target.
      env.target.plateToken = nil
      Fire("NAME_PLATE_UNIT_REMOVED", "nameplate3")
      Assert.Nil(addon.TTK.GetTargetPlateToken(), "a removed plate is no longer the target's")
    end)
  end)

  test("TTK finds a target plate that was visible before its frame existed", function()
    local env = BuildEnv()
    env.targetLookupEmpty = true
    env.target.plateToken = "nameplate7"
    WithGlobals(env.globals, function()
      local addon, Fire = Setup(env, LoadAddonModules)
      -- No NAME_PLATE_UNIT_ADDED for nameplate7: it existed before the install.
      Fire("PLAYER_TARGET_CHANGED")
      Assert.Equal(addon.TTK.GetTargetPlateToken(), "nameplate7", "the fixed-token scan finds the target's plate")
    end)
  end)

  test("TTK falls back to the combat clock and restarts recycled nameplate tokens", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules)
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "%.0f" })

      env.now = 100
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 120
      Tick()
      Assert.Equal(text._text, "20", "without an own clock the fight start is used")

      Fire("UNIT_HEALTH", "nameplate1")
      env.now = 130
      Fire("UNIT_HEALTH", "nameplate1")
      Tick()
      Assert.Equal(text._text, "10", "the nameplate clock wins once it runs")

      Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
      Tick()
      Assert.Equal(text._text, "30", "a recycled token drops its clock")
    end)
  end)

  test("TTK uses the encounter clock for a boss target", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules)
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "%.0f" })
      env.target.isBoss = true

      env.now = 50
      Fire("ENCOUNTER_START")
      env.now = 52
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 60
      Fire("UNIT_HEALTH", "nameplate1")
      env.now = 90
      Fire("UNIT_HEALTH", "nameplate1")
      Tick()
      Assert.Equal(text._text, "40", "a boss runs on the encounter clock, not its nameplate")
    end)
  end)
end

local function RegisterGatingTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TTK shows nothing outside combat, outside a key, when off or for a dead target", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules)
      local text = NewDisplayText()
      local hidden = 0
      addon.TTK.RegisterDisplay(text, {
        format = "%.0f",
        onHide = function()
          hidden = hidden + 1
        end,
      })
      env.now = 100
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 120
      Tick()
      Assert.Equal(text._text, "20", "baseline: a live target in a key fight")

      env.target.dead = true
      Tick()
      Assert.Equal(text._text, "", "a dead target clears the display")
      Assert.Equal(hidden, 1, "the hide hook runs once")
      Tick()
      Assert.Equal(hidden, 1, "an already hidden display is not cleared again on every tick")

      env.target.dead = false
      env.db.ttkEnabled = false
      Tick()
      Assert.Equal(text._text, "", "the setting turns the TTK off")
      env.db.ttkEnabled = nil

      Fire("PLAYER_REGEN_ENABLED")
      addon.TTK.Update()
      Assert.Equal(text._text, "", "nothing outside combat")
      Assert.True(env.tickers[#env.tickers].cancelled, "combat end stops the ticker")
    end)

    local noKey = BuildEnv({ keyRunning = false })
    WithGlobals(noKey.globals, function()
      local addon, Fire = Setup(noKey, LoadAddonModules)
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "%.0f" })
      Fire("PLAYER_REGEN_DISABLED")
      Assert.Equal(#noKey.tickers, 0, "outside a key no ticker starts")
      noKey.now = 130
      addon.TTK.Update()
      Assert.Equal(text._text, "", "outside a key nothing is shown")
    end)
  end)

  test("TTK test mode previews above the target and runs outside a key until turned off", function()
    local env = BuildEnv({ keyRunning = false })
    WithGlobals(env.globals, function()
      local addon, Fire, Tick, frame = Setup(env, LoadAddonModules)
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "%.0f" })
      Assert.True(addon.TTK.SetTestMode(true), "the test mode turns on")
      Assert.Equal(text._text, "12", "out of combat the test mode shows a sample value at once")
      env.target.exists = false
      Tick()
      Assert.Equal(text._text, "", "without a target the sample hides")
      env.target.exists = true
      Fire("PLAYER_TARGET_CHANGED")
      Assert.Equal(text._text, "12", "a new target shows the sample again")
      env.now = 100
      Fire("PLAYER_REGEN_DISABLED")
      Assert.True(frame._events.UNIT_HEALTH == true, "a test-mode fight listens for nameplate damage")
      env.now = 120
      Tick()
      Assert.Equal(text._text, "20", "a training-dummy fight shows the TTK in test mode")

      Assert.False(addon.TTK.SetTestMode(false), "the test mode turns off")
      Assert.Equal(text._text, "", "turning it off outside a key clears the display")
      Assert.True(env.tickers[#env.tickers].cancelled, "and stops the ticker")
    end)
  end)

  test("TTK listens to UNIT_HEALTH only during a key fight", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local _, Fire, _, frame = Setup(env, LoadAddonModules)
      Assert.True(not frame._events.UNIT_HEALTH, "no UNIT_HEALTH outside combat")
      Fire("PLAYER_REGEN_DISABLED")
      Assert.True(frame._events.UNIT_HEALTH == true, "a key fight listens for nameplate damage")
      Fire("PLAYER_REGEN_ENABLED")
      Assert.True(not frame._events.UNIT_HEALTH, "combat end stops listening")
    end)
  end)
end

local function RegisterRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TTK resumes a verified ongoing fight after reload regardless of timer event order", function()
    local env = BuildEnv()
    env.inCombat = true
    WithGlobals(env.globals, function()
      local addon = LoadAddonModules({ "isiLive_mplus_timer.lua", "isiLive_ttk.lua" })
      addon.TTK.Install()
      local frame = Assert.NotNil(FindTtkFrame(env), "the real event frame must exist")
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "%.0f", placeholder = "pending" })
      frame._scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD")
      Assert.Equal(#env.tickers, 0, "the timer has not been restored yet")
      addon.MplusTimer.HandleEvent("PLAYER_ENTERING_WORLD")
      for _, callback in ipairs(env.after) do
        callback()
      end
      Assert.True(addon.MplusTimer.IsRunning(), "the real timer restores the active key")
      Assert.Equal(#env.tickers, 1, "one ticker starts after all world-entry handlers")
      addon.MplusTimer.HandleEvent("PLAYER_ENTERING_WORLD")
      frame._scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD")
      for _, callback in ipairs(env.after) do
        callback()
      end
      Assert.Equal(#env.tickers, 1, "timer-first dispatch and repeated callbacks never duplicate the ticker")
      Assert.True(frame._events.UNIT_HEALTH, "health listening resumes without a new combat-start event")
      Assert.Equal(addon.TTK.GetTargetClock(), 100, "only the post-reload observation time is known")
      Assert.Equal(text._text, "pending", "no pre-reload damage duration is invented")
      env.now = 110
      frame._scripts.OnEvent(frame, "UNIT_HEALTH", "nameplate1")
      env.now = 120
      frame._scripts.OnEvent(frame, "UNIT_HEALTH", "nameplate1")
      env.tickers[1].callback()
      Assert.Equal(text._text, "10", "fresh health observations produce a normal estimate")
      frame._scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED")
      Assert.True(env.tickers[1].cancelled, "combat end cancels the recovered ticker")
    end)
  end)

  test("TTK leaves a masked startup combat state unresolved", function()
    local env = BuildEnv()
    env.inCombat = Secret(true)
    WithGlobals(env.globals, function()
      local addon, Fire, _, frame = Setup(env, LoadAddonModules)
      Fire("PLAYER_ENTERING_WORLD")
      for _, callback in ipairs(env.after) do
        callback()
      end
      Assert.Equal(#env.tickers, 0, "a masked combat answer must not start work")
      Assert.Nil(addon.TTK.GetTargetClock(), "no combat clock is manufactured")
      Assert.False(frame._events.UNIT_HEALTH == true, "the health listener stays off")
    end)
  end)

  test("TTK settings wake an ongoing fight and display defaults restart it", function()
    local env = BuildEnv({ db = { ttkEnabled = false } })
    env.globals.Settings = {
      RegisterCanvasLayoutCategory = function(canvas, name)
        return { canvas = canvas, name = name }
      end,
      RegisterAddOnCategory = function() end,
    }
    WithGlobals(env.globals, function()
      local addon, Fire, Tick, eventFrame = Setup(env, LoadAddonModules, {
        "isiLive_ui_common.lua",
        "isiLive_settings.lua",
      })
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "%.0f" })
      local panel = addon.SettingsPanel.Create({
        getL = function()
          return {}
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return env.db
        end,
      })
      local check, reset
      for _, frame in ipairs(env.createdFrames) do
        if frame._settingKey == "SETTINGS_TTK" then
          check = frame
        elseif frame._settingKey == "SETTINGS_DISPLAY_RESET" then
          reset = frame
        end
      end
      check = Assert.NotNil(check, "the real TTK checkbox must exist")
      reset = Assert.NotNil(reset, "the real display reset must exist")
      Fire("PLAYER_REGEN_DISABLED")
      Assert.Equal(#env.tickers, 0, "a disabled fight starts no ticker")
      check:SetChecked(true)
      check._scripts.OnClick(check)
      Assert.Equal(#env.tickers, 1, "enabling starts the missing ticker immediately")
      Assert.True(eventFrame._events.UNIT_HEALTH, "enabling starts health observations")
      env.now = 110
      Fire("UNIT_HEALTH", "nameplate1")
      env.now = 120
      Fire("UNIT_HEALTH", "nameplate1")
      Tick()
      Assert.Equal(text._text, "10", "the existing fight updates without another combat-start event")
      check:SetChecked(false)
      check._scripts.OnClick(check)
      Assert.True(env.tickers[1].cancelled, "disabling cancels the ticker immediately")
      Assert.False(eventFrame._events.UNIT_HEALTH == true, "disabling stops the health listener")
      Assert.Equal(text._text, "", "disabling clears the display immediately")
      reset._scripts.OnClick(reset)
      Assert.True(env.db.ttkEnabled, "display defaults restore TTK")
      Assert.Equal(#env.tickers, 2, "display defaults wake the current fight")
      Assert.True(eventFrame._events.UNIT_HEALTH, "display defaults restore the listener")
      panel.Refresh()
      Assert.True(check:GetChecked(), "the checkbox mirrors the restored value")
      Fire("PLAYER_REGEN_ENABLED")
    end)
  end)

  test("TTK raid hard off stops its own frame work and resumes after raid return", function()
    local env = BuildEnv()
    local lookups = 0
    local unitIsUnit = env.globals.UnitIsUnit
    env.globals.UnitIsUnit = function(...)
      lookups = lookups + 1
      return unitIsUnit(...)
    end
    local plateReads = 0
    local getPlate = env.globals.C_NamePlate.GetNamePlateForUnit
    env.globals.C_NamePlate.GetNamePlateForUnit = function(...)
      plateReads = plateReads + 1
      return getPlate(...)
    end
    WithGlobals(env.globals, function()
      local addon, Fire, Tick, frame = Setup(env, LoadAddonModules)
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "%.0f" })
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 120
      Tick()
      Assert.Equal(text._text, "20", "precondition: a key fight shows TTK")
      env.inRaid = true
      Fire("GROUP_ROSTER_UPDATE")
      local debugCount = #env.db.ttkDebug
      local previousLookups, previousPlateReads = lookups, plateReads
      Assert.True(env.tickers[1].cancelled, "raid entry cancels the independent ticker")
      Assert.False(frame._events.UNIT_HEALTH == true, "raid entry stops health listening")
      Assert.Equal(text._text, "", "raid entry clears the display")
      Fire("PLAYER_TARGET_CHANGED")
      Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
      Fire("UNIT_HEALTH", "nameplate1")
      Fire("PLAYER_REGEN_DISABLED")
      Fire("PLAYER_REGEN_ENABLED")
      addon.TTK.SetTestMode(true)
      addon.TTK.Update()
      Assert.Equal(lookups, previousLookups, "no unit matching happens in raid, including test mode")
      Assert.Equal(plateReads, previousPlateReads, "no nameplate lookup happens in raid")
      Assert.Equal(#env.db.ttkDebug, debugCount, "raid events do not append diagnostic output")
      addon.TTK.SetTestMode(false)
      env.inRaid = false
      env.inCombat = true
      Fire("GROUP_ROSTER_UPDATE")
      Assert.Equal(#env.tickers, 2, "raid return restores work for a verified ongoing key fight")
      Assert.True(frame._events.UNIT_HEALTH, "raid return restores health listening")
    end)
  end)

  test("TTK excluded fights never scan nameplates through diagnostics", function()
    for _, opts in ipairs({ { keyRunning = false }, { db = { ttkEnabled = false } } }) do
      local env = BuildEnv(opts)
      local lookups = 0
      env.globals.UnitIsUnit = function()
        lookups = lookups + 1
        return false
      end
      env.globals.C_NamePlate.GetNamePlateForUnit = function()
        lookups = lookups + 1
        return nil
      end
      WithGlobals(env.globals, function()
        local addon, Fire = Setup(env, LoadAddonModules)
        Fire("PLAYER_REGEN_DISABLED")
        Fire("PLAYER_TARGET_CHANGED")
        addon.TTK.Update()
        Assert.Equal(lookups, 0, "neither disabled TTK nor a non-key fight may scan through Trace")
        Assert.Equal(#env.tickers, 0, "excluded fights have no ticker")
      end)
    end
  end)
end

local function RegisterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TTKNameplate keeps the real overlay font bonus across updates and font size changes", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules, {
        "isiLive_mob_nameplate.lua",
        "isiLive_ttk_nameplate.lua",
      })
      local anchor = env.globals.CreateFrame("Frame")
      -- The client health-bar resolver is the only UI seam; font application
      -- and TTK display updates both run through their real production modules.
      addon.MobNameplate.ResolveTtkAnchor = function()
        return anchor
      end
      addon.TTKNameplate.Install()
      local plate
      for _, frame in ipairs(env.createdFrames) do
        if frame.text and frame.plate then
          plate = frame
        end
      end
      plate = Assert.NotNil(plate, "the nameplate display must exist")
      plate.text.SetFormattedText = NewDisplayText().SetFormattedText
      plate.text.SetTextHeight = function(self, height)
        self._textHeight = height
      end
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 120
      for _ = 1, 3 do
        Tick()
        local _, size = plate.text:GetFont()
        Assert.Equal(size, 16, "every update keeps the default 14 plus 2 point font")
        Assert.Equal(plate.text._textHeight, 16, "rendered text height keeps the same bonus")
      end
      addon.MobNameplate.SetAppearance({ fontSize = 18 })
      for _ = 1, 2 do
        Tick()
        local _, size = plate.text:GetFont()
        Assert.Equal(size, 20, "a changed overlay setting keeps its bonus on subsequent updates")
        Assert.Equal(plate.text._textHeight, 20, "rendered text height follows the new setting plus bonus")
      end
    end)
  end)

  local ROW_FILES = { "isiLive_ui_common.lua", "isiLive_roster_panel_helpers.lua", "isiLive_roster_panel_kill_row.lua" }

  test("CreateKillTrackRow registers a right-aligned TTK text in the pace line", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules, ROW_FILES)
      local row = addon._RosterInternal.CreateKillTrackRow(env.globals.CreateFrame("Frame", nil, nil))
      local ttkText = Assert.NotNil(row.killTrackTtkText, "the kill row must create a TTK text")
      Assert.Equal(ttkText._justifyH, "RIGHT", "the TTK text is right-aligned")
      ttkText.SetFormattedText = NewDisplayText().SetFormattedText

      env.now = 100
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 101
      Tick()
      Assert.Equal(ttkText._text, "TTK …", "the window shows the pending text first")
      env.now = 120
      Tick()
      Assert.Equal(ttkText._text, "TTK 20s", "the window shows the target TTK")
    end)
  end)

  test("TTKNameplate sits centred in the resolved health bar on a dark plate and hides without one", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules, { "isiLive_ttk_nameplate.lua" })
      local anchor = {
        GetFrameStrata = function()
          return "MEDIUM"
        end,
        GetFrameLevel = function()
          return 4
        end,
      }
      local fontApplied = 0
      addon.MobNameplate = {
        ResolveTtkAnchor = function()
          return anchor
        end,
        ApplyOverlayFont = function()
          fontApplied = fontApplied + 1
        end,
      }
      Assert.True(addon.TTKNameplate.Install(), "the nameplate text installs")
      local frame
      for _, f in ipairs(env.createdFrames) do
        if f.text and f.text._fontObject == "GameFontNormalOutline" then
          frame = f
        end
      end
      frame = Assert.NotNil(frame, "the nameplate text frame must exist")
      frame.text.SetFormattedText = NewDisplayText().SetFormattedText

      env.now = 100
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 130
      Tick()
      Assert.Equal(frame.text._text, "30s", "the nameplate shows the target TTK")
      Assert.Equal(frame._point[1], "CENTER", "the plate is centred")
      Assert.Equal(frame._point[2], anchor, "anchored to the resolved health bar")
      Assert.Equal(frame._point[3], "CENTER", "inside the health bar")
      Assert.NotNil(frame.plate, "a dark plate sits behind the number")
      Assert.True(fontApplied > 0, "the forces overlay font is applied")

      addon.MobNameplate.ResolveTtkAnchor = function()
        return nil
      end
      Tick()
      Assert.True(frame.hidden == true or frame._shown == false, "without an anchor the text hides")
    end)
  end)
end

local function RegisterImportantTargetTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TTK shows only for bosses, minibosses and casters by default, from game data", function()
    local env = BuildEnv()
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules)
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "%.0f" })
      env.now = 100
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 120

      Tick()
      Assert.Equal(text._text, "20", "a miniboss (elite above the player's level) shows the TTK")

      env.target.level = 90
      Tick()
      Assert.Equal(text._text, "", "a plain elite on the player's level is trash and hides the TTK")

      env.target.mana = true
      Tick()
      Assert.Equal(text._text, "20", "an elite with mana is a caster and shows the TTK")

      env.target.mana = false
      env.target.lieutenant = true
      Tick()
      Assert.Equal(text._text, "20", "a lieutenant shows the TTK")

      env.target.lieutenant = false
      env.target.classification = "normal"
      env.target.isBoss = true
      Tick()
      Assert.Equal(text._text, "20", "a boss unit shows the TTK")

      env.target.isBoss = false
      Tick()
      Assert.Equal(text._text, "", "a normal mob hides the TTK")

      env.db.ttkImportantOnly = false
      Tick()
      Assert.Equal(text._text, "20", "with the filter off every enemy target shows the TTK")
    end)
  end)

  test("TTK test mode ignores the important-target filter", function()
    local env = BuildEnv({ keyRunning = false })
    env.target.classification = "normal"
    env.target.level = 1
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules)
      local text = NewDisplayText()
      addon.TTK.RegisterDisplay(text, { format = "%.0f" })
      addon.TTK.SetTestMode(true)
      env.now = 100
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 120
      Tick()
      Assert.Equal(text._text, "20", "a training dummy shows the TTK in test mode")
    end)
  end)
end

local function RegisterTestPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  test("TTK test panel shows value and state only while the test mode is on", function()
    local env = BuildEnv({ keyRunning = false })
    WithGlobals(env.globals, function()
      local addon, Fire, Tick = Setup(env, LoadAddonModules, { "isiLive_ttk_test_panel.lua" })
      Assert.True(addon.TTKTestPanel.Install(), "the test panel installs")
      local panel
      for _, f in ipairs(env.createdFrames) do
        if f._width == 460 then
          panel = f
        end
      end
      panel = Assert.NotNil(panel, "the panel frame must exist")
      Assert.True(panel.hidden == true or panel._shown == false, "the panel starts hidden")

      addon.TTK.SetTestMode(true)
      Assert.True(panel.hidden ~= true and panel._shown ~= false, "the test mode shows the panel")

      env.now = 100
      Fire("PLAYER_REGEN_DISABLED")
      env.now = 120
      Tick()
      Assert.True(panel.hidden ~= true and panel._shown ~= false, "the panel stays up during a test-mode fight")

      addon.TTK.SetTestMode(false)
      Assert.True(panel.hidden == true or panel._shown == false, "turning the test mode off hides the panel")
    end)
  end)
end

local function RegisterSettingTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Settings TTK toggle is default-on and persists", function()
    local createFrameStub, createdFrames = BuildCreateFrameStub()
    local db = {}
    WithGlobals({
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrameStub,
      Settings = {
        RegisterCanvasLayoutCategory = function(canvas, name)
          return { canvas = canvas, name = name }
        end,
        RegisterAddOnCategory = function() end,
      },
    }, function()
      local addon = LoadAddonModules({
        "isiLive_db_schema.lua",
        "isiLive_ui_common.lua",
        "isiLive_ttk.lua",
        "isiLive_settings.lua",
      })
      local fresh = {}
      addon.DBSchema.Sanitize(fresh)
      Assert.True(fresh.ttkEnabled, "the schema default must be on")
      Assert.True(addon.TTK.IsEnabled(), "a fresh install reads the setting as on")

      local panel = addon.SettingsPanel.Create({
        getL = function()
          return { SETTINGS_TTK = "M+: Time to kill" }
        end,
        getCurrentLocale = function()
          return "enUS"
        end,
        setLanguage = function() end,
        getDB = function()
          return db
        end,
      })
      local check = nil
      for _, frame in ipairs(createdFrames) do
        if frame._frameType == "CheckButton" and frame._settingKey == "SETTINGS_TTK" then
          check = frame
        end
      end
      check = Assert.NotNil(check, "the display section must render the TTK toggle")
      Assert.True(check:GetChecked(), "the toggle must default to on")
      check:SetChecked(false)
      check._scripts.OnClick(check)
      Assert.False(db.ttkEnabled, "turning it off must persist false")
      Assert.False(addon.TTK.IsEnabled(), "the module must read the persisted off state")
      panel.Refresh()
      Assert.False(check:GetChecked(), "refresh must mirror the stored off state")
    end)
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterClockTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterGatingTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRecoveryTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterImportantTargetTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTestPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSettingTests(test, Assert, WithGlobals, LoadAddonModules)
end
