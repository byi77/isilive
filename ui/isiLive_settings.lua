local _, addonTable = ...
addonTable = addonTable or {}
local SettingsPanel = {}
addonTable.SettingsPanel = SettingsPanel
local Colors = addonTable.UICommon and addonTable.UICommon.Colors or {}
local ApplyBackdrop = addonTable.UICommon and addonTable.UICommon.ApplyBackdrop
local PADDING_X = 16
local PADDING_TOP = 16
local SECTION_GAP = 22
local SETTINGS_SCROLL_STEP = 32
local SETTINGS_CONTENT_WIDTH = 700
local ISILIVE_BRAND_TITLE = "isi|cff1e90ffLive|r"
local CreateSettingsIntro = addonTable.SettingsControls.CreateSettingsIntro
local BuildGeneralSettingsSection = addonTable.SettingsSections.BuildGeneralSection
local BuildDisplaySettingsSection = addonTable.SettingsSections.BuildDisplaySection
local RefreshGeneralControls = addonTable.SettingsSections.RefreshGeneralControls
local RefreshDisplayControls = addonTable.SettingsSections.RefreshDisplayControls
local BuildNameplatesSettingsSection = addonTable.SettingsNameplates.BuildSection
local BuildBehaviorSettingsSection = addonTable.SettingsBehavior.BuildSection
local RefreshBehaviorControls = addonTable.SettingsBehavior.RefreshControls
local BuildSoundSettingsSection = addonTable.SettingsSound.BuildSoundSection
local BuildVIPGuestSettingsSection = addonTable.SettingsSound.BuildVIPGuestSection
local RefreshSoundControls = addonTable.SettingsSound.RefreshSoundControls
local RefreshVIPGuestControls = addonTable.SettingsSound.RefreshVIPGuestControls
local BuildChatSettingsSection = addonTable.SettingsSupport.BuildChatSection
local BuildDebugSettingsSection = addonTable.SettingsSupport.BuildDebugSection
local BuildResetSection = addonTable.SettingsSupport.BuildResetSection
local BuildBetaSection = addonTable.SettingsSupport.BuildBetaSection
local RefreshSupportControls = addonTable.SettingsSupport.RefreshControls

local function ApplySettingsBackdrop(frame)
  if type(ApplyBackdrop) == "function" then
    ApplyBackdrop(frame, "PRIMARY")
  end
end

local function CreateSettingsTitle(canvas)
  local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  -- Accent-gold baseline so the plain `isi` prefix in ISILIVE_BRAND_TITLE
  -- renders in the historical brand color. The `Live` segment overrides
  -- this default via its embedded |cff1e90ff...|r color code.
  local ag = Colors.ACCENT_GOLD or { 1, 0.82, 0 }
  title:SetTextColor(ag[1], ag[2], ag[3], 1)
  title:SetPoint("TOPLEFT", canvas, "TOPLEFT", PADDING_X, -PADDING_TOP)
  title:SetText(ISILIVE_BRAND_TITLE)

  return title
end

local function ResolveSettingsOptions(opts)
  opts = opts or {}

  return {
    getL = type(opts.getL) == "function" and opts.getL or function()
      return {}
    end,
    setLanguage = opts.setLanguage,
    getCurrentLocale = opts.getCurrentLocale,
    getDB = type(opts.getDB) == "function" and opts.getDB or function()
      return {}
    end,
    onEscPanelToggle = opts.onEscPanelToggle,
    onBgAlphaChange = opts.onBgAlphaChange,
    onStatsBoxToggle = opts.onStatsBoxToggle,
    onStatsBoxLockToggle = opts.onStatsBoxLockToggle,
    onStatsBoxBgAlphaChange = opts.onStatsBoxBgAlphaChange,
    onStatsBoxFontSizeOffsetChange = opts.onStatsBoxFontSizeOffsetChange,
    onStatsBoxOptionsChange = opts.onStatsBoxOptionsChange,
    onUiScaleChange = opts.onUiScaleChange,
    onSyncToggle = opts.onSyncToggle,
    onMinimapButtonToggle = opts.onMinimapButtonToggle,
    onAutoOpenQueueToggle = opts.onAutoOpenQueueToggle,
    onAutoCloseOnKeyStartToggle = opts.onAutoCloseOnKeyStartToggle,
    onAutoCloseOnSoloChangeToggle = opts.onAutoCloseOnSoloChangeToggle,
    onMainFramePositionLockToggle = opts.onMainFramePositionLockToggle,
    onCombatFadeMMToggle = opts.onCombatFadeMMToggle,
    onAutoShowMainFrameOnStartupToggle = opts.onAutoShowMainFrameOnStartupToggle,
    onAutoOpenMainFrameOnKeyEndToggle = opts.onAutoOpenMainFrameOnKeyEndToggle,
    onRaidTransitionBehaviorChange = opts.onRaidTransitionBehaviorChange,
    onPortalNavigatorToggle = opts.onPortalNavigatorToggle,
    onDefaultLayoutModeChange = opts.onDefaultLayoutModeChange,
    onNameMaxCharsChange = opts.onNameMaxCharsChange,
    onRosterColumnGuidesToggle = opts.onRosterColumnGuidesToggle,
    onTeleportColumnsChange = opts.onTeleportColumnsChange,
    getQueueDebugEnabled = opts.getQueueDebugEnabled,
    onQueueDebugToggle = opts.onQueueDebugToggle,
    getRuntimeLogEnabled = opts.getRuntimeLogEnabled,
    onRuntimeLogToggle = opts.onRuntimeLogToggle,
    onClearRuntimeLog = opts.onClearRuntimeLog,
    onClearQueueDebugLog = opts.onClearQueueDebugLog,
    onLfgFlagsToggle = opts.onLfgFlagsToggle,
    onLfgGroupBonusesToggle = opts.onLfgGroupBonusesToggle,
    onTooltipFlagsToggle = opts.onTooltipFlagsToggle,
    onMplusForcesToggle = opts.onMplusForcesToggle,
    onMobNameplateChange = opts.onMobNameplateChange,
    onResetDB = opts.onResetDB,
    onResetMainFramePosition = opts.onResetMainFramePosition,
    onHearthstoneChoiceChange = opts.onHearthstoneChoiceChange,
  }
end

local function RefreshSettingsControls(controls, config)
  local freshL = config.getL()
  local db = config.getDB()
  local function SetLocalizedText(control, key, fallback)
    if control and type(control.SetText) == "function" then
      control:SetText(freshL[key] or fallback)
    end
  end
  local function SetDescription(control, key, fallback)
    if type(control) == "table" and control.description and type(control.description.SetText) == "function" then
      control.description:SetText(freshL[key] or fallback or "")
    end
  end

  SetLocalizedText(
    controls.introText,
    "SETTINGS_PAGE_HINT",
    "Use the sections below to tune layout, behavior, and audio cues."
  )
  RefreshGeneralControls(controls, freshL, db, config)
  RefreshDisplayControls(controls, freshL, db, config)
  SetLocalizedText(controls.nameplatesHeader, "SETTINGS_SECTION_NAMEPLATES", "Nameplates")
  SetLocalizedText(
    controls.nameplatesHint,
    "SETTINGS_SECTION_NAMEPLATES_HINT",
    "Enemy forces overlay on Mythic+ nameplates."
  )
  SetLocalizedText(
    controls.nameplatesExternalWarn,
    "SETTINGS_NAMEPLATE_EXTERNAL_WARN",
    "Plater or Platynator detected: if that addon already shows M+ count, leave this off."
  )
  RefreshBehaviorControls(controls, freshL, db)
  RefreshSoundControls(controls, freshL, db)
  RefreshVIPGuestControls(controls, freshL, db)
  RefreshSupportControls(controls, freshL, db, config)
  if controls.nameplateDisplayMode and type(controls.nameplateDisplayMode.UpdateHighlight) == "function" then
    controls.nameplateDisplayMode.UpdateHighlight()
  end
  if controls.nameplateShowPercent then
    controls.nameplateShowPercent.label:SetText(freshL.SETTINGS_NAMEPLATE_SHOW_PERCENT or "Show percentage")
    SetDescription(
      controls.nameplateShowPercent,
      "SETTINGS_NAMEPLATE_SHOW_PERCENT_DESC",
      "Shows each mob's contribution as a percentage."
    )
    controls.nameplateShowPercent.check:SetChecked(db.mobNameplateShowPercent ~= false)
  end
  if controls.nameplateShowRemaining then
    controls.nameplateShowRemaining.label:SetText(freshL.SETTINGS_NAMEPLATE_SHOW_REMAINING or "Show remaining needed")
    SetDescription(
      controls.nameplateShowRemaining,
      "SETTINGS_NAMEPLATE_SHOW_REMAINING_DESC",
      "Adds the remaining enemy forces needed when live dungeon data is available."
    )
    controls.nameplateShowRemaining.check:SetChecked(db.mobNameplateShowRemaining == true)
  end
  if controls.nameplatePosition and type(controls.nameplatePosition.UpdateHighlight) == "function" then
    controls.nameplatePosition.UpdateHighlight()
  end
  if controls.nameplateFontSize then
    controls.nameplateFontSize.label:SetText(freshL.SETTINGS_NAMEPLATE_FONT_SIZE or "Font size")
    SetDescription(
      controls.nameplateFontSize,
      "SETTINGS_NAMEPLATE_FONT_SIZE_DESC",
      "Adjusts the enemy forces text size on nameplates."
    )
    controls.nameplateFontSize.SetValueSilently(tonumber(db.mobNameplateFontSize) or 14)
  end
  if controls.nameplateXOffset then
    controls.nameplateXOffset.label:SetText(freshL.SETTINGS_NAMEPLATE_X_OFFSET or "X offset")
    SetDescription(
      controls.nameplateXOffset,
      "SETTINGS_NAMEPLATE_X_OFFSET_DESC",
      "Moves the nameplate enemy forces text horizontally."
    )
    controls.nameplateXOffset.SetValueSilently(tonumber(db.mobNameplateXOffset) or 0)
  end
  if controls.nameplateYOffset then
    controls.nameplateYOffset.label:SetText(freshL.SETTINGS_NAMEPLATE_Y_OFFSET or "Y offset")
    SetDescription(
      controls.nameplateYOffset,
      "SETTINGS_NAMEPLATE_Y_OFFSET_DESC",
      "Moves the nameplate enemy forces text vertically."
    )
    controls.nameplateYOffset.SetValueSilently(tonumber(db.mobNameplateYOffset) or 0)
  end
  if controls.nameplatePreviewLabel then
    controls.nameplatePreviewLabel:SetText(freshL.SETTINGS_NAMEPLATE_PREVIEW or "Preview")
  end
  if type(controls.nameplatePreviewUpdate) == "function" then
    controls.nameplatePreviewUpdate()
  end
end

function SettingsPanel.Create(opts)
  local config = ResolveSettingsOptions(opts)

  local blizzardSettings = rawget(_G, "Settings")
  if type(blizzardSettings) ~= "table" or type(blizzardSettings.RegisterCanvasLayoutCategory) ~= "function" then
    return nil
  end

  local canvas = CreateFrame("Frame", nil, rawget(_G, "UIParent"), "BackdropTemplate")
  ApplySettingsBackdrop(canvas)
  local scrollFrame = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", canvas, "TOPLEFT", PADDING_X, -PADDING_TOP)
  scrollFrame:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -PADDING_X, PADDING_TOP)
  if type(scrollFrame.EnableMouseWheel) == "function" then
    scrollFrame:EnableMouseWheel(true)
  end

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
  if type(content.SetWidth) == "function" then
    content:SetWidth(SETTINGS_CONTENT_WIDTH)
  elseif type(content.SetSize) == "function" then
    content:SetSize(SETTINGS_CONTENT_WIDTH, 1)
  end
  if type(scrollFrame.SetScrollChild) == "function" then
    scrollFrame:SetScrollChild(content)
  end

  if type(scrollFrame.SetScript) == "function" then
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
      local currentScroll = type(self.GetVerticalScroll) == "function" and (self:GetVerticalScroll() or 0) or 0
      local maxScroll = type(self.GetVerticalScrollRange) == "function" and (self:GetVerticalScrollRange() or 0) or 0
      local nextScroll = currentScroll - ((tonumber(delta) or 0) * SETTINGS_SCROLL_STEP)
      if nextScroll < 0 then
        nextScroll = 0
      elseif nextScroll > maxScroll then
        nextScroll = maxScroll
      end
      if type(self.SetVerticalScroll) == "function" then
        self:SetVerticalScroll(nextScroll)
      end
    end)
  end

  local itemDataRefreshFrame = CreateFrame("Frame")
  itemDataRefreshFrame:SetScript("OnEvent", function()
    if type(canvas.Refresh) == "function" then
      canvas.Refresh()
    end
  end)
  itemDataRefreshFrame:RegisterEvent("TOYS_UPDATED")
  itemDataRefreshFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

  local L = config.getL()
  local controls = {}

  CreateSettingsTitle(content)

  local y = -PADDING_TOP - 30
  controls.introText, y = CreateSettingsIntro(
    content,
    y,
    L.SETTINGS_PAGE_HINT or "Use the sections below to tune layout, behavior, and audio cues."
  )
  y = BuildBetaSection(content, y, L, controls)
  y = y - SECTION_GAP
  y = BuildGeneralSettingsSection(content, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildDisplaySettingsSection(content, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildNameplatesSettingsSection(content, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildBehaviorSettingsSection(content, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildSoundSettingsSection(content, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildChatSettingsSection(content, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildDebugSettingsSection(content, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildResetSection(content, y, L, config, controls)
  y = y - SECTION_GAP
  y = BuildVIPGuestSettingsSection(content, y, L, config, controls)

  local finalYOffset = tonumber(y) or 0
  local contentHeight = math.max(212, math.ceil(-finalYOffset + PADDING_TOP))
  local contentWidth = type(content.GetWidth) == "function" and content:GetWidth() or SETTINGS_CONTENT_WIDTH
  if type(content.SetSize) == "function" then
    content:SetSize(contentWidth, contentHeight)
  elseif type(content.SetHeight) == "function" then
    content:SetHeight(contentHeight)
  end
  if type(scrollFrame.UpdateScrollChildRect) == "function" then
    scrollFrame:UpdateScrollChildRect()
  end

  local category = blizzardSettings.RegisterCanvasLayoutCategory(canvas, ISILIVE_BRAND_TITLE)
  if type(blizzardSettings.RegisterAddOnCategory) == "function" then
    blizzardSettings.RegisterAddOnCategory(category)
  end

  local function Refresh()
    RefreshSettingsControls(controls, config)
  end
  canvas.Refresh = Refresh

  return {
    category = category,
    canvas = canvas,
    scrollFrame = scrollFrame,
    content = content,
    Refresh = Refresh,
  }
end
