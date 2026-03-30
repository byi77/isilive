local _, addonTable = ...

addonTable = addonTable or {}

local SoundUtils = {}
addonTable.SoundUtils = SoundUtils

local SPAM_WINDOW = 1.0 -- seconds: ignore duplicate sound within this window
local lastPlayedAt = {} -- soundFile -> timestamp

-- Plays a sound file on the SFX channel with spam protection.
-- A sound that was played less than SPAM_WINDOW seconds ago is silently dropped.
function SoundUtils.Play(soundFile)
  if type(soundFile) ~= "string" or soundFile == "" then
    return
  end
  local GetTime_ref = rawget(_G, "GetTime")
  local now = type(GetTime_ref) == "function" and GetTime_ref() or 0
  local last = lastPlayedAt[soundFile]
  if last and (now - last) < SPAM_WINDOW then
    return
  end
  lastPlayedAt[soundFile] = now
  local playSoundFile = rawget(_G, "PlaySoundFile")
  if type(playSoundFile) == "function" then
    playSoundFile(soundFile, "SFX")
  end
end
