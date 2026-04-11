# Wartungsdatei

Diese Datei ist fuer den Fall gedacht, dass das Addon laenger nicht gepflegt wurde und du schnell wieder in einen sicheren Arbeitsmodus kommen musst.

## 1) Erstes Vorgehen nach laengerer Pause

Arbeite immer in dieser Reihenfolge:

1. `CHANGELOG.md` oben lesen:
   - letzte reale Version
   - letzte geplante Version
   - offene Produktentscheidungen
2. `TODO.md` lesen:
   - offene Nachzuegler
   - Doku-/Release-Sync
3. `RULES_LOGIC.md` lesen:
   - aktive Regeln sind harte Runtime-Vertraege
   - besonders wichtig: No Guess, KICK-Hard-off und Rate-Limit-Vertraege niemals nur implizit ableiten
4. `ARCHITECTURE_RULES.md` lesen:
   - aktive Architekturregeln sind ebenfalls Gate-relevant
5. `AGENTS.md` lesen:
   - Workflow-/Gate-Pflichten nicht vergessen
6. `README.md` lesen:
   - aktueller Produkt- und Verhaltensstand fuer Nutzer
7. `RELEASE.md` lesen:
   - offizieller Release-Ablauf und Freigabe-Gates
   - Release-Tag erst nach gruenem `Lua Check` auf `main`
8. `USECASES.md` lesen:
   - deterministische Laufzeit- und Validierungsbasis
9. `ARCHITECTURE.md` lesen:
   - aktueller Struktur- und Wiring-Stand

## 2) Pflicht-Gates vor jeder echten Aenderung

Mindestens das hier laufen lassen:

```powershell
lua tools/validate_usecases.lua
```

Fuer groessere Wartung oder Release-Vorbereitung immer komplett:

```powershell
stylua --check .
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check.ps1
ISILIVE_MAX_FILE_LINES=3200 ISILIVE_MAX_FUNCTION_LINES=420 lua tools/lua_metrics_check.lua
lua tools/validate_rules_logic.lua
lua tools/validate_architecture_rules.lua
lua tools/validate_usecases.lua
```

Wenn das nicht gruen ist, nicht "kurz weiterbauen".
Vor jedem Release-Tag gilt zusaetzlich: erst `main` pushen, dann den gruenen `Lua Check` fuer genau diesen Commit abwarten. Lokal entspricht der Einstieg dafuer `tools/check.ps1` bzw. `tools/check.cmd`.

## 3) Die Stellen, die nach WoW-Patches zuerst brechen koennen

### 3.1 WoW-Interface / Addon-Load

Pruefen:
- `isiLive.toc`
  - `## Interface`
  - `## Version`
- ob das Addon nach Login ohne Lua-Fehler laedt

Typische Ursache:
- neuer WoW-Patch, aber `Interface` noch alt

### 3.2 Dungeon-/Schwierigkeits-Kontext

Pruefen:
- `isiLive_status.lua`
- `isiLive_event_handlers_runtime.lua`

Kritisch:
- `GetInstanceInfo()`
- `difficultyID`-Mapping fuer Normal/Heroic/Mythic
- `C_Map.GetBestMapForUnit("player")`

Wichtig:
- `M+` wird ueber `CHALLENGE_MODE_COMPLETED/RESET` erkannt
- `M0` wird aktuell ueber `mythic non-challenge dungeon exit` erkannt
- fuer `M0` wird der Gruppen-Roster beim Eintritt eingefroren und spaeter beim Exit verwendet

Wenn Blizzard Difficulty-IDs aendert, muss das dort angepasst werden.

### 3.3 Blizzard Damage Meter API

Pruefen:
- `isiLive_stats.lua`
- `isiLive_event_handlers_challenge.lua`

Kritisch:
- `C_DamageMeter`
- `GetCombatSessionFromType`
- Session-Typen `overall/current`
- `combatSources`
- `amountPerSecond`
- `totalAmount`

Wenn Blizzard die Struktur aendert, bricht die DPS-Anzeige.

### 3.4 Season-/Dungeon-Daten

Pruefen:
- `isiLive_season_data.lua`

Kritisch:
- `SeasonData.ACTIVE_SEASON_ID`
- `mapToTeleport`
- `displayOrder`
- `shortCodesByLocale`
- `challengeMapAliases`
- `inactivePortalMessageByLocale`

Wenn eine neue Season startet:
- neue Season als vollstaendigen Datensatz eintragen
- erst dann `ACTIVE_SEASON_ID` umstellen
- keine halbfertige Season live schalten

## 4) Dinge, die bewusst so gebaut sind und nicht versehentlich rueckgaengig gemacht werden duerfen

### 4.1 Kein Raten

Das Projekt folgt strikt:
- keine guessed dungeon names
- keine guessed activity/map fallbacks
- keine guessed DPS-Zuordnung

Wenn etwas nicht eindeutig ist, bleibt es ungelost.

### 4.2 Speicher darf nicht explodieren

Aktueller Soll-Zustand:
- keine persistente Fremdspieler-Historie
- keine persistente `Runs together`-Historie
- fremde Last-Run-DPS nur session-only
- persistent bleibt nur der eigene letzte Run-DPS

Wenn du hier wieder Fremdspieler persistierst, baust du wieder unbounded Wachstum ein.

### 4.3 Roster-Layout ist absichtlich eng

Pruefen:
- `isiLive_roster.lua`
- `isiLive_roster_panel.lua`
- `RULES_LOGIC.md` Regeln 35 und 36

Aktueller Soll-Zustand:
- Name max 12 Zeichen
- Spec max 5 Zeichen
- Sprache nur Flagge
- Key-Code max 4 Zeichen
- kein numerischer `mapID`-Fallback im Key
- feste Kompaktbreiten fuer Spec/Name/iLvl/Key/Rio/DPS/Flagge

Nicht "nur mal eben breiter" machen, ohne Tests und Regeln mitzuziehen.

### 4.4 Hidden-Mode ist nicht mehr "UI komplett schlafen legen"

Pruefen:
- `isiLive_events.lua`
- `isiLive_bootstrap.lua`
- `isiLive_config_builders.lua`
- `isiLive_event_handlers_runtime.lua`
- `isiLive_event_handlers_challenge.lua`
- `isiLive_factory_controllers.lua`
- `isiLive_roster_panel.lua`
- `isiLive_leader_watch.lua`

Aktueller Soll-Zustand:
- Hidden stoppt Queue-Scanning und dauerhafte Polling-Last
- `CHAT_MSG_ADDON` und `GROUP_ROSTER_UPDATE` duerfen weiterlaufen
- eventgetriebenes Vor-Rendern der UI ist erlaubt
- der dedizierte Kick-Keep-Alive darf hidden fuer Gruppenmitglieder weiterlaufen
- der Utility/CD-Poller darf hidden nicht dauerhaft laufen; beim erneuten Anzeigen markiert die Show-Logik den Tracker dirty, und der erste sichtbare Render zieht genau einen frischen CD-Scan
- Leader-State wird hidden still synchronisiert
- hidden gibt es keine Notice-/Chat-Ausgabe fuer Leader-Transfers
- verzoegerter Post-Run-Refresh darf im Raid nicht laufen; er muss nach Raid-Ende sauber wieder aufgenommen werden
- lokale LuaLS-/VS-Code-Konfiguration wie `.luarc.json` bleibt developer-spezifisch, kann absolute Pfade enthalten und gehoert nicht ins Repo; falls die Datei existiert, muss sie in `.gitignore` stehen

Nicht versehentlich zurueckbauen auf:
- "alles hidden komplett aus"
- oder das Gegenteil: permanente Hidden-CPU-Last / Polling
- oder "Raid verhaelt sich nur wie Hidden" statt echtem Hard-Off

## 5) Wenn UI oder Runtime geaendert wurde, diese Dateien mitziehen

Pflicht nachziehen je nach Aenderung:
- `CHANGELOG.md`
- `USECASES.md`
- `README.md`
- `RELEASE.md`
- `TODO.md`
- `RULES_LOGIC.md` nur wenn echte Runtime-Regel geaendert/neu ist
- `ARCHITECTURE_RULES.md` nur wenn echte Strukturregel geaendert/neu ist

Wichtig:
- `RULES_LOGIC.md` ist append-only
- bei neuen aktiven Regeln immer Testnamen im selben Change ergaenzen
- ein geloeschter Git-Tag loescht kein bereits erzeugtes CurseForge-Paket; das muss dort separat archiviert/entfernt werden
- `.pkgmeta` haelt PNG-Screenshots, Logo-Dateien, die grosse `CHANGELOG.md` und die `.claude/`-Helper aus dem CurseForge-Paket raus; die Release-Notiz nutzt stattdessen `CHANGELOG_RELEASE.md` als kurzen Link-Hinweis auf das Repo

## 6) Wenn die Season gewechselt oder Dungeon-Daten angefasst wurden

Dann immer:

1. `isiLive_season_data.lua` komplett pruefen
2. `CHANGELOG.md` aktualisieren
3. `README.md` auf aktive/prepared Season abgleichen
4. `USECASES.md` pruefen, falls Verhalten sichtbar anders ist
5. `lua tools/validate_usecases.lua` laufen lassen

## 7) Ingame-Smoke nach groesseren Aenderungen

Mindestens das testen:

1. Addon laedt ohne Fehler
2. UI oeffnen/schliessen
3. Gruppeneintritt / Gruppenaustritt
4. Demo-Modus + Refresh
5. M+-Run Ende -> DPS sichtbar
6. M0 betreten, Gruppe teilweise aufloesen, Dungeon verlassen -> DPS bleibt ueber frozen roster matchbar
7. Key-Anzeige zeigt echte Shortcodes, keine `228`/`277`-Zahlen
8. Tooltip zeigt `Level`, `Lang`, `Last run DPS`

## 8) Wenn du nur 20 Minuten hast

Dann genau das:

1. `CHANGELOG.md` oben lesen
2. `TODO.md` lesen
3. `lua tools/validate_usecases.lua`
4. `isiLive_season_data.lua` auf aktive Season pruefen
5. `isiLive.toc` auf aktuelle WoW-Interface-Version pruefen

Wenn einer dieser Punkte rot ist, nicht blind releasen.
