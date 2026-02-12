local _, addonTable = ...

addonTable = addonTable or {}

local Demo = {}
addonTable.Demo = Demo

function Demo.BuildDummyRoster(opts)
  opts = opts or {}

  local getUnitNameAndRealm = opts.getUnitNameAndRealm
    or function(unit)
      local name, realm = UnitFullName(unit)
      if not name then
        name = UnitName(unit)
      end
      if not realm or realm == "" then
        realm = GetRealmName() or ""
      end
      return name, realm
    end
  local getUnitServerLanguage = opts.getUnitServerLanguage or function(_unit, _realm)
    return "??"
  end
  local getUnitRole = opts.getUnitRole or function(_unit)
    return "DAMAGER"
  end
  local getPlayerSpecName = opts.getPlayerSpecName or function()
    return nil
  end
  local getUnitRio = opts.getUnitRio or function(_unit)
    return nil
  end

  local playerName, playerRealm = getUnitNameAndRealm("player")
  local _, playerClass = UnitClass("player")
  local playerLanguage = getUnitServerLanguage("player", playerRealm)
  local playerRole = getUnitRole("player")
  local playerSpec = getPlayerSpecName()
  local playerRio = getUnitRio("player")

  local playerIlvl = nil
  if C_Item and C_Item.GetAverageItemLevel then
    local avgIlvl = C_Item.GetAverageItemLevel()
    if type(avgIlvl) == "number" and avgIlvl > 0 then
      playerIlvl = avgIlvl
    end
  elseif GetAverageItemLevel then
    local avgIlvl, equippedIlvl = GetAverageItemLevel()
    local resolvedIlvl = equippedIlvl or avgIlvl
    if type(resolvedIlvl) == "number" and resolvedIlvl > 0 then
      playerIlvl = resolvedIlvl
    end
  end

  return {
    ["player"] = {
      name = playerName or UnitName("player") or "Player",
      realm = playerRealm or GetRealmName() or "",
      language = playerLanguage or "??",
      class = playerClass or "WARRIOR",
      role = playerRole or "DAMAGER",
      spec = playerSpec,
      ilvl = playerIlvl,
      rio = playerRio,
      hasIsiLive = true,
    },
    ["party1"] = {
      name = "HealBot",
      language = "DE",
      class = "PRIEST",
      role = "HEALER",
      spec = "Holy",
      ilvl = 158,
      rio = 3810,
    },
    ["party2"] = {
      name = "PumperDPS",
      language = "EN",
      class = "MAGE",
      role = "DAMAGER",
      spec = "Frost",
      ilvl = 166,
      rio = 3955,
    },
    ["party3"] = {
      name = "LazyRogue",
      language = "EN",
      class = "ROGUE",
      role = "DAMAGER",
      spec = "Outlaw",
      ilvl = 161,
      rio = 3875,
    },
    ["party4"] = {
      name = "Huntard",
      language = "EN",
      class = "HUNTER",
      role = "DAMAGER",
      spec = "Marksman",
      ilvl = 167,
      rio = 4090,
    },
  }
end
