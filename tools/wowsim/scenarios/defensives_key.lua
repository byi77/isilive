-- Defensives column in a running key (rules 267-269), regression and viewer.
-- Outside the key the DPS column stays; while the key runs the Def cell takes
-- its place: own cooldown (exact), isiLive peers through the real DEF sync
-- (ready / cooldown, then frozen with the clock in the own chat lockdown) and
-- the estimate for members without isiLive (blue-grey seconds on the icon,
-- remaining fill, and the
-- running buff shown by the container with its duration and blue border).
--
-- The client's AuraContainer (CustomAuraContainerTemplate) cannot run here:
-- this scenario stands in for it with a small aura model per unit
-- (AURA_UP). The stand-in answers the sensor's IsMouseOver and shows the
-- aura frame of the visible container like Blizzard does; everything else is
-- the real addon.
local MAP_ID = 249
local REALM = "Antonidas"
local RU_REALM = "Гордунни"

local NAMES = { "Frostweberin", "Sturmbrecher", "Велисандрия", "Тенебраэлина", "Lichtschwurin" }

local ICE_BLOCK = 45438
local IRONBARK = 102342
local BARKSKIN = 22812
local SACRIFICE = 6940
local SHIELD_WALL = 871
local AMZ_AURA = 145629

local AURA_UP = {} -- [unit .. ":" .. auraID] = expiry (simulated seconds)
local containers = {}

local function Enable(db)
  db.defensiveTrackerEnabled = true
end

local function ApplySettings(sim, name)
  local runtime = sim.Client(name).addonTable.DefensiveRuntime
  if type(runtime) == "table" then
    runtime.ApplySettings()
  end
end

-- Own cooldowns of one client: spellID -> { start, duration }.
local function InstallCooldowns(sim, name, known)
  local client = sim.Client(name)
  client.knownSpells = client.knownSpells or {}
  for _, spellID in ipairs(known) do
    client.knownSpells[spellID] = true
  end
  local env = sim.Env(name)
  local cooldowns = {}
  local base = env.C_Spell.GetSpellCooldown
  env.C_Spell.GetSpellCooldown = function(spellID)
    local cd = cooldowns[spellID]
    if cd then
      return { startTime = cd.start, duration = cd.duration, isEnabled = true, modRate = 1 }
    end
    return base(spellID)
  end
  return cooldowns
end

local function UnitOf(env, name)
  for index = 1, 4 do
    local unit = "party" .. index
    if env.UnitName(unit) == name then
      return unit
    end
  end
  return nil
end

local function IsUp(sim, unit, auraID)
  local expiry = AURA_UP[tostring(unit) .. ":" .. tostring(auraID)]
  return expiry ~= nil and sim.Now() < expiry
end

-- Blizzard's side of the visible container: show the aura frame while the
-- aura is up, with icon and remaining duration, and play the shown animation.
local function SyncAuraFrames(sim)
  for _, container in ipairs(containers) do
    local button = container._button
    if button and container._groups.isiLiveDefActive then
      local expiry = AURA_UP[tostring(container._unit) .. ":" .. tostring(container._aura)]
      if expiry and sim.Now() < expiry then
        if button._auraIcon then
          button._auraIcon:SetTexture(136243)
        end
        if button._durationText then
          button._durationText:SetText(string.format("%d", math.ceil(expiry - sim.Now())))
        end
        if not button:IsShown() then
          button:Show()
          for _, group in ipairs(button._shownAnimations) do
            group:Play()
          end
        end
      else
        button:Hide()
      end
    end
  end
end

-- Blizzard's inspect traits: one tree with every talent of the manifest taken
-- (read through the real inspect flow, rule 268).
local function InstallTraits(sim, env)
  local talents = {}
  for castID, record in pairs(sim.Client().addonTable.DefensiveManifest.spells) do
    if record.talent then
      talents[#talents + 1] = castID
    end
  end
  env.C_Traits = env.C_Traits or {}
  env.C_Traits.HasValidInspectData = function()
    return true
  end
  env.C_Traits.GetConfigInfo = function()
    return { treeIDs = { 1 } }
  end
  env.C_Traits.GetTreeNodes = function()
    local nodes = {}
    for index = 1, #talents do
      nodes[index] = index
    end
    return nodes
  end
  env.C_Traits.GetNodeInfo = function(_configID, nodeID)
    return { entryIDs = { nodeID }, activeRank = 1, activeEntry = { entryID = nodeID } }
  end
  env.C_Traits.GetEntryInfo = function(_configID, entryID)
    return { definitionID = entryID }
  end
  env.C_Traits.GetDefinitionInfo = function(definitionID)
    return { spellID = talents[definitionID] }
  end
end

local function InstallAuraContainer(sim)
  local env = sim.Env()
  InstallTraits(sim, env)
  local createFrame = env.CreateFrame
  env.C_XMLUtil = {
    GetTemplateInfo = function(name)
      return name == "CustomAuraContainerTemplate" and { type = "AuraContainer" } or nil
    end,
  }
  env.C_CurveUtil.EvaluateColorValueFromBoolean = function(condition, ifTrue, ifFalse)
    local value = ifFalse
    if condition == true then
      value = ifTrue
    end
    return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5) / 255 -- client: color value steps
  end
  env.CreateFrame = function(frameType, name, parent, template, ...)
    if frameType ~= "AuraContainer" then
      return createFrame(frameType, name, parent, template, ...)
    end
    local container = createFrame("Frame", name, parent)
    container._groups = {}
    function container:AddAuraGroup(key, _filter, options)
      self._groups[key] = options
      self._aura = next(options.candidateFilters.includeSpellIDs)
      local button = createFrame("Button", nil, self)
      button._shownAnimations = {}
      button.SetIcon = function(_, texture)
        button._auraIcon = texture
      end
      button.SetDurationText = function(_, fontString)
        button._durationText = fontString
      end
      button.AddAuraShownAnimation = function(_, group)
        button._shownAnimations[#button._shownAnimations + 1] = group
      end
      button:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
      options.initializeFrame(button)
      button:Hide()
      self._button = button
    end
    function container:SetAuraGroupCandidateFilters(_key, filters)
      self._aura = next(filters.includeSpellIDs)
    end
    function container:SetUnit(unit)
      self._unit = unit
    end
    function container:SetEnabled(enabled)
      self._enabled = enabled
    end
    function container:IsMouseOver()
      return IsUp(sim, self._unit, self._aura)
    end
    containers[#containers + 1] = container
    return container
  end
end

local function Cells(sim)
  local out = {}
  local frame = sim.Env().isiLiveMainFrame
  for _, child in ipairs({ frame:GetChildren() }) do
    if type(child.slots) == "table" and child:IsVisible() then
      out[#out + 1] = child
    end
  end
  return out
end

local function SlotOf(sim, spellID)
  for _, cell in ipairs(Cells(sim)) do
    for _, slot in ipairs(cell.slots) do
      if slot:IsVisible() and slot.spellID == spellID then
        return slot
      end
    end
  end
  return nil
end

-- The cell sits between RIO (46 px in the key) and the kick column.
local function Measure(sim, label)
  local frame = sim.Env().isiLiveMainFrame
  local left = frame:GetLeft()
  local cellAddon = sim.Client().addonTable.RosterDefensiveCell
  local cells = Cells(sim)
  sim.Expect(#cells > 0, label .. ": defensives cells visible")
  for _, cell in ipairs(cells) do
    local cellLeft, cellRight = cell:GetLeft() - left, cell:GetRight() - left
    sim.Expect(math.abs(cellLeft - cellAddon.CELL_X) < 0.5, label .. ": cell at its column")
    sim.Expect(cellRight <= 446.5, label .. ": cell ends left of the kick column")
    for _, slot in ipairs(cell.slots) do
      if slot:IsVisible() then
        sim.Expect(slot.text:IsTruncated() ~= true, label .. ": slot text fits")
      end
    end
  end
end

local function ShowTooltip(sim, unit)
  local frame = sim.Env().isiLiveMainFrame
  for _, child in ipairs({ frame:GetChildren() }) do
    if child.unit == unit and child:GetScript("OnEnter") then
      local cx, cy = child:GetLeft() + 380, child:GetBottom() + 8
      sim.Env().GetCursorPosition = function()
        return cx, cy
      end
      child:GetScript("OnEnter")(child)
      return child
    end
  end
  return nil
end

local function HideTooltip(child)
  if child and child:GetScript("OnLeave") then
    child:GetScript("OnLeave")(child)
  end
end

return {
  name = "defensives_key",
  description = "Defensives column replaces DPS in a running key: own, isiLive sync, frozen, estimate",
  timeLimits = { [MAP_ID] = 33 * 60 },
  setup = {
    locale = "deDE",
    party = {
      {
        name = NAMES[1],
        realm = REALM,
        class = "MAGE",
        specID = 64,
        role = "DAMAGER",
        ilvl = 712,
        rating = 3120,
        key = { mapID = MAP_ID, level = 14 },
      },
      {
        name = NAMES[2],
        realm = REALM,
        class = "WARRIOR",
        specID = 73,
        role = "TANK",
        ilvl = 714,
        rating = 3388,
        addon = "none",
      },
      {
        name = NAMES[3],
        realm = RU_REALM,
        class = "DRUID",
        specID = 105,
        role = "HEALER",
        ilvl = 709,
        rating = 2954,
        simulate = true,
      },
      {
        name = NAMES[4],
        realm = RU_REALM,
        class = "DEATHKNIGHT",
        specID = 252,
        role = "DAMAGER",
        ilvl = 711,
        rating = 3047,
        addon = "none",
      },
      {
        name = NAMES[5],
        realm = REALM,
        class = "PALADIN",
        specID = 70,
        role = "DAMAGER",
        ilvl = 713,
        rating = 3215,
        simulate = true,
      },
    },
  },
  run = function(sim)
    sim.Login()
    InstallAuraContainer(sim)
    local ownCooldowns = InstallCooldowns(sim, NAMES[1], { ICE_BLOCK })
    local druidCooldowns = InstallCooldowns(sim, NAMES[3], { IRONBARK, BARKSKIN })
    InstallCooldowns(sim, NAMES[5], { SACRIFICE, 642 })
    local lockdown = false
    sim.Env().C_ChatInfo.InChatMessagingLockdown = function()
      return lockdown
    end
    Enable(sim.Env().IsiLiveDB)
    Enable(sim.Env(NAMES[3]).IsiLiveDB)
    Enable(sim.Env(NAMES[5]).IsiLiveDB)
    sim.JoinGroup(NAMES[2], NAMES[3], NAMES[4], NAMES[5])
    sim.Wait(8)

    sim.EnterDungeon(MAP_ID)
    sim.Wait(2)
    for _, name in ipairs({ NAMES[1], NAMES[3], NAMES[5] }) do
      ApplySettings(sim, name)
    end
    sim.Wait(2)
    sim.Step("1 Ausserhalb Key: DPS-Spalte wie bisher")
    sim.ExpectText("^DPS$", "DPS header outside the key")
    sim.Expect(#Cells(sim) == 0, "no defensives cell outside the key")

    sim.StartKey({ mapID = MAP_ID, level = 15 })
    sim.Wait(12)
    -- Own Ice Block on cooldown, the druid's Ironbark on cooldown (sync).
    local iceBlockStart = sim.Now() - 20
    ownCooldowns[ICE_BLOCK] = { start = iceBlockStart, duration = 240 }
    sim.Cast(NAMES[1], ICE_BLOCK)
    druidCooldowns[IRONBARK] = { start = sim.Now(), duration = 90 }
    sim.Cast(NAMES[3], IRONBARK)
    sim.Wait(2)
    SyncAuraFrames(sim)
    sim.Step("2 Key laeuft: Def statt DPS (eigen exakt, Sync, geschaetzt ~)")
    sim.ExpectText("^Def$", "Def header in the key")
    sim.Expect(#sim.FindText("^DPS$") == 0, "no DPS header in the key")
    sim.ExpectText("^4m$", "own cooldown from 100 s on in minutes")
    local ironbark = SlotOf(sim, IRONBARK)
    sim.Expect(
      ironbark ~= nil and ironbark.state == "cd" and (ironbark.text:GetText() or ""):find("^%d+$") ~= nil,
      "synced Ironbark cooldown in exact seconds: " .. tostring(ironbark and ironbark.text:GetText())
    )
    local marked = false
    for _, cell in ipairs(Cells(sim)) do
      for _, slot in ipairs(cell.slots) do
        marked = marked or (slot:IsVisible() and slot.text:GetText() == "~")
      end
    end
    sim.Expect(not marked, "no ~ mark any more: estimates are blue-grey numbers on the icon")
    sim.Expect(SlotOf(sim, ICE_BLOCK) ~= nil, "own Ice Block slot")
    sim.Expect(SlotOf(sim, SACRIFICE) ~= nil, "synced paladin external first")
    Measure(sim, "step2")

    -- The tank (no isiLive) uses Shield Wall: the container shows it.
    local env = sim.Env()
    local tankUnit = UnitOf(env, NAMES[2])
    local dkUnit = UnitOf(env, NAMES[4])
    AURA_UP[tostring(tankUnit) .. ":" .. SHIELD_WALL] = sim.Now() + 8
    sim.Wait(1)
    SyncAuraFrames(sim)
    sim.Step("3 Geschaetzt: Schildwall des Tanks aktiv (blauer Rahmen, Restdauer)")
    sim.ExpectText("^7$", "the running buff shows its duration")
    local wall = SlotOf(sim, SHIELD_WALL)
    sim.Expect(wall ~= nil and wall.state == "estimate", "Shield Wall slot is estimated")

    AURA_UP[tostring(dkUnit) .. ":" .. AMZ_AURA] = sim.Now() + 6
    sim.Wait(30)
    SyncAuraFrames(sim)
    sim.Step("4 Geschaetzt: Abklingzeit als Fuellung ab Buff-Start")
    local bar = wall and wall.estimateBar
    if bar then
      local minValue, maxValue = bar:GetMinMaxValues()
      local share = (bar:GetValue() - minValue) / (maxValue - minValue)
      sim.Expect(share > 0.7 and share < 0.85, string.format("Shield Wall ~%.2f of 180 s left", share))
    end

    local tip = ShowTooltip(sim, tankUnit)
    sim.Wait(0.2)
    sim.Step("5 Zeilen-Tooltip Nicht-isiLive-Nutzer (geschaetzt)")
    sim.ExpectText("geschätzt, siehe Symbol", "estimated entries point at the icon")
    sim.Expect(SlotOf(sim, 12975) ~= nil, "the tank's third defensive (Last Stand) has its own icon")
    HideTooltip(tip)
    tip = ShowTooltip(sim, UnitOf(env, NAMES[3]))
    sim.Wait(0.2)
    sim.Step("6 Zeilen-Tooltip isiLive-Nutzer (Sync, Alter)")
    sim.ExpectText("isiLive%-Sync, vor", "sync source with its age")
    HideTooltip(tip)

    lockdown = true
    sim.Wait(3)
    SyncAuraFrames(sim)
    sim.Step("7 Eigene Chat-Sperre: Schaetzung ab dem geteilten Stand")
    local locked = SlotOf(sim, IRONBARK)
    sim.Expect(locked ~= nil and locked.state == "estimate", "Ironbark estimated in the lockdown")
    if locked then
      local low, high = locked.estimateBar:GetMinMaxValues()
      local left = (locked.estimateBar:GetValue() - low) / (high - low)
      sim.Expect(left > 0.4 and left < 0.8, string.format("Ironbark ~%.2f from the shared cooldown", left))
    end

    sim.Env().IsiLiveDB.uiDesign = "classic"
    sim.Reload()
    InstallAuraContainer(sim)
    sim.Env().C_ChatInfo.InChatMessagingLockdown = function()
      return lockdown
    end
    -- A reload starts a fresh client: the own spellbook and cooldown again.
    InstallCooldowns(sim, NAMES[1], { ICE_BLOCK })[ICE_BLOCK] = { start = iceBlockStart, duration = 240 }
    sim.Fire("SPELLS_CHANGED")
    sim.Wait(4)
    SyncAuraFrames(sim)
    sim.Step("8 Classic-Design")
    Measure(sim, "step8-classic")
    sim.Expect(SlotOf(sim, ICE_BLOCK) ~= nil, "own Ice Block again after the reload")

    sim.Env().IsiLiveDB.uiDesign = "modern"
    sim.Env().IsiLiveDB.locale = "enUS"
    lockdown = false
    sim.Reload()
    InstallAuraContainer(sim)
    InstallCooldowns(sim, NAMES[1], { ICE_BLOCK })[ICE_BLOCK] = { start = iceBlockStart, duration = 240 }
    sim.Fire("SPELLS_CHANGED")
    sim.Wait(4)
    SyncAuraFrames(sim)
    sim.Step("9 enUS, Modern")
    sim.ExpectText("^Def$", "Def header in enUS")
    Measure(sim, "step9-enUS")

    sim.CompleteKey()
    sim.Wait(6)
    sim.Step("10 Nach dem Key: DPS zurueck")
    sim.ExpectText("^DPS$", "DPS header after the key")
    sim.Expect(#Cells(sim) == 0, "no defensives cell after the key")
  end,
}
