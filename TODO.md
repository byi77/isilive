# TODO

## P0 - Release / Review

- [x] `v0.9.65` vorbereiten:
  - `CHANGELOG.md` auf `0.9.65` Runtime-/Doku-Stand bringen
  - `README.md` / `RELEASE.md` auf `0.9.65` Beispiele und Tag-Namen synchronisieren
- [x] `v0.9.65` veroeffentlichen
  - Midnight-S1-Pre-Season-Text und leeres Portal-Grid pruefen
  - unsicheren Roster-Linksklick nicht mehr bewerben
  - DPS-Snapshot fuer `M+` und `M0` ingame querpruefen
- [x] `v0.9.67` vorbereiten:
  - Tooltip-Isolation, Load-Order-Hotfix und private Tooltip-Layoutfixes dokumentieren
  - `README.md` / `ARCHITECTURE.md` / `USECASES.md` / `RELEASE.md` auf `0.9.67` Beispiele und Baselines synchronisieren
- [x] `v0.9.67` veroeffentlichen
  - isolierte Tooltip-Hover in Roster / Buttons / Teleport / Notice ingame querpruefen
  - Tooltip-Wrap und Kantenabstand bei laengeren Strings im Live-Client pruefen
- [x] `v0.9.68` vorbereiten:
  - Post-Run-DPS-Retry fuer `M+` und `M0` dokumentieren
  - `README.md` / `ARCHITECTURE.md` / `USECASES.md` / `RELEASE.md` auf `0.9.68` Beispiele, Baselines und Validator-Zaehler synchronisieren
- [ ] `v0.9.68` veroeffentlichen
  - Ingame querpruefen, dass spaet veroeffentlichte Blizzard-Damage-Meter-Sessions die DPS-Spalte nach Key-Ende/M0-Exit noch fuellen
- [x] `v0.9.70` vorbereiten:
  - `isiLive_stats.lua` Argumentreihenfolge fixen
  - Code Review Robustness (pcall, UnitExists) umsetzen
  - `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md` und `RELEASE.md` auf 0.9.70 synchronisieren
- [x] `v0.9.71` vorbereiten:
  - Diff von `2026-03-10` auf `2026-03-11` fuer die heutigen Commits in die Release-Notes ziehen
  - `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md` und `isiLive.toc` auf 0.9.71 synchronisieren
  - Release-Dokus/Tasks auf den naechsten echten Stable-Stand nach dem archivierten `0.9.70`-Fehlrelease umstellen
- [ ] `v0.9.71` veroeffentlichen
  - erster Release-Tag wurde wieder geloescht
  - zugehoeriges CurseForge-Paket wurde archiviert
  - neuer Stable-Tag erst nach gruenem `Lua Check` auf `main`
  - Ingame Smoketest
  - Kurz-Smoketest vor Release:
    - UI oeffnen/schliessen
    - Checkboxen fuer `advancedCombatLogging` / `damageMeterResetOnNewInstance`
    - Blizzard-UI-Aenderung pruefen und kontrollieren, dass `isiLive` nur spiegelt
    - Group join / key start / key end / queue target / teleport button
    - Demo-Refresh
    - `M0` betreten/verlassen mit frueh leavenden Gruppenmitgliedern

- [x] `v0.9.74` vorbereiten:
  - Auto-Mark Toggle und Logik entfernen
  - Secure Role-Buttons implementieren
  - `CHANGELOG.md` / `README.md` / `RULES_LOGIC.md` aktualisieren
  - Tag: `isiLive_release_0.9.74`

- [x] `v0.9.75` vorbereiten:
  - Tank Helper Buttons (Secure /wm Macros)
  - Mini Mode (Collapse Toggle) und Persistenz
  - Layout-Anpassung und Breite
  - Tag: `isiLive_release_0.9.75`

- [x] `v0.9.78` vorbereiten:
  - Compact-Toggles auf `V` / `H` / `M` umstellen und direkt nebeneinander positionieren
  - Default-Rosterhoehe unten leicht vergroessern, damit M+Marker und `Target Dungeon` sauber getrennt bleiben
  - `Refresh` um gruppenweiten `REQSYNC`-Pfad erweitern, damit Hidden-Peers einmal forciert `KEY/STATS` antworten koennen
  - Doku-/Validator-Zaehler auf `0.9.78` synchronisieren
  - Tag: `isiLive_release_0.9.78`

- [ ] `v0.9.78` veroeffentlichen
  - Ingame Combat-Smoketest fuer Teleport-Grid, Center Notice, Collapse und Role-/M+Marker-Buttons
  - Release-Tag erst nach gruenem `Lua Check` auf `main`

- [x] `v0.9.79` vorbereiten:
  - H/V/M-Layoutbuttons auf statische Direktschalter mit aktiver Gold-Markierung umstellen
  - H-Modus auf `RC` / `CD` / `CD 0` verdichten; `Share Keys` und `Refresh` nur noch in M/V zeigen
  - Raid-Gruppen automatisch in den sichtbaren H-Modus schalten statt die UI auszublenden
  - Doku/Regeln/Release-Beispiele auf `0.9.79` synchronisieren
  - Tag: `isiLive_release_0.9.79`

- [ ] `v0.9.79` veroeffentlichen
  - Ingame pruefen: Raid->H-Modus, H/V/M-Schalter, H-Modus-Shortlabels und versteckte `Share Keys`/`Refresh`
  - Release-Tag erst nach gruenem `Lua Check` auf `main`

- [x] `v0.9.80` vorbereiten:
  - lokalen Last-Run-DPS char-genau statt accountweit in einem Single-Slot persistieren
  - alte mehrwertige `playerLastRuns` nur fuer den exakt passenden lokalen Char migrieren
  - den ambiguen Legacy-Single-Slot `playerLastRun` verwerfen statt ihn auf den zuerst eingeloggenen Char zu raten
  - Doku/Release-Beispiele auf `0.9.80` synchronisieren
  - Tag: `isiLive_release_0.9.80`

- [x] `v0.9.80` veroeffentlichen
  - Ingame pruefen: eigener DPS nach Reload mit demselben Char vorhanden, nach Relog auf anderen Alt nicht uebernommen
  - Release-Tag erst nach gruenem `Lua Check` auf `main`

- [x] `v0.9.81` vorbereiten:
  - PNG-Screenshot-Assets aus dem CurseForge-Paket ausschliessen
  - Doku/Release-Beispiele auf `0.9.81` synchronisieren
  - Validator-Zaehler auf `263` Szenarien abgleichen
  - Tag: `isiLive_release_0.9.81`

- [ ] `v0.9.81` veroeffentlichen
  - pruefen, dass die neuen PNG-Dateien nicht mehr im CurseForge-Artefakt landen
  - Release-Tag erst nach gruenem `Lua Check` auf `main`

## P1 - Quality Gates

- [x] CI optional um `lua tools/validate_usecases.lua` erweitern (zusaetzlicher Runtime-Gate auf `main`)
- [x] Optional pruefen, ob `luacheck .` ebenfalls als GitHub-Workflow-Gate aufgenommen werden soll
- [x] Optional pruefen, ob `lua tools/lua_metrics_check.lua` als separater CI-Check sinnvoll ist

## P2 - Season / Runtime

- [x] Off-Season-Modus vorbereiten:
  - Teleport-Grid ausblenden / leeren
  - Non-Mythic-Warnung deaktivieren
- [ ] Vorbereitung fuer Midnight S1:
  - neue MapIDs recherchieren
  - neue Teleport-Spells recherchieren
  - Alias-/Resolver-Daten anpassen, sobald Blizzard-Daten feststehen
- [x] Blizzard Damage Meter API nach Patches revalidieren:
  - belastbar pruefen, ob `C_DamageMeter`-Lesepfade im Live-Client unveraendert verfuegbar sind
  - `overall/current` Session-Aufloesung und `combatSources` querpruefen
  - pruefen, ob `amountPerSecond`, `totalAmount` und `durationSeconds` weiterhin stabil geliefert werden

## P3 - Doku / Pflege

- [x] Nach `v0.9.65`: `TODO.md`, `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md` und `WARTUNG.md` wieder auf denselben Stand ziehen
- [x] Nach `v0.9.67`: Tooltip-Doku/Runbooks wieder auf denselben Stand ziehen
- [x] Nach `v0.9.68`: DPS-Retry-Doku/Runbooks wieder auf denselben Stand ziehen
- [x] Release-Text fuer CurseForge / GitHub kurz pruefen, damit die neue passive CVar-Logik klar beschrieben ist
- [x] Nach archiviertem `v0.9.70`-Fehlrelease: Release-Dokus/Runbooks auf Tag-delete + CurseForge-Archiv-Flow haerten

## Geparkt / Nicht aktiv

- [x] Hard-Split `isiLive` -> `isiKeyMPlus` wurde reaktiviert und in `TODO_RENAME.md` konkret geplant
  - Ziel: Hardcut nach `v0.9.71`
  - kein Legacy-Fallback, keine DB-Migration, kein Alt-Sync

## Bereits erledigt (wichtig als Kontext)

- [x] Deterministische Runtime-Usecase-Pruefung (`tools/validate_usecases.lua`)
- [x] Release-Dokus auf Quality-Gates inkl. Usecase-Validator umgestellt
- [x] `isiLive.lua` in Kernmodule zerlegt (`keysync`, `group`, `highlight`, `refresh`, `Event-Routing`)
- [x] Passive Blizzard-CVar-Checkboxen in der Main-UI eingebaut
- [x] `luacheck .` und `lua tools/validate_usecases.lua` aktuell gruen
