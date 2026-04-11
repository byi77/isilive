local function NewRecordedFontString(createdFontStrings)
  local fontString = {
    wordWrap = nil,
    nonSpaceWrap = nil,
    maxLines = nil,
    width = nil,
  }

  function fontString.SetPoint() end
  function fontString.SetAllPoints() end
  function fontString.ClearAllPoints() end
  function fontString.Hide() end
  function fontString.Show() end
  function fontString.SetWidth(self, value)
    self.width = value
  end
  function fontString.SetJustifyH() end
  function fontString.GetFont()
    return "font", 10, ""
  end
  function fontString.SetFont() end
  function fontString.SetTextColor() end
  function fontString.SetShadowOffset() end
  function fontString.SetText(self, value)
    self.text = value
  end
  function fontString.SetWordWrap(self, value)
    self.wordWrap = value
  end
  function fontString.SetNonSpaceWrap(self, value)
    self.nonSpaceWrap = value
  end
  function fontString.SetMaxLines(self, value)
    self.maxLines = value
  end

  table.insert(createdFontStrings, fontString)
  return fontString
end

local function NewRecordedFrame(createdFrames, createdFontStrings)
  local frame = {
    enabled = nil,
    alpha = nil,
    pointY = nil,
    checked = false,
    attributes = {},
    _shown = true,
    _frameStrata = "MEDIUM",
    _frameLevel = 1,
  }

  function frame.SetSize() end
  function frame.SetHeight() end
  function frame.SetWidth() end
  function frame.SetPoint(self, ...)
    local argCount = select("#", ...)
    for index = argCount, 1, -1 do
      local value = select(index, ...)
      if type(value) == "number" then
        self.pointY = value
        return
      end
    end
  end
  function frame.SetScript(self, script, handler)
    self[script] = handler
  end
  function frame.SetText(self, text)
    self.text = text
  end
  function frame.SetEnabled(self, value)
    self.enabled = value and true or false
  end
  function frame.SetAlpha(self, value)
    self.alpha = value
  end
  function frame.SetChecked(self, value)
    self.checked = value and true or false
  end
  function frame.GetChecked(self)
    return self.checked
  end
  function frame.SetAttribute(self, key, value)
    self.attributes[key] = value
  end
  function frame.GetAttribute(self, key)
    return self.attributes[key]
  end
  function frame.EnableMouse() end
  function frame.RegisterForClicks() end
  function frame.Hide() end
  function frame.Show() end
  function frame.SetShown(self, value)
    self._shown = value and true or false
  end
  function frame.IsShown()
    return true
  end
  function frame.SetNormalTexture(self, value)
    self.normalTexture = value
  end
  function frame.SetPushedTexture(self, value)
    self.pushedTexture = value
  end
  function frame.SetHighlightTexture(self, value)
    self.highlightTexture = value
  end
  function frame.SetFrameStrata(self, value)
    self._frameStrata = value
  end
  function frame.GetFrameStrata(self)
    return self._frameStrata
  end
  function frame.SetFrameLevel(self, value)
    self._frameLevel = value
  end
  function frame.GetFrameLevel(self)
    return self._frameLevel
  end
  function frame.CreateTexture()
    return {
      SetAllPoints = function() end,
      SetColorTexture = function() end,
      SetTexture = function() end,
      SetTexCoord = function() end,
      SetVertexColor = function() end,
      SetHeight = function() end,
      SetPoint = function() end,
      SetWidth = function() end,
      GetWidth = function()
        return 0
      end,
      Hide = function() end,
      Show = function() end,
      IsShown = function()
        return false
      end,
    }
  end
  function frame.CreateFontString()
    return NewRecordedFontString(createdFontStrings)
  end

  table.insert(createdFrames, frame)
  return frame
end

local function NewRecordedMainFrame(createdFontStrings)
  local mainFrame = {
    width = 0,
    _frameStrata = "MEDIUM",
    _frameLevel = 1,
  }

  function mainFrame.SetBackdrop() end
  function mainFrame.SetBackdropColor() end
  function mainFrame.SetWidth(self, value)
    self.width = value
  end
  function mainFrame.GetFrameStrata(self)
    return self._frameStrata
  end
  function mainFrame.GetFrameLevel(self)
    return self._frameLevel
  end
  function mainFrame.IsShown()
    return true
  end
  function mainFrame.CreateFontString()
    return NewRecordedFontString(createdFontStrings)
  end
  function mainFrame.CreateTexture()
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
      SetTexCoord = function() end,
      SetVertexColor = function() end,
      Hide = function() end,
      Show = function() end,
      IsShown = function()
        return false
      end,
    }
  end

  return mainFrame
end

local function RegisterRosterPanelWrappingLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel rows disable wrapping for all member text columns", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {}
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function()
          return {
            {
              unit = "party1",
              info = {
                name = "Member",
                role = "DAMAGER",
              },
            },
          }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Member",
            languageDisplay = "EN",
            specText = "DPS",
            ilvlText = "650",
            rioText = "3000",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          party1 = 1,
        },
      })

      local fontStringsBeforeRender = #createdFontStrings
      controller.RenderRoster({})

      local rowFontStrings = {}
      for index = fontStringsBeforeRender + 1, #createdFontStrings do
        table.insert(rowFontStrings, createdFontStrings[index])
      end

      Assert.Equal(#rowFontStrings, 8, "one rendered row should create eight member text columns")
      for _, fontString in ipairs(rowFontStrings) do
        Assert.False(fontString.wordWrap, "member text columns must disable word wrap")
        Assert.False(fontString.nonSpaceWrap, "member text columns must disable non-space wrap")
      end
    end)
  end)

  test("Roster panel uses compact width budget for primary data columns", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {
            COL_DPS = "DPS",
          }
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function()
          return {
            {
              unit = "party1",
              info = {
                name = "Member",
                realm = "Realm",
                role = "DAMAGER",
              },
            },
          }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Member",
            languageDisplay = "|Tflag-de:0|t",
            specText = "Shadow",
            ilvlText = "650",
            rioText = "(+15)3000",
            keyText = "DAWN +14",
            dpsText = "321.1K",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DAWN"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          party1 = 1,
        },
      })

      local fontStringsBeforeRender = #createdFontStrings
      controller.RenderRoster({})

      local rowFontStrings = {}
      for index = fontStringsBeforeRender + 1, #createdFontStrings do
        table.insert(rowFontStrings, createdFontStrings[index])
      end

      Assert.Equal(#rowFontStrings, 8, "one rendered row should create eight member text columns")
      Assert.Equal(rowFontStrings[1].width, 52, "spec column should keep compact width budget")
      Assert.Equal(rowFontStrings[2].width, 122, "name column should keep the compact body width budget")
      Assert.Equal(rowFontStrings[3].width, 32, "ilvl column should keep compact width budget without truncation")
      Assert.Equal(rowFontStrings[4].width, 62, "key column should fit short-code plus two-digit level (e.g. NPX +10)")
      Assert.Equal(rowFontStrings[5].width, 70, "rio column should fit (+999)9999 without clipping")
      Assert.Equal(rowFontStrings[6].width, 40, "dps column should keep compact width budget")
      Assert.Equal(rowFontStrings[7].width, 58, "kick column should keep the readable width budget")
    end)
  end)
end

local function RegisterRosterPanelWrappingDpsTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Roster panel renders DPS column from latest run snapshot", function()
    local createdFrames = {}
    local createdFontStrings = {}

    WithGlobals({
      CreateFrame = function()
        return NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
      AbbreviateNumbers = function(value)
        if value == 321123 then
          return "321.1K"
        end
        return tostring(value)
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_roster_panel.lua" })
      local controller = addon.RosterPanel.CreateController({
        mainFrame = NewRecordedMainFrame(createdFontStrings),
        getL = function()
          return {
            COL_DPS = "DPS",
          }
        end,
        isPlayerLeader = function()
          return true
        end,
        getAddonVersionText = function()
          return ""
        end,
        updateStatusLine = function() end,
        setMainFrameHeightSafe = function() end,
        setMainFrameWidthSafe = function() end,
        buildOrderedRoster = function()
          return {
            {
              unit = "party1",
              info = {
                name = "Member",
                realm = "Realm",
                role = "DAMAGER",
              },
            },
          }
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {
            colorHex = "ffffffff",
            displayName = "Member",
            languageDisplay = "EN",
            specText = "DPS",
            ilvlText = "650",
            rioText = "3000",
            keyText = "DB +10",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
        truncateName = function(text)
          return text
        end,
        getShortSpecLabel = function(text)
          return text
        end,
        getLanguageFlagMarkup = function()
          return ""
        end,
        getDungeonShortCode = function()
          return "DB"
        end,
        resolveActiveKeyOwnerUnit = function()
          return nil
        end,
        getRoster = function()
          return {}
        end,
        isInGroup = function()
          return true
        end,
        rolePriority = {
          DAMAGER = 1,
          NONE = 2,
        },
        unitPriority = {
          party1 = 1,
        },
        getPlayerLastRunDps = function(name, realm)
          if name == "Member" and realm == "Realm" then
            return 321123
          end
          return nil
        end,
      })

      local fontStringsBeforeRender = #createdFontStrings
      controller.RenderRoster({})

      local rowFontStrings = {}
      for index = fontStringsBeforeRender + 1, #createdFontStrings do
        table.insert(rowFontStrings, createdFontStrings[index])
      end

      local foundDpsText = false
      for _, fontString in ipairs(rowFontStrings) do
        if fontString.text == "321.1K" then
          foundDpsText = true
          break
        end
      end

      Assert.True(foundDpsText, "rendered row should include abbreviated DPS text")
    end)
  end)
end

return function(test, ctx)
  RegisterRosterPanelWrappingLayoutTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
  RegisterRosterPanelWrappingDpsTests(test, ctx.assert, ctx.with_globals, ctx.load_modules)
end
