-- Standalone CLI tool: simulates the MobNameplate gate chain around
-- CHALLENGE_MODE_START and asserts why the percent overlay is visible or hidden.
--
-- End-to-end discipline (CLAUDE.md "Tests & simulators: end-to-end by default"):
-- the real MobNameplate module is loaded; CHALLENGE_MODE_START and
-- NAME_PLATE_UNIT_ADDED events are dispatched through the production OnEvent
-- handler that the module registers. Frame state is inspected through the
-- mock CreateFrame factory.
--
-- COMPONENT-ONLY exception (justified): this simulator calls
-- addon.MobNameplate.DumpState(unit) and addon.MobNameplate.DumpFrames(),
-- which are test-only introspection hooks the production module exposes.
-- The alternative would be reading frame state via Reflection through
-- _NameplateInternal — which violates module boundaries even more. The
-- DumpState surface is a deliberate test seam, documented as such here.
---@diagnostic disable: undefined-global
local io = io
---@diagnostic disable: undefined-global
local load = load

local function LoadLocal(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local chunk, err = (loadstring or load)(source, "@" .. path)
  assert(chunk, err)
  return chunk()
end

local Harness = LoadLocal("testmodul/isilive_test_harness.lua")
local failures = 0

local function MakeFontString()
  local fs = {
    _text = "",
    _font = { file = "Fonts\\FRIZQT__.TTF", size = 10, flags = "OUTLINE" },
    _shown = true,
    _points = {},
  }
  function fs:SetText(text)
    self._text = tostring(text or "")
  end
  function fs:GetText()
    return self._text
  end
  function fs:SetPoint(...)
    self._points[#self._points + 1] = { ... }
  end
  function fs:ClearAllPoints()
    self._points = {}
  end
  function fs:SetTextColor(_r, _g, _b, _a) end
  function fs:SetDrawLayer(_layer, _subLayer) end
  function fs:SetFont(file, size, flags)
    self._font = { file = file, size = size, flags = flags }
  end
  function fs:GetFont()
    return self._font.file, self._font.size, self._font.flags
  end
  function fs:SetTextHeight(size)
    self._font.size = size
  end
  function fs:SetFontObject(_obj) end
  function fs:Show()
    self._shown = true
  end
  function fs:Hide()
    self._shown = false
  end
  return fs
end

local function MakeFrame(kind)
  local f = {
    _kind = kind or "Frame",
    _shown = false,
    _scripts = {},
    _events = {},
    _points = {},
    _size = { 0, 0 },
  }
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
  function f:SetPoint(...)
    self._points[#self._points + 1] = { ... }
  end
  function f:ClearAllPoints()
    self._points = {}
  end
  function f:SetSize(w, h)
    self._size = { w, h }
  end
  function f:GetSize()
    return self._size[1], self._size[2]
  end
  function f:SetFrameStrata(_strata) end
  function f:SetFrameLevel(_level) end
  function f:SetIgnoreParentAlpha(_flag) end
  function f:CreateFontString(_name, _layer, _template)
    return MakeFontString()
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
  return f
end

local function CloneTable(t)
  local out = {}
  for key, value in pairs(t or {}) do
    out[key] = value
  end
  return out
end

local function ApplyFactoryNameplateDefaults(db)
  -- Mirrors the persisted defaults applied by factory/isiLive_factory.lua.
  if db.mobNameplateEnabled == nil then
    db.mobNameplateEnabled = true
    db.mplusForcesEstimate = false
  end
  if db.mobNameplateShowPercent == nil then
    db.mobNameplateShowPercent = true
  end
  if db.mobNameplateShowRemaining == nil then
    db.mobNameplateShowRemaining = false
  end
  if db.mobNameplateFontSize == nil then
    db.mobNameplateFontSize = 14
  end
  if db.mobNameplatePosition == nil then
    db.mobNameplatePosition = "RIGHT"
  end
  if db.mobNameplateXOffset == nil then
    db.mobNameplateXOffset = 0
  end
  if db.mobNameplateYOffset == nil then
    db.mobNameplateYOffset = 0
  end
end

local function FormatBool(value)
  return value == true and "yes" or "no"
end

local function FormatValue(value)
  if value == nil then
    return "-"
  end
  return tostring(value)
end

-- Sentinel value used by the optional `issecretvalue` stub. Any field whose
-- value matches this string (or any string starting with the prefix) is
-- reported as a Secret Value to mimic WoW 12.0 tainted-context masking.
local SECRET_SENTINEL = "<secret>"

local function BuildEnvironment(opts)
  opts = opts or {}
  local createdFrames = {}
  local timers = {}
  local state = {
    now = 0,
    challengeActive = opts.challengeActive == true,
    activeMapID = opts.activeMapID or 161,
    unitExists = opts.unitExists ~= false,
    unitReaction = opts.unitReaction or 2,
    guid = opts.guid or "Creature-0-3889-161-12345-76132-0",
    apiPercent = opts.apiPercent,
    secretGuid = opts.secretGuid == true,
    secretMapID = opts.secretMapID == true,
  }
  if opts.apiPercent == false then
    state.apiPercent = nil
  elseif state.apiPercent == nil then
    state.apiPercent = "1.16"
  end
  if state.secretGuid then
    state.guid = SECRET_SENTINEL
  end

  local nameplateFrame = MakeFrame("NamePlate")
  nameplateFrame:Show()

  local globals = {
    UIParent = MakeFrame("UIParent"),
    CreateFrame = function(frameType)
      local frame = MakeFrame(frameType or "Frame")
      createdFrames[#createdFrames + 1] = frame
      return frame
    end,
    C_Timer = {
      After = function(delay, callback)
        timers[#timers + 1] = { at = state.now + delay, callback = callback }
      end,
    },
    C_NamePlate = opts.withNamePlateAPI == false and nil or {
      GetNamePlateForUnit = function(unit)
        if unit == "nameplate1" then
          return nameplateFrame
        end
        return nil
      end,
    },
    C_ChallengeMode = {
      IsChallengeModeActive = function()
        return state.challengeActive == true
      end,
      GetActiveChallengeMapID = function()
        if state.secretMapID then
          return SECRET_SENTINEL
        end
        return state.activeMapID
      end,
    },
    -- Mirrors WoW 12.0 `issecretvalue`. The simulator treats anything tagged
    -- with SECRET_SENTINEL as a Secret Value so the nameplate's IsSecretValue
    -- guards trigger exactly like in a tainted M+ key context.
    issecretvalue = function(v)
      return type(v) == "string" and v == SECRET_SENTINEL
    end,
    C_ScenarioInfo = opts.withScenarioAPI == false and nil or {
      GetUnitCriteriaProgressValues = function(unit)
        if unit ~= "nameplate1" then
          return nil
        end
        return 5, 431, state.apiPercent
      end,
    },
    UnitExists = function(unit)
      return unit == "nameplate1" and state.unitExists == true
    end,
    UnitGUID = function(unit)
      if unit == "nameplate1" then
        return state.guid
      end
      return nil
    end,
    UnitReaction = function(unit, _other)
      if unit == "nameplate1" then
        return state.unitReaction
      end
      return nil
    end,
    UnitName = function(unit)
      return unit == "nameplate1" and "Simulated Mob" or nil
    end,
    GameFontNormalOutline = {
      GetFont = function()
        return "Fonts\\FRIZQT__.TTF", 10, "OUTLINE"
      end,
    },
  }

  local function FindEventFrame()
    for _, frame in ipairs(createdFrames) do
      if type(frame._scripts.OnEvent) == "function" then
        return frame
      end
    end
    return nil
  end

  local function Dispatch(event, arg1)
    local frame = FindEventFrame()
    if frame and type(frame._scripts.OnEvent) == "function" then
      frame._scripts.OnEvent(frame, event, arg1)
    end
  end

  local function Advance(seconds)
    state.now = state.now + seconds
    local pending = timers
    timers = {}
    for _, timer in ipairs(pending) do
      if timer.at <= state.now then
        timer.callback()
      else
        timers[#timers + 1] = timer
      end
    end
  end

  return globals, state, Dispatch, Advance
end

local function PrintSnapshot(addon, label)
  local dump = addon.MobNameplate.DumpState("nameplate1")
  local frames = addon.MobNameplate.DumpFrames()
  local first = frames.frames[1] or {}
  print("---- " .. label)
  print("  enabled              = " .. FormatBool(dump.enabled))
  print("  hasNamePlateAPI      = " .. FormatBool(dump.hasNamePlateAPI))
  print("  hasProgressAPI       = " .. FormatBool(dump.hasProgressAPI))
  print("  challengeActive      = " .. FormatBool(dump.challengeActive))
  print("  eligible             = " .. FormatBool(dump.eligible))
  print("  activeMapID          = " .. FormatValue(dump.activeMapID))
  print("  npcId                = " .. FormatValue(dump.npcId))
  print("  dbPercent            = " .. FormatValue(dump.dbPercent))
  print("  apiPercent           = " .. FormatValue(dump.apiPercent))
  print("  remainingPercent     = " .. FormatValue(dump.remainingPercent))
  print("  resolvedText         = " .. FormatValue(dump.resolvedText))
  print("  frameExists          = " .. FormatBool(dump.frameExists))
  print("  frameShown           = " .. FormatBool(dump.frameShown))
  print("  renderedText         = " .. FormatValue(first.fontStringText or dump.fontStringText))
  print("  renderedFontHeight   = " .. FormatValue(first.fontHeight or dump.fontHeight))
  return {
    dump = dump,
    frame = first,
    renderedText = first.fontStringText or dump.fontStringText,
    frameShown = dump.frameShown == true,
  }
end

local function Check(condition, message)
  if condition then
    print("  [CHECK PASS] " .. message)
    return
  end
  failures = failures + 1
  print("  [CHECK FAIL] " .. message)
end

local function RunScenario(name, opts)
  print("\n========== " .. name .. " ==========")
  local db = CloneTable(opts and opts.db)
  ApplyFactoryNameplateDefaults(db)
  print(
    string.format(
      "SavedVariables after defaults: mobNameplateEnabled=%s, mplusForcesEstimate=%s, showPercent=%s, showRemaining=%s",
      tostring(db.mobNameplateEnabled),
      tostring(db.mplusForcesEstimate),
      tostring(db.mobNameplateShowPercent),
      tostring(db.mobNameplateShowRemaining)
    )
  )

  local globals, state, Dispatch, Advance = BuildEnvironment(opts)
  local mplusForces = nil
  if not (opts and opts.withForcesDB == false) then
    mplusForces = {
      byNpcId = {
        [76132] = {
          mapID = opts and opts.dbMapID or 161,
          count = 5,
        },
      },
      dungeonTotal = {
        [161] = { total = 431 },
        [162] = { total = 431 },
      },
    }
  end

  local seed = {
    MPlusForces = mplusForces,
    KillTrack = {
      GetData = function()
        return {
          active = true,
          mapID = state.activeMapID,
          rawCount = 326,
          total = 431,
        }
      end,
    },
  }

  Harness.WithGlobals(globals, function()
    local addon = Harness.LoadAddonModules({ "isiLive_mob_nameplate.lua" }, seed)
    addon.MobNameplate.SetFormat({
      showPercent = db.mobNameplateShowPercent ~= false,
      showRemaining = db.mobNameplateShowRemaining == true,
    })
    addon.MobNameplate.SetAppearance({
      fontSize = tonumber(db.mobNameplateFontSize) or 14,
      position = type(db.mobNameplatePosition) == "string" and db.mobNameplatePosition or "RIGHT",
      xOffset = tonumber(db.mobNameplateXOffset) or 0,
      yOffset = tonumber(db.mobNameplateYOffset) or 0,
    })
    addon.MobNameplate.SetEnabled(db.mobNameplateEnabled == true)

    local snap1 = PrintSnapshot(addon, "1. ADDON_LOADED / ApplyDBSettings applied")
    Dispatch("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local snap2 = PrintSnapshot(addon, "2. nameplate exists before key start")
    Dispatch("CHALLENGE_MODE_START")
    local snap3 = PrintSnapshot(addon, "3. CHALLENGE_MODE_START immediate refresh")
    state.challengeActive = true
    Advance(0.25)
    local snap4 = PrintSnapshot(addon, "4. delayed refresh after active key API is true")
    Advance(0.75)
    local snap5 = PrintSnapshot(addon, "5. one-second safety refresh")

    local expectedFinalShown = true
    if opts and opts.expectedFinalShown ~= nil then
      expectedFinalShown = opts.expectedFinalShown == true
    end
    Check(snap1.frameShown == false, "overlay is not visible directly after ApplyDBSettings")
    Check(snap2.frameShown == false, "overlay is not visible before challenge mode is active")
    Check(
      snap3.frameShown == false,
      "immediate CHALLENGE_MODE_START refresh still fails closed while API reports inactive"
    )
    Check(snap4.frameShown == expectedFinalShown, "delayed key-start refresh matches expected visibility")
    Check(snap5.frameShown == expectedFinalShown, "one-second safety refresh keeps expected visibility")

    if opts and type(opts.expectedFinalText) == "string" then
      Check(snap5.renderedText == opts.expectedFinalText, "final rendered text matches expected value")
    end
  end)
end

local scenarios = {
  happy = function()
    RunScenario("happy path: default SavedVariables, hostile nameplate, DB percent", {
      expectedFinalShown = true,
      expectedFinalText = "1.16%",
    })
  end,
  disabled = function()
    RunScenario("disabled setting: user explicitly turned nameplates off", {
      db = { mobNameplateEnabled = false, mplusForcesEstimate = false },
      expectedFinalShown = false,
    })
  end,
  friendly = function()
    RunScenario("friendly unit: UnitReaction > 4 blocks rendering", {
      unitReaction = 5,
      expectedFinalShown = false,
    })
  end,
  db_mismatch = function()
    RunScenario("DB mismatch: NPC exists but belongs to another map, API fallback renders", {
      dbMapID = 162,
      apiPercent = "2.50",
      expectedFinalShown = true,
      expectedFinalText = "2.50%",
    })
  end,
  no_sources = function()
    RunScenario("no percent source: DB missing and API returns nil", {
      withForcesDB = false,
      apiPercent = false,
      expectedFinalShown = false,
    })
  end,
  secret_guid = function()
    -- WoW 12.0 M+ tainted context: UnitGUID returns a Secret Value, so
    -- ResolveMobContributionFromDB cannot match the NPC. The Blizzard
    -- API path must render a percent regardless.
    RunScenario("Secret-Value GUID: DB lookup blocked, API fallback renders", {
      secretGuid = true,
      apiPercent = "3.42",
      expectedFinalShown = true,
      expectedFinalText = "3.42%",
    })
  end,
  api_only = function()
    -- No MDT-synced DB at all (e.g. forces module not loaded yet) but the
    -- Blizzard scenario API is healthy. Overlay must still render because
    -- the API-only fallback is a documented path for fresh-patch mobs.
    RunScenario("API-only: no MDT DB shipped, scenario API delivers percent", {
      withForcesDB = false,
      apiPercent = "0.50",
      expectedFinalShown = true,
      expectedFinalText = "0.50%",
    })
  end,
  secret_mapid = function()
    -- C_ChallengeMode.GetActiveChallengeMapID returns a Secret Value during
    -- some tainted M+ paths. activeMapID resolves to nil, so the DB lookup
    -- short-circuits — the API path must take over.
    RunScenario("Secret-Value mapID: DB lookup short-circuits, API fallback renders", {
      secretMapID = true,
      apiPercent = "1.99",
      expectedFinalShown = true,
      expectedFinalText = "1.99%",
    })
  end,
  format_no_percent = function()
    -- showPercent=false collapses BuildText to nil even when both percent
    -- sources are populated. The overlay must stay hidden.
    RunScenario("format gate: showPercent=false hides overlay despite available data", {
      db = { mobNameplateShowPercent = false },
      expectedFinalShown = false,
    })
  end,
}

local mode = tostring(select(1, ...) or "all")
if mode == "all" then
  scenarios.happy()
  scenarios.disabled()
  scenarios.friendly()
  scenarios.db_mismatch()
  scenarios.no_sources()
  scenarios.secret_guid()
  scenarios.api_only()
  scenarios.secret_mapid()
  scenarios.format_no_percent()
else
  local scenario = scenarios[mode]
  if not scenario then
    print("Unknown mode: " .. tostring(mode))
    print(
      "Available modes: all, happy, disabled, friendly, db_mismatch, no_sources, "
        .. "secret_guid, api_only, secret_mapid, format_no_percent"
    )
    os.exit(1)
  end
  scenario()
end

if failures > 0 then
  print(string.format("\nNameplate key-start simulator failed: %d check(s) failed", failures))
  os.exit(1)
end

print("\nNameplate key-start simulator passed.")
