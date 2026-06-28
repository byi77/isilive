local _, addonTable = ...
addonTable = addonTable or {}

local SettingsSound = {}
addonTable.SettingsSound = SettingsSound

local CreateSectionHeader = addonTable.SettingsControls.CreateSectionHeader
local CreateSectionNote = addonTable.SettingsControls.CreateSectionNote
local CreateChildSeparator = addonTable.SettingsControls.CreateChildSeparator
local CreateSettingsCheckbox = addonTable.SettingsControls.CreateSettingsCheckbox
local CreateSettingsOptionSelector = addonTable.SettingsControls.CreateSettingsOptionSelector
local DESCRIPTION_WIDTH = 620
local PREVIEW_BUTTON_WIDTH = 24
local PREVIEW_BUTTON_HEIGHT = 22
local CHILD_CHECKBOX_OFFSET_X = 32
local PREVIEW_PLAY_TEXTURE = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local SOUND_CHANNEL_VALUES = { Master = true, SFX = true }

local SOUND_CHANNEL_SETTING = {
  labelKey = "SETTINGS_SOUND_CHANNEL",
  descKey = "SETTINGS_SOUND_CHANNEL_DESC",
  labelFallback = "Sound output channel",
  descFallback = "Choose whether isiLive sound alerts use the Master or Sound Effects channel.",
  settingKey = "soundOutputChannel",
  defaultValue = "Master",
  options = {
    {
      value = "Master",
      labelKey = "SETTINGS_SOUND_CHANNEL_MASTER",
      fallback = "Master",
      width = 74,
    },
    {
      value = "SFX",
      labelKey = "SETTINGS_SOUND_CHANNEL_SFX", -- sound-ok
      fallback = "SFX",
      width = 58,
    },
  },
}

local SOUND_SETTING_FALLBACKS = {
  leader_transfer = {
    labelKey = "SETTINGS_SOUND_LEAD_ENABLED",
    descKey = "SETTINGS_SOUND_LEAD_ENABLED_DESC",
    labelFallback = "Sound: Lead Transfer",
    descFallback = "Plays a sound when group leadership changes to you.",
    settingKey = "soundLeadEnabled",
    defaultEnabled = true,
  },
  group_join = {
    labelKey = "SETTINGS_SOUND_GROUP_JOIN_ENABLED",
    descKey = "SETTINGS_SOUND_GROUP_JOIN_ENABLED_DESC",
    labelFallback = "Sound: Full Group",
    descFallback = "Plays a sound when your group reaches five players.",
    settingKey = "soundGroupJoinEnabled",
    defaultEnabled = true,
  },
  ready_check_complete = {
    labelKey = "SETTINGS_SOUND_READY_CHECK_COMPLETE",
    descKey = "SETTINGS_SOUND_READY_CHECK_COMPLETE_DESC",
    labelFallback = "Sound: Ready Check complete",
    descFallback = "Plays a sound once when all five ready-check participants are marked ready.",
    settingKey = "soundReadyCheckCompleteEnabled",
    defaultEnabled = true,
  },
  portal_available = {
    labelKey = "SETTINGS_SOUND_PORTAL_AVAILABLE",
    descKey = "SETTINGS_SOUND_PORTAL_AVAILABLE_DESC",
    labelFallback = "Sound: Incoming Summon",
    descFallback = "Plays a sound when an incoming summon is detected.",
    settingKey = "soundPortalAvailableEnabled",
    defaultEnabled = true,
  },
  battle_res = {
    labelKey = "SETTINGS_SOUND_BATTLE_RES",
    descKey = "SETTINGS_SOUND_BATTLE_RES_DESC",
    labelFallback = "Sound: Battle Res",
    descFallback = "Plays a sound when a Battle Resurrection is used.",
    settingKey = "soundBattleResEnabled",
    defaultEnabled = true,
  },
  battle_res_ready = {
    labelKey = "SETTINGS_SOUND_BATTLE_RES_READY",
    descKey = "SETTINGS_SOUND_BATTLE_RES_READY_DESC",
    labelFallback = "Sound: Battle Res ready",
    descFallback = "Plays a sound when Battle Resurrection becomes available again.",
    settingKey = "soundBattleResReadyEnabled",
    defaultEnabled = true,
  },
  bloodlust = {
    labelKey = "SETTINGS_SOUND_BLOODLUST",
    descKey = "SETTINGS_SOUND_BLOODLUST_DESC",
    labelFallback = "Sound: Bloodlust",
    descFallback = "Plays a sound when Bloodlust or a similar effect starts.",
    settingKey = "soundBloodlustEnabled",
    defaultEnabled = true,
  },
  bloodlust_ready = {
    labelKey = "SETTINGS_SOUND_BLOODLUST_READY",
    descKey = "SETTINGS_SOUND_BLOODLUST_READY_DESC",
    labelFallback = "Sound: Bloodlust ready",
    descFallback = "Plays a sound when Bloodlust or a similar exhaustion effect expires.",
    settingKey = "soundBloodlustReadyEnabled",
    defaultEnabled = true,
  },
  power_infusion_received = {
    labelKey = "SETTINGS_SOUND_POWER_INFUSION_RECEIVED",
    descKey = "SETTINGS_SOUND_POWER_INFUSION_RECEIVED_DESC",
    labelFallback = "Sound: PI received",
    descFallback = "Plays a sound when you receive Power Infusion during an active M+ run.",
    settingKey = "soundPowerInfusionReceivedEnabled",
    defaultEnabled = true,
  },
  tank_died = {
    labelKey = "SETTINGS_SOUND_TANK_DIED",
    descKey = "SETTINGS_SOUND_TANK_DIED_DESC",
    labelFallback = "Sound: Tank died",
    descFallback = "Plays a sound when the tank dies during an active M+ run.",
    settingKey = "soundTankDiedEnabled",
    defaultEnabled = true,
  },
  healer_died = {
    labelKey = "SETTINGS_SOUND_HEALER_DIED",
    descKey = "SETTINGS_SOUND_HEALER_DIED_DESC",
    labelFallback = "Sound: Healer died",
    descFallback = "Plays a sound when the healer dies during an active M+ run.",
    settingKey = "soundHealerDiedEnabled",
    defaultEnabled = true,
  },
}

local BLOODLUST_READY_REMINDER_SETTING = {
  labelKey = "SETTINGS_SOUND_BLOODLUST_READY_REMINDER",
  descKey = "SETTINGS_SOUND_BLOODLUST_READY_REMINDER_DESC",
  labelFallback = "Repeat Bloodlust-ready alert every 60 seconds",
  descFallback = "Repeats the Bloodlust-ready sound every 60 seconds while Bloodlust remains unused.",
  settingKey = "soundBloodlustReadyReminderEnabled",
  defaultEnabled = true,
}

local INCOMING_SUMMON_LOOP_SETTING = {
  labelKey = "SETTINGS_SOUND_INCOMING_SUMMON_LOOP",
  descKey = "SETTINGS_SOUND_INCOMING_SUMMON_LOOP_DESC",
  labelFallback = "Repeat incoming-summon alert every 5 seconds",
  descFallback = "Repeats the incoming-summon sound every 5 seconds while the summon is still pending.",
  settingKey = "soundIncomingSummonLoopEnabled",
  defaultEnabled = true,
}

local OWN_DEATH_SOUND_SETTINGS = {
  {
    controlKey = "ownTankDiedSoundCheck",
    soundKey = "own_tank_died",
    labelKey = "SETTINGS_SOUND_OWN_TANK_DIED",
    descKey = "SETTINGS_SOUND_OWN_TANK_DIED_DESC",
    parentSoundKey = "tank_died",
    labelFallback = "Sound alert even when you play tank yourself",
    descFallback = "Also plays the tank-death sound even when you are the tank yourself.",
    settingKey = "soundOwnTankDiedEnabled",
    defaultEnabled = true,
  },
  {
    controlKey = "ownHealerDiedSoundCheck",
    soundKey = "own_healer_died",
    labelKey = "SETTINGS_SOUND_OWN_HEALER_DIED",
    descKey = "SETTINGS_SOUND_OWN_HEALER_DIED_DESC",
    parentSoundKey = "healer_died",
    labelFallback = "Sound alert even when you play healer yourself",
    descFallback = "Also plays the healer-death sound even when you are the healer yourself.",
    settingKey = "soundOwnHealerDiedEnabled",
    defaultEnabled = true,
  },
}

local VIP_SOUND_DESCRIPTIONS = {
  SETTINGS_VIP_ASTRAL_AUROCHS_SOUND = {
    descKey = "SETTINGS_VIP_ASTRAL_AUROCHS_SOUND_DESC",
    fallback = "Mutes the selected Astral Aurochs mount ambience.",
  },
  SETTINGS_VIP_GRAND_EXPEDITION_YAK_SOUND = {
    descKey = "SETTINGS_VIP_GRAND_EXPEDITION_YAK_SOUND_DESC",
    fallback = "Mutes the Grand Expedition Yak vendor mount ambience.",
  },
  SETTINGS_VIP_GILDED_BRUTOSAUR_SOUND = {
    descKey = "SETTINGS_VIP_GILDED_BRUTOSAUR_SOUND_DESC",
    fallback = "Mutes the Trader Brutosaur vendor mount ambience.",
  },
  SETTINGS_VIP_DK_SOUL_REAPER_WARNING = {
    descKey = "SETTINGS_VIP_DK_SOUL_REAPER_WARNING_DESC",
    fallback = "Shows a red warning on Soul Reaper when Dark Transformation is nearly ready.",
  },
  SETTINGS_VIP_DK_PUTREFY_WARNING = {
    descKey = "SETTINGS_VIP_DK_PUTREFY_WARNING_DESC",
    fallback = "Shows a red warning on Putrefy when Dark Transformation is nearly ready.",
  },
  SETTINGS_VIP_BLOODLUST_DEBUFF_BUTTON_WARNING = {
    descKey = "SETTINGS_VIP_BLOODLUST_DEBUFF_BUTTON_WARNING_DESC",
    fallback = "Shows a red cross on your Bloodlust button while you have a Sated/Exhaustion debuff.",
  },
  SETTINGS_VIP_DK_APOCALYPSE_HORSE_SOUND = {
    descKey = "SETTINGS_VIP_DK_APOCALYPSE_HORSE_SOUND_DESC",
    fallback = "Mutes the horse summon sounds from Riders of the Apocalypse.",
  },
  SETTINGS_VIP_DK_GHOUL_REMINDER = {
    descKey = "SETTINGS_VIP_DK_GHOUL_REMINDER_DESC",
    fallback = "Shows a movable warning when your Unholy ghoul is missing.",
  },
}

local function NormalizeSoundChannel(value)
  if type(value) == "string" and SOUND_CHANNEL_VALUES[value] then
    return value
  end
  return SOUND_CHANNEL_SETTING.defaultValue
end

local function DescriptionOptions(descriptionText)
  return {
    descriptionText = descriptionText,
    descriptionWidth = DESCRIPTION_WIDTH,
    descriptionWordWrap = true,
    width = DESCRIPTION_WIDTH - PREVIEW_BUTTON_WIDTH - 12,
  }
end

local function SetDescription(control, text)
  if type(control) == "table" and control.description and type(control.description.SetText) == "function" then
    control.description:SetText(text or "")
  end
end

function SettingsSound.GetSoundSettingEntries()
  local soundUtils = addonTable.SoundUtils
  local registry = type(soundUtils) == "table" and type(soundUtils.Registry) == "table" and soundUtils.Registry or nil
  local order = type(soundUtils) == "table" and type(soundUtils.SettingsOrder) == "table" and soundUtils.SettingsOrder
    or {
      "leader_transfer",
      "group_join",
      "portal_available",
      "battle_res",
      "battle_res_ready",
      "bloodlust",
      "bloodlust_ready",
    }
  local entries = {}

  for _, key in ipairs(order) do
    local entry = registry and registry[key] or nil
    local fallback = SOUND_SETTING_FALLBACKS[key] or {}
    entries[#entries + 1] = {
      key = key,
      labelKey = type(entry) == "table" and entry.labelKey or fallback.labelKey,
      descKey = type(entry) == "table" and entry.descKey or fallback.descKey,
      labelFallback = type(entry) == "table" and entry.labelFallback or fallback.labelFallback,
      descFallback = type(entry) == "table" and entry.descFallback or fallback.descFallback,
      settingKey = type(entry) == "table" and entry.settingKey or fallback.settingKey,
      defaultEnabled = type(entry) == "table" and entry.defaultEnabled or fallback.defaultEnabled,
    }
  end

  return entries
end

local function SetLocalizedText(region, key, fallback, labels)
  if region and key then
    region:SetText(labels[key] or fallback or key)
  end
end

local function SetPreviewTooltip(button, labels)
  if type(button) ~= "table" then
    return
  end
  button._previewTooltipText = labels.SETTINGS_SOUND_PREVIEW or "Play preview"
end

local function CreateSoundPreviewButton(parent, checkbox, soundKey)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(PREVIEW_BUTTON_WIDTH, PREVIEW_BUTTON_HEIGHT)
  button:SetPoint("LEFT", checkbox.check, "RIGHT", 4, 0)
  button._sectionKey = "SETTINGS_SECTION_SOUNDS"
  button._settingKey = "SETTINGS_SOUND_PREVIEW"
  button._soundPreviewKey = soundKey

  if type(button.SetBackdrop) == "function" then
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    button:SetBackdropColor(0.12, 0.12, 0.18, 0.75)
    button:SetBackdropBorderColor(0.3, 0.65, 1, 0.55)
  end

  local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("CENTER", 0, 0)
  label:SetText("")
  button.label = label
  if type(button.CreateTexture) == "function" then
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", 0, 0)
    icon:SetSize(14, 14)
    icon:SetTexture(PREVIEW_PLAY_TEXTURE)
    button.icon = icon
  end

  button:SetScript("OnEnter", function(self)
    local tooltip = rawget(_G, "GameTooltip")
    if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" then
      return
    end
    tooltip:SetOwner(self, "ANCHOR_RIGHT")
    if type(tooltip.SetText) == "function" then
      tooltip:SetText(self._previewTooltipText or "Play preview", 1, 1, 1)
    elseif type(tooltip.AddLine) == "function" then
      tooltip:AddLine(self._previewTooltipText or "Play preview", 1, 1, 1)
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function()
    local tooltip = rawget(_G, "GameTooltip")
    if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
      tooltip:Hide()
    end
  end)

  if checkbox.label and type(checkbox.label.ClearAllPoints) == "function" then
    checkbox.label:ClearAllPoints()
    checkbox.label:SetPoint("LEFT", button, "RIGHT", 4, 0)
  end

  button:SetScript("OnClick", function()
    local soundUtils = addonTable.SoundUtils
    if type(soundUtils) == "table" and type(soundUtils.PlayPreviewKey) == "function" then
      soundUtils.PlayPreviewKey(soundKey)
    end
  end)

  return button
end

local function CreateIncomingSummonLoopCheckbox(canvas, yOffset, labels, config, controls)
  local checkbox, nextY = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels[INCOMING_SUMMON_LOOP_SETTING.labelKey] or INCOMING_SUMMON_LOOP_SETTING.labelFallback,
    function()
      local db = config.getDB()
      local stored = db[INCOMING_SUMMON_LOOP_SETTING.settingKey]
      if stored ~= nil then
        return stored == true
      end
      return INCOMING_SUMMON_LOOP_SETTING.defaultEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db[INCOMING_SUMMON_LOOP_SETTING.settingKey] = checked == true
    end,
    INCOMING_SUMMON_LOOP_SETTING.labelKey,
    DescriptionOptions(labels[INCOMING_SUMMON_LOOP_SETTING.descKey] or INCOMING_SUMMON_LOOP_SETTING.descFallback)
  )

  if checkbox and checkbox.check then
    checkbox.check._sectionKey = "SETTINGS_SECTION_SOUNDS"
    checkbox.check._soundKey = "incoming_summon_loop"
  end
  controls.incomingSummonLoopCheck = checkbox
  return nextY
end

local function CreateBloodlustReadyReminderCheckbox(canvas, yOffset, labels, config, controls)
  local checkbox, nextY = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels[BLOODLUST_READY_REMINDER_SETTING.labelKey] or BLOODLUST_READY_REMINDER_SETTING.labelFallback,
    function()
      local db = config.getDB()
      local stored = db[BLOODLUST_READY_REMINDER_SETTING.settingKey]
      if stored ~= nil then
        return stored == true
      end
      return BLOODLUST_READY_REMINDER_SETTING.defaultEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db[BLOODLUST_READY_REMINDER_SETTING.settingKey] = checked == true
    end,
    BLOODLUST_READY_REMINDER_SETTING.labelKey,
    DescriptionOptions(
      labels[BLOODLUST_READY_REMINDER_SETTING.descKey] or BLOODLUST_READY_REMINDER_SETTING.descFallback
    )
  )

  if checkbox and checkbox.check then
    checkbox.check._sectionKey = "SETTINGS_SECTION_SOUNDS"
    checkbox.check._soundKey = "bloodlust_ready_reminder"
  end
  controls.bloodlustReadyReminderCheck = checkbox
  return nextY
end

local function CreateOwnDeathSoundCheckbox(canvas, yOffset, labels, config, controls, entry)
  local checkbox, nextY = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels[entry.labelKey] or entry.labelFallback,
    function()
      local db = config.getDB()
      local stored = db[entry.settingKey]
      if stored ~= nil then
        return stored == true
      end
      return entry.defaultEnabled ~= false
    end,
    function(checked)
      local db = config.getDB()
      db[entry.settingKey] = checked == true
    end,
    entry.labelKey,
    DescriptionOptions(labels[entry.descKey] or entry.descFallback)
  )

  if checkbox and checkbox.check and type(checkbox.check.ClearAllPoints) == "function" then
    checkbox.check:ClearAllPoints()
    checkbox.check:SetPoint("TOPLEFT", canvas, "TOPLEFT", CHILD_CHECKBOX_OFFSET_X, yOffset)
  end
  if checkbox and checkbox.description and type(checkbox.description.GetPoint) == "function" then
    local point, _, relativePoint, _, y = checkbox.description:GetPoint()
    if point and type(checkbox.description.ClearAllPoints) == "function" then
      checkbox.description:ClearAllPoints()
      checkbox.description:SetPoint(point, canvas, relativePoint, CHILD_CHECKBOX_OFFSET_X, y or 0)
    end
  end

  if checkbox and checkbox.check then
    checkbox.check._sectionKey = "SETTINGS_SECTION_SOUNDS"
    checkbox.check._soundKey = entry.soundKey
  end
  controls[entry.controlKey] = checkbox
  return nextY
end

local function CreateSoundChannelSelector(canvas, yOffset, labels, config, controls)
  local selector, nextY = CreateSettingsOptionSelector(
    canvas,
    yOffset,
    SOUND_CHANNEL_SETTING.labelKey,
    labels[SOUND_CHANNEL_SETTING.labelKey] or SOUND_CHANNEL_SETTING.labelFallback,
    SOUND_CHANNEL_SETTING.options,
    function()
      return labels
    end,
    function()
      local db = config.getDB()
      return NormalizeSoundChannel(db[SOUND_CHANNEL_SETTING.settingKey])
    end,
    function(value)
      local db = config.getDB()
      db[SOUND_CHANNEL_SETTING.settingKey] = NormalizeSoundChannel(value)
    end,
    NormalizeSoundChannel,
    false,
    {
      descriptionKey = SOUND_CHANNEL_SETTING.descKey,
      descriptionText = labels[SOUND_CHANNEL_SETTING.descKey] or SOUND_CHANNEL_SETTING.descFallback,
      descriptionWidth = DESCRIPTION_WIDTH,
      descriptionWordWrap = true,
    }
  )

  selector._sectionKey = "SETTINGS_SECTION_SOUNDS"
  selector._settingKey = SOUND_CHANNEL_SETTING.labelKey
  if selector.label then
    selector.label._sectionKey = "SETTINGS_SECTION_SOUNDS"
    selector.label._settingKey = SOUND_CHANNEL_SETTING.labelKey
  end
  if selector.buttons then
    for _, button in ipairs(selector.buttons) do
      button._sectionKey = "SETTINGS_SECTION_SOUNDS"
      button._settingKey = SOUND_CHANNEL_SETTING.labelKey
    end
  end
  controls.soundChannelSelector = selector
  return nextY
end

function SettingsSound.BuildSoundSection(canvas, yOffset, labels, config, controls)
  controls.soundHeader, yOffset = CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_SOUNDS or "Sounds")
  if controls.soundHeader then
    controls.soundHeader._sectionKey = "SETTINGS_SECTION_SOUNDS"
  end

  controls.soundHint, yOffset =
    CreateSectionNote(canvas, yOffset, labels.SETTINGS_SECTION_SOUNDS_HINT or "Toggle the built-in audio cues.")
  if controls.soundHint then
    controls.soundHint._sectionKey = "SETTINGS_SECTION_SOUNDS"
  end

  controls.soundChecks = controls.soundChecks or {}
  controls.soundPreviewButtons = controls.soundPreviewButtons or {}

  yOffset = CreateSoundChannelSelector(canvas, yOffset, labels, config, controls)
  if type(CreateChildSeparator) == "function" then
    controls.soundOutputSeparator, yOffset = CreateChildSeparator(canvas, yOffset)
    if controls.soundOutputSeparator then
      controls.soundOutputSeparator._sectionKey = "SETTINGS_SECTION_SOUNDS"
    end
  end

  for _, entry in ipairs(SettingsSound.GetSoundSettingEntries()) do
    local checkbox, nextY = CreateSettingsCheckbox(
      canvas,
      yOffset,
      labels[entry.labelKey] or entry.labelFallback or entry.labelKey or entry.key or "Sound",
      function()
        local db = config.getDB()
        local settingKey = entry.settingKey
        if type(settingKey) == "string" and settingKey ~= "" then
          local stored = db[settingKey]
          if stored ~= nil then
            return stored == true
          end
        end
        return entry.defaultEnabled ~= false
      end,
      function(checked)
        local db = config.getDB()
        local settingKey = entry.settingKey
        if type(settingKey) == "string" and settingKey ~= "" then
          db[settingKey] = checked
        end
      end,
      entry.labelKey,
      DescriptionOptions(labels[entry.descKey] or entry.descFallback)
    )

    if checkbox and checkbox.check then
      checkbox.check._sectionKey = "SETTINGS_SECTION_SOUNDS"
      checkbox.check._soundKey = entry.key
    end
    controls.soundChecks[entry.key] = checkbox
    controls.soundPreviewButtons[entry.key] = CreateSoundPreviewButton(canvas, checkbox, entry.key)
    SetPreviewTooltip(controls.soundPreviewButtons[entry.key], labels)
    yOffset = nextY
    if entry.key == "portal_available" then
      yOffset = CreateIncomingSummonLoopCheckbox(canvas, yOffset, labels, config, controls)
    end
    if entry.key == "bloodlust_ready" then
      yOffset = CreateBloodlustReadyReminderCheckbox(canvas, yOffset, labels, config, controls)
    end
    for _, ownDeathEntry in ipairs(OWN_DEATH_SOUND_SETTINGS) do
      if ownDeathEntry.parentSoundKey == entry.key then
        yOffset = CreateOwnDeathSoundCheckbox(canvas, yOffset, labels, config, controls, ownDeathEntry)
      end
    end
  end

  return yOffset
end

function SettingsSound.BuildVIPGuestSection(canvas, yOffset, labels, config, controls)
  controls.vipGuestHeader, yOffset =
    CreateSectionHeader(canvas, yOffset, labels.SETTINGS_SECTION_VIP_GUESTS or "VIP Guest Settings")
  if controls.vipGuestHeader then
    controls.vipGuestHeader._sectionKey = "SETTINGS_SECTION_VIP_GUESTS"
  end

  controls.vipGuestHint, yOffset = CreateSectionNote(
    canvas,
    yOffset,
    labels.SETTINGS_SECTION_VIP_GUESTS_HINT or "Special sound controls for selected guests."
  )
  if controls.vipGuestHint then
    controls.vipGuestHint._sectionKey = "SETTINGS_SECTION_VIP_GUESTS"
  end

  local function CreateVIPMountSoundCheckbox(controlKey, labelKey, fallbackLabel, dbKey, applyFnName)
    local desc = VIP_SOUND_DESCRIPTIONS[labelKey] or {}
    controls[controlKey], yOffset = CreateSettingsCheckbox(
      canvas,
      yOffset,
      labels[labelKey] or fallbackLabel,
      function()
        local db = config.getDB()
        return db[dbKey] == true
      end,
      function(checked)
        local db = config.getDB()
        db[dbKey] = checked == true
        local soundUtils = addonTable.SoundUtils
        if type(soundUtils) == "table" and type(soundUtils[applyFnName]) == "function" then
          soundUtils[applyFnName](checked)
        end
      end,
      labelKey,
      DescriptionOptions(labels[desc.descKey] or desc.fallback)
    )
    if controls[controlKey] and controls[controlKey].check then
      controls[controlKey].check._sectionKey = "SETTINGS_SECTION_VIP_GUESTS"
    end
  end

  CreateVIPMountSoundCheckbox(
    "vipAstralAurochsSound",
    "SETTINGS_VIP_ASTRAL_AUROCHS_SOUND",
    "Mute Astral Aurochs mount sound",
    "vipAstralAurochsSoundMuted",
    "ApplyAstralAurochsSoundSetting"
  )
  if controls.vipAstralAurochsSound and controls.vipAstralAurochsSound.check then
    controls.vipAstralAurochsSound.check._sectionKey = "SETTINGS_SECTION_VIP_GUESTS"
  end
  CreateVIPMountSoundCheckbox(
    "vipGrandExpeditionYakSound",
    "SETTINGS_VIP_GRAND_EXPEDITION_YAK_SOUND",
    "Mute Grand Expedition Yak mount sound",
    "vipGrandExpeditionYakSoundMuted",
    "ApplyGrandExpeditionYakSoundSetting"
  )
  CreateVIPMountSoundCheckbox(
    "vipGildedBrutosaurSound",
    "SETTINGS_VIP_GILDED_BRUTOSAUR_SOUND",
    "Mute Trader Brutosaur mount sound",
    "vipGildedBrutosaurSoundMuted",
    "ApplyGildedBrutosaurSoundSetting"
  )

  local function CreateVipDkWarningCheckbox(controlKey, labelKey, fallbackLabel, dbKey)
    local desc = VIP_SOUND_DESCRIPTIONS[labelKey] or {}
    controls[controlKey], yOffset = CreateSettingsCheckbox(
      canvas,
      yOffset,
      labels[labelKey] or fallbackLabel,
      function()
        local db = config.getDB()
        return db[dbKey] == true
      end,
      function(checked)
        local db = config.getDB()
        db[dbKey] = checked == true
        local vipDkAssist = addonTable.VipDkAssist
        if type(vipDkAssist) == "table" and type(vipDkAssist.HandleEvent) == "function" then
          vipDkAssist.HandleEvent("PLAYER_SPECIALIZATION_CHANGED")
        end
      end,
      labelKey,
      DescriptionOptions(labels[desc.descKey] or desc.fallback)
    )
    if controls[controlKey] and controls[controlKey].check then
      controls[controlKey].check._sectionKey = "SETTINGS_SECTION_VIP_GUESTS"
    end
  end

  local function CreateVipDkChildSoundCheckbox(controlKey, labelKey, fallbackLabel, dbKey, applyFnName)
    local desc = VIP_SOUND_DESCRIPTIONS[labelKey] or {}
    local originalY = yOffset
    local checkbox, nextY = CreateSettingsCheckbox(
      canvas,
      yOffset,
      labels[labelKey] or fallbackLabel,
      function()
        local db = config.getDB()
        return db[dbKey] == true
      end,
      function(checked)
        local db = config.getDB()
        db[dbKey] = checked == true
        local soundUtils = addonTable.SoundUtils
        if type(soundUtils) == "table" and type(soundUtils[applyFnName]) == "function" then
          soundUtils[applyFnName](checked)
        end
      end,
      labelKey,
      DescriptionOptions(labels[desc.descKey] or desc.fallback)
    )
    controls[controlKey] = checkbox
    if controls[controlKey] and controls[controlKey].check then
      controls[controlKey].check._sectionKey = "SETTINGS_SECTION_VIP_GUESTS"
      if type(controls[controlKey].check.ClearAllPoints) == "function" then
        controls[controlKey].check:ClearAllPoints()
        controls[controlKey].check:SetPoint("TOPLEFT", canvas, "TOPLEFT", CHILD_CHECKBOX_OFFSET_X, originalY)
      end
    end
    if controls[controlKey] and controls[controlKey].description and type(controls[controlKey].description.GetPoint) == "function" then
      local point, _, relativePoint, _, y = controls[controlKey].description:GetPoint()
      if point and type(controls[controlKey].description.ClearAllPoints) == "function" then
        controls[controlKey].description:ClearAllPoints()
        controls[controlKey].description:SetPoint(point, canvas, relativePoint, CHILD_CHECKBOX_OFFSET_X, y or 0)
      end
    end
    yOffset = nextY
  end

  local function CreateVipDkChildCheckbox(controlKey, labelKey, fallbackLabel, dbKey, onChanged, defaultOn)
    local desc = VIP_SOUND_DESCRIPTIONS[labelKey] or {}
    local originalY = yOffset
    local checkbox, nextY = CreateSettingsCheckbox(
      canvas,
      yOffset,
      labels[labelKey] or fallbackLabel,
      function()
        local db = config.getDB()
        if defaultOn == true then
          return db[dbKey] ~= false
        end
        return db[dbKey] == true
      end,
      function(checked)
        local db = config.getDB()
        db[dbKey] = checked == true
        if type(onChanged) == "function" then
          onChanged()
        else
          local vipDkAssist = addonTable.VipDkAssist
          if type(vipDkAssist) == "table" and type(vipDkAssist.HandleEvent) == "function" then
            vipDkAssist.HandleEvent("PLAYER_SPECIALIZATION_CHANGED")
          end
        end
      end,
      labelKey,
      DescriptionOptions(labels[desc.descKey] or desc.fallback)
    )
    controls[controlKey] = checkbox
    if controls[controlKey] and controls[controlKey].check then
      controls[controlKey].check._sectionKey = "SETTINGS_SECTION_VIP_GUESTS"
      if type(controls[controlKey].check.ClearAllPoints) == "function" then
        controls[controlKey].check:ClearAllPoints()
        controls[controlKey].check:SetPoint("TOPLEFT", canvas, "TOPLEFT", CHILD_CHECKBOX_OFFSET_X, originalY)
      end
    end
    if controls[controlKey] and controls[controlKey].description and type(controls[controlKey].description.GetPoint) == "function" then
      local point, _, relativePoint, _, y = controls[controlKey].description:GetPoint()
      if point and type(controls[controlKey].description.ClearAllPoints) == "function" then
        controls[controlKey].description:ClearAllPoints()
        controls[controlKey].description:SetPoint(point, canvas, relativePoint, CHILD_CHECKBOX_OFFSET_X, y or 0)
      end
    end
    yOffset = nextY
  end

  CreateVipDkWarningCheckbox(
    "vipDkSoulReaperWarning",
    "SETTINGS_VIP_DK_SOUL_REAPER_WARNING",
    "Soul Reaper warning for Unholy DK",
    "vipDkSoulReaperWarningEnabled"
  )
  CreateVipDkWarningCheckbox(
    "vipDkPutrefyWarning",
    "SETTINGS_VIP_DK_PUTREFY_WARNING",
    "Putrefy warning for Unholy DK",
    "vipDkPutrefyWarningEnabled"
  )
  CreateVipDkChildCheckbox(
    "vipBloodlustDebuffButtonWarning",
    "SETTINGS_VIP_BLOODLUST_DEBUFF_BUTTON_WARNING",
    "Bloodlust button warning while debuffed",
    "vipBloodlustDebuffButtonWarningEnabled",
    function()
      local bloodlustWarning = addonTable.BloodlustButtonWarning
      if type(bloodlustWarning) == "table" and type(bloodlustWarning.HandleEvent) == "function" then
        bloodlustWarning.HandleEvent("UNIT_AURA", "player")
      end
    end,
    false
  )
  CreateVipDkChildSoundCheckbox(
    "vipDkApocalypseHorseSound",
    "SETTINGS_VIP_DK_APOCALYPSE_HORSE_SOUND",
    "Mute Riders of the Apocalypse horse sounds",
    "vipDkApocalypseHorseSoundMuted",
    "ApplyDkApocalypseHorseSoundSetting"
  )
  CreateVipDkChildCheckbox(
    "vipDkGhoulReminder",
    "SETTINGS_VIP_DK_GHOUL_REMINDER",
    "Show missing-ghoul reminder",
    "vipDkGhoulReminderEnabled"
  )

  return yOffset
end

function SettingsSound.RefreshSoundControls(controls, labels, db)
  SetLocalizedText(controls.soundHeader, "SETTINGS_SECTION_SOUNDS", "Sounds", labels)
  SetLocalizedText(controls.soundHint, "SETTINGS_SECTION_SOUNDS_HINT", "Toggle the built-in audio cues.", labels)

  if controls.soundChannelSelector and type(controls.soundChannelSelector.UpdateHighlight) == "function" then
    controls.soundChannelSelector.UpdateHighlight()
  end

  if controls.soundChecks then
    for _, entry in ipairs(SettingsSound.GetSoundSettingEntries()) do
      local soundControl = controls.soundChecks[entry.key]
      if soundControl then
        local fallback = SOUND_SETTING_FALLBACKS[entry.key] or {}
        soundControl.label:SetText(
          labels[entry.labelKey]
            or fallback.labelFallback
            or fallback.labelKey
            or entry.labelKey
            or entry.key
            or "Sound"
        )
        SetDescription(soundControl, labels[entry.descKey] or fallback.descFallback or entry.descFallback)
      end
      local previewButton = controls.soundPreviewButtons and controls.soundPreviewButtons[entry.key] or nil
      if previewButton and previewButton.label then
        previewButton.label:SetText("")
        SetPreviewTooltip(previewButton, labels)
      end
    end
  end

  if controls.soundChecks then
    for _, entry in ipairs(SettingsSound.GetSoundSettingEntries()) do
      local soundControl = controls.soundChecks[entry.key]
      if soundControl then
        local settingKey = entry.settingKey
        local defaultEnabled = entry.defaultEnabled ~= false
        local nextValue = defaultEnabled
        if type(settingKey) == "string" and settingKey ~= "" and db[settingKey] ~= nil then
          nextValue = db[settingKey] == true
        end
        soundControl.check:SetChecked(nextValue)
      end
    end
  end

  if controls.bloodlustReadyReminderCheck then
    controls.bloodlustReadyReminderCheck.label:SetText(
      labels[BLOODLUST_READY_REMINDER_SETTING.labelKey] or BLOODLUST_READY_REMINDER_SETTING.labelFallback
    )
    SetDescription(
      controls.bloodlustReadyReminderCheck,
      labels[BLOODLUST_READY_REMINDER_SETTING.descKey] or BLOODLUST_READY_REMINDER_SETTING.descFallback
    )
    local stored = db[BLOODLUST_READY_REMINDER_SETTING.settingKey]
    local nextValue = BLOODLUST_READY_REMINDER_SETTING.defaultEnabled ~= false
    if stored ~= nil then
      nextValue = stored == true
    end
    controls.bloodlustReadyReminderCheck.check:SetChecked(nextValue)
  end

  if controls.incomingSummonLoopCheck then
    controls.incomingSummonLoopCheck.label:SetText(
      labels[INCOMING_SUMMON_LOOP_SETTING.labelKey] or INCOMING_SUMMON_LOOP_SETTING.labelFallback
    )
    SetDescription(
      controls.incomingSummonLoopCheck,
      labels[INCOMING_SUMMON_LOOP_SETTING.descKey] or INCOMING_SUMMON_LOOP_SETTING.descFallback
    )
    local stored = db[INCOMING_SUMMON_LOOP_SETTING.settingKey]
    local nextValue = INCOMING_SUMMON_LOOP_SETTING.defaultEnabled ~= false
    if stored ~= nil then
      nextValue = stored == true
    end
    controls.incomingSummonLoopCheck.check:SetChecked(nextValue)
  end

  for _, entry in ipairs(OWN_DEATH_SOUND_SETTINGS) do
    local control = controls[entry.controlKey]
    if control then
      control.label:SetText(labels[entry.labelKey] or entry.labelFallback)
      SetDescription(control, labels[entry.descKey] or entry.descFallback)
      local stored = db[entry.settingKey]
      local nextValue = entry.defaultEnabled ~= false
      if stored ~= nil then
        nextValue = stored == true
      end
      control.check:SetChecked(nextValue)
    end
  end
end

function SettingsSound.RefreshVIPGuestControls(controls, labels, db)
  SetLocalizedText(controls.vipGuestHeader, "SETTINGS_SECTION_VIP_GUESTS", "VIP Guest Settings", labels)
  SetLocalizedText(
    controls.vipGuestHint,
    "SETTINGS_SECTION_VIP_GUESTS_HINT",
    "Special sound controls for selected guests.",
    labels
  )
  if controls.vipAstralAurochsSound and controls.vipAstralAurochsSound.label then
    controls.vipAstralAurochsSound.label:SetText(
      labels.SETTINGS_VIP_ASTRAL_AUROCHS_SOUND or "Mute Astral Aurochs mount sound"
    )
    SetDescription(
      controls.vipAstralAurochsSound,
      labels.SETTINGS_VIP_ASTRAL_AUROCHS_SOUND_DESC or "Mutes the selected Astral Aurochs mount ambience."
    )
    controls.vipAstralAurochsSound.check:SetChecked(db.vipAstralAurochsSoundMuted == true)
  end
  if controls.vipGrandExpeditionYakSound and controls.vipGrandExpeditionYakSound.label then
    controls.vipGrandExpeditionYakSound.label:SetText(
      labels.SETTINGS_VIP_GRAND_EXPEDITION_YAK_SOUND or "Mute Grand Expedition Yak mount sound"
    )
    SetDescription(
      controls.vipGrandExpeditionYakSound,
      labels.SETTINGS_VIP_GRAND_EXPEDITION_YAK_SOUND_DESC or "Mutes the Grand Expedition Yak vendor mount ambience."
    )
    controls.vipGrandExpeditionYakSound.check:SetChecked(db.vipGrandExpeditionYakSoundMuted == true)
  end
  if controls.vipGildedBrutosaurSound and controls.vipGildedBrutosaurSound.label then
    controls.vipGildedBrutosaurSound.label:SetText(
      labels.SETTINGS_VIP_GILDED_BRUTOSAUR_SOUND or "Mute Trader Brutosaur mount sound"
    )
    SetDescription(
      controls.vipGildedBrutosaurSound,
      labels.SETTINGS_VIP_GILDED_BRUTOSAUR_SOUND_DESC or "Mutes the Trader Brutosaur vendor mount ambience."
    )
    controls.vipGildedBrutosaurSound.check:SetChecked(db.vipGildedBrutosaurSoundMuted == true)
  end
  if controls.vipDkSoulReaperWarning and controls.vipDkSoulReaperWarning.label then
    controls.vipDkSoulReaperWarning.label:SetText(
      labels.SETTINGS_VIP_DK_SOUL_REAPER_WARNING or "Soul Reaper warning for Unholy DK"
    )
    SetDescription(
      controls.vipDkSoulReaperWarning,
      labels.SETTINGS_VIP_DK_SOUL_REAPER_WARNING_DESC
        or "Shows a red warning on Soul Reaper when Dark Transformation is nearly ready."
    )
    controls.vipDkSoulReaperWarning.check:SetChecked(db.vipDkSoulReaperWarningEnabled == true)
  end
  if controls.vipDkPutrefyWarning and controls.vipDkPutrefyWarning.label then
    controls.vipDkPutrefyWarning.label:SetText(
      labels.SETTINGS_VIP_DK_PUTREFY_WARNING or "Putrefy warning for Unholy DK"
    )
    SetDescription(
      controls.vipDkPutrefyWarning,
      labels.SETTINGS_VIP_DK_PUTREFY_WARNING_DESC
        or "Shows a red warning on Putrefy when Dark Transformation is nearly ready."
    )
    controls.vipDkPutrefyWarning.check:SetChecked(db.vipDkPutrefyWarningEnabled == true)
  end
  if controls.vipBloodlustDebuffButtonWarning and controls.vipBloodlustDebuffButtonWarning.label then
    controls.vipBloodlustDebuffButtonWarning.label:SetText(
      labels.SETTINGS_VIP_BLOODLUST_DEBUFF_BUTTON_WARNING or "Bloodlust button warning while debuffed"
    )
    SetDescription(
      controls.vipBloodlustDebuffButtonWarning,
      labels.SETTINGS_VIP_BLOODLUST_DEBUFF_BUTTON_WARNING_DESC
        or "Shows a red cross on your Bloodlust button while you have a Sated/Exhaustion debuff."
    )
    controls.vipBloodlustDebuffButtonWarning.check:SetChecked(db.vipBloodlustDebuffButtonWarningEnabled == true)
  end
  if controls.vipDkApocalypseHorseSound and controls.vipDkApocalypseHorseSound.label then
    controls.vipDkApocalypseHorseSound.label:SetText(
      labels.SETTINGS_VIP_DK_APOCALYPSE_HORSE_SOUND or "Mute Riders of the Apocalypse horse sounds"
    )
    SetDescription(
      controls.vipDkApocalypseHorseSound,
      labels.SETTINGS_VIP_DK_APOCALYPSE_HORSE_SOUND_DESC
        or "Mutes the horse summon sounds from Riders of the Apocalypse."
    )
    controls.vipDkApocalypseHorseSound.check:SetChecked(db.vipDkApocalypseHorseSoundMuted == true)
  end
  if controls.vipDkGhoulReminder and controls.vipDkGhoulReminder.label then
    controls.vipDkGhoulReminder.label:SetText(labels.SETTINGS_VIP_DK_GHOUL_REMINDER or "Show missing-ghoul reminder")
    SetDescription(
      controls.vipDkGhoulReminder,
      labels.SETTINGS_VIP_DK_GHOUL_REMINDER_DESC or "Shows a movable warning when your Unholy ghoul is missing."
    )
    controls.vipDkGhoulReminder.check:SetChecked(db.vipDkGhoulReminderEnabled == true)
  end
end
