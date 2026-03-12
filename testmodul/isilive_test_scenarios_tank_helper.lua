---@diagnostic disable: undefined-global

local function NewRecordedTexture()
  return {
    SetAllPoints = function() end,
    SetColorTexture = function() end,
    SetHeight = function() end,
    SetPoint = function() end,
    SetTexture = function(self, texture)
      self.texture = texture
    end,
    SetTexCoord = function(self, ...)
      self.texCoord = { ... }
    end,
    Hide = function(self)
      self.hidden = true
    end,
    Show = function(self)
      self.hidden = false
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

  function fontString:SetPoint(point, x, y)
    self.point = point
    self.pointX = x
    self.pointY = y
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
  function frame:SetPoint(point, x, y)
    if point == "TOPRIGHT" then
      self.pointX = x
      self.pointY = y
    end
  end
  function frame:GetPoint()
    return "TOPRIGHT", nil, nil, self.pointX, self.pointY
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
  function frame.RegisterForClicks(_self) end
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
    return { SetHeight = function() end, SetPoint = function() end, SetColorTexture = function() end }
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

local function FindFrameByTexture(createdFrames, texture)
  for _, frame in ipairs(createdFrames) do
    if frame.normalTexture == texture then
      return frame
    end
  end
  return nil
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

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("M+Helper buttons use native world-marker secure attributes", function()
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
          return { TANK_HELPER_HEADER = "M+Helper" }
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function()
          return {}
        end,
        hasFullSync = function()
          return false
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

    Assert.Equal(#tankHelperButtons, 8, "Should create 8 M+Helper world-marker buttons")
    Assert.Equal(
      tankHelperButtons[1].pointX,
      -136,
      "M+Helper column should occupy the management-side slot in expanded mode"
    )
    local readyCheckButton = nil
    for _, frame in ipairs(createdFrames) do
      if frame._template == "UIPanelButtonTemplate" and frame.pointY == -60 then
        readyCheckButton = frame
        break
      end
    end
    Assert.NotNil(readyCheckButton, "Readycheck button should exist")
    Assert.Equal(
      readyCheckButton.pointX,
      -170,
      "M+Managment buttons must keep a safe fixed slot right of the DPS column in expanded mode"
    )
    Assert.Equal(tankHelperButtons[1]:GetAttribute("marker1"), 1, "Blue Square uses world marker 1")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("action1"), "set", "left click must place marker")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("marker2"), 1, "Blue Square clears same marker")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("action2"), "clear", "right click must clear marker")
    Assert.Equal(tankHelperButtons[8]:GetAttribute("marker1"), 8, "Skull uses world marker 8")
  end)

  test("Mini frame width accommodates tank helper buttons without clipping", function()
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
          return { TANK_HELPER_HEADER = "M+Helper" }
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        buildOrderedRoster = function()
          return {}
        end,
        hasFullSync = function()
          return false
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

    local tankButton = nil
    for _, frame in ipairs(createdFrames) do
      if frame._template == "SecureActionButtonTemplate" then
        tankButton = frame
        break
      end
    end
    Assert.NotNil(tankButton, "Tank helper button should exist")

    local collapseButton = FindFrameByProperty(createdFrames, "_collapseLayoutMode", "compact_vertical")
    Assert.NotNil(collapseButton, "Collapse button should exist")
    local titleFontString = FindFontStringByPoint(createdFontStrings, "TOP", 0, -4)
    local versionFontString = FindFontStringByPoint(createdFontStrings, "BOTTOMRIGHT", -10, 6)
    Assert.NotNil(titleFontString, "Title font string should exist")
    Assert.NotNil(versionFontString, "Version font string should exist")

    -- Click collapse to switch to MINI mode
    collapseButton.OnClick()

    local miniWidth = mainFrame.width
    local buttonX = tankButton.pointX -- Negative value relative to TOPRIGHT
    local readyCheckButton = nil
    for _, frame in ipairs(createdFrames) do
      if frame._template == "UIPanelButtonTemplate" and frame.pointY == -60 then
        readyCheckButton = frame
        break
      end
    end
    Assert.NotNil(readyCheckButton, "Readycheck button should exist")
    Assert.Equal(buttonX, -37, "M+Helper buttons should move into the right mini-mode tool column")
    Assert.Equal(readyCheckButton.pointX, -70, "M+Managment buttons should stay fully inside the mini-mode frame")
    Assert.True(
      miniWidth + buttonX > 20,
      "Tank buttons (at " .. tostring(buttonX) .. ") must fit inside mini frame width (" .. tostring(miniWidth) .. ")"
    )
    Assert.True(
      miniWidth + readyCheckButton.pointX - 120 >= 0,
      "Management buttons must not clip out of the mini frame"
    )
    Assert.True(titleFontString.hidden, "Title should be hidden in vertical mini mode")
    Assert.True(versionFontString.hidden, "Version line should be hidden in vertical mini mode")
  end)

  test("Horizontal mini mode arranges management buttons and helper icons in slim rows", function()
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
          return { TANK_HELPER_HEADER = "M+Helper" }
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function(height)
          mainFrame.height = height
        end,
        buildOrderedRoster = function()
          return {}
        end,
        hasFullSync = function()
          return false
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

    local horizontalButton = FindFrameByTexture(createdFrames, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    Assert.NotNil(horizontalButton, "Horizontal collapse button should exist")
    local previousButton = FindFrameByProperty(createdFrames, "_managementCycleDirection", -1)
    local nextButton = FindFrameByProperty(createdFrames, "_managementCycleDirection", 1)
    Assert.NotNil(previousButton, "Horizontal management previous button should exist")
    Assert.NotNil(nextButton, "Horizontal management next button should exist")

    local helperButtons = {}
    local managementButtons = {}
    for _, frame in ipairs(createdFrames) do
      if frame._template == "SecureActionButtonTemplate" and frame:GetAttribute("type1") == "worldmarker" then
        table.insert(helperButtons, frame)
      elseif frame._template == "UIPanelButtonTemplate" then
        table.insert(managementButtons, frame)
      end
    end

    horizontalButton.OnClick()

    table.sort(helperButtons, function(a, b)
      return a.pointX < b.pointX
    end)
    Assert.Equal(mainFrame.width, 212, "Horizontal mini mode should use only the minimal toolbar width")
    Assert.Equal(mainFrame.height, 94, "Horizontal mini mode should shrink the frame height")
    Assert.Equal(helperButtons[1].width, 18, "M+Helper icons should be slightly enlarged")
    Assert.Equal(helperButtons[1].height, 18, "M+Helper icons should keep the enlarged square size")
    Assert.Equal(
      helperButtons[1].pointY,
      -64,
      "M+Helper icons should share one horizontal row with extra spacing below the carousel"
    )
    Assert.Equal(helperButtons[#helperButtons].pointY, -64, "All M+Helper icons should stay on the same row")
    Assert.Equal(managementButtons[1].pointY, -28, "Active management button should use the horizontal toolbar row")
    Assert.False(managementButtons[2]._shown, "Only one management button should stay visible in horizontal mode")
    Assert.True(previousButton._shown, "Previous button should be visible in horizontal mode")
    Assert.True(nextButton._shown, "Next button should be visible in horizontal mode")
    Assert.Equal(previousButton.width, 24, "Previous carousel button should be slightly enlarged")
    Assert.Equal(nextButton.width, 24, "Next carousel button should be slightly enlarged")
    Assert.True(
      helperButtons[1].pointX < helperButtons[#helperButtons].pointX,
      "Helper icons should spread horizontally"
    )

    local firstManagementX = managementButtons[1].pointX
    nextButton.OnClick()

    Assert.False(managementButtons[1]._shown, "First management button should hide after cycling")
    Assert.True(managementButtons[2]._shown, "Second management button should appear after cycling")
    Assert.Equal(managementButtons[2].pointY, -28, "Cycled management button should stay on the toolbar row")
    Assert.Equal(
      managementButtons[2].pointX,
      firstManagementX,
      "Cycled management button should reuse the centered slot"
    )

    horizontalButton.OnClick()

    Assert.Equal(
      helperButtons[1].pointX,
      -136,
      "Helper buttons should restore the expanded tool column after leaving horizontal mode"
    )
    Assert.Equal(
      helperButtons[1].pointY,
      -60,
      "Helper buttons should restore their original vertical stack after leaving horizontal mode"
    )
    Assert.Equal(helperButtons[2].pointY, -80, "Second helper button should restore its own original Y slot")
    Assert.True(managementButtons[1]._shown, "All management buttons should return when leaving horizontal mode")
    Assert.True(managementButtons[2]._shown, "Second management button should be visible again in expanded mode")
  end)
end
