# TODO

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
