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

  function fontString.SetPoint(_self) end
  function fontString.Hide(_self) end
  function fontString.Show(_self) end
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
    Assert.True(
      miniWidth + buttonX > 20,
      "Tank buttons (at " .. tostring(buttonX) .. ") must fit inside mini frame width (" .. tostring(miniWidth) .. ")"
    )
  end)
end
