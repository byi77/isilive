local _, addonTable = ...
addonTable = addonTable or {}

-- Live kicks of the running key (rule 245, K9): the landed interrupts are
-- read from the damage meter's Overall session when a pull in a key ends --
-- the moment the probe key of 2026-11-12 found it readable -- and once more
-- when the next pull starts, which picks up interrupts the meter booked late.
-- No timer: a masked or unreadable read simply keeps the previous count.
-- Own event frame, created at load; setting liveRunKicksEnabled (Pattern A).
local FactoryLiveKicks = {}
addonTable.FactoryLiveKicks = FactoryLiveKicks

local function IsKeyActive()
  local challengeMode = rawget(_G, "C_ChallengeMode")
  local getMapID = type(challengeMode) == "table" and challengeMode.GetActiveChallengeMapID or nil
  if type(getMapID) ~= "function" then
    return false
  end
  local ok, mapID = pcall(getMapID)
  return ok and not addonTable.Validators.IsSecretValue(mapID) and type(mapID) == "number" and mapID > 0
end

--- Installs the between-pull read for ctx.statsController. Returns the event
--- frame or nil.
function FactoryLiveKicks.Install(ctx)
  local stats = ctx and ctx.statsController
  local createFrame = rawget(_G, "CreateFrame")
  if type(stats) ~= "table" or type(stats.CaptureLiveKicks) ~= "function" or type(createFrame) ~= "function" then
    return nil
  end
  local frame = createFrame("Frame")
  frame:SetScript("OnEvent", function()
    local db = rawget(_G, "IsiLiveDB")
    if (type(db) == "table" and db.liveRunKicksEnabled == false) or not IsKeyActive() then
      return
    end
    stats.CaptureLiveKicks()
  end)
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  return frame
end
