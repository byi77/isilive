---@diagnostic disable: undefined-global, undefined-field
-- Rule 249 locks the main window to the M+ layout (RI.LAYOUT_LOCKED_TO_MPLUS).
-- These scenarios cover the kept V / H / M layout code, so they lift the lock.
local function UnlockLayout(addon)
  if type(addon) == "table" and type(addon._RosterInternal) == "table" then
    addon._RosterInternal.LAYOUT_LOCKED_TO_MPLUS = false
  end
  return addon
end

-- Round 7 UI audit regressions: roster render visibility/tooltip ownership,
-- reset popup restore, nameplate diagnostics secret safety, trace chat frame reuse.

local function LoadRosterPanelHelpers()
  local chunk, loadErr = loadfile("testmodul/isilive_test_scenarios_roster_panel.lua")
  if not chunk then
    error(string.format("cannot load roster_panel helpers: %s", tostring(loadErr)))
  end
  local helperAddon = {}
  local ok, runErr = pcall(chunk, "isiLive", helperAddon)
  if not ok then
    error(string.format("cannot execute roster_panel helpers: %s", tostring(runErr)))
  end
  return helperAddon._RosterPanelTests or {}
end

local H = LoadRosterPanelHelpers()

return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = function(files)
    return UnlockLayout(ctx.load_modules(files))
  end

  local ORDER = { "player", "party1", "party2" }
  local function BuildRoster(count)
    local roster = {}
    for i = 1, count do
      roster[ORDER[i]] = { name = "Member" .. i, role = "DAMAGER", syncDps = 123456 }
    end
    return roster
  end

  -- Renders through the real RosterPanel controller with recorded frames.
  local function WithRosterController(globals, body)
    local createdFrames, createdFontStrings = {}, {}
    local base = {
      CreateFrame = function()
        return H.NewRecordedFrame(createdFrames, createdFontStrings)
      end,
      GameTooltip = {
        SetOwner = function() end,
        SetText = function() end,
        AddLine = function() end,
        Show = function() end,
        Hide = function() end,
      },
    }
    for k, v in pairs(globals or {}) do
      base[k] = v
    end
    WithGlobals(base, function()
      local addon = LoadAddonModules({ "isiLive_roster.lua", "isiLive_roster_panel.lua" })
      local controller = H.BuildHiddenSettingTestController(addon, createdFontStrings, {
        buildOrderedRoster = function(roster)
          local out = {}
          for _, unit in ipairs(ORDER) do
            if roster and roster[unit] then
              out[#out + 1] = { unit = unit, info = roster[unit] }
            end
          end
          return out
        end,
        buildDisplayData = function(info)
          return {
            colorHex = "ffffffff",
            displayName = info.name,
            languageDisplay = "",
            specText = "-",
            ilvlText = "-",
            rioText = "-",
            keyText = "-",
            addonMarker = "",
            atDungeonMarker = "",
            readyCheckMarkup = "",
            roleIconMarkup = "",
          }
        end,
      })
      body(controller, createdFrames, createdFontStrings)
    end)
  end

  local function FindByText(fontStrings, pattern)
    for _, fs in ipairs(fontStrings) do
      if type(fs.text) == "string" and fs.text:find(pattern) then
        return fs
      end
    end
    return nil
  end

  for _, mode in ipairs({ "compact_vertical", "compact_horizontal" }) do
    test("R7 U-1: re-render in " .. mode .. " keeps DPS header and values hidden", function()
      WithRosterController({ IsiLiveDB = { rosterDefaultLayoutMode = mode } }, function(controller, _, fontStrings)
        controller.ApplyLocalization()
        controller.RestoreSavedState()
        controller.RenderRoster(BuildRoster(2))
        controller.RenderRoster(BuildRoster(2))
        local header = Assert.NotNil(FindByText(fontStrings, "DPS"), "DPS header font string")
        Assert.False(header._shown, "DPS header must stay hidden after a render in a compact layout")
        for _, fs in ipairs(fontStrings) do
          if type(fs.text) == "string" and fs.text:find("123") then
            Assert.False(fs._shown, "DPS value must stay hidden after a render in a compact layout")
          end
        end
      end)
    end)
  end

  test("R7 U-1: expanded layout still shows DPS header and values", function()
    WithRosterController({ IsiLiveDB = { rosterDefaultLayoutMode = "expanded" } }, function(controller, _, fontStrings)
      controller.ApplyLocalization()
      controller.RestoreSavedState()
      controller.RenderRoster(BuildRoster(2))
      local header = Assert.NotNil(FindByText(fontStrings, "DPS"), "DPS header font string")
      Assert.True(header._shown, "DPS header must be shown in the expanded layout")
      local value = Assert.NotNil(FindByText(fontStrings, "123"), "DPS value font string")
      Assert.True(value._shown, "DPS value must be shown in the expanded layout")
    end)
  end)

  local function FindHover(frames, unit)
    for _, f in ipairs(frames) do
      if f.unit == unit and type(f.OnEnter) == "function" then
        return f
      end
    end
    return nil
  end

  -- The panel owns several simple-tooltip frames; the roster one is whichever
  -- the hover handler anchored to the hovered row.
  local function FindTooltipOwnedBy(frames, owner)
    for _, f in ipairs(frames) do
      if f._isIsiLiveTooltip and f._isiLiveTooltipOwner == owner then
        return f
      end
    end
    return nil
  end

  test("R7 U-2: clearing stale rows does not hide the tooltip of a hovered live row", function()
    WithRosterController({ IsiLiveDB = { rosterDefaultLayoutMode = "expanded" } }, function(controller, frames)
      controller.RenderRoster(BuildRoster(2))
      local live = Assert.NotNil(FindHover(frames, "player"), "live row hover frame")
      live.OnEnter()
      local tooltip = Assert.NotNil(FindTooltipOwnedBy(frames, live), "hover must anchor the shared roster tooltip")
      Assert.True(tooltip._isiLiveTooltipShown == true, "hover must show the tooltip")
      Assert.Equal(tooltip._isiLiveTooltipOwner, live, "hovered row owns the tooltip")
      -- Group shrinks: row 2 becomes a stale slot and is cleared on this render.
      controller.RenderRoster(BuildRoster(1))
      Assert.True(tooltip._isiLiveTooltipShown == true, "clearing another row must keep the tooltip")
    end)
  end)

  test("R7 U-2: clearing the row that owns the tooltip still hides it", function()
    WithRosterController({ IsiLiveDB = { rosterDefaultLayoutMode = "expanded" } }, function(controller, frames)
      controller.RenderRoster(BuildRoster(2))
      local stale = Assert.NotNil(FindHover(frames, "party1"), "second row hover frame")
      stale.OnEnter()
      local tooltip = Assert.NotNil(FindTooltipOwnedBy(frames, stale), "hover must anchor the shared roster tooltip")
      Assert.True(tooltip._isiLiveTooltipShown == true, "hover must show the tooltip")
      controller.RenderRoster(BuildRoster(1))
      Assert.False(tooltip._isiLiveTooltipShown == true, "clearing the owning row must hide the tooltip")
    end)
  end)

  test("R7 S-2: nameplate diagnostics never carry or compare secret values", function()
    local secretPercent = "__R7_SECRET_PERCENT__"
    local secretText = "__R7_SECRET_TEXT__"
    WithGlobals({
      issecretvalue = function(v)
        return v == secretPercent or v == secretText
      end,
      C_ScenarioInfo = {},
    }, function()
      local addon = LoadAddonModules({ "isiLive_validation_helpers.lua", "isiLive_mob_nameplate_diagnostics.lua" })
      local frames = {
        np = {
          IsShown = function()
            return true
          end,
          text = {
            GetText = function()
              return secretText
            end,
          },
        },
      }
      local built = {}
      local diagnostics = addon.MobNameplateDiagnostics.Create({
        frames = frames,
        appearance = { fontSize = 12 },
        getState = function()
          return { enabled = true, testMode = false }
        end,
        hasNamePlateAPI = function()
          return true
        end,
        hasProgressAPI = function()
          return true
        end,
        challengeActive = function()
          return true
        end,
        activeMapID = function()
          return 1
        end,
        isEligibleUnit = function()
          return false
        end,
        npcIdFromGuid = function() end,
        getForcesDB = function() end,
        resolveMobContributionFromDB = function() end,
        resolveRemainingPercent = function() end,
        buildText = function(percent)
          built[#built + 1] = percent
          return tostring(percent)
        end,
        safeCall = function()
          return nil, nil, secretPercent
        end,
      })
      local state = diagnostics.DumpState("target")
      Assert.Nil(state.apiPercentRaw, "raw API value must not be exposed")
      Assert.Equal(state.apiPercent, "<secret>", "secret API percent is redacted")
      Assert.True(state.apiPercentSecret == true, "secret flag set")
      Assert.True(state.resolvedFromMaskedApi == true, "masked API value still resolves")
      Assert.Equal(#built, 0, "secret percent must never reach BuildText")
      for k, v in pairs(state) do
        Assert.True(v ~= secretPercent and v ~= secretText, "state field " .. tostring(k) .. " leaks a secret")
      end
      local frameDump = diagnostics.DumpFrames()
      Assert.Equal(frameDump.frames[1].fontStringText, "<secret>", "DumpFrames redacts secret text")
    end)
  end)

  test("R7 S-3: trace chat frame is re-resolved by name and closed through FCF_Close", function()
    local function MakeChatFrame()
      local f = { _shown = false, _msgs = {} }
      function f:Show()
        self._shown = true
      end
      function f:Hide()
        self._shown = false
      end
      function f:IsShown()
        return self._shown
      end
      function f:AddMessage(text)
        self._msgs[#self._msgs + 1] = text
      end
      return f
    end
    local frameA = MakeChatFrame()
    local slot1Name = "isiLive Trace"
    local closed = {}
    WithGlobals({
      NUM_CHAT_WINDOWS = 2,
      GetChatWindowInfo = function(i)
        return i == 1 and slot1Name or nil
      end,
      ChatFrame1 = frameA,
      FCF_Close = function(frame)
        closed[#closed + 1] = frame
        frame._shown = false
      end,
      FCF_OpenNewWindow = function()
        return nil
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_trace_chat_frame.lua" })
      local controller = addon.TraceChatFrame.CreateController()
      controller.AddMessage("one")
      Assert.Equal(#frameA._msgs, 1, "first message lands in the trace frame")
      controller.Close()
      Assert.Equal(closed[1], frameA, "Close must go through FCF_Close")
      -- The user closed the tab; Blizzard reuses ChatFrame1 for an unrelated window.
      slot1Name = "General"
      controller.AddMessage("two")
      Assert.Equal(#frameA._msgs, 1, "traces must not stream into a reused ChatFrame slot")
    end)
  end)

  test("R7 S-1: reset confirmation restores the shared StaticPopup frame on hide", function()
    local dialogs = {}
    local shown
    local function MakeButton()
      local b = { _w = 120, _h = 24, _scripts = {}, _hooks = {} }
      function b:SetSize(w, h)
        self._w, self._h = w, h
      end
      function b:GetSize()
        return self._w, self._h
      end
      function b:GetText()
        return "x"
      end
      function b:SetText() end
      function b:HookScript(name, fn)
        self._hooks[name] = fn
      end
      function b:SetScript(name, fn)
        self._scripts[name] = fn
      end
      return b
    end
    local textColor = { 1, 0.82, 0, 1 }
    local text = {}
    function text:SetTextColor(...)
      textColor = { ... }
    end
    function text:GetTextColor()
      return unpack(textColor)
    end
    local popup = { text = text, button1 = MakeButton(), button2 = MakeButton(), _movable = true }
    function popup:SetMovable(v)
      self._movable = v
    end
    function popup:IsMovable()
      return self._movable
    end
    WithGlobals({
      StaticPopupDialogs = dialogs,
      StaticPopup_Show = function(name)
        shown = name
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_settings_reset.lua" })
      addon.SettingsReset.ShowResetConfirmation("R7", "Reset?", function() end)
      local def = dialogs[shown]
      def.OnShow(popup)
      Assert.Equal(popup.button1._w, 96, "styled while shown")
      Assert.False(popup._movable, "styled popup is not movable")
      Assert.Nil(popup.button1._scripts.OnEnter, "Blizzard OnEnter must not be replaced via SetScript")
      Assert.NotNil(popup.button1._hooks.OnEnter, "hover visuals use HookScript")
      def.OnHide(popup)
      Assert.Equal(popup.button1._w, 120, "button width restored")
      Assert.Equal(popup.button1._h, 24, "button height restored")
      Assert.True(popup._movable == true, "movable restored")
      Assert.Equal(textColor[1], 1, "text color restored")
      Assert.Equal(textColor[3], 0, "text color restored")
    end)
  end)

  test("R7 S-1b: a design switch after the reset popup closed leaves the shared StaticPopup alone", function()
    local dialogs = {}
    local shown
    local popup = { backdropCalls = 0 }
    function popup:SetBackdrop(backdrop)
      self.backdropCalls = self.backdropCalls + 1
      self.backdrop = backdrop
    end
    function popup:GetBackdrop()
      return self.backdrop
    end
    function popup:SetBackdropColor() end
    function popup:SetBackdropBorderColor() end
    WithGlobals({
      StaticPopupDialogs = dialogs,
      StaticPopup_Show = function(name)
        shown = name
      end,
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_common.lua", "isiLive_settings_reset.lua" })
      addon.SettingsReset.ShowResetConfirmation("R7B", "Reset?", function() end)
      local def = dialogs[shown]
      def.OnShow(popup)
      Assert.True(popup.backdropCalls > 0, "popup styled while shown")
      def.OnHide(popup)
      local afterHide = popup.backdropCalls
      addon.UICommon.RepaintDesign()
      Assert.Equal(popup.backdropCalls, afterHide, "design repaint must not touch the handed-back popup")
    end)
  end)
end
