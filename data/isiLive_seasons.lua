local _, addonTable = ...

addonTable = addonTable or {}

-- Central maintenance file for all manually curated season data.
-- Each season defines its activation state, MDT/forces requirements, inactive messages,
-- portal navigator layout, and one complete record per dungeon.
-- Each dungeon record keeps the map, activity, portal spell, display order, level,
-- localized name, short code, and optional verification metadata together.
--
-- Maintenance workflow for a new season:
-- 1. Add a new entry under `seasons`; do not overwrite historical season entries.
-- 2. Add every dungeon exactly once and use only IDs confirmed by a reliable source.
-- 3. Keep `autoDetectFromChallengeMaps = false` until the season is ready for activation.
-- 4. Set `mdtDirectory` only when the exact MDT directory is verified; never guess it.
-- 5. Change `activeSeasonID` only after the full season intake has been verified.
-- 6. Run `lua tools/check_season_intake.lua` and `lua tools/validate_usecases.lua`.
--
-- Runtime lookup tables are compiled from this manifest by game/isiLive_season_data.lua.
-- Generated M+ forces payloads intentionally remain in data/isiLive_mplus_forces.lua.
addonTable.SeasonManifest = {
  activeSeasonID = "midnight_s1",
  seasons = {
    midnight_s1 = {
      label = "Midnight Season 1",
      autoDetectFromChallengeMaps = true,
      requiresForces = true,
      mdtDirectory = "Midnight",
      inactivePortalMessageByLocale = {},
      portalNavigator = {
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
      autoDetectFromChallengeMaps = false,
      requiresForces = false,
      inactivePortalMessageByLocale = {
        default = "Midnight Season 2 is prepared but not active yet.",
        deDE = "Midnight Season 2 ist vorbereitet, aber noch nicht aktiv.",
      },
      portalNavigator = {
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
      dungeons = {
        {
          mapID = 249,
          activityIDs = { 514 },
          portalSpellIDs = { 1286831 },
          displayOrder = 1,
          names = { enUS = "King's Rest", deDE = "Königsruh" },
          shortCodes = { default = "KR", deDE = "KR" },
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
