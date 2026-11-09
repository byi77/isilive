---@diagnostic disable: undefined-global
local helpers = dofile("testmodul/isilive_test_ui_helpers.lua")
local BuildCreateFrameStub = helpers.BuildCreateFrameStub
local BuildBlizzardSettingsStub = helpers.BuildBlizzardSettingsStub

-- Rule 241: search in isiLive's config window. The tests drive the real
-- SettingsPanel.Create / ConfigWindow / SettingsSearch code with the real
-- locale tables; the search box is typed into through its own scripts. The
-- Blizzard Settings side is the COMPONENT-ONLY stub from
-- isilive_test_ui_helpers.lua (no addon event path).
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  -- Builds the real settings panel inside the config window.
  -- opts.locale (initial tag), opts.inCombat, opts.frameStubOpts.
  local function WithSearchPanel(opts, body)
    opts = opts or {}
    local createFrame, frames = BuildCreateFrameStub(opts.frameStubOpts)
    local inCombat = opts.inCombat or function()
      return false
    end
    local timers = {}
    local blizzardGlobals = BuildBlizzardSettingsStub({ isInCombat = inCombat })
    local db = {}
    local globals = {
      UIParent = {},
      IsiLiveDB = db,
      CreateFrame = createFrame,
      UISpecialFrames = {},
      InCombatLockdown = inCombat,
      C_Timer = {
        After = function(delay, callback)
          timers[#timers + 1] = { delay = delay, callback = callback }
        end,
      },
    }
    for key, value in pairs(blizzardGlobals) do
      globals[key] = value
    end
    WithGlobals(globals, function()
      local addon = LoadAddonModules({
        "isiLive_texts.lua",
        "isiLive_sound_utils.lua",
        "isiLive_ui_common.lua",
        "isiLive_ui_design.lua",
        "isiLive_settings.lua",
      })
      local locales = addon.Texts.GetLocaleTables()
      local env = { locale = opts.locale or "enUS" }
      local panel = addon.SettingsPanel.Create({
        deferBuild = true,
        getL = function()
          return locales[env.locale]
        end,
        getDB = function()
          return db
        end,
        setLanguage = function() end,
      })
      env.addon = addon
      env.panel = panel
      env.frames = frames
      env.db = db
      env.timers = timers
      env.locales = locales
      env.L = function()
        return locales[env.locale]
      end
      -- Language switch as the factory does it: new labels, then Refresh.
      function env.SwitchLanguage(tag)
        env.locale = tag
        panel.Refresh()
      end
      -- Runs the pending debounce timers like the client clock would.
      function env.RunTimers()
        local pending = {}
        for index, timer in ipairs(timers) do
          pending[index] = timer
        end
        for index = #timers, 1, -1 do
          timers[index] = nil
        end
        for _, timer in ipairs(pending) do
          timer.callback()
        end
      end
      function env.Box()
        return panel.window.searchBox
      end
      -- Types like a player: one OnTextChanged per edit, filter after the
      -- debounce.
      function env.Type(text)
        local box = env.Box()
        box:SetText(text)
        box._scripts.OnTextChanged(box, true)
        env.RunTimers()
        return panel.GetSearchResult()
      end
      function env.Entry(key)
        for _, entry in ipairs(panel.GetSearchEntries()) do
          if entry.key == key then
            return entry
          end
        end
        error("no search entry " .. tostring(key))
      end
      function env.Shown(key)
        return env.Entry(key).region:IsShown() == true
      end
      function env.Header(localeKey)
        local text = env.L()[localeKey]
        for _, fontString in ipairs(panel.content._fontStrings or {}) do
          if fontString:GetText() == text and fontString._isiLiveSurfaceRole == "settings_section" then
            return fontString
          end
        end
        error("no section header " .. tostring(localeKey))
      end
      function env.ContentFrame(field)
        for _, child in ipairs(panel.content._children or {}) do
          if child[field] ~= nil then
            return child
          end
        end
        return nil
      end
      function env.ContentFrames(field)
        local found = {}
        for _, child in ipairs(panel.content._children or {}) do
          if child[field] ~= nil then
            found[child[field]] = child
          end
        end
        return found
      end
      -- The client fires OnHide when a shown frame is hidden; the stub only
      -- flips the flag, so the test fires the window's script itself.
      function env.CloseWindow()
        local frame = panel.windowFrame
        panel.Close()
        frame._scripts.OnHide(frame)
      end
      panel.Open()
      body(env)
    end)
  end

  -- Every claimed widget of the content with its anchor and visibility.
  local function SnapshotLayout(panel)
    local snapshot = {}
    local function Add(object)
      local point = object._point
      snapshot[#snapshot + 1] = {
        object = object,
        point = point and table.concat({ tostring(point[1]), tostring(point[3]), point[4], point[5] }, "|") or "-",
        shown = object.IsShown and object:IsShown() or not object.hidden,
      }
    end
    for _, child in ipairs(panel.content._children or {}) do
      Add(child)
    end
    for _, region in ipairs(panel.content._fontStrings or {}) do
      Add(region)
    end
    for _, region in ipairs(panel.content._textures or {}) do
      Add(region)
    end
    local offsets = {}
    for key, value in pairs(panel.navigation.offsets) do
      offsets[#offsets + 1] = key .. "=" .. tostring(value)
    end
    table.sort(offsets)
    return snapshot, panel.content:GetHeight(), table.concat(offsets, ",")
  end

  test("SettingsSearch normalizes case accents and color codes UTF-8 safe", function()
    -- COMPONENT-ONLY: Normalize/Tokenize are pure text functions without an
    -- event path; the filter tests below drive them through the panel.
    local addon = LoadAddonModules({ "isiLive_settings_search.lua" })
    local Normalize = addon.SettingsSearch.Normalize
    Assert.Equal(Normalize("MiniMap Button"), "minimap button", "ASCII is lower-cased")
    Assert.Equal(Normalize("Größe ÄÖÜ"), "grosse aou", "German umlauts and sharp s fold")
    Assert.Equal(Normalize("Général Écran Œuvre"), "general ecran oeuvre", "French accents and ligature fold")
    Assert.Equal(Normalize("İSTANBUL ılık ĞŞÇ"), "istanbul ilik gsc", "Turkish dotted and dotless i fold to i")
    Assert.Equal(Normalize("ЗВУК Ёлка"), "звук елка", "Cyrillic upper case folds, yo folds to ye")
    Assert.Equal(Normalize("|cff1e90ffLive|r |TInterface\\Icons\\X:16|tKick"), "live kick", "codes are dropped")
    Assert.Equal(Normalize("Ωmega"), "Ωmega", "other scripts stay byte-exact and intact")
    local words = addon.SettingsSearch.Tokenize("  Sound   TANK ")
    Assert.Equal(#words, 2, "blank runs split the words")
    Assert.Equal(words[1], "sound", "first word")
    Assert.Equal(words[2], "tank", "second word")
    Assert.Equal(#addon.SettingsSearch.Tokenize("   "), 0, "a blank query has no words")
  end)

  test("Config search shows matching controls with their section heading only", function()
    WithSearchPanel({}, function(env)
      local result = env.Type("minimap")
      Assert.True(result.active, "a typed word starts the search")
      Assert.Equal(result.matchCount, 1, "exactly the minimap option matches")
      Assert.True(env.Shown("minimapBtn"), "the matching control stays visible")
      Assert.True(env.Header("SETTINGS_SECTION_DISPLAY"):IsShown(), "its section heading stays visible")
      Assert.False(env.Shown("lang"), "other controls are hidden")
      Assert.False(env.Header("SETTINGS_SECTION_SOUNDS"):IsShown(), "headings without hits are hidden")
      Assert.False(env.panel.noMatchesText:IsShown(), "no hint while something matches")
      local displayPreview = env.ContentFrame("_sample")
      Assert.False(displayPreview:IsShown(), "the display preview hides without a scale or opacity hit")

      local nav = env.panel.navigation
      Assert.False(nav.buttons.display._disabled == true, "the section with the hit stays navigable")
      Assert.True(nav.buttons.sounds._disabled == true, "sections without hits are disabled")
      Assert.True(nav.disabled.sounds == true, "the disabled section is remembered")
      local scroll = env.panel.scrollFrame
      scroll:SetVerticalScroll(0)
      nav.buttons.sounds._scripts.OnClick(nav.buttons.sounds)
      Assert.Equal(scroll:GetVerticalScroll(), 0, "a disabled navigation button does not scroll")

      local minimapLabel = env.Entry("minimapBtn").region
      local headerY = select(5, env.Header("SETTINGS_SECTION_DISPLAY"):GetPoint())
      local labelAnchor = select(2, minimapLabel:GetPoint())
      local rowY = select(5, labelAnchor:GetPoint())
      Assert.True(headerY > rowY, "the hit sits right below its heading")
      Assert.True(headerY - rowY < 60, "the hidden rows in between take no space (gap " .. (headerY - rowY) .. ")")

      env.Type("UI Scale")
      Assert.True(env.Shown("uiScale"), "two words match the UI scale slider")
      Assert.True(displayPreview:IsShown(), "the display preview follows a scale hit")
    end)
  end)

  test("Config search needs every word and shows a hint without matches", function()
    WithSearchPanel({}, function(env)
      local result = env.Type("SOUND tank")
      Assert.True(env.Shown("soundChecks.tank_died"), "both words match the tank death alert")
      Assert.False(env.Shown("soundChecks.healer_died"), "the healer alert misses one word")
      Assert.True(result.matchCount >= 1, "at least one control matches")

      result = env.Type("minimap xyzzy")
      Assert.Equal(result.matchCount, 0, "a second unknown word drops every hit")
      Assert.Equal(result.visibleRows, 0, "nothing is shown")
      Assert.True(env.panel.noMatchesText:IsShown(), "the no-matches hint is shown")
      Assert.True(env.panel.noMatchesText:GetText():find("minimap xyzzy", 1, true) ~= nil, "the hint names the query")
      Assert.True(env.panel.navigation.buttons.general._disabled == true, "every section is disabled")

      env.Type("")
      Assert.False(env.panel.noMatchesText:IsShown(), "clearing hides the hint")
      Assert.True(env.Shown("lang"), "clearing shows every control again")
      Assert.False(env.panel.navigation.buttons.sounds._disabled == true, "clearing enables the navigation")
    end)
  end)

  test("Config search finds English tags on every client language", function()
    for _, tag in ipairs({ "deDE", "frFR", "ruRU", "trTR" }) do
      WithSearchPanel({ locale = tag }, function(env)
        env.Type("interrupt")
        Assert.True(env.Shown("missedKickAlert"), tag .. ": 'interrupt' finds the missed-kick alert")
        Assert.True(env.Shown("missedKickOnlyInKey"), tag .. ": and its key-only option")
        Assert.False(env.Shown("lang"), tag .. ": unrelated controls are hidden")
        env.Type("hearthstone")
        Assert.True(env.Shown("hearthstoneSelect"), tag .. ": 'hearthstone' finds the hearthstone selection")
        env.Type("teleport")
        Assert.True(env.Shown("portalNavigator"), tag .. ": 'teleport' finds the portal navigator")
        Assert.True(env.Shown("escPanel"), tag .. ": 'teleport' finds the ESC shortcuts")
      end)
    end
    WithSearchPanel({ locale = "deDE" }, function(env)
      env.Type("SPRACHE")
      Assert.True(env.Shown("lang"), "the localized label matches case-insensitively")
    end)
    WithSearchPanel({ locale = "frFR" }, function(env)
      env.Type("general")
      Assert.True(env.Shown("lang"), "an unaccented word opens the accented heading's block")
    end)
    WithSearchPanel({ locale = "ruRU" }, function(env)
      Assert.Equal(env.Entry("lang").label, "Язык", "setup: Russian language label")
      env.Type("ЯЗЫК")
      Assert.True(env.Shown("lang"), "upper-case Cyrillic matches the Russian label")
    end)
    WithSearchPanel({ locale = "trTR" }, function(env)
      Assert.Equal(env.Entry("lang").label, "Dil", "setup: Turkish language label")
      env.Type("DİL")
      Assert.True(env.Shown("lang"), "the Turkish dotted capital I matches")
    end)
  end)

  test("Config search filters again with the new labels after a language switch", function()
    WithSearchPanel({ locale = "deDE" }, function(env)
      env.Type("sprache")
      Assert.True(env.Shown("lang"), "German label matches")
      env.SwitchLanguage("enUS")
      local result = env.panel.GetSearchResult()
      Assert.True(result.active, "the search survives the language switch")
      Assert.False(env.Shown("lang"), "the English label no longer contains the German word")
      Assert.True(env.panel.noMatchesText:IsShown(), "the hint appears for the new language")
      Assert.Equal(env.Box():GetText(), "sprache", "the search text is kept")

      env.Type("language")
      Assert.True(env.Shown("lang"), "the English label matches")
      env.SwitchLanguage("deDE")
      Assert.True(env.Shown("lang"), "the English tag keeps the row after switching back")
      Assert.False(env.Shown("minimapBtn"), "unrelated rows stay hidden after the switch")
      Assert.Equal(env.Header("SETTINGS_SECTION_GENERAL"):GetText(), "Allgemein", "headings relabel")
    end)
  end)

  test("Clearing the config search restores the original layout exactly", function()
    WithSearchPanel({}, function(env)
      local scroll = env.panel.scrollFrame
      scroll:SetHeight(400)
      scroll:SetVerticalScroll(300)
      local before, beforeHeight, beforeOffsets = SnapshotLayout(env.panel)
      env.Type("sound")
      Assert.Equal(scroll:GetVerticalScroll(), 0, "results start at the top")
      env.Type("kick")
      env.SwitchLanguage("enUS")
      env.Type("")
      local after, afterHeight, afterOffsets = SnapshotLayout(env.panel)
      Assert.Equal(#after, #before, "the same widgets exist")
      for index, entry in ipairs(before) do
        Assert.Equal(after[index].point, entry.point, "widget " .. index .. " returns to its anchor")
        Assert.Equal(after[index].shown, entry.shown, "widget " .. index .. " returns to its visibility")
      end
      Assert.Equal(afterHeight, beforeHeight, "the content height is the original one")
      Assert.Equal(afterOffsets, beforeOffsets, "the navigation offsets are the original ones")
      Assert.Equal(scroll:GetVerticalScroll(), 300, "clearing returns to the scroll position")
    end)
  end)

  test("Config search keeps previews dropdowns VIP and reset rows intact", function()
    WithSearchPanel({}, function(env)
      local preview = env.ContentFrame("_isiLivePreviewRoot")
      local overlay = nil
      for _, frame in ipairs(env.frames) do
        if frame._isiLiveSettingsPreviewOverlay then
          overlay = frame
        end
      end
      Assert.Equal(overlay._parent, preview, "the nameplate overlay hangs off the preview")

      env.Type("offset")
      Assert.True(env.Shown("nameplateXOffset"), "the nameplate offset matches")
      Assert.True(preview:IsShown(), "the nameplate preview follows hits in its block")
      env.Type("minimap")
      Assert.False(preview:IsShown(), "the preview hides without a nameplate hit")
      env.panel.Refresh()
      Assert.False(preview:IsShown(), "a repaint keeps the hidden preview (and its overlay) hidden")

      env.Type("bloodlust")
      local previewButtons = env.ContentFrames("_soundPreviewKey")
      Assert.True(previewButtons.bloodlust:IsShown(), "the sound preview button stays with its alert")
      Assert.False(previewButtons.tank_died:IsShown(), "other sound preview buttons hide with their row")
      local bloodlustCheck = select(2, previewButtons.bloodlust:GetPoint())
      Assert.True(bloodlustCheck:IsShown(), "the preview button's checkbox is visible")

      env.Type("hearthstone")
      local dropdown = env.Entry("hearthstoneSelect")
      Assert.True(dropdown.region:IsShown(), "the hearthstone dropdown label is visible")
      local dropdownButton = nil
      for _, child in ipairs(env.panel.content._children) do
        if child._options ~= nil then
          dropdownButton = child
        end
      end
      Assert.True(dropdownButton:IsShown(), "the hearthstone dropdown button is visible")

      env.Type("ghoul")
      Assert.True(env.Shown("vipDkGhoulReminder"), "the VIP sub-option matches")
      Assert.False(env.Shown("vipDkPutrefyWarning"), "its siblings hide")
      Assert.True(env.Header("SETTINGS_SECTION_VIP_GUESTS"):IsShown(), "the VIP heading stays")
      Assert.False(env.ContentFrame("line"):IsShown(), "the VIP separator hides")

      env.Type("resetui")
      local resetUi = env.Entry("resetUiBtn")
      Assert.True(resetUi.region:GetParent():IsShown(), "the reset-UI button is visible")
      Assert.False(env.Entry("resetDBBtn").region:GetParent():IsShown(), "the reset-all button hides")
      local hint = nil
      for _, fontString in ipairs(env.panel.content._fontStrings) do
        local _, relativeTo = fontString:GetPoint()
        if relativeTo == resetUi.region:GetParent() then
          hint = fontString
        end
      end
      Assert.True(hint ~= nil and hint:IsShown(), "the reset-UI hint stays with its button")

      env.Type("")
      Assert.True(preview:IsShown(), "clearing shows the preview again")
      Assert.True(previewButtons.tank_died:IsShown(), "clearing shows every sound preview button")
      Assert.True(env.Entry("resetDBBtn").region:GetParent():IsShown(), "clearing shows the reset-all button")
    end)
  end)

  test("Config search box debounces, ESC clears first and closes second, closing clears", function()
    WithSearchPanel({}, function(env)
      local box = env.Box()
      local panel = env.panel
      Assert.Equal(env.panel.window.searchPlaceholder:GetText(), env.L().CONFIG_SEARCH_PLACEHOLDER, "placeholder")
      box:SetText("mini")
      box._scripts.OnTextChanged(box, true)
      box:SetText("minimap")
      box._scripts.OnTextChanged(box, true)
      Assert.Equal(#env.timers, 2, "every keystroke schedules the debounce")
      Assert.Equal(panel.GetSearchResult(), nil, "nothing filters before the debounce ends")
      env.RunTimers()
      Assert.False(env.Shown("lang"), "only the last keystroke filters")
      Assert.Equal(panel.window.GetSearchText(), "minimap", "the applied text")

      box._scripts.OnEscapePressed(box)
      Assert.Equal(box:GetText(), "", "the first ESC empties the box")
      Assert.True(env.Shown("lang"), "the first ESC restores every control at once")
      Assert.True(panel.IsOpen(), "the first ESC keeps the window open")
      box._scripts.OnEscapePressed(box)
      Assert.False(panel.IsOpen(), "the second ESC closes the window")

      panel.Open()
      env.Type("minimap")
      Assert.False(env.Shown("lang"), "setup: a search is active")
      env.CloseWindow()
      Assert.Equal(box:GetText(), "", "closing clears the search text")
      Assert.True(env.Shown("lang"), "closing restores every control")
      panel.Open()
      Assert.Equal(panel.GetSearchResult().active, false, "the reopened window has no search")

      -- Typing and closing before the debounce ends filters nothing.
      box:SetText("sound")
      box._scripts.OnTextChanged(box, true)
      panel.Close()
      env.RunTimers()
      Assert.True(env.Shown("lang"), "no filter work runs while the window is closed")
    end)
  end)

  test("Config search works in combat without protected calls", function()
    WithSearchPanel({
      inCombat = function()
        return true
      end,
      frameStubOpts = {
        simulateProtectedFrames = true,
        isInCombat = function()
          return true
        end,
      },
    }, function(env)
      env.Type("bloodlust")
      Assert.True(env.Shown("soundChecks.bloodlust"), "the search filters in combat")
      env.Type("")
      Assert.True(env.Shown("lang"), "clearing works in combat")
    end)
  end)
end
