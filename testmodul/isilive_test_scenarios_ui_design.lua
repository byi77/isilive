---@diagnostic disable: undefined-global, undefined-field
-- UI design switch (rule 233): schema default, in-place theme application,
-- the ADDON_LOADED apply path, the settings selector and /isilive design.
local unpack = rawget(_G, "unpack") or (type(table) == "table" and rawget(table, "unpack")) or nil
local FactoryFixture = dofile("testmodul/isilive_test_factory_fixture.lua")
local BuildGlobals = FactoryFixture.buildGlobals
local GetAllIsiLiveFiles = FactoryFixture.moduleFiles

local function CopyArray(source)
  local copy = {}
  for index = 1, #source do
    copy[index] = source[index]
  end
  return copy
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  local function AssertSameArray(actual, expected, message)
    Assert.Equal(#actual, #expected, message .. " (length)")
    for index = 1, #expected do
      Assert.Equal(actual[index], expected[index], message .. " [" .. index .. "]")
    end
  end

  local function ContainsLine(lines, needle)
    for _, line in ipairs(lines) do
      if string.find(line, needle, 1, true) then
        return true
      end
    end
    return false
  end

  -- Boots the real composition root with IsiLiveDB still missing (file-load
  -- state), then restores `savedDb` and fires the real ADDON_LOADED handler.
  -- `beforeAddonLoaded(addon)` runs between the two steps.
  local function BootFactory(savedDb, beforeAddonLoaded)
    local globals = BuildGlobals()
    globals.IsiLiveDB = nil
    local printed = {}
    globals.print = function(msg)
      printed[#printed + 1] = tostring(msg)
    end
    local baseCreateFrame = globals.CreateFrame
    local created = {}
    globals.CreateFrame = function(...)
      local frame = baseCreateFrame(...)
      created[#created + 1] = frame
      return frame
    end
    globals.Settings = {
      RegisterAddOnCategory = function() end,
      RegisterCanvasLayoutCategory = function(canvas, _name)
        return { ID = "isiLive-settings", canvas = canvas }
      end,
    }
    local env = { globals = globals, printed = printed, created = created, db = savedDb }
    WithGlobals(globals, function()
      -- The composition fixture leaves the schema out; the ADDON_LOADED
      -- sanitizer pass is part of what these tests drive.
      local files = GetAllIsiLiveFiles()
      table.insert(files, 1, "isiLive_db_schema.lua")
      env.addon = LoadAddonModules(files)
      env.runtime = env.addon.Factory.InitializeAddon("isiLive", env.addon, { returnContext = true })
      if type(beforeAddonLoaded) == "function" then
        beforeAddonLoaded(env.addon)
      end
      -- Later WithGlobals blocks re-install the globals table, so the restored
      -- DB has to live there as well.
      globals.IsiLiveDB = savedDb
      _G.IsiLiveDB = savedDb
      local onEvent = Assert.NotNil(env.runtime.eventFrame:GetScript("OnEvent"), "event frame must have OnEvent")
      onEvent(env.runtime.eventFrame, "ADDON_LOADED", "isiLive")
    end)
    return env
  end

  test("UI design defaults to classic and unknown values sanitize to classic", function()
    local DBSchema = LoadAddonModules({ "isiLive_db_schema.lua" }).DBSchema
    local db = {}
    DBSchema.Sanitize(db)
    Assert.Equal(db.uiDesign, "classic", "fresh install must default to the classic design")

    db.uiDesign = "neon"
    DBSchema.Sanitize(db)
    Assert.Equal(db.uiDesign, "classic", "an unknown design must fall back to classic")

    db.uiDesign = 7
    DBSchema.Sanitize(db)
    Assert.Equal(db.uiDesign, "classic", "a non-string design must fall back to classic")

    db.uiDesign = "modern"
    DBSchema.Sanitize(db)
    Assert.Equal(db.uiDesign, "modern", "the modern design must be preserved")
  end)

  test("UI design modern ships a palette of known tokens and classic restores every token", function()
    local UICommon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_design.lua" }).UICommon
    local before = {}
    for token, color in pairs(UICommon.Colors) do
      before[token] = CopyArray(color)
    end
    local overrideCount = 0
    for token in pairs(UICommon.ThemeOverrides.modern) do
      Assert.NotNil(before[token], "modern must only override existing tokens: " .. token)
      overrideCount = overrideCount + 1
    end
    Assert.True(overrideCount > 0, "modern must ship color overrides")

    Assert.Equal(UICommon.GetActiveDesign(), "classic", "classic must be active before any apply")
    local design, changed = UICommon.ApplyDesign("modern")
    Assert.Equal(design, "modern", "modern must be a known design")
    Assert.True(changed, "the modern palette must change colors")
    Assert.Equal(UICommon.GetActiveDesign(), "modern", "modern must be reported as active")
    AssertSameArray(
      UICommon.Colors.SURFACE_MAIN_FRAME,
      UICommon.ThemeOverrides.modern.SURFACE_MAIN_FRAME,
      "modern must reach the main frame surface token"
    )

    UICommon.ApplyDesign("classic")
    for token, color in pairs(UICommon.Colors) do
      AssertSameArray(color, before[token], "classic must restore " .. token)
    end
  end)

  -- COMPONENT-ONLY: the repaint registry is a UICommon surface; these mocks
  -- record exactly the widget calls it makes (backdrop colors, text colors,
  -- created decoration textures and their visibility).
  local function NewRegion()
    local region = { shown = true }
    function region:Show()
      self.shown = true
    end
    function region:Hide()
      self.shown = false
    end
    function region:IsShown()
      return self.shown
    end
    function region:SetPoint() end
    function region:SetAllPoints() end
    function region:AddMaskTexture(mask)
      self.mask = mask
    end
    function region:RemoveMaskTexture(mask)
      if self.mask == mask then
        self.mask = nil
      end
    end
    function region:SetBlendMode() end
    function region:SetWidth() end
    function region:SetHeight() end
    function region:SetTexture(path)
      self.texture = path
    end
    function region:SetGradient(orientation, from, to)
      self.gradient = { orientation, from, to }
    end
    function region:SetTextColor(r, g, b, a)
      self.textColor = { r, g, b, a }
    end
    function region:SetColorTexture(r, g, b, a)
      self.colorTexture = { r, g, b, a }
    end
    function region:SetSize() end
    function region:ClearAllPoints() end
    function region:SetJustifyH() end
    function region:SetWordWrap() end
    function region:GetFont()
      return "FontsFRIZQT__.TTF", 12, ""
    end
    function region:SetFont(_path, size)
      self.fontSize = size
    end
    function region:SetText(text)
      self.text = text
    end
    return region
  end

  local function NewBackdropFrame()
    local frame = NewRegion()
    function frame:SetBackdrop(backdrop)
      self.backdrop = backdrop
    end
    function frame:SetBackdropColor(r, g, b, a)
      self.backdropColor = { r, g, b, a }
    end
    function frame:SetBackdropBorderColor(r, g, b, a)
      self.borderColor = { r, g, b, a }
    end
    function frame:CreateTexture()
      local texture = NewRegion()
      self.textures = self.textures or {}
      self.textures[#self.textures + 1] = texture
      return texture
    end
    function frame:CreateFontString()
      return NewRegion()
    end
    return frame
  end

  test("UI design repaints built surfaces and token paints and toggles modern decorations", function()
    WithGlobals({
      CreateColor = function(r, g, b, a)
        return { r = r, g = g, b = b, a = a }
      end,
    }, function()
      local UICommon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_design.lua" }).UICommon
      local mainFrame = NewBackdropFrame()
      local runCard = NewBackdropFrame()
      local label = NewRegion()
      UICommon.ApplyBackdrop(mainFrame, "MAIN_FRAME")
      UICommon.ApplyBackdrop(runCard, "CD_BOX")
      UICommon.PaintToken(label, "SetTextColor", "TEXT_SECTION")
      Assert.Nil(mainFrame._isiLiveDesignDecor, "classic must not decorate the main frame")
      Assert.Nil(mainFrame.textures, "classic must not create decoration textures")
      local classicBorder = CopyArray(mainFrame.borderColor)
      local classicLabel = CopyArray(label.textColor)

      UICommon.ApplyDesign("modern")
      local modern = UICommon.ThemeOverrides.modern
      AssertSameArray(mainFrame.borderColor, modern.BORDER_TITLE_BAR, "the built main frame must get the modern border")
      AssertSameArray(
        { label.textColor[1], label.textColor[2], label.textColor[3] },
        modern.TEXT_SECTION,
        "a token paint must be repainted with the modern token"
      )
      local mainDecor = Assert.NotNil(mainFrame._isiLiveDesignDecor, "modern must decorate the main frame")
      Assert.True(#mainDecor.mainFrame > 0, "the main frame decoration must create regions")
      for _, region in ipairs(mainDecor.mainFrame) do
        Assert.True(region:IsShown(), "modern decorations must be shown")
        Assert.NotNil(region.gradient, "modern decorations are drawn as gradients")
      end
      local cardDecor = Assert.NotNil(runCard._isiLiveDesignDecor, "modern must decorate run cards")
      Assert.Equal(#cardDecor.runCard, 2, "a run card gets an accent stripe and a top highlight")

      local lateCard = NewBackdropFrame()
      UICommon.ApplyBackdrop(lateCard, "MPLUS_BOX")
      Assert.NotNil(lateCard._isiLiveDesignDecor, "a surface built after the switch must be decorated at once")

      local tile = NewBackdropFrame()
      tile.icon = NewRegion()
      function tile.icon:ClearAllPoints()
        self.points = {}
      end
      function tile.icon:SetPoint(point, _relative, _relativePoint, x, y)
        self.points[point] = { x, y }
      end
      UICommon.RegisterDesignSurface(tile, "PORTAL_TILE")
      local tileDecor = Assert.NotNil(tile._isiLiveDesignDecor, "modern must decorate a registered portal tile")
      Assert.True(#tileDecor.portalTile > 0, "the portal tile decoration must create regions")
      AssertSameArray(tile.icon.points.TOPLEFT, { 1, -1 }, "modern must widen the tile artwork to a 1 px inset")

      local forcesBar = NewBackdropFrame()
      forcesBar.height = 10
      function forcesBar:GetHeight()
        return self.height
      end
      function forcesBar:SetHeight(height)
        self.height = height
      end
      UICommon.RegisterDesignSurface(forcesBar, "FORCES_BAR")
      Assert.Equal(forcesBar.height, 12, "modern must thicken the forces bar")
      Assert.NotNil(forcesBar._isiLiveDesignDecor, "modern must decorate the forces bar")

      local flatButton = NewBackdropFrame()
      UICommon.ApplyBackdrop(flatButton, "FLAT_BUTTON")
      Assert.Nil(flatButton.backdrop.edgeFile, "modern buttons must be borderless")

      local primaryButton = NewBackdropFrame()
      UICommon.ApplyActionButtonVisual(primaryButton, "primary", "default")
      AssertSameArray(
        primaryButton.backdropColor,
        UICommon.Colors.SURFACE_ACTION_SECONDARY,
        "modern must draw primary buttons with the calm secondary surface"
      )
      Assert.Equal(primaryButton._isiLiveSemanticRole, "primary", "the semantic role must stay primary")

      local lockedButton = NewBackdropFrame()
      lockedButton._isiLiveAvailability = "leader"
      UICommon.ApplyActionButtonVisual(lockedButton, "primary", "default")
      AssertSameArray(
        { lockedButton.borderColor[1], lockedButton.borderColor[2], lockedButton.borderColor[3] },
        { modern.BORDER_ACTION_SECONDARY[1], modern.BORDER_ACTION_SECONDARY[2], modern.BORDER_ACTION_SECONDARY[3] },
        "modern must give a leader-locked button the quiet secondary border"
      )

      UICommon.ApplyDesign("classic")
      Assert.NotNil(flatButton.backdrop.edgeFile, "classic must restore the button border")
      AssertSameArray(
        primaryButton.backdropColor,
        UICommon.Colors.SURFACE_ACTION_PRIMARY,
        "classic must give primary buttons their primary surface back"
      )
      AssertSameArray(tile.icon.points.TOPLEFT, { 2, -2 }, "classic must restore the 2 px tile inset")
      Assert.Equal(forcesBar.height, 10, "classic must restore the forces bar height")
      for _, region in ipairs(tileDecor.portalTile) do
        Assert.False(region:IsShown(), "classic must hide the portal tile decorations")
      end
      AssertSameArray(
        { lockedButton.borderColor[1], lockedButton.borderColor[2], lockedButton.borderColor[3] },
        UICommon.Colors.TEXT_SUPPORTING,
        "classic must keep the leader-lock state border"
      )
      AssertSameArray(mainFrame.borderColor, classicBorder, "classic must restore the border")
      AssertSameArray(label.textColor, classicLabel, "classic must restore the token paint")
      for _, region in ipairs(mainDecor.mainFrame) do
        Assert.False(region:IsShown(), "classic must hide the modern decorations")
      end
    end)
  end)

  test("UI design ApplyDesign mutates color arrays in place and restores classic exactly", function()
    local UICommon = LoadAddonModules({ "isiLive_ui_common.lua" }).UICommon
    local colors = UICommon.Colors
    local cachedColors = colors
    local cachedSecondary = colors.BG_SECONDARY
    local cachedAccent = colors.ACCENT_BLUE
    local classicSecondary = CopyArray(cachedSecondary)
    local classicAccent = CopyArray(cachedAccent)
    UICommon.ThemeOverrides.modern = {
      BG_SECONDARY = { 0.2, 0.3, 0.4, 0.9 },
      ACCENT_BLUE = { 0.1, 0.2, 0.3, 0.5 },
      NOT_A_TOKEN = { 1, 1, 1 },
    }

    -- A runtime-owned value set by the background-opacity path.
    UICommon.ApplyBgAlpha({}, 0.8)

    local design, changed = UICommon.ApplyDesign("modern")
    Assert.Equal(design, "modern", "modern must apply")
    Assert.True(changed, "a non-empty overlay must report a change")
    Assert.True(UICommon.Colors == cachedColors, "the Colors table must stay the same table")
    Assert.True(colors.BG_SECONDARY == cachedSecondary, "BG_SECONDARY must be mutated in place")
    Assert.True(colors.ACCENT_BLUE == cachedAccent, "ACCENT_BLUE must be mutated in place")
    AssertSameArray(cachedSecondary, { 0.2, 0.3, 0.4, 0.9 }, "cached BG_SECONDARY must carry the override")
    AssertSameArray(cachedAccent, { 0.1, 0.2, 0.3, 0.5 }, "cached ACCENT_BLUE must carry the override")
    Assert.True(
      UICommon.Theme.color.surface.raised == cachedSecondary,
      "Theme aliases must keep pointing at the mutated token"
    )
    Assert.Nil(colors.NOT_A_TOKEN, "an override for an unknown token must not create one")

    local _, changedAgain = UICommon.ApplyDesign("modern")
    Assert.False(changedAgain, "applying the active design again must be a no-op")
    AssertSameArray(cachedSecondary, { 0.2, 0.3, 0.4, 0.9 }, "a repeated apply must keep the override")

    design, changed = UICommon.ApplyDesign("classic")
    Assert.Equal(design, "classic", "classic must apply")
    Assert.True(changed, "switching back must report a change")
    AssertSameArray(cachedSecondary, classicSecondary, "classic BG_SECONDARY must be restored exactly")
    AssertSameArray(cachedAccent, classicAccent, "classic ACCENT_BLUE must be restored with its arity")
    Assert.Equal(colors.BG_PRIMARY[4], 0.8, "the design switch must not touch the background opacity")

    design, changed = UICommon.ApplyDesign("neon")
    Assert.Equal(design, "classic", "an unknown design must fall back to classic")
    Assert.False(changed, "falling back to the active classic design must not change anything")
  end)

  test("UI design ADDON_LOADED applies the stored design and repaints the main frame", function()
    local overrideSurface = { 0.2, 0.25, 0.3 }
    local env = BootFactory({ locale = "enUS", uiDesign = "modern", bgAlpha = 0.4 }, function(addon)
      Assert.Equal(addon.UICommon.GetActiveDesign(), "classic", "file load must run the classic design")
      addon.UICommon.ThemeOverrides.modern = { SURFACE_MAIN_FRAME = overrideSurface }
    end)
    Assert.Equal(env.addon.UICommon.GetActiveDesign(), "modern", "ADDON_LOADED must apply the stored design")
    AssertSameArray(
      env.addon.UICommon.Colors.SURFACE_MAIN_FRAME,
      overrideSurface,
      "the stored design must reach the color token"
    )
    local r, g, b, a = env.runtime.mainFrame:GetBackdropColor()
    Assert.Equal(r, 0.2, "main frame must be repainted with the design surface (r)")
    Assert.Equal(g, 0.25, "main frame must be repainted with the design surface (g)")
    Assert.Equal(b, 0.3, "main frame must be repainted with the design surface (b)")
    Assert.Equal(a, 0.4, "the repaint must keep the stored background opacity")

    local unknown = BootFactory({ locale = "enUS", uiDesign = "neon" })
    Assert.Equal(unknown.db.uiDesign, "classic", "ADDON_LOADED must sanitize an unknown design to classic")
    Assert.Equal(unknown.addon.UICommon.GetActiveDesign(), "classic", "an unknown design must run classic")
  end)

  test("UI design settings selector stores the design and asks for a reload", function()
    local env = BootFactory({ locale = "enUS" })
    local panel = Assert.NotNil(env.runtime.settingsPanel, "the composition root must create the settings panel")
    WithGlobals(env.globals, function()
      panel.EnsureBuilt()
      local modernButton, classicButton = nil, nil
      for _, frame in ipairs(env.created) do
        if frame._optionLabelKey == "SETTINGS_UI_DESIGN_MODERN" then
          modernButton = frame
        elseif frame._optionLabelKey == "SETTINGS_UI_DESIGN_CLASSIC" then
          classicButton = frame
        end
      end
      modernButton = Assert.NotNil(modernButton, "the general section must offer a Modern button")
      classicButton = Assert.NotNil(classicButton, "the general section must offer a Classic button")
      Assert.Equal(classicButton._backdropColor[4], 0.25, "Classic must be highlighted by default")

      modernButton:GetScript("OnClick")(modernButton, "LeftButton")
      Assert.Equal(env.db.uiDesign, "modern", "clicking Modern must persist IsiLiveDB.uiDesign")
      Assert.True(
        ContainsLine(env.printed, "Design set to Modern. Type /reload to apply it."),
        "switching away from the active design must print the reload hint"
      )
      Assert.Equal(env.addon.UICommon.GetActiveDesign(), "classic", "the switch must not apply before /reload")
      Assert.Equal(modernButton._backdropColor[4], 0.25, "Modern must be highlighted after the click")

      local printedBefore = #env.printed
      classicButton:GetScript("OnClick")(classicButton, "LeftButton")
      Assert.Equal(env.db.uiDesign, "classic", "clicking Classic must persist classic again")
      Assert.Equal(#env.printed, printedBefore, "returning to the active design needs no reload hint")
    end)
  end)

  test("UI design slash command reports, stores and validates the design", function()
    local env = BootFactory({ locale = "enUS" })
    WithGlobals(env.globals, function()
      local slash = Assert.NotNil(env.globals.SlashCmdList.ISILIVE, "/isilive must be registered")

      slash("design")
      Assert.True(ContainsLine(env.printed, "UI design: Classic"), "/isilive design must print the current design")
      Assert.True(ContainsLine(env.printed, "/isilive design classic|modern"), "/isilive design must print the usage")

      slash("design modern")
      Assert.Equal(env.db.uiDesign, "modern", "/isilive design modern must persist the design")
      Assert.True(
        ContainsLine(env.printed, "Design set to Modern. Type /reload to apply it."),
        "/isilive design modern must print the reload hint"
      )

      local printedBefore = #env.printed
      slash("design neon")
      Assert.Equal(env.db.uiDesign, "modern", "an unknown design must not be stored")
      Assert.True(#env.printed > printedBefore, "an unknown design must print the usage")
      Assert.True(
        ContainsLine({ env.printed[#env.printed] }, "/isilive design classic|modern"),
        "an unknown design must end with the usage line"
      )

      slash("design classic")
      Assert.Equal(env.db.uiDesign, "classic", "/isilive design classic must persist classic")
      Assert.Equal(env.printed[#env.printed], "isiLive: UI design: Classic", "classic is already active: no reload")

      local helpStart = #env.printed + 1
      slash("help")
      local helpLines = { unpack(env.printed, helpStart) }
      Assert.True(ContainsLine(helpLines, "/isilive design classic|modern"), "help must list the design command")
    end)
  end)
  test("UI design modern M+ timer leads with elapsed time and shows only the reachable grade", function()
    local UICommon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_design.lua" }).UICommon
    Assert.Nil(UICommon.GetDesignComponent("MPLUS_TIMER"), "classic must not offer a timer variant")
    UICommon.ApplyDesign("modern")
    local timer = Assert.NotNil(UICommon.GetDesignComponent("MPLUS_TIMER"), "modern must offer a timer variant")
    local row = { mplusBox = NewBackdropFrame() }
    for _, key in ipairs({ "mplusLabel", "mp3Icon", "mp3Text", "mp2Icon", "mp2Text", "mp1Icon", "mp1Text" }) do
      row[key] = NewRegion()
    end

    timer.Update(row, {
      timer = 217,
      timeLimit = 1980,
      timeRemaining3 = 971,
      timeRemaining2 = 1367,
      timeRemaining1 = 1763,
    }, 3)
    local parts = Assert.NotNil(row._modernTimer, "the variant must build its parts on the timer box")
    Assert.Equal(parts.elapsed.text, "3:37", "the elapsed time must lead")
    Assert.Equal(parts.limit.text, "/ 33:00", "the time limit must follow the elapsed time")
    Assert.Equal(parts.gradeLabel.text, "+3", "only the reachable grade must be listed")
    Assert.Equal(parts.gradeTime.text, "16:11", "the reachable grade must show its remaining time")
    Assert.False(row.mp3Text:IsShown(), "modern must hide the classic grade texts")
    Assert.False(row.mplusLabel:IsShown(), "modern must hide the classic M+ label")

    timer.Update(row, {
      timer = 2113,
      timeLimit = 1980,
      timeRemaining3 = -925,
      timeRemaining2 = -529,
      timeRemaining1 = -133,
    }, 0)
    Assert.Equal(parts.gradeLabel.text, "+1", "overtime must show the +1 overshoot")
    Assert.Equal(parts.gradeTime.text, "-2:13", "overtime must show the overshoot as negative time")
    AssertSameArray(
      { parts.elapsed.textColor[1], parts.elapsed.textColor[2], parts.elapsed.textColor[3] },
      UICommon.Colors.TEXT_ALERT_DANGER,
      "overtime must paint the elapsed time red"
    )

    timer.Update(row, nil, nil)
    Assert.Equal(parts.elapsed.text, "--:--", "without a key the elapsed time must show the placeholder")
    Assert.Equal(parts.gradeLabel.text, "", "without a key no grade must be listed")

    timer.Release(row)
    Assert.True(row.mp3Text:IsShown(), "release must bring the classic grade texts back")
    Assert.False(parts.elapsed:IsShown(), "release must hide the modern timer parts")
  end)
  test("UI design modern ready-check row uses a status stripe and a light wash instead of a full tint", function()
    WithGlobals({
      CreateColor = function(r, g, b, a)
        return { r = r, g = g, b = b, a = a }
      end,
    }, function()
      local UICommon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_design.lua" }).UICommon
      Assert.Nil(UICommon.GetDesignComponent("READY_CHECK_ROW"), "classic must keep the full-row tint")
      UICommon.ApplyDesign("modern")
      local variant = Assert.NotNil(UICommon.GetDesignComponent("READY_CHECK_ROW"), "modern must restyle the status")
      local row = { hoverFrame = NewBackdropFrame(), readyCheckBackground = NewRegion() }

      variant.Apply(row, { 0.08, 0.5, 0.16, 0.42 })
      local parts = Assert.NotNil(row._modernReadyCheck, "the variant must build its stripe and wash")
      Assert.True(parts.stripe:IsShown(), "a status must show the stripe")
      Assert.True(parts.wash:IsShown(), "a status must show the wash")
      Assert.Nil(parts.wash.gradient, "the per-render wash must not use a gradient (opaque white in the client)")
      Assert.Equal(parts.wash.colorTexture[4], 0.21, "the wash must be a lighter tint than the classic one")
      Assert.False(row.readyCheckBackground:IsShown(), "modern must hide the full-row tint")

      variant.Apply(row, nil)
      Assert.False(parts.stripe:IsShown(), "no status must hide the stripe")

      variant.Apply(row, { 0.48, 0.12, 0.12, 0.34 })
      row._readyCheckStatusKey = "notready"
      variant.Release(row)
      Assert.False(parts.wash:IsShown(), "release must hide the modern status")
      Assert.True(row.readyCheckBackground:IsShown(), "release must bring the classic tint back for a live status")
    end)
  end)
  test("UI design text roles recolor registered texts in modern and restore their own color in classic", function()
    local UICommon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_design.lua" }).UICommon
    local text = NewRegion()
    text.textColor = { 1, 0.82, 0, 1 }
    function text:GetTextColor()
      return self.textColor[1], self.textColor[2], self.textColor[3], self.textColor[4]
    end
    UICommon.RegisterDesignText(text, "RUN_VALUE")
    AssertSameArray(text.textColor, { 1, 0.82, 0, 1 }, "classic must leave a role text untouched")

    UICommon.ApplyDesign("modern")
    local token = UICommon.Colors[UICommon.DesignTextRoles.modern.RUN_VALUE]
    AssertSameArray(
      { text.textColor[1], text.textColor[2], text.textColor[3] },
      { token[1], token[2], token[3] },
      "modern must paint the role token"
    )

    UICommon.ApplyDesign("classic")
    AssertSameArray(text.textColor, { 1, 0.82, 0, 1 }, "classic must restore the font object's own color")
  end)
  test("UI design modern run icons get a round mask, a ring and a circular swipe that classic removes", function()
    local UICommon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_ui_design.lua" }).UICommon
    local card = NewBackdropFrame()
    function card:CreateMaskTexture()
      local mask = NewRegion()
      function mask:SetTexture(path)
        self.texture = path
      end
      return mask
    end
    local icon = NewRegion()
    local cooldown = {}
    function cooldown:SetSwipeTexture(path)
      self.swipe = path
    end
    function cooldown:SetUseCircularEdge(value)
      self.circular = value
    end
    card._isiLiveRunIcons = { { icon = icon, cooldown = cooldown } }
    UICommon.RegisterDesignSurface(card, "RUN_ICONS")
    Assert.Nil(icon.mask, "classic must keep the square icon")
    Assert.Nil(cooldown.swipe, "classic must keep the default swipe")

    UICommon.ApplyDesign("modern")
    local mask = Assert.NotNil(icon.mask, "modern must mask the icon round")
    Assert.True(
      string.find(mask.texture, "TempPortraitAlphaMask", 1, true) ~= nil,
      "the mask must be the portrait circle"
    )
    Assert.Equal(cooldown.swipe, mask.texture, "the swipe must use the same circle")
    Assert.True(cooldown.circular, "the swipe must use a circular edge")

    UICommon.ApplyDesign("classic")
    Assert.Nil(icon.mask, "classic must remove the round mask")
    Assert.False(cooldown.circular, "classic must turn the circular edge off")
    Assert.True(string.find(cooldown.swipe, "WHITE8X8", 1, true) ~= nil, "classic must get the square swipe back")
  end)
  test("Action button label makes room for a shown availability icon", function()
    WithGlobals({
      CreateFrame = function()
        local button = NewBackdropFrame()
        function button:SetSize() end
        function button:EnableMouse() end
        function button:RegisterForClicks() end
        function button:HookScript() end
        function button:SetAlpha() end
        function button:CreateFontString()
          local label = NewRegion()
          label.points = {}
          function label:ClearAllPoints()
            self.points = {}
          end
          function label:SetPoint(point, _relative, _relativePoint, x)
            self.points[point] = x
          end
          return label
        end
        return button
      end,
    }, function()
      local UICommon = LoadAddonModules({ "isiLive_ui_common.lua" }).UICommon
      local button = UICommon.CreateActionButton(nil, { width = 120, height = 24 })
      Assert.Equal(UICommon.GetActionButtonLabelInset(button), 0, "no icon must reserve no space")

      button:SetAvailabilityState("cooldown")
      local inset = UICommon.GetActionButtonLabelInset(button)
      Assert.True(inset >= 17, "a shown cooldown icon must reserve its slot on the left")
      Assert.Equal(button._flatLabel.points.CENTER, inset / 2, "the label must move right by half the reserved space")

      button:SetAvailabilityState("available")
      Assert.Equal(UICommon.GetActionButtonLabelInset(button), 0, "an available button must free the slot again")
      Assert.Equal(button._flatLabel.points.CENTER, 0, "the label must return to the center")
    end)
  end)
end
