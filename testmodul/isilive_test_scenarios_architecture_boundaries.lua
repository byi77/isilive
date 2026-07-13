local ioLib = rawget(_G, "io")

local function ReadFile(path)
  local file, err = ioLib.open(path, "rb")
  if not file then
    error(string.format("cannot read %s: %s", tostring(path), tostring(err)))
  end
  local content = file:read("*a")
  file:close()
  return content or ""
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Architecture large-module watchlist is documented and gate-pinned", function()
    local architecture = ReadFile("docs/ARCHITECTURE.md")
    local metrics = ReadFile("tools/lua_metrics_check.lua")
    local expected = {
      "ui/isiLive_lfg_flags.lua",
      "logic/isiLive_sync.lua",
      "ui/isiLive_notice.lua",
      "ui/isiLive_ui_game_menu.lua",
      "game/isiLive_lfg_detect.lua",
      "core/isiLive_sound_utils.lua",
    }
    Assert.True(architecture:find("## Architektur-Refactoring-Watchlist", 1, true) ~= nil, "watchlist required")
    for _, path in ipairs(expected) do
      Assert.True(architecture:find("`" .. path .. "`", 1, true) ~= nil, path .. " must be documented")
    end
    Assert.True(metrics:find('read_file("docs/ARCHITECTURE.md")', 1, true) ~= nil, "metrics must read watchlist")
    Assert.True(metrics:find("watchlist missing", 1, true) ~= nil, "metrics must fail for missing entries")
  end)

  test("Architecture production layers do not consume private roster UI registry", function()
    local consumers = {
      "logic/isiLive_event_handlers_runtime.lua",
      "factory/isiLive_controller_init.lua",
      "factory/isiLive_factory.lua",
      "factory/isiLive_factory_refresh.lua",
      "factory/isiLive_factory_secondary_runtime.lua",
    }
    for _, path in ipairs(consumers) do
      Assert.Nil(ReadFile(path):find("_RosterInternal", 1, true), path .. " must use explicit public APIs")
    end
  end)

  test("Architecture optional WoW globals use guarded rawget caches", function()
    local consumers = {
      ["factory/isiLive_factory_secondary_runtime.lua"] = {
        'rawget(_G, "C_Map")',
        'rawget(_G, "UnitExists")',
      },
      ["logic/isiLive_highlight.lua"] = {
        'rawget(_G, "C_Map")',
        'rawget(_G, "UnitExists")',
      },
      ["logic/isiLive_event_handlers_runtime.lua"] = {
        'rawget(_G, "C_Map")',
        'rawget(_G, "UnitExists")',
        'rawget(_G, "GetInstanceInfo")',
      },
    }
    for path, required in pairs(consumers) do
      local content = ReadFile(path):gsub("%-%-[^\r\n]*", "")
      for _, needle in ipairs(required) do
        Assert.True(content:find(needle, 1, true) ~= nil, path .. " must contain " .. needle)
      end
      Assert.Nil(content:find("C_Map and", 1, true), path .. " must not use bare C_Map chains")
      Assert.Nil(content:find("pcall(UnitExists", 1, true), path .. " must not call bare UnitExists")
      Assert.Nil(content:find("pcall(GetInstanceInfo", 1, true), path .. " must not call bare GetInstanceInfo")
    end
  end)

  test("Architecture CTL wire-order simulator is enforced by local and GitHub CI", function()
    local command = "lua tools/simulate_ctl_wire_order.lua"
    local localPreflight = ReadFile("tools/validate_ci_local.ps1")
    local workflow = ReadFile(".github/workflows/lua-check.yml")
    Assert.True(localPreflight:find(command, 1, true) ~= nil, "local preflight must execute the CTL simulator")
    Assert.True(workflow:find(command, 1, true) ~= nil, "GitHub CI must execute the CTL simulator")
  end)

  test("Architecture factory does not publish mutable composition context", function()
    local content = ReadFile("factory/isiLive_factory.lua")
    Assert.Nil(content:find("tbl._factoryCtx", 1, true), "factory context must not escape through addonTable")
    Assert.True(content:find("testOptions.returnContext == true", 1, true) ~= nil, "test introspection must be opt-in")
    Assert.True(content:find("return true", 1, true) ~= nil, "production composition must return only success")
  end)

  test("Architecture season manifest is the only manually maintained runtime season source", function()
    local toc = ReadFile("isiLive.toc")
    local seasonData = ReadFile("game/isiLive_season_data.lua")
    local lfgDetect = ReadFile("game/isiLive_lfg_detect.lua")
    local status = ReadFile("ui/isiLive_status.lua")
    local forcesTool = ReadFile("tools/sync_mdt_forces.lua")
    Assert.True(toc:find("data/isiLive_seasons.lua", 1, true) ~= nil, "TOC must load the season manifest")
    Assert.True(seasonData:find("addonTable.SeasonManifest", 1, true) ~= nil, "SeasonData must compile it")
    Assert.True(lfgDetect:find("seasonData.GetMapIDByActivityID(numID)", 1, true) ~= nil, "LFG must use it")
    Assert.Nil(lfgDetect:find("[1542] = 557", 1, true), "LFG must not duplicate season activity ids")
    Assert.True(status:find("seasonData.GetPortalNavigatorConfig()", 1, true) ~= nil, "status must use it")
    Assert.True(forcesTool:find("season.mdtDirectory", 1, true) ~= nil, "MDT tooling must use it")
    Assert.Nil(forcesTool:find("SEASON_TO_MDT_DIR", 1, true), "MDT tooling must not duplicate seasons")
  end)
end
