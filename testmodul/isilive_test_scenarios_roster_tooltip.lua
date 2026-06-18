---@diagnostic disable: undefined-global, undefined-field, unused-local, unused-vararg

-- Scenarios for ui/isiLive_roster_tooltip.lua - targets the helper
-- surface that the composition-root test never reaches (simple tooltip
-- layout, AnchorRosterHoverTooltip, ShowRosterInfoTooltip with rich /
-- sync / syncDebug branches, BuildFallbackTooltipPlayerName,
-- FormatCompactTooltipNumber, FormatSyncAge variants, Blizzard unit
-- language tooltip hookscript registration).

local function BuildFontStringStub()
  local fs = { _text = "", _w = 0 }
  function fs:SetText(text)
    self._text = tostring(text or "")
  end
  function fs:GetText()
    return self._text
  end
  function fs:SetFont(_p, _s, _f) end
  function fs:SetTextColor(_r, _g, _b, _a) end
  function fs:SetJustifyH(_j) end
  function fs:SetJustifyV(_j) end
  function fs:SetWidth(w)
    self._w = w
  end
  function fs:SetWordWrap(_v) end
  function fs:SetNonSpaceWrap(_v) end
  function fs:SetMaxLines(_n) end
  function fs:SetPoint(...) end
  function fs:ClearAllPoints() end
  function fs:GetStringHeight()
    return 14
  end
  function fs:GetStringWidth()
    return math.max(1, #self._text * 6)
  end
  function fs:Show()
    self._shown = true
  end
  function fs:Hide()
    self._shown = false
  end
  return fs
end

local function BuildTooltipFrameStub()
  local f = {
    _points = {},
    _size = { 0, 0 },
    _shown = false,
    _strata = nil,
    _clamped = false,
    _textures = {},
    _createdFontStrings = {},
  }
  function f:SetPoint(...)
    table.insert(self._points, { ... })
  end
  function f:ClearAllPoints()
    self._points = {}
  end
  function f:SetSize(w, h)
    self._size = { w, h }
  end
  function f:SetWidth(w)
    self._size[1] = w
  end
  function f:SetHeight(h)
    self._size[2] = h
  end
  function f:SetFrameStrata(s)
    self._strata = s
  end
  function f:SetFrameLevel(level)
    self._frameLevel = level
  end
  function f:GetFrameLevel()
    return self._frameLevel or 1
  end
  function f:SetClampedToScreen(v)
    self._clamped = v
  end
  function f:Show()
    self._shown = true
  end
  function f:Hide()
    self._shown = false
  end
  function f:CreateTexture(_name, _layer)
    local t = { SetAllPoints = function() end, SetColorTexture = function() end }
    table.insert(self._textures, t)
    return t
  end
  function f:CreateFontString(_name, _layer, _template)
    local fs = BuildFontStringStub()
    table.insert(self._createdFontStrings, fs)
    return fs
  end
  function f:HookScript(name, fn)
    self._hooks = self._hooks or {}
    self._hooks[name] = fn
  end
  return f
end

local function BuildGlobals(overrides)
  overrides = overrides or {}
  return {
    UIParent = overrides.UIParent or {
      GetEffectiveScale = function()
        return 1
      end,
    },
    GetCursorPosition = overrides.GetCursorPosition,
    CreateFrame = function()
      return BuildTooltipFrameStub()
    end,
    RAID_CLASS_COLORS = overrides.RAID_CLASS_COLORS or {
      MAGE = { r = 0.25, g = 0.78, b = 0.92 },
      WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
      SHAMAN = { r = 0, g = 0.44, b = 0.87 },
    },
    AbbreviateNumbers = overrides.AbbreviateNumbers,
    IsiLiveDB = overrides.IsiLiveDB,
    UnitClass = overrides.UnitClass,
    GetSpecialization = overrides.GetSpecialization,
    GetSpecializationInfo = overrides.GetSpecializationInfo,
  }
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  local function Load()
    -- roster_tooltip pulls from Sync/Locale tables on addonTable; load
    -- the deps alongside so `addonTable.Sync` can be probed safely.
    return LoadAddonModules({ "isiLive_roster_tooltip.lua" })
  end

  local function LoadWithRosterBonuses()
    return LoadAddonModules({
      "isiLive_languages.lua",
      "isiLive_texts.lua",
      "isiLive_lfg_flags.lua",
      "isiLive_roster_tooltip.lua",
    })
  end

  -- =====================================================
  -- Simple tooltip lifecycle
  -- =====================================================

  test("roster_tooltip: EnsureSimpleTooltipAPI is idempotent and ignores non-table input", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      Assert.Nil(addon._RosterInternal.EnsureSimpleTooltipAPI(nil))
      Assert.Nil(addon._RosterInternal.EnsureSimpleTooltipAPI("string"))
      local tooltip = BuildTooltipFrameStub()
      local returned = addon._RosterInternal.EnsureSimpleTooltipAPI(tooltip)
      Assert.Equal(returned, tooltip)
      Assert.Equal(tooltip._isiLiveTooltipReady, true)
      -- Calling again returns the same tooltip (fast path).
      Assert.Equal(addon._RosterInternal.EnsureSimpleTooltipAPI(tooltip), tooltip)
    end)
  end)

  test("roster_tooltip: SetText / AddLine / ClearLines / Show / Hide drive the full layout", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local tooltip = addon._RosterInternal.EnsureSimpleTooltipAPI(BuildTooltipFrameStub())
      tooltip:SetText("Header", 1, 1, 1)
      tooltip:AddLine("Line 2", 0.9, 0.9, 0.9)
      tooltip:AddLine("Line 3")
      Assert.Equal(tooltip._isiLiveTooltipLineCount, 3)
      Assert.Equal(tooltip._isiLiveTooltipLines[1]:GetText(), "Header")
      Assert.Equal(tooltip._isiLiveTooltipLines[2]:GetText(), "Line 2")

      tooltip:Show()
      Assert.Equal(tooltip._isiLiveTooltipShown, true)

      tooltip:Hide()
      Assert.Equal(tooltip._isiLiveTooltipShown, false)
      Assert.Equal(tooltip._isiLiveTooltipLineCount, 0, "Hide must clear line count")
    end)
  end)

  test("roster_tooltip: SetOwner with ANCHOR_CURSOR reads GetCursorPosition and UIParent scale", function()
    local cursorCalls = 0
    WithGlobals(
      BuildGlobals({
        GetCursorPosition = function()
          cursorCalls = cursorCalls + 1
          return 200, 300
        end,
        UIParent = {
          GetEffectiveScale = function()
            return 0.8
          end,
        },
      }),
      function()
        local addon = Load()
        local tooltip = addon._RosterInternal.EnsureSimpleTooltipAPI(BuildTooltipFrameStub())
        local anchor = BuildTooltipFrameStub()
        tooltip:SetOwner(anchor, "ANCHOR_CURSOR")
        Assert.Equal(tooltip._isiLiveTooltipOwner, anchor)
        Assert.True(cursorCalls > 0, "ANCHOR_CURSOR must consult GetCursorPosition")
        Assert.True(#tooltip._points > 0, "SetOwner must position via SetPoint")
      end
    )
  end)

  test("roster_tooltip: SetOwner without ANCHOR_CURSOR anchors TOPLEFT to BOTTOMLEFT of owner", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local tooltip = addon._RosterInternal.EnsureSimpleTooltipAPI(BuildTooltipFrameStub())
      local anchor = BuildTooltipFrameStub()
      tooltip:SetOwner(anchor, "ANCHOR_TOP")
      Assert.Equal(tooltip._isiLiveTooltipAnchor, "ANCHOR_TOP")
    end)
  end)

  -- =====================================================
  -- CreateRosterHoverTooltip / HideRosterHoverTooltip / Anchor
  -- =====================================================

  test("roster_tooltip: CreateRosterHoverTooltip wires backdrop texture when UICommon is absent", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local mainFrame = BuildTooltipFrameStub()
      local tooltip = addon._RosterInternal.CreateRosterHoverTooltip(mainFrame)
      Assert.NotNil(tooltip)
      Assert.Equal(tooltip._strata, "TOOLTIP")
      Assert.Equal(tooltip._clamped, true)
      Assert.Equal(tooltip._shown, false, "newly created tooltip must start hidden")
    end)
  end)

  test("roster_tooltip: HideRosterHoverTooltip tolerates nil + non-table + valid tooltip", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      addon._RosterInternal.HideRosterHoverTooltip(nil)
      addon._RosterInternal.HideRosterHoverTooltip("string")
      local tooltip = BuildTooltipFrameStub()
      tooltip._shown = true
      addon._RosterInternal.HideRosterHoverTooltip(tooltip)
      Assert.Equal(tooltip._shown, false)
    end)
  end)

  test("roster_tooltip: AnchorRosterHoverTooltip prepares tooltip for rendering", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local tooltip = BuildTooltipFrameStub()
      local anchorFrame = BuildTooltipFrameStub()
      local prepared = addon._RosterInternal.AnchorRosterHoverTooltip(tooltip, anchorFrame)
      Assert.NotNil(prepared)
      Assert.Equal(prepared._isiLiveTooltipOwner, anchorFrame)
      Assert.Equal(prepared._isiLiveTooltipAnchor, "ANCHOR_CURSOR")
    end)
  end)

  test("roster_tooltip: AnchorRosterHoverTooltip returns nil for non-table input", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      Assert.Nil(addon._RosterInternal.AnchorRosterHoverTooltip(nil))
    end)
  end)

  -- =====================================================
  -- FormatCompactTooltipNumber / ShowRosterNameFallbackTooltip
  -- =====================================================

  test("roster_tooltip: FormatCompactTooltipNumber returns nil for non-numeric input", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      Assert.Nil(addon._RosterInternal.FormatCompactTooltipNumber(nil))
      Assert.Nil(addon._RosterInternal.FormatCompactTooltipNumber("not-a-number"))
    end)
  end)

  test("roster_tooltip: FormatCompactTooltipNumber rounds and falls back when AbbreviateNumbers missing", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      Assert.Equal(addon._RosterInternal.FormatCompactTooltipNumber(1499), "1.5K", "manual thousands abbreviation")
      Assert.Equal(addon._RosterInternal.FormatCompactTooltipNumber(999), "999", "sub-thousand stays as integer")
      Assert.Equal(addon._RosterInternal.FormatCompactTooltipNumber(1500000), "1.5M")
      Assert.Equal(addon._RosterInternal.FormatCompactTooltipNumber(2500000000), "2.5B")
    end)
  end)

  test("roster_tooltip: FormatCompactTooltipNumber forwards to AbbreviateNumbers when available", function()
    WithGlobals(
      BuildGlobals({
        AbbreviateNumbers = function(v)
          return "AB:" .. tostring(v)
        end,
      }),
      function()
        local addon = Load()
        Assert.Equal(addon._RosterInternal.FormatCompactTooltipNumber(42.6), "AB:43")
      end
    )
  end)

  test("roster_tooltip: ShowRosterNameFallbackTooltip returns false without a name", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local tooltip = BuildTooltipFrameStub()
      local anchor = BuildTooltipFrameStub()
      Assert.Equal(
        addon._RosterInternal.ShowRosterNameFallbackTooltip(tooltip, anchor, "", nil),
        false,
        "empty name must reject tooltip"
      )
    end)
  end)

  test("roster_tooltip: ShowRosterNameFallbackTooltip renders Name-Realm title", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local tooltip = BuildTooltipFrameStub()
      local anchor = BuildTooltipFrameStub()
      local ok = addon._RosterInternal.ShowRosterNameFallbackTooltip(tooltip, anchor, "Alice", "Draenor")
      Assert.Equal(ok, true)
      Assert.Equal(tooltip._isiLiveTooltipShown, true)
      Assert.True(tooltip._isiLiveTooltipLines[1]:GetText():find("Alice", 1, true) ~= nil)
      Assert.True(tooltip._isiLiveTooltipLines[1]:GetText():find("Draenor", 1, true) ~= nil)
    end)
  end)

  -- =====================================================
  -- ShowRosterInfoTooltip - core branches
  -- =====================================================

  local function buildShowArgs(info, overrides)
    overrides = overrides or {}
    return {
      tooltipFrame = BuildTooltipFrameStub(),
      anchorFrame = BuildTooltipFrameStub(),
      unit = overrides.unit,
      info = info,
      getDungeonShortCode = overrides.getDungeonShortCode or function()
        return nil
      end,
      getDungeonName = overrides.getDungeonName or function()
        return nil
      end,
      getPlayerLastRunDps = overrides.getPlayerLastRunDps,
      getLanguageTooltipMarkup = overrides.getLanguageTooltipMarkup,
      getL = overrides.getL or function()
        return {}
      end,
    }
  end

  local function callShow(addon, args)
    return addon._RosterInternal.ShowRosterInfoTooltip(
      args.tooltipFrame,
      args.anchorFrame,
      args.unit,
      args.info,
      args.getDungeonShortCode,
      args.getDungeonName,
      args.getPlayerLastRunDps,
      args.getLanguageTooltipMarkup,
      args.getL
    )
  end

  test("roster_tooltip: ShowRosterInfoTooltip rejects non-table info", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs("not-a-table")
      Assert.Equal(callShow(addon, args), false)
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip rejects empty-name info", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({ name = "" })
      Assert.Equal(callShow(addon, args), false)
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip returns false without rich info payload", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({ name = "Alice", realm = "Draenor" })
      Assert.Equal(callShow(addon, args), false, "name-only info must not surface a rich tooltip")
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip renders class-color title + rich lines", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({
        name = "Alice",
        realm = "Draenor",
        class = "MAGE",
        spec = "Arcane",
        ilvl = 625.4,
        rio = 3400.7,
        keyMapID = 2649,
        keyLevel = 12,
        language = "de",
      }, {
        getDungeonName = function(mapID)
          if mapID == 2649 then
            return "Ara-Kara"
          end
        end,
      })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      Assert.Equal(tf._isiLiveTooltipShown, true)
      -- Title line carries the class color + name.
      local title = tf._isiLiveTooltipLines[1]:GetText()
      Assert.True(title:find("|cff", 1, true) ~= nil, "class-color prefix must be applied: " .. title)
      Assert.True(title:find("Alice", 1, true) ~= nil)
      -- Look for key line "Key: Ara-Kara +12" somewhere.
      local foundKey = false
      for _, line in ipairs(tf._isiLiveTooltipLines) do
        if line:GetText():find("Ara-Kara +12", 1, true) then
          foundKey = true
        end
      end
      Assert.Equal(foundKey, true, "resolved dungeon name + key level must surface as a line")
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip falls back to dungeon short code when full name is empty", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({
        name = "Alice",
        class = "MAGE",
        keyMapID = 2649,
        keyLevel = 10,
      }, {
        getDungeonName = function()
          return ""
        end,
        getDungeonShortCode = function(mapID)
          if mapID == 2649 then
            return "AK"
          end
        end,
      })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      local found = false
      for _, line in ipairs(tf._isiLiveTooltipLines) do
        if line:GetText():find("AK +10", 1, true) then
          found = true
        end
      end
      Assert.Equal(found, true)
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip uses '?' when neither dungeon name nor short code resolves", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({
        name = "Alice",
        class = "WARRIOR",
        keyMapID = 2649,
        keyLevel = 14,
      })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      local matched = false
      for _, line in ipairs(tf._isiLiveTooltipLines) do
        if line:GetText():find("Key: ? +14", 1, true) then
          matched = true
        end
      end
      Assert.Equal(matched, true, "unresolved dungeon must fall back to '?'")
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip surfaces last-run DPS line with compact number", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({ name = "Alice", class = "MAGE" }, {
        getPlayerLastRunDps = function()
          return 1234567
        end,
        getL = function()
          return { TOOLTIP_LAST_RUN_DPS = "Last run DPS: %s" }
        end,
      })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      local matched = false
      for _, line in ipairs(tf._isiLiveTooltipLines) do
        if line:GetText():find("Last run DPS:", 1, true) then
          matched = true
        end
      end
      Assert.Equal(matched, true)
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip renders green-heart class buff details", function()
    WithGlobals(
      BuildGlobals({
        IsiLiveDB = { locale = "enUS" },
        UnitClass = function(unit)
          if unit == "player" then
            return "Shaman", "SHAMAN"
          end
          return nil, nil
        end,
        GetSpecialization = function()
          return 1
        end,
        GetSpecializationInfo = function()
          return 262
        end,
      }),
      function()
        local addon = LoadWithRosterBonuses()
        local args = buildShowArgs({
          name = "Totem",
          class = "SHAMAN",
          specID = 262,
        })
        Assert.Equal(callShow(addon, args), true)

        local foundBonusLine = false
        for _, line in ipairs(args.tooltipFrame._isiLiveTooltipLines) do
          local text = line:GetText()
          if text:find("Group bonus:", 1, true) and text:find("+2% Mastery", 1, true) and text:find("BL", 1, true) then
            foundBonusLine = true
          end
        end
        Assert.True(foundBonusLine, "roster tooltip must show the concrete buff and BL behind the mouseover")
      end
    )
  end)

  -- UC-21: Multi-Kick-Extras rendering inside the rich roster tooltip.
  -- The data path (KeySync.ApplyKnownKeyToRosterEntry and Sync.SetPlayerKickInfo)
  -- is covered separately; this test exercises the actual tooltip lines so the
  -- "Extra kicks:" header and per-spell rows are visible to the user.
  test("roster_tooltip: ShowRosterInfoTooltip renders multi-kick extras header and per-spell lines", function()
    -- BuildGlobals only forwards a fixed set of fields; C_Spell needs to be
    -- merged into the globals table directly so the rawget(_G, "C_Spell")
    -- call inside ShowRosterInfoTooltip resolves to our stub.
    local globals = BuildGlobals()
    globals.C_Spell = {
      GetSpellName = function(spellID)
        if spellID == 31935 then
          return "Avenger's Shield"
        end
        return nil
      end,
    }
    WithGlobals(globals, function()
      local addon = Load()
      local args = buildShowArgs({
        name = "Alice",
        class = "PALADIN",
        syncKickExtras = {
          [31935] = { cooldownRemain = 7 },
        },
      }, {
        getL = function()
          return { TOOLTIP_KICK_EXTRAS_HEADER = "Extra kicks:" }
        end,
      })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      local foundHeader = false
      local foundLine = false
      for _, line in ipairs(tf._isiLiveTooltipLines) do
        local text = line:GetText()
        if text:find("Extra kicks:", 1, true) then
          foundHeader = true
        end
        if text:find("Avenger's Shield", 1, true) and text:find("7s", 1, true) then
          foundLine = true
        end
      end
      Assert.Equal(foundHeader, true, "extras header line must render")
      Assert.Equal(foundLine, true, "spell name + remaining cooldown must render as indented line")
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip falls back to 'Spell <ID>' when GetSpellName is missing", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({
        name = "Alice",
        class = "PALADIN",
        syncKickExtras = {
          [31935] = { cooldownRemain = 12 },
        },
      })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      local matched = false
      for _, line in ipairs(tf._isiLiveTooltipLines) do
        if line:GetText():find("Spell 31935", 1, true) then
          matched = true
        end
      end
      Assert.Equal(matched, true, "missing GetSpellName must fall back to 'Spell <ID>'")
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip renders multi-kick extras sorted by spellID", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({
        name = "Alice",
        class = "PALADIN",
        syncKickExtras = {
          [31935] = { cooldownRemain = 12 },
          [19647] = { cooldownRemain = 8 },
        },
      }, {
        getL = function()
          return { TOOLTIP_KICK_EXTRAS_HEADER = "Extra kicks:" }
        end,
      })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      local spellLockIndex = nil
      local avengerIndex = nil
      for index, line in ipairs(tf._isiLiveTooltipLines) do
        local text = line:GetText()
        if text:find("Spell 19647", 1, true) then
          spellLockIndex = index
        end
        if text:find("Spell 31935", 1, true) then
          avengerIndex = index
        end
      end
      Assert.NotNil(spellLockIndex, "lower spellID extra must render")
      Assert.NotNil(avengerIndex, "higher spellID extra must render")
      Assert.True(spellLockIndex < avengerIndex, "extra kick tooltip lines must be sorted by numeric spellID")
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip omits extras block when all entries expired", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({
        name = "Alice",
        class = "PALADIN",
        syncKickExtras = {
          [31935] = { cooldownRemain = 0 },
        },
      }, {
        getL = function()
          return { TOOLTIP_KICK_EXTRAS_HEADER = "Extra kicks:" }
        end,
      })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      for _, line in ipairs(tf._isiLiveTooltipLines) do
        Assert.False(
          line:GetText():find("Extra kicks:", 1, true) ~= nil,
          "header must not render when no extras are active"
        )
      end
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip prefers getLanguageTooltipMarkup hit over addon locale", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({ name = "Alice", class = "MAGE", language = "de" }, {
        getLanguageTooltipMarkup = function(code)
          if code == "DE" then
            return "|TGermany:0|t DE"
          end
        end,
      })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      local matched = false
      for _, line in ipairs(tf._isiLiveTooltipLines) do
        if line:GetText():find("Germany", 1, true) then
          matched = true
        end
      end
      Assert.Equal(matched, true)
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip tolerates pcall failure in getLanguageTooltipMarkup", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      local args = buildShowArgs({ name = "Alice", class = "MAGE", language = "fr" }, {
        getLanguageTooltipMarkup = function()
          error("markup fn raised", 0)
        end,
      })
      Assert.Equal(callShow(addon, args), true, "pcall failure must degrade gracefully without raising")
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip surfaces sync summary interval + source lines", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      addon.Sync = {
        GetPlayerSyncSummary = function()
          return { intervalSeconds = 42, source = "hello" }
        end,
      }
      local args = buildShowArgs({ name = "Alice", class = "MAGE" }, {
        getL = function()
          return {
            TOOLTIP_SYNC_FRESHNESS = "Sync %s",
            TOOLTIP_SYNC_SOURCE = "From %s",
          }
        end,
      })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      local hasInterval = false
      local hasSource = false
      for _, line in ipairs(tf._isiLiveTooltipLines) do
        local text = line:GetText()
        if text:find("Sync", 1, true) then
          hasInterval = true
        end
        if text:find("From hello", 1, true) then
          hasSource = true
        end
      end
      Assert.Equal(hasInterval, true)
      Assert.Equal(hasSource, true)
      addon.Sync = nil
    end)
  end)

  test("roster_tooltip: ShowRosterInfoTooltip surfaces client version line from syncHelloInfo", function()
    WithGlobals(BuildGlobals(), function()
      local addon = Load()
      addon.Sync = {
        GetPlayerHelloInfo = function()
          return { addonVersion = "1.2.3" }
        end,
      }
      local args = buildShowArgs({ name = "Alice", class = "MAGE" })
      Assert.Equal(callShow(addon, args), true)
      local tf = args.tooltipFrame
      local matched = false
      for _, line in ipairs(tf._isiLiveTooltipLines) do
        if line:GetText():find("1.2.3", 1, true) then
          matched = true
        end
      end
      Assert.Equal(matched, true, "sync hello addonVersion must surface")
      addon.Sync = nil
    end)
  end)
end
