# TODO

## P0 - Release / Review

- [x] `v0.9.61` veroeffentlichen
- [ ] `v0.9.62` vorbereiten:
  - `isiLive.toc` auf `0.9.62` gehoben
  - `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `USECASES.md`, `RELEASE.md` auf `0.9.62` synchronisiert
- [ ] `v0.9.62` veroeffentlichen
- [ ] Kurz-Smoketest vor Release:
  - Hover-Tooltip auf Roster-Zeilen: nur mit echten Addon-Daten (Spec/iLvl/Rio) pruefen
  - Teleport-Grid und Non-Mythic-Warnung in normalem Season-Betrieb pruefen

## P1 - Quality Gates

- [ ] CI optional um `lua tools/validate_usecases.lua` erweitern (zusaetzlicher Runtime-Gate auf `main`)
- [ ] Optional pruefen, ob `luacheck .` ebenfalls als GitHub-Workflow-Gate aufgenommen werden soll
- [ ] Optional pruefen, ob `lua tools/lua_metrics_check.lua` als separater CI-Check sinnvoll ist

## P2 - Season / Runtime

- [x] Off-Season-Modus vorbereiten:
  - `SeasonData.HasActiveDungeons()` ergaenzt
  - Teleport-Grid blendet sich bei leerem Season-Mapping automatisch aus (kein extra Code noetig)
  - Non-Mythic-Warnung via `controller_wiring` gated hinter `HasActiveDungeons()`
- [ ] Vorbereitung fuer Midnight S1:
  - neue MapIDs recherchieren
  - neue Teleport-Spells recherchieren
  - Alias-/Resolver-Daten anpassen, sobald Blizzard-Daten feststehen

## P3 - Doku / Pflege

- [x] Nach `v0.9.60`: `TODO.md`, `CHANGELOG.md`, `README.md`, `RELEASE.md` wieder auf denselben Stand ziehen
- [x] Release-Text fuer CurseForge / GitHub kurz pruefen, damit die neue passive CVar-Logik klar beschrieben ist

## Geparkt / Nicht aktiv

- [ ] Hard-Split `isiLive` -> `isiKeyMplus` ist aktuell nicht der aktive Arbeitsplan
  - nur bei expliziter Reaktivierung neu aufsetzen
  - alten Split-Plan nicht stillschweigend wieder aufnehmen

## Bereits erledigt (wichtig als Kontext)

- [x] Bugfix: `ShowRosterInfoTooltip` Guard auf class/spec/ilvl/rio (verhindert Doppel-Anchor und falschen Tooltip-Typ)
- [x] `SLASH_ISILIVE2` in `.luacheckrc` ergaenzt (CI Lua Check jetzt vollstaendig gruen)
- [x] Off-Season-Infrastruktur: `SeasonData.HasActiveDungeons()` + Non-Mythic-Warnung gated
- [x] Testabdeckung: `restoreRioBaseline` ADDON_LOADED Test (156 Szenarien); Nil-Guards; Diagnostic Cleanup

- [x] Interne Refaktorierung `isiLive_commands.lua`: `HandleLogCommand` / `HandleQDebugCommand` in gemeinsame `HandleDebugLogCommand` zusammengefuehrt (kein Behavior-Change)
- [x] `/isk` Slash-Alias registriert (`SLASH_ISILIVE2`)
- [x] Rio-Baseline persistent in `IsiLiveDB.rioBaseline` gespeichert und bei `ADDON_LOADED` wiederhergestellt
- [x] Roster-Hover-Tooltip zeigt isiLive-Daten (Name, Realm, Spec, iLvl, Rio, Key)
- [x] Deterministische Runtime-Usecase-Pruefung (`tools/validate_usecases.lua`)
- [x] Release-Dokus auf Quality-Gates inkl. Usecase-Validator umgestellt
- [x] `isiLive.lua` in Kernmodule zerlegt (`keysync`, `group`, `highlight`, `refresh`, Event-Routing)
- [x] Passive Blizzard-CVar-Checkboxen in der Main-UI eingebaut
- [x] `luacheck .` und `lua tools/validate_usecases.lua` aktuell gruen
