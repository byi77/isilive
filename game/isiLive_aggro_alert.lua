local _, addonTable = ...
addonTable = addonTable or {}

-- Aggro alert for non-tanks (rule 244, K6): a short "AGGRO" notice in the
-- death-alert style (optional sound) when a mob in a running key turns on
-- the player. The probe of 2026-11-12 found UnitThreatSituation("player")
-- readable in a key (0..3, never secret); without a second unit it returns
-- the player's highest status over all enemies, so no nameplate scan is
-- needed. 2 = tanking without the top threat, 3 = securely tanking.
--
-- Rules: only in a running key, never in a raid, never for a player whose
-- verified own spec is a tank, not while the group's tank is dead (then
-- everybody has aggro), at most once per pull, and only after the status
-- held for HOLD_SECONDS (a mob that taps the player once does not alert).
-- Setting aggroAlertEnabled (Pattern B, default off), sound aggroAlertSound
-- (Pattern B).
--
-- Own event frame (installed from the factory at load, never from a
-- protected dispatch). UNIT_THREAT_SITUATION_UPDATE is registered for
-- "player" only, and only while a key runs with the alert on; the listening
-- state is re-checked at every pull start and key edge.
local AggroAlert = {}
addonTable.AggroAlert = AggroAlert

local HOLD_SECONDS = 0.5
local AGGRO_STATUS = 2
local PARTY_UNITS = { "party1", "party2", "party3", "party4" }
local STATIC_EVENTS = {
  "PLAYER_ENTERING_WORLD",
  "CHALLENGE_MODE_START",
  "CHALLENGE_MODE_COMPLETED",
  "CHALLENGE_MODE_RESET",
  "PLAYER_REGEN_DISABLED",
}

local IsSecretValue = addonTable.Validators.IsSecretValue

local eventFrame = nil
local listening = false
local alertedThisPull = false
local holdToken = 0
local showAlert = nil

local function GetDB()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db or nil
end

--- Pattern B: off unless the player switched it on.
function AggroAlert.IsEnabled()
  local db = GetDB()
  return db ~= nil and db.aggroAlertEnabled == true
end

local function ReadPlain(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok or IsSecretValue(value) then
    return nil
  end
  return value
end

local function IsKeyActive()
  local challengeMode = rawget(_G, "C_ChallengeMode")
  local mapID = type(challengeMode) == "table" and ReadPlain(challengeMode.GetActiveChallengeMapID) or nil
  return type(mapID) == "number" and mapID > 0
end

local function IsRaid()
  local runtimeMode = addonTable.RuntimeMode
  return type(runtimeMode) == "table"
    and type(runtimeMode.IsRaidContext) == "function"
    and runtimeMode.IsRaidContext() == true
end

local function RoleOf(unit)
  local units = addonTable.Units
  if type(units) == "table" and type(units.GetUnitRole) == "function" then
    return units.GetUnitRole(unit)
  end
  return "NONE"
end

-- A dead or ghost tank of the group: everybody has aggro then.
local function IsGroupTankDead()
  local isDead = rawget(_G, "UnitIsDeadOrGhost")
  for _, unit in ipairs(PARTY_UNITS) do
    if RoleOf(unit) == "TANK" and ReadPlain(isDead, unit) == true then
      return true
    end
  end
  return false
end

-- Own role from the active specialization (verified, unlike the assigned
-- group role); the shared unit helper is the fallback.
local function OwnRole()
  local specIndex = ReadPlain(rawget(_G, "GetSpecialization"))
  if type(specIndex) == "number" and specIndex > 0 then
    local role = ReadPlain(rawget(_G, "GetSpecializationRole"), specIndex)
    if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
      return role
    end
  end
  return RoleOf("player")
end

local function HasAggro()
  local status = ReadPlain(rawget(_G, "UnitThreatSituation"), "player")
  return type(status) == "number" and status >= AGGRO_STATUS
end

local function MayAlert()
  return not alertedThisPull
    and AggroAlert.IsEnabled()
    and IsKeyActive()
    and not IsRaid()
    and OwnRole() ~= "TANK"
    and not IsGroupTankDead()
end

local function UpdateListening()
  if not eventFrame then
    return
  end
  local listen = AggroAlert.IsEnabled() and IsKeyActive() and not IsRaid()
  if listen == listening then
    return
  end
  if listen then
    eventFrame:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
  else
    eventFrame:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")
  end
  listening = listen
end

-- After the hold time: still aggro and still allowed -> one alert this pull.
local function Evaluate(token)
  if token ~= holdToken or not MayAlert() or not HasAggro() then
    return
  end
  alertedThisPull = true
  if type(showAlert) == "function" then
    showAlert()
  end
end

local function OnThreatChanged()
  if not MayAlert() or not HasAggro() then
    holdToken = holdToken + 1
    return
  end
  holdToken = holdToken + 1
  local token = holdToken
  local timer = rawget(_G, "C_Timer")
  if type(timer) == "table" and type(timer.After) == "function" then
    timer.After(HOLD_SECONDS, function()
      Evaluate(token)
    end)
  end
end

function AggroAlert.HandleEvent(event, unit)
  if event == "UNIT_THREAT_SITUATION_UPDATE" then
    if unit == "player" then
      OnThreatChanged()
    end
    return
  end
  if event == "PLAYER_REGEN_DISABLED" or event == "CHALLENGE_MODE_START" then
    alertedThisPull = false
    holdToken = holdToken + 1
  end
  UpdateListening()
end

--- Creates the event frame. opts.show() shows the alert (factory: death
--- alert kind AGGRO plus the optional sound).
function AggroAlert.Install(opts)
  showAlert = type(opts) == "table" and opts.show or nil
  if eventFrame then
    return true
  end
  local createFrame = rawget(_G, "CreateFrame")
  if type(createFrame) ~= "function" then
    return false
  end
  local ok, frame = pcall(createFrame, "Frame")
  if not ok or type(frame) ~= "table" then
    return false
  end
  frame:SetScript("OnEvent", function(_, event, arg1)
    AggroAlert.HandleEvent(event, arg1)
  end)
  for _, event in ipairs(STATIC_EVENTS) do
    frame:RegisterEvent(event)
  end
  eventFrame = frame
  UpdateListening()
  return true
end
