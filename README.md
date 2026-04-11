# isiLive

WoW Mythic+ group helper addon focused on pre-key group overview and in-key tracking.

Compatibility: WoW `12.0+` only.
Current version: `0.9.147`.

---

## Features

### Group Roster

- Roster table with columns: `Spec`, `Name`, `Flag`, `Key`, `iLvl`, `RIO`, `DPS`, `Kick`
- Stable role sort: Tank → Healer → Damager
- Addon-presence marker (blue heart) per member; group leaders show an additional crown icon
- Ghost rows: players who leave remain visible (greyed out) until the next roster rebuild
- Right-click a roster row to Whisper

### Layouts

- **M2** — main stacked layout (default): full roster + all M+ tools
- **H** — slim horizontal tool strip with compact leader buttons
- **V** — compact vertical palette with markers and management only
- `CTRL+F9` toggles the main window; the title bar in M2 shows this hint directly
- Active mode button is highlighted in gold; mode persists via `Default UI on Open`

### M+ Utility Row (M2 only)

- **BR/BL Tracker:** live Battle Res charges/cooldown, Bloodlust/Heroism remaining time with spell icons
- **M+ Timer:** countdown with `+3` / `+2` / `+1` cutoffs and death-penalty loss; rerenders live during a running key

### M+ Killtracker Row (M2 only)

- Permanently visible bottom row showing Enemy Forces (`EF`) percentage as a labelled progress bar
- Bar colour: green (<80%), yellow (<95%), red (≥95%)
- Shows `--,--` when no key is active; resets immediately on key end or reset
- **Pull prediction:** while in combat, a light-blue bar segment appended to the right of the main bar shows the forces delta of the current pull; the same value appears as `+X,XX%` text next to the main percentage
- Pull prediction uses a scenario-quantity delta (combat-start snapshot vs. current value) — the only viable method in Midnight M+ where all NPC identification APIs return secret values inside the instance
- Data source: `C_ScenarioInfo.GetScenarioStepInfo()` weighted-progress criterion

### Kick Cooldown Sync

- `Kick` column shows synced interrupt state per party member: `ready` or remaining seconds
- Spec-specific interrupt spell, smooth interpolation between packets, no guessing
- Kick state stays unresolved if exact cooldown proof is unavailable after raid exit

### Teleport Grid

- 8 Midnight Season 1 dungeon portals in deterministic display order
- Cooldown shown as `HH:MM`; active dungeon highlighted from concrete target context only
- Short code rendered on icon when portal is ready; hidden during cooldown
- Portal targets highlighted only from active listing or exact synced target data — never guessed
- **LFG detection:** when the player accepts an LFG group invite or creates their own LFG queue listing, the matching portal icon is highlighted automatically (gold border + glow animation); highlight clears when the queue is cancelled, the group dissolves, or the key starts

### Addon Sync

- Party members with `isiLive` share `Spec`, `iLvl`, `RIO`, `DPS`, `Key`, dungeon location, and kick state
- `LibKeystone`-compatible addons can contribute `Key` + `RIO` without `isiLive`
- Manual `Re-Sync` force-sends the full local snapshot and requests replies from all peers
- `Share Keys` posts all party keys to chat; 30s cooldown shared across all `isiLive` clients

### M+ Markers

- 8 world marker buttons (`Square`, `Triangle`, `Diamond`, `Cross`, `Star`, `Circle`, `Moon`, `Skull`)
- Secure native world-marker actions; vertical stack in M2, single row in H layout

### Esc Menu Shortcuts (optional)

- Tooling strip: `Professions`, `Talents`, `Spells`, `Achievements`, `Quests`, `Dungeons`, `Journal`, `Collections`, `Guild`, `ReloadUI`
- Travel strip: `Arkantine`, `Hearthstone`, `Housing`
- Toggle via `Show ESC Menu Shortcuts` in Blizzard Settings

### Blizzard Settings (`Settings → AddOns → isiLive`)

Language, Advanced Combat Logging, DM Reset on Dungeon Entry, Show ESC Menu Shortcuts, Background Opacity, UI Scale, Default UI on Open, Minimap Button, Addon Sync, Auto-Open on M+ Queue, Auto-Close on Key Start / Solo, Column Guides, Sound: Lead Transfer, Sound: Group Join, Queue Debug Log, Runtime Log

### Auto-Behaviour

- Auto-open on real small-group join, key end, and dungeon entry while grouped
- Raid-size groups (`>5` members) hide the UI and stop all background processing
- `Auto-Close on Key Start / Solo` defaults to disabled

---

## Hotkeys

| Key | Action |
|---|---|
| `CTRL+F9` | Toggle main window |
| `CTRL+ALT+F9` | Toggle demo mode (activates/deactivates without closing the UI; deactivation restores real group state) |

## Slash Commands

```
/isilive testall
/isilive log [on|off|clear|tail [n]]
/isilive stop
/isilive start
```

---

## Season

Active season: `midnight_s1` — 8 dungeons: `WRS`, `MT`, `NPX`, `MC`, `AA`, `POS`, `SOT`, `SR`
