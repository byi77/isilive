-- Portal navigator layouts (rule 263, maintainability package 4 G). Renders
-- all 32 occupied/empty combinations of the five navigator slots through the
-- real navigator card and measures the result: every text stays inside the
-- card, no two slots overlap, and no single-line label is cut. Background: on
-- the Season 2 launch day the outer slots were left empty for the first time,
-- the extra "Unoccupied" line pushed the labels out through the card's bottom
-- border (fix 33df89e). The occupied slots get the longest dungeon names of
-- the season in the client language, so a name that wraps onto a second line
-- is part of every check. Run once per client locale:
--
--   lua tools/wowsim/wowsim.lua navigator_layouts --locale deDE
--
-- Geometry comes from wowsim's widget engine: real anchors and sizes of the
-- addon, text sizes estimated from the font size (0.55 em per glyph, greedy
-- word wrap at the set width).

local SLOTS = { "left", "half_left", "center", "half_right", "right" }
local TOLERANCE = 0.5

local function Rect(engine, obj)
  local rect = engine.ResolveRect(obj)
  if not rect then
    return nil
  end
  return { left = rect.left, right = rect.left + rect.w, bottom = rect.bottom, top = rect.bottom + rect.h }
end

local function Overlaps(a, b)
  return a.left < b.right - TOLERANCE
    and b.left < a.right - TOLERANCE
    and a.bottom < b.top - TOLERANCE
    and b.bottom < a.top - TOLERANCE
end

-- Visible, non-empty font strings drawn on the navigator card.
local function NavigatorTexts(engine, card)
  local texts = {}
  for _, obj in ipairs(engine.all) do
    if obj._type == "FontString" and obj:IsVisible() and (obj._text or "") ~= "" then
      local parent = obj:GetParent()
      if parent == card then
        texts[#texts + 1] = obj
      end
    end
  end
  return texts
end

local function MaskLabel(mask)
  local parts = {}
  for index, slot in ipairs(SLOTS) do
    local occupied = math.floor(mask / 2 ^ (index - 1)) % 2 == 1
    parts[#parts + 1] = (occupied and "" or "-") .. slot
  end
  return table.concat(parts, " ")
end

return {
  name = "navigator_layouts",
  description = "All 32 portal navigator slot layouts: inside the card, no overlap, nothing cut (--locale <tag>)",
  setup = {
    locale = "deDE",
    party = {
      { name = "Isiplayer", class = "MAGE", specID = 63, role = "DAMAGER", ilvl = 330, rating = 3310 },
    },
  },
  run = function(sim)
    sim.Login()
    sim.Wait(2)
    local env = sim.Env()
    local engine = sim.Client().engine
    local seasonData = sim.Client().addonTable.SeasonData
    local locale = env.GetLocale()
    local seasonID = seasonData.GetActiveSeasonID()
    local navigator = seasonData.GetPortalNavigatorConfig(seasonID)
    sim.Expect(type(navigator) == "table", "the active season has a portal navigator")
    if type(navigator) ~= "table" then
      return
    end
    local original = {}
    for _, slot in ipairs(SLOTS) do
      original[slot] = navigator.slots[slot]
    end

    -- The season's dungeons, longest name in the client language first.
    local maps = {}
    for _, mapID in ipairs(seasonData.GetOrderedMapIDs(seasonID)) do
      maps[#maps + 1] = { mapID = mapID, name = seasonData.GetDungeonName(mapID, locale, seasonID) or "" }
    end
    table.sort(maps, function(a, b)
      return #a.name > #b.name
    end)

    local zoneName = navigator.zone.names[1]
    local failures = 0
    for mask = 0, 31 do
      for index, slot in ipairs(SLOTS) do
        local occupied = math.floor(mask / 2 ^ (index - 1)) % 2 == 1
        navigator.slots[slot] = occupied and maps[index].mapID or false
      end
      sim.world.zone = "Dornogal"
      sim.world.FireAll("ZONE_CHANGED_NEW_AREA")
      sim.Wait(0.5)
      sim.world.zone = zoneName
      sim.world.FireAll("ZONE_CHANGED_NEW_AREA")
      sim.Wait(1)

      local label = string.format("layout %02d (%s)", mask, MaskLabel(mask))
      local card = env.isiLivePortalNavigatorNotice
      local cardRect = card and card:IsVisible() and Rect(engine, card) or nil
      local ok = sim.Expect(cardRect ~= nil, label .. ": the navigator card is shown")
      if cardRect then
        local texts = NavigatorTexts(engine, card)
        for i, text in ipairs(texts) do
          local r = Rect(engine, text)
          if r then
            local inside = r.bottom >= cardRect.bottom - TOLERANCE
              and r.top <= cardRect.top + TOLERANCE
              and r.left >= cardRect.left - TOLERANCE
              and r.right <= cardRect.right + TOLERANCE
            ok = sim.Expect(inside, string.format("%s: '%s' stays inside the card", label, text._text)) and ok
            if text._wrap == false then
              ok = sim.Expect(
                not text:IsTruncated(),
                string.format("%s: single-line '%s' is not cut", label, text._text)
              ) and ok
            end
            for j = i + 1, #texts do
              local other = Rect(engine, texts[j])
              if other then
                ok = sim.Expect(
                  not Overlaps(r, other),
                  string.format("%s: '%s' and '%s' do not overlap", label, text._text, texts[j]._text)
                ) and ok
              end
            end
          end
        end
      end
      if not ok then
        failures = failures + 1
        sim.Step(label)
      end
    end
    sim.Step(string.format("32 navigator layouts (%s): %d with findings", locale, failures))

    for _, slot in ipairs(SLOTS) do
      navigator.slots[slot] = original[slot]
    end
  end,
}
