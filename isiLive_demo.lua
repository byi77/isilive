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

  local roster = {
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
  }

  local dummies = {
    tank = {
      name = "Atabey",
      language = "DE",
      class = "WARRIOR",
      role = "TANK",
      spec = "Protection",
      ilvl = 166,
      rio = 3850,
    },
    healer = {
      name = "Nisan",
      language = "DE",
      class = "PRIEST",
      role = "HEALER",
      spec = "Holy",
      ilvl = 169,
      rio = 3810,
    },
    dd1 = {
      name = "PumperDPS",
      language = "EN",
      class = "MAGE",
      role = "DAMAGER",
      spec = "Frost",
      ilvl = 170,
      rio = 3955,
    },
    dd2 = {
      name = "Bircan",
      language = "EN",
      class = "ROGUE",
      role = "DAMAGER",
      spec = "Outlaw",
      ilvl = 164,
      rio = 3780,
    },
    dd3 = {
      name = "KÜrshad",
      language = "EN",
      class = "HUNTER",
      role = "DAMAGER",
      spec = "Marksman",
      ilvl = 164,
      rio = 3890,
    },
  }

  local fill = {}
  if playerRole == "TANK" then
    table.insert(fill, dummies.healer)
    table.insert(fill, dummies.dd1)
    table.insert(fill, dummies.dd2)
    table.insert(fill, dummies.dd3)
  elseif playerRole == "HEALER" then
    table.insert(fill, dummies.tank)
    table.insert(fill, dummies.dd1)
    table.insert(fill, dummies.dd2)
    table.insert(fill, dummies.dd3)
  else
    -- DAMAGER or NONE
    table.insert(fill, dummies.tank)
    table.insert(fill, dummies.healer)
    table.insert(fill, dummies.dd1)
    table.insert(fill, dummies.dd2)
  end

  for i, member in ipairs(fill) do
    roster["party" .. i] = member
  end

  return roster
end
