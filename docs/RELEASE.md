# Freigabe-Runbook

Dies ist der verbindliche Release-Ablauf fuer `isiLive` (Repository- und Tag-Praefix bleiben `isiLive_*`).

## 1) Version und Dokus aktualisieren

1. TOC-Version in `isiLive.toc` aktualisieren:
   - `## Version: x.y.z`
   - Wenn der optionale Git-Hook aktiv ist, werden die passenden dokumentierten Baselines und der Titelstring vor dem Commit automatisch aus der TOC-Version synchronisiert.
2. Einen neuen Eintrag oben in `CHANGELOG.md` anlegen.
   - Fuer `0.9.99` sowohl den Docs-Baseline-Bump als auch den Stand der Post-Baseline-Bereinigung notieren, damit `CHANGELOG.md` und die Dokus den Branch korrekt widerspiegeln.
3. `README.md` fuer user-visible Verhaltens- oder Layoutaenderungen aktualisieren.
4. Wenn Season-Daten angefasst wurden, muessen die Dokus die aktive `ACTIVE_SEASON_ID` und den Vorbereitungsstand der naechsten Season explizit nennen (`README.md` und `CHANGELOG.md`).
5. Wenn Runtime-Flow oder UI-Verhalten geaendert wurden, `ARCHITECTURE.md` und `USECASES.md` aktualisieren; wenn kurze Engineering-Regeln oder Wartungserwartungen betroffen sind, auch `RULES.md` und `WARTUNG.md` synchronisieren.
6. Wenn UI-Labels geaendert wurden, pruefen, dass `README.md` und `ARCHITECTURE.md` die aktuellen Buttontexte verwenden.
7. Wenn lokalisierte Texte geaendert wurden, sicherstellen, dass neue produktive Texte mindestens enUS/deDE haben, vorbereitete weitere Locales bewusst englische Fallbacks oder nachbearbeitete Uebersetzungen tragen und externe Uebersetzungshelfer im `CHANGELOG.md` bedankt werden.
8. Wenn Wartungs- oder Runbook-Erwartungen geaendert wurden, `WARTUNG.md` synchronisieren und die Packaging-Ignores in `.pkgmeta` abgestimmt halten.
   Das vollstaendige `CHANGELOG.md` bleibt aus dem CurseForge-Zip draussen; stattdessen wird der kurze Stub `CHANGELOG_RELEASE.md` verwendet.
9. `CHANGELOG_RELEASE.md` mit einer kurzen user-facing Zusammenfassung der aktuellen Version aktualisieren; der Stub ist die Release-Notiz im Paket und darf nicht nur bei der Versionsnummer stehen bleiben, wenn sichtbare Features geaendert wurden.
10. Sprachregel fuer Dokus einhalten:
   - `README.md` und die Changelog-Dateien bleiben Englisch.
   - Alle anderen gepflegten Projektdokumente bleiben Deutsch.

## 2) Lokales Quality Gate

Vor dem Commit ausfuehren:

```powershell
stylua --check .
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1
ISILIVE_MAX_FILE_LINES=3200 ISILIVE_MAX_FUNCTION_LINES=420 lua tools/lua_metrics_check.lua
lua tools/validate_rules_logic.lua
lua tools/validate_architecture_rules.lua
lua tools/validate_usecases.lua
```

Erwartung: Lint, Style, Metrics, Usecase- und Rule-Checks sind gruen.

Die Wrapper `tools/check.ps1` und `tools/check.cmd` fuehren den vollen lokalen Preflight ueber den repo-lokalen `luacheck.cmd`-Shim aus und vermeiden so den Windows-App-Auswahldialog, der beim direkten Aufruf des LuaRocks-`luacheck`-Scripts auftaucht.

`tools/validate_release_trigger.ps1` prueft die Release- und Pre-Release-Triggerlogik lokal. Fuer einen Dry-Run ohne GitHub-API-Check `CHECK_TAG_EXISTS=false` setzen und die passenden `EVENT_NAME`, `REF` bzw. `MANUAL_*`-Variablen uebergeben.
Die GitHub-Workflows checken das Repository vor der Trigger-Pruefung aus, damit `tools/validate_release_trigger.ps1` und die lokalen Release-Checks im Workflow-Kontext auf die echten Dateien zugreifen koennen.

`tools/validate_rules_logic.lua` validiert aktive Vertraege aus `RULES_LOGIC.md` gegen deterministische Testnamen.
`tools/validate_architecture_rules.lua` validiert aktive Architekturvertraege aus `ARCHITECTURE_RULES.md` gegen deterministische Testnamen.
`tools/validate_usecases.lua` ist Pflicht fuer das Release-Gate, fuehrt beide Regelvalidatoren zuerst aus und validiert danach die aktuell registrierten Szenarien ueber `tools/usecase_scenarios.lua` (Stand nach Invite-Hint-Dead-Code-Maintenance: 1938 Szenarien). Die Regelvalidatoren indizieren die entsprechenden deterministischen Tests.

Windows-Hinweis: Wenn Metrics mit fehlenden LuaRocks-Modulen (`lfs`, `luacheck.decoder`, `luacheck.parser`) scheitern, `LUA_PATH` und `LUA_CPATH` auf die LuaRocks-Pfade `share/lua/5.4` und `lib/lua/5.4` setzen, bevor der Metrics-Check laeuft. Lokal gelten dieselben Release-Schwellen wie in CI: `ISILIVE_MAX_FILE_LINES=3200` und `ISILIVE_MAX_FUNCTION_LINES=420`.

## 3) Commit und Push

```powershell
git add -A
git commit -m "Bump version to x.y.z"
git push origin main
```

## 4) Auf gruene Main-CI warten

Kein Release-Tag erstellen, solange der gepushte `main`-Commit in GitHub Actions noch pending oder rot ist.

Pflicht:

1. Den `Lua Check`-Run fuer genau den gepushten `main`-Commit oeffnen.
2. Warten, bis er gruen ist.
3. Erst dann mit Stable- oder Pre-Release-Tagging weitermachen.

Diese Reihenfolge ist nach dem archivierten versehentlichen `0.9.70`-Release-Paket verbindlich.

## 5) Release-Tag erstellen

Stable-Tag-Format fuer den `Release`-Workflow:

```powershell
git tag isiLive_release_X.Y.Z
git push origin isiLive_release_X.Y.Z
```

Pre-Release-Tag-Formate fuer den Workflow `Pre-Release (Alpha/Beta)`:

```powershell
git tag isiLive_alpha_X.Y.Z
git push origin isiLive_alpha_X.Y.Z
git tag isiLive_beta_X.Y.Z
git push origin isiLive_beta_X.Y.Z
```

Beispiel:

```powershell
git tag isiLive_release_0.9.117
git push origin isiLive_release_0.9.117
```

## 6) GitHub Actions pruefen

Im Actions-Tab pruefen:

1. `Lua Check` als Quality Gate muss erfolgreich sein.
2. Der `Release`-Workflow darf nur fuer `isiLive_release_*` triggern.
3. `Pre-Release (Alpha/Beta)` darf nur fuer `isiLive_alpha_*` und `isiLive_beta_*` triggern.
4. Der Stable-`Release`-Workflow muss neben CurseForge auch den GitHub-Release-Asset-Upload fuer WowUp erfolgreich abschliessen.

## 7) CurseForge-Paket pruefen

Der Stable-`Release`-Workflow baut zuerst das gemeinsame Release-ZIP `isiLive-X.Y.Z.zip`, haengt es an das GitHub Release fuer WowUp und laedt dasselbe ZIP danach mit `CF_API_KEY` direkt ueber `https://wow.curseforge.com/api/projects/{id}/upload-file` auf CurseForge hoch. Die CurseForge-Metadata setzt `gameVersionNames` aus der TOC-Interface-Version. Der fruehere Website-Auto-Packager-Trigger und der BigWigs-Packager werden fuer den Stable-Release nicht mehr verwendet, weil beide vor dem Upload an externen CurseForge-Web/API-Versionsabfragen scheitern koennen.

Nach erfolgreichem `Release` auf CurseForge pruefen:

1. Eine neue Datei fuer den Release-Tag ist vorhanden.
2. Die angezeigte Version entspricht der TOC-Version.
3. Changelog und Release Notes sehen korrekt aus.
4. Wenn der Release ein Fehler war, das CurseForge-Artefakt dort explizit archivieren oder entfernen; Git-Tag-Cleanup allein reicht nicht.

## 8) Einen versehentlichen Release zurueckrollen

Wenn ein Stable- oder Pre-Release-Tag zu frueh gepusht wurde:

1. Das erzeugte Paket auf CurseForge archivieren oder entfernen.
2. Den lokalen Git-Tag loeschen.
3. Den Remote-Git-Tag loeschen.
4. Das zugrunde liegende Problem auf `main` beheben.
5. Auf einen grünen `Lua Check` fuer den korrigierten `main`-Commit warten, bevor ein neuer Release-Tag erstellt wird.

Beispiel fuer das Loeschen eines Remote-Tags:

```powershell
git tag -d isiLive_release_X.Y.Z
git push origin :refs/tags/isiLive_release_X.Y.Z
```

## 9) Wago-Publish

- In diesem Repository ist kein automatischer Wago-Publish-Workflow konfiguriert.
- Auf Wago manuell veroeffentlichen oder aktualisieren, nachdem CurseForge/GitHub-Release bestaetigt ist.

## 10) WowUp-Hub-Publish

- WowUp wird ueber das GitHub Release bedient.
- Der Stable-`Release`-Workflow baut aus den getrackten Addon-Dateien ein ZIP und haengt es als `isiLive-X.Y.Z.zip` an das GitHub Release.
- Der Workflow prueft vor dem Upload, dass das ZIP am Root die Addon-Mappe `isiLive/` mit `isiLive/isiLive.toc` enthaelt. Diese Struktur ist fuer WowUp Hub erforderlich.
- Nach erfolgreichem Release in WowUp Hub pruefen, dass das neue GitHub-Release-Asset erkannt wird und die Version der TOC-Version entspricht.

## Hinweise

- Release-Tagging ist absichtlich vom normalen `main`-Push getrennt, damit CI noch sicher fehlschlagen kann, bevor CurseForge-Pakete gebaut werden.
- Ein TOC-/Doku-Bump auf `main` ist noch kein CurseForge-Release. CurseForge wird erst durch einen passenden Release- oder Pre-Release-Tag beziehungsweise einen explizit bestaetigten Workflow-Dispatch hochgeladen.
- CI schliesst `.luarocks/` bereits aus Lint- und Syntax-Checks aus.
- Packaging ignoriert Nicht-Nutzer-Dateien ueber `.pkgmeta`, einschliesslich `.github/`, `.claude/`, dem kompletten `docs/`-Ordner (mit `ARCHITECTURE.md`, `USECASES.md`, `WARTUNG.md`, `RULES.md`, `RULES_LOGIC.md`, `ARCHITECTURE_RULES.md`, `RELEASE.md`, `CHANGELOG.md`), dem Root-`README.md`, `AGENTS.md`, `CLAUDE.md`, den Dev-only-Ordnern `tools/` und `testmodul/` sowie PNG-Screenshots/Logos. Die CurseForge-Dateinotizen verwenden den kurzen Stub `CHANGELOG_RELEASE.md`, nicht das volle Repository-Changelog.
- Wenn VS-Code-Diagnostics veraltet wirken, ausfuehren:
  - `Developer: Reload Window`
  - `Lua: Restart Language Server`
