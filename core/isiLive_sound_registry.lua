local _, addonTable = ...

addonTable = addonTable or {}

local SoundRegistry = {
  Registry = {
    leader_transfer = {
      file = "Interface\\AddOns\\isiLive\\sounds\\CartoonVoiceBaritone.ogg",
      labelKey = "SETTINGS_SOUND_LEAD_ENABLED",
      settingKey = "soundLeadEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
    group_join = {
      file = "Interface\\AddOns\\isiLive\\sounds\\SynthChord.ogg",
      labelKey = "SETTINGS_SOUND_GROUP_JOIN_ENABLED",
      settingKey = "soundGroupJoinEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
    ready_check_complete = {
      file = "Interface\\AddOns\\isiLive\\sounds\\BttF_Tinkle.wav",
      labelKey = "SETTINGS_SOUND_READY_CHECK_COMPLETE",
      descKey = "SETTINGS_SOUND_READY_CHECK_COMPLETE_DESC",
      labelFallback = "Sound alert when all five players are ready",
      descFallback = "Plays a sound once when all five ready-check participants are marked ready.",
      settingKey = "soundReadyCheckCompleteEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
    portal_available = {
      file = "Interface\\AddOns\\isiLive\\sounds\\Portal.ogg",
      localizedFiles = {
        deDE = "Interface\\AddOns\\isiLive\\sounds\\Portal_deDE.wav",
      },
      labelKey = "SETTINGS_SOUND_PORTAL_AVAILABLE",
      settingKey = "soundPortalAvailableEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
    battle_res = {
      file = "Interface\\AddOns\\isiLive\\sounds\\ChickenAlarm.ogg",
      fallbackFile = "Interface\\AddOns\\isiLive\\sounds\\RoosterChickenCalls.ogg",
      labelKey = "SETTINGS_SOUND_BATTLE_RES",
      settingKey = "soundBattleResEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
    battle_res_ready = {
      file = "Interface\\AddOns\\isiLive\\sounds\\BattleRezReady.wav",
      localizedFiles = {
        deDE = "Interface\\AddOns\\isiLive\\sounds\\BattleRezReady_deDE.wav",
      },
      labelKey = "SETTINGS_SOUND_BATTLE_RES_READY",
      descKey = "SETTINGS_SOUND_BATTLE_RES_READY_DESC",
      labelFallback = "Sound: Battle Res ready",
      descFallback = "Plays a sound when Battle Resurrection becomes available again.",
      settingKey = "soundBattleResReadyEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
    bloodlust = {
      file = "Interface\\AddOns\\isiLive\\sounds\\BoxingArenaSound.ogg",
      labelKey = "SETTINGS_SOUND_BLOODLUST",
      settingKey = "soundBloodlustEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
    bloodlust_ready = {
      file = "Interface\\AddOns\\isiLive\\sounds\\BloodlustReady.wav",
      localizedFiles = {
        deDE = "Interface\\AddOns\\isiLive\\sounds\\BloodlustReady_deDE.wav",
      },
      labelKey = "SETTINGS_SOUND_BLOODLUST_READY",
      descKey = "SETTINGS_SOUND_BLOODLUST_READY_DESC",
      labelFallback = "Sound: Bloodlust ready",
      descFallback = "Plays a sound when Bloodlust or a similar exhaustion effect expires.",
      settingKey = "soundBloodlustReadyEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
    power_infusion_received = {
      file = "Interface\\AddOns\\isiLive\\sounds\\PowerInfusionReceived.wav",
      localizedFiles = {
        deDE = "Interface\\AddOns\\isiLive\\sounds\\PowerInfusionReceived_deDE.wav",
      },
      labelKey = "SETTINGS_SOUND_POWER_INFUSION_RECEIVED",
      descKey = "SETTINGS_SOUND_POWER_INFUSION_RECEIVED_DESC",
      labelFallback = "Sound: PI received",
      descFallback = "Plays a sound when you receive Power Infusion during an active M+ run.",
      settingKey = "soundPowerInfusionReceivedEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
    tank_died = {
      file = "Interface\\AddOns\\isiLive\\sounds\\TankDied.wav",
      localizedFiles = {
        deDE = "Interface\\AddOns\\isiLive\\sounds\\TankDied_deDE.wav",
      },
      labelKey = "SETTINGS_SOUND_TANK_DIED",
      descKey = "SETTINGS_SOUND_TANK_DIED_DESC",
      labelFallback = "Sound: Tank died",
      descFallback = "Plays a sound when the tank dies during an active M+ run.",
      settingKey = "soundTankDiedEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
    healer_died = {
      file = "Interface\\AddOns\\isiLive\\sounds\\HealerDied.wav",
      localizedFiles = {
        deDE = "Interface\\AddOns\\isiLive\\sounds\\HealerDied_deDE.wav",
      },
      labelKey = "SETTINGS_SOUND_HEALER_DIED",
      descKey = "SETTINGS_SOUND_HEALER_DIED_DESC",
      labelFallback = "Sound: Healer died",
      descFallback = "Plays a sound when the healer dies during an active M+ run.",
      settingKey = "soundHealerDiedEnabled",
      defaultEnabled = true,
      defaultChannel = "Master",
    },
  },
  SettingsOrder = {
    "leader_transfer",
    "group_join",
    "ready_check_complete",
    "portal_available",
    "battle_res",
    "battle_res_ready",
    "bloodlust",
    "bloodlust_ready",
    "power_infusion_received",
    "tank_died",
    "healer_died",
  },
}

addonTable.SoundRegistry = SoundRegistry
