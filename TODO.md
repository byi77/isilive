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

## P2 - Pre-Key Readiness / Informationen vor Key-Start

- [x] Key-Spalte anzeigen: Gruppenmitglieder-Key als `Shortcut +Stufe` (z. B. `DB +14`).
- [ ] Affix-Panel einbauen: aktuelle Wochen-Affixe mit kurzem 1-Zeilen-Hinweis pro Affix.
- [ ] Gruppen-Check fuer `Bloodlust/Hero` und `Battle Rez` (Ampel: `ok/fehlt`).
- [ ] Dispel-Coverage anzeigen: `Curse/Poison/Disease/Magic` als Gruppenabdeckung.
- [ ] Kick-Setup anzeigen: Interrupt vorhanden, CD, einfache Reihenfolge (`1-2-3`).
- [ ] Defensive-Readiness vor Start anzeigen (wichtige Def-CDs bereit/nicht bereit).
- [ ] Consumables-Check: Flask/Food/Weapon Buff/Healthstone/Combat Pot (ja/nein).
- [ ] Dungeon-spezifische Warnungen/Hinweise je Key anzeigen (z. B. empfohlene Utility).
- [ ] Route-/Skip-Hinweis-Slot einbauen (kurzer freier Text fuer Gruppenplan).
- [ ] `Pre-Key Checklist`-Button: kompakte Gesamtpruefung mit Gruen/Rot-Status.

## P3 - Entschlackung `isiLive.lua` (nach Release `0.9.26`)

- [ ] `v0.9.26` zuerst releasen (keine strukturellen Refactors im Release-Commit mischen).
- [ ] Baseline dokumentieren: kurzer Ingame-Smoketest vor Refactor (Group join/leave, Queue/Teleport highlight, Key-Spalte, Refresh, Hidden/Sleep).
- [ ] `isiLive_keysync.lua` extrahieren (Key-Sync + Active-Key-Owner-Logik), in `isiLive.lua` nur noch Aufrufe.
- [ ] `isiLive_group.lua` extrahieren (Group-Lifecycle / Roster-Rebuild / Group-Leave-Cleanup).
- [ ] `isiLive_highlight.lua` extrahieren (Active-Target-Resolver + Highlight-State-Entscheidung).
- [ ] `isiLive_refresh.lua` extrahieren (voller Refresh-Flow inkl. forced HELLO/KEY + Inspect-Refresh).
- [ ] Event-Dispatcher in `isiLive.lua` auf dünne Routing-Schicht reduzieren.
- [ ] Nach jedem Schritt: `stylua --check .` + `luacheck --exclude-files ".luarocks/**" -- .` + kurzer Ingame-Smoketest.
- [ ] Zielgroesse: `isiLive.lua` deutlich reduzieren (Richtwert < ~1200 Zeilen) ohne Verhaltensaenderung.
