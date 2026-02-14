local _, addonTable = ...

addonTable = addonTable or {}

local Units = {}
addonTable.Units = Units

function Units.GetUnitRole(unit)
  local role = UnitGroupRolesAssigned(unit)
  if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
    return role
  end

  -- Fallback for player: use current specialization role if group role is not set
  if UnitIsUnit(unit, "player") and GetSpecialization and GetSpecializationRole then
    local specIndex = GetSpecialization()
    if specIndex then
      role = GetSpecializationRole(specIndex)
      if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
        return role
      end
    end
  end

  return "NONE"
end

function Units.TruncateName(name, maxChars)
  if not name then
    return ""
  end
  maxChars = maxChars or 10

  local utf8len = rawget(_G, "utf8len")
  local utf8sub = rawget(_G, "utf8sub")
  if utf8len and utf8sub then
    if utf8len(name) > maxChars then
      return utf8sub(name, 1, maxChars)
    end
    return name
  end

  if string.len(name) > maxChars then
    return string.sub(name, 1, maxChars)
  end
  return name
end

function Units.GetUnitNameAndRealm(unit)
  local name, realm = UnitFullName(unit)
  if not name then
    name = UnitName(unit)
  end
  if not realm or realm == "" then
    realm = GetRealmName() or ""
  end
  return name, realm
end

function Units.GetPlayerSpecName()
  if not GetSpecialization or not GetSpecializationInfo then
    return nil
  end
  local specIndex = GetSpecialization()
  if not specIndex or specIndex <= 0 then
    return nil
  end
  local _, specName = GetSpecializationInfo(specIndex)
  return specName
end

function Units.GetInspectSpecName(unit)
  if not unit or not GetInspectSpecialization or not GetSpecializationInfoByID then
    return nil
  end
  local specID = GetInspectSpecialization(unit)
  if not specID or specID <= 0 then
    return nil
  end
  local _, specName = GetSpecializationInfoByID(specID)
  return specName
end

function Units.GetUnitRio(unit)
  if not unit or not UnitExists(unit) then
    return nil
  end
  if not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
    return nil
  end

  local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
  if ok and summary then
    local currentSeasonScore = rawget(summary, "currentSeasonScore")
    local currentSeasonBestScore = rawget(summary, "currentSeasonBestScore")
    local rating = rawget(summary, "rating")
    local score = rawget(summary, "score")

    if currentSeasonScore then
      return currentSeasonScore
    end
    if currentSeasonBestScore then
      return currentSeasonBestScore
    end
    if rating then
      return rating
    end
    if score then
      return score
    end
  end

  return nil
end
