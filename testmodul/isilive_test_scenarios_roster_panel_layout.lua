return function(test, ctx)
  test("Roster panel system option toggles keep spacing between adjacent labels", function()
    local Assert = ctx.assert
    local WithGlobals = ctx.with_globals
    local LoadAddonModules = ctx.load_modules
    local createdFrames = {}
    local createdFontStrings = {}

    local function NewPointRecordedFontString()
      local fontString = {}

      function fontString.SetPoint(self, point, relativeTo, relativePoint, x, y)
        self.point = point
        self.relativeTo = relativeTo
        self.relativePoint = relativePoint
        self.pointX = x
        self.pointY = y
      end
      function fontString.SetWidth() end
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
      function fontString.SetWordWrap() end
      function fontString.SetNonSpaceWrap() end
      function fontString.SetMaxLines() end
      function fontString.Hide() end
      function fontString.Show() end

      table.insert(createdFontStrings, fontString)
      return fontString
    end

    local function NewPointRecordedFrame()
      local frame = {
        checked = false,
      }

      function frame.SetSize() end
      function frame.SetHeight() end
      function frame.SetWidth() end
      function frame.ClearAllPoints(self)
        self.point = nil
        self.relativeTo = nil
        self.relativePoint = nil
        self.pointX = nil
        self.pointY = nil
      end
      function frame.SetPoint(self, point, relativeTo, relativePoint, x, y)
        self.point = point
        self.relativeTo = relativeTo
        self.relativePoint = relativePoint
        self.pointX = x
        self.pointY = y
      end
      function frame.SetScript(self, script, handler)
        self[script] = handler
      end
      function frame.SetText(self, value)
        self.text = value
      end
      function frame.SetEnabled() end
      function frame.SetAlpha() end
      function frame.SetChecked(self, value)
        self.checked = value and true or false
      end
      function frame.GetChecked(self)
        return self.checked
      end
      function frame.EnableMouse() end
      function frame.Hide() end
      function frame.Show() end
      function frame.IsShown()
        return true
      end
      function frame.CreateTexture()
        return {
          SetAllPoints = function() end,
          SetColorTexture = function() end,
          SetTexture = function() end,
          SetTexCoord = function() end,
          Hide = function() end,
          Show = function() end,
          SetHeight = function() end,
          SetPoint = function() end,
        }
      end
      function frame.CreateFontString()
        return NewPointRecordedFontString()
      end

      table.insert(createdFrames, frame)
      return frame
    end

    local mainFrame = {
      SetBackdrop = function() end,
      SetBackdropColor = function() end,
      IsShown = function()
        return true
      end,
      CreateFontString = function()
        return NewPointRecordedFontString()
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

    WithGlobals({
      CreateFrame = function()
        return NewPointRecordedFrame()
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
        mainFrame = mainFrame,
        getL = function()
          return {
            OPT_ADVANCED_COMBAT_LOGGING = "Combat Logging",
            OPT_DAMAGE_METER_RESET = "DM Reset on Entry",
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
        buildOrderedRoster = function()
          return {}
        end,
        hasFullSync = function()
          return false
        end,
        buildDisplayData = function()
          return {}
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
          return ""
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
        rolePriority = {},
        unitPriority = {},
      })

      controller.ApplyLocalization()

      local combatLabel = nil
      local damageMeterResetLabel = nil
      for _, fontString in ipairs(createdFontStrings) do
        if fontString.text == "Combat Logging" then
          combatLabel = fontString
        elseif fontString.text == "DM Reset on Entry" then
          damageMeterResetLabel = fontString
        end
      end

      Assert.NotNil(combatLabel, "combat logging label should exist")
      Assert.NotNil(damageMeterResetLabel, "damage meter reset label should exist")

      local damageMeterResetToggle = nil
      for _, frame in ipairs(createdFrames) do
        if frame.relativeTo == combatLabel then
          damageMeterResetToggle = frame
        end
      end

      Assert.NotNil(damageMeterResetToggle, "damage meter reset toggle should anchor after the combat logging label")
      ---@diagnostic disable: need-check-nil, undefined-field
      Assert.Equal(damageMeterResetToggle.point, "LEFT", "damage meter reset toggle should align horizontally")
      Assert.Equal(
        damageMeterResetToggle.relativePoint,
        "RIGHT",
        "damage meter reset toggle should attach to the combat label edge"
      )
      Assert.Equal(damageMeterResetToggle.pointX, 18, "damage meter reset toggle should keep the same visible gap")
      Assert.Equal(damageMeterResetToggle.pointY, 0, "damage meter reset toggle should stay on the same baseline")
      ---@diagnostic enable: need-check-nil, undefined-field
    end)
  end)
end
