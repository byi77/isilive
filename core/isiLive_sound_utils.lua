local _, addonTable = ...

addonTable = addonTable or {}

local SoundUtils = {}
addonTable.SoundUtils = SoundUtils

local SPAM_WINDOW = 1.0 -- seconds: ignore duplicate sound within this window
local lastPlayedAt = {} -- soundKey -> timestamp
local VIP_MOUNT_SOUND_FILE_IDS = {
  astral_aurochs = {
    7340960,
    7340962,
    7340964,
    7340966,
    7340968,
    7340970,
    7340972,
    7340974,
    7340976,
    7340978,
    7340940,
    7340942,
    7340944,
    7340946,
    7340948,
    7340950,
    7340952,
    7340954,
    7340956,
    7340958,
    7340915,
    7340917,
    7340919,
    7340921,
    7340933,
    7340935,
    7340938,
    7340891,
    7340893,
    7340895,
    7340897,
    7340899,
    7340911,
    7340913,
    7340841,
    7340843,
    7340845,
    7340847,
    7340849,
    7340851,
    7340853,
    7340855,
    7340857,
    7340859,
    6795931,
    6795933,
    6795935,
    6795937,
    6795939,
    6795941,
    6795943,
    6795945,
    6795947,
    6795949,
    7340861,
    7340863,
    7340865,
    7340867,
    7340869,
    6986422,
    6986424,
    6986426,
    6986428,
    6986430,
    6986432,
    6986434,
    6986436,
    6986438,
    6986440,
    950654,
    950656,
    950658,
    950660,
    950662,
    950664,
    4906115,
    4906117,
    4906119,
    4906121,
    4906123,
    4906125,
    4906127,
    4906129,
    4906131,
    4906133,
    4906135,
    4906137,
    4906139,
    4906141,
    4906143,
    4906145,
    4906147,
    4906149,
    4906151,
    6788040,
    6788042,
    6788044,
    6788046,
    6788048,
    6788050,
    6788052,
    6788054,
    6788056,
    6788058,
  },
  grand_expedition_yak = {
    613111,
    613113,
    613115,
    613117,
    613119,
    613121,
    613123,
    613125,
    613127,
    613101,
    613103,
    613105,
    613107,
    613109,
    613171,
    613173,
    613175,
    613177,
    613179,
    613181,
    613183,
    613185,
    613187,
    613161,
    613163,
    613165,
    613167,
    613169,
    613129,
    613131,
    613133,
    613135,
    613137,
    613139,
    613141,
    613151,
    613153,
    613155,
    613157,
    613159,
    613091,
    613093,
    613095,
    613097,
    613099,
    613143,
    613145,
    613147,
    613149,
    633579,
    633581,
    633583,
    633585,
    633587,
    633589,
    633591,
    633593,
    633595,
    633597,
    633599,
    633601,
    633603,
    633605,
    633607,
    633609,
    633611,
    633613,
    633615,
    633617,
    643051,
    643053,
    643055,
    643057,
    643059,
    643061,
    643063,
    643065,
    643067,
    643069,
    643071,
    643073,
    551670,
    551684,
    551686,
    551700,
    552058,
    552065,
    552073,
    552077,
    552084,
    557703,
    557708,
    557711,
    557712,
    557716,
    557718,
    557721,
    557725,
    557726,
    557727,
    557728,
    557729,
    557731,
    558265,
    569062,
    1023697,
    1023698,
    1023699,
    1023700,
    1023701,
    1023702,
    1023703,
    1023704,
    1023705,
    1023706,
    1023707,
    1023708,
    1023709,
    1023710,
    1023711,
    1023712,
    1023713,
    1023714,
    1023715,
    1023716,
    3165629,
    3500738,
    1023717,
    1023718,
    1023719,
    1023720,
    1023721,
    1023722,
    1023723,
    1023724,
    1023725,
    1023726,
    1023727,
    1023728,
    1023729,
    1023730,
    1023731,
    1023732,
    1023733,
    1023734,
    1023735,
    1023736,
    1416763,
    1416764,
    1416765,
    3165630,
    1023737,
    1023738,
    1023739,
    1023740,
    1023741,
    1023742,
    1023743,
    1023744,
    1023745,
    1023746,
    1023747,
    1023748,
    1023749,
    1023750,
    1023751,
    1023752,
    1023753,
    1023754,
    1023755,
    1023756,
    3165631,
    1011277,
    1011278,
    1011279,
    1011280,
    1011282,
    1011283,
    1011284,
    1011285,
    1011286,
    1011288,
    1023757,
    1023758,
    1023759,
    1023760,
    1023761,
    1023762,
    1023763,
    1023764,
    1023765,
    1023766,
    3165632,
    1023771,
    1023772,
    1023773,
    1023774,
    1023775,
    1023776,
    1023777,
    1023778,
    1023779,
    1023780,
    1023781,
    1023782,
    1023783,
    1023784,
    1023785,
    1023786,
    1023787,
    1023788,
    3165633,
    1023789,
    1023790,
    1023791,
    1023792,
    1023793,
    1023794,
    1023795,
    1023796,
    1023797,
    1023798,
    1023799,
    1023800,
    1023801,
    1023802,
    1023803,
    1023804,
    1023805,
    1023806,
    1023807,
    1023808,
    3165634,
    1010720,
    1010721,
    1010722,
    1010723,
    1010724,
    1010725,
    1010726,
    1010727,
    1010728,
    1010729,
    1010730,
    1010731,
    1010732,
    1010733,
    1010734,
    1010735,
    1010736,
    1010737,
    1010738,
    1010739,
    3165649,
    1010741,
    1010742,
    1010743,
    1010744,
    1010745,
    1010746,
    1010747,
    1010748,
    1010749,
    1010750,
    1010751,
    1010752,
    1010753,
    1010754,
    1010755,
    3165818,
    5660915,
    5660917,
    5660919,
    5660921,
    5660923,
    5754872,
    5754874,
    5754876,
    5754878,
    1030490,
    1030491,
    1030492,
    1030493,
    1030494,
    1030495,
    1030496,
    1030497,
    1030498,
    1030499,
    1030500,
    1030501,
    1030502,
    1030503,
    1030504,
    1030505,
    1030506,
    1030507,
    1030508,
    1030509,
    3168049,
    5666417,
    5666419,
    5666421,
    5666423,
    1325474,
    1325475,
    1325476,
    1325477,
    1325478,
    1325479,
    1325480,
    1325481,
    1325482,
    1325483,
    1325484,
    1325485,
    1325486,
    1325487,
    1325488,
    1325489,
    1325490,
    1325491,
    1325492,
    1325493,
    3589226,
    5445343,
    5445345,
    5445347,
    5445349,
    1335296,
    1335297,
    1335298,
    1335299,
    1335300,
    1335301,
    1335302,
    1335303,
    1335304,
    1335305,
    1335306,
    1335307,
    1335308,
    1335309,
    1335310,
    1335311,
    1335312,
    1335313,
    1335314,
    1335315,
    3593511,
    4577695,
    4577697,
    4577699,
    4577701,
    1337786,
    1337787,
    1337788,
    1337789,
    1337790,
    1337791,
    1337792,
    1337793,
    1337794,
    1337795,
    1337796,
    1337797,
    1337798,
    1337799,
    1337800,
    1337801,
    1337802,
    1337803,
    1337804,
    1337805,
    3593748,
    4531291,
    4531293,
    4531295,
    4531297,
    2470741,
    2470743,
    2470744,
    2470745,
    2470746,
    2470747,
    2470748,
    1025195,
    1025196,
    1025197,
    1025198,
    1025199,
    1025200,
    1025201,
    1025202,
    1025203,
    1025204,
    1025205,
    1025206,
    1025207,
    1025208,
    1025209,
    1025210,
    1025211,
    1025212,
    1025213,
    1025214,
  },
  gilded_brutosaur = {
    1824124,
    1824125,
    1824126,
    1824127,
    1824128,
    1824129,
    1824130,
    1824098,
    1824099,
    1824100,
    1824101,
    1824102,
    1824103,
    1824104,
    1824105,
    1824106,
    1824107,
    1824121,
    1824122,
    1824123,
    1824131,
    1824132,
    1824133,
    1824134,
    1824135,
    1824136,
    1824137,
    1824138,
    2129245,
    2129246,
    2129247,
    2129248,
    2129249,
    1824113,
    1824114,
    1824115,
    1824116,
    1824117,
    1824118,
    1824119,
    1824120,
    1824108,
    1824109,
    1824110,
    1824111,
    1824112,
    801380,
    801382,
    801384,
    801386,
    801388,
    6211349,
    6211351,
    6211353,
    6211355,
    6211357,
    6211359,
    6211361,
    6211363,
    6211365,
    6211367,
    6211369,
    6211371,
    6211373,
    6211375,
    6211377,
    6211431,
    6211433,
    6211435,
    6211437,
    6211439,
    6211441,
    6211443,
    6211445,
    6211447,
    6211449,
    6211389,
    6211391,
    6211393,
    6211395,
    6211397,
    6211399,
    6211401,
    6211403,
    6211379,
    6211381,
    6211383,
    6211385,
    6211387,
    4674601,
    4674603,
    4674605,
    4674607,
    6211425,
    6211427,
    6211429,
    6211405,
    6211407,
    6211409,
    6211411,
    6211413,
    6211415,
    6211417,
    6211419,
    6211421,
    6211423,
    6211670,
    6211672,
    6211674,
    6211676,
    6211678,
    6211680,
    6211682,
    6211684,
    6211686,
    6211688,
    6211690,
    6211692,
    6211694,
    6211696,
    6211698,
    6211700,
    6211702,
    6211704,
    6211706,
    6211708,
    6211710,
    6211712,
    6211714,
    6211716,
    801310,
    801312,
    801314,
    801316,
    801318,
    801320,
    801322,
    801324,
    801326,
    801328,
    2470749,
    2470750,
    2470751,
    2470752,
    2470753,
    2470754,
  },
}

SoundUtils.Registry = {
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
  portal_available = {
    file = "Interface\\AddOns\\isiLive\\sounds\\Portal.ogg",
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
    labelKey = "SETTINGS_SOUND_BATTLE_RES_READY",
    descKey = "SETTINGS_SOUND_BATTLE_RES_READY_DESC",
    labelFallback = "Sound: Battle Res ready",
    descFallback = "Plays a TTS alert when Battle Resurrection becomes available again.",
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
    labelKey = "SETTINGS_SOUND_BLOODLUST_READY",
    descKey = "SETTINGS_SOUND_BLOODLUST_READY_DESC",
    labelFallback = "Sound: Bloodlust ready",
    descFallback = "Plays a TTS alert when Bloodlust or a similar exhaustion effect expires.",
    settingKey = "soundBloodlustReadyEnabled",
    defaultEnabled = true,
    defaultChannel = "Master",
  },
}

SoundUtils.SettingsOrder = {
  "leader_transfer",
  "group_join",
  "portal_available",
  "battle_res",
  "battle_res_ready",
  "bloodlust",
  "bloodlust_ready",
}

local function BuildSoundKey(soundFile, channel, spamScope)
  if type(spamScope) == "string" and spamScope ~= "" then
    return "scope\31" .. spamScope .. "\31" .. tostring(channel or "Master")
  end
  return tostring(soundFile) .. "\31" .. tostring(channel or "Master")
end

function SoundUtils.GetEntry(key)
  if type(key) ~= "string" or key == "" then
    return nil
  end
  local registry = SoundUtils.Registry
  if type(registry) ~= "table" then
    return nil
  end
  local entry = registry[key]
  if type(entry) ~= "table" then
    return nil
  end
  return entry
end

function SoundUtils.HasKey(key)
  return SoundUtils.GetEntry(key) ~= nil
end

function SoundUtils.IsEnabled(key)
  local entry = SoundUtils.GetEntry(key)
  if not entry then
    return false
  end

  local db = rawget(_G, "IsiLiveDB")
  local settingKey = type(entry.settingKey) == "string" and entry.settingKey or nil
  if settingKey and type(db) == "table" then
    local stored = db[settingKey]
    if stored ~= nil then
      return stored == true
    end
  end

  return entry.defaultEnabled ~= false
end

-- Plays a sound file on the configured channel with spam protection.
-- A sound that was played less than SPAM_WINDOW seconds ago is silently dropped.
function SoundUtils.Play(soundFile, channel, spamScope)
  if type(soundFile) ~= "string" or soundFile == "" then
    return false
  end
  local resolvedChannel = type(channel) == "string" and channel ~= "" and channel or "Master"
  local GetTime_ref = rawget(_G, "GetTime")
  local now = type(GetTime_ref) == "function" and GetTime_ref() or 0
  local soundKey = BuildSoundKey(soundFile, resolvedChannel, spamScope)
  local last = lastPlayedAt[soundKey]
  if last and (now - last) < SPAM_WINDOW then
    return false
  end
  local playSoundFile = rawget(_G, "PlaySoundFile")
  if type(playSoundFile) ~= "function" then
    return false
  end
  local ok, accepted = pcall(playSoundFile, soundFile, resolvedChannel)
  if not ok or accepted == false then
    return false
  end
  lastPlayedAt[soundKey] = now
  return true
end

-- Plays a Blizzard SoundKit (numeric ID or SOUNDKIT name) with spam protection
-- on the same window as Play() above. Silently no-ops when the kit name does
-- not resolve in this client (e.g. constant renamed in a future patch).
function SoundUtils.PlaySoundKit(soundKit, channel)
  if soundKit == nil then
    return false
  end
  local resolvedKit = soundKit
  if type(resolvedKit) == "string" then
    local kitTable = rawget(_G, "SOUNDKIT")
    resolvedKit = type(kitTable) == "table" and kitTable[soundKit] or nil
  end
  if resolvedKit == nil then
    return false
  end
  local resolvedChannel = type(channel) == "string" and channel ~= "" and channel or "Master"
  local GetTime_ref = rawget(_G, "GetTime")
  local now = type(GetTime_ref) == "function" and GetTime_ref() or 0
  local soundKey = "kit\31" .. tostring(resolvedKit) .. "\31" .. resolvedChannel
  local last = lastPlayedAt[soundKey]
  if last and (now - last) < SPAM_WINDOW then
    return false
  end
  local playSound = rawget(_G, "PlaySound")
  if type(playSound) ~= "function" then
    return false
  end
  local ok, accepted = pcall(playSound, resolvedKit, resolvedChannel)
  if not ok or accepted == false then
    return false
  end
  lastPlayedAt[soundKey] = now
  return true
end

local function PlayEntry(entry, key)
  if type(entry) ~= "table" then
    return false
  end
  local channel = type(entry.defaultChannel) == "string" and entry.defaultChannel or "Master"
  if entry.soundKit ~= nil then
    return SoundUtils.PlaySoundKit(entry.soundKit, channel)
  end
  local soundFile = entry.file
  if type(soundFile) ~= "string" or soundFile == "" then
    return false
  end
  if SoundUtils.Play(soundFile, channel, key) then
    return true
  end
  local fallbackFile = entry.fallbackFile
  if type(fallbackFile) == "string" and fallbackFile ~= "" then
    return SoundUtils.Play(fallbackFile, channel, key and (key .. ":fallback") or nil)
  end
  return false
end

function SoundUtils.PlayKey(key)
  local entry = SoundUtils.GetEntry(key)
  if not entry or not SoundUtils.IsEnabled(key) then
    return false
  end
  return PlayEntry(entry, key)
end

function SoundUtils.PlayPreviewKey(key)
  return PlayEntry(SoundUtils.GetEntry(key), key and ("preview:" .. key) or nil)
end

function SoundUtils.PlayGroupJoin()
  return SoundUtils.PlayKey("group_join")
end

function SoundUtils.PlayPortalAvailable()
  return SoundUtils.PlayKey("portal_available")
end

function SoundUtils.PlayIncomingSummon()
  return SoundUtils.PlayKey("portal_available")
end

function SoundUtils.PlayBattleRes()
  return SoundUtils.PlayKey("battle_res")
end

function SoundUtils.PlayBattleResReady()
  return SoundUtils.PlayKey("battle_res_ready")
end

function SoundUtils.PlayBloodlust()
  return SoundUtils.PlayKey("bloodlust")
end

function SoundUtils.PlayBloodlustReady()
  return SoundUtils.PlayKey("bloodlust_ready")
end

local function CopySoundFileIDs(key)
  local ids = VIP_MOUNT_SOUND_FILE_IDS[key]
  local copy = {}
  if type(ids) ~= "table" then
    return copy
  end
  for i = 1, #ids do
    copy[i] = ids[i]
  end
  return copy
end

local function ApplyVIPMountSoundSetting(key, muted)
  local ids = VIP_MOUNT_SOUND_FILE_IDS[key]
  if type(ids) ~= "table" then
    return false
  end
  local apiName = muted == true and "MuteSoundFile" or "UnmuteSoundFile"
  local soundApis = {}
  local globalSoundApi = rawget(_G, apiName)
  if type(globalSoundApi) == "function" then
    soundApis[#soundApis + 1] = globalSoundApi
  end
  local cSound = rawget(_G, "C_Sound")
  local cSoundApi = type(cSound) == "table" and cSound[apiName] or nil
  if type(cSoundApi) == "function" and cSoundApi ~= globalSoundApi then
    soundApis[#soundApis + 1] = cSoundApi
  end
  if #soundApis == 0 then
    return false
  end
  for i = 1, #ids do
    for apiIndex = 1, #soundApis do
      soundApis[apiIndex](ids[i])
    end
  end
  return true
end

function SoundUtils.GetAstralAurochsSoundFileIDs()
  return CopySoundFileIDs("astral_aurochs")
end

function SoundUtils.GetGrandExpeditionYakSoundFileIDs()
  return CopySoundFileIDs("grand_expedition_yak")
end

function SoundUtils.GetGildedBrutosaurSoundFileIDs()
  return CopySoundFileIDs("gilded_brutosaur")
end

function SoundUtils.ApplyAstralAurochsSoundSetting(muted)
  return ApplyVIPMountSoundSetting("astral_aurochs", muted)
end

function SoundUtils.ApplyGrandExpeditionYakSoundSetting(muted)
  return ApplyVIPMountSoundSetting("grand_expedition_yak", muted)
end

function SoundUtils.ApplyGildedBrutosaurSoundSetting(muted)
  return ApplyVIPMountSoundSetting("gilded_brutosaur", muted)
end

function SoundUtils.ApplyVIPGuestSoundSettings()
  local db = rawget(_G, "IsiLiveDB")
  local astralMuted = false
  local yakMuted = false
  local brutosaurMuted = false
  if type(db) == "table" and db.vipAstralAurochsSoundMuted ~= nil then
    astralMuted = db.vipAstralAurochsSoundMuted == true
  end
  if type(db) == "table" and db.vipGrandExpeditionYakSoundMuted ~= nil then
    yakMuted = db.vipGrandExpeditionYakSoundMuted == true
  end
  if type(db) == "table" and db.vipGildedBrutosaurSoundMuted ~= nil then
    brutosaurMuted = db.vipGildedBrutosaurSoundMuted == true
  end
  SoundUtils.ApplyAstralAurochsSoundSetting(astralMuted)
  SoundUtils.ApplyGrandExpeditionYakSoundSetting(yakMuted)
  SoundUtils.ApplyGildedBrutosaurSoundSetting(brutosaurMuted)
end
