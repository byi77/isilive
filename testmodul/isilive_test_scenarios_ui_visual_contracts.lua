local ioLib = rawget(_G, "io")

local function ReadFile(path)
  local file, err = ioLib.open(path, "rb")
  if not file then
    error(string.format("cannot read %s: %s", path, tostring(err)))
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function AssertContains(Assert, content, needle, message)
  Assert.True(content:find(needle, 1, true) ~= nil, message)
end

return function(test, ctx)
  local Assert = ctx.assert

  test("Architecture M+ title omits beta label while settings retain beta status", function()
    local rosterPanelContent = ReadFile("ui/isiLive_roster_panel.lua")
    local rosterLayoutContent = ReadFile("ui/isiLive_roster_layout.lua")
    local settingsSupportContent = ReadFile("ui/isiLive_settings_support.lua")

    AssertContains(Assert, rosterPanelContent, 'ui.titleHint:SetText("")', "M+ title hint must stay empty")
    AssertContains(
      Assert,
      rosterLayoutContent,
      '{ "titleHint", false, false, false, false }',
      "no main-frame layout may reveal the removed beta title hint"
    )
    AssertContains(
      Assert,
      settingsSupportContent,
      'labels.SETTINGS_BETA_NOTICE or "Beta"',
      "settings must retain the addon's general beta-status notice"
    )
  end)

  test("Architecture M+ title and table separators share horizontal bounds", function()
    local uiCommonContent = ReadFile("ui/isiLive_ui_common.lua")
    local chromeContent = ReadFile("ui/isiLive_roster_panel_chrome.lua")

    AssertContains(
      Assert,
      uiCommonContent,
      'separator:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -(height + 1))',
      "title separator must start at the shared 8 px inset"
    )
    AssertContains(
      Assert,
      uiCommonContent,
      'separator:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -(height + 1))',
      "title separator must end at the shared 8 px inset"
    )
    AssertContains(
      Assert,
      chromeContent,
      'headerSepLeft:SetPoint("TOPLEFT", 8, -48)',
      "table separator must start at the same 8 px inset"
    )
    AssertContains(
      Assert,
      chromeContent,
      'headerSepRight:SetPoint("TOPRIGHT", -8, -48)',
      "table separator must end at the same 8 px inset"
    )
  end)

  test("Architecture release baseline synchronizer targets beta-free M+ title", function()
    local syncContent = ReadFile("tools/sync_release_baseline.ps1")

    AssertContains(
      Assert,
      syncContent,
      "(\\s+Open/Close CTRL-F9\\b)",
      "release baseline sync must target the beta-free architecture title"
    )
    Assert.True(
      syncContent:find("\\s+BETA\\s+Open/Close", 1, true) == nil,
      "release baseline sync must not require the removed beta label"
    )
  end)
end
