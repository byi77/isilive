---@diagnostic disable: undefined-global
return function(test, ctx)
  local Assert = ctx.assert
  local WithGlobals = ctx.with_globals
  local LoadAddonModules = ctx.load_modules

  test("EventUtils detects negative status strings", function()
    local addon = LoadAddonModules({ "isiLive_event_utils.lua" })

    Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue("declined"), "declined must be negative")
    Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue("cancelled"), "cancelled must be negative")
    Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue("failed"), "failed must be negative")
    Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue("timeout"), "timeout must be negative")
    Assert.True(
      addon.EventUtils.IsNegativeApplicationStatusValue("InviteDeclined"),
      "InviteDeclined must be negative (mixed case)"
    )
  end)

  test("EventUtils detects negative status enums", function()
    WithGlobals({
      Enum = {
        LFGListApplicationStatus = {
          InviteDeclined = 2,
          Cancelled = 5,
          Failed = 6,
          InviteAccepted = 3,
        },
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_utils.lua" })

      Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue(2), "InviteDeclined enum must be negative")
      Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue(5), "Cancelled enum must be negative")
      Assert.True(addon.EventUtils.IsNegativeApplicationStatusValue(6), "Failed enum must be negative")
    end)
  end)

  test("EventUtils ignores first numeric argument as non-status identifier", function()
    WithGlobals({
      Enum = {
        LFGListApplicationStatus = {
          InviteAccepted = 3,
          InviteDeclined = 2,
        },
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_utils.lua" })

      Assert.False(
        addon.EventUtils.IsNegativeApplicationStatusEvent(
          2,
          Enum.LFGListApplicationStatus.InviteAccepted,
          Enum.LFGListApplicationStatus.InviteAccepted
        ),
        "first numeric argument should be treated as identifier, not status"
      )
      Assert.True(
        addon.EventUtils.IsNegativeApplicationStatusEvent(
          9999,
          Enum.LFGListApplicationStatus.InviteDeclined,
          Enum.LFGListApplicationStatus.InviteAccepted
        ),
        "negative numeric status in later argument must still be detected"
      )
    end)
  end)

  test("EventUtils returns false for positive status events", function()
    WithGlobals({
      Enum = {
        LFGListApplicationStatus = {
          InviteAccepted = 3,
          Applied = 1,
        },
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_event_utils.lua" })

      Assert.False(addon.EventUtils.IsNegativeApplicationStatusValue("invited"), "invited must not be negative")
      Assert.False(addon.EventUtils.IsNegativeApplicationStatusValue("accepted"), "accepted must not be negative")
      Assert.False(addon.EventUtils.IsNegativeApplicationStatusValue(3), "InviteAccepted enum must not be negative")
      Assert.False(addon.EventUtils.IsNegativeApplicationStatusValue(1), "Applied enum must not be negative")
    end)
  end)

  test("EventUtils handles nil and empty arguments without crashing", function()
    local addon = LoadAddonModules({ "isiLive_event_utils.lua" })

    Assert.False(addon.EventUtils.IsNegativeApplicationStatusEvent(), "no arguments should return false")
    Assert.False(addon.EventUtils.IsNegativeApplicationStatusEvent(nil, nil), "nil arguments should return false")
    Assert.False(
      addon.EventUtils.IsNegativeApplicationStatusEvent(42, true, {}),
      "non-string/non-enum arguments should return false"
    )
    Assert.True(
      addon.EventUtils.IsNegativeApplicationStatusEvent(1, "declined", 3),
      "declined at any position should be detected"
    )
  end)
end
