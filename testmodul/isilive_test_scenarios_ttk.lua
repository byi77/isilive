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
    target = { exists = true, canAttack = true, dead = false, plateToken = "nameplate1", isBoss = false },
    db = opts.db or {},
    keyRunning = opts.keyRunning ~= false,
    tickers = {},
    curves = {},
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
      After = function() end,
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

local function RegisterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
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

  test("TTKNameplate sits above the resolved health bar and hides without one", function()
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
      Assert.Equal(frame._point[1], "BOTTOM", "the text grows upwards")
      Assert.Equal(frame._point[2], anchor, "anchored to the resolved health bar")
      Assert.Equal(frame._point[3], "TOP", "above the health bar")
      Assert.True(frame._point[5] > 0, "clear of the name line above the bar")
      Assert.True(fontApplied > 0, "the forces overlay font is applied")

      addon.MobNameplate.ResolveTtkAnchor = function()
        return nil
      end
      Tick()
      Assert.True(frame.hidden == true or frame._shown == false, "without an anchor the text hides")
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
  RegisterDisplayTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterTestPanelTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterSettingTests(test, Assert, WithGlobals, LoadAddonModules)
end
