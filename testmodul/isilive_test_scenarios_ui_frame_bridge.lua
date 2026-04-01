---@diagnostic disable: undefined-global, need-check-nil

local function RequireValue(value, message)
  if value == nil then
    error(message, 2)
  end
  return value
end

local function RegisterFrameBridgeFollowupTests(test, Assert, WithGlobals, LoadAddonModules)
  test("Frame bridge blocks show requests while raid mode is active", function()
    local visible = false
    local groupShownCalls = 0

    WithGlobals({ UIParent = {} }, function()
      local addon = LoadAddonModules({ "isiLive_frame_bridge.lua" })
      local FrameBridge = RequireValue(addon.FrameBridge, "FrameBridge module should load")

      local context = FrameBridge.CreateContext({
        createCenterNotice = function()
          return {
            frame = {},
            teleportButton = {},
            SetVisible = function() end,
            UpdateTeleportButtonVisual = function() end,
            Show = function() end,
          }
        end,
        createInviteHint = function()
          return { Show = function() end }
        end,
        createMainFrame = function(_opts)
          return {
            frame = {
              IsShown = function()
                return visible
              end,
            },
            SetVisible = function(wantVisible)
              if wantVisible then
                visible = true
                return true
              end
              visible = false
              return true
            end,
            SetHeightSafe = function() end,
            ToggleVisibility = function() end,
          }
        end,
        isInGroup = function()
          return true
        end,
        isRaidGroup = function()
          return true
        end,
        onShownInGroup = function()
          groupShownCalls = groupShownCalls + 1
        end,
        onShownNoGroup = function() end,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return nil
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return nil
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or "")
        end,
        getL = function()
          return {}
        end,
      })

      local didShow = context.SetMainFrameVisible(true)
      Assert.False(didShow, "raid mode must reject frame opens")
      Assert.False(visible, "raid mode must keep the frame hidden")
      Assert.Equal(groupShownCalls, 0, "raid mode must not run group show callbacks")
    end)
  end)

  test("Frame bridge center notice strips dungeon context from runtime calls", function()
    local shownMessage = nil
    local shownDuration = nil
    local shownDungeonName = "sentinel"
    local shownActivityID = "sentinel"
    local shownOptions = nil

    WithGlobals({ UIParent = {} }, function()
      local addon = LoadAddonModules({ "isiLive_frame_bridge.lua" })
      local FrameBridge = RequireValue(addon.FrameBridge, "FrameBridge module should load")

      local context = FrameBridge.CreateContext({
        createCenterNotice = function()
          return {
            frame = {},
            teleportButton = {},
            SetVisible = function() end,
            UpdateTeleportButtonVisual = function() end,
            Show = function(message, durationSeconds, dungeonName, activityID, showOptions)
              shownMessage = message
              shownDuration = durationSeconds
              shownDungeonName = dungeonName
              shownActivityID = activityID
              shownOptions = showOptions
            end,
          }
        end,
        createInviteHint = function()
          return { Show = function() end }
        end,
        createMainFrame = function(_opts)
          return {
            frame = {},
            SetVisible = function()
              return false
            end,
            SetHeightSafe = function() end,
            SetWidthSafe = function() end,
            ToggleVisibility = function() end,
          }
        end,
        isInGroup = function()
          return false
        end,
        onShownInGroup = function() end,
        onShownNoGroup = function() end,
        isInCombat = function()
          return false
        end,
        resolveTeleportSpellID = function()
          return nil
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return 0
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or "")
        end,
        getL = function()
          return {}
        end,
      })

      local showOptions = { persistent = true }
      context.ShowCenterNotice("Queue joined", 20, "The Dawnbreaker", 2662, showOptions)

      Assert.Equal(shownMessage, "Queue joined", "frame bridge should still forward the center notice message")
      Assert.Equal(shownDuration, 20, "frame bridge should still forward the notice duration")
      Assert.Nil(shownDungeonName, "runtime center notice should not receive dungeon detection context")
      Assert.Nil(shownActivityID, "runtime center notice should not receive activity context")
      Assert.Equal(shownOptions, showOptions, "frame bridge should forward generic notice options unchanged")
    end)
  end)

  test("Frame bridge deferred combat opens still run show callbacks after regen", function()
    local visible = false
    local pendingVisible = nil
    local inCombat = true
    local groupShownCalls = 0

    WithGlobals({ UIParent = {} }, function()
      local addon = LoadAddonModules({ "isiLive_frame_bridge.lua" })
      local FrameBridge = RequireValue(addon.FrameBridge, "FrameBridge module should load")

      local context = FrameBridge.CreateContext({
        createCenterNotice = function()
          return {
            frame = {},
            teleportButton = {},
            SetVisible = function() end,
            UpdateTeleportButtonVisual = function() end,
            Show = function() end,
          }
        end,
        createInviteHint = function()
          return { Show = function() end }
        end,
        createMainFrame = function(_opts)
          return {
            frame = {
              IsShown = function()
                return visible
              end,
            },
            SetVisible = function(wantVisible)
              if inCombat then
                pendingVisible = wantVisible and true or false
                return false
              end
              pendingVisible = nil
              if wantVisible then
                if visible then
                  return false
                end
                visible = true
                return true
              end
              visible = false
              return true
            end,
            SetHeightSafe = function() end,
            ToggleVisibility = function() end,
            GetPendingVisible = function()
              return pendingVisible
            end,
          }
        end,
        isInGroup = function()
          return true
        end,
        onShownInGroup = function()
          groupShownCalls = groupShownCalls + 1
        end,
        onShownNoGroup = function() end,
        isInCombat = function()
          return inCombat
        end,
        resolveTeleportSpellID = function()
          return nil
        end,
        applySecureSpellToButton = function() end,
        isSpellKnown = function()
          return true
        end,
        getTeleportCooldownRemaining = function()
          return nil
        end,
        formatCooldownSeconds = function(value)
          return tostring(value or "")
        end,
        getL = function()
          return {}
        end,
      })

      local queuedShow = context.SetMainFrameVisible(true, {
        skipShowCallbacks = true,
      })
      Assert.False(queuedShow, "combat show should stay deferred")
      Assert.Equal(groupShownCalls, 0, "deferred show must not fire callbacks while queued")

      inCombat = false
      local appliedShow = context.SetMainFrameVisible(true)
      Assert.True(appliedShow, "queued show should open after combat")
      Assert.Equal(groupShownCalls, 1, "deferred show should still run the group callback after combat")
    end)
  end)
end

return function(test, ctx)
  local Assert = RequireValue(ctx.assert, "UI frame bridge followup scenario ctx.assert should exist")
  local WithGlobals = RequireValue(ctx.with_globals, "UI frame bridge followup scenario ctx.with_globals should exist")
  local LoadAddonModules =
    RequireValue(ctx.load_modules, "UI frame bridge followup scenario ctx.load_modules should exist")

  RegisterFrameBridgeFollowupTests(test, Assert, WithGlobals, LoadAddonModules)
end
