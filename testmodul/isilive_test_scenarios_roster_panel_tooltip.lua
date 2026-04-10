local function MakeGameTooltip(tooltipLines)
  return {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function(_self, text)
      table.insert(tooltipLines, text)
    end,
    SetUnit = function(self, unit)
      self._unit = unit
    end,
    GetUnit = function(self)
      return self._unit
    end,
    HookScript = function(self, script, handler)
      self[script] = handler
    end,
    Show = function() end,
    Hide = function() end,
  }
end

local function NewRowTooltipCreateFrameStub(createdFrames, tooltipLines, tooltipOps)
  return function(frameType)
    local f = {
      frameType = frameType,
    }

    f.SetPoint = function() end
    f.SetSize = function(_self, width, height)
      f.width = width
      f.height = height
    end
    f.SetHeight = function(_self, height)
      f.height = height
    end
    f.SetWidth = function(_self, width)
      f.width = width
    end
    f.SetEnabled = function() end
    f.SetAlpha = function() end
    f.EnableMouse = function() end
    f.RegisterForClicks = function() end
    f.GetFrameLevel = function()
      return 1
    end
    f.SetFrameLevel = function() end
    f.SetScript = function(self, script, handler)
      self[script] = handler
    end
    f.CreateTexture = function()
      return {
        SetAllPoints = function() end,
        SetPoint = function() end,
        SetWidth = function() end,
        GetWidth = function()
          return 0
        end,
        SetHeight = function() end,
        SetColorTexture = function() end,
        SetTexture = function() end,
        SetVertexColor = function() end,
        SetTexCoord = function() end,
        Hide = function() end,
        Show = function() end,
        IsShown = function()
          return false
        end,
      }
    end
    f.CreateFontString = function()
      local fontString = {
        text = "",
        SetPoint = function() end,
        SetAllPoints = function() end,
        ClearAllPoints = function() end,
        SetJustifyH = function() end,
        SetWidth = function() end,
        SetTextColor = function() end,
        SetText = function(self, text)
          self.text = tostring(text or "")
          if f._isIsiLiveTooltip == true then
            table.insert(tooltipLines, self.text)
          end
        end,
        GetStringWidth = function(self)
          return #tostring(self.text or "") * 6
        end,
        SetWordWrap = function() end,
        SetNonSpaceWrap = function() end,
        SetMaxLines = function() end,
        Hide = function() end,
        Show = function() end,
      }
      return fontString
    end
    f.Hide = function()
      if tooltipOps and f._isIsiLiveTooltip == true then
        tooltipOps.hideCalls = (tooltipOps.hideCalls or 0) + 1
      end
    end
    f.Show = function()
      if tooltipOps and f._isIsiLiveTooltip == true then
        tooltipOps.showCalls = (tooltipOps.showCalls or 0) + 1
      end
    end

    if tooltipOps then
      f.ClearAllPoints = function() end
      f.SetOwner = function(_self, _anchorFrame, anchor)
        if f._isIsiLiveTooltip == true then
          tooltipOps.setOwnerCalls = (tooltipOps.setOwnerCalls or 0) + 1
          tooltipOps.lastAnchor = anchor
        end
      end
    end

    table.insert(createdFrames, f)
    return f
  end
end

local function NewTooltipMainFrameStub()
  return {
    SetBackdrop = function() end,
    SetBackdropColor = function() end,
    GetFrameLevel = function()
      return 1
    end,
    CreateFontString = function()
      return {
        SetPoint = function() end,
        SetAllPoints = function() end,
        ClearAllPoints = function() end,
        SetWidth = function() end,
        SetJustifyH = function() end,
        GetFont = function()
          return "font", 10, ""
        end,
        SetFont = function() end,
        SetTextColor = function() end,
        SetShadowOffset = function() end,
        SetText = function() end,
        SetWordWrap = function() end,
        SetNonSpaceWrap = function() end,
        SetMaxLines = function() end,
        Hide = function() end,
        Show = function() end,
      }
    end,
    CreateTexture = function()
      return {
        SetAllPoints = function() end,
        SetHeight = function() end,
        SetPoint = function() end,
        SetWidth = function() end,
        GetWidth = function()
          return 0
        end,
        SetColorTexture = function() end,
        SetTexture = function() end,
        SetVertexColor = function() end,
        SetTexCoord = function() end,
        Hide = function() end,
        Show = function() end,
        IsShown = function()
          return false
        end,
      }
    end,
  }
end

local function BuildTooltipController(addon, options)
  options = options or {}
  return addon.RosterPanel.CreateController({
    mainFrame = NewTooltipMainFrameStub(),
    getL = options.getL or function()
      return {}
    end,
    isPlayerLeader = options.isPlayerLeader or function()
      return true
    end,
    getAddonVersionText = function()
      return ""
    end,
    updateStatusLine = function() end,
    setMainFrameHeightSafe = function() end,
    setMainFrameWidthSafe = function() end,
    buildOrderedRoster = options.buildOrderedRoster or function()
      return { { unit = "party1", info = { name = "Buddy", realm = "Realm", class = "WARRIOR" } } }
    end,
    hasFullSync = function()
      return false
    end,
    buildDisplayData = options.buildDisplayData or function()
      return {
        colorHex = "ffffffff",
        displayName = "Buddy",
        languageDisplay = "EN",
        specText = "",
        ilvlText = "",
        rioText = "",
        keyText = "",
        addonMarker = "",
        atDungeonMarker = "",
        readyCheckMarkup = "",
        roleIconMarkup = "",
      }
    end,
    truncateName = options.truncateName or function(text)
      return text
    end,
    getShortSpecLabel = options.getShortSpecLabel or function(text)
      return text
    end,
    getLanguageFlagMarkup = options.getLanguageFlagMarkup or function()
      return ""
    end,
    getLanguageTooltipMarkup = options.getLanguageTooltipMarkup or function(tag)
      if addon.Locale and addon.Locale.GetLanguageTooltipMarkup then
        return addon.Locale.GetLanguageTooltipMarkup(tag, "deDE")
      end
      if addon.Locale and addon.Locale.GetLanguageFlagMarkup then
        return addon.Locale.GetLanguageFlagMarkup(tag)
      end
      return ""
    end,
    getDungeonShortCode = options.getDungeonShortCode or function()
      return ""
    end,
    getDungeonName = options.getDungeonName or function()
      return nil
    end,
    resolveActiveKeyOwnerUnit = options.resolveActiveKeyOwnerUnit or function()
      return nil
    end,
    getRoster = options.getRoster or function()
      return {}
    end,
    isInGroup = options.isInGroup or function()
      return true
    end,
    rolePriority = options.rolePriority or {},
    unitPriority = options.unitPriority or {},
    getPlayerLastRunDps = options.getPlayerLastRunDps,
    getPlayerKickStats = options.getPlayerKickStats,
  })
end

local function FindTooltipRowFrame(createdFrames, tooltipLines)
  for _, frame in ipairs(createdFrames) do
    if frame.OnEnter and frame.unit == "party1" then
      frame.OnEnter()
      if #tooltipLines > 0 then
        return frame
      end
    end
  end

  return nil
end

local function RunTooltipScenario(WithGlobals, LoadAddonModules, Assert, options, configureAddon, verifyFn)
  options = options or {}
  local tooltipLines = {}
  local createdFrames = {}
  local globals = {
    CreateFrame = NewRowTooltipCreateFrameStub(createdFrames, tooltipLines),
    GetTime = options.getTime or function()
      return 100
    end,
    GameTooltip = MakeGameTooltip(tooltipLines),
    RAID_CLASS_COLORS = {},
  }
  if options.isShiftKeyDown then
    globals.IsShiftKeyDown = options.isShiftKeyDown
  end
  if options.abbreviateNumbers then
    globals.AbbreviateNumbers = options.abbreviateNumbers
  end
  if options.extraGlobals then
    for key, value in pairs(options.extraGlobals) do
      globals[key] = value
    end
  end

  WithGlobals(globals, function()
    local addon = LoadAddonModules(
      options.modules
        or { "isiLive_languages.lua", "isiLive_locale.lua", "isiLive_sync.lua", "isiLive_roster_panel.lua" }
    )
    if configureAddon then
      configureAddon(addon)
    end

    local controller = BuildTooltipController(addon, options.controller)
    controller.RenderRoster({})

    local rowFrame = FindTooltipRowFrame(createdFrames, tooltipLines)
    Assert.NotNil(rowFrame, "Should find a row frame with OnEnter")
    verifyFn(addon, controller, rowFrame, tooltipLines, createdFrames)
  end)
end

local function RegisterRosterPanelRowTooltipNoHistoryTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip no longer shows deprecated runs-together history", function()
    RunTooltipScenario(WithGlobals, LoadAddonModules, Assert, {}, function(addon)
      addon.Sync.SetPlayerHelloInfo("Buddy", "Realm", "0.9.36", 2, 90, "inspect")
    end, function(_addon, _controller, _rowFrame, tooltipLines)
      local foundRuns = false
      for _, line in ipairs(tooltipLines) do
        if line:find("Runs together: 5", 1, true) then
          foundRuns = true
        end
      end
      Assert.False(foundRuns, "Tooltip should not contain deprecated runs-together history")
    end)
  end)
end

local function RegisterRosterPanelRowTooltipDpsTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip shows last run DPS when available", function()
    RunTooltipScenario(WithGlobals, LoadAddonModules, Assert, {
      abbreviateNumbers = function(value)
        if value == 321123 then
          return "321.1K"
        end
        return tostring(value)
      end,
      controller = {
        getL = function()
          return {
            TOOLTIP_LAST_RUN_DPS = "Last run DPS: %s",
          }
        end,
        getPlayerLastRunDps = function(name, realm)
          if name == "Buddy" and realm == "Realm" then
            return 321123
          end
          return nil
        end,
      },
    }, function(addon)
      addon.Sync.SetPlayerHelloInfo("Buddy", "Realm", "0.9.36", 2, 80, "inspect")
      addon.Sync.SetPlayerHelloInfo("Buddy", "Realm", "0.9.36", 2, 90, "inspect")
    end, function(_addon, _controller, _rowFrame, tooltipLines)
      local foundDps = false
      local foundSyncInterval = false
      local foundSyncSource = false
      local foundSyncVersion = false
      for _, line in ipairs(tooltipLines) do
        if line:find("Last run DPS: 321.1K", 1, true) then
          foundDps = true
        end
        if line:find("Sync interval: 10s", 1, true) then
          foundSyncInterval = true
        end
        if line:find("Source: inspect", 1, true) then
          foundSyncSource = true
        end
        if line:find("Client version: 0.9.36", 1, true) then
          foundSyncVersion = true
        end
      end
      Assert.True(foundDps, "Tooltip should contain abbreviated last-run DPS")
      Assert.True(foundSyncInterval, "Tooltip should contain sync interval")
      Assert.True(foundSyncSource, "Tooltip should contain sync source")
      Assert.True(foundSyncVersion, "Tooltip should contain client version info")
    end)
  end)
end

local function RegisterRosterPanelRowTooltipKickStatsTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip shows kick counts and failed or missed kicks", function()
    RunTooltipScenario(WithGlobals, LoadAddonModules, Assert, {
      controller = {
        getPlayerKickStats = function(name, realm)
          if name == "Buddy" and realm == "Realm" then
            return {
              kicks = 5,
              failed = 1,
              missed = 2,
            }
          end
          return nil
        end,
      },
    }, function(addon)
      addon.Sync.SetPlayerHelloInfo("Buddy", "Realm", "0.9.36", 2, 90, "inspect")
    end, function(_addon, _controller, _rowFrame, tooltipLines)
      local foundKickStats = false
      for _, line in ipairs(tooltipLines) do
        if line:find("Kick stats: 5 total, 1 failed, 2 missed", 1, true) then
          foundKickStats = true
        end
      end
      Assert.True(foundKickStats, "Tooltip should contain kick counts and failed or missed counts")
    end)
  end)
end

local function RegisterRosterPanelRowTooltipSyncDebugTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip shows sync debug field sources when shift is held", function()
    RunTooltipScenario(WithGlobals, LoadAddonModules, Assert, {
      isShiftKeyDown = function()
        return true
      end,
      abbreviateNumbers = function(value)
        if value == 321123 then
          return "321.1K"
        end
        return tostring(value)
      end,
      controller = {
        getL = function()
          return {
            TOOLTIP_LAST_RUN_DPS = "Last run DPS: %s",
            TOOLTIP_SYNC_DEBUG_HEADER = "Sync debug",
            TOOLTIP_SYNC_DEBUG_HELLO = "Hello",
            TOOLTIP_SYNC_DEBUG_KEY = "Key",
            TOOLTIP_SYNC_DEBUG_STATS = "Stats",
            TOOLTIP_SYNC_DEBUG_DPS = "DPS",
            TOOLTIP_SYNC_DEBUG_LOC = "Loc",
          }
        end,
        getPlayerLastRunDps = function(name, realm)
          if name == "Buddy" and realm == "Realm" then
            return 321123
          end
          return nil
        end,
      },
    }, function(addon)
      addon.Sync.SetPlayerHelloInfo("Buddy", "Realm", "0.9.36", 2, 90, "group")
      addon.Sync.SetPlayerKeyInfo("Buddy", "Realm", 2649, 15, 89, "refresh")
      addon.Sync.SetPlayerStatsInfo("Buddy", "Realm", 72, 615, 3210, 88, "inspect")
      addon.Sync.SetPlayerDpsInfo("Buddy", "Realm", 321123, 87, "world")
      addon.Sync.SetPlayerLocInfo("Buddy", "Realm", 2649, 86, "zone")
    end, function(_addon, _controller, _rowFrame, tooltipLines)
      local foundDebugHeader = false
      local foundHello = false
      local foundKey = false
      local foundStats = false
      local foundDps = false
      local foundLoc = false
      for _, line in ipairs(tooltipLines) do
        if line:find("Sync debug", 1, true) then
          foundDebugHeader = true
        end
        if line:find("Hello: group (10s)", 1, true) then
          foundHello = true
        end
        if line:find("Key: refresh (11s)", 1, true) then
          foundKey = true
        end
        if line:find("Stats: inspect (12s)", 1, true) then
          foundStats = true
        end
        if line:find("DPS: world (13s)", 1, true) then
          foundDps = true
        end
        if line:find("Loc: zone (14s)", 1, true) then
          foundLoc = true
        end
      end
      Assert.True(foundDebugHeader, "Tooltip should contain sync debug header")
      Assert.True(foundHello, "Tooltip should contain hello sync source")
      Assert.True(foundKey, "Tooltip should contain key sync source")
      Assert.True(foundStats, "Tooltip should contain stats sync source")
      Assert.True(foundDps, "Tooltip should contain DPS sync source")
      Assert.True(foundLoc, "Tooltip should contain location sync source")
    end)
  end)
end

local function RegisterRosterPanelRowTooltipFullKeyNameTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster row tooltip shows full dungeon name instead of key short code", function()
    RunTooltipScenario(WithGlobals, LoadAddonModules, Assert, {
      controller = {
        buildOrderedRoster = function()
          return {
            {
              unit = "party1",
              info = {
                name = "Buddy",
                realm = "Realm",
                class = "MAGE",
                keyMapID = 558,
                keyLevel = 12,
              },
            },
          }
        end,
        getDungeonShortCode = function(mapID)
          if mapID == 558 then
            return "TDM"
          end
          return nil
        end,
        getDungeonName = function(mapID)
          if mapID == 558 then
            return "Terrasse der Magister"
          end
          return nil
        end,
      },
    }, function(addon)
      addon.Sync.SetPlayerHelloInfo("Buddy", "Realm", "0.9.36", 2, 90, "inspect")
    end, function(_addon, _controller, _rowFrame, tooltipLines)
      local foundFullName = false
      local foundShortCode = false
      for _, line in ipairs(tooltipLines) do
        if line:find("Key: Terrasse der Magister +12", 1, true) then
          foundFullName = true
        end
        if line:find("Key: TDM +12", 1, true) then
          foundShortCode = true
        end
      end
      Assert.True(foundFullName, "Tooltip should show the full dungeon name for the key")
      Assert.False(foundShortCode, "Tooltip should no longer show the dungeon short code in the key line")
    end)
  end)
end

local function RegisterRosterPanelRowTooltipHistoryAndDpsTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipNoHistoryTest(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipDpsTest(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipKickStatsTest(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipSyncDebugTest(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipFullKeyNameTest(test, Assert, WithGlobals, LoadAddonModules)
end

local function RegisterBlizzardUnitTooltipLanguageFlagTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Blizzard GameTooltip shows server language name for player hovers", function()
    local tooltipLines = {}
    local createdFrames = {}
    local gameTooltip = MakeGameTooltip(tooltipLines)

    WithGlobals({
      CreateFrame = NewRowTooltipCreateFrameStub(createdFrames, tooltipLines),
      GameTooltip = gameTooltip,
      hooksecurefunc = function(target, method, callback)
        local original = target[method]
        target[method] = function(self, ...)
          if type(original) == "function" then
            original(self, ...)
          end
          return callback(self, ...)
        end
      end,
      UnitIsPlayer = function(unit)
        return unit == "mouseover"
      end,
      UnitExists = function(unit)
        return unit == "mouseover"
      end,
      RAID_CLASS_COLORS = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua", "isiLive_roster_tooltip.lua" })
      local registered = addon._RosterInternal.RegisterBlizzardUnitLanguageTooltip({
        getLanguageTooltipMarkup = function(tag)
          Assert.Equal(tag, "FR", "Tooltip hook must resolve the 2-letter server language tag")
          return "|Tflag-fr:0|t Französisch"
        end,
        getUnitNameAndRealm = function(unit)
          Assert.Equal(unit, "mouseover", "Tooltip hook must receive the hovered unit token")
          return "Traveler", "Argent Dawn"
        end,
        getUnitServerLanguage = function(unit, realm)
          Assert.Equal(unit, "mouseover", "Tooltip hook must receive the hovered unit token")
          Assert.Equal(
            realm,
            "Argent Dawn",
            "Tooltip hook must use the hovered unit realm, not the current player realm"
          )
          return "FR"
        end,
      })

      Assert.True(registered, "Blizzard tooltip language hook must register successfully")

      gameTooltip:SetUnit("mouseover")

      local foundLanguage = false
      local foundLanguageText = false
      for _, line in ipairs(tooltipLines) do
        if line == "|Tflag-fr:0|t Französisch" then
          foundLanguage = true
        end
        if line:find("Lang:", 1, true) then
          foundLanguageText = true
        end
      end
      Assert.True(foundLanguage, "Blizzard tooltip should show the server language name")
      Assert.False(foundLanguageText, "Blizzard tooltip should not show language letters")
      Assert.Equal(#tooltipLines, 1, "Blizzard tooltip should append the language line exactly once")

      if type(gameTooltip.OnTooltipCleared) == "function" then
        gameTooltip:OnTooltipCleared()
      end
      gameTooltip:SetUnit("mouseover")
      Assert.Equal(#tooltipLines, 2, "clearing the Blizzard tooltip should allow the language line to be added again")
    end)
  end)
end

local function RegisterBlizzardUnitTooltipDataProcessorTest(test, Assert, WithGlobals, LoadAddonModules)
  test("Blizzard GameTooltip shows server language name via TooltipDataProcessor for GUID hovers", function()
    local tooltipLines = {}
    local gameTooltip = MakeGameTooltip(tooltipLines)
    local postCallCallbacks = {}

    WithGlobals({
      GameTooltip = gameTooltip,
      hooksecurefunc = function()
        return nil
      end,
      TooltipDataProcessor = {
        AddTooltipPostCall = function(dataType, callback)
          Assert.Equal(dataType, 1, "TooltipDataProcessor must register the unit tooltip type")
          table.insert(postCallCallbacks, callback)
        end,
      },
      Enum = {
        TooltipDataType = {
          Unit = 1,
        },
      },
      RAID_CLASS_COLORS = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua", "isiLive_roster_tooltip.lua" })
      local registered = addon._RosterInternal.RegisterBlizzardUnitLanguageTooltip({
        getLanguageTooltipMarkup = function(tag)
          Assert.Equal(tag, "FR", "Tooltip hook must resolve the 2-letter server language tag")
          return "|Tflag-fr:0|t Französisch"
        end,
        getUnitNameAndRealm = function(_unit)
          error("GUID-only tooltip hovers should not use the unit-token resolver")
        end,
        getUnitServerLanguage = function(_unit, _realm)
          error("GUID-only tooltip hovers should not use the unit-token resolver")
        end,
        getRealmInfoLib = function()
          return {
            GetRealmInfoByGUID = function(_self, guid)
              Assert.Equal(guid, "Player-3685-0ABCDEF1", "Tooltip hook must resolve the hovered player GUID")
              return nil, nil, nil, nil, "frFR"
            end,
          }
        end,
      })

      Assert.True(registered, "Blizzard tooltip language hook must register successfully")
      Assert.Equal(#postCallCallbacks, 1, "TooltipDataProcessor must register exactly one unit post-call")

      for _, callback in ipairs(postCallCallbacks) do
        callback(gameTooltip, {
          guid = "Player-3685-0ABCDEF1",
          isPlayer = true,
          dataInstanceID = 43049,
        })
      end

      local foundLanguage = false
      for _, line in ipairs(tooltipLines) do
        if line == "|Tflag-fr:0|t Französisch" then
          foundLanguage = true
        end
      end
      Assert.True(foundLanguage, "Blizzard tooltip should show the server language name")
      Assert.Equal(#tooltipLines, 1, "Blizzard tooltip should append the language line exactly once")
      Assert.Equal(
        gameTooltip._isiLiveLanguageFlagUnit,
        43049,
        "TooltipDataProcessor hovers should cache the data instance id"
      )

      if type(gameTooltip.OnTooltipCleared) == "function" then
        gameTooltip:OnTooltipCleared()
      end
      for _, callback in ipairs(postCallCallbacks) do
        callback(gameTooltip, {
          guid = "Player-3685-0ABCDEF1",
          isPlayer = true,
          dataInstanceID = 43049,
        })
      end
      Assert.Equal(#tooltipLines, 2, "clearing the Blizzard tooltip should allow the language line to be added again")
    end)
  end)
end

local function RegisterBlizzardUnitTooltipDataProcessorSkipTest(test, Assert, WithGlobals, LoadAddonModules)
  test(
    "Blizzard GameTooltip skips TooltipDataProcessor hovers without a GUID instead of probing the unit token",
    function()
      local tooltipLines = {}
      local gameTooltip = MakeGameTooltip(tooltipLines)
      gameTooltip.GetUnit = function()
        error("TooltipDataProcessor hovers without a GUID should not probe the tooltip unit")
      end
      local postCallCallbacks = {}

      WithGlobals({
        GameTooltip = gameTooltip,
        hooksecurefunc = function()
          return nil
        end,
        TooltipDataProcessor = {
          AddTooltipPostCall = function(dataType, callback)
            Assert.Equal(dataType, 1, "TooltipDataProcessor must register the unit tooltip type")
            table.insert(postCallCallbacks, callback)
          end,
        },
        Enum = {
          TooltipDataType = {
            Unit = 1,
          },
        },
        RAID_CLASS_COLORS = {},
      }, function()
        local addon = LoadAddonModules({ "isiLive_languages.lua", "isiLive_locale.lua", "isiLive_roster_tooltip.lua" })
        local registered = addon._RosterInternal.RegisterBlizzardUnitLanguageTooltip({
          getLanguageTooltipMarkup = function()
            error("unit hovers without a GUID should not resolve a language")
          end,
          getUnitNameAndRealm = function()
            error("unit hovers without a GUID should not probe the tooltip unit")
          end,
          getUnitServerLanguage = function()
            error("unit hovers without a GUID should not probe the tooltip unit")
          end,
        })

        Assert.True(registered, "Blizzard tooltip language hook must register successfully")
        Assert.Equal(#postCallCallbacks, 1, "TooltipDataProcessor must register exactly one unit post-call")

        for _, callback in ipairs(postCallCallbacks) do
          callback(gameTooltip, {
            type = 2,
            lines = {},
          })
        end

        Assert.Equal(#tooltipLines, 0, "TooltipDataProcessor hovers without GUIDs should not append a language line")
        Assert.Equal(
          gameTooltip._isiLiveLanguageFlagUnit,
          nil,
          "TooltipDataProcessor hovers without GUIDs should not cache a language key"
        )
      end)
    end
  )
end

return function(test, ctx)
  RegisterRosterPanelRowTooltipHistoryAndDpsTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
  RegisterBlizzardUnitTooltipLanguageFlagTest(test, ctx.assert, ctx.with_globals, ctx.load_modules)
  RegisterBlizzardUnitTooltipDataProcessorTest(test, ctx.assert, ctx.with_globals, ctx.load_modules)
  RegisterBlizzardUnitTooltipDataProcessorSkipTest(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
