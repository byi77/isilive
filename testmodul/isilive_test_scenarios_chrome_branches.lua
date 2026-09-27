---@diagnostic disable: undefined-global

-- Branch-coverage scenarios for ui/isiLive_roster_panel_chrome.lua.
-- The existing chrome scenarios (via roster_panel_render / structure)
-- exercise the column-header layout, but every interactive closure in
-- CreateFlatButton, AttachPanelButtonTooltip, AttachModeButtonTooltip,
-- and CreateTankHelperButtons stays dark. This file drives them
-- through RI.* and direct button-stub triggering.

local function NewBackdropFrame(opts)
  opts = opts or {}
  local frame = {
    _backdropColor = nil,
    _borderColor = nil,
    _scripts = {},
    _hookScripts = {},
    _attributes = {},
    _mouseOver = opts.mouseOver == true,
    _label = nil,
    _children = {},
  }
  function frame.SetSize() end
  function frame.SetBackdropColor(self, ...)
    self._backdropColor = { ... }
  end
  function frame.SetBackdropBorderColor(self, ...)
    self._borderColor = { ... }
  end
  function frame.EnableMouse() end
  function frame.RegisterForClicks() end
  function frame.SetPoint() end
  function frame.SetWidth() end
  function frame.SetHeight() end
  function frame.SetText() end
  function frame.SetTextColor() end
  function frame.SetJustifyH() end
  function frame.SetWordWrap() end
  function frame.SetNonSpaceWrap() end
  function frame.SetMaxLines() end
  function frame.SetTexture() end
  function frame.SetGradient() end
  function frame.SetColorTexture() end
  function frame.SetNormalTexture(self, path)
    self._normalPath = path
  end
  function frame.SetHighlightTexture(self, path)
    self._highlightPath = path
    self._highlight = self._highlight
      or {
        SetVertexColor = function(texture, ...)
          texture._color = { ... }
        end,
        SetBlendMode = function(texture, mode)
          texture._blendMode = mode
        end,
      }
  end
  function frame.GetHighlightTexture(self)
    return self._highlight
  end
  function frame.SetAttribute(self, key, value)
    self._attributes[key] = value
  end
  function frame.HookScript(self, scriptType, fn)
    self._hookScripts[scriptType] = fn
  end
  function frame.SetScript(self, scriptType, fn)
    self._scripts[scriptType] = fn
  end
  function frame.GetScript(self, scriptType)
    return self._scripts[scriptType] or self._hookScripts[scriptType]
  end
  function frame.IsMouseOver(self)
    return self._mouseOver == true
  end
  function frame.AddLine() end
  function frame.Show() end
  function frame.Hide() end
  function frame.CreateFontString(self, _, _, _)
    local fs = NewBackdropFrame()
    self._label = fs
    return fs
  end
  function frame.CreateTexture(self, _, _)
    local tex = NewBackdropFrame()
    table.insert(self._children, tex)
    return tex
  end
  function frame.Trigger(self, scriptType, ...)
    local fn = self._hookScripts[scriptType] or self._scripts[scriptType]
    if fn then
      fn(self, ...)
    end
  end
  return frame
end

local function NewLooseFrame()
  -- Used as parent / mainFrame; supports CreateFontString / CreateTexture.
  return NewBackdropFrame()
end

local function MinimalGlobals(framesOut)
  return {
    CreateFrame = function()
      local f = NewBackdropFrame()
      if framesOut then
        table.insert(framesOut, f)
      end
      return f
    end,
  }
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  -- CreateFlatButton: hover / press / leave / mouse-up visual handlers --------

  test("CreateFlatButton applies default backdrop on creation", function()
    local frames = {}
    WithGlobals(MinimalGlobals(frames), function()
      local addon = LoadAddonModules({
        "isiLive_roster_panel_helpers.lua",
        "isiLive_roster_panel_chrome.lua",
      })
      local parent = NewLooseFrame()
      local btn = addon._RosterInternal.CreateFlatButton(parent, 80, 24)
      Assert.NotNil(btn._backdropColor, "default backdrop must be applied on creation")
    end)
  end)

  test("CreateFlatButton OnEnter / OnLeave hooks swap visuals", function()
    WithGlobals(MinimalGlobals(), function()
      local addon = LoadAddonModules({
        "isiLive_roster_panel_helpers.lua",
        "isiLive_roster_panel_chrome.lua",
      })
      local btn = addon._RosterInternal.CreateFlatButton(NewLooseFrame(), 80, 24)
      btn:Trigger("OnEnter") -- ApplyHoverVisual
      Assert.Equal(btn._backdropColor[1], 0.18, "hover backdrop r")
      Assert.Equal(btn._backdropColor[4], 0.8, "hover backdrop alpha")
      btn:Trigger("OnLeave") -- ApplyDefaultVisual
      Assert.True(btn._backdropColor[4] ~= 0.8, "leave must restore default alpha")
    end)
  end)

  test("CreateFlatButton OnMouseDown applies pressed visual", function()
    WithGlobals(MinimalGlobals(), function()
      local addon = LoadAddonModules({
        "isiLive_roster_panel_helpers.lua",
        "isiLive_roster_panel_chrome.lua",
      })
      local btn = addon._RosterInternal.CreateFlatButton(NewLooseFrame(), 80, 24)
      btn:Trigger("OnMouseDown")
      Assert.Equal(btn._backdropColor[1], 0.08, "pressed backdrop r")
      Assert.Equal(btn._backdropColor[4], 0.95, "pressed backdrop alpha")
    end)
  end)

  test("CreateFlatButton OnMouseUp returns to hover when still mouse-over", function()
    WithGlobals(MinimalGlobals(), function()
      local addon = LoadAddonModules({
        "isiLive_roster_panel_helpers.lua",
        "isiLive_roster_panel_chrome.lua",
      })
      local btn = addon._RosterInternal.CreateFlatButton(NewLooseFrame(), 80, 24)
      btn._mouseOver = true
      btn:Trigger("OnMouseUp")
      Assert.Equal(btn._backdropColor[4], 0.8, "mouse-over OnMouseUp must show hover backdrop")
    end)
  end)

  test("CreateFlatButton OnMouseUp returns to default when no longer mouse-over", function()
    WithGlobals(MinimalGlobals(), function()
      local addon = LoadAddonModules({
        "isiLive_roster_panel_helpers.lua",
        "isiLive_roster_panel_chrome.lua",
      })
      local btn = addon._RosterInternal.CreateFlatButton(NewLooseFrame(), 80, 24)
      btn._mouseOver = false
      btn:Trigger("OnMouseUp")
      -- default alpha is 0.45 from BG_SECONDARY ACCENT_BLUE
      Assert.True(btn._backdropColor[4] ~= 0.8, "no mouse-over OnMouseUp must show default alpha")
    end)
  end)

  -- AttachPanelButtonTooltip ---------------------------------------------------

  -- Helper: install AnchorRosterHoverTooltip / HideRosterHoverTooltip
  -- stubs *before* chrome.lua executes so its local upvalues bind to
  -- our stubs. Returns the loaded addon table.
  local function LoadChromeWithTooltipStubs(stubs)
    local addon = LoadAddonModules({ "isiLive_roster_panel_helpers.lua" })
    addon._RosterInternal.AnchorRosterHoverTooltip = stubs.anchor
    addon._RosterInternal.HideRosterHoverTooltip = stubs.hide
    -- Manually execute chrome.lua so the upvalue capture sees the stubs.
    local chunk = assert(loadfile("ui/isiLive_roster_panel_chrome.lua"))
    chunk("isiLive", addon)
    return addon
  end

  test("AttachPanelButtonTooltip OnEnter renders title + description + lead-required hint", function()
    WithGlobals(MinimalGlobals(), function()
      local tooltipCalls = { setText = nil, lines = {} }
      local tooltip = {
        SetText = function(_, text)
          tooltipCalls.setText = text
        end,
        AddLine = function(_, line)
          table.insert(tooltipCalls.lines, line)
        end,
        Show = function()
          tooltipCalls.shown = true
        end,
      }
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return tooltip
        end,
        hide = function() end,
      })

      local btn = NewBackdropFrame()
      addon._RosterInternal.AttachPanelButtonTooltip(
        nil,
        btn,
        function()
          return {
            HEADER_KEY = "Header",
            DESC_KEY = "Description",
            TOOLTIP_LEAD_REQUIRED = "Leader required",
          }
        end,
        "HEADER_KEY",
        "DESC_KEY",
        function()
          return false -- not leader -> add the leader hint
        end
      )
      btn:Trigger("OnEnter")
      Assert.Equal(tooltipCalls.setText, "Header", "title text must be set")
      Assert.Equal(tooltipCalls.lines[1], "Description", "description line must be added")
      Assert.Equal(tooltipCalls.lines[2], "Leader required", "leader-required hint must be shown when not leader")
    end)
  end)

  test("AttachPanelButtonTooltip OnEnter skips lead hint when player is leader", function()
    WithGlobals(MinimalGlobals(), function()
      local tooltip = {}
      tooltip.SetText = function() end
      tooltip.AddLine = function(_, line)
        tooltip._lines = tooltip._lines or {}
        table.insert(tooltip._lines, line)
      end
      tooltip.Show = function() end
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return tooltip
        end,
        hide = function() end,
      })

      local btn = NewBackdropFrame()
      addon._RosterInternal.AttachPanelButtonTooltip(
        nil,
        btn,
        function()
          return { TITLE = "T", DESC = "D", TOOLTIP_LEAD_REQUIRED = "Lead!" }
        end,
        "TITLE",
        "DESC",
        function()
          return true -- is leader
        end
      )
      btn:Trigger("OnEnter")
      Assert.Equal(#(tooltip._lines or {}), 1, "leader must only see the description line")
    end)
  end)

  test("AttachPanelButtonTooltip OnEnter aborts when AnchorRosterHoverTooltip yields non-table", function()
    WithGlobals(MinimalGlobals(), function()
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return nil
        end,
        hide = function() end,
      })
      local btn = NewBackdropFrame()
      addon._RosterInternal.AttachPanelButtonTooltip(
        nil,
        btn,
        function()
          return {}
        end,
        "T",
        "D",
        function()
          return true
        end
      )
      btn:Trigger("OnEnter") -- must not throw
    end)
  end)

  test("AttachPanelButtonTooltip OnLeave invokes HideRosterHoverTooltip", function()
    WithGlobals(MinimalGlobals(), function()
      local hideCalls = 0
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return nil
        end,
        hide = function()
          hideCalls = hideCalls + 1
        end,
      })
      local btn = NewBackdropFrame()
      addon._RosterInternal.AttachPanelButtonTooltip(nil, btn, function()
        return {}
      end, "T", "D", nil)
      btn:Trigger("OnLeave")
      Assert.Equal(hideCalls, 1, "OnLeave must call HideRosterHoverTooltip")
    end)
  end)

  -- AttachModeButtonTooltip ---------------------------------------------------

  test("AttachModeButtonTooltip OnEnter prefers locale strings over fallbacks", function()
    WithGlobals(MinimalGlobals(), function()
      local tooltip = {
        _lines = {},
        SetText = function(self, text)
          self._title = text
        end,
        AddLine = function(self, line)
          table.insert(self._lines, line)
        end,
        Show = function() end,
      }
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return tooltip
        end,
        hide = function() end,
      })
      local btn = NewBackdropFrame()
      addon._RosterInternal.AttachModeButtonTooltip(nil, btn, function()
        return { DESC = "Loc desc", HINT = "Loc hint" }
      end, "Mode title", "DESC", "fallback desc", "HINT", "fallback hint")
      btn:Trigger("OnEnter")
      Assert.Equal(tooltip._title, "Mode title", "title must be passed through verbatim")
      Assert.Equal(tooltip._lines[1], "Loc desc", "locale description must win over fallback")
      Assert.Equal(tooltip._lines[2], "Loc hint", "locale hint must win over fallback")
    end)
  end)

  test("AttachModeButtonTooltip OnEnter falls back to provided fallbacks when locale strings are missing", function()
    WithGlobals(MinimalGlobals(), function()
      local tooltip = {
        _lines = {},
        SetText = function() end,
        AddLine = function(self, line)
          table.insert(self._lines, line)
        end,
        Show = function() end,
      }
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return tooltip
        end,
        hide = function() end,
      })
      local btn = NewBackdropFrame()
      addon._RosterInternal.AttachModeButtonTooltip(nil, btn, function()
        return {} -- no locale strings
      end, "Title", "DESC_KEY", "Fallback desc", "HINT_KEY", "Fallback hint")
      btn:Trigger("OnEnter")
      Assert.Equal(tooltip._lines[1], "Fallback desc", "fallback description must be used")
      Assert.Equal(tooltip._lines[2], "Fallback hint", "fallback hint must be used")
    end)
  end)

  test("AttachModeButtonTooltip OnLeave invokes HideRosterHoverTooltip", function()
    WithGlobals(MinimalGlobals(), function()
      local hideCalls = 0
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return nil
        end,
        hide = function()
          hideCalls = hideCalls + 1
        end,
      })
      local btn = NewBackdropFrame()
      addon._RosterInternal.AttachModeButtonTooltip(nil, btn, function()
        return {}
      end, "T", "D", "fd", "C", "fc")
      btn:Trigger("OnLeave")
      Assert.Equal(hideCalls, 1, "OnLeave must call HideRosterHoverTooltip")
    end)
  end)

  test("AttachModeButtonTooltip OnEnter renders an optional lock-reason line between description and hint", function()
    WithGlobals(MinimalGlobals(), function()
      local tooltip = {
        _lines = {},
        SetText = function() end,
        AddLine = function(self, line)
          table.insert(self._lines, line)
        end,
        Show = function() end,
      }
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return tooltip
        end,
        hide = function() end,
      })
      local btn = NewBackdropFrame()
      addon._RosterInternal.AttachModeButtonTooltip(
        nil,
        btn,
        function()
          return {}
        end,
        "T",
        "D",
        "desc",
        "C",
        "hint",
        function()
          return "raid lock notice"
        end
      )
      btn:Trigger("OnEnter")
      Assert.Equal(tooltip._lines[1], "desc", "description line stays first")
      Assert.Equal(tooltip._lines[2], "raid lock notice", "lock reason line sits between description and click hint")
      Assert.Equal(tooltip._lines[3], "hint", "click hint stays last")
    end)
  end)

  test("AttachModeButtonTooltip OnEnter skips lock-reason line when callback returns nil", function()
    WithGlobals(MinimalGlobals(), function()
      local tooltip = {
        _lines = {},
        SetText = function() end,
        AddLine = function(self, line)
          table.insert(self._lines, line)
        end,
        Show = function() end,
      }
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return tooltip
        end,
        hide = function() end,
      })
      local btn = NewBackdropFrame()
      addon._RosterInternal.AttachModeButtonTooltip(
        nil,
        btn,
        function()
          return {}
        end,
        "T",
        "D",
        "desc",
        "C",
        "hint",
        function()
          return nil
        end
      )
      btn:Trigger("OnEnter")
      Assert.Equal(#tooltip._lines, 2, "no lock-reason line should be emitted when the callback returns nil")
      Assert.Equal(tooltip._lines[1], "desc", "description line still emitted")
      Assert.Equal(tooltip._lines[2], "hint", "click hint still emitted")
    end)
  end)

  -- CreateTankHelperButtons OnEnter / OnLeave for one of the marker buttons ---

  test("CreateTankHelperButtons attaches hover tooltips that render marker name and click hints", function()
    WithGlobals(MinimalGlobals(), function()
      local tooltip = {
        _lines = {},
        SetText = function(self, text)
          self._title = text
        end,
        AddLine = function(self, line)
          table.insert(self._lines, line)
        end,
        Show = function() end,
      }
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return tooltip
        end,
        hide = function() end,
      })
      local mainFrame = NewLooseFrame()
      local buttons = addon._RosterInternal.CreateTankHelperButtons(mainFrame, nil, function()
        return {
          TANK_HELPER_HEADER = "Tank Helper",
          TOOLTIP_WORLDMARKER_TITLE_FMT = "Marker: %s",
          TOOLTIP_WORLDMARKER_LCLICK = "L",
          TOOLTIP_WORLDMARKER_RCLICK = "R",
        }
      end)
      Assert.True(#buttons >= 1, "CreateTankHelperButtons must produce buttons")
      buttons[1]:Trigger("OnEnter")
      Assert.Equal(tooltip._title, "Marker: Square (Blue)", "marker name must format into title")
      Assert.Equal(tooltip._lines[1], "L", "left-click hint line")
      Assert.Equal(tooltip._lines[2], "R", "right-click hint line")
    end)
  end)

  test("CreateTankHelperButtons uses client marker names and a cool hover highlight", function()
    local globals = MinimalGlobals()
    globals.RAID_TARGET_6 = "Viereck"
    globals.RAID_TARGET_8 = "Totenschaedel"
    WithGlobals(globals, function()
      local tooltip = {
        _lines = {},
        SetText = function(self, text)
          self._title = text
        end,
        AddLine = function(self, line)
          table.insert(self._lines, line)
        end,
        Show = function() end,
      }
      local addon = LoadChromeWithTooltipStubs({
        anchor = function()
          return tooltip
        end,
        hide = function() end,
      })
      local buttons = addon._RosterInternal.CreateTankHelperButtons(NewLooseFrame(), nil, function()
        return { TOOLTIP_WORLDMARKER_TITLE_FMT = "Marker: %s" }
      end)

      buttons[1]:Trigger("OnEnter")
      Assert.Equal(tooltip._title, "Marker: Viereck", "square marker must use the client's RAID_TARGET_6 name")
      buttons[8]:Trigger("OnEnter")
      Assert.Equal(tooltip._title, "Marker: Totenschaedel", "skull marker must use the client's RAID_TARGET_8 name")
      buttons[5]:Trigger("OnEnter")
      Assert.Equal(tooltip._title, "Marker: Star (Yellow)", "a missing client name must fall back to English")

      Assert.Equal(
        buttons[1]._normalPath,
        "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6",
        "square marker must keep its raid-target icon"
      )
      Assert.Equal(buttons[1]._highlightPath, "Interface\\Buttons\\WHITE8X8", "marker buttons must get a hover texture")
      local highlight = buttons[1]:GetHighlightTexture()
      Assert.Equal(highlight._blendMode, "ADD", "marker hover must blend softly")
      -- BLUE_HOVER_GLOW = { 0.3, 0.65, 1, 0.2 }: cool, translucent, never gold.
      Assert.Equal(highlight._color[1], 0.3, "marker hover must use the cool hover red channel")
      Assert.Equal(highlight._color[3], 1, "marker hover must be blue-dominant")
      Assert.Equal(highlight._color[4], 0.2, "marker hover must stay translucent")
    end)
  end)
end
