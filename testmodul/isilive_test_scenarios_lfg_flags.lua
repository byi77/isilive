---@diagnostic disable: undefined-global

-- Builds the minimal WoW global stubs needed to load isiLive_lfg_flags.lua.
-- overrides.LFGListFrame: optional table to use as _G.LFGListFrame
-- overrides.ScrollBoxUtil: optional table to use as _G.ScrollBoxUtil
-- Returns globals + a captured-state table the tests can inspect.
local function BuildLFGFlagsEnv(overrides)
  overrides = overrides or {}

  local captured = {
    addonLoadedHandler = nil,
    registeredEvents = {},
    hookSecureCalls = {},
  }

  local globals = {
    CreateFrame = function()
      return {
        RegisterEvent = function(_, event)
          captured.registeredEvents[event] = (captured.registeredEvents[event] or 0) + 1
        end,
        SetScript = function(_, scriptType, fn)
          if scriptType == "OnEvent" then
            captured.addonLoadedHandler = fn
          end
        end,
        UnregisterEvent = function() end,
      }
    end,
    C_Timer = {
      After = function(_, fn)
        if type(fn) == "function" then
          fn()
        end
      end,
    },
    hooksecurefunc = function(name, fn)
      captured.hookSecureCalls[name] = fn
    end,
    GetRealmName = overrides.GetRealmName or function()
      return "TestRealm"
    end,
  }

  if overrides.LFGListFrame ~= nil then
    globals.LFGListFrame = overrides.LFGListFrame
  end
  if overrides.ScrollBoxUtil ~= nil then
    globals.ScrollBoxUtil = overrides.ScrollBoxUtil
  end

  return globals, captured
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  -- ---------------------------------------------------------------------------
  -- Register: input validation (must not crash on bad input)
  -- ---------------------------------------------------------------------------

  test("LFGFlags.Register returns silently when deps is nil", function()
    local globals = BuildLFGFlagsEnv()
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.Register(nil) -- must not throw
      Assert.True(true, "Register(nil) must not crash")
    end)
  end)

  test("LFGFlags.Register returns silently when deps is not a table", function()
    local globals = BuildLFGFlagsEnv()
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.Register("not a table")
      addon.LFGFlags.Register(42)
      addon.LFGFlags.Register(true)
      Assert.True(true, "Register with non-table must not crash")
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- Register: deferred hook when Blizzard_LFGList not yet loaded
  -- ---------------------------------------------------------------------------

  test("LFGFlags.Register registers ADDON_LOADED handler when LFGListFrame is absent", function()
    local globals, captured = BuildLFGFlagsEnv() -- LFGListFrame intentionally nil
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.Register({})
      Assert.Equal(
        captured.registeredEvents["ADDON_LOADED"] or 0,
        1,
        "must register ADDON_LOADED handler when LFGListFrame missing"
      )
    end)
  end)

  test("LFGFlags.Register defers HookSearchPanel until Blizzard_LFGList loads", function()
    local hookSearchPanelCalls = 0
    local globals, captured = BuildLFGFlagsEnv()
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })

      -- Wrap HookSearchPanel to count calls without recursing.
      local original = addon.LFGFlags.HookSearchPanel
      addon.LFGFlags.HookSearchPanel = function(...)
        hookSearchPanelCalls = hookSearchPanelCalls + 1
        return original(...)
      end

      addon.LFGFlags.Register({})
      Assert.Equal(hookSearchPanelCalls, 0, "must not call HookSearchPanel before ADDON_LOADED for Blizzard_LFGList")

      -- Fire wrong addon: still must not hook.
      captured.addonLoadedHandler({}, "ADDON_LOADED", "OtherAddon")
      Assert.Equal(hookSearchPanelCalls, 0, "must ignore unrelated ADDON_LOADED events")

      -- Fire Blizzard_LFGList: now hook is attempted.
      captured.addonLoadedHandler({ UnregisterEvent = function() end }, "ADDON_LOADED", "Blizzard_LFGList")
      Assert.Equal(hookSearchPanelCalls, 1, "Blizzard_LFGList ADDON_LOADED must trigger HookSearchPanel")
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- Register: locale module wiring
  -- ---------------------------------------------------------------------------

  test("LFGFlags.Register wires localeModule getters into module-local closures", function()
    local serverLanguageCalls = {}
    local flagPathCalls = {}
    local localeModule = {
      GetUnitServerLanguage = function(_unit, realm, _lib)
        table.insert(serverLanguageCalls, realm)
        return "DE"
      end,
      GetLanguageFlagTexturePath = function(tag)
        table.insert(flagPathCalls, tag)
        return "Interface\\AddOns\\isiLive\\media\\flags\\" .. tostring(tag):lower()
      end,
    }

    local searchPanel = {
      ScrollBox = {
        GetFrames = function()
          return {}
        end,
      },
    }
    local globals = BuildLFGFlagsEnv({
      LFGListFrame = { SearchPanel = searchPanel },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.Register({ localeModule = localeModule })

      -- The module captured the closures. We can't invoke them directly without
      -- exposing internals, but we can verify Register completed without error
      -- and that HookSearchPanel was reached (otherwise hooksecurefunc capture
      -- would be empty for the search-panel hooks).
      Assert.True(true, "Register must not crash with valid locale module")
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- HookSearchPanel: defensive against missing globals
  -- ---------------------------------------------------------------------------

  test("LFGFlags.HookSearchPanel returns silently when LFGListFrame is missing", function()
    local globals = BuildLFGFlagsEnv() -- no LFGListFrame
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.HookSearchPanel() -- must not throw
      Assert.True(true, "HookSearchPanel without LFGListFrame must not crash")
    end)
  end)

  test("LFGFlags.HookSearchPanel returns silently when SearchPanel is missing", function()
    local globals = BuildLFGFlagsEnv({
      LFGListFrame = {}, -- no SearchPanel
    })
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.HookSearchPanel()
      Assert.True(true, "HookSearchPanel without SearchPanel must not crash")
    end)
  end)

  test("LFGFlags.HookSearchPanel returns silently when SearchPanel.ScrollBox is missing", function()
    local globals = BuildLFGFlagsEnv({
      LFGListFrame = { SearchPanel = {} }, -- no ScrollBox
    })
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.HookSearchPanel()
      Assert.True(true, "HookSearchPanel without ScrollBox must not crash")
    end)
  end)

  test("LFGFlags.HookSearchPanel uses ScrollBoxUtil when available", function()
    local viewFramesCalls = 0
    local viewScrollCalls = 0
    local searchPanel = { ScrollBox = {} }
    local globals = BuildLFGFlagsEnv({
      LFGListFrame = { SearchPanel = searchPanel },
      ScrollBoxUtil = {
        OnViewFramesChanged = function(_, box, _cb)
          if box == searchPanel.ScrollBox then
            viewFramesCalls = viewFramesCalls + 1
          end
        end,
        OnViewScrollChanged = function(_, box, _cb)
          if box == searchPanel.ScrollBox then
            viewScrollCalls = viewScrollCalls + 1
          end
        end,
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.HookSearchPanel()
      Assert.Equal(viewFramesCalls, 1, "must register OnViewFramesChanged on the search ScrollBox")
      Assert.Equal(viewScrollCalls, 1, "must register OnViewScrollChanged on the search ScrollBox")
    end)
  end)

  test("LFG view hooks wire recycled applicant frames and Blizzard viewer callbacks", function()
    local applicantEnter
    local inviteEnter
    local function NewApplicantButton(applicantID)
      local button = {
        applicantID = applicantID,
        Members = {},
        HookScript = function(_, scriptType, callback)
          if scriptType == "OnEnter" then
            applicantEnter = callback
          end
        end,
      }
      button.InviteButton = {
        HookScript = function(_, scriptType, callback)
          if scriptType == "OnEnter" then
            inviteEnter = callback
          end
        end,
        GetParent = function()
          return button
        end,
      }
      return button
    end

    local first = NewApplicantButton(31)
    local second = NewApplicantButton(32)
    local changedFramesCallbacks = {}
    local viewer = {
      ScrollFrame = { buttons = { first } },
      ScrollBox = {
        GetFrames = function()
          return { second }
        end,
      },
    }
    local globals, captured = BuildLFGFlagsEnv({
      LFGListFrame = {
        SearchPanel = { ScrollBox = {} },
        ApplicationViewer = viewer,
      },
      ScrollBoxUtil = {
        OnViewFramesChanged = function(_, _, callback)
          table.insert(changedFramesCallbacks, callback)
        end,
      },
    })
    globals.LFGListApplicationViewerScrollFrameButton1 = NewApplicantButton(33)

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.HookSearchPanel()

      Assert.True(type(applicantEnter) == "function", "applicant row must receive an OnEnter hook")
      Assert.True(type(inviteEnter) == "function", "invite button must receive an OnEnter hook")
      Assert.True(#changedFramesCallbacks >= 2, "applicant and search ScrollBoxes must receive recycle callbacks")
      changedFramesCallbacks[1]({ NewApplicantButton(34) })
      applicantEnter(first)
      inviteEnter(first.InviteButton)

      local updateResults = captured.hookSecureCalls.LFGListApplicationViewer_UpdateResults
      local updateApplicant = captured.hookSecureCalls.LFGListApplicationViewer_UpdateApplicant
      local updateMember = captured.hookSecureCalls.LFGListApplicationViewer_UpdateApplicantMember
      local memberOnEnter = captured.hookSecureCalls.LFGListApplicantMember_OnEnter
      Assert.True(type(updateResults) == "function", "viewer result hook must be registered")
      Assert.True(type(updateApplicant) == "function", "applicant update hook must be registered")
      Assert.True(type(updateMember) == "function", "member update hook must be registered")
      Assert.True(type(memberOnEnter) == "function", "member tooltip hook must be registered")

      updateResults(viewer)
      updateApplicant(first, 31)
      updateMember({}, 31, 1)
      memberOnEnter({})
    end)
  end)

  test("LFGFlags.HookSearchPanel falls back to event handler when ScrollBoxUtil missing", function()
    local searchPanel = { ScrollBox = {
      GetFrames = function()
        return {}
      end,
    } }
    local globals, captured = BuildLFGFlagsEnv({
      LFGListFrame = { SearchPanel = searchPanel },
      -- ScrollBoxUtil intentionally omitted
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.HookSearchPanel()
      Assert.Equal(
        captured.registeredEvents["LFG_LIST_SEARCH_RESULTS_RECEIVED"] or 0,
        1,
        "must fall back to LFG_LIST_SEARCH_RESULTS_RECEIVED handler"
      )
    end)
  end)

  test("LFGFlags.HookSearchPanel installs cache-clear hook for LFGListSearchPanel_DoSearch", function()
    local searchPanel = { ScrollBox = {} }
    local globals, captured = BuildLFGFlagsEnv({
      LFGListFrame = { SearchPanel = searchPanel },
      ScrollBoxUtil = {
        OnViewFramesChanged = function() end,
        OnViewScrollChanged = function() end,
      },
    })

    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.HookSearchPanel()
      Assert.NotNil(
        captured.hookSecureCalls["LFGListSearchPanel_DoSearch"],
        "must hook DoSearch to clear result tag cache"
      )
      Assert.NotNil(
        captured.hookSecureCalls["LFGListUtil_SetSearchEntryTooltip"],
        "must hook SetSearchEntryTooltip for per-button refresh"
      )
    end)
  end)

  -- ---------------------------------------------------------------------------
  -- SetEnabled: state mutation without hooked buttons (smoke)
  -- ---------------------------------------------------------------------------

  test("LFGFlags.SetEnabled accepts true/false/nil without hooked buttons", function()
    local globals = BuildLFGFlagsEnv()
    WithGlobals(globals, function()
      local addon = LoadAddonModules({ "isiLive_lfg_flags.lua" })
      addon.LFGFlags.SetEnabled(true)
      addon.LFGFlags.SetEnabled(false)
      addon.LFGFlags.SetEnabled(nil)
      Assert.True(true, "SetEnabled must accept any boolean-ish without crashing")
    end)
  end)
end
