local _, addonTable = ...

addonTable = addonTable or {}

-- Start values for the forces pace, used for a dungeon until the player has a
-- learned route that fits the run (game/isiLive_forces_pace.lua).
--
-- Every number is the enemy-forces percentage measured at a boss kill in our
-- own completed runs. Do not fill this table from another addon: external
-- route tables are not ours to redistribute. A dungeon without a measured run
-- stays out of the table and shows no target before the last boss.
--
-- Same shape as IsiLiveDB.forcesPace[seasonID][mapID].routes, and read through
-- the same validation. A season without an entry shows learned values only.
addonTable.ForcesSeed = {
  midnight_s2 = {
    [250] = { -- Temple of Sethraliss
      routes = {
        ["1-2-3-4"] = { order = { 1, 2, 3, 4 }, checkpoints = { 21.7, 61.4, 83.7, 100 }, leanScore = 266.8 },
      },
    },
    [399] = { -- Ruby Life Pools
      routes = {
        ["1-2-3"] = { order = { 1, 2, 3 }, checkpoints = { 29.9, 73.1, 98.4 }, leanScore = 201.4 },
      },
    },
    [584] = { -- The Blinding Vale
      routes = {
        ["1-2-3-4"] = { order = { 1, 2, 3, 4 }, checkpoints = { 36, 47.8, 67.1, 99.1 }, leanScore = 250 },
      },
    },
    [585] = { -- Voidscar Arena
      routes = {
        ["1-2-3"] = { order = { 1, 2, 3 }, checkpoints = { 35.5, 55.7, 100 }, leanScore = 191.2 },
      },
    },
    [586] = { -- Den of Nalorakk
      routes = {
        ["1-2-3"] = { order = { 1, 2, 3 }, checkpoints = { 28.7, 55.8, 85.2 }, leanScore = 169.7 },
      },
    },
    [587] = { -- Murder Row
      routes = {
        ["1-2-3-4"] = { order = { 1, 2, 3, 4 }, checkpoints = { 26.7, 30.7, 60.8, 90.8 }, leanScore = 209 },
      },
    },
    [588] = { -- Altar of Fangs
      routes = {
        ["1-2-3"] = { order = { 1, 2, 3 }, checkpoints = { 43.8, 61.3, 99 }, leanScore = 204.1 },
      },
    },
  },
}
