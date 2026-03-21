local function MakeGameTooltip(tooltipLines)
  return {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function(_self, text)
      table.insert(tooltipLines, text)
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
    f.SetScript = function(self, script, handler)
      self[script] = handler
    end
    f.CreateTexture = function()
      return {
        SetAllPoints = function() end,
        SetColorTexture = function() end,
        SetTexture = function() end,
        SetTexCoord = function() end,
        Hide = function() end,
        Show = function() end,
      }
    end
    f.CreateFontString = function()
      local fontString = {
        text = "",
        SetPoint = function() end,
        SetJustifyH = function() end,
        SetWidth = function() end,
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
    CreateFontString = function()
      return {
        SetPoint = function() end,
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
        SetHeight = function() end,
        SetPoint = function() end,
        SetColorTexture = function() end,
        SetTexture = function() end,
        SetTexCoord = function() end,
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
    getDungeonShortCode = options.getDungeonShortCode or function()
      return ""
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
    local addon = LoadAddonModules(options.modules or { "isiLive_sync.lua", "isiLive_roster_panel.lua" })
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
      addon.Sync.SetPlayerHelloInfo("Buddy", "Realm", "0.9.36", 2, 90, "inspect")
    end, function(_addon, _controller, _rowFrame, tooltipLines)
      local foundDps = false
      local foundSyncAge = false
      local foundSyncSource = false
      local foundSyncVersion = false
      for _, line in ipairs(tooltipLines) do
        if line:find("Last run DPS: 321.1K", 1, true) then
          foundDps = true
        end
        if line:find("Sync age: 10s", 1, true) then
          foundSyncAge = true
        end
        if line:find("Source: inspect", 1, true) then
          foundSyncSource = true
        end
        if line:find("Peer version: 0.9.36 (p2)", 1, true) then
          foundSyncVersion = true
        end
      end
      Assert.True(foundDps, "Tooltip should contain abbreviated last-run DPS")
      Assert.True(foundSyncAge, "Tooltip should contain sync age")
      Assert.True(foundSyncSource, "Tooltip should contain sync source")
      Assert.True(foundSyncVersion, "Tooltip should contain peer version info")
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

local function RegisterRosterPanelRowTooltipHistoryAndDpsTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipNoHistoryTest(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipDpsTest(test, Assert, WithGlobals, LoadAddonModules)
  RegisterRosterPanelRowTooltipSyncDebugTest(test, Assert, WithGlobals, LoadAddonModules)
end

return function(test, ctx)
  RegisterRosterPanelRowTooltipHistoryAndDpsTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
