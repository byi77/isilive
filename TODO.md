# TODO

## P0 - Release / Review

- [x] `v0.9.65` vorbereiten:
  - `CHANGELOG.md` auf `0.9.65` Runtime-/Doku-Stand bringen
  - `README.md` / `RELEASE.md` auf `0.9.65` Beispiele und Tag-Namen synchronisieren
- [x] `v0.9.65` veroeffentlichen
  - Midnight-S1-Pre-Season-Text und leeres Portal-Grid pruefen
  - unsicheren Roster-Linksklick nicht mehr bewerben
  - DPS-Snapshot fuer `M+` und `M0` ingame querpruefen
- [x] `v0.9.66` vorbereiten:
  - Tooltip-Isolation, Load-Order-Hotfix und private Tooltip-Layoutfixes dokumentieren
  - `README.md` / `ARCHITECTURE.md` / `USECASES.md` / `RELEASE.md` auf `0.9.66` Beispiele und Baselines synchronisieren
- [ ] `v0.9.66` veroeffentlichen
  - isolierte Tooltip-Hover in Roster / Buttons / Teleport / Notice ingame querpruefen
  - Tooltip-Wrap und Kantenabstand bei laengeren Strings im Live-Client pruefen
- [ ] Kurz-Smoketest vor Release:
  - UI oeffnen/schliessen
  - Checkboxen fuer `advancedCombatLogging` / `damageMeterResetOnNewInstance`
  - Blizzard-UI-Aenderung pruefen und kontrollieren, dass `isiLive` nur spiegelt
  - Group join / key start / key end / queue target / teleport button
  - Demo-Refresh
  - `M0` betreten/verlassen mit frueh leavenden Gruppenmitgliedern

## P1 - Quality Gates

- [ ] CI optional um `lua tools/validate_usecases.lua` erweitern (zusaetzlicher Runtime-Gate auf `main`)
- [ ] Optional pruefen, ob `luacheck .` ebenfalls als GitHub-Workflow-Gate aufgenommen werden soll
- [ ] Optional pruefen, ob `lua tools/lua_metrics_check.lua` als separater CI-Check sinnvoll ist

## P2 - Season / Runtime

- [x] Off-Season-Modus vorbereiten:
  - Teleport-Grid ausblenden / leeren
  - Non-Mythic-Warnung deaktivieren
- [ ] Vorbereitung fuer Midnight S1:
  - neue MapIDs recherchieren
  - neue Teleport-Spells recherchieren
  - Alias-/Resolver-Daten anpassen, sobald Blizzard-Daten feststehen
- [ ] Blizzard Damage Meter API nach Patches revalidieren:
  - belastbar pruefen, ob `C_DamageMeter`-Lesepfade im Live-Client unveraendert verfuegbar sind
  - `overall/current` Session-Aufloesung und `combatSources` querpruefen
  - pruefen, ob `amountPerSecond`, `totalAmount` und `durationSeconds` weiterhin stabil geliefert werden

## P3 - Doku / Pflege

- [x] Nach `v0.9.65`: `TODO.md`, `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md` und `WARTUNG.md` wieder auf denselben Stand ziehen
- [x] Nach `v0.9.66`: Tooltip-Doku/Runbooks wieder auf denselben Stand ziehen
- [ ] Release-Text fuer CurseForge / GitHub kurz pruefen, damit die neue passive CVar-Logik klar beschrieben ist

## Geparkt / Nicht aktiv

- [x] Hard-Split `isiLive` -> `isiKeyMPlus` wurde reaktiviert und in `TODO_RENAME.md` konkret geplant
  - Ziel: Hardcut nach `v0.9.70`
  - kein Legacy-Fallback, keine DB-Migration, kein Alt-Sync

## Bereits erledigt (wichtig als Kontext)

- [x] Deterministische Runtime-Usecase-Pruefung (`tools/validate_usecases.lua`)
- [x] Release-Dokus auf Quality-Gates inkl. Usecase-Validator umgestellt
- [x] `isiLive.lua` in Kernmodule zerlegt (`keysync`, `group`, `highlight`, `refresh`, `Event-Routing`)
- [x] Passive Blizzard-CVar-Checkboxen in der Main-UI eingebaut
- [x] `luacheck .` und `lua tools/validate_usecases.lua` aktuell gruen
