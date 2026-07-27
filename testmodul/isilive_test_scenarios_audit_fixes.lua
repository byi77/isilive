---@diagnostic disable: undefined-global

local function ReadFile(path)
  local file = assert(io.open(path, "rb"))
  local content = file:read("*a")
  file:close()
  return content
end

local function Contains(content, needle)
  return type(content) == "string" and content:find(needle, 1, true) ~= nil
end

return function(test, ctx)
  local Assert = ctx.assert
  local LoadAddonModules = ctx.load_modules

  test("Architecture M+ forces workflow records exact source commit", function()
    local workflow = ReadFile(".github/workflows/sync-mplus-forces.yml")
    Assert.True(
      Contains(workflow, "git -C tools/cache/mdt rev-parse HEAD"),
      "M+ forces sync must resolve the exact checked-out MDT commit"
    )
    Assert.True(
      Contains(workflow, '"--source_commit=${MDT_SOURCE_COMMIT}"'),
      "M+ forces sync must pass exact upstream provenance into the generator"
    )
  end)

  test("Architecture coverage reports reject unreadable source warnings", function()
    local workflow = ReadFile(".github/workflows/lua-check.yml")
    local localPreflight = ReadFile("tools/validate_ci_local.ps1")
    Assert.True(
      Contains(localPreflight, "Invoke-LuaCovReport"),
      "local coverage reporting must use the warning-aware LuaCov launcher"
    )
    Assert.True(
      Contains(localPreflight, "Coverage Report encountered an unreadable source file."),
      "local coverage reporting must fail on unreadable-source warnings"
    )
    Assert.True(
      Contains(workflow, "LuaCov reported an unreadable source file."),
      "GitHub coverage reporting must fail on unreadable-source warnings"
    )
  end)

  test("SoundRegistry owns static sound entries before SoundUtils playback loads", function()
    local addon = LoadAddonModules({ "isiLive_sound_utils.lua" })
    Assert.NotNil(addon.SoundRegistry, "the static sound registry module must load before SoundUtils")
    Assert.Equal(
      addon.SoundUtils.Registry,
      addon.SoundRegistry.Registry,
      "SoundUtils must consume the separately owned static registry"
    )
    Assert.Equal(
      addon.SoundUtils.SettingsOrder,
      addon.SoundRegistry.SettingsOrder,
      "SoundUtils must consume the separately owned settings order"
    )
    Assert.NotNil(
      addon.SoundUtils.GetEntry("ready_check_complete"),
      "the extracted registry must preserve existing public sound lookup behavior"
    )
  end)
end
