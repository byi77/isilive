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
  }

  function fontString:SetPoint() end
  function fontString:Hide() end
  function fontString:Show() end
  function fontString:SetWidth(value)
    self.width = value
  end
  function fontString:SetJustifyH() end
  function fontString:GetFont()
    return "font", 10, ""
  end
  function fontString:SetFont() end
  function fontString:SetTextColor() end
  function fontString:SetShadowOffset() end
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
  function frame:SetScript(script, handler)
    self[script] = handler
  end
  function frame:SetAttribute(key, value)
    self._attributes[key] = value
  end
  function frame:GetAttribute(key)
    return self._attributes[key]
  end
  function frame:EnableMouse() end
  function frame:RegisterForClicks() end
  function frame:SetShown(shown)
    self._shown = shown and true or false
  end
  function frame:CreateTexture()
    return NewRecordedTexture()
  end
  function frame:CreateFontString()
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
  }

  function mainFrame:SetBackdrop() end
  function mainFrame:SetBackdropColor() end
  function mainFrame:IsShown()
    return true
  end
  function mainFrame:CreateFontString()
    return NewRecordedFontString(createdFontStrings)
  end
  function mainFrame:CreateTexture()
    return { SetHeight = function() end, SetPoint = function() end, SetColorTexture = function() end }
  end
  function mainFrame:SetWidth(w)
    self.width = w
  end
  function mainFrame:GetFrameStrata()
    return "MEDIUM"
  end
  function mainFrame:GetFrameLevel()
    return 1
  end

  return mainFrame
end

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("Tank Helper buttons have correct world marker macro attributes", function()
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
      C_CVar = { GetCVar = function()
        return "0"
      end, SetCVar = function() end },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_roster_panel.lua" })
      addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return { TANK_HELPER_HEADER = "Tank Helper" }
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
        isPlayerLeader = function() return true end,
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
        local macro1 = frame:GetAttribute("macrotext1")
        if macro1 and macro1:find("/wm") then
          table.insert(tankHelperButtons, frame)
        end
      end
    end

    table.sort(tankHelperButtons, function(a, b)
      return a.pointY > b.pointY
    end)

    Assert.Equal(#tankHelperButtons, 5, "Should create 5 tank helper buttons")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("macrotext1"), "/wm 6", "Blue Square")
    Assert.Equal(tankHelperButtons[2]:GetAttribute("macrotext1"), "/wm 4", "Green Triangle")
    Assert.Equal(tankHelperButtons[3]:GetAttribute("macrotext1"), "/wm 3", "Purple Diamond")
    Assert.Equal(tankHelperButtons[4]:GetAttribute("macrotext1"), "/wm 7", "Red Cross")
    Assert.Equal(tankHelperButtons[5]:GetAttribute("macrotext1"), "/wm 1", "Yellow Star")
    Assert.Equal(tankHelperButtons[1]:GetAttribute("macrotext2"), "/cwm 6", "Clear Blue Square")
    Assert.Equal(tankHelperButtons[5]:GetAttribute("macrotext2"), "/cwm 1", "Clear Yellow Star")
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
      C_CVar = { GetCVar = function()
        return "0"
      end, SetCVar = function() end },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_roster_panel.lua" })
      addon.RosterPanel.CreateController({
        mainFrame = mainFrame,
        getL = function()
          return { TANK_HELPER_HEADER = "Tank Helper" }
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
        isPlayerLeader = function() return true end,
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

    local collapseButton = nil
    for _, frame in ipairs(createdFrames) do
      if frame.normalTexture == "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up" then
        collapseButton = frame
        break
      end
    end
    Assert.NotNil(collapseButton, "Collapse button should exist")

    -- Click collapse to switch to MINI mode
    collapseButton.OnClick()

    local miniWidth = mainFrame.width
    local buttonX = tankButton.pointX -- Negative value relative to TOPRIGHT
    Assert.True(miniWidth + buttonX > 20, "Tank buttons (at " .. tostring(buttonX) .. ") must fit inside mini frame width (" .. tostring(miniWidth) .. ")")
  end)
end
