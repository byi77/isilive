local _, addonTable = ...
addonTable = addonTable or {}

-- Season evaluation for the event handlers (rules 97 and 250), split out of
-- factory/isiLive_controller_wiring.lua. Create returns the
-- refreshActiveSeasonFromBlizzard callback the event handlers call on
-- PLAYER_LOGIN, CHALLENGE_MODE_MAPS_UPDATE and PLAYER_REGEN_ENABLED.
local SeasonRefresh = {}
addonTable.SeasonRefresh = SeasonRefresh

-- `config` is the event-handler config (logRuntimeTracef is read at call
-- time), `deps` the wiring deps (showSeasonUnrecognizedNotice), `controllers`
-- and `callbacks` the wiring tables (teleport rebuild, updateUI).
function SeasonRefresh.Create(config, deps, controllers, callbacks)
  -- PLAYER_LOGIN and CHALLENGE_MODE_MAPS_UPDATE own the season evaluation;
  -- PLAYER_REGEN_ENABLED only catches up an evaluation that is still pending
  -- (skipped in combat, or no usable map table yet). It used to re-run the
  -- full season validation at the end of every single fight. A conclusive
  -- rejection (no exact match, ambiguous set, season not ready) is not pending:
  -- its inputs only change with a new map list, which fires
  -- CHALLENGE_MODE_MAPS_UPDATE, or with a new addon build.
  local seasonRefreshPending = true
  -- Rule 250: the off-season state needs a server answer
  -- (CHALLENGE_MODE_MAPS_UPDATE). RequestMapInfo asks for it once per session;
  -- without it the event only arrives when something else requests the data.
  local mapInfoRequested = false
  local seasonUnrecognizedNoticeShown = false
  return function(eventName)
    if eventName == "PLAYER_REGEN_ENABLED" and not seasonRefreshPending then
      return false
    end
    local seasonData = addonTable.SeasonData
    -- The roster's item level colours hang on the season reward curve, which
    -- arrives (or changes) with this event. Repaint only when the scale moved.
    local itemLevelBands = addonTable.ItemLevelBands
    if
      eventName == "CHALLENGE_MODE_MAPS_UPDATE"
      and type(itemLevelBands) == "table"
      and type(itemLevelBands.Refresh) == "function"
      and itemLevelBands.Refresh()
      and type(callbacks.updateUI) == "function"
    then
      callbacks.updateUI()
    end
    local challengeMode = rawget(_G, "C_ChallengeMode")
    local getMapTable = type(challengeMode) == "table" and rawget(challengeMode, "GetMapTable") or nil
    if
      type(seasonData) ~= "table"
      or type(seasonData.TryAutoSelectSeasonFromChallengeMapIDs) ~= "function"
      or type(getMapTable) ~= "function"
    then
      return false
    end

    local inCombatLockdown = rawget(_G, "InCombatLockdown")
    if type(inCombatLockdown) == "function" then
      local okCombat, inCombat = pcall(inCombatLockdown)
      if not okCombat or inCombat == true then
        seasonRefreshPending = true
        return false
      end
    end

    if eventName == "PLAYER_LOGIN" and not mapInfoRequested then
      mapInfoRequested = true
      local mythicPlus = rawget(_G, "C_MythicPlus")
      local requestMapInfo = type(mythicPlus) == "table" and rawget(mythicPlus, "RequestMapInfo") or nil
      if type(requestMapInfo) == "function" then
        pcall(requestMapInfo)
      end
    end

    local okMaps, mapIDs = pcall(getMapTable)
    if not okMaps or type(mapIDs) ~= "table" then
      seasonRefreshPending = true
      return false
    end

    local getState = seasonData.GetBlizzardSeasonState
    local stateBefore = type(getState) == "function" and getState() or nil
    local selectOpts = { serverConfirmed = eventName == "CHALLENGE_MODE_MAPS_UPDATE" }
    local ok, changed, message, retryable = seasonData.TryAutoSelectSeasonFromChallengeMapIDs(mapIDs, selectOpts)
    local stateAfter = type(getState) == "function" and getState() or nil
    seasonRefreshPending = ok ~= true and retryable == true
    if type(config.logRuntimeTracef) == "function" then
      config.logRuntimeTracef(
        "[SEASON] auto_select event=%s ok=%s changed=%s active=%s state=%s reason=%s",
        tostring(eventName),
        tostring(ok),
        tostring(changed),
        tostring(seasonData.GetActiveSeasonID and seasonData.GetActiveSeasonID() or nil),
        tostring(stateAfter),
        tostring(message)
      )
    end
    local stateChanged = stateAfter ~= stateBefore
    if
      stateChanged
      and stateAfter == "unrecognized"
      and not seasonUnrecognizedNoticeShown
      and type(deps.showSeasonUnrecognizedNotice) == "function"
    then
      seasonUnrecognizedNoticeShown = true
      deps.showSeasonUnrecognizedNotice()
    end
    if not (ok and changed) then
      if stateChanged and type(callbacks.updateUI) == "function" then
        callbacks.updateUI()
      end
      return false
    end

    if controllers.teleport and type(controllers.teleport.BuildButtons) == "function" then
      controllers.teleport.BuildButtons()
    end
    if type(callbacks.updateUI) == "function" then
      callbacks.updateUI()
    end
    return true
  end
end

-- Rule 250: one chat line per session when Blizzard's challenge map list
-- matches no configured season (the addon needs an update).
function SeasonRefresh.BuildUnrecognizedNotice(ctx)
  return function()
    local L = type(ctx.getL) == "function" and ctx.getL() or nil
    local line = type(L) == "table" and L.SEASON_UNRECOGNIZED_NOTICE or nil
    if type(line) ~= "string" or line == "" then
      line = "isiLive does not know the current Mythic+ season - please update isiLive."
    end
    if type(ctx.printFn) == "function" then
      ctx.printFn("|cffffd200" .. line .. "|r")
    end
  end
end
