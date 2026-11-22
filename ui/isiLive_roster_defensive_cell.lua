local _, addonTable = ...
addonTable = addonTable or {}

-- Defensives cell of the M+ roster (rule 269, vorhaben V1 stage 2).
--
-- While a key runs and the defensive tracker is on, a 70 px cell (two slots
-- of 34 px: icon 14 + gap 2 + text 18) takes the place of the DPS column; the
-- RIO column shrinks to 54 px and drops its "(+N)" delta, the kick column
-- stays. Outside a key, with the tracker off, in the compact layouts and in
-- the run focus (the cell is a child of the main frame) nothing changes.
--
-- Slot states (externals before group cooldowns before personal ones):
--   ready      bright icon, no text                         (own / sync)
--   cooldown   grey icon, seconds, "Xm" from 100 s on         (own / sync)
--   active     cool blue border with an alpha pulse, seconds  (own / sync)
--   frozen     isiLive sync while the own addon chat is locked down: dimmed
--              icon and a clock glyph instead of seconds
--   estimated  members without an isiLive state (rule 268): "~", the
--              remaining estimated cooldown as a dark fill over the icon and,
--              while the buff runs, Blizzard's own aura icon with its
--              duration and the pulsing blue border
-- The full list, the source and its age are in the row tooltip.
--
-- Demo source (rule 270, tablet action C14): while a demo provider is set the
-- cell is active without the tracker setting or a running key and reads every
-- row only from the provider -- never from DefensiveStore or the sensors. Its
-- estimate slots draw a plain Lua share into the fill bar.
local RosterDefensiveCell = {}
addonTable.RosterDefensiveCell = RosterDefensiveCell

local RI = addonTable._RosterInternal or {}
addonTable._RosterInternal = RI
RI.RosterDefensiveCell = RosterDefensiveCell

local IsSecretValue = addonTable.Validators.IsSecretValue

local ICON_SIZE = 14
local TEXT_OFFSET = 2
local TEXT_WIDTH = 18
local SLOT_WIDTH = ICON_SIZE + TEXT_OFFSET + TEXT_WIDTH -- 34
local SLOT_GAP = 2
local CELL_WIDTH = 2 * SLOT_WIDTH + SLOT_GAP -- 70
local ROW_HEIGHT = 16
local RIO_COL_X = RI.RIO_COL_X or 318
local RIO_COL_WIDTH = RI.RIO_COL_WIDTH or 84
local KICK_COL_X = RI.KICK_COL_X or 448
-- The cell ends 2 px left of the kick column; RIO keeps a 4 px gap to it.
local CELL_RIGHT = KICK_COL_X - 2
local CELL_X = CELL_RIGHT - CELL_WIDTH
local RIO_KEY_WIDTH = CELL_X - 4 - RIO_COL_X -- 54

RosterDefensiveCell.ICON_SIZE = ICON_SIZE
RosterDefensiveCell.SLOT_WIDTH = SLOT_WIDTH
RosterDefensiveCell.CELL_WIDTH = CELL_WIDTH
RosterDefensiveCell.CELL_X = CELL_X
RosterDefensiveCell.RIO_KEY_WIDTH = RIO_KEY_WIDTH

local MEDIA = "Interface\\AddOns\\isiLive\\media\\"
local CLOCK_TEXTURE = MEDIA .. "defensive_clock"
local BORDER_TEXTURE = MEDIA .. "defensive_border"
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ESTIMATE_MARK = "~"

local COLORS = {
  cdText = { 0.92, 0.92, 0.92, 1 },
  activeText = { 0.55, 0.82, 1, 1 },
  estimateText = { 0.78, 0.82, 0.88, 1 },
  border = { 0.35, 0.7, 1, 1 },
  clock = { 0.62, 0.7, 0.8, 0.9 },
  estimateFill = { 0, 0, 0, 0.65 },
}

local KIND_KEYS = {
  external = { "DEF_KIND_EXTERNAL", "external" },
  raid = { "DEF_KIND_RAID", "group" },
  personal = { "DEF_KIND_PERSONAL", "personal" },
}

local rendered = {} -- [row] = { info, mainFrame, index }
local lastActive = nil
local demoProvider = nil

local function ReadDB()
  local db = rawget(_G, "IsiLiveDB")
  return type(db) == "table" and db or nil
end

local function CallRuntime(name)
  local runtimeMode = addonTable.RuntimeMode
  local fn = type(runtimeMode) == "table" and runtimeMode[name] or nil
  if type(fn) ~= "function" then
    return false
  end
  local ok, value = pcall(fn)
  return ok and value == true
end

--- Sets (function) or clears (nil) the demo source. The provider answers
-- provider(playerKey, now) with a resolved view (see ResolvePlayer) or nil;
-- while set, the store and the sensors are not read at all.
function RosterDefensiveCell.SetDemoProvider(provider)
  demoProvider = type(provider) == "function" and provider or nil
end

function RosterDefensiveCell.IsDemoActive()
  return demoProvider ~= nil
end

--- True while the cell replaces the DPS column: tracker on, a key running,
-- not in a raid; or the demo source is set (not in a raid).
function RosterDefensiveCell.IsActive()
  if demoProvider ~= nil then
    return not CallRuntime("IsRaidContext")
  end
  local db = ReadDB()
  if db == nil or db.defensiveTrackerEnabled ~= true then
    return false
  end
  return CallRuntime("IsActiveChallenge") and not CallRuntime("IsRaidContext")
end

local function IsEstimateEnabled()
  local db = ReadDB()
  return db ~= nil and db.defensiveEstimateEnabled == true
end

local function Now()
  local getTime = rawget(_G, "GetTime")
  if type(getTime) ~= "function" then
    return nil
  end
  local ok, value = pcall(getTime)
  if ok and type(value) == "number" and not IsSecretValue(value) then
    return value
  end
  return nil
end

local function Text(getL, key, fallback)
  local L = type(getL) == "function" and getL() or nil
  if type(L) == "table" and type(L[key]) == "string" and L[key] ~= "" then
    return L[key]
  end
  local uiCommon = addonTable.UICommon
  if type(uiCommon) == "table" and type(uiCommon.GetLocalizedText) == "function" then
    return uiCommon.GetLocalizedText(key, fallback)
  end
  return fallback
end

--- Cell text of a remaining time: whole seconds, from 100 s on "Xm".
function RosterDefensiveCell.FormatShort(seconds)
  local value = math.ceil(tonumber(seconds) or 0)
  if value >= 100 then
    return string.format("%dm", math.ceil(value / 60))
  end
  return string.format("%d", math.max(0, value))
end

--- Tooltip text of a time span: m:ss.
function RosterDefensiveCell.FormatLong(seconds)
  local value = math.max(0, math.floor(tonumber(seconds) or 0))
  return string.format("%d:%02d", math.floor(value / 60), value % 60)
end

local function PlayerKey(info)
  local sync = addonTable.Sync
  if type(info) ~= "table" or type(info.name) ~= "string" or info.name == "" then
    return nil
  end
  if type(sync) ~= "table" or type(sync.NormalizePlayerKey) ~= "function" then
    return nil
  end
  return sync.NormalizePlayerKey(info.name, info.realm)
end

local function SpellTexture(spellID)
  local spellApi = rawget(_G, "C_Spell")
  local fn = type(spellApi) == "table" and spellApi.GetSpellTexture or nil
  if type(fn) == "function" then
    local ok, texture = pcall(fn, spellID)
    if ok and not IsSecretValue(texture) and (type(texture) == "number" or type(texture) == "string") then
      return texture
    end
  end
  return FALLBACK_ICON
end

-- Client-localized spell name (C_Spell.GetSpellName), or nil.
local function SpellName(spellID)
  local spellApi = rawget(_G, "C_Spell")
  local fn = type(spellApi) == "table" and spellApi.GetSpellName or nil
  if type(fn) == "function" then
    local ok, name = pcall(fn, spellID)
    if ok and not IsSecretValue(name) and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return nil
end

local function Sensors()
  local sensors = addonTable.DefensiveSensors
  return type(sensors) == "table" and sensors or nil
end

-- The view of the demo source (demo = true); an unknown row stays empty.
local function ResolveDemo(playerKey, now)
  local ok, view = pcall(demoProvider, playerKey, now)
  if not ok or type(view) ~= "table" or type(view.entries) ~= "table" then
    return { mode = "none", entries = {}, demo = true }
  end
  view.demo = true
  return view
end

--- What the cell shows for one player at `now`:
-- { mode = "own"|"sync"|"estimate"|"none", frozen, ageSeconds, entries }.
-- own / sync entries come from DefensiveStore (state, remain, charges);
-- estimate entries carry only the spell and its slot (the estimate itself
-- lives in the sensor widgets). With the demo source set the provider answers
-- alone.
function RosterDefensiveCell.ResolvePlayer(playerKey, now)
  if demoProvider ~= nil then
    return ResolveDemo(playerKey, now)
  end
  local store = addonTable.DefensiveStore
  if type(playerKey) ~= "string" or type(store) ~= "table" or type(now) ~= "number" then
    return { mode = "none", entries = {} }
  end
  local view = store.GetForPlayer(playerKey, now)
  if view.source == "own" or view.source == "sync" then
    return {
      mode = view.source,
      frozen = view.frozenAt ~= nil,
      ageSeconds = view.ageSeconds,
      entries = view.entries,
    }
  end
  local sensors = Sensors()
  if IsEstimateEnabled() and sensors and type(sensors.GetEstimate) == "function" then
    local estimate = sensors.GetEstimate(playerKey)
    if #estimate > 0 then
      return { mode = "estimate", entries = estimate }
    end
  end
  return { mode = "none", entries = {} }
end

local function SetColor(target, method, color)
  target[method](target, color[1], color[2], color[3], color[4])
end

local function CreateSlot(cell, index)
  local slot = CreateFrame("Frame", nil, cell)
  slot:SetSize(SLOT_WIDTH, ROW_HEIGHT)
  slot:SetPoint("TOPLEFT", cell, "TOPLEFT", (index - 1) * (SLOT_WIDTH + SLOT_GAP), 0)

  local holder = CreateFrame("Frame", nil, slot)
  holder:SetSize(ICON_SIZE, ICON_SIZE)
  holder:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, -1)
  slot.iconHolder = holder

  slot.icon = holder:CreateTexture(nil, "ARTWORK")
  slot.icon:SetAllPoints()
  slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  -- Estimated remaining cooldown: a dark fill driven by the sensor latch.
  local bar = CreateFrame("StatusBar", nil, holder)
  bar:SetAllPoints(holder)
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  SetColor(bar, "SetStatusBarColor", COLORS.estimateFill)
  if type(bar.SetOrientation) == "function" then
    bar:SetOrientation("VERTICAL")
  end
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)
  bar:Hide()
  slot.estimateBar = bar

  slot.border = holder:CreateTexture(nil, "OVERLAY")
  slot.border:SetTexture(BORDER_TEXTURE)
  slot.border:SetPoint("TOPLEFT", holder, "TOPLEFT", -1, 1)
  slot.border:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 1, -1)
  SetColor(slot.border, "SetVertexColor", COLORS.border)
  if type(slot.border.SetBlendMode) == "function" then
    slot.border:SetBlendMode("ADD")
  end
  slot.border:Hide()
  -- Alpha-only pulse (CLAUDE.md highlight style: 0.55 -> 1.0, 1.2 s BOUNCE).
  if type(slot.border.CreateAnimationGroup) == "function" then
    local pulse = slot.border:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local alpha = pulse:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.55)
    alpha:SetToAlpha(1)
    alpha:SetDuration(1.2)
    slot.pulse = pulse
  end

  slot.text = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  slot.text:SetPoint("TOPLEFT", slot, "TOPLEFT", ICON_SIZE + TEXT_OFFSET, -1)
  slot.text:SetSize(TEXT_WIDTH, ICON_SIZE)
  slot.text:SetJustifyH("LEFT")
  if type(slot.text.SetWordWrap) == "function" then
    slot.text:SetWordWrap(false)
  end
  local uiCommon = addonTable.UICommon
  if type(uiCommon) == "table" and type(uiCommon.ApplyLocaleFont) == "function" then
    uiCommon.ApplyLocaleFont(slot.text)
  end

  slot.clock = slot:CreateTexture(nil, "OVERLAY")
  slot.clock:SetTexture(CLOCK_TEXTURE)
  slot.clock:SetSize(9, 9)
  slot.clock:SetPoint("TOPLEFT", slot, "TOPLEFT", ICON_SIZE + 3, -3)
  SetColor(slot.clock, "SetVertexColor", COLORS.clock)
  slot.clock:Hide()
  return slot
end

local function EnsureCell(row, mainFrame)
  if row.defCell then
    return row.defCell
  end
  local cell = CreateFrame("Frame", nil, mainFrame)
  cell:SetSize(CELL_WIDTH, ROW_HEIGHT)
  cell:SetFrameLevel((mainFrame:GetFrameLevel() or 1) + 12)
  -- Display only: the row's hover frame keeps the tooltip and the whisper.
  if type(cell.EnableMouse) == "function" then
    cell:EnableMouse(false)
  end
  cell.slots = { CreateSlot(cell, 1), CreateSlot(cell, 2) }
  cell:Hide()
  row.defCell = cell
  return cell
end

-- Clears a slot before the next state is applied. A running pulse and an
-- attached estimate stay when the next state keeps them, so the 1 s repaint
-- neither restarts the animation nor re-enables the container.
local function ResetSlot(slot, nextState)
  slot.icon:SetDesaturated(false)
  slot.icon:SetAlpha(1)
  slot.text:SetText("")
  slot.clock:Hide()
  if nextState ~= "active" then
    slot.border:Hide()
    if slot.pulse then
      slot.pulse:Stop()
    end
  end
  slot.state = nil
  if nextState ~= "estimate" then
    slot.estimateBar:Hide()
    local sensors = Sensors()
    if sensors then
      sensors.BindBar(slot.estimateBar, nil)
      sensors.DetachActive(slot.iconHolder)
    end
  end
end

local function ApplyExactSlot(slot, entry, frozen)
  if frozen then
    -- Snapshot from before the own chat lockdown: no countdown, age in the tooltip.
    slot.icon:SetDesaturated(entry.state ~= "ready")
    slot.icon:SetAlpha(entry.state == "ready" and 0.6 or 0.45)
    slot.clock:Show()
    slot.state = "frozen"
    return
  end
  slot.state = entry.state
  if entry.state == "active" then
    slot.border:Show()
    if slot.pulse and not (type(slot.pulse.IsPlaying) == "function" and slot.pulse:IsPlaying()) then
      slot.pulse:Play()
    end
    slot.text:SetText(RosterDefensiveCell.FormatShort(entry.remain))
    SetColor(slot.text, "SetTextColor", COLORS.activeText)
  elseif entry.state == "cd" then
    slot.icon:SetDesaturated(true)
    slot.icon:SetAlpha(0.8)
    slot.text:SetText(RosterDefensiveCell.FormatShort(entry.remain))
    SetColor(slot.text, "SetTextColor", COLORS.cdText)
  end
end

local function ApplyEstimateSlot(slot, entry, playerKey)
  local sensors = Sensors()
  slot.state = "estimate"
  slot.text:SetText(ESTIMATE_MARK)
  SetColor(slot.text, "SetTextColor", COLORS.estimateText)
  if sensors then
    slot.estimateBar:Show()
    sensors.BindBar(slot.estimateBar, playerKey, entry.slotIndex)
    sensors.AttachActive(slot.iconHolder, playerKey, entry.slotIndex)
  end
end

-- Demo estimate: "~" and a plain Lua share (0..1) in the fill bar; no sensor
-- is bound, so nothing secret is involved.
local function ApplyDemoEstimateSlot(slot, entry)
  local sensors = Sensors()
  if sensors then
    sensors.BindBar(slot.estimateBar, nil)
    sensors.DetachActive(slot.iconHolder)
  end
  slot.state = "estimate"
  slot.text:SetText(ESTIMATE_MARK)
  SetColor(slot.text, "SetTextColor", COLORS.estimateText)
  slot.estimateBar:SetMinMaxValues(0, 1)
  slot.estimateBar:SetValue(math.max(0, math.min(1, tonumber(entry.share) or 0)))
  slot.estimateBar:Show()
end

local function ApplySlots(cell, resolved, playerKey)
  local entries = resolved.entries
  for slotIndex = 1, 2 do
    local slot = cell.slots[slotIndex]
    local entry = entries[slotIndex]
    local nextState = nil
    if entry then
      nextState = resolved.mode == "estimate" and "estimate" or (resolved.frozen and "frozen" or entry.state)
    end
    ResetSlot(slot, nextState)
    if entry then
      slot.icon:SetTexture(SpellTexture(entry.spellID))
      slot.spellID = entry.spellID
      if resolved.mode == "estimate" and resolved.demo then
        ApplyDemoEstimateSlot(slot, entry)
      elseif resolved.mode == "estimate" then
        ApplyEstimateSlot(slot, entry, playerKey)
      else
        ApplyExactSlot(slot, entry, resolved.frozen == true)
      end
      slot:Show()
    else
      slot.spellID = nil
      slot:Hide()
    end
  end
  -- One-icon cells align right like the old DPS numbers.
  cell.slots[1]:ClearAllPoints()
  local firstX = entries[2] and 0 or (SLOT_WIDTH + SLOT_GAP)
  cell.slots[1]:SetPoint("TOPLEFT", cell, "TOPLEFT", firstX, 0)
end

--- Hides the cell of a row (no key, tracker off, cleared row).
function RosterDefensiveCell.HideRow(row)
  rendered[row] = nil
  local cell = type(row) == "table" and row.defCell or nil
  if not cell then
    return
  end
  for _, slot in ipairs(cell.slots) do
    ResetSlot(slot, nil)
  end
  cell:Hide()
end

--- Fills the cell of one roster row (render pass, key running).
function RosterDefensiveCell.ApplyRow(row, info, mainFrame, index, now)
  if type(row) ~= "table" or type(mainFrame) ~= "table" then
    return
  end
  now = now or Now()
  local cell = EnsureCell(row, mainFrame)
  cell:ClearAllPoints()
  cell:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", CELL_X, -52 - (index - 1) * ROW_HEIGHT)
  local playerKey = PlayerKey(info)
  local resolved = RosterDefensiveCell.ResolvePlayer(playerKey, now)
  cell.mode = resolved.mode
  ApplySlots(cell, resolved, playerKey)
  rendered[row] = { info = info, mainFrame = mainFrame, index = index }
  cell:Show()
end

--- Header and RIO column for the current phase: "Def" over the cell and RIO
-- 54 px while a key runs, DPS and RIO 84 px otherwise.
function RosterDefensiveCell.ApplyHeaders(uiRef, active, getL)
  lastActive = active == true
  if type(uiRef) ~= "table" then
    return
  end
  if uiRef.dpsHeader then
    local text = active and Text(getL, "COL_DEF", "Def") or Text(getL, "COL_DPS", "DPS")
    uiRef.dpsHeader:SetText(text)
  end
  if uiRef.rioHeader then
    uiRef.rioHeader:SetWidth(active and RIO_KEY_WIDTH or RIO_COL_WIDTH)
  end
end

--- RIO cell width and text while the cell is active: the "(+N)" delta of the
-- previous run would not fit next to the cell.
function RosterDefensiveCell.ApplyRio(row, rioText, active)
  if type(row) ~= "table" or not row.rio then
    return rioText
  end
  row.rio:SetWidth(active and RIO_KEY_WIDTH or RIO_COL_WIDTH)
  if active and type(rioText) == "string" then
    return (rioText:gsub("^%(%+%d+%)", ""))
  end
  return rioText
end

--- True when the active phase changed since the last render (the factory
-- then asks for a full roster render instead of a cell refresh).
function RosterDefensiveCell.NeedsRender()
  return lastActive ~= nil and lastActive ~= RosterDefensiveCell.IsActive()
end

--- Repaints every visible cell from the store and the sensors (1 s tick).
function RosterDefensiveCell.RefreshAll(now)
  now = now or Now()
  for row, entry in pairs(rendered) do
    local cell = row.defCell
    if cell and type(cell.IsShown) == "function" and cell:IsShown() then
      local playerKey = PlayerKey(entry.info)
      local resolved = RosterDefensiveCell.ResolvePlayer(playerKey, now)
      cell.mode = resolved.mode
      ApplySlots(cell, resolved, playerKey)
    end
  end
end

local function KindLabel(getL, kind)
  local keys = KIND_KEYS[kind]
  if not keys then
    return ""
  end
  return Text(getL, keys[1], keys[2])
end

local function ExactStatus(getL, entry)
  local status
  if entry.state == "active" then
    status =
      string.format(Text(getL, "DEF_STATE_ACTIVE", "active, %s left"), RosterDefensiveCell.FormatLong(entry.remain))
  elseif entry.state == "cd" then
    status = string.format(Text(getL, "DEF_STATE_CD", "cooldown %s"), RosterDefensiveCell.FormatLong(entry.remain))
  else
    status = Text(getL, "DEF_STATE_READY", "ready")
  end
  if type(entry.charges) == "number" and entry.charges > 0 then
    status = string.format(Text(getL, "DEF_STATE_CHARGES", "%s, charges: %d"), status, entry.charges)
  end
  return status
end

local STATE_COLORS = {
  ready = { 0.45, 0.95, 0.55 },
  cd = { 0.8, 0.8, 0.8 },
  active = { 0.55, 0.82, 1 },
  frozen = { 0.6, 0.66, 0.74 },
  estimate = { 0.78, 0.82, 0.88 },
}

local function AddEntryLine(tooltip, getL, spellID, kind, status, color)
  local name = SpellName(spellID) or string.format("#%d", spellID)
  local icon = SpellTexture(spellID)
  tooltip:AddLine(
    string.format("|T%s:14:14|t %s |cff8a96a8(%s)|r: %s", tostring(icon), name, KindLabel(getL, kind), status),
    color[1],
    color[2],
    color[3]
  )
end

-- Every manifest defensive of a member without an isiLive state: the
-- estimated ones point at the cell symbol (the estimate is secret and cannot
-- be printed), the rest were never seen.
local function AddEstimateLines(tooltip, getL, playerKey, info)
  local sensors = Sensors()
  if not sensors then
    return false
  end
  local estimated = {}
  for _, entry in ipairs(sensors.GetEstimate(playerKey)) do
    estimated[entry.spellID] = true
  end
  local units = addonTable.Units
  local specID = nil
  if type(units) == "table" and type(units.GetInspectSpecID) == "function" and type(info.unit) == "string" then
    specID = units.GetInspectSpecID(info.unit)
  end
  local candidates = sensors.GetCandidateSpells(info.class, specID)
  for _, candidate in ipairs(candidates) do
    if estimated[candidate.spellID] then
      AddEntryLine(
        tooltip,
        getL,
        candidate.spellID,
        candidate.kind,
        Text(getL, "DEF_STATE_ESTIMATED", "~ estimated, see the icon"),
        STATE_COLORS.estimate
      )
    else
      AddEntryLine(
        tooltip,
        getL,
        candidate.spellID,
        candidate.kind,
        Text(getL, "DEF_STATE_NOT_SEEN", "likely ready (not seen)"),
        STATE_COLORS.ready
      )
    end
  end
  return #candidates > 0
end

-- Demo estimate: the estimated slots and the provider's unseen candidates.
local function AddDemoEstimateLines(tooltip, getL, resolved)
  for _, entry in ipairs(resolved.entries) do
    AddEntryLine(
      tooltip,
      getL,
      entry.spellID,
      entry.kind,
      Text(getL, "DEF_STATE_ESTIMATED", "~ estimated, see the icon"),
      STATE_COLORS.estimate
    )
  end
  for _, entry in ipairs(type(resolved.unseen) == "table" and resolved.unseen or {}) do
    AddEntryLine(
      tooltip,
      getL,
      entry.spellID,
      entry.kind,
      Text(getL, "DEF_STATE_NOT_SEEN", "likely ready (not seen)"),
      STATE_COLORS.ready
    )
  end
end

--- Defensives block of the roster row tooltip (rule 269): every defensive of
-- the player with icon, client-localized name, kind and state, then the
-- source (own client, isiLive sync with its age, estimated "~").
function RosterDefensiveCell.AppendTooltip(tooltip, info, getL, unit)
  if type(tooltip) ~= "table" or type(tooltip.AddLine) ~= "function" or type(info) ~= "table" then
    return false
  end
  if not RosterDefensiveCell.IsActive() then
    return false
  end
  local now = Now()
  local playerKey = PlayerKey(info)
  local resolved = RosterDefensiveCell.ResolvePlayer(playerKey, now)
  if resolved.mode == "none" then
    return false
  end
  local header = Text(getL, "DEF_TOOLTIP_HEADER", "Defensives / externals")
  tooltip:AddLine(" ")
  tooltip:AddLine(header, 0.55, 0.8, 1)
  local source
  if resolved.mode == "estimate" and resolved.demo then
    AddDemoEstimateLines(tooltip, getL, resolved)
    source = Text(getL, "DEF_SOURCE_ESTIMATED", "Source: estimated (~)")
  elseif resolved.mode == "estimate" then
    AddEstimateLines(tooltip, getL, playerKey, { class = info.class, unit = unit })
    source = Text(getL, "DEF_SOURCE_ESTIMATED", "Source: estimated (~)")
  else
    for _, entry in ipairs(resolved.entries) do
      local status = ExactStatus(getL, entry)
      local color = resolved.frozen and STATE_COLORS.frozen or STATE_COLORS[entry.state] or STATE_COLORS.ready
      AddEntryLine(tooltip, getL, entry.spellID, entry.kind, status, color)
    end
    if resolved.mode == "own" then
      source = Text(getL, "DEF_SOURCE_OWN", "Source: own client")
    else
      local age = RosterDefensiveCell.FormatLong(resolved.ageSeconds)
      local key = resolved.frozen and "DEF_SOURCE_SYNC_FROZEN" or "DEF_SOURCE_SYNC"
      local fallback = resolved.frozen and "Source: isiLive sync, %s ago (frozen in combat)"
        or "Source: isiLive sync, %s ago"
      source = string.format(Text(getL, key, fallback), age)
    end
  end
  tooltip:AddLine(source, 0.5, 0.62, 0.78)
  return true
end
