-- Branch-coverage scenarios for ui/isiLive_notice.lua. Targets functions and
-- code paths that the existing isilive_test_scenarios_ui_center_notice.lua
-- file does not exercise:
--   * Notice.CreateInviteHint full lifecycle (anchor resolution, OnUpdate
--     auto-hide, manual-texture fallback when SetBackdrop is unavailable)
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
  function fs:SetWidth() end
  function fs:Hide()
    self._shown = false
  end
  function fs:Show()
    self._shown = true
  end
  function fs:IsShown()
    return self._shown == true
  end
  function fs:SetFont() end
  function fs:GetFont()
    return "Fonts\\FRIZQT__.TTF", 12, ""
  end
  function fs:GetStringHeight()
    return 14
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

local function RegisterInviteHintTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Notice.CreateInviteHint anchors to LFGListInviteDialog when shown", function()
    local now = 100
    local lfgListInviteDialog = CreateFrameStub()
    lfgListInviteDialog:Show()

    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return now
      end,
      LFGListInviteDialog = lfgListInviteDialog,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local hint = Notice.CreateInviteHint({ parent = UIParent })

      hint.Show("Tank pending", 5)
      Assert.True(hint.frame:IsShown(), "invite hint should be visible after Show()")

      local point, relativeTo, relativePoint, _, _ = hint.frame:GetPoint()
      Assert.Equal(point, "TOP", "invite hint should anchor TOP-side")
      Assert.Equal(relativeTo, lfgListInviteDialog, "invite hint should anchor to LFGListInviteDialog when shown")
      Assert.Equal(relativePoint, "BOTTOM", "invite hint should anchor relative to dialog BOTTOM")
    end)
  end)

  test("Notice.CreateInviteHint falls back to LFGDungeonReadyDialog when invite dialog is hidden", function()
    local now = 200
    local lfgListInviteDialog = CreateFrameStub()
    lfgListInviteDialog:Hide()
    local lfgDungeonReadyDialog = CreateFrameStub()
    lfgDungeonReadyDialog:Show()

    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return now
      end,
      LFGListInviteDialog = lfgListInviteDialog,
      LFGDungeonReadyDialog = lfgDungeonReadyDialog,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local hint = Notice.CreateInviteHint({ parent = UIParent })
      hint.Show("Healer pending", 5)

      local _, relativeTo = hint.frame:GetPoint()
      Assert.Equal(
        relativeTo,
        lfgDungeonReadyDialog,
        "invite hint should fall back to LFGDungeonReadyDialog when invite dialog is hidden"
      )
    end)
  end)

  test("Notice.CreateInviteHint falls back to global main frame when no LFG dialog is shown", function()
    local now = 300
    local mainFrameMock = CreateFrameStub()
    mainFrameMock:Show()

    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return now
      end,
      isiLiveMainFrame = mainFrameMock,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local hint = Notice.CreateInviteHint({ parent = UIParent })
      hint.Show("Damage pending", 5)

      local _, relativeTo = hint.frame:GetPoint()
      Assert.Equal(
        relativeTo,
        mainFrameMock,
        "invite hint should anchor to global main frame when no LFG dialog is shown"
      )
    end)
  end)

  test("Notice.CreateInviteHint falls back to parent UIParent when nothing else is available", function()
    local now = 400
    local parent = CreateFrameStub()

    WithGlobals({
      UIParent = parent,
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local hint = Notice.CreateInviteHint({ parent = parent })
      hint.Show("Looking for group", 10)

      local point, relativeTo, relativePoint, _, y = hint.frame:GetPoint()
      Assert.Equal(point, "TOP", "fallback anchor should be TOP-side")
      Assert.Equal(relativeTo, parent, "fallback anchor should be the parent UIParent")
      Assert.Equal(relativePoint, "TOP", "fallback relative point should be parent TOP")
      Assert.Equal(y, -220, "fallback y offset should match notice spec")
    end)
  end)

  test("Notice.CreateInviteHint OnUpdate auto-hides after duration", function()
    local now = 500

    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return now
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local hint = Notice.CreateInviteHint({ parent = UIParent })

      hint.Show("Auto-expire", 3)
      Assert.True(hint.frame:IsShown(), "invite hint should be visible right after Show()")

      local onUpdate = hint.frame:GetScript("OnUpdate")
      onUpdate = RequireValue(onUpdate, "invite hint frame should expose OnUpdate")

      now = 502 -- inside duration window
      onUpdate(hint.frame, 2)
      Assert.True(hint.frame:IsShown(), "invite hint stays visible while inside duration")

      now = 504 -- past endsAt (500 + 3)
      onUpdate(hint.frame, 2)
      Assert.False(hint.frame:IsShown(), "invite hint hides itself after duration elapses")
    end)
  end)

  test("Notice.CreateInviteHint stays visible when dialog resultID matches Show() searchResultID", function()
    local now = 600
    local dialog = CreateFrameStub()
    dialog:Show()
    dialog.resultID = 42

    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return now
      end,
      LFGListInviteDialog = dialog,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local hint = Notice.CreateInviteHint({ parent = UIParent })

      hint.Show("Matching listing", 5, 42)
      Assert.True(
        hint.frame:IsShown(),
        "invite hint must stay visible when dialog.resultID matches the rendered searchResultID"
      )
    end)
  end)

  test("Notice.CreateInviteHint hides itself when dialog resultID differs from Show() searchResultID", function()
    local now = 700
    local dialog = CreateFrameStub()
    dialog:Show()
    dialog.resultID = 99

    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return now
      end,
      LFGListInviteDialog = dialog,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local hint = Notice.CreateInviteHint({ parent = UIParent })

      hint.Show("Stale listing", 5, 42)
      Assert.False(
        hint.frame:IsShown(),
        "invite hint must NOT show when dialog.resultID points at a different listing — Fix 3a"
      )
    end)
  end)

  test("Notice.CreateInviteHint stays visible when no LFGListInviteDialog is shown", function()
    -- Anchor falls back to LFGDungeonReadyDialog or main frame; the resultID
    -- mismatch guard only kicks in when LFGListInviteDialog is actively visible.
    local now = 800
    local readyDialog = CreateFrameStub()
    readyDialog:Show()

    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return now
      end,
      LFGDungeonReadyDialog = readyDialog,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local hint = Notice.CreateInviteHint({ parent = UIParent })

      hint.Show("Ready dialog", 5, 7)
      Assert.True(
        hint.frame:IsShown(),
        "invite hint must remain visible against non-LFGListInviteDialog anchors regardless of searchResultID"
      )
    end)
  end)

  test("Notice.CreateInviteHint OnUpdate hides when dialog switches to a different resultID mid-flight", function()
    local now = 900
    local dialog = CreateFrameStub()
    dialog:Show()
    dialog.resultID = 17

    WithGlobals({
      UIParent = CreateFrameStub(),
      CreateFrame = CreateFrameStub,
      GetTime = function()
        return now
      end,
      LFGListInviteDialog = dialog,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_notice.lua" })
      local Notice = RequireValue(addon.Notice, "Notice module should load")
      local hint = Notice.CreateInviteHint({ parent = UIParent })

      hint.Show("Initial listing", 10, 17)
      Assert.True(hint.frame:IsShown(), "matching resultID at Show() time keeps the hint visible")

      local onUpdate = hint.frame:GetScript("OnUpdate")
      onUpdate = RequireValue(onUpdate, "invite hint frame should expose OnUpdate")

      -- Blizzard advances to the next queued invite; Dialog.resultID flips.
      dialog.resultID = 18
      onUpdate(hint.frame, 0.5)
      Assert.False(hint.frame:IsShown(), "OnUpdate must hide the hint when the dialog switches to a different listing")
    end)
  end)
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
      Assert.NotNil(centerNotice.titleSeparator, "titleSeparator must be exposed")
      Assert.NotNil(centerNotice.teleportHeader, "teleportHeader must be exposed")
      Assert.NotNil(centerNotice.fieldRows, "fieldRows must be exposed")
      Assert.Equal(#centerNotice.fieldRows, 4, "should pre-allocate 4 field rows")
      Assert.False(centerNotice.titleText._shown, "titleText hidden by default")
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
        title = "isiLive - Einladung angenommen",
        fields = {
          { label = "Dungeon:", value = "Akademie von Algeth'ar +13" },
          { label = "Gruppe:", value = "+13 Push-Lobby" },
        },
        teleportLabel = "Zum Dungeon teleportieren:",
      })

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
        title = "isiLive - Einladung angenommen",
        fields = {
          { label = "Dungeon:", value = "Akademie von Algeth'ar +13" },
          { label = "Gruppe:", value = "+13 Push-Lobby" },
        },
      })

      Assert.Equal(centerNotice.teleportButton:GetWidth(), 64, "rich teleport button should use the larger icon size")
      Assert.Equal(centerNotice.teleportButton:GetHeight(), 64, "rich teleport button should use the larger icon size")
      local point, relativeTo, relativePoint, x, y = centerNotice.teleportButton:GetPoint()
      Assert.Equal(point, "CENTER", "rich teleport button should anchor by its center in the right action area")
      Assert.Equal(relativeTo, centerNotice.frame, "rich teleport button should anchor to the center notice")
      Assert.Equal(relativePoint, "TOPRIGHT", "rich teleport button should calculate its y-position from the frame top")
      Assert.Equal(x, -72, "rich teleport button should sit in the free right-side interior area")
      Assert.Equal(y, -88, "rich teleport button should align symmetrically with the rich field rows")
      Assert.Equal(
        #centerNotice.teleportButton.icon._points,
        2,
        "rich teleport icon texture should be explicitly stretched to the larger button"
      )
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
end

return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "ui_notice_branches scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "ui_notice_branches scenario ctx.with_globals should exist")
  local LoadAddonModules = RequireValue(ctx.load_modules, "ui_notice_branches scenario ctx.load_modules should exist")

  RegisterInviteHintTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterPortalNavigatorBranchTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCenterNoticeSublineTests(test, Assert, WithGlobals, LoadAddonModules)
  RegisterCenterNoticeRichLayoutTests(test, Assert, WithGlobals, LoadAddonModules)
end
