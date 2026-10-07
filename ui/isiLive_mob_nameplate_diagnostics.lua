local _, addonTable = ...
addonTable = addonTable or {}

-- Read-only diagnostics surface of the MobNameplate overlay. The facade in
-- ui/isiLive_mob_nameplate.lua owns every piece of runtime state and injects
-- it here: the live `frames` / `appearance` tables by reference, the scalar
-- mode flags through `getState()`, and the resolver helpers as functions. This
-- module never mutates any of them; it only builds the dump tables that
-- `MobNameplate.DumpFrames` / `MobNameplate.DumpState` return.
local MobNameplateDiagnostics = {}
addonTable.MobNameplateDiagnostics = MobNameplateDiagnostics

local IsSecretValue = addonTable.Validators.IsSecretValue

-- Reads font file/height/flags and the rendered text of an overlay FontString
-- into `target`. Every getter is pcall-protected because the FontString may be
-- mid-teardown when a diagnostic slash command runs.
local function ReadFontStringInto(target, fontString)
  if type(fontString.GetFont) == "function" then
    local okFont, file, height, flags = pcall(fontString.GetFont, fontString)
    if okFont then
      target.fontFile = file
      target.fontHeight = height
      target.fontFlags = flags
    end
  end
  if type(fontString.GetText) == "function" then
    local okText, txt = pcall(fontString.GetText, fontString)
    if okText then
      target.fontStringText = txt
    end
  end
end

function MobNameplateDiagnostics.Create(deps)
  local frames = deps.frames
  local appearance = deps.appearance
  local getState = deps.getState
  local HasNamePlateAPI = deps.hasNamePlateAPI
  local HasProgressAPI = deps.hasProgressAPI
  local IsEligibleUnit = deps.isEligibleUnit
  local NpcIdFromGuid = deps.npcIdFromGuid
  local GetForcesDB = deps.getForcesDB
  local ResolveMobContributionFromDB = deps.resolveMobContributionFromDB
  local ResolveRemainingPercent = deps.resolveRemainingPercent
  local BuildText = deps.buildText
  local SafeCall = deps.safeCall

  -- Thin wrappers keep the facade's pcall-protected challenge helpers under
  -- their original names, so the Secret-Value gate sees file-local helpers.
  local function IsChallengeModeActive()
    return deps.challengeActive()
  end

  local function GetActiveChallengeMapID()
    return deps.activeMapID()
  end

  -- Inspects every active nameplate frame and returns one row per frame with
  -- the actually-rendered font height, text, frame size etc. Used to verify
  -- whether the slider value truly hits the FontString in M+ keys (where the
  -- per-unit data path is masked but the rendering may still be happening).
  local function DumpFrames()
    local rows = {}
    for unit, frame in pairs(frames) do
      local row = { unit = unit }
      if frame and type(frame) == "table" then
        row.frameShown = type(frame.IsShown) == "function" and frame:IsShown() == true or false
        if type(frame.GetSize) == "function" then
          local okSize, w, h = pcall(frame.GetSize, frame)
          if okSize then
            row.frameWidth = w
            row.frameHeight = h
          end
        end
        if frame.text then
          ReadFontStringInto(row, frame.text)
        end
      end
      rows[#rows + 1] = row
    end
    local state = getState()
    return {
      enabled = state.enabled,
      testMode = state.testMode,
      testActiveMapID = state.testActiveMapID,
      appearanceFontSize = appearance.fontSize,
      frameCount = #rows,
      frames = rows,
    }
  end

  -- Diagnostic dump for the live data path. `unit` defaults to "target".
  -- Returns a table with the resolved values at every gate so a slash command
  -- can print why a nameplate text might be missing or off-size in real keys.
  local function DumpState(unit)
    unit = type(unit) == "string" and unit ~= "" and unit or "target"

    local state = getState()
    local out = {
      unit = unit,
      enabled = state.enabled,
      testMode = state.testMode,
      testActiveMapID = state.testActiveMapID,
      appearanceFontSize = appearance.fontSize,
      hasNamePlateAPI = HasNamePlateAPI(),
      hasProgressAPI = HasProgressAPI(),
      challengeActive = IsChallengeModeActive(),
      -- secret-value-ok: file-local helper is pcall-protected.
      activeMapID = state.testMode and state.testActiveMapID or GetActiveChallengeMapID(),
      eligible = IsEligibleUnit(unit),
    }

    local unitGUIDFn = rawget(_G, "UnitGUID")
    if out.eligible and type(unitGUIDFn) == "function" then
      local okGuid, guid = pcall(unitGUIDFn, unit)
      if okGuid then
        out.guidIsSecret = IsSecretValue(guid)
        out.guid = out.guidIsSecret and "<secret>" or guid
        out.npcId = NpcIdFromGuid(guid)
      end
    end

    -- Probe the tooltip data path. The unit's own GUID comes back masked in
    -- restricted instances, but the GUID Blizzard hands to tooltip consumers does
    -- not -- that is why the tooltip forces line still works while the nameplate
    -- one does not. If C_TooltipInfo.GetUnit answers with a readable guid here,
    -- the nameplate can be fed from the same source.
    local tooltipInfo = rawget(_G, "C_TooltipInfo")
    local getUnitTooltip = type(tooltipInfo) == "table" and rawget(tooltipInfo, "GetUnit") or nil
    out.tooltipApi = type(getUnitTooltip) == "function"
    if out.eligible and out.tooltipApi then
      local okData, data = pcall(getUnitTooltip, unit)
      out.tooltipData = okData and type(data) == "table"
      if out.tooltipData then
        local candidate = data.guid
        out.tooltipGuidSecret = IsSecretValue(candidate)
        if not out.tooltipGuidSecret and type(candidate) == "string" then
          out.tooltipGuid = candidate
          out.tooltipNpcId = NpcIdFromGuid(candidate)
        else
          out.tooltipGuid = "<secret>"
        end
      end
    end

    local unitNameFn = rawget(_G, "UnitName")
    if out.eligible and type(unitNameFn) == "function" then
      local okName, name = pcall(unitNameFn, unit)
      if okName then
        out.unitNameSecret = IsSecretValue(name)
        out.unitName = out.unitNameSecret and "<secret>" or name
      end
    end

    local db = GetForcesDB()
    if type(db) == "table" and out.npcId then
      out.dbHasByNpcId = type(db.byNpcId) == "table"
      if type(db.byNpcId) == "table" then
        local entry = db.byNpcId[out.npcId]
        out.dbEntry = entry
        if type(entry) == "table" and out.activeMapID then
          out.dbEntryMatchesMap = entry.mapID == out.activeMapID
        end
      end
      if type(db.dungeonTotal) == "table" and out.activeMapID then
        out.dbDungeonTotal = db.dungeonTotal[out.activeMapID]
      end
    end

    local dbPercent = ResolveMobContributionFromDB(unit, out.activeMapID)
    out.dbPercent = dbPercent

    -- Diagnostic: try the API regardless of eligibility so we can see what it
    -- returns in M+ tainted context. Redact the value if it comes back as a
    -- Secret Value so the resulting line does not get filtered out by chat
    -- copy/paste tools.
    if HasProgressAPI() then
      local api = rawget(_G, "C_ScenarioInfo")
      local _, _, apiPercent = SafeCall(api.GetUnitCriteriaProgressValues, unit)
      out.apiPercentSecret = IsSecretValue(apiPercent)
      out.apiPercentRaw = apiPercent
      out.apiPercent = out.apiPercentSecret and "<secret>" or apiPercent
    end

    -- Mirror what UpdateNameplate actually does, including the part that matters
    -- most in a key: a masked API value IS passed through to the FontString, which
    -- can render it even though Lua may not inspect it. The earlier version of this
    -- diagnostic dropped masked values and therefore reported resolvedPercent=nil
    -- for a case the real path would have displayed -- which read like "the feature
    -- cannot work" when the actual reason was simply that it was switched off.
    local percentString = dbPercent
    local resolvedIsSecret = false
    if percentString == nil and out.apiPercentRaw ~= nil then
      percentString = out.apiPercentRaw
      resolvedIsSecret = out.apiPercentSecret == true
    end
    out.resolvedFromMaskedApi = resolvedIsSecret
    out.resolvedPercent = resolvedIsSecret and "<secret, would render>" or percentString
    out.remainingPercent = ResolveRemainingPercent(out.activeMapID)
    out.resolvedText = resolvedIsSecret and "<secret, would render>" or BuildText(percentString, out.remainingPercent)

    local frame = frames[unit]
    if frame then
      out.frameExists = true
      out.frameShown = frame.IsShown and frame:IsShown() == true or false
      out.anchorSource = frame._isiLiveAnchorSource
      if frame.text then
        ReadFontStringInto(out, frame.text)
      end
    else
      out.frameExists = false
    end

    return out
  end

  return {
    DumpFrames = DumpFrames,
    DumpState = DumpState,
  }
end

return MobNameplateDiagnostics
