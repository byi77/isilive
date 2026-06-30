---@diagnostic disable: undefined-global

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules
  local WithGlobals = ctx.with_globals

  test("HearthstoneDebug dump fails closed when toy APIs are unavailable", function()
    local addon = LoadAddonModules({ "isiLive_ui_game_menu_travel.lua", "isiLive_hearthstone_debug.lua" })
    local lines = addon.HearthstoneDebug.BuildDumpLines()
    Assert.True(#lines > 1, "dump must include known static hearthstone toys")
    local joined = table.concat(lines, "\n")
    Assert.True(joined:find("knownToyCount=", 1, true) ~= nil, "dump must include known toy count")
    Assert.True(joined:find("ownedSource=unavailable", 1, true) ~= nil, "missing PlayerHasToy must be surfaced")
    Assert.True(joined:find("infoSource=unavailable", 1, true) ~= nil, "missing C_ToyBox must be surfaced")
  end)

  test("HearthstoneDebug dump prints observed ownership and ToyBox names", function()
    local joined = nil
    WithGlobals({
      PlayerHasToy = function(toyID)
        return toyID == 54452
      end,
      C_ToyBox = {
        GetToyInfo = function(toyID)
          if toyID == 54452 then
            return toyID, "Ethereal Portal", "Interface\\Icons\\spell_arcane_portalstormwind"
          end
          return toyID, nil, nil
        end,
      },
    }, function()
      local addon = LoadAddonModules({ "isiLive_ui_game_menu_travel.lua", "isiLive_hearthstone_debug.lua" })
      joined = table.concat(addon.HearthstoneDebug.BuildDumpLines(), "\n")
    end)
    Assert.True(joined:find("toy=54452 owned=true", 1, true) ~= nil, "owned toy must be printed")
    Assert.True(joined:find("name=Ethereal Portal", 1, true) ~= nil, "ToyBox name must be printed")
  end)
end
