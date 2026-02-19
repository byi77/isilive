# TODO

## P0 - Reliability Gates

- [x] Deterministische Runtime-Usecase-Pruefung als Script angelegt (`tools/validate_usecases.lua`).
- [x] Release-Dokus auf harte Quality-Gates inkl. Usecase-Validator umgestellt (`README.md`, `RELEASE.md`).
- [ ] CI Workflow optional um `tools/validate_usecases.lua` erweitern (zusatzlicher Runtime-Gate auf `main`).

## P1 - Rename `isiLive` -> `isiKeyMPlus` (stabil, mit Kompatibilitaet)

- [ ] Rename aller Addon-Dateien per `git mv` (`isiLive*` -> `isiKeyMPlus*`) inkl. `.toc`.
- [ ] Verzeichnis-Name in WoW AddOns von `isiLive` auf `isiKeyMPlus` umstellen.
- [ ] Alle Referenzen im Code auf den neuen Namen umstellen (Strings, Frame-Namen, Binding-Buttons, Pfade).
- [ ] `isiLive.toc` nach `isiKeyMPlus.toc`: Title, Dateiliste und Metadaten aktualisieren.
- [ ] SavedVariables-Migration: `IsiLiveDB` nach `IsiKeyMPlusDB` mit sicherer Uebernahme bei Upgrade.
- [ ] Optionaler Legacy-Alias fuer Slash-Command (`/isilive`) fuer 1-2 Releases beibehalten.
- [ ] Addon-Kommunikation/Prefix auf neuen Namensraum umstellen (ggf. temporaere Rueckwaertskompatibilitaet).
- [ ] Release/Packaging/Git aktualisieren: `.pkgmeta`, Workflow-Tag-Prefix, Doku.
- [ ] `.luacheckrc` auf neuen Standard-/Global-Namen anpassen.
- [ ] Validierung: Resttreffer-Suche, Lua-Checks/Lint, Ingame-Smoketest (Load, UI, Queue, Sync, Teleport).

## P2 - Pre-Key Readiness / Informationen vor Key-Start

- [x] Key-Spalte anzeigen: Gruppenmitglieder-Key als `Shortcut +Stufe` (z. B. `DB +14`).
- [ ] **Next Week:** Off-Season Modus aktivieren (Teleport-Grid ausblenden/leeren, Non-Mythic Warnung deaktivieren).
- [ ] **Next Week:** Vorbereitung Midnight S1 (neue MapIDs/Spells recherchieren).

## P3 - Entschlackung `isiLive.lua` (nach Release `0.9.26`)

- [x] `v0.9.26` zuerst releasen (keine strukturellen Refactors im Release-Commit mischen).
- [x] Baseline dokumentieren: kurzer Ingame-Smoketest vor Refactor (Group join/leave, Queue/Teleport highlight, Key-Spalte, Refresh, Hidden/Sleep). Siehe `README.md` Abschnitt `Use Case / Logic Baseline (v0.9.26)`.
- [x] `isiLive_keysync.lua` extrahieren (Key-Sync + Active-Key-Owner-Logik), in `isiLive.lua` nur noch Aufrufe.
- [x] `isiLive_group.lua` extrahieren (Group-Lifecycle / Roster-Rebuild / Group-Leave-Cleanup).
- [x] `isiLive_highlight.lua` extrahieren (Active-Target-Resolver + Highlight-State-Entscheidung).
- [x] `isiLive_refresh.lua` extrahieren (voller Refresh-Flow inkl. forced HELLO/KEY + Inspect-Refresh).
- [x] Event-Dispatcher in `isiLive.lua` auf duenne Routing-Schicht reduzieren.
- [x] Nach jedem Schritt: `stylua --check .` + `luacheck --exclude-files ".luarocks/**" -- .` + `lua tools/lua_metrics_check.lua` + kurzer Ingame-Smoketest.
- [x] Zielgroesse: `isiLive.lua` deutlich reduzieren (Richtwert < ~1200 Zeilen) ohne Verhaltensaenderung.
