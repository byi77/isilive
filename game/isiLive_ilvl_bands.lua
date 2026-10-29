local _, addonTable = ...

addonTable = addonTable or {}

local ItemLevelBands = {}
addonTable.ItemLevelBands = ItemLevelBands
local IsSecretValue = addonTable.Validators.IsSecretValue

-- Item level quality bands, derived from the live Mythic+ reward curve.
--
-- The thresholds are the season itself: Blizzard keeps the reward levels per
-- key level current, so the bands move with every season without a code
-- change. There is deliberately no hard-coded fallback table: a snapshot of
-- item levels rots at the next season start and would then paint the wrong
-- colour with full confidence. Without usable reward data the roster shows the
-- item level uncoloured, exactly as before this feature.
--
-- Key levels are chosen, not interpolated: the reward table has holes (a higher
-- key can return a lower reward level), so only these three anchors are read
-- and they must be strictly descending.
local ILVL_BAND_KEY_LEVELS = { 10, 6, 2 }
local ILVL_BAND_QUALITIES = { 4, 3, 2 } -- epic, rare, uncommon
local ILVL_BELOW_FLOOR_QUALITY = 0 -- poor
-- A zero or a near-zero reward level means "no data", never "everyone is epic".
local ILVL_REWARD_PLAUSIBLE_MIN = 200
-- On a cold login the reward levels are not loaded yet. Retry at most this
-- often, a bounded number of times; CHALLENGE_MODE_MAPS_UPDATE resets the
-- budget once the server delivers the season data.
local ILVL_BAND_RETRY_SECONDS = 5
local ILVL_BAND_MAX_ATTEMPTS = 6

local itemLevelBands = nil
local itemLevelBandAttempts = 0
local itemLevelBandLastAttemptAt = nil
local itemLevelBandRequested = false

local function CurrentTime()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return 0
  end
  local ok, now = pcall(getTime)
  if not ok or IsSecretValue(now) or type(now) ~= "number" then
    return 0
  end
  return now
end

local function ReadRewardLevel(keyLevel)
  local mythicPlus = rawget(_G, "C_MythicPlus")
  local getRewardLevel = type(mythicPlus) == "table" and rawget(mythicPlus, "GetRewardLevelFromKeystoneLevel") or nil
  if type(getRewardLevel) ~= "function" then
    return nil
  end
  local ok, rewardLevel = pcall(getRewardLevel, keyLevel)
  if not ok or IsSecretValue(rewardLevel) or type(rewardLevel) ~= "number" then
    return nil
  end
  if rewardLevel < ILVL_REWARD_PLAUSIBLE_MIN then
    return nil
  end
  return rewardLevel
end

local function ReadQualityColorHex(quality)
  local itemApi = rawget(_G, "C_Item")
  local getQualityColor = type(itemApi) == "table" and rawget(itemApi, "GetItemQualityColor") or nil
  if type(getQualityColor) ~= "function" then
    return nil
  end
  local ok, r, g, b = pcall(getQualityColor, quality)
  if not ok or IsSecretValue(r) or IsSecretValue(g) or IsSecretValue(b) then
    return nil
  end
  local channels = { r, g, b }
  for i = 1, 3 do
    local channel = channels[i]
    if type(channel) ~= "number" or channel < 0 or channel > 1 then
      return nil
    end
    channels[i] = math.floor(channel * 255 + 0.5)
  end
  return string.format("ff%02x%02x%02x", channels[1], channels[2], channels[3])
end

-- Highest threshold first; the last row has no threshold and catches all.
local function BuildItemLevelBands()
  local bands = {}
  local previous = nil
  for i = 1, #ILVL_BAND_KEY_LEVELS do
    local threshold = ReadRewardLevel(ILVL_BAND_KEY_LEVELS[i])
    if not threshold or (previous and threshold >= previous) then
      return nil
    end
    previous = threshold
    local hex = ReadQualityColorHex(ILVL_BAND_QUALITIES[i])
    if not hex then
      return nil
    end
    bands[#bands + 1] = { minItemLevel = threshold, colorHex = hex }
  end
  local floorHex = ReadQualityColorHex(ILVL_BELOW_FLOOR_QUALITY)
  if not floorHex then
    return nil
  end
  bands[#bands + 1] = { minItemLevel = nil, colorHex = floorHex }
  return bands
end

local function RequestSeasonRewardData()
  if itemLevelBandRequested then
    return
  end
  itemLevelBandRequested = true
  local mythicPlus = rawget(_G, "C_MythicPlus")
  local requestMapInfo = type(mythicPlus) == "table" and rawget(mythicPlus, "RequestMapInfo") or nil
  if type(requestMapInfo) == "function" then
    pcall(requestMapInfo)
  end
end

local function ResolveItemLevelBands()
  if itemLevelBands then
    return itemLevelBands
  end
  if itemLevelBandAttempts >= ILVL_BAND_MAX_ATTEMPTS then
    return nil
  end
  local now = CurrentTime()
  if itemLevelBandLastAttemptAt and now - itemLevelBandLastAttemptAt < ILVL_BAND_RETRY_SECONDS then
    return nil
  end
  itemLevelBandAttempts = itemLevelBandAttempts + 1
  itemLevelBandLastAttemptAt = now
  itemLevelBands = BuildItemLevelBands()
  if not itemLevelBands then
    RequestSeasonRewardData()
  end
  return itemLevelBands
end

local function BandsSignature(bands)
  if type(bands) ~= "table" then
    return ""
  end
  local parts = {}
  for i = 1, #bands do
    parts[#parts + 1] = tostring(bands[i].minItemLevel) .. "=" .. bands[i].colorHex
  end
  return table.concat(parts, ",")
end

-- Colour (AARRGGBB hex) of an item level on the current season scale, or nil
-- when the item level is not a plain positive number or no season data exists.
function ItemLevelBands.GetColorHex(itemLevel)
  if IsSecretValue(itemLevel) or type(itemLevel) ~= "number" or itemLevel <= 0 then
    return nil
  end
  local bands = ResolveItemLevelBands()
  if not bands then
    return nil
  end
  for i = 1, #bands do
    local minItemLevel = bands[i].minItemLevel
    if minItemLevel == nil or itemLevel >= minItemLevel then
      return bands[i].colorHex
    end
  end
  return nil
end

-- CHALLENGE_MODE_MAPS_UPDATE: season data may have arrived (or changed with a
-- new season). Drop the cache and the retry budget and resolve again right
-- away. Returns true when the colour scale differs from before, so the caller
-- repaints once instead of on every map update.
function ItemLevelBands.Refresh()
  local before = BandsSignature(itemLevelBands)
  itemLevelBands = nil
  itemLevelBandAttempts = 0
  itemLevelBandLastAttemptAt = nil
  -- itemLevelBandRequested stays set: RequestMapInfo itself fires
  -- CHALLENGE_MODE_MAPS_UPDATE, so re-arming it here would make a client that
  -- never gets reward data ping-pong request -> event -> request forever.
  local after = BandsSignature(ResolveItemLevelBands())
  return before ~= after
end
