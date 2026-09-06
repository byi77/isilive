-- Branch-coverage scenarios for ui/isiLive_notice.lua. Targets functions and
-- code paths that the existing isilive_test_scenarios_ui_center_notice.lua
-- file does not exercise:
--   * PortalNavigator close-by-right-click and close-button branches
--   * CreateCenterNotice teleport-button blink animation tick

local function CreateTextureStub()
  local tex = { _hidden = false }
  tex.SetAllPoints = function(self)
    self._allPoints = true
  end
  tex.SetColorTexture = function() end
  tex.SetTexture = function() end
  tex.SetSize = function(self, w, h)
    self._width = w
    self._height = h
  end
  tex.SetWidth = function() end
  tex.SetHeight = function() end
  tex.SetPoint = function(self, ...)
    self._points = self._points or {}
    table.insert(self._points, { ... })
  end
  tex.ClearAllPoints = function(self)
    self._points = {}
    self._allPoints = false
  end
  tex.SetTexCoord = function() end
  tex.SetBlendMode = function() end
  tex.SetVertexColor = function() end
  tex.SetRotation = function() end
  tex.Hide = function(self)
    self._hidden = true
  end
  tex.Show = function(self)
    self._hidden = false
  end
  tex.IsShown = function(self)
    return self._hidden ~= true
  end
  return tex
end

local function CreateFontStringStub()
  local fs = { _shown = true, _text = "" }
  function fs:SetPoint(...)
    self._point = { ... }
  end
  function fs:ClearAllPoints()
    self._point = nil
  end
  function fs:GetPoint()
    local p = self._point
    if not p then
      return nil
    end
    return p[1], p[2], p[3], p[4], p[5]
  end
  function fs:SetText(value)
    self._text = tostring(value or "")
  end
  function fs:GetText()
    return self._text
  end
  function fs:SetJustifyH() end
  function fs:SetJustifyV() end
  function fs:SetTextColor(r, g, b, a)
    self._textColor = { r, g, b, a }
  end
  function fs:GetTextColor()
    local color = self._textColor or { 1, 1, 1, 1 }
    return color[1], color[2], color[3], color[4]
  end
  function fs:SetWordWrap() end
  function fs:SetNonSpaceWrap() end
  function fs:SetWidth(width)
    self._width = tonumber(width) or width
  end
  function fs:Hide()
    self._shown = false
  end
  function fs:Show()
    self._shown = true
  end
  function fs:IsShown()
    return self._shown == true
  end
  function fs:SetFont(path, size, flags)
    self._fontPath = path
    self._fontSize = size
    self._fontFlags = flags
  end
  function fs:GetFont()
    return self._fontPath or "Fonts\\FRIZQT__.TTF", self._fontSize or 12, self._fontFlags or ""
  end
  function fs:GetStringHeight()
    local width = tonumber(self._width) or 0
    if width <= 0 then
      return 14
    end
    local charsPerLine = math.max(8, math.floor(width / 7))
    local textLength = #(self._text or "")
    local lines = math.max(1, math.ceil(textLength / charsPerLine))
    return lines * 14
  end
  return fs
end

local function CreateFrameStub(_frameType, _name, parent, _template)
  local frame = {
    _scripts = {},
    _shown = false,
    _point = nil,
    _parent = parent,
    _frameStrata = "MEDIUM",
    _alpha = 1,
    _width = 100,
    _height = 50,
  }
  function frame:SetSize(w, h)
    self._width = w
    self._height = h
  end
  function frame:SetWidth(w)
    self._width = w
  end
  function frame:SetHeight(h)
    self._height = h
  end
  function frame:GetWidth()
    return self._width
  end
  function frame:GetHeight()
    return self._height
  end
  function frame:SetPoint(...)
    self._point = { ... }
  end
  function frame:GetPoint()
    if not self._point then
      return nil
    end
    return self._point[1], self._point[2], self._point[3], self._point[4], self._point[5]
  end
  function frame:ClearAllPoints()
    self._point = nil
  end
  function frame:SetFrameStrata(s)
    self._frameStrata = s
  end
  function frame:GetFrameStrata()
    return self._frameStrata
  end
  function frame:SetFrameLevel(level)
    self._frameLevel = level
  end
  function frame:GetFrameLevel()
    return self._frameLevel or 1
  end
  function frame:Hide()
    self._shown = false
  end
  function frame:Show()
    self._shown = true
  end
  function frame:IsShown()
    return self._shown == true
  end
  function frame:SetScript(name, fn)
    self._scripts[name] = fn
  end
  function frame:GetScript(name)
    return self._scripts[name]
  end
  function frame:SetAlpha(a)
    self._alpha = a
  end
  function frame:GetAlpha()
    return self._alpha
  end
  function frame:CreateTexture()
    return CreateTextureStub()
  end
  function frame:CreateFontString()
    return CreateFontStringStub()
  end
  function frame:EnableMouse() end
  function frame:SetMovable() end
  function frame:RegisterForDrag() end
  function frame:RegisterForClicks() end
  function frame:SetAttribute() end
  function frame:SetClampedToScreen() end
  function frame:SetIgnoreParentAlpha() end
  function frame:Enable() end
  function frame:Disable() end
  return frame
end

local function RequireValue(value, message)
  if value == nil then
    error(message, 2)
  end
  return value
end

local function RegisterPortalNavigatorBranchTests(test, Assert, WithGlobals, LoadAddonModules)
  test("PortalNavigator hides itself when right-clicked", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local portal = Notice.CreatePortalNavigatorNotice({ parent = UIParent })
      portal.SetVisible(true)
      Assert.True(portal.frame:IsShown(), "portal navigator visible before right-click")

      local onMouseUp = portal.frame:GetScript("OnMouseUp")
      onMouseUp = RequireValue(onMouseUp, "portal navigator frame should define OnMouseUp")
      onMouseUp(portal.frame, "RightButton")
      Assert.False(portal.frame:IsShown(), "portal navigator hides on RightButton mouse-up")
    end)
  end)

  test("PortalNavigator left-click does NOT hide the frame", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local portal = Notice.CreatePortalNavigatorNotice({ parent = UIParent })
      portal.SetVisible(true)

      local onMouseUp = portal.frame:GetScript("OnMouseUp")
      onMouseUp(portal.frame, "LeftButton")
      Assert.True(portal.frame:IsShown(), "portal navigator must NOT hide on LeftButton mouse-up")
    end)
  end)

  test("PortalNavigator close-button click hides the frame", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local portal = Notice.CreatePortalNavigatorNotice({ parent = UIParent })
      portal.SetVisible(true)

      local closeButton = RequireValue(portal.closeButton, "portal navigator should expose close button")
      local onClick = closeButton:GetScript("OnClick")
      onClick = RequireValue(onClick, "portal navigator close button should define OnClick")
      onClick(closeButton)
      Assert.False(portal.frame:IsShown(), "portal navigator close button hides the frame")
    end)
  end)
end

local function RegisterCenterNoticeSublineTests(test, Assert, WithGlobals, LoadAddonModules)
  local function CreateCenterNoticeForSublineTest()
    local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
    local Notice = RequireValue(addon.Notice, "Notice module should load")
    return Notice.CreateCenterNotice({
      parent = UIParent,
      isInCombat = function()
        return false
      end,
    })
  end

  test("Center notice exposes top/bottom subline FontStrings", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForSublineTest()
      Assert.NotNil(centerNotice.sublineTop, "sublineTop FontString must be exposed on the controller")
      Assert.NotNil(centerNotice.sublineBottom, "sublineBottom FontString must be exposed on the controller")
      Assert.False(centerNotice.sublineTop._shown == true, "sublineTop must be hidden by default before any Show call")
      Assert.False(
        centerNotice.sublineBottom._shown == true,
        "sublineBottom must be hidden by default before any Show call"
      )
    end)
  end)

  test("Center notice Show with sublineTop/sublineBottom renders both sublines", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForSublineTest()
      centerNotice.Show("Windrunner Spire +15", 12, nil, nil, {
        sublineTop = "Joined",
        sublineBottom = "Group: Push lobby",
      })

      Assert.True(centerNotice.sublineTop._shown, "sublineTop must be shown when sublineTop option is set")
      Assert.Equal(centerNotice.sublineTop:GetText(), "Joined", "sublineTop must contain the supplied text")
      Assert.True(centerNotice.sublineBottom._shown, "sublineBottom must be shown when sublineBottom option is set")
      Assert.Equal(
        centerNotice.sublineBottom:GetText(),
        "Group: Push lobby",
        "sublineBottom must contain the supplied text"
      )
    end)
  end)

  test("Center notice Show without subline options keeps sublines hidden (legacy 1-line layout)", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForSublineTest()
      centerNotice.Show("Plain notice", 20, nil, nil, {})
      Assert.False(centerNotice.sublineTop._shown, "sublineTop must remain hidden in legacy single-line layout")
      Assert.False(centerNotice.sublineBottom._shown, "sublineBottom must remain hidden in legacy single-line layout")
    end)
  end)

  test("Center notice Show resets sublines when reused with a single-line message after a stacked one", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForSublineTest()
      centerNotice.Show("Stacked headline", 12, nil, nil, {
        sublineTop = "Joined",
        sublineBottom = "Group: X",
      })
      Assert.True(centerNotice.sublineTop._shown, "sublineTop visible after first stacked Show")

      centerNotice.Show("Plain follow-up", 12, nil, nil, {})
      Assert.False(
        centerNotice.sublineTop._shown,
        "sublineTop must be hidden again when the next Show passes no subline option"
      )
      Assert.False(
        centerNotice.sublineBottom._shown,
        "sublineBottom must be hidden again when the next Show passes no subline option"
      )
    end)
  end)

  test("Center notice Show treats empty-string sublines as absent", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForSublineTest()
      centerNotice.Show("Headline only", 12, nil, nil, {
        sublineTop = "",
        sublineBottom = "",
      })
      Assert.False(centerNotice.sublineTop._shown, "empty-string sublineTop must not be shown")
      Assert.False(centerNotice.sublineBottom._shown, "empty-string sublineBottom must not be shown")
    end)
  end)
end

local function RegisterCenterNoticeRichLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
  local function CreateCenterNoticeForRichTest()
    local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
    local Notice = RequireValue(addon.Notice, "Notice module should load")
    return Notice.CreateCenterNotice({
      parent = UIParent,
      isInCombat = function()
        return false
      end,
    })
  end

  test("Center notice exposes rich-layout primitives (title, separator, fieldRows, teleportHeader)", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      Assert.NotNil(centerNotice.titleText, "titleText must be exposed")
      Assert.NotNil(centerNotice.eyebrowText, "eyebrowText must be exposed")
      Assert.NotNil(centerNotice.titleSeparator, "titleSeparator must be exposed")
      Assert.NotNil(centerNotice.teleportHeader, "teleportHeader must be exposed")
      Assert.NotNil(centerNotice.fieldRows, "fieldRows must be exposed")
      Assert.Equal(#centerNotice.fieldRows, 4, "should pre-allocate 4 field rows")
      Assert.False(centerNotice.titleText._shown, "titleText hidden by default")
      Assert.False(centerNotice.eyebrowText._shown, "eyebrowText hidden by default")
      Assert.False(centerNotice.fieldRows[1].label._shown, "first field row hidden by default")
    end)
  end)

  test("Center notice rich Show renders title, separator, field rows, teleport header", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      centerNotice.Show(nil, 12, nil, nil, {
        eyebrow = "M+ Target",
        title = "isiLive - Einladung angenommen",
        fields = {
          { label = "Dungeon:", value = "Akademie von Algeth'ar +13" },
          { label = "Gruppe:", value = "+13 Push-Lobby" },
        },
        teleportLabel = "Zum Dungeon teleportieren:",
      })

      Assert.True(centerNotice.eyebrowText._shown, "eyebrowText must be visible")
      Assert.Equal(centerNotice.eyebrowText:GetText(), "M+ Target", "eyebrow text must propagate")
      Assert.True(centerNotice.titleText._shown, "titleText must be visible")
      Assert.Equal(centerNotice.titleText:GetText(), "isiLive - Einladung angenommen", "title text must propagate")
      Assert.Equal(centerNotice.titleSeparator._hidden, false, "titleSeparator must be visible when title is set")

      Assert.True(centerNotice.fieldRows[1].label._shown, "first field label visible")
      Assert.Equal(centerNotice.fieldRows[1].label:GetText(), "Dungeon:", "first field label text")
      Assert.Equal(centerNotice.fieldRows[1].value:GetText(), "Akademie von Algeth'ar +13", "first field value text")
      Assert.True(centerNotice.fieldRows[2].label._shown, "second field label visible")
      Assert.Equal(centerNotice.fieldRows[2].value:GetText(), "+13 Push-Lobby", "second field value text")
      Assert.False(centerNotice.fieldRows[3].label._shown, "third field row stays hidden when only 2 fields supplied")

      Assert.True(centerNotice.teleportHeader._shown, "teleportHeader must be visible")
      Assert.Equal(centerNotice.teleportHeader:GetText(), "Zum Dungeon teleportieren:", "teleportHeader text")

      Assert.False(centerNotice.text._shown, "regular text body must be hidden in rich mode")
    end)
  end)

  test("Center notice headline titles use shared gold color", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      centerNotice.Show(nil, 12, nil, nil, {
        title = "isiLive - Einladung angenommen",
        fields = {
          { label = "Dungeon:", value = "Akademie von Algeth'ar +13" },
        },
      })

      local r, g, b = centerNotice.titleText:GetTextColor()
      Assert.Equal(r, 1, "center notice headline title should use the shared gold red channel")
      Assert.Equal(g, 0.9, "center notice headline title should use the shared gold green channel")
      Assert.Equal(b, 0.45, "center notice headline title should use the shared gold blue channel")
    end)
  end)

  test("Center notice rich field values use wider label gutter", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      centerNotice.Show(nil, 12, nil, nil, {
        title = "isiLive - Dungeon entered",
        fields = {
          { label = "Dungeon:", value = "Priory of the Sacred Flame" },
        },
      })

      local point, relativeTo, relativePoint, x = centerNotice.fieldRows[1].value:GetPoint()
      Assert.Equal(point, "TOPLEFT", "field value should anchor from the left text block")
      Assert.Equal(relativeTo, centerNotice.frame, "field value should anchor to the center notice frame")
      Assert.Equal(relativePoint, "TOPLEFT", "field value should use a stable top-left anchor")
      Assert.Equal(x, 170, "field values should start farther to the right")
    end)
  end)

  test("Center notice rich warning field renders red and blinks", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      centerNotice.Show(nil, 12, nil, nil, {
        title = "isiLive - Dungeon entered",
        fields = {
          { label = "Dungeon:", value = "Priory of the Sacred Flame" },
          { label = "Hint:", value = "Not a Mythic+ dungeon", warning = true, blink = true },
        },
      })

      local labelR, labelG, labelB, labelA = centerNotice.fieldRows[2].label:GetTextColor()
      local valueR, valueG, valueB, valueA = centerNotice.fieldRows[2].value:GetTextColor()
      Assert.Equal(labelR, 1, "warning label red channel must be dominant")
      Assert.Equal(labelG, 0.16, "warning label green channel must use danger tint")
      Assert.Equal(labelB, 0.12, "warning label blue channel must use danger tint")
      Assert.Equal(labelA, 1, "warning label starts fully visible")
      Assert.Equal(valueR, 1, "warning value red channel must be dominant")
      Assert.Equal(valueG, 0.16, "warning value green channel must use danger tint")
      Assert.Equal(valueB, 0.12, "warning value blue channel must use danger tint")
      Assert.Equal(valueA, 1, "warning value starts fully visible")

      centerNotice.frame:GetScript("OnUpdate")(centerNotice.frame, 0.2)
      local _, _, _, blinkAlpha = centerNotice.fieldRows[2].value:GetTextColor()
      Assert.True(blinkAlpha < 1, "warning value alpha should pulse after an update tick")
    end)
  end)

  test("Center notice removes hidden OnUpdate polling and restores it when shown", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      centerNotice.Show("Visible", 12)
      Assert.Equal(type(centerNotice.frame:GetScript("OnUpdate")), "function", "shown notice must animate")
      centerNotice.SetVisible(false)
      Assert.Nil(centerNotice.frame:GetScript("OnUpdate"), "hidden notice must remove OnUpdate polling")
      centerNotice.SetVisible(true)
      Assert.Equal(type(centerNotice.frame:GetScript("OnUpdate")), "function", "shown notice must restore OnUpdate")
    end)
  end)

  test("Center notice teleport button owns OnUpdate only while visible", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local centerNotice = addon.Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellIDByMapID = function()
          return 12345
        end,
        applySecureSpellToButton = function()
          return true
        end,
        isSpellKnown = function()
          return true
        end,
      })
      Assert.True(centerNotice.ConfigureTeleportButton("Dungeon", nil, 777), "verified map must show button")
      Assert.Equal(type(centerNotice.teleportButton:GetScript("OnUpdate")), "function", "visible button must poll")
      Assert.False(centerNotice.ConfigureTeleportButton(nil, nil, nil), "empty target must hide button")
      Assert.Nil(centerNotice.teleportButton:GetScript("OnUpdate"), "hidden button must remove polling")
      Assert.True(centerNotice.ConfigureTeleportButton("Dungeon", nil, 777), "button must be restorable")
      Assert.Equal(type(centerNotice.teleportButton:GetScript("OnUpdate")), "function", "restored button must poll")
    end)
  end)

  test("Center notice rich field values use Cyrillic-capable font for Cyrillic leader names", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
      IsiLiveDB = { locale = "enUS" },
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      centerNotice.Show(nil, 12, nil, nil, {
        title = "isiLive - Einladung angenommen",
        fields = {
          { label = "Dungeon:", value = "Maisarakavernen" },
          {
            label = "Leader:",
            value = "\208\157\208\184\209\129\208\176\208\189-\208\154\208\176\208\183\208\183\208\176\208\186",
          },
        },
      })

      Assert.Equal(
        centerNotice.fieldRows[2].value._fontPath,
        "Fonts\\ARIALN.TTF",
        "Cyrillic leader names should use a Cyrillic-capable font in the center notice"
      )
    end)
  end)

  test("Center notice rich Show places a larger teleport button in the right action area", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return 12345
        end,
        resolveMapIDBySpellID = function()
          return 559
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
      })

      centerNotice.Show(nil, 12, "Akademie von Algeth'ar", nil, {
        eyebrow = "M+ Ziel",
        title = "isiLive - Einladung angenommen",
        fields = {
          { label = "Dungeon:", value = "Akademie von Algeth'ar +13" },
          { label = "Gruppe:", value = "+13 Push-Lobby" },
          { label = "Leader:", value = "Lead-Realm" },
          { label = "Quelle:", value = "LFG-Einladung angenommen" },
        },
      })

      Assert.Equal(
        centerNotice.teleportButton:GetWidth(),
        170,
        "rich teleport button should keep a generous click area"
      )
      Assert.Equal(
        centerNotice.teleportButton:GetHeight(),
        107,
        "rich teleport button should span title through source row"
      )
      local point, relativeTo, relativePoint, x, y = centerNotice.teleportButton:GetPoint()
      Assert.Equal(point, "CENTER", "rich teleport button should anchor by its center in the right action area")
      Assert.Equal(relativeTo, centerNotice.frame, "rich teleport button should anchor to the center notice")
      Assert.Equal(relativePoint, "TOPRIGHT", "rich teleport button should calculate its y-position from the frame top")
      Assert.Equal(x, -109, "rich teleport button should sit in the free right-side interior area")
      Assert.Equal(y, -84, "rich teleport button should align symmetrically with the rich text block")
      Assert.Equal(
        centerNotice.teleportButton.icon._width,
        93,
        "rich teleport icon should be visually dominant inside the action area"
      )
      Assert.Equal(
        centerNotice.teleportButton.actionBg._width,
        101,
        "rich teleport visible blue background should only frame the icon"
      )
    end)
  end)

  test("Center notice SetVisible(false) hides the rich teleport button with the frame", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return 12345
        end,
        resolveMapIDBySpellID = function()
          return 559
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
      })

      centerNotice.Show(nil, 12, "Akademie von Algeth'ar", nil, {
        title = "isiLive - Einladung angenommen",
        fields = {
          { label = "Dungeon:", value = "Akademie von Algeth'ar +13" },
        },
      })
      Assert.True(centerNotice.teleportButton:IsShown(), "setup: rich teleport button is visible")

      centerNotice.SetVisible(false)

      Assert.False(centerNotice.frame:IsShown(), "center notice frame must hide")
      Assert.False(centerNotice.teleportButton:IsShown(), "rich teleport button must not float after hiding the frame")
    end)
  end)

  test("Center notice rich teleport button shows Portal label while ready", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return 12345
        end,
        resolveMapIDBySpellID = function()
          return 559
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        getL = function()
          return { CENTER_NOTICE_PORTAL_READY_LABEL = "Portal" }
        end,
      })

      centerNotice.Show(nil, 12, "Grube von Saron", nil, {
        title = "isiLive - Einladung angenommen",
        fields = {
          { label = "Dungeon:", value = "Grube von Saron" },
        },
      })
      centerNotice.teleportButton:GetScript("OnUpdate")(centerNotice.teleportButton, 0.1)

      Assert.True(centerNotice.teleportButton.cooldownText:IsShown(), "ready portal label should be visible")
      Assert.Equal(
        centerNotice.teleportButton.cooldownText:GetText(),
        "Portal",
        "ready portal label should use the locale text"
      )
      local _, fontSize = centerNotice.teleportButton.cooldownText:GetFont()
      Assert.True(fontSize >= 16, "ready portal label should use the enlarged teleport status font")
    end)
  end)

  test("Center notice rich teleport button cooldown text overrides Portal label", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local centerNotice = Notice.CreateCenterNotice({
        parent = UIParent,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return 12345
        end,
        resolveMapIDBySpellID = function()
          return 559
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 479
        end,
        formatCooldownSeconds = function()
          return "07:59"
        end,
        getL = function()
          return { CENTER_NOTICE_PORTAL_READY_LABEL = "Portal" }
        end,
      })

      centerNotice.Show(nil, 12, "Grube von Saron", nil, {
        title = "isiLive - Einladung angenommen",
        fields = {
          { label = "Dungeon:", value = "Grube von Saron" },
        },
      })
      centerNotice.teleportButton:GetScript("OnUpdate")(centerNotice.teleportButton, 0.1)

      Assert.Equal(centerNotice.teleportButton.cooldownText:GetText(), "07:59", "cooldown must replace the ready label")
      local _, fontSize = centerNotice.teleportButton.cooldownText:GetFont()
      Assert.True(fontSize >= 16, "cooldown timer should use the enlarged teleport status font")
    end)
  end)

  test("Center notice rich Show with frameWidth resizes the frame", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      centerNotice.Show(nil, 12, nil, nil, {
        title = "T",
        fields = { { label = "X:", value = "y" } },
        frameWidth = 540,
      })
      Assert.Equal(centerNotice.frame:GetWidth(), 540, "frameWidth option must resize the frame")

      centerNotice.Show("legacy", 12, nil, nil, {})
      Assert.Equal(centerNotice.frame:GetWidth(), 680, "legacy Show without frameWidth resets to default 680")
    end)
  end)

  test("Center notice transitions rich -> legacy hide rich primitives", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      centerNotice.Show(nil, 12, nil, nil, {
        title = "Rich",
        fields = { { label = "Dungeon:", value = "Spire" } },
        teleportLabel = "TP:",
      })
      Assert.True(centerNotice.titleText._shown, "rich title visible after rich Show")

      centerNotice.Show("plain follow-up", 12, nil, nil, {})
      Assert.False(centerNotice.titleText._shown, "title hidden after legacy Show")
      Assert.False(centerNotice.eyebrowText._shown, "eyebrow hidden after legacy Show")
      Assert.False(centerNotice.fieldRows[1].label._shown, "field rows hidden after legacy Show")
      Assert.False(centerNotice.teleportHeader._shown, "teleportHeader hidden after legacy Show")
      Assert.True(centerNotice.text._shown, "regular text body shown again in legacy mode")
    end)
  end)

  test("Center notice rich Show without title still renders fields (title/separator stay hidden)", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      centerNotice.Show(nil, 12, nil, nil, {
        fields = { { label = "Role:", value = "Tank" } },
      })
      Assert.False(centerNotice.titleText._shown, "no title -> titleText stays hidden")
      Assert.True(centerNotice.fieldRows[1].label._shown, "field row visible without title")
    end)
  end)

  test("Center notice rich layout expands height for long wrapped fields", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      local longValue = string.rep("VeryLongVerifiedDungeonGroupName ", 12)
      centerNotice.Show(nil, 12, nil, nil, {
        title = "isiLive - Dungeon entered",
        fields = {
          { label = "Dungeon:", value = longValue },
          { label = "Group:", value = longValue },
          { label = "Leader:", value = longValue },
        },
        frameWidth = 540,
      })

      Assert.True(
        centerNotice.frame:GetHeight() > 220,
        "rich center notice must grow beyond the default max height when wrapped verified values need it"
      )
    end)
  end)

  test("Center notice rich layout ignores too-small explicit maxHeight for required content", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeForRichTest()
      local longValue = string.rep("VeryLongVerifiedDungeonGroupName ", 12)
      centerNotice.Show(nil, 12, nil, nil, {
        title = "isiLive - Dungeon entered",
        fields = {
          { label = "Dungeon:", value = longValue },
          { label = "Group:", value = longValue },
          { label = "Leader:", value = longValue },
        },
        frameWidth = 540,
        maxHeight = 240,
      })

      Assert.True(
        centerNotice.frame:GetHeight() > 240,
        "explicit rich maxHeight must not clip verified wrapped field content"
      )
    end)
  end)

  -- The accepted-invite card carries a teleport button, but the teleport is an
  -- optional convenience: whether the player has learned that dungeon's
  -- teleport must never decide whether the card itself is shown.
  local function CreateCenterNoticeWithTeleportResolvers(LoadModules, spellID, known)
    local addon = LoadModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
    local Notice = RequireValue(addon.Notice, "Notice module should load")
    return Notice.CreateCenterNotice({
      parent = UIParent,
      isInCombat = function()
        return false
      end,
      resolveTeleportSpellIDByMapID = function()
        return spellID
      end,
      resolveTeleportSpellID = function()
        return spellID
      end,
      resolveMapIDBySpellID = function()
        return 559
      end,
      applySecureSpellToButton = function() end,
      isSpellKnown = function()
        return known
      end,
    })
  end

  local function ShowAcceptedInviteCard(centerNotice)
    centerNotice.Show(nil, nil, "Halls of Atonement", nil, {
      eyebrow = "M+ Target",
      title = "isiLive - Invite accepted",
      fields = {
        { label = "Dungeon:", value = "Halls of Atonement +12" },
        { label = "Leader:", value = "Leader-Realm" },
      },
      teleportMapID = 559,
      frameWidth = 680,
      persistent = true,
    })
  end

  test("Center notice accepted-invite card renders when the dungeon teleport is not learned", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeWithTeleportResolvers(LoadAddonModules, 354464, false)
      ShowAcceptedInviteCard(centerNotice)

      Assert.True(centerNotice.frame:IsShown(), "card must show even though the teleport spell is not learned")
      Assert.True(centerNotice.titleText._shown, "card title must render without a learned teleport")
      Assert.True(centerNotice.fieldRows[1].label._shown, "dungeon row must render without a learned teleport")
      Assert.True(centerNotice.fieldRows[2].label._shown, "leader row must render without a learned teleport")
      Assert.True(centerNotice.teleportButton:IsShown(), "an unlearned teleport stays visible as a disabled action")
    end)
  end)

  test("Center notice accepted-invite card renders when no teleport spell resolves at all", function()
    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return 0
      end,
    }, function()
      local centerNotice = CreateCenterNoticeWithTeleportResolvers(LoadAddonModules, nil, false)
      ShowAcceptedInviteCard(centerNotice)

      Assert.True(centerNotice.frame:IsShown(), "card must show even when no teleport spell resolves")
      Assert.True(centerNotice.titleText._shown, "card title must render without any teleport")
      Assert.True(centerNotice.fieldRows[1].label._shown, "dungeon row must render without any teleport")
      Assert.False(centerNotice.teleportButton:IsShown(), "an unresolvable teleport hides only the button")
    end)
  end)
end

return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "ui_notice_branches scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "ui_notice_branches scenario ctx.with_globals should exist")
  local LoadAddonModules = RequireValue(ctx.load_modules, "ui_notice_branches scenario ctx.load_modules should exist")

  RegisterPortalNavigatorBranchTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCenterNoticeSublineTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCenterNoticeRichLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
end
