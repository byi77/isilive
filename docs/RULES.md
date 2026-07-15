# Regeln

## Code
- Niemals raten.
- KICK- und Sync-Zustaende muessen aus belegbaren Live-Daten oder explizit validierten Peer-Payloads stammen; malformed Payloads werden verworfen statt interpretiert.
- Wenn ein Runtime-Wert, Zustand oder Zusammenhang nicht auf einer verifizierbaren Quelle beruht, bleibt er unresolved statt einen Fallback zu erfinden.
- Keine spekulativen Fallbacks, heuristischen Ersatzwerte oder synthetischen Defaults verwenden, ausser sie sind explizit spezifiziert, dokumentiert und durch Tests abgedeckt.
- Solange das Fenster hidden ist, bleiben Queue-Scanning und nicht-synchrones Polling aus; Background-Sync, eventgetriebenes Pre-Render und das Gruppen-Kick-Keep-Alive fuer normale Gruppen oder verifizierte automatische Instanzgruppen bleiben aktiv. Solo darf der Kick-Heartbeat nicht scannen oder senden.
- Raid-Gruppen werden als Hard-off-Zustand behandelt: UI ausblenden und jede Hintergrundverarbeitung anhalten, inklusive hidden Kick-Keep-Alive.
- Slash-Command-Verhalten bleibt rueckwaertskompatibel, ausser es wird explizit geaendert.
- Additive Aenderungen vor breaking Refactors bevorzugen.
- Zielplattform ist ausschliesslich WoW-Patch `12.0.7+`.
- `<12.0.7` gilt als unsupported/incompatible; dafuer wird kein Legacy-Kompatibilitaetscode hinzugefuegt.
- Die Aktivierung des RIO-Deltas bleibt an den erfolgreichen delayed Post-Run-Refresh gebunden, nicht direkt an das Key-End-Event.
- Wenn der delayed Post-Run-Refresh waehrend Raid-Hard-off faellig wird, wird er verschoben und erst nach Raid-Ende fortgesetzt.
- `CHALLENGE_MODE_COMPLETED` und `CHALLENGE_MODE_RESET` bleiben auch bei hidden Main-Window aktiv, damit Post-Run-Refresh und Delta-Flow verlaesslich bleiben.

## Season-Rahmen
- Das Addon ist season-open; die aktive Runtime-Season wird ausschliesslich ueber `activeSeasonID` in `data/isiLive_seasons.lua` festgelegt und von `SeasonData.ACTIVE_SEASON_ID` gespiegelt.
- `data/isiLive_seasons.lua` ist die einzige manuell gepflegte Runtime-Saisonquelle und darf mehrere Seasons enthalten (`active` plus vorbereitete zukuenftige Seasons); pro Dungeon werden IDs, Darstellungsdaten, Stufengate, Portalraum-Slot und Verifikationsmetadaten in einem Datensatz gepflegt.
- `isiLive_season_data.lua` enthaelt nur Compiler, Validierung und Zugriffsfunktionen fuer die aus dem Manifest erzeugten Indizes. Parallele saisonale Tabellen in LFG-, Status- oder MDT-Werkzeugcode sind verboten; der generierte Forces-Datensatz bleibt separat.
- `ACTIVE_SEASON_ID` wird nur automatisch umgestellt, wenn Blizzards Challenge-Map-Satz exakt zu einer vorbereiteten Season passt, deren Ziel-Season-Mappings (`mapToTeleport`, `displayOrder`, `shortCodesByLocale`, `namesByLocale`, `challengeMapAliases`) vollstaendig validiert sind und deren passende Forces-DB frisch ist.
- Bei Season-Data-Aenderungen muessen `README.md` und `CHANGELOG.md` die aktive Season-ID und den Vorbereitungsstand der naechsten Season explizit nennen.
- Zeitgebundene Aktivierungs- und Intake-Staende gehoeren in `README.md`,
  `docs/SEASON_INTAKE.md` und `docs/WARTUNG.md`, nicht in diese stabilen Regeln.

## Lokalisierung
- Alle user-facing Texte laufen ueber die Lokalisierungstabelle.
- Nicht unterstuetzte Locales fallen auf Englisch zurueck.
- Beim Programmieren werden neue Texte mindestens auf Englisch und Deutsch gepflegt; vorbereitete weitere Locales duerfen bis zur Nachbearbeitung englische Fallbacks behalten.
- Hilfreiche Uebersetzungs-PRs fuer vorbereitete Locales werden dankend integriert, sofern sie technisch mit den aktuellen UI-/Regelvertraegen kompatibel gemacht werden.
- Externe Uebersetzungshelfer werden im Changelog dankend erwaehnt.
- Locale-Tag-zu-Sprachflaggen-Aufloesung muss auf Tooltip-Hotpaths ueber konstante Lookups laufen; kein Lazy-Aufbau durch Iteration der Sprachliste beim Hover.
- Status darf nicht ausschliesslich durch Farbe vermittelt werden; Ready-Check-Zustaende kombinieren Hintergrundfarbe und eindeutiges Blizzard-Statussymbol.

## Performance
- Keine Arbeit in `OnUpdate`, ausser sie ist strikt noetig.
- Laufende Timer werden bei Bedarf aus belastbaren Blizzard-Daten gelesen statt ueber einen eigenen hochfrequenten Frame-Poller fortgeschrieben.
- Periodische UI-Refreshes aktualisieren die kleinste betroffene Oberflaeche; vollstaendige Roster-, Layout- oder Unit-Token-Scans brauchen einen eigenen belegten Anlass.
- Hotpath-Logging formatiert keine Strings, solange der zugehoerige Logger deaktiviert ist.
- Queues werden beim Wechsel in Standby-Zustaende geleert.

## Dokumentation
- `README.md` wird bei jeder user-visible Verhaltensaenderung aktualisiert.
- Beispiele und Slash-Commands bleiben synchron mit dem Code.
- Aktive UI-Labels in den Dokus bleiben synchron zu den Lokalisierungskeys, zum Beispiel Feature-Liste in `README.md` und ASCII-Skizze in `ARCHITECTURE.md`.
- UI-Beschreibungen mit Buff-Rating-Herzchen verwenden die Datei `media/heart_bonus_green.tga`; der WoW-API-Pfad darf extensionless `media/heart_bonus_green` sein. Font-Herz-Glyphen werden dafuer nicht dokumentiert.
- Das dokumentierte Roster-Format bleibt synchron zur Runtime, insbesondere das `RIO`-Deltaformat `(+X)RIO` ohne negative Werte.
- `CHANGELOG.md` wird bei jeder funktionalen oder Code-Aenderung aktualisiert.
- Changelog-Eintraege tragen immer ein explizites Datum im Format `YYYY-MM-DD`.
- `ARCHITECTURE.md` wird aktualisiert, wenn sich Modulgrenzen oder Runtime-Flow aendern.
- `USECASES.md` wird aktualisiert, wenn sich funktionales Verhalten oder Use-Case-Flows aendern.
- `RELEASE.md` haelt die Quality-Gate-Kommandos synchron zu den echten Projekt-Gates.
- Sprachregel fuer Dokus: `README.md`, `CHANGELOG.md` und `CHANGELOG_RELEASE.md` bleiben Englisch; alle anderen gepflegten Projektdokumente werden auf Deutsch gehalten.

## Validierung
- Vor Release-Commits laufen alle lokalen Quality Gates:
- `stylua --check .`
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1`
- `cmd /c tools\check.cmd`
- Lua-Syntax-Parse fuer alle `.lua`-Dateien (`luac -p`)
- `lua tools/lua_metrics_check.lua`
- `lua tools/validate_rules_logic.lua`
- `lua tools/validate_architecture_rules.lua`
- `lua tools/validate_usecases.lua`
- Erzwingbare Usecase- und Runtime-Vertraege liegen in `RULES_LOGIC.md` mit stabilen `RULE-ID`-Bloecken.
- Erzwingbare Architekturvertraege liegen in `ARCHITECTURE_RULES.md` mit stabilen `RULE-ID`-Bloecken.
- Nur produktiv erzwungene Vertraege werden als `Status: aktiv` markiert und jeweils auf exakte deterministische Testnamen gemappt.
- Fuer Verhaltensfixes wird deterministische Abdeckung in `tools/validate_usecases.lua` hinzugefuegt oder aktualisiert.
- Aktive Runtime-Regeln sind immer Teil des Pflicht-Gates ueber `lua tools/validate_usecases.lua`; Runtime-Aenderungen werden nicht ohne gruene Rule- und Usecase-Validierung gemergt.
- Aktive Architekturregeln sind ebenfalls Teil des Pflicht-Gates ueber `lua tools/validate_usecases.lua`; strukturelle Refactors werden nicht ohne gruene Architektur-, Rule- und Usecase-Validierung gemergt.
- Wenn eine Aenderung Verhalten beruehrt, das durch eine aktive Regel abgedeckt ist, werden Code, deterministische Tests und Regel-zu-Test-Zuordnung im selben Change aktualisiert.
- Wenn sich ein deterministischer Testname aendert, werden alle aktiven `Erforderliche Tests`-Referenzen sofort nachgezogen, damit das Rule-Gate gueltig bleibt.
- Wenn ein Gate scheitert, wird die Ursache behoben und das komplette Gate-Set erneut ausgefuehrt; kein Release auf Teilgruens.
- Bevorzugter lokaler Einstiegspunkt fuer das statische Lint-Gate ist `tools/check.ps1` oder `tools/check.cmd`; damit bleibt der Windows-`luacheck`-Shim aktiv und der App-Auswahldialog wird vermieden.

## Release-Hygiene
- Die Version in `isiLive.toc` wird nur auf ausdrueckliches User-Kommando hochgezogen.
- `CHANGELOG_RELEASE.md` bleibt ein kurzer, user-facing Release-Stub fuer CurseForge/Wago und wird bei sichtbaren Features ebenfalls aktualisiert.
- Die Herkunft und der Lizenzstatus gebuendelter Drittbibliotheken, Sounds und
  Texturen werden in `docs/ASSET_PROVENANCE.md` gepflegt. Unbekannte
  Datei-zu-Quelle-Zuordnungen bleiben `unresolved` und werden nicht aus Namen
  oder Metadaten abgeleitet.
- Oeffentliche Entwicklungs-Mockups muessen ihren Zweck, ihre Abhaengigkeiten
  und ihren Ausschluss aus dem Addonpaket direkt im Mockup-Verzeichnis
  dokumentieren.
- Nach Aenderungen wird geprueft, dass das Addon ohne Lua-Fehler laedt.
- Commits und Pushes werden nur auf ausdrueckliches User-Kommando ausgefuehrt.

## Versionierung
- Verwendet wird `MAJOR.MINOR.PATCH` im SemVer-light-Stil, zum Beispiel `0.9.1`.
- Solange das Projekt pre-1.0 ist, bleiben Releases im Schema `0.x.y`.
- `PATCH`-Bump (`0.9.1 -> 0.9.2`): Bugfixes ohne neue user-facing Features.
- `MINOR`-Bump (`0.9.2 -> 0.10.0`): neue Features, neue Commands, neue UI-Controls, backward-compatible Verhalten.
- `MAJOR`-Bump (`0.x -> 1.0.0` oder `1.x -> 2.0.0`): Breaking Changes oder inkompatible Migration.
- Jede funktionale Aenderung aktualisiert, sofern vom User kein anderer Release-Zuschnitt vorgegeben ist:
- `CHANGELOG.md` Eintrag mit explizitem Datum (`YYYY-MM-DD`)
- `README.md`, wenn user-visible Verhalten, Commands oder Installation geaendert wurden
- `isiLive.toc` Version nur bei ausdruecklichem User-Kommando

## Supply Chain

- Externe GitHub Actions werden auf vollstaendige Commit-SHAs gepinnt; der lesbare Major-Tag bleibt als Kommentar erhalten und Dependabot pflegt die Pins.
- Fremde, frisch geklonte Lua-Datenquellen duerfen in schreibenden Workflows keinen Zugriff auf `_G`, Datei-/Prozessfunktionen oder unbeschraenkte Ausfuehrung erhalten.

## Offene Punkte
- Hier koennen projektspezifische Regeln ergaenzt werden.
