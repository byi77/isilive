# TODO

## P0 - Release / Review

- [x] `v0.9.90` vorbereiten:
  - Doku- und Baseline-Sync auf `0.9.90` abgeschlossen
  - `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `TODO.md`, `CHANGELOG.md` und `isiLive.toc` auf `0.9.90` synchronisieren
  - Tag: `isiLive_release_0.9.90`

- [x] `v0.9.85` vorbereiten:
  - erweiterte Blizzard-Settings, Hidden-Legacy-Controls und die hart gesetzten Runtime-Defaults dokumentieren
  - Exit-DPS-Capture fuer normale, heroische und mythische Non-Challenge-Dungeons in den Baselines/Release-Notes nachziehen
  - `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `TODO.md`, `CHANGELOG.md` und `isiLive.toc` auf `0.9.85` synchronisieren
  - Tag: `isiLive_release_0.9.85`

- [x] `v0.9.84` vorbereiten:
  - Heart-Sync-Marker, DPS/LOC-Sync und 4-Zeichen-Spec-Labels dokumentieren
  - Blizzard-Settings `Background Opacity` und Combat-Close-Verhalten in den Release-Notes und Baselines nachziehen
  - `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `TODO.md` und `CHANGELOG.md` auf `0.9.84` synchronisieren
  - Tag: `isiLive_release_0.9.84`

- [x] `v0.9.83` vorbereiten:
  - Esc-Menu-Shortcut-Strip und Blizzard-Settings-Panel dokumentieren
  - UI-Polish fuer Roster/Notice/Tooltip-Frames in den Release-Notes nachziehen
  - `CHANGELOG.md`, `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RELEASE.md`, `TODO.md` und `isiLive.toc` auf `0.9.83` synchronisieren
  - Tag: `isiLive_release_0.9.83`

- [x] `v0.9.82` vorbereiten:
  - Combat-Defer fuer Main-UI-Sichtbarkeit und Regen-Replay dokumentieren
  - Midnight-S1-Portalpool mit finalen Map-/Spell-IDs und Shortcodes dokumentieren
  - kompaktere `Marker`/`Travel`-Beschriftung im Roster-Panel nachziehen
  - LuaLS-/Validator-Haertung fuer dynamische UI-Testfixtures und Regen-Visibility-Wiring nachziehen
  - `CHANGELOG.md`, `README.md`, `USECASES.md`, `ARCHITECTURE.md`, `RULES_LOGIC.md`, `TODO.md` und `isiLive.toc` synchronisieren
  - Tag: `isiLive_release_0.9.82`

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
- [x] `v0.9.70` vorbereiten:
  - `isiLive_stats.lua` Argumentreihenfolge fixen
  - Code Review Robustness (pcall, UnitExists) umsetzen
  - `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md` und `RELEASE.md` auf 0.9.70 synchronisieren
- [x] `v0.9.71` vorbereiten:
  - Diff von `2026-03-10` auf `2026-03-11` fuer die heutigen Commits in die Release-Notes ziehen
  - `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md` und `isiLive.toc` auf 0.9.71 synchronisieren
  - Release-Dokus/Tasks auf den naechsten echten Stable-Stand nach dem archivierten `0.9.70`-Fehlrelease umstellen
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

- [x] `v0.9.79` vorbereiten:
  - H/V/M-Layoutbuttons auf statische Direktschalter mit aktiver Gold-Markierung umstellen
  - H-Modus auf `RC` / `CD` / `CD 0` verdichten; `Share Keys` und `Refresh` nur noch in M/V zeigen
  - Raid-Gruppen automatisch in den sichtbaren H-Modus schalten statt die UI auszublenden
  - Doku/Regeln/Release-Beispiele auf `0.9.79` synchronisieren
  - Tag: `isiLive_release_0.9.79`

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

## P1 - Quality Gates

- [x] CI optional um `lua tools/validate_usecases.lua` erweitern (zusaetzlicher Runtime-Gate auf `main`)
- [x] Optional pruefen, ob `luacheck .` ebenfalls als GitHub-Workflow-Gate aufgenommen werden soll
- [x] Optional pruefen, ob `lua tools/lua_metrics_check.lua` als separater CI-Check sinnvoll ist

## P2 - UI / Navigation

- [ ] M2-UI-Umbau weiterziehen:
  - Abstaende, Reihenfolge und visuelle Hierarchie der Hauptansicht weiter glatten
  - Portalreihe, Statuszeile und Bedienung im Haupt-Layout gegen die neuen Defaults pruefen
- [ ] Portalraum-Navigator definieren:
  - schnelle Navigation zwischen Portalraum, Zielportal und aktiver Zielanzeige konzipieren
  - pruefen, ob die Navigation rein als UI-Hilfe oder als echtes Bedien-Feature umgesetzt werden soll

## P2 - Season / Runtime

- [x] Off-Season-Modus vorbereiten:
  - Teleport-Grid ausblenden / leeren
  - Non-Mythic-Warnung deaktivieren
- [x] Vorbereitung fuer Midnight S1:
  - neue MapIDs recherchieren (erledigt in v0.9.82)
  - neue Teleport-Spells recherchieren (erledigt in v0.9.82)
  - Alias-/Resolver-Daten anpassen (erledigt in v0.9.82)
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

- [x] Hard-Split `isiLive` -> `isiKeyMPlus` wurde **storniert**.
  - Der Addon-Name bleibt dauerhaft `isiLive`.

## Bereits erledigt (wichtig als Kontext)

- [x] Deterministische Runtime-Usecase-Pruefung (`tools/validate_usecases.lua`)
- [x] Release-Dokus auf Quality-Gates inkl. Usecase-Validator umgestellt
- [x] `isiLive.lua` in Kernmodule zerlegt (`keysync`, `group`, `highlight`, `refresh`, `Event-Routing`)
- [x] Passive Blizzard-CVar-Checkboxen in der Main-UI eingebaut
- [x] `luacheck .` und `lua tools/validate_usecases.lua` aktuell gruen
