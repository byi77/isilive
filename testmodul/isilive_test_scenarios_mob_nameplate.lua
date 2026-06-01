---@diagnostic disable: undefined-global, undefined-field

-- Scenarios for ui/isiLive_mob_nameplate.lua.
-- The module attaches a FontString overlay to each enemy nameplate in an
-- active Mythic+ keystone and renders the unit's progress contribution via
-- C_ScenarioInfo.GetUnitCriteriaProgressValues(unit). We stub Blizzard's
-- nameplate + scenario APIs, drive UpdateNameplate via the test helper, and
-- assert on the resulting frame/text state.

local function MakeFontString()
  local fs = { _text = "", _points = nil, _color = nil, _font = nil, _justifyH = nil, _setFontCallCount = 0 }
  function fs:SetText(text)
    self._text = tostring(text or "")
  end
  function fs:SetPoint(...)
    self._points = { ... }
  end
  function fs:ClearAllPoints()
    self._points = nil
  end
  function fs:SetJustifyH(justify)
    self._justifyH = justify
  end
  function fs:SetTextColor(r, g, b, a)
    self._color = { r, g, b, a }
  end
  function fs:SetFont(file, size, flags)
    self._font = { file = file, size = size, flags = flags }
    self._setFontCallCount = self._setFontCallCount + 1
  end
  function fs:GetFont()
    if not self._font then
      return nil, nil, nil
    end
    return self._font.file, self._font.size, self._font.flags
  end
  function fs:SetTextHeight(size)
    if self._font then
      self._font.size = size
    else
      self._font = { file = nil, size = size, flags = nil }
    end
  end
  function fs:SetFontObject(_obj)
    -- Mock: detaching the FontObject template is a no-op for these tests.
  end
  function fs:SetDrawLayer(_layer, _sublayer)
    -- Mock: draw layer is captured implicitly, no behaviour needed.
  end
  function fs:GetText()
    return self._text
  end
  return fs
end

-- Stand-in for the global FontObject `GameFontNormalOutline` that ApplyFont
-- queries via `GetFont()` to inherit the template's font-file + flags.
-- Returns deterministic values so the SetFont assertions can compare exactly.
local function MakeGameFontNormalOutline()
  return {
    GetFont = function(_self)
      return "Fonts\\\\FRIZQT__.TTF", 10, "OUTLINE"
    end,
  }
end

local function MakeFrame()
  local f = {
    _shown = false,
    _points = nil,
    _size = nil,
    _strata = nil,
    _ignoreParentAlpha = nil,
    _scripts = {},
    _events = {},
  }
  function f:SetSize(w, h)
    self._size = { w, h }
  end
  function f:SetFrameStrata(s)
    self._strata = s
  end
  function f:SetIgnoreParentAlpha(flag)
    self._ignoreParentAlpha = flag
  end
  function f:SetPoint(...)
    self._points = { ... }
  end
  function f:ClearAllPoints()
    self._points = nil
  end
  function f:Show()
    self._shown = true
  end
  function f:Hide()
    self._shown = false
  end
  function f:IsShown()
    return self._shown == true
  end
  function f:SetScript(name, fn)
    self._scripts[name] = fn
  end
  function f:GetScript(name)
    return self._scripts[name]
  end
  function f:RegisterEvent(event)
    self._events[event] = true
  end
  function f:UnregisterEvent(event)
    self._events[event] = nil
  end
  function f:UnregisterAllEvents()
    self._events = {}
  end
  function f:CreateFontString(_name, _layer, _template)
    return MakeFontString()
  end
  return f
end

local function BuildEnv(overrides)
  overrides = overrides or {}
  local createdFrames = {}
  local state = {
    challengeActive = overrides.challengeActive,
    mapID = overrides.mapID,
    units = overrides.units or {},
    nameplates = overrides.nameplates or {},
    progressValues = overrides.progressValues or {},
    scenarioCriteria = overrides.scenarioCriteria,
  }
  if state.challengeActive == nil then
    state.challengeActive = true
  end
  if state.mapID == nil then
    state.mapID = 161
  end

  local globals = {
    CreateFrame = function()
      local f = MakeFrame()
      table.insert(createdFrames, f)
      return f
    end,
    UIParent = {},
    UnitExists = overrides.UnitExists or function(unit)
      return state.units[unit] ~= nil
    end,
    UnitGUID = overrides.UnitGUID or function(unit)
      local u = state.units[unit]
      return u and u.guid or nil
    end,
    UnitReaction = overrides.UnitReaction or function(unit)
      local u = state.units[unit]
      if u and u.reaction then
        return u.reaction
      end
      return 2
    end,
    C_NamePlate = overrides.C_NamePlate or {
      GetNamePlateForUnit = function(unit)
        return state.nameplates[unit]
      end,
    },
    C_ChallengeMode = overrides.C_ChallengeMode or {
      IsChallengeModeActive = function()
        return state.challengeActive == true
      end,
      GetActiveChallengeMapID = function()
        return state.mapID
      end,
    },
    C_ScenarioInfo = overrides.C_ScenarioInfo or {
      GetUnitCriteriaProgressValues = function(unit)
        local v = state.progressValues[unit]
        if not v then
          return nil
        end
        return v.count, v.total, v.percent
      end,
      GetStepInfo = function()
        if state.scenarioCriteria then
          return { numCriteria = #state.scenarioCriteria }
        end
        return { numCriteria = 0 }
      end,
      GetCriteriaInfo = function(idx)
        if state.scenarioCriteria then
          return state.scenarioCriteria[idx]
        end
        return nil
      end,
    },
    issecretvalue = overrides.issecretvalue,
    GameFontNormalOutline = overrides.GameFontNormalOutline or MakeGameFontNormalOutline(),
  }

  if overrides.globals then
    for k, v in pairs(overrides.globals) do
      globals[k] = v
    end
  end

  return globals, state, createdFrames
end

local function LoadModule(LoadAddonModules, addonOverrides)
  return LoadAddonModules({ "isiLive_mob_nameplate.lua" }, addonOverrides)
end

local function RegisterLifecycleTests(test, Assert, WithGlobals, LoadAddonModules)
  test("MobNameplate.Register reports success when nameplate API is present", function()
    local globals = BuildEnv()
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      local ok = addon.MobNameplate.Register()
      Assert.True(ok, "Register() must succeed when C_NamePlate is available")
    end)
  end)

  test("MobNameplate.Register reports success when C_ScenarioInfo is missing", function()
    local globals = BuildEnv({ C_ScenarioInfo = false })
    globals.C_ScenarioInfo = nil
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      local ok = addon.MobNameplate.Register()
      Assert.True(ok, "Register() must not depend on C_ScenarioInfo")
    end)
  end)

  test("MobNameplate.Register reports failure when C_NamePlate is missing", function()
    local globals = BuildEnv({ C_NamePlate = false })
    globals.C_NamePlate = nil
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      local ok = addon.MobNameplate.Register()
      Assert.False(ok, "Register() must fail without C_NamePlate")
    end)
  end)

  test("MobNameplate.SetEnabled(true) registers nameplate + challenge events on a tracker frame", function()
    local globals, _state, frames = BuildEnv()
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)

      local eventFrame = nil
      for _, f in ipairs(frames) do
        if f._events and next(f._events) ~= nil then
          eventFrame = f
          break
        end
      end
      eventFrame = Assert.NotNil(eventFrame, "SetEnabled(true) must register events on a dedicated frame")
      Assert.True(eventFrame._events["NAME_PLATE_UNIT_ADDED"] == true, "NAME_PLATE_UNIT_ADDED must be registered")
      Assert.True(eventFrame._events["NAME_PLATE_UNIT_REMOVED"] == true, "NAME_PLATE_UNIT_REMOVED must be registered")
      Assert.True(eventFrame._events["CHALLENGE_MODE_START"] == true, "CHALLENGE_MODE_START must be registered")
      Assert.True(eventFrame._events["PLAYER_ENTERING_WORLD"] == true, "PLAYER_ENTERING_WORLD must be registered")
      Assert.True(eventFrame._events["SCENARIO_UPDATE"] == true, "SCENARIO_UPDATE must be registered")

      addon.MobNameplate.SetEnabled(false)
      Assert.True(next(eventFrame._events) == nil, "SetEnabled(false) must unregister all events")
    end)
  end)

  test("MobNameplate CHALLENGE_MODE_START schedules delayed refreshes for late active-key APIs", function()
    local scheduled = {}
    local globals, state, frames = BuildEnv({
      challengeActive = false,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
      globals = {
        C_Timer = {
          After = function(delay, fn)
            scheduled[#scheduled + 1] = { delay = delay, fn = fn }
          end,
        },
      },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)

      local eventFrame = nil
      for _, f in ipairs(frames) do
        if f._scripts and type(f._scripts.OnEvent) == "function" then
          eventFrame = f
          break
        end
      end
      eventFrame = Assert.NotNil(eventFrame, "event frame with OnEvent script must exist")

      eventFrame._scripts.OnEvent(eventFrame, "CHALLENGE_MODE_START")
      Assert.Equal(#scheduled, 2, "challenge start must queue delayed refreshes after the immediate refresh")
      Assert.True(
        addon.MobNameplate._Test_GetFrames()["nameplate1"] == nil,
        "immediate refresh still respects inactive API state"
      )

      state.challengeActive = true
      scheduled[1].fn()
      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "delayed refresh must render once the active-key API state is available")
      Assert.True(frame._shown == true, "delayed challenge refresh must show the nameplate overlay")
      Assert.Equal(frame.text._text, "1.16%", "delayed challenge refresh must render the percent text")
    end)
  end)
end

local function RegisterRenderTests(test, Assert, WithGlobals, LoadAddonModules)
  test("MobNameplate renders percent text for an eligible hostile unit in an active key", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local pool = addon.MobNameplate._Test_GetFrames()
      local frame = pool["nameplate1"]
      Assert.True(frame ~= nil, "frame must be created for eligible nameplate")
      Assert.True(frame._shown == true, "frame must be visible")
      Assert.Equal(frame.text._text, "1.16%", "default format renders the percent string with a trailing %")
    end)
  end)

  test("MobNameplate appends remaining dungeon percent when enabled and KillTrack has matching map data", function()
    local globals = BuildEnv({
      mapID = 161,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules, {
        KillTrack = {
          GetData = function()
            return {
              active = true,
              mapID = 161,
              percent = 75.66,
              total = 431,
            }
          end,
        },
      })
      addon.MobNameplate.SetFormat({ showPercent = true, showRemaining = true })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must be created for eligible nameplate")
      Assert.Equal(
        frame.text._text,
        "1.16%/24.34%",
        "remaining percent must append as current-mob percent / remaining-needed percent"
      )
    end)
  end)

  test("MobNameplate omits remaining percent when KillTrack map does not match", function()
    local globals = BuildEnv({
      mapID = 161,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules, {
        KillTrack = {
          GetData = function()
            return {
              active = true,
              mapID = 999,
              percent = 75.66,
              total = 431,
            }
          end,
        },
      })
      addon.MobNameplate.SetFormat({ showPercent = true, showRemaining = true })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must be created for eligible nameplate")
      Assert.Equal(frame.text._text, "1.16%", "mismatched KillTrack map must not invent a remaining value")
    end)
  end)

  test("MobNameplate hides text for friendly units (reaction > 4)", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 5 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      Assert.True(frame == nil, "no frame should be created for a friendly unit (reaction > 4)")
    end)
  end)

  test("MobNameplate hides text when the key is not active", function()
    local globals = BuildEnv({
      challengeActive = false,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      Assert.True(frame == nil, "no frame should be created when challenge mode is not active")
    end)
  end)

  test("MobNameplate falls back to API path when UnitGUID is a Secret Value", function()
    -- WoW 12.0 M+ keystones return UnitGUID as a Secret Value in the tainted
    -- addon execution context. The DB lookup correctly bails (it cannot parse
    -- an NPC id from a secret string), but the API path C_ScenarioInfo.
    -- GetUnitCriteriaProgressValues stays usable — eligibility no longer
    -- gates on the GUID's secret state, so the frame still renders.
    local secret = "__ISILIVE_TEST_SECRET_GUID__"
    local globals = BuildEnv({
      units = { nameplate1 = { guid = secret, reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
      issecretvalue = function(v)
        return v == secret
      end,
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "Secret GUID must not block the API-fallback render path")
      Assert.True(frame._shown == true, "frame must be visible when the API path supplies a non-secret percent")
    end)
  end)

  test("MobNameplate renders Secret-Valued percentString through to the FontString", function()
    -- WoW 12.0 M+ tainted context returns most unit-derived data as Secret
    -- Values, including the percent string from
    -- C_ScenarioInfo.GetUnitCriteriaProgressValues. The FontString renderer
    -- can still display the masked text — only Lua-side reads are blocked.
    -- Filtering Secret Values out at the data path would leave every M+
    -- nameplate empty, so the module passes them straight through.
    local secret = "__ISILIVE_TEST_SECRET_PERCENT__"
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-99999-99999-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = secret } },
      issecretvalue = function(v)
        return v == secret
      end,
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "Secret-Valued percentString must still produce a frame")
      Assert.True(frame._shown == true, "frame must be visible — WoW's renderer handles the masked text")
    end)
  end)

  test("MobNameplate hides and drops the pool entry after NAME_PLATE_UNIT_REMOVED", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")
      Assert.True(addon.MobNameplate._Test_GetFrames()["nameplate1"] ~= nil, "frame should exist after update")

      -- Simulate NAME_PLATE_UNIT_REMOVED via the internal path: setting enabled off
      -- forces HideAll. Alternatively, the event handler is attached to a frame
      -- we cannot easily reach by name; instead we simply disable and re-enable.
      addon.MobNameplate.SetEnabled(false)
      Assert.True(addon.MobNameplate._Test_GetFrames()["nameplate1"] == nil, "disable must clear the frame pool")
    end)
  end)
end

local function RegisterDefensivePathTests(test, Assert, WithGlobals, LoadAddonModules)
  local POSITIONS = { "LEFT", "RIGHT", "TOP", "BOTTOM" }
  local EXPECTED_ANCHORS = {
    LEFT = { "RIGHT", "LEFT" },
    RIGHT = { "LEFT", "RIGHT" },
    TOP = { "BOTTOM", "TOP" },
    BOTTOM = { "TOP", "BOTTOM" },
  }
  local EXPECTED_TEXT_ANCHORS = {
    LEFT = { "RIGHT", "RIGHT", "RIGHT" },
    RIGHT = { "LEFT", "LEFT", "LEFT" },
    TOP = { "CENTER", "CENTER", "CENTER" },
    BOTTOM = { "CENTER", "CENTER", "CENTER" },
  }

  for _, pos in ipairs(POSITIONS) do
    test("MobNameplate ApplyPosition anchors correctly for position " .. pos, function()
      local globals = BuildEnv({
        units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
        nameplates = { nameplate1 = MakeFrame() },
        progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
      })
      WithGlobals(globals, function()
        local addon = LoadModule(LoadAddonModules)
        addon.MobNameplate.SetAppearance({ position = pos })
        addon.MobNameplate.SetEnabled(true)
        addon.MobNameplate._Test_UpdateNameplate("nameplate1")

        local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
        Assert.True(frame ~= nil, "frame must exist for pos=" .. pos)
        local expected = EXPECTED_ANCHORS[pos]
        Assert.Equal(frame._points[1], expected[1], "frame anchor point for pos=" .. pos)
        Assert.Equal(frame._points[3], expected[2], "nameplate anchor point for pos=" .. pos)
        local expectedText = EXPECTED_TEXT_ANCHORS[pos]
        Assert.Equal(frame.text._points[1], expectedText[1], "text anchor point for pos=" .. pos)
        Assert.Equal(frame.text._points[3], expectedText[2], "text parent anchor point for pos=" .. pos)
        Assert.Equal(frame.text._justifyH, expectedText[3], "text justification for pos=" .. pos)
      end)
    end)
  end

  test("MobNameplate ApplyPosition falls back to CENTER for unknown position", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetAppearance({ position = "DIAGONAL" })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      Assert.True(frame ~= nil, "frame must exist for unknown position")
      Assert.Equal(frame._points[1], "CENTER", "unknown position falls back to CENTER anchor")
      Assert.Equal(frame._points[3], "CENTER", "unknown position falls back to CENTER nameplate anchor")
    end)
  end)

  test("MobNameplate hides nothing and creates no frame when CreateFrame pcall throws", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    globals.CreateFrame = function()
      error("createframe blew up in test")
    end
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      -- SetEnabled tries to create the event frame via CreateFrame pcall.
      -- The module must swallow the failure and not crash the caller.
      addon.MobNameplate.SetEnabled(true)
      Assert.True(
        addon.MobNameplate._Test_GetFrames()["nameplate1"] == nil,
        "no frame should be created when CreateFrame pcall fails"
      )
    end)
  end)

  test("MobNameplate hides unit when UnitReaction returns a Secret Value", function()
    local secret = "__ISILIVE_TEST_SECRET_REACTION__"
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
      UnitReaction = function()
        return secret
      end,
      issecretvalue = function(v)
        return v == secret
      end,
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      -- A Secret-Valued reaction must not taint the unit-eligibility check.
      -- The module should ignore reaction > 4 when reaction is secret, so
      -- rendering proceeds (reaction defaults to "hostile" when unreadable).
      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      Assert.True(frame ~= nil, "Secret-Valued reaction must not crash; unit treated as eligible")
    end)
  end)

  test("MobNameplate NAME_PLATE_UNIT_REMOVED OnEvent hides frame and clears pool entry", function()
    local globals, _, frames = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")
      Assert.True(
        addon.MobNameplate._Test_GetFrames()["nameplate1"] ~= nil,
        "frame should exist before NAME_PLATE_UNIT_REMOVED"
      )

      -- Find the event frame (the one with scripts) and drive its OnEvent handler.
      local eventFrame = nil
      for _, f in ipairs(frames) do
        if f._scripts and type(f._scripts.OnEvent) == "function" then
          eventFrame = f
          break
        end
      end
      eventFrame = Assert.NotNil(eventFrame, "event frame with OnEvent script must exist")
      eventFrame._scripts.OnEvent(eventFrame, "NAME_PLATE_UNIT_REMOVED", "nameplate1")

      Assert.True(
        addon.MobNameplate._Test_GetFrames()["nameplate1"] == nil,
        "NAME_PLATE_UNIT_REMOVED must clear the pool entry for the removed unit"
      )
    end)
  end)

  test("MobNameplate SetFormat during enabled=true triggers RefreshAll", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")
      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      Assert.Equal(frame.text._text, "1.16%", "initial render uses default format")

      -- Flip showPercent off: RefreshAll should re-apply to all active frames and
      -- produce empty text, which hides the frame.
      addon.MobNameplate.SetFormat({ showPercent = false })
      Assert.True(frame._shown == false, "frame is hidden after SetFormat removes the only visible part")
    end)
  end)

  test("MobNameplate SetAppearance during enabled=true re-applies font size", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      addon.MobNameplate.SetAppearance({ fontSize = 19 })
      local state = addon.MobNameplate._Test_GetState()
      Assert.Equal(state.appearance.fontSize, 19, "fontSize must be persisted in module state")
    end)
  end)
end

local function RegisterFontSizeTests(test, Assert, WithGlobals, LoadAddonModules)
  test("MobNameplate ApplyFont calls SetFont with the configured fontSize on initial frame creation", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetAppearance({ fontSize = 22 })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must exist after update")
      local font = frame.text._font
      font = Assert.NotNil(font, "ApplyFont must call SetFont on the FontString")
      Assert.Equal(font.size, 22, "initial frame must use the configured fontSize, not the template default")
      Assert.True(font.file ~= nil and font.file ~= "", "SetFont must receive a non-empty font file path")
      Assert.True(
        type(font.flags) == "string" and font.flags ~= "",
        "SetFont must receive flags (e.g. OUTLINE) inherited from the template"
      )
    end)
  end)

  test("MobNameplate SetAppearance({fontSize}) during enabled re-applies SetFont with the new size", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")
      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must exist after first update")
      local initialCallCount = frame.text._setFontCallCount
      Assert.True(initialCallCount >= 1, "SetFont must have been called at least once during initial render")

      -- Slider moves to 19 mid-key; SetAppearance must trigger RefreshAll
      -- which re-runs UpdateNameplate -> ApplyFont with the new size.
      addon.MobNameplate.SetAppearance({ fontSize = 19 })
      Assert.True(
        frame.text._setFontCallCount > initialCallCount,
        "SetAppearance during enabled must trigger another SetFont call via RefreshAll"
      )
      Assert.Equal(frame.text._font.size, 19, "FontString must have the new fontSize after SetAppearance")
    end)
  end)

  test("MobNameplate re-applies configured font size when WoW reasserts template height", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetAppearance({ fontSize = 22 })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must exist after first update")
      Assert.Equal(frame.text._font.size, 22, "initial render must use the configured font size")
      local initialCallCount = frame.text._setFontCallCount

      -- Simulates a Blizzard internal refresh restoring the inherited
      -- GameFontNormalOutline height while the isiLive cache still says the
      -- requested user size was applied.
      frame.text._font.size = 10
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      Assert.True(
        frame.text._setFontCallCount > initialCallCount,
        "ApplyFont must not trust the cache when the actual FontString height changed"
      )
      Assert.Equal(frame.text._font.size, 22, "configured font size must be restored after template reassertion")
    end)
  end)

  test("MobNameplate ApplyFont falls back to default font when GameFontNormalOutline is missing", function()
    -- Simulates a runtime context where Blizzard has not (yet) registered the
    -- GameFontNormalOutline FontObject. ApplyFont must still call SetFont on
    -- the FontString with the configured size and a hardcoded fallback file
    -- so the nameplate label remains visible.
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    globals.GameFontNormalOutline = nil
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetAppearance({ fontSize = 14 })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must still be created without the template global")
      local font = Assert.NotNil(frame.text._font, "ApplyFont must still call SetFont without template")
      Assert.Equal(font.size, 14, "configured fontSize must still be honored")
      Assert.True(font.file ~= nil and font.file ~= "", "fallback font file must be non-empty")
      Assert.Equal(font.flags, "OUTLINE", "fallback flags default to OUTLINE")
    end)
  end)

  test("MobNameplate font-size pipeline is unaffected by Plater being loaded", function()
    -- Plater/Platynator soft-detect lives in the settings UI, NOT in the
    -- nameplate module itself. The module renders identically regardless of
    -- which external nameplate addon is loaded; this scenario locks that in
    -- so a future "skip if Plater" optimisation cannot silently break the
    -- font-size pipeline.
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    globals.IsAddOnLoaded = function(name)
      return name == "Plater"
    end
    globals.C_AddOns = {
      IsAddOnLoaded = function(name)
        return name == "Plater"
      end,
    }
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetAppearance({ fontSize = 16 })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must still be created when Plater is loaded -- module ignores soft-detect")
      Assert.True(frame._shown == true, "overlay must render even with Plater loaded (user opt-in)")
      local font = Assert.NotNil(frame.text._font, "SetFont must still be called when Plater is loaded")
      Assert.Equal(font.size, 16, "fontSize must still be honoured when Plater is loaded")
    end)
  end)
end

local function RegisterDebugSurfaceTests(test, Assert, WithGlobals, LoadAddonModules)
  test("MobNameplate.SetTestMode toggles testMode and renders the fake percent", function()
    local globals = BuildEnv({
      challengeActive = false,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      Assert.False(addon.MobNameplate.IsTestMode(), "test mode is off by default")

      local active = addon.MobNameplate.SetTestMode(true, "42.50")
      Assert.True(active == true, "SetTestMode(true) must return the resulting on state")
      Assert.True(addon.MobNameplate.IsTestMode(), "IsTestMode() must reflect the toggle")

      addon.MobNameplate._Test_UpdateNameplate("nameplate1")
      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "test mode must produce a frame even outside an active key")
      Assert.True(frame._shown == true, "test-mode frame must be visible")
      Assert.Equal(frame.text._text, "42.50%", "frame text must show the supplied test percent with %")

      local off = addon.MobNameplate.SetTestMode(false)
      Assert.True(off == false, "SetTestMode(false) must return the resulting off state")
      Assert.False(addon.MobNameplate.IsTestMode(), "IsTestMode() must be false after toggling off")
    end)
  end)

  test("MobNameplate.SetTestMode(nil) inverts the current state", function()
    local globals = BuildEnv({ challengeActive = false })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      local first = addon.MobNameplate.SetTestMode(nil)
      Assert.True(first == true, "first nil-toggle must turn test mode on")
      local second = addon.MobNameplate.SetTestMode(nil)
      Assert.True(second == false, "second nil-toggle must turn test mode off again")
    end)
  end)

  test("MobNameplate.DumpFrames returns appearance state and one row per active frame", function()
    local globals = BuildEnv({
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetAppearance({ fontSize = 18 })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local dump = addon.MobNameplate.DumpFrames()
      dump = Assert.NotNil(dump, "DumpFrames must return a table")
      Assert.Equal(dump.appearanceFontSize, 18, "appearance.fontSize must surface in the dump")
      Assert.Equal(dump.frameCount, 1, "exactly one frame should be active for nameplate1")
      Assert.Equal(type(dump.frames), "table", "frames field must be a table")
      local row = dump.frames[1]
      row = Assert.NotNil(row, "first frame row must exist")
      Assert.Equal(row.unit, "nameplate1", "row.unit must match the rendered unit")
      Assert.True(row.frameShown == true, "row.frameShown must reflect the rendered state")
      Assert.Equal(row.fontHeight, 18, "row.fontHeight must reflect the configured size")
      Assert.Equal(row.fontStringText, "1.16%", "row.fontStringText must reflect the rendered text")
    end)
  end)

  test("MobNameplate.DumpState reports gates and per-frame state for the queried unit", function()
    local globals = BuildEnv({
      units = { target = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { target = MakeFrame() },
      progressValues = { target = { count = 5, total = 431, percent = "1.16" } },
    })
    globals.UnitName = function(_unit)
      return "Test Mob"
    end
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetAppearance({ fontSize = 16 })
      addon.MobNameplate.SetEnabled(true)

      local state = addon.MobNameplate.DumpState("target")
      state = Assert.NotNil(state, "DumpState must return a table")
      Assert.Equal(state.unit, "target", "unit must be echoed")
      Assert.True(state.enabled == true, "enabled flag must reflect SetEnabled(true)")
      Assert.Equal(state.appearanceFontSize, 16, "appearance.fontSize must surface")
      Assert.True(state.hasNamePlateAPI == true, "C_NamePlate stub must be detected")
      Assert.True(state.hasProgressAPI == true, "C_ScenarioInfo stub must be detected")
      Assert.True(state.challengeActive == true, "challenge stub must report active")
      Assert.True(state.eligible == true, "hostile target with valid GUID must be eligible")
      Assert.Equal(state.unitName, "Test Mob", "non-secret UnitName must propagate")
      Assert.Equal(state.npcId, 76132, "GUID must parse to the embedded NPC id")
      Assert.True(state.unitNameSecret == false, "non-secret UnitName must report unitNameSecret=false")
      Assert.True(state.guidIsSecret == false, "non-secret GUID must report guidIsSecret=false")
    end)
  end)

  test("MobNameplate.DumpState redacts Secret-Value GUID, Name and apiPercent", function()
    local secretGuid = "__ISILIVE_TEST_SECRET_GUID__"
    local secretName = "__ISILIVE_TEST_SECRET_NAME__"
    local secretPercent = "__ISILIVE_TEST_SECRET_PERCENT__"
    local globals = BuildEnv({
      units = { target = { guid = secretGuid, reaction = 2 } },
      nameplates = { target = MakeFrame() },
      progressValues = { target = { count = 5, total = 431, percent = secretPercent } },
      issecretvalue = function(v)
        return v == secretGuid or v == secretName or v == secretPercent
      end,
    })
    globals.UnitName = function(_unit)
      return secretName
    end
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)

      local state = addon.MobNameplate.DumpState("target")
      Assert.Equal(state.guid, "<secret>", "Secret GUID must be redacted")
      Assert.True(state.guidIsSecret == true, "guidIsSecret must be true")
      Assert.Equal(state.unitName, "<secret>", "Secret UnitName must be redacted")
      Assert.True(state.unitNameSecret == true, "unitNameSecret must be true")
      Assert.Equal(state.apiPercent, "<secret>", "Secret apiPercent must be redacted")
      Assert.True(state.apiPercentSecret == true, "apiPercentSecret must be true")
    end)
  end)

  test("MobNameplate test mode bypasses challenge guard and renders the test percent", function()
    -- challengeActive = false simulates the "not in a key" state. With test
    -- mode on, the module must still render so the user can verify the size
    -- slider outside of a real M+.
    local globals = BuildEnv({
      challengeActive = false,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetAppearance({ fontSize = 22 })
      addon.MobNameplate.SetTestMode(true, "9.99")
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "test mode must render even without an active challenge")
      Assert.True(frame._shown == true, "test-mode frame must be visible")
      Assert.Equal(frame.text._text, "9.99%", "test percent must render with %% suffix")
      Assert.Equal(frame.text._font.size, 22, "test-mode frame must honour the configured font size")
    end)
  end)
end

-- Branch coverage: targets the rarely-exercised paths inside UpdateNameplate
-- and its helpers. ResolveMobContributionFromDB happy path (DB hits override
-- the C_ScenarioInfo API), ResolveRemainingPercent rawCount-nil percent
-- fallback, BuildText showPercent=false guard, the GetNameplate-returns-nil
-- hide path, the not-in-challenge hide path, and SetEnabled(false) cleanup.
local function RegisterBranchCoverageTests(test, Assert, WithGlobals, LoadAddonModules)
  test("MobNameplate ResolveMobContributionFromDB returns percent from MDT-synced DB and overrides the API", function()
    local globals = BuildEnv({
      mapID = 161,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      -- Set the API percent to a marker so we can prove DB wins.
      progressValues = { nameplate1 = { count = 99, total = 100, percent = "99.99" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules, {
        MPlusForces = {
          byNpcId = {
            -- npcId 76132 from the GUID above.
            [76132] = { mapID = 161, count = 25 },
          },
          dungeonTotal = {
            [161] = { total = 1000 },
          },
        },
      })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must be created when DB has a hit")
      -- 25 / 1000 = 2.50% (DB) — must beat the API "99.99".
      Assert.Equal(frame.text._text, "2.50%", "DB percent must override the API percent")
    end)
  end)

  test("MobNameplate renders DB-derived percent when ScenarioInfo progress API is unavailable", function()
    local globals = BuildEnv({
      mapID = 161,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      C_ScenarioInfo = {},
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules, {
        MPlusForces = {
          byNpcId = {
            [76132] = { mapID = 161, count = 25 },
          },
          dungeonTotal = {
            [161] = { total = 1000 },
          },
        },
      })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must be created from DB data without ScenarioInfo progress API")
      Assert.True(frame._shown == true, "DB-derived percent must render without ScenarioInfo progress API")
      Assert.Equal(frame.text._text, "2.50%", "DB-derived per-mob percent must remain the primary source")
    end)
  end)

  test(
    "MobNameplate ResolveMobContributionFromDB returns nil when DB entry's mapID does not match active key",
    function()
      local globals = BuildEnv({
        mapID = 161,
        units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
        nameplates = { nameplate1 = MakeFrame() },
        progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
      })
      WithGlobals(globals, function()
        local addon = LoadModule(LoadAddonModules, {
          MPlusForces = {
            byNpcId = {
              -- DB lists this NPC under a DIFFERENT map: must fall back to API.
              [76132] = { mapID = 999, count = 25 },
            },
            dungeonTotal = {
              [161] = { total = 1000 },
              [999] = { total = 1000 },
            },
          },
        })
        addon.MobNameplate.SetEnabled(true)
        addon.MobNameplate._Test_UpdateNameplate("nameplate1")

        local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
        frame = Assert.NotNil(frame, "API fallback must still produce a frame")
        Assert.Equal(frame.text._text, "1.16%", "mismatched DB mapID must fall through to the API value")
      end)
    end
  )

  test("MobNameplate ResolveRemainingPercent computes rawCount from percent when KillTrack omits rawCount", function()
    local globals = BuildEnv({
      mapID = 161,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules, {
        KillTrack = {
          GetData = function()
            -- No rawCount; only percent + total. 50% of 431 = 215.5; remaining
            -- = 215.5 / 431 = 50.00%.
            return { active = true, mapID = 161, total = 431, percent = 50 }
          end,
        },
      })
      addon.MobNameplate.SetFormat({ showPercent = true, showRemaining = true })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must be created")
      Assert.Equal(
        frame.text._text,
        "1.16%/50.00%",
        "remaining percent must be derived from KillTrack percent when rawCount is missing"
      )
    end)
  end)

  test("MobNameplate omits remaining percent when KillTrack reports active=false", function()
    local globals = BuildEnv({
      mapID = 161,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules, {
        KillTrack = {
          GetData = function()
            return { active = false, mapID = 161, total = 431, percent = 50 }
          end,
        },
      })
      addon.MobNameplate.SetFormat({ showPercent = true, showRemaining = true })
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      frame = Assert.NotNil(frame, "frame must be created")
      Assert.Equal(frame.text._text, "1.16%", "active=false must not append a remaining percent")
    end)
  end)

  test("MobNameplate hides the frame when SetFormat({showPercent=false}) yields nothing to render", function()
    local globals = BuildEnv({
      mapID = 161,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = MakeFrame() },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")
      -- First update creates the frame; capture it before flipping showPercent.
      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      Assert.NotNil(frame, "first update must create the frame")
      Assert.True(frame._shown == true, "frame must be visible after first render")

      addon.MobNameplate.SetFormat({ showPercent = false })
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")

      -- Frame survives but is hidden when there is nothing to render.
      Assert.True(frame._shown == false, "frame must be hidden when showPercent is disabled")
    end)
  end)

  test("MobNameplate hides any existing frame when GetNamePlateForUnit returns nil for the unit", function()
    local plate = MakeFrame()
    local globals = BuildEnv({
      mapID = 161,
      units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
      nameplates = { nameplate1 = plate },
      progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
    })
    WithGlobals(globals, function()
      local addon = LoadModule(LoadAddonModules)
      addon.MobNameplate.SetEnabled(true)
      addon.MobNameplate._Test_UpdateNameplate("nameplate1")
      local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
      Assert.True(frame and frame._shown == true, "frame must be visible after first render")

      -- Drop the nameplate from C_NamePlate's pool to simulate it disappearing
      -- from the Blizzard side (e.g. unit despawn).
      globals.C_NamePlate = {
        GetNamePlateForUnit = function()
          return nil
        end,
      }
      WithGlobals(globals, function()
        addon.MobNameplate._Test_UpdateNameplate("nameplate1")
      end)

      Assert.True(frame._shown == false, "frame must hide when the underlying nameplate disappears")
    end)
  end)

  test(
    "MobNameplate hides any existing frame when the active key ends mid-render (challenge no longer active)",
    function()
      local globals = BuildEnv({
        mapID = 161,
        units = { nameplate1 = { guid = "Creature-0-3889-161-12345-76132-0", reaction = 2 } },
        nameplates = { nameplate1 = MakeFrame() },
        progressValues = { nameplate1 = { count = 5, total = 431, percent = "1.16" } },
      })
      WithGlobals(globals, function()
        local addon = LoadModule(LoadAddonModules)
        addon.MobNameplate.SetEnabled(true)
        addon.MobNameplate._Test_UpdateNameplate("nameplate1")
        local frame = addon.MobNameplate._Test_GetFrames()["nameplate1"]
        Assert.True(frame and frame._shown == true, "frame must be visible during active key")

        -- End the key mid-session: IsChallengeModeActive flips to false.
        globals.C_ChallengeMode = {
          IsChallengeModeActive = function()
            return false
          end,
          GetActiveChallengeMapID = function()
            return nil
          end,
        }
        WithGlobals(globals, function()
          addon.MobNameplate._Test_UpdateNameplate("nameplate1")
        end)

        Assert.True(frame._shown == false, "frame must hide when the key ends")
      end)
    end
  )
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterLifecycleTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRenderTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterDefensivePathTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterFontSizeTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterDebugSurfaceTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterBranchCoverageTests(test, Assert, WithGlobals, LoadAddonModules)
end
