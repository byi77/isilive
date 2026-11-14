---@diagnostic disable: undefined-global

-- Builds the minimal WoW global stubs needed to load isiLive_lfg_detect.lua.
-- Returns a fire(event, ...) helper that invokes the captured OnEvent handler.
local function BuildLFGDetectEnv(overrides)
  overrides = overrides or {}

  local onEvent = nil
  local prints = {}

  local globals = {
    CreateFrame = function()
      return {
        RegisterEvent = function() end,
        SetScript = function(_, scriptType, fn)
          if scriptType == "OnEvent" then
            onEvent = fn
          end
        end,
      }
    end,
    C_Timer = {
      -- Suppress the 5s ticker so tests control when CheckActiveGroup runs.
      NewTicker = function() end,
    },
    DEFAULT_CHAT_FRAME = {
      AddMessage = function(_, msg)
        table.insert(prints, tostring(msg))
      end,
    },
    IsInGroup = overrides.IsInGroup or function()
      return false
    end,
    IsInRaid = overrides.IsInRaid or function()
      return false
    end,
    GetNumGroupMembers = overrides.GetNumGroupMembers or function()
      return 0
    end,
  }

  -- Merge any extra globals the caller needs.
  if overrides.globals then
    for k, v in pairs(overrides.globals) do
      globals[k] = v
    end
  end

  return globals,
    function(event, ...)
      local addon = rawget(_G, "__isilive_last_loaded_addon")
      if addon and addon.LFGDetect and type(addon.LFGDetect.HandleEvent) == "function" then
        addon.LFGDetect.HandleEvent(event, ...)
      elseif onEvent then
        onEvent(nil, event, ...)
      end
    end,
    prints
end

return BuildLFGDetectEnv
