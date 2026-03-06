local _, addonTable = ...

addonTable = addonTable or {}

local Stats = {}
addonTable.Stats = Stats

local function NormalizeName(name, realm)
  if not name then
    return nil
  end
  local n = tostring(name)
  local r = realm and tostring(realm) or ""
  if r == "" then
    local getRealmName = _G.GetRealmName
    if type(getRealmName) == "function" then
      local ok, realmName = pcall(getRealmName)
      if ok and type(realmName) == "string" then
        r = realmName
      end
    end
  end
  return string.lower(n .. "-" .. r)
end

function Stats.CreateController(opts)
  opts = opts or {}
  local getRoster = opts.getRoster
  local getUnitNameAndRealm = opts.getUnitNameAndRealm

  -- Ensure DB structure exists
  if not IsiLiveDB then
    IsiLiveDB = {}
  end
  if not IsiLiveDB.stats then
    IsiLiveDB.stats = {}
  end
  if not IsiLiveDB.stats.dungeons then
    IsiLiveDB.stats.dungeons = {}
  end
  if not IsiLiveDB.stats.players then
    IsiLiveDB.stats.players = {}
  end

  local controller = {}

  function controller.RecordRun(mapID)
    if not mapID then
      return
    end

    -- 1. Dungeon Count
    local dStats = IsiLiveDB.stats.dungeons
    dStats[mapID] = (dStats[mapID] or 0) + 1

    -- 2. Player Count
    local roster = getRoster and getRoster()
    if roster then
      local pStats = IsiLiveDB.stats.players
      local myName, myRealm = getUnitNameAndRealm("player")
      local myKey = NormalizeName(myName, myRealm)

      for _, info in pairs(roster) do
        -- Don't count yourself
        local targetKey = NormalizeName(info.name, info.realm)
        if targetKey and targetKey ~= myKey then
          pStats[targetKey] = (pStats[targetKey] or 0) + 1
        end
      end
    end
  end

  function controller.GetDungeonCount(mapID)
    if not mapID or not IsiLiveDB or not IsiLiveDB.stats or not IsiLiveDB.stats.dungeons then
      return 0
    end
    return IsiLiveDB.stats.dungeons[mapID] or 0
  end

  function controller.GetPlayerCount(name, realm)
    if not name or not IsiLiveDB or not IsiLiveDB.stats or not IsiLiveDB.stats.players then
      return 0
    end
    local key = NormalizeName(name, realm)
    return IsiLiveDB.stats.players[key] or 0
  end

  function controller.GetUniquePlayersCount()
    if not IsiLiveDB or not IsiLiveDB.stats or not IsiLiveDB.stats.players then
      return 0
    end
    local count = 0
    for _ in pairs(IsiLiveDB.stats.players) do
      count = count + 1
    end
    return count
  end

  function controller.GetTotalDungeonRuns()
    -- Could be calculated if needed
    return 0
  end

  return controller
end
