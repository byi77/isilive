local _, addonTable = ...
addonTable = addonTable or {}

local SettingsSound = {}
addonTable.SettingsSound = SettingsSound

local CreateSectionHeader = addonTable.SettingsControls.CreateSectionHeader
local CreateSectionNote = addonTable.SettingsControls.CreateSectionNote
local CreateSettingsCheckbox = addonTable.SettingsControls.CreateSettingsCheckbox
local DESCRIPTION_WIDTH = 620
local PREVIEW_BUTTON_WIDTH = 24
local PREVIEW_BUTTON_HEIGHT = 22

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
    descFallback = "Plays a TTS alert when Battle Resurrection becomes available again.",
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
    descFallback = "Plays a TTS alert when Bloodlust or a similar exhaustion effect expires.",
    settingKey = "soundBloodlustReadyEnabled",
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
}

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
  label:SetText(">")
  button.label = label

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
    yOffset = nextY
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

  return yOffset
end

function SettingsSound.RefreshSoundControls(controls, labels, db)
  SetLocalizedText(controls.soundHeader, "SETTINGS_SECTION_SOUNDS", "Sounds", labels)
  SetLocalizedText(controls.soundHint, "SETTINGS_SECTION_SOUNDS_HINT", "Toggle the built-in audio cues.", labels)

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
        previewButton.label:SetText(">")
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
end
