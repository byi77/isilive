-- "Voice instead of effect" child option of the sound settings (rule 266).
-- Extends SettingsSound (ui/isiLive_settings_sound.lua, loaded before this
-- file) with CreateVoiceCheckbox / RefreshVoiceControls; both are only called
-- at build/refresh time, so the load order is the sole dependency.
local _, addonTable = ...
addonTable = addonTable or {}

local SettingsSound = addonTable.SettingsSound
local CreateSettingsCheckbox = addonTable.SettingsControls.CreateSettingsCheckbox
local DescriptionOptions = SettingsSound.DescriptionOptions
local SetDescription = SettingsSound.SetDescription
local IndentChildCheckbox = SettingsSound.IndentChildCheckbox

-- "Voice instead of effect" child option (rule 266) under every alert whose
-- registry entry has a `voice` part. Key and default come from the registry.
local VOICE_OPTION_TEXT = {
  labelKey = "SETTINGS_SOUND_VOICE_INSTEAD",
  descKey = "SETTINGS_SOUND_VOICE_INSTEAD_DESC",
  labelFallback = "Voice instead of effect",
  descFallback = "Speaks the alert instead of playing the sound effect.",
}

-- The registry `voice` part of a sound key (settingKey, defaultEnabled), or nil.
local function GetVoiceSetting(soundKey)
  local soundUtils = addonTable.SoundUtils
  local entry = type(soundUtils) == "table"
      and type(soundUtils.GetEntry) == "function"
      and soundUtils.GetEntry(soundKey)
    or nil
  local voice = type(entry) == "table" and entry.voice or nil
  if type(voice) ~= "table" or type(voice.settingKey) ~= "string" or voice.settingKey == "" then
    return nil
  end
  return voice
end

local function IsVoiceOptionChecked(voice, db)
  local stored = nil
  if type(db) == "table" then
    stored = db[voice.settingKey]
  end
  if stored ~= nil then
    return stored ~= false
  end
  return voice.defaultEnabled ~= false
end

--- Adds the indented "Voice instead of effect" option under the sound toggle
-- of `soundKey` (rule 266) when its registry entry has a voice line. Also
-- used by the display section for the aggro and missed-kick sounds.
-- Stored as controls.soundVoiceChecks[soundKey]; returns the next yOffset.
function SettingsSound.CreateVoiceCheckbox(canvas, yOffset, labels, config, controls, soundKey, sectionKey)
  local voice = GetVoiceSetting(soundKey)
  if not voice then
    return yOffset
  end
  local checkbox, nextY = CreateSettingsCheckbox(
    canvas,
    yOffset,
    labels[VOICE_OPTION_TEXT.labelKey] or VOICE_OPTION_TEXT.labelFallback,
    function()
      return IsVoiceOptionChecked(voice, config.getDB())
    end,
    function(checked)
      local db = config.getDB()
      db[voice.settingKey] = checked == true
    end,
    VOICE_OPTION_TEXT.labelKey,
    DescriptionOptions(labels[VOICE_OPTION_TEXT.descKey] or VOICE_OPTION_TEXT.descFallback)
  )
  IndentChildCheckbox(canvas, checkbox, yOffset)
  if checkbox and checkbox.check then
    checkbox.check._sectionKey = sectionKey or "SETTINGS_SECTION_SOUNDS"
    checkbox.check._soundKey = soundKey .. "_voice"
  end
  controls.soundVoiceChecks = controls.soundVoiceChecks or {}
  controls.soundVoiceChecks[soundKey] = checkbox
  return nextY
end

--- Repaints label, description and state of every voice option.
function SettingsSound.RefreshVoiceControls(controls, labels, db)
  if type(controls.soundVoiceChecks) ~= "table" then
    return
  end
  for soundKey, control in pairs(controls.soundVoiceChecks) do
    local voice = GetVoiceSetting(soundKey)
    if voice and control then
      control.label:SetText(labels[VOICE_OPTION_TEXT.labelKey] or VOICE_OPTION_TEXT.labelFallback)
      SetDescription(control, labels[VOICE_OPTION_TEXT.descKey] or VOICE_OPTION_TEXT.descFallback)
      control.check:SetChecked(IsVoiceOptionChecked(voice, db))
    end
  end
end
