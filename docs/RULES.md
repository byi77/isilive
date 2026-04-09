# Regeln

## Code
- Niemals raten.
- KICK- und Sync-Zustaende muessen aus belegbaren Live-Daten oder explizit validierten Peer-Payloads stammen; malformed Payloads werden verworfen statt interpretiert.
- Wenn ein Runtime-Wert, Zustand oder Zusammenhang nicht auf einer verifizierbaren Quelle beruht, bleibt er unresolved statt einen Fallback zu erfinden.
- Keine spekulativen Fallbacks, heuristischen Ersatzwerte oder synthetischen Defaults verwenden, ausser sie sind explizit spezifiziert, dokumentiert und durch Tests abgedeckt.
- Solange das Fenster hidden ist, bleiben Queue-Scanning und nicht-synchrones Polling aus; Background-Sync, eventgetriebenes Pre-Render und das Party-Kick-Keep-Alive bleiben aktiv.
- Raid-Gruppen werden als Hard-off-Zustand behandelt: UI ausblenden und jede Hintergrundverarbeitung anhalten, inklusive hidden Kick-Keep-Alive.
- Slash-Command-Verhalten bleibt rueckwaertskompatibel, ausser es wird explizit geaendert.
- Additive Aenderungen vor breaking Refactors bevorzugen.
- Zielplattform ist ausschliesslich WoW-Patch `12.0+`.
- `<12.0` gilt als unsupported/incompatible; dafuer wird kein Legacy-Kompatibilitaetscode hinzugefuegt.
- Die Aktivierung des RIO-Deltas bleibt an den erfolgreichen delayed Post-Run-Refresh gebunden, nicht direkt an das Key-End-Event.
- Wenn der delayed Post-Run-Refresh waehrend Raid-Hard-off faellig wird, wird er verschoben und erst nach Raid-Ende fortgesetzt.
- `CHALLENGE_MODE_COMPLETED` und `CHALLENGE_MODE_RESET` bleiben auch bei hidden Main-Window aktiv, damit Post-Run-Refresh und Delta-Flow verlaesslich bleiben.

## Season-Rahmen
- Das Addon ist season-open; aktive Runtime-Season-Daten werden ausschliesslich ueber `SeasonData.ACTIVE_SEASON_ID` gewaehlt.
- `isiLive_season_data.lua` darf mehrere Seasons enthalten (`active` plus vorbereitete zukuenftige Seasons), aber zur Laufzeit ist immer nur eine Season-ID aktiv.
- `ACTIVE_SEASON_ID` wird nie umgestellt, bevor die Ziel-Season-Mappings (`mapToTeleport`, `displayOrder`, `shortCodesByLocale`, `challengeMapAliases`) vollstaendig und validiert sind.
- Bei Season-Data-Aenderungen muessen `README.md` und `CHANGELOG.md` die aktive Season-ID und den Vorbereitungsstand der naechsten Season explizit nennen.
- Aktuelle Planungsbasis: `midnight_s1` ist das aktive Pre-Season-Dataset.

## Lokalisierung
- Alle user-facing Texte laufen ueber die Lokalisierungstabelle.
- Nicht unterstuetzte Locales fallen auf Englisch zurueck.

## Performance
- Keine Arbeit in `OnUpdate`, ausser sie ist strikt noetig.
- Queues werden beim Wechsel in Standby-Zustaende geleert.

## Dokumentation
- `README.md` wird bei jeder user-visible Verhaltensaenderung aktualisiert.
- Beispiele und Slash-Commands bleiben synchron mit dem Code.
- Aktive UI-Labels in den Dokus bleiben synchron zu den Lokalisierungskeys, zum Beispiel Feature-Liste in `README.md` und ASCII-Skizze in `ARCHITECTURE.md`.
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
- Nur produktiv erzwungene Vertraege werden als `Status: active` markiert und jeweils auf exakte deterministische Testnamen gemappt.
- Fuer Verhaltensfixes wird deterministische Abdeckung in `tools/validate_usecases.lua` hinzugefuegt oder aktualisiert.
- Aktive Runtime-Regeln sind immer Teil des Pflicht-Gates ueber `lua tools/validate_usecases.lua`; Runtime-Aenderungen werden nicht ohne gruene Rule- und Usecase-Validierung gemergt.
- Aktive Architekturregeln sind ebenfalls Teil des Pflicht-Gates ueber `lua tools/validate_usecases.lua`; strukturelle Refactors werden nicht ohne gruene Architektur-, Rule- und Usecase-Validierung gemergt.
- Wenn eine Aenderung Verhalten beruehrt, das durch eine aktive Regel abgedeckt ist, werden Code, deterministische Tests und Regel-zu-Test-Zuordnung im selben Change aktualisiert.
- Wenn sich ein deterministischer Testname aendert, werden alle aktiven `Erforderliche Tests`-Referenzen sofort nachgezogen, damit das Rule-Gate gueltig bleibt.
- Wenn ein Gate scheitert, wird die Ursache behoben und das komplette Gate-Set erneut ausgefuehrt; kein Release auf Teilgruens.
- Bevorzugter lokaler Einstiegspunkt fuer das statische Lint-Gate ist `tools/check.ps1` oder `tools/check.cmd`; damit bleibt der Windows-`luacheck`-Shim aktiv und der App-Auswahldialog wird vermieden.

## Release-Hygiene
- Bei funktionalen Aenderungen wird die Version in `isiLive.toc` hochgezogen.
- Nach Aenderungen wird geprueft, dass das Addon ohne Lua-Fehler laedt.

## Versionierung
- Verwendet wird `MAJOR.MINOR.PATCH` im SemVer-light-Stil, zum Beispiel `0.9.1`.
- Solange das Projekt pre-1.0 ist, bleiben Releases im Schema `0.x.y`.
- `PATCH`-Bump (`0.9.1 -> 0.9.2`): Bugfixes ohne neue user-facing Features.
- `MINOR`-Bump (`0.9.2 -> 0.10.0`): neue Features, neue Commands, neue UI-Controls, backward-compatible Verhalten.
- `MAJOR`-Bump (`0.x -> 1.0.0` oder `1.x -> 2.0.0`): Breaking Changes oder inkompatible Migration.
- Jede funktionale Aenderung aktualisiert:
- `isiLive.toc` Version
- `CHANGELOG.md` Eintrag mit explizitem Datum (`YYYY-MM-DD`)
- `README.md`, wenn user-visible Verhalten, Commands oder Installation geaendert wurden

## Offene Punkte
- Hier koennen projektspezifische Regeln ergaenzt werden.
