local _, addonTable = ...

addonTable = addonTable or {}

-- Central maintenance file for all manually curated season data.
-- Each season defines its activation state, MDT/forces requirements, inactive messages,
-- portal navigator layout, and one complete record per dungeon.
-- Each dungeon record keeps the map, activity, portal spell, display order, level,
-- localized name, short code, and optional verification metadata together.
-- Optional `entrance` = { uiMapID, x, y, zoneNames }: outdoor zone UiMapID and
-- entrance coordinates (0-100) for the accepted-invite "Navigation" row. The
-- displayed zone name is read from C_Map.GetMapInfo(uiMapID) in the client
-- language; `zoneNames` (enUS required, other locales optional) is only the
-- fallback when the client returns no map info.
--
-- Maintenance workflow for a new season:
-- 1. Add a new entry under `seasons`; do not overwrite historical season entries.
--    Point `upcomingSeasonID` at it so the season tooling targets it by default.
-- 2. Add every dungeon exactly once and use only IDs confirmed by a reliable source.
-- 3. Keep `autoDetectFromChallengeMaps = false` until every dungeon row is verified.
--    Once verified it may be set to `true` ahead of the season launch: selection is an
--    exact match against Blizzard's challenge-map table, so a prepared season only wins
--    once Blizzard actually ships it. Auto-selection is runtime-only and never rewrites
--    `activeSeasonID`.
-- 4. Set `mdtDirectory` only when the exact MDT directory is verified; never guess it.
--    `requiresForces = true` is a build/CI gate (SeasonData.GetForcesReadiness via
--    tools/check_mplus_db_lifetime.lua) for the generated forces DB. It never decides
--    season activation: without a matching, fresh DB only the MDT mob displays close.
-- 5. Change `activeSeasonID` only as the manual fallback when auto-selection cannot
--    match (e.g. Blizzard's map table diverges from the manifest). Clear
--    `upcomingSeasonID` once the prepared season is the active one.
-- 6. Run `lua tools/check_season_intake.lua` and `lua tools/validate_usecases.lua`.
--
-- Runtime lookup tables are compiled from this manifest by game/isiLive_season_data.lua.
-- Generated M+ forces payloads intentionally remain in data/isiLive_mplus_forces.lua.
addonTable.SeasonManifest = {
  -- Midnight Season 2 went live; confirmed 2026-09-06 against a running client
  -- whose portal room and keystones carry the S2 dungeons. Auto-selection had
  -- already switched at runtime, but this value is what the build gates and the
  -- no-auto-match fallback read, and leaving it on S1 kept the generated forces
  -- DB pinned to a season nobody plays any more.
  activeSeasonID = "midnight_s2",
  -- Optional, tooling only: the season currently being prepared. MDT preview and
  -- other tools default to it, otherwise to `activeSeasonID`. It must name a
  -- season below (an unknown id is a manifest error); the runtime never reads it.
  -- Leave it unset while no next season is configured, and clear it once that
  -- season is the active one.
  -- upcomingSeasonID = "<next season id>",
  seasons = {
    midnight_s1 = {
      label = "Midnight Season 1",
      autoDetectFromChallengeMaps = true,
      -- S1 ended on 2026-09-06. The generated forces DB now tracks the active
      -- season, so the forces build gate is skipped for S1. It stays fully
      -- usable as the manual fallback, just without MDT mob percentages -- the
      -- documented no-DB behavior.
      requiresForces = false,
      mdtDirectory = "Midnight",
      inactivePortalMessageByLocale = {},
      portalNavigator = {
        -- Hub zone that hosts this season's portal room. `mapIDs` is the reliable
        -- signal; `names` is the localized fallback when the map id is unavailable.
        zone = {
          mapIDs = { 2266 },
          names = {
            "Millennia's Threshold",
            "Die Jahrhundertschwelle",
            "Jahrhundertschwelle",
            "The Timeways",
            "Timeways",
          },
        },
        titleByLocale = {
          default = "isiLive - Midnight Season One M+ Navigator",
        },
        slots = {
          left = 161,
          half_left = 556,
          center = false,
          half_right = 402,
          right = 239,
        },
      },
      dungeons = {
        {
          mapID = 558,
          activityIDs = { 1760 },
          portalSpellIDs = { 1254572 },
          displayOrder = 1,
          minimumPlayerLevel = 90,
          names = { enUS = "Magisters' Terrace", deDE = "Terrasse der Magister" },
          shortCodes = { default = "MT", deDE = "MT" },
        },
        {
          mapID = 560,
          activityIDs = { 1764 },
          portalSpellIDs = { 1254559 },
          displayOrder = 2,
          minimumPlayerLevel = 90,
          names = { enUS = "Maisara Caverns", deDE = "Maisarakavernen" },
          shortCodes = { default = "MC", deDE = "MC" },
        },
        {
          mapID = 559,
          activityIDs = { 1768 },
          portalSpellIDs = { 1254563 },
          displayOrder = 3,
          minimumPlayerLevel = 90,
          names = { enUS = "Nexus-Point Xenas", deDE = "Nexuspunkt Xenas" },
          shortCodes = { default = "NPX", deDE = "NPX" },
        },
        {
          mapID = 557,
          activityIDs = { 1542 },
          portalSpellIDs = { 1254400 },
          displayOrder = 4,
          minimumPlayerLevel = 90,
          names = { enUS = "Windrunner Spire", deDE = "Windläuferturm" },
          shortCodes = { default = "WRS", deDE = "WRS" },
        },
        {
          mapID = 402,
          activityIDs = { 1160 },
          portalSpellIDs = { 393273 },
          displayOrder = 5,
          names = { enUS = "Algeth'ar Academy", deDE = "Akademie von Algeth'ar" },
          shortCodes = { default = "AA", deDE = "AA" },
        },
        {
          mapID = 556,
          activityIDs = { 1770 },
          portalSpellIDs = { 1254555 },
          displayOrder = 6,
          names = { enUS = "Pit of Saron", deDE = "Grube von Saron" },
          shortCodes = { default = "POS", deDE = "POS" },
        },
        {
          mapID = 239,
          activityIDs = { 486 },
          portalSpellIDs = { 1254551 },
          displayOrder = 7,
          names = { enUS = "Seat of the Triumvirate", deDE = "Sitz des Triumvirats" },
          shortCodes = { default = "SOT", deDE = "SOT" },
        },
        {
          mapID = 161,
          activityIDs = { 182 },
          portalSpellIDs = { 159898 },
          displayOrder = 8,
          names = { enUS = "Skyreach", deDE = "Die Himmelsnadel" },
          shortCodes = { default = "SR", deDE = "SR" },
        },
      },
    },
    midnight_s2 = {
      label = "Midnight Season 2",
      autoDetectFromChallengeMaps = true,
      -- Verified 2026-09-06 against MDT 6.2.15: the S2 dungeons ship in the same
      -- "Midnight" directory as the S1 ones (KingsRest.lua, TempleOfSethraliss.lua,
      -- MurderRow.lua, RubyLifePools.lua, AltarOfFangs.lua, DenOfNalorakk.lua,
      -- TheBlindingVale.lua, VoidscarArena.lua). Until then this season had no
      -- mdtDirectory and requiresForces = false, so the generator skipped it and
      -- an active S2 key showed no mob percentages at all.
      requiresForces = true,
      mdtDirectory = "Midnight",
      -- Shown only as the teleport empty state while the active season maps no
      -- dungeons (SeasonData.HasActiveDungeons); a populated season never reaches it.
      inactivePortalMessageByLocale = {},
      portalNavigator = {
        -- Same hub zone as Season 1 (Millennia's Threshold), confirmed by the
        -- maintainer on 2026-07-22: S2 reuses the S1 portal room, only the
        -- portals inside it change. The slots below carry that difference.
        zone = {
          mapIDs = { 2266 },
          names = {
            "Millennia's Threshold",
            "Die Jahrhundertschwelle",
            "Jahrhundertschwelle",
            "The Timeways",
            "Timeways",
          },
        },
        titleByLocale = {
          default = "isiLive - Midnight Season Two M+ Navigator",
          deDE = "isiLive - Midnight Saison Zwei M+ Navigator",
        },
        slots = {
          left = false,
          half_left = 249,
          center = 399,
          half_right = 250,
          right = false,
        },
      },
      -- Entrances: UiMapID + /way coordinates from method.gg "WoW Midnight Season 2:
      -- Dungeon Entrance Locations", checked 2026-10-22.
      dungeons = {
        {
          mapID = 249,
          activityIDs = { 514 },
          portalSpellIDs = { 1286831 },
          displayOrder = 1,
          names = { enUS = "King's Rest", deDE = "Königsruh" },
          shortCodes = { default = "KR", deDE = "KR" },
          entrance = { uiMapID = 1193, x = 37.90, y = 39.73, zoneNames = { enUS = "Zuldazar" } },
          verification = {
            status = "verified",
            verifiedAt = "2026-07-13",
            source = "Portal: approved cross-check; LFG: PTR C_LFGList.GetActivityInfoTable",
          },
        },
        {
          mapID = 250,
          activityIDs = { 504 },
          portalSpellIDs = { 1286828 },
          displayOrder = 2,
          names = { enUS = "Temple of Sethraliss", deDE = "Tempel von Sethraliss" },
          shortCodes = { default = "TOS", deDE = "TVS" },
          entrance = { uiMapID = 1195, x = 51.94, y = 26.53, zoneNames = { enUS = "Vol'dun" } },
          verification = {
            status = "verified",
            verifiedAt = "2026-07-13",
            source = "Portal: approved cross-check; LFG: PTR Blizzard activity search",
          },
        },
        {
          mapID = 399,
          activityIDs = { 1176 },
          portalSpellIDs = { 393256 },
          displayOrder = 3,
          names = { enUS = "Ruby Life Pools", deDE = "Rubinlebensbecken" },
          shortCodes = { default = "RLP", deDE = "RLB" },
          entrance = { uiMapID = 2022, x = 59.84, y = 75.90, zoneNames = { enUS = "The Waking Shores" } },
          verification = {
            status = "verified",
            verifiedAt = "2026-07-13",
            source = "Portal: PTR C_Spell.GetSpellInfo and approved cross-check; "
              .. "LFG: PTR C_LFGList.GetActivityInfoTable",
          },
        },
        {
          mapID = 584,
          activityIDs = { 1949 },
          portalSpellIDs = { 1286801 },
          displayOrder = 4,
          minimumPlayerLevel = 90,
          names = { enUS = "The Blinding Vale", deDE = "Das blendende Tal" },
          shortCodes = { default = "TBV", deDE = "DBT" },
          entrance = { uiMapID = 2413, x = 27.43, y = 77.98, zoneNames = { enUS = "Harandar" } },
          verification = {
            status = "verified",
            verifiedAt = "2026-07-13",
            source = "Portal: approved cross-check; LFG: PTR Blizzard activity search",
          },
        },
        {
          mapID = 585,
          activityIDs = { 1951 },
          portalSpellIDs = { 1286804 },
          displayOrder = 5,
          minimumPlayerLevel = 90,
          names = { enUS = "Voidscar Arena", deDE = "Arena der Leerennarbe" },
          shortCodes = { default = "VA", deDE = "ADL" },
          entrance = { uiMapID = 2405, x = 53.62, y = 35.45, zoneNames = { enUS = "Voidstorm" } },
          verification = {
            status = "verified",
            verifiedAt = "2026-07-13",
            source = "Portal: approved cross-check; LFG: PTR Blizzard activity search",
          },
        },
        {
          mapID = 586,
          activityIDs = { 1952 },
          portalSpellIDs = { 1286807 },
          displayOrder = 6,
          minimumPlayerLevel = 90,
          names = { enUS = "Den of Nalorakk", deDE = "Nalorakks Bau" },
          shortCodes = { default = "DON", deDE = "NB" },
          entrance = { uiMapID = 2437, x = 29.99, y = 84.45, zoneNames = { enUS = "Zul'Aman" } },
          verification = {
            status = "verified",
            verifiedAt = "2026-07-13",
            source = "Portal: approved cross-check; LFG: PTR Blizzard activity search",
          },
        },
        {
          mapID = 587,
          activityIDs = { 1950 },
          portalSpellIDs = { 1286809 },
          displayOrder = 7,
          minimumPlayerLevel = 90,
          names = { enUS = "Murder Row", deDE = "Mördergasse" },
          shortCodes = { default = "MR", deDE = "MG" },
          entrance = { uiMapID = 2393, x = 56.61, y = 61.10, zoneNames = { enUS = "Silvermoon City" } },
          verification = {
            status = "verified",
            verifiedAt = "2026-07-13",
            source = "Portal: approved cross-check; LFG: PTR Blizzard activity search",
          },
        },
        {
          mapID = 588,
          activityIDs = { 1933 },
          portalSpellIDs = { 1286812 },
          displayOrder = 8,
          minimumPlayerLevel = 90,
          names = { enUS = "Altar of Fangs", deDE = "Der Altar der Fänge" },
          shortCodes = { default = "AOF", deDE = "ADF" },
          entrance = {
            uiMapID = 2509,
            x = 47.29,
            y = 68.16,
            zoneNames = { enUS = "The Coiled Isle", deDE = "Die gewundene Insel" },
          },
          verification = {
            status = "verified",
            verifiedAt = "2026-07-13",
            source = "Portal: approved cross-check; LFG: PTR Blizzard activity search",
          },
        },
      },
    },
  },
}
