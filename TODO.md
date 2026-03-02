# TODO

## P0 - Release / Review

- [x] `v0.9.59` vorbereiten:
  - `isiLive.toc` auf `0.9.59` heben
  - `CHANGELOG.md` auf aktuellen Runtime-Stand bringen
  - `README.md` / `RELEASE.md` auf `0.9.59` Beispiele und Tag-Namen synchronisieren
- [ ] `v0.9.59` als entschärften Folge-Release gegenueber `0.9.58` veroeffentlichen
  - passive Blizzard-CVar-Checkboxen statt hartem Erzwingen
  - reduzierte Sync-Aktivitaet aus `v0.9.58` beibehalten
- [ ] Kurz-Smoketest vor Release:
  - UI oeffnen/schliessen
  - Checkboxen fuer `advancedCombatLogging` / `damageMeterResetOnNewInstance`
  - Blizzard-UI-Aenderung pruefen und kontrollieren, dass `isiLive` nur spiegelt
  - Group join / key start / key end / queue target / teleport button

## P1 - Quality Gates

- [ ] CI optional um `lua tools/validate_usecases.lua` erweitern (zusaetzlicher Runtime-Gate auf `main`)
- [ ] Optional pruefen, ob `luacheck .` ebenfalls als GitHub-Workflow-Gate aufgenommen werden soll
- [ ] Optional pruefen, ob `lua tools/lua_metrics_check.lua` als separater CI-Check sinnvoll ist

## P2 - Season / Runtime

- [ ] Off-Season-Modus vorbereiten:
  - Teleport-Grid ausblenden / leeren
  - Non-Mythic-Warnung deaktivieren
- [ ] Vorbereitung fuer Midnight S1:
  - neue MapIDs recherchieren
  - neue Teleport-Spells recherchieren
  - Alias-/Resolver-Daten anpassen, sobald Blizzard-Daten feststehen

## P3 - Doku / Pflege

- [ ] Nach `v0.9.59`: `TODO.md`, `CHANGELOG.md`, `README.md`, `RELEASE.md` wieder auf denselben Stand ziehen
- [ ] Release-Text fuer CurseForge / GitHub kurz pruefen, damit die neue passive CVar-Logik klar beschrieben ist

## Geparkt / Nicht aktiv

- [ ] Hard-Split `isiLive` -> `isiKeyMplus` ist aktuell nicht der aktive Arbeitsplan
  - nur bei expliziter Reaktivierung neu aufsetzen
  - alten Split-Plan nicht stillschweigend wieder aufnehmen

## Bereits erledigt (wichtig als Kontext)

- [x] Deterministische Runtime-Usecase-Pruefung (`tools/validate_usecases.lua`)
- [x] Release-Dokus auf Quality-Gates inkl. Usecase-Validator umgestellt
- [x] `isiLive.lua` in Kernmodule zerlegt (`keysync`, `group`, `highlight`, `refresh`, Event-Routing)
- [x] Passive Blizzard-CVar-Checkboxen in der Main-UI eingebaut
- [x] `luacheck .` und `lua tools/validate_usecases.lua` aktuell gruen
