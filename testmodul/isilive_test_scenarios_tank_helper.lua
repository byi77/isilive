---@diagnostic disable: undefined-global

local function NewRecordedTexture()
  return {
    SetAllPoints = function() end,
    SetColorTexture = function() end,
    SetHeight = function() end,
    SetPoint = function() end,
    SetWidth = function() end,
    GetWidth = function()
      return 0
    end,
    SetTexture = function(self, texture)
      self.texture = texture
    end,
    SetTexCoord = function(self, ...)
      self.texCoord = { ... }
    end,
    SetVertexColor = function(self, ...)
      self.vertexColor = { ... }
    end,
    Hide = function(self)
      self.hidden = true
    end,
    Show = function(self)
      self.hidden = false
    end,
    IsShown = function(self)
      return not self.hidden
    end,
  }
end

local function NewRecordedFontString(createdFontStrings)
  local fontString = {
    wordWrap = nil,
    nonSpaceWrap = nil,
    maxLines = nil,
    width = nil,
    hidden = false,
    point = nil,
    pointX = nil,
    pointY = nil,
  }

  function fontString:SetPoint(point, ...)
    local args = { ... }
    self.point = point
    if #args >= 4 then
      self.pointX = args[3]
      self.pointY = args[4]
    elseif #args >= 2 then
      self.pointX = args[1]
      self.pointY = args[2]
    elseif #args == 1 then
      self.pointX = args[1]
      self.pointY = nil
    else
      self.pointX = nil
      self.pointY = nil
    end
  end
  function fontString:ClearAllPoints()
    self.point = nil
    self.pointX = nil
    self.pointY = nil
  end
  function fontString:SetAllPoints()
    self.point = "ALL"
    self.pointX = nil
    self.pointY = nil
  end
  function fontString:Hide()
    self.hidden = true
  end
  function fontString:Show()
    self.hidden = false
  end
  function fontString:SetWidth(value)
    self.width = value
  end
  function fontString.SetJustifyH(_self) end
  function fontString.GetFont(_self)
    return "font", 10, ""
  end
  function fontString.SetFont(_self) end
  function fontString.SetTextColor(_self) end
  function fontString.SetShadowOffset(_self) end
  function fontString:SetText(value)
    self.text = value
  end
  function fontString:SetWordWrap(value)
    self.wordWrap = value
  end
  function fontString:SetNonSpaceWrap(value)
    self.nonSpaceWrap = value
  end
  function fontString:SetMaxLines(value)
    self.maxLines = value
  end

  table.insert(createdFontStrings, fontString)
  return fontString
end

local function NewRecordedFrame(createdFrames, createdFontStrings, frameType, name, parent, template)
  local frame = {
    _frameType = frameType,
    _name = name,
    _parent = parent,
    _template = template,
    _attributes = {},
    _shown = true,
    pointY = nil,
    pointX = nil,
    normalTexture = nil,
  }

  function frame:SetSize(width, height)
    self.width = width
    self.height = height
  end
  function frame:SetWidth(value)
    self.width = value
  end
  function frame:SetHeight(value)
    self.height = value
  end
  function frame:GetWidth()
    return self.width or 0
  end
  function frame:GetHeight()
    return self.height or 0
  end
  function frame:SetPoint(point, ...)
    local args = { ... }
    self.point = point
    if #args >= 4 then
      self.relativeTo = args[1]
      self.relativePoint = args[2]
      self.pointX = args[3]
      self.pointY = args[4]
    elseif #args >= 2 then
      self.pointX = args[1]
      self.pointY = args[2]
    elseif #args == 1 then
      self.pointX = args[1]
      self.pointY = nil
    else
      self.pointX = nil
      self.pointY = nil
    end
  end
  function frame:ClearAllPoints()
    self.point = nil
    self.pointX = nil
    self.pointY = nil
    self.relativeTo = nil
    self.relativePoint = nil
  end
  function frame:GetPoint()
    return self.point or "TOPRIGHT", self.relativeTo, self.relativePoint, self.pointX, self.pointY
  end
  function frame:SetScript(script, handler)
    self[script] = handler
  end
  function frame:SetAttribute(key, value)
    self._attributes[key] = value
  end
  function frame:GetAttribute(key)
    return self._attributes[key]
  end
  function frame.EnableMouse(_self) end
  function frame:SetMouseClickEnabled(value)
    self.mouseClickEnabled = value
  end
  function frame.RegisterForClicks(_self) end
  function frame:SetFrameLevel(value)
    self._frameLevel = value
  end
  function frame:SetEnabled(value)
    self.enabled = value and true or false
  end
  function frame:SetAlpha(value)
    self.alpha = value
  end
  function frame:GetFrameLevel()
    return self._frameLevel or 1
  end
  function frame:SetShown(shown)
    self._shown = shown and true or false
  end
  function frame.CreateTexture(_self)
    return NewRecordedTexture()
  end
  function frame.CreateFontString(_self)
    return NewRecordedFontString(createdFontStrings)
  end
  function frame:Hide()
    self._shown = false
  end
  function frame:Show()
    self._shown = true
  end
  function frame:SetNormalTexture(tex)
    self.normalTexture = tex
  end
  function frame:SetPushedTexture(tex)
    self.pushedTexture = tex
  end
  function frame:SetHighlightTexture(tex)
    self.highlightTexture = tex
  end
  function frame:SetBackdrop(backdrop)
    self._backdrop = backdrop
  end
  function frame:SetBackdropColor(r, g, b, a)
    self._backdropColor = { r, g, b, a }
  end
  function frame:SetBackdropBorderColor(r, g, b, a)
    self._backdropBorderColor = { r, g, b, a }
  end

  table.insert(createdFrames, frame)
  return frame
end

local function NewRecordedMainFrame(createdFontStrings)
  local mainFrame = {
    width = 0,
    height = 0,
  }

  function mainFrame.SetBackdrop(_self) end
  function mainFrame.SetBackdropColor(_self) end
  function mainFrame.IsShown(_self)
    return true
  end
  function mainFrame.CreateFontString(_self)
    return NewRecordedFontString(createdFontStrings)
  end
  function mainFrame.CreateTexture(_self)
    return NewRecordedTexture()
  end
  function mainFrame:SetWidth(w)
    self.width = w
  end
  function mainFrame.GetFrameStrata(_self)
    return "MEDIUM"
  end
  function mainFrame.GetFrameLevel(_self)
    return 1
  end

  return mainFrame
end

local function FindFrameByProperty(createdFrames, key, value)
  for _, frame in ipairs(createdFrames) do
    if frame[key] == value then
      return frame
    end
  end
  return nil
end

local function FindFontStringByPoint(createdFontStrings, point, x, y)
  for _, fontString in ipairs(createdFontStrings) do
    if fontString.point == point and fontString.pointX == x and fontString.pointY == y then
      return fontString
    end
  end
  return nil
end

local function RegisterNativeWorldMarkerButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  test("M+Marker buttons use native world-marker secure attributes", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      CreateFrame = function(frameType, name, parent, template)
        return NewRecordedFrame(createdFrames, createdFontStrings, frameType, name, parent, template)
      end,
      IsCombatLockdownActive = function()
        return false
      end,
      InCombatLockdown = function()
        return false
      end,
      C_CVar = {
        GetCVar = function()
          return "0"
        end,
        SetCVar = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_roster_panel.lua" })
      addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return { TANK_HELPER_HEADER = "M+Marker" }
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function()
          return {}
        end,
        buildDisplayData = function(info)
          return {
            colorHex = "ffffffff",
            displayName = tostring(info and info.name or ""),
            languageDisplay = "",
            specText = "",
            ilvlText = "-",
            rioText = "-",
            keyText = "-",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
          }
        end,
        truncateName = function(name)
          return name
        end,
        getShortSpecLabel = function(spec)
          return spec
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return ""
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        rolePriority = {},
        unitPriority = {},
        isPlayerLeader = function()
          return true
        end,
        isInGroup = function()
          return true
        end,
        isRaidGroup = function()
          return false
        end,
      })
    end)

    local tankHelperButtons = {}
    for _, frame in ipairs(createdFrames) do
      if frame._template == "SecureActionButtonTemplate" then
        if frame:GetAttribute("type1") == "worldmarker" then
          table.insert(tankHelperButtons, frame)
        end
      end
    end

    table.sort(tankHelperButtons, function(a, b)
      return a.pointY > b.pointY
    end)

    Assert.Equal(#tankHelperButtons, 8, "Should create 8 M+Marker world-marker buttons")
    Assert.Equal(
      tankHelperButtons[1].pointX,
      -111,
      "M+Marker column should occupy the compact helper slot in expanded mode"
    )
    local readyCheckButton = nil
    for _, frame in ipairs(createdFrames) do
      if
        (
          frame._template == "UIPanelButtonTemplate"
          or frame._template == "BackdropTemplate"
          or (type(frame._template) == "string" and frame._template:find("BackdropTemplate", 1, true) ~= nil)
        ) and frame.pointY == -60
      then
        readyCheckButton = frame
        break
      end
    end
    readyCheckButton = Assert.NotNil(readyCheckButton, "Readycheck button should exist")
    ---@diagnostic disable-next-line: undefined-field
    Assert.Equal(readyCheckButton.pointX, -145, "M+Managment buttons should align with the expanded management column")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("marker1"), 1, "Blue Square uses world marker 1")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("type"), "worldmarker", "world marker button uses native type")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("marker"), 1, "world marker button uses native marker")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("action1"), "set", "left click must place marker")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("marker2"), 1, "Blue Square clears same marker")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("action2"), "clear", "right click must clear marker")
    Assert.True(tankHelperButtons[1].mouseClickEnabled, "world marker button must explicitly enable mouse clicks")
    Assert.Equal(tankHelperButtons[1]._frameLevel, 11, "world marker button must sit above sibling overlays")
    Assert.Equal(tankHelperButtons[8]:GetAttribute("marker1"), 8, "Skull uses world marker 8")
  end)
end

local function RegisterVerticalMiniLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Mini frame width accommodates tank helper buttons without clipping", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local mainFrame = NewRecordedMainFrame(createdFontStrings)
    local controller = nil

    WithGlobals({
      CreateFrame = function(frameType, name, parent, template)
        return NewRecordedFrame(createdFrames, createdFontStrings, frameType, name, parent, template)
      end,
      IsCombatLockdownActive = function()
        return false
      end,
      InCombatLockdown = function()
        return false
      end,
      C_CVar = {
        GetCVar = function()
          return "0"
        end,
        SetCVar = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_roster_panel.lua" })
      controller = addon.RosterPanel.CreateController({
        mainFrame = mainFrame,
        getL = function()
          return {
            TANK_HELPER_HEADER = "M+Marker",
            LEAD_OPTIONS = "M+Management",
            BTN_READYCHECK = "Readycheck",
            BTN_READYCHECK_SHORT = "RC",
            BTN_COUNTDOWN10 = "Countdown10",
            BTN_COUNTDOWN10_SHORT = "CD10",
            BTN_COUNTDOWN_CANCEL = "Countdown 0",
            BTN_COUNTDOWN_CANCEL_SHORT = "CD0",
            BTN_SHARE_KEYS = "Share Keys",
            BTN_REFRESH = "Re-Sync",
          }
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function(height)
          mainFrame.height = height
        end,
        setMainFrameWidthSafe = function(width)
          mainFrame.width = width
        end,
        buildOrderedRoster = function()
          return {}
        end,
        buildDisplayData = function(info)
          return {
            colorHex = "ffffffff",
            displayName = tostring(info and info.name or ""),
            languageDisplay = "",
            specText = "",
            ilvlText = "-",
            rioText = "-",
            keyText = "-",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
          }
        end,
        truncateName = function(name)
          return name
        end,
        getShortSpecLabel = function(spec)
          return spec
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return ""
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        rolePriority = {},
        unitPriority = {},
        isPlayerLeader = function()
          return true
        end,
        isInGroup = function()
          return true
        end,
        isRaidGroup = function()
          return false
        end,
      })
      controller.ApplyLocalization()
    end)

    local tankButton = nil
    for _, frame in ipairs(createdFrames) do
      if frame._template == "SecureActionButtonTemplate" then
        tankButton = frame
        break
      end
    end
    tankButton = Assert.NotNil(tankButton, "Tank helper button should exist")

    local collapseButton = FindFrameByProperty(createdFrames, "_collapseLayoutMode", "compact_vertical")
    local horizontalCollapseButton = FindFrameByProperty(createdFrames, "_collapseLayoutMode", "compact_horizontal")
    collapseButton = Assert.NotNil(collapseButton, "Collapse button should exist")
    horizontalCollapseButton = Assert.NotNil(horizontalCollapseButton, "Horizontal collapse button should exist")
    local titleFontString = FindFontStringByPoint(createdFontStrings, "TOPLEFT", 10, -7)
    local versionFontString = FindFontStringByPoint(createdFontStrings, "LEFT", 5, 0)
    titleFontString = Assert.NotNil(titleFontString, "Title font string should exist")
    versionFontString = Assert.NotNil(versionFontString, "Version font string should exist")
    ---@diagnostic disable: undefined-field
    Assert.Equal(
      collapseButton._collapseButtonLabel,
      "V",
      "Vertical collapse toggle should use the V label in expanded mode"
    )
    Assert.Equal(
      horizontalCollapseButton._collapseButtonLabel,
      "H",
      "Horizontal collapse toggle should use the H label in expanded mode"
    )
    Assert.Equal(
      collapseButton.pointX - horizontalCollapseButton.pointX,
      collapseButton.width + 2,
      "Expanded collapse toggles should match the 2px title-bar button gap"
    )
    Assert.Equal(
      mainFrame.height,
      236,
      "Expanded roster panel should reserve extra bottom space for helper/status separation"
    )

    -- Click collapse to switch to MINI mode
    collapseButton.OnClick()

    local miniWidth = mainFrame.width
    Assert.Equal(mainFrame.width, 150, "Vertical mini mode should use the tight V frame width")
    Assert.Equal(mainFrame.height, 128, "Vertical mini mode should keep a small bottom pad")
    local buttonX = tankButton.pointX -- Negative value relative to TOPRIGHT
    local markerButtons = {}
    local readyCheckButton = nil
    local countdownButton = nil
    local countdownCancelButton = nil
    local refreshButton = controller and controller.GetRefreshButton and controller.GetRefreshButton() or nil
    local shareKeysButton = nil
    for _, frame in ipairs(createdFrames) do
      if frame._template == "SecureActionButtonTemplate" and frame:GetAttribute("type1") == "worldmarker" then
        table.insert(markerButtons, frame)
      end
      if frame._flatLabel and frame._verticalY == -60 then
        readyCheckButton = frame
      end
      if frame._flatLabel and frame._verticalY == -90 then
        countdownButton = frame
      end
      if frame._flatLabel and frame._verticalY == -120 then
        countdownCancelButton = frame
      end
      if frame._flatLabel and frame._verticalY == -150 then
        shareKeysButton = frame
      end
    end
    readyCheckButton = Assert.NotNil(readyCheckButton, "Readycheck button should exist")
    countdownButton = Assert.NotNil(countdownButton, "Countdown10 button should exist")
    countdownCancelButton = Assert.NotNil(countdownCancelButton, "Countdown 0 button should exist")
    refreshButton = Assert.NotNil(refreshButton, "Refresh button should exist")
    shareKeysButton = Assert.NotNil(shareKeysButton, "Share Keys button should exist")
    table.sort(markerButtons, function(a, b)
      return (a._markerIndex or 0) < (b._markerIndex or 0)
    end)
    Assert.Equal(#markerButtons, 8, "V mode should keep all 8 M+Marker buttons available")
    Assert.Equal(buttonX, -44, "M+Marker buttons should move into the left V-mode marker column")
    Assert.Equal(readyCheckButton.pointX, -82, "M+Managment buttons should move into the tight V-mode action column")
    Assert.Equal(readyCheckButton.width, 52, "V mode should use narrower action buttons")
    Assert.Equal(readyCheckButton.height, 20, "V mode should use shorter action buttons")
    Assert.True(
      miniWidth + buttonX > 20,
      "Tank buttons (at " .. tostring(buttonX) .. ") must fit inside mini frame width (" .. tostring(miniWidth) .. ")"
    )
    Assert.True(
      miniWidth + readyCheckButton.pointX - readyCheckButton.width >= 0,
      "Management buttons must not clip out of the mini frame"
    )
    Assert.Equal(countdownButton.pointY, -55, "V mode should keep action buttons tightly stacked")
    Assert.Equal(countdownCancelButton.pointY, -76, "V mode should keep the third action button near the stack")
    Assert.Equal(markerButtons[1].pointX, -44, "V marker column 1 should use the left marker column")
    Assert.Equal(markerButtons[2].pointX, -44, "V marker column 1 should keep marker 2 below marker 1")
    Assert.Equal(markerButtons[3].pointX, -44, "V marker column 1 should keep marker 3 below marker 2")
    Assert.Equal(markerButtons[4].pointX, -44, "V marker column 1 should keep marker 4 below marker 3")
    Assert.Equal(markerButtons[5].pointX, -24, "V marker column 2 should start close beside marker column 1")
    Assert.Equal(markerButtons[8].pointX, -24, "V marker column 2 should keep marker 8 in the right marker column")
    Assert.Equal(markerButtons[1].pointY, -34, "V marker column 1 should start in the removed header space")
    Assert.Equal(markerButtons[4].pointY, -94, "V marker column 1 should place four markers downward")
    Assert.Equal(markerButtons[5].pointY, -34, "V marker column 2 should start at the top beside marker 1")
    Assert.Equal(markerButtons[8].pointY, -94, "V marker column 2 should place four markers downward")
    Assert.True(titleFontString.hidden, "Title should be hidden in vertical mini mode")
    Assert.True(versionFontString.hidden, "Version line should be hidden in vertical mini mode")
    local managementHeader = nil
    local markerHeader = nil
    for _, fontString in ipairs(createdFontStrings) do
      if fontString.text == "M+Management" then
        managementHeader = fontString
      elseif fontString.text == "M+Marker" then
        markerHeader = fontString
      end
    end
    managementHeader =
      Assert.NotNil(managementHeader, "V mode management header should exist before visibility is applied")
    markerHeader = Assert.NotNil(markerHeader, "V mode marker header should exist before visibility is applied")
    Assert.True(managementHeader.hidden, "V mode should hide the M+Management header")
    Assert.True(markerHeader.hidden, "V mode should hide the Marker header")
    Assert.Equal(readyCheckButton._flatLabel.text, "RC", "V mode should use the short ready-check label")
    Assert.Equal(countdownButton._flatLabel.text, "CD10", "V mode should use the short countdown label")
    Assert.Equal(countdownCancelButton._flatLabel.text, "CD0", "V mode should use the short countdown-cancel label")
    Assert.False(refreshButton._shown, "Re-Sync button should be hidden in vertical mini mode")
    Assert.False(shareKeysButton._shown, "Share Keys button should be hidden in vertical mini mode")
    Assert.Equal(collapseButton._collapseButtonLabel, "V", "V mode button keeps static V label")
    Assert.Equal(
      horizontalCollapseButton._collapseButtonLabel,
      "H",
      "H mode button keeps static H label while vertical mini mode is active"
    )
    ---@diagnostic enable: undefined-field
  end)
end

local function RegisterHorizontalMiniLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Horizontal mini mode arranges management buttons and helper icons in slim rows", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local mainFrame = NewRecordedMainFrame(createdFontStrings)
    local addon = nil

    WithGlobals({
      CreateFrame = function(frameType, name, parent, template)
        return NewRecordedFrame(createdFrames, createdFontStrings, frameType, name, parent, template)
      end,
      IsCombatLockdownActive = function()
        return false
      end,
      InCombatLockdown = function()
        return false
      end,
      C_CVar = {
        GetCVar = function()
          return "0"
        end,
        SetCVar = function() end,
      },
    }, function()
      addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_roster_panel.lua" })
      addon.RosterPanel.CreateController({
        mainFrame = mainFrame,
        getL = function()
          return { TANK_HELPER_HEADER = "M+Marker" }
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function(height)
          mainFrame.height = height
        end,
        setMainFrameWidthSafe = function(width)
          mainFrame.width = width
        end,
        buildOrderedRoster = function()
          return {}
        end,
        buildDisplayData = function(info)
          return {
            colorHex = "ffffffff",
            displayName = tostring(info and info.name or ""),
            languageDisplay = "",
            specText = "",
            ilvlText = "-",
            rioText = "-",
            keyText = "-",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
          }
        end,
        truncateName = function(name)
          return name
        end,
        getShortSpecLabel = function(spec)
          return spec
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return ""
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        rolePriority = {},
        unitPriority = {},
        isPlayerLeader = function()
          return true
        end,
        isInGroup = function()
          return true
        end,
        isRaidGroup = function()
          return false
        end,
      })
    end)

    local collapseButton = FindFrameByProperty(createdFrames, "_collapseLayoutMode", "compact_vertical")
    local horizontalButton = FindFrameByProperty(createdFrames, "_collapseLayoutMode", "compact_horizontal")
    local m2Button = FindFrameByProperty(createdFrames, "_collapseLayoutMode", "compact_main_horizontal")
    local expandedButton = FindFrameByProperty(createdFrames, "_collapseLayoutMode", "expanded")
    local titleFontString = FindFontStringByPoint(createdFontStrings, "TOPLEFT", 10, -7)
    local titleVersion = FindFontStringByPoint(createdFontStrings, "LEFT", 5, 0)
    collapseButton = Assert.NotNil(collapseButton, "Vertical collapse button should exist")
    horizontalButton = Assert.NotNil(horizontalButton, "Horizontal collapse button should exist")
    m2Button = Assert.NotNil(m2Button, "M2 mode button should exist")
    Assert.Nil(expandedButton, "Expanded mode button should stay hidden from the title bar")
    titleFontString = Assert.NotNil(titleFontString, "Title font string should exist")
    titleVersion = Assert.NotNil(titleVersion, "Title version should exist")
    Assert.Nil(
      addon.UICommon.CreateCompactLayoutChrome,
      "compact layouts should not add boxed inner backgrounds around actions or markers"
    )
    Assert.Equal(m2Button.pointX, -112, "M+ mode button should sit directly left of the H/V title-bar controls")
    Assert.Equal(horizontalButton.pointX, -90, "H mode button should sit between M+ and V in the title-bar group")
    Assert.Equal(collapseButton.pointX, -68, "V mode button should sit directly left of the settings button")
    Assert.Equal(m2Button._template, "BackdropTemplate", "M+ mode button should use title-bar button chrome")
    Assert.Equal(horizontalButton._template, "BackdropTemplate", "H mode button should use title-bar button chrome")
    Assert.Equal(collapseButton._template, "BackdropTemplate", "V mode button should use title-bar button chrome")
    Assert.Equal(m2Button._isiLiveSemanticRole, "title", "inactive M+ mode button should use quiet title chrome")
    Assert.Equal(horizontalButton._isiLiveSemanticRole, "title", "inactive H mode button should use quiet title chrome")
    Assert.Equal(collapseButton._isiLiveSemanticRole, "title", "inactive V mode button should use quiet title chrome")
    Assert.Equal(horizontalButton._collapseButtonLabel, "H", "H mode button has static H label in expanded mode")

    local helperButtons = {}
    local managementButtons = {}
    for _, frame in ipairs(createdFrames) do
      if frame._template == "SecureActionButtonTemplate" and frame:GetAttribute("type1") == "worldmarker" then
        table.insert(helperButtons, frame)
      elseif
        (
          frame._template == "UIPanelButtonTemplate"
          or frame._template == "BackdropTemplate"
          or (type(frame._template) == "string" and frame._template:find("BackdropTemplate", 1, true) ~= nil)
        ) and frame._verticalY
      then
        table.insert(managementButtons, frame)
      end
    end
    -- managementButtons-Reihenfolge: readyCheck (y=-60), countdown (y=-90), countdownCancel (y=-120)
    table.sort(managementButtons, function(a, b)
      return (a.pointY or 0) > (b.pointY or 0)
    end)

    horizontalButton.OnClick()

    Assert.Equal(horizontalButton._isiLiveSemanticRole, "primary", "active H mode should receive the stronger surface")
    Assert.Equal(collapseButton._isiLiveSemanticRole, "title", "inactive V mode should retain quiet title chrome")
    horizontalButton.OnEnter(horizontalButton)
    Assert.Equal(horizontalButton._isiLiveVisualState, "hover", "active H mode should retain semantic hover feedback")
    horizontalButton.OnLeave(horizontalButton)
    Assert.Equal(horizontalButton._isiLiveVisualState, "default", "H mode should restore its active default surface")

    table.sort(helperButtons, function(a, b)
      return a.pointX < b.pointX
    end)
    Assert.Equal(mainFrame.width, 212, "Horizontal mini mode should use only the minimal toolbar width")
    Assert.Equal(mainFrame.height, 94, "Horizontal mini mode should shrink the frame height")
    Assert.Equal(helperButtons[1].width, 18, "M+Marker icons should keep their size")
    Assert.Equal(helperButtons[1].height, 18, "M+Marker icons should keep the square size")
    Assert.Equal(helperButtons[1].pointY, -64, "M+Marker icons should share one horizontal row")
    Assert.Equal(helperButtons[#helperButtons].pointY, -64, "All M+Marker icons should stay on the same row")
    -- Alle 3 Management-Buttons nebeneinander in H-Modus (rechts nach links: index 1,2,3)
    Assert.Equal(managementButtons[1].pointY, -28, "Management buttons should use the horizontal toolbar row")
    Assert.Equal(managementButtons[2].pointY, -28, "All management buttons share the toolbar row")
    Assert.Equal(managementButtons[3].pointY, -28, "All management buttons share the toolbar row")
    Assert.Equal(managementButtons[1].pointX, -10, "First management button anchored at right in H mode")
    Assert.Equal(managementButtons[2].pointX, -76, "Second management button at center in H mode")
    Assert.Equal(managementButtons[3].pointX, -142, "Third management button at left in H mode")
    Assert.Equal(managementButtons[1].width, 60, "Management buttons resize to compact width in H mode")
    Assert.Equal(horizontalButton._collapseButtonLabel, "H", "H mode button keeps static H label in horizontal mode")
    Assert.Equal(collapseButton._collapseButtonLabel, "V", "V mode button keeps static V label in horizontal mode")
    Assert.Equal(horizontalButton.pointY, -4, "H mode should vertically center its title buttons")
    Assert.Equal(collapseButton.pointY, -4, "V selector should share the centered title-button anchor")
    Assert.Equal(m2Button.pointY, -4, "M+ selector should share the centered title-button anchor")
    Assert.True(titleVersion.hidden, "Title version should be hidden in horizontal mini mode")
    Assert.True(
      helperButtons[1].pointX < helperButtons[#helperButtons].pointX,
      "Helper icons should spread horizontally"
    )

    collapseButton.OnClick()

    Assert.Equal(mainFrame.width, 150, "Vertical mini mode should retain its fixed width budget")
    Assert.Equal(mainFrame.height, 128, "Vertical mini mode should retain its fixed height budget")

    local titleUtilityButton =
      NewRecordedFrame(createdFrames, createdFontStrings, "Button", nil, mainFrame, "BackdropTemplate")
    titleUtilityButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, -2)
    mainFrame._isiLiveTitleBarButtons = { titleUtilityButton }

    m2Button.OnClick()

    Assert.Equal(mainFrame.width, 500, "Leaving H through M2 should switch into the visible main layout")
    Assert.Equal(mainFrame.height, 272, "Leaving H through M2 should restore the modern main-layout height")
    Assert.Equal(m2Button.pointY, -4, "M+ mode should keep every title control vertically centered")
    Assert.Equal(titleUtilityButton.pointY, -4, "M+ mode should align utility buttons with the layout controls")
    Assert.Equal(titleFontString.point, "TOPLEFT", "M+ title should preserve its stable anchor type")
    Assert.Equal(titleFontString.pointY, -8, "M+ title should receive the matching one-pixel optical correction")
    Assert.Equal(managementButtons[1].width, 92, "Leaving H through M2 should restore the M2 button widths")
    Assert.Equal(
      horizontalButton._collapseButtonLabel,
      "H",
      "H mode button keeps static H label after leaving horizontal mode"
    )
    Assert.True(titleVersion.hidden ~= true, "Title version should be visible again in M2 mode")
  end)
end

local function RegisterHorizontalModernLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  test("M2 mode keeps roster visible and stacks action rows under the list", function()
    local createdFrames = {}
    local createdFontStrings = {}
    local mainFrame = NewRecordedMainFrame(createdFontStrings)

    WithGlobals({
      CreateFrame = function(frameType, name, parent, template)
        return NewRecordedFrame(createdFrames, createdFontStrings, frameType, name, parent, template)
      end,
      IsCombatLockdownActive = function()
        return false
      end,
      InCombatLockdown = function()
        return false
      end,
      C_CVar = {
        GetCVar = function()
          return "0"
        end,
        SetCVar = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_roster_panel.lua" })
      addon.RosterPanel.CreateController({
        mainFrame = mainFrame,
        getL = function()
          return {
            TITLE = "isiLive",
            COL_SPEC = "Spec",
            COL_NAME = "Name",
            COL_LANGUAGE = "Lang",
            COL_KEY = "Key",
            COL_ILVL = "iLvl",
            COL_RIO = "RIO",
            COL_DPS = "DPS",
            LEAD_OPTIONS = "Lead",
            MPLUS_MANAGEMENT = "Mgmt",
            BTN_READYCHECK = "Readycheck",
            BTN_COUNTDOWN10 = "Countdown10",
            BTN_COUNTDOWN_CANCEL = "Countdown 0",
            BTN_SHARE_KEYS = "Share Keys",
            BTN_REFRESH = "Refresh",
            OPT_ADVANCED_COMBAT_LOGGING = "Logging",
            OPT_DAMAGE_METER_RESET = "Reset",
            TANK_HELPER_HEADER = "M+Marker",
          }
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function(height)
          mainFrame.height = height
        end,
        setMainFrameWidthSafe = function(width)
          mainFrame.width = width
        end,
        buildOrderedRoster = function()
          return {}
        end,
        buildDisplayData = function(info)
          return {
            colorHex = "ffffffff",
            displayName = tostring(info and info.name or ""),
            languageDisplay = "",
            specText = "",
            ilvlText = "-",
            rioText = "-",
            keyText = "-",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
          }
        end,
        truncateName = function(name)
          return name
        end,
        getShortSpecLabel = function(spec)
          return spec
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return ""
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        rolePriority = {},
        unitPriority = {},
        isPlayerLeader = function()
          return true
        end,
        isInGroup = function()
          return true
        end,
        isRaidGroup = function()
          return false
        end,
      })
    end)

    local m2Button = FindFrameByProperty(createdFrames, "_collapseLayoutMode", "compact_main_horizontal")
    Assert.NotNil(m2Button, "M2 collapse button should exist")
    assert(m2Button ~= nil)
    ---@cast m2Button { OnClick: fun(), _collapseButtonLabel: string }

    local toolbarButtons = {}
    local markerButtons = {}
    for _, frame in ipairs(createdFrames) do
      if
        (
          frame._template == "UIPanelButtonTemplate"
          or frame._template == "BackdropTemplate"
          or (type(frame._template) == "string" and frame._template:find("BackdropTemplate", 1, true) ~= nil)
        )
        and frame._flatLabel
        and frame._modeTarget == nil
      then
        table.insert(toolbarButtons, frame)
      elseif frame._template == "SecureActionButtonTemplate" and frame:GetAttribute("type1") == "worldmarker" then
        table.insert(markerButtons, frame)
      end
    end

    m2Button.OnClick()

    table.sort(toolbarButtons, function(a, b)
      return (a.pointX or 0) < (b.pointX or 0)
    end)
    table.sort(markerButtons, function(a, b)
      return (a.pointX or 0) < (b.pointX or 0)
    end)

    Assert.Equal(mainFrame.width, 500, "M2 mode should use the widened modern frame")
    Assert.Equal(mainFrame.height, 272, "M2 mode should keep the roster compact and leave room for the action rows")
    Assert.Equal(m2Button._collapseButtonLabel, "M+", "M2 mode button should keep its static label")
    Assert.Equal(#toolbarButtons, 5, "M2 mode should keep all action buttons in one horizontal row")
    Assert.Equal(toolbarButtons[1].point, "BOTTOMLEFT", "M2 action row should anchor from the bottom-left")
    Assert.Equal(toolbarButtons[1].pointX, 10, "M2 action row should start at the left margin")
    Assert.Equal(toolbarButtons[1].pointY, 105, "M2 action row should leave clearance below a full roster")
    Assert.Equal(toolbarButtons[1].width, 92, "M2 action buttons should use the modern compact width")
    Assert.Equal(toolbarButtons[1].height, 22, "M2 action buttons should use the modern compact height")
    Assert.Equal(toolbarButtons[#toolbarButtons].pointX, 402, "M2 action row should remain left-aligned")
    Assert.Equal(toolbarButtons[#toolbarButtons].pointY, 105, "All M2 action buttons should share one row")
    Assert.Equal(#markerButtons, 8, "M2 mode should keep all world markers available")
    Assert.False(markerButtons[1]._shown, "M2 marker buttons should be hidden entirely")
    Assert.False(markerButtons[#markerButtons]._shown, "M2 marker buttons should be hidden entirely")
    local tankHeaderFontString = nil
    for _, fontString in ipairs(createdFontStrings) do
      if fontString.text == "M+Marker" then
        tankHeaderFontString = fontString
        break
      end
    end
    Assert.NotNil(tankHeaderFontString, "M2 marker header should exist")
    assert(tankHeaderFontString ~= nil)
    ---@cast tankHeaderFontString { hidden: boolean }
    Assert.True(tankHeaderFontString.hidden, "M2 marker header should be hidden entirely")
  end)
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  RegisterNativeWorldMarkerButtonTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterVerticalMiniLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterHorizontalMiniLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterHorizontalModernLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
end
