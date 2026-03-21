﻿﻿﻿﻿﻿﻿# Regellogik

Diese Datei ist die verbindliche Quelle fuer Usecase- und Runtime-Regeln, die im Gate geprueft werden.

## Schreibformat

1. Oben steht eine nummerierte `Regeluebersicht` mit je einem Kurzsatz pro Regel.
2. Darunter folgt pro Regel ein Detailblock mit Heading `### REGEL-ID` (oder `### RULE-ID`).
3. Erlaubte Statuswerte:
   - `aktiv`: harte Gate-Regel (muss Testzuordnung haben und validieren)
   - `entwurf`: in Arbeit, noch kein Gate-Blocker
   - `veraltet`: dokumentiert, nicht mehr aktiv erzwungen
   - `deaktiviert`: temporaer deaktiviert
4. Pflichtfelder pro Detailblock:
   - `- Regelnummer: ...`
   - `- Status: ...`
   - `- Zusammenfassung: ...`
   - `- Erforderliche Tests:`
5. Unter `Erforderliche Tests` muessen exakte deterministische Testnamen aus `tools/validate_usecases.lua` stehen.
6. Keine Sortierung noetig: neue Regeln immer unten anhaengen (erst in `Regeluebersicht`, dann als neuer Detailblock).

## Regeluebersicht

1. Queue-Zielaufloesung darf ohne konkreten map/activity-Kontext niemals raten.
2. Die UI muss per STRG-F9 in jedem Zustand toggelbar bleiben; blockierte Show/Hide-Wechsel werden im Kampf gependelt und bei `PLAYER_REGEN_ENABLED` angewendet.
3. Negative Queue-Folgeevents duerfen ein bereits gruppiertes Ziel nicht unerwartet loeschen.
4. RIO-Delta darf erst nach erfolgreichem verzoegertem Post-Run-Refresh aktiviert werden.
5. Teleport-Ziel darf ohne Activity-Kontext nicht per Name geraten werden.
6. Identische KEY-Sync-Zustaende duerfen keine unnoetigen Folgeupdates erzeugen.
7. Queue-Capture darf pending/applied Rauschen nicht als neues Ziel behandeln und muss Doppler ignorieren.
8. Highlight-Aufloesung darf nur mit eindeutigem activity/map-Kontext arbeiten und kein Gruppen-freies Fallback nutzen.
9. QueueFlow muss waehrend aktiver Challenge Queue-Events ignorieren und doppelte Updates/Announces unterdruecken.
10. Secure-Button-Updates duerfen im Kampf nur verzoegert angewendet werden; blockierte Main-UI-Sichtbarkeitswechsel werden gependelt und bei `PLAYER_REGEN_ENABLED` angewendet.
11. In Raid-Groesse bleibt die UI sichtbar, wechselt in den H-Modus; beim Verlassen einer Kleingruppe bleibt die bisherige Sichtbarkeit erhalten und ehemalige Gruppenmitglieder werden als Geister weiter angezeigt.
12. Locale-Tabellen muessen schluesselsymmetrisch sein; Fallback fuer unbekannte Tags bleibt enUS.
13. Voll-Refresh laeuft nur in erlaubten Zustaenden und muss bei Stop oder aktivem M+ sauber aussetzen.
14. Slash-Commands muessen State-Zyklen stabil ausfuehren (test/stop/start/pause/resume/lang).
15. Roster-RIO-Delta bleibt nicht-negativ und im Prefix-Format, inklusive unit-basiertem Live-Update.
16. Addon-Sync-Nachrichten muessen rosterrelevante Aenderungen verarbeiten, deduplizieren und refreshen.
17. Die Buttons `Readycheck`, `Countdown10` und `Countdown 0` sind fuer Nicht-Leader deaktiviert und optisch abgedimmt.
18. Voll-Refresh wird waehrend aktivem M+-Run nicht ausgefuehrt.
19. Die Aktionen `Share Keys` und `Refresh` sind gegen Klick-Spam geschuetzt (Debounce/Rate-Limit).
20. In den Gruppenmitglieder-Zeilen ist kein Zeilenumbruch erlaubt.
21. Es gibt kein Dungeon-Portal-Highlight, wenn das Ziel nicht eindeutig aufloesbar ist.
22. Es gibt keinen wiederholten Target-Dungeon-Chatspam; bei identischem erkanntem Ziel reicht eine einmalige Ausgabe.
23. coding: KEINE fallbacks von fallbacks
24. coding: kein raten, schätzen oder herbeizaubern von aussagen. fakten zählen! robust und qualitativ hochwertig bleiben!
25. der rio delta kann niemals negativ sein also zb. -15, der kann nur 0 oder höher sein.
26. die ui kann jederzeit mit STRG+F9 geöffnet und geschlossen werden, auch infight
27. das schliessen der ui ist jederzeit anforderbar, entweder per klick auf das rote x rechts oben (windows like) oder per STRG+F9; blockierte hide-wechsel werden bei `PLAYER_REGEN_ENABLED` nachgezogen
28. während die ui ausgeblendet ist, laufen roster/addon-sync im hintergrund weiter und dürfen eventgetrieben vor-rendern; queue-scanning und dauerhafte polling-last stoppen jedoch.
29. teleport-eintraege fuer shared spells bleiben deterministisch sortiert und doppelte grid-eintraege werden entfernt.
30. falls ein anderer user entdeckt wird welcher auch "isiLive" benutzt, hängen wir hinter seinen Namen ein <3 (blaues herz) an
31. main ui immer -> auto open beim gruppenbeitritt, autoclose bei key start und auto open bei key ende weiterhin behalten
32. verlaesst ein gruppenmitglied die gruppe, bleibt es als "geist" (ausgegraut) in der liste, bis der slot neu besetzt wird oder ein reload erfolgt
33. spieler, die sich bereits im zieldungeon befinden, werden mit einem portal-icon markiert
34. waehrend eines ready-checks wird der name jedes spielers entsprechend dem status (bereit=gruen/nicht bereit=rot/wartend=gelb) eingefaerbt
35. die kompakten roster-datenspalten behalten ihr festes breitenbudget fuer spec, name, ilvl, key, rio, dps und flagge.
36. roster-kurztexte bleiben kompakt und faktenbasiert: name max 12 zeichen, spec max 5 zeichen mit hunter-kurzlabels `MM`/`BM`, sprache nur flagge, key-code max 4 zeichen und kein numerischer mapID-Fallback.
37. die wartungsdatei `WARTUNG.md` darf nicht im curseforge-paket landen.
38. `WARTUNG.md` muss die verpflichtende wartungskette fuer den wiedereinstieg nennen: `CHANGELOG.md`, `TODO.md`, `TODO_RENAME.md`, `RULES_LOGIC.md`, `ARCHITECTURE_RULES.md`, `AGENTS.md`, `README.md`, `RELEASE.md`, `USECASES.md`, `ARCHITECTURE.md`.
39. Die Rollensymbole im Roster-Panel sind interaktive Buttons und ermoeglichen per Klick das manuelle Markieren von Tank (Blau) und Heiler (Gruen).
40. Bei Gruppengroessen > 5 (Raid) wird im Roster-Panel in den H-Modus gewechselt, die Gruppenmitglieder-Zeilen werden ausgeblendet und die Raid-Benachrichtigung nur einmal pro Raid-Uebergang ausgegeben.
41. API-Aufrufe mit Unit-Tokens muessen `UnitExists` pruefen, bevor sie aufgerufen werden, um Race-Conditions bei Gruppenaenderungen abzufangen.

## Regelbloecke

### RULE-QUEUE-NO-GUESS
- Regelnummer: 1
- Status: aktiv
- Zusammenfassung: Queue-Zielaufloesung darf ohne konkreten map/activity-Kontext niemals raten.
- Erforderliche Tests:
  - Queue does not guess first candidate when no concrete map is available
  - Teleport does not resolve by dungeon name without activityID
  - Teleport does not resolve localized dungeon names without activityID

### RULE-UI-HOTKEY-KAMPF-TOGGLE
- Regelnummer: 2
- Status: aktiv
- Zusammenfassung: Die UI muss per STRG-F9 in jedem Zustand toggelbar bleiben; wenn Kampf-Lockdown `Show` oder `Hide` blockiert, wird die angeforderte Sichtbarkeit bei `PLAYER_REGEN_ENABLED` deterministisch nachgezogen.
- Erforderliche Tests:
  - UI toggle defers closing frame during combat and applies after regen
  - UI toggle defers opening frame during combat and applies after regen

### RULE-QUEUE-NEGATIV-GRUPPE-STABIL
- Regelnummer: 3
- Status: aktiv
- Zusammenfassung: Negative Queue-Folgeevents duerfen ein bereits gruppiertes Ziel nicht unerwartet loeschen.
- Erforderliche Tests:
  - Event handlers keep target on negative updates when group fills to five

### RULE-RIO-DELTA-POSTRUN-AKTIVIERUNG
- Regelnummer: 4
- Status: aktiv
- Zusammenfassung: RIO-Delta darf erst nach erfolgreichem verzoegertem Post-Run-Refresh aktiviert werden.
- Erforderliche Tests:
  - Event handlers enable RIO delta only after delayed post-run refresh
  - Event handlers retry post-run refresh when first delayed attempt is blocked

### RULE-TELEPORT-KEIN-NAME-GUESSING
- Regelnummer: 5
- Status: aktiv
- Zusammenfassung: Teleport-Ziel darf ohne Activity-Kontext nicht per Name geraten werden.
- Erforderliche Tests:
  - Teleport does not resolve by dungeon name without activityID
  - Teleport does not resolve localized dungeon names without activityID

### RULE-SYNC-KEY-DEDUP
- Regelnummer: 6
- Status: aktiv
- Zusammenfassung: Identische KEY-Sync-Zustaende duerfen keine unnoetigen Folgeupdates erzeugen.
- Erforderliche Tests:
  - Sync SetPlayerKeyInfo deduplicates identical key updates

### RULE-QUEUE-CAPTURE-PENDING-DEDUP
- Regelnummer: 7
- Status: aktiv
- Zusammenfassung: Queue-Capture darf pending/applied Rauschen nicht als neues Ziel behandeln und muss Doppler ignorieren.
- Erforderliche Tests:
  - Queue capture ignores pending application updates
  - Queue capture deduplicates duplicate apply signatures
  - Queue capture resolves numeric values via search-result info

### RULE-HIGHLIGHT-STRIKTER-MAP-KONTEXT
- Regelnummer: 8
- Status: aktiv
- Zusammenfassung: Highlight-Aufloesung darf nur mit eindeutigem activity/map-Kontext arbeiten und kein Gruppen-freies Fallback nutzen.
- Erforderliche Tests:
  - Highlight joined-key resolver requires activity-based map context
  - Highlight listing resolver requires unique activity map
  - Highlight queue fallback is disabled while not in group

### RULE-QUEUEFLOW-CHALLENGE-UND-DEDUP
- Regelnummer: 9
- Status: aktiv
- Zusammenfassung: QueueFlow muss waehrend aktiver Challenge Queue-Events ignorieren und doppelte Updates/Announces unterdruecken.
- Erforderliche Tests:
  - QueueFlow capture ignores queue events while in challenge mode
  - QueueFlow update suppresses exact duplicate updates
  - QueueFlow deduplicates repeated grouped announce for same target

### RULE-TELEPORT-SECURE-COMBAT-DEFER
- Regelnummer: 10
- Status: aktiv
- Zusammenfassung: Secure-Button-Updates duerfen im Kampf nur verzoegert angewendet werden; direkte Main-UI-Sichtbarkeitswechsel werden bei Kampf-Lockdown gependelt und bei `PLAYER_REGEN_ENABLED` angewendet.
- Erforderliche Tests:
  - Teleport secure button updates are deferred during combat and applied after regen
  - UI game-menu secure button updates are deferred during combat and applied after regen
  - UI direct SetVisible defers during combat and applies after regen

### RULE-GRUPPE-RAID-SICHTBARKEIT
- Regelnummer: 11
- Status: aktiv
- Zusammenfassung: In Raid-Groesse bleibt die UI sichtbar und wechselt in den H-Modus; beim Verlassen einer Kleingruppe bleibt die bisherige Sichtbarkeit erhalten und ehemalige Gruppenmitglieder werden als Geister weiter angezeigt.
- Erforderliche Tests:
  - Group leave keeps frame state and ghosts former party members
  - Old ghosts are cleared when joining a new group
  - Raid group switches to H mode, keeps frame visible and prints notification
  - Raid notification prints again after leaving raid-size group

### RULE-LOCALE-SYMMETRIE-FALLBACK
- Regelnummer: 12
- Status: aktiv
- Zusammenfassung: Locale-Tabellen muessen schluesselsymmetrisch sein; Fallback fuer unbekannte Tags bleibt enUS.
- Erforderliche Tests:
  - All enUS keys exist in deDE locale
  - All deDE keys exist in enUS locale
  - Locale tag resolver returns enUS as default fallback

### RULE-REFRESH-STATE-GATES
- Regelnummer: 13
- Status: aktiv
- Zusammenfassung: Voll-Refresh laeuft nur in erlaubten Zustaenden und muss bei Stop oder aktivem M+ sauber aussetzen.
- Erforderliche Tests:
  - Refresh RunFullRefresh executes all refresh steps
  - Refresh RunFullRefresh skips when stopped
  - Refresh RunFullRefresh skips during active M+

### RULE-COMMANDS-STATE-ZYKLEN
- Regelnummer: 14
- Status: aktiv
- Zusammenfassung: Slash-Commands muessen State-Zyklen stabil ausfuehren (test/stop/start/pause/resume/lang).
- Erforderliche Tests:
  - Commands routes test command to toggle
  - Commands stop/start cycle works correctly
  - Commands pause/resume cycle works correctly
  - Commands lang sets language for valid args

### RULE-ROSTER-RIO-DELTA-FORMAT
- Regelnummer: 15
- Status: aktiv
- Zusammenfassung: Roster-RIO-Delta bleibt nicht-negativ und im Prefix-Format, inklusive unit-basiertem Live-Update.
- Erforderliche Tests:
  - Roster display prepends positive RIO delta in parentheses
  - Roster display clamps negative RIO delta to +0
  - Roster display keeps plain RIO text when no baseline delta exists
  - Roster display forwards unit to delta callback and renders live-updated rio

### RULE-EVENT-SYNC-ROSTER-REFRESH
- Regelnummer: 16
- Status: aktiv
- Zusammenfassung: Addon-Sync-Nachrichten muessen rosterrelevante Aenderungen verarbeiten, deduplizieren und refreshen.
- Erforderliche Tests:
  - Event handlers process addon sync messages and refresh changed roster
  - Sync ProcessAddonMessage handles HELLO, REQSYNC, and KEY payloads
  - Sync SetPlayerKeyInfo deduplicates identical key updates

### RULE-LEADER-BUTTONS-SICHTBARKEIT
- Regelnummer: 17
- Status: aktiv
- Zusammenfassung: Die Buttons `Readycheck`, `Countdown10` und `Countdown 0` sind fuer Nicht-Leader deaktiviert und optisch abgedimmt.
- Erforderliche Tests:
  - Roster panel leader-only buttons disable when player is not leader
  - LeaderWatch detects leader gain via PARTY_LEADER_CHANGED
  - LeaderWatch detects leader loss

### RULE-REFRESH-BUTTON-CHALLENGE-SICHTBARKEIT
- Regelnummer: 18
- Status: aktiv
- Zusammenfassung: Voll-Refresh wird waehrend aktivem M+-Run nicht ausgefuehrt.
- Erforderliche Tests:
  - Refresh RunFullRefresh skips during active M+

### RULE-BUTTON-SPAM-GUARD
- Regelnummer: 19
- Status: aktiv
- Zusammenfassung: Die Aktionen `Share Keys` und `Refresh` sind gegen Klick-Spam geschuetzt (Debounce/Rate-Limit).
- Erforderliche Tests:
  - Refresh RunFullRefresh debounces rapid clicks
  - Roster panel share keys button debounces rapid clicks

### RULE-ROSTER-ZEILENUMBRUCH-VERBOT
- Regelnummer: 20
- Status: aktiv
- Zusammenfassung: In den Gruppenmitglieder-Zeilen ist kein Zeilenumbruch erlaubt.
- Erforderliche Tests:
  - Roster panel rows disable wrapping for all member text columns

### RULE-HIGHLIGHT-NUR-BEI-EINDEUTIGEM-ZIEL
- Regelnummer: 21
- Status: aktiv
- Zusammenfassung: Es gibt kein Dungeon-Portal-Highlight, wenn das Ziel nicht eindeutig aufloesbar ist.
- Erforderliche Tests:
  - Highlight listing resolver requires unique activity map
  - Highlight joined-key resolver requires activity-based map context
  - Queue does not guess first candidate when no concrete map is available

### RULE-TARGET-DUNGEON-CHAT-DEDUP
- Regelnummer: 22
- Status: aktiv
- Zusammenfassung: Es gibt keinen wiederholten Target-Dungeon-Chatspam; bei identischem erkanntem Ziel reicht eine einmalige Ausgabe.
- Erforderliche Tests:
  - QueueFlow deduplicates repeated grouped announce for same target

### RULE-UI-STRG-F9-JEDERZEIT
- Regelnummer: 26
- Status: veraltet
- Zusammenfassung: Duplikat zu Regel 2; der STRG-F9-Kampf-Toggle wird dort verbindlich erzwungen.
- Erforderliche Tests:
  - UI toggle defers closing frame during combat and applies after regen
  - UI toggle defers opening frame during combat and applies after regen

### RULE-UI-SCHLIESSEN-X-ODER-HOTKEY
- Regelnummer: 27
- Status: aktiv
- Zusammenfassung: das schliessen der ui ist jederzeit anforderbar, entweder per klick auf das rote x rechts oben (windows like) oder per STRG+F9; falls Kampf-Lockdown das Ausblenden blockiert, wird es bei `PLAYER_REGEN_ENABLED` deterministisch nachgezogen.
- Erforderliche Tests:
  - UI close button hides frame directly
  - UI toggle defers closing frame during combat and applies after regen

### RULE-UI-HIDDEN-SPARFLAMME
- Regelnummer: 28
- Status: aktiv
- Zusammenfassung: waehrend die ui ausgeblendet ist, laeuft der daten-sync (roster/addon-msgs) im hintergrund weiter und darf eventgetrieben ui-zustand vor-rendern; queue-scanning und dauerhafte polling-last bleiben jedoch aus. Ein expliziter Refresh-Request darf Hidden-Clients genau eine forciert eventgetriebene KEY/STATS-Antwort entlocken; gestoppte, pausierte oder aktive M+-Runs antworten dabei nicht.
- Erforderliche Tests:
  - Bootstrap gate allows sync events while frame is hidden if configured
  - Hidden grouped roster updates keep pre-rendered UI fresh
  - Event handlers pre-render UI for hidden addon sync updates
  - Event handlers process addon sync messages and refresh changed roster
  - Event handlers answer refresh requests while frame is hidden
  - KeySync SendRefreshResponse can answer hidden refresh requests outside active M+
  - KeySync SendRefreshResponse skips while paused, stopped, or active M+
  - Bootstrap gate keeps hidden auto-open triggers for group join and key end
  - Event handlers run regen teleport refresh when frame is visible

### RULE-PORTAL-ICONS-STABILE-SLOTS
- Regelnummer: 29
- Status: aktiv
- Zusammenfassung: Teleport-Eintraege fuer Shared-Spells bleiben deterministisch sortiert und doppelte Grid-Eintraege werden entfernt.
- Erforderliche Tests:
  - Teleport resolves shared-map spell IDs as deterministic sorted map list
  - Teleport entry builder de-duplicates shared spells for grid rendering

### RULE-SYNC-USER-BLUESHEART-MARKER
- Regelnummer: 30
- Status: aktiv
- Zusammenfassung: Bekannte isiLive-Nutzer erhalten im Roster den `<3`-Marker.
- Erforderliche Tests:
  - Roster display appends blue-heart marker for synced users
  - Sync MarkUser and IsUserKnown track players
  - Event handlers process addon sync messages and refresh changed roster

### RULE-MAIN-UI-AUTO-OPEN-CLOSE-ZYKLEN
- Regelnummer: 31
- Status: aktiv
- Zusammenfassung: main ui immer -> auto open beim gruppenbeitritt, autoclose bei key start und auto open bei key ende weiterhin behalten
- Erforderliche Tests:
  - Group join builds roster with player and 4 party members
  - Group leave keeps frame state and ghosts former party members
  - Existing grouped roster updates do not re-open a manually hidden frame
  - Event handlers auto-hide main frame on challenge start
  - Event handlers auto-show main frame on challenge completion while grouped

### RULE-ROSTER-GHOST-MEMBER
- Regelnummer: 32
- Status: aktiv
- Zusammenfassung: verlaesst ein gruppenmitglied die gruppe, bleibt es als "geist" (ausgegraut) in der liste, bis der slot neu besetzt wird oder ein reload erfolgt.
- Erforderliche Tests:
  - Group member leaving becomes ghost
  - Ghost is removed and data restored when player rejoins

### RULE-ROSTER-AT-DUNGEON-MARKER
- Regelnummer: 33
- Status: aktiv
- Zusammenfassung: spieler, die sich bereits im zieldungeon befinden, werden mit einem portal-icon markiert.
- Erforderliche Tests:
  - Roster shows at-dungeon marker when unit map matches target

### RULE-ROSTER-READY-CHECK-INDICATOR
- Regelnummer: 34
- Status: aktiv
- Zusammenfassung: waehrend eines ready-checks wird der name jedes spielers entsprechend dem status (bereit=gruen/nicht bereit=rot/wartend=gelb) eingefaerbt und danach auf die klassenfarbe zurueckgesetzt.
- Erforderliche Tests:
  - Roster name color follows ready check status colors
  - Roster name color resets to class color after ready check

### RULE-CODING-KEINE-FALLBACK-KETTEN
- Regelnummer: 23
- Status: entwurf
- Zusammenfassung: Resolver sollen keinen weiteren ratebasierten API-Fallback ausfuehren, wenn der primäre injizierte Resolver bereits keine eindeutige Aussage liefert.
- Erforderliche Tests:
  - Highlight map resolver does not bypass injected resolver with direct API fallback

### RULE-CODING-KEIN-RATEN
- Regelnummer: 24
- Status: veraltet
- Zusammenfassung: Duplikat zu Regel 1 und Regel 5; unklare Faktenlage bleibt unresolved statt geraten zu werden.
- Erforderliche Tests:
  - Queue does not guess first candidate when no concrete map is available

### RULE-RIO-DELTA-NIE-NEGATIV
- Regelnummer: 25
- Status: veraltet
- Zusammenfassung: Duplikat zu Regel 15; RIO-Delta bleibt immer bei `+0` oder hoeher.
- Erforderliche Tests:
  - Roster display clamps negative RIO delta to +0

### RULE-ROSTER-KOMPAKT-SPALTENBREITEN
- Regelnummer: 35
- Status: aktiv
- Zusammenfassung: Die Roster-Datenspalten behalten ein festes Kompaktlayout mit den Breiten Spec=52, Name=134, iLvl=34, Key=56, Rio=70, DPS=58 und Flagge=14.
- Erforderliche Tests:
  - Roster panel uses compact width budget for primary data columns

### RULE-ROSTER-KOMPAKT-KURZTEXTE
- Regelnummer: 36
- Status: aktiv
- Zusammenfassung: Die Roster-Anzeige bleibt kompakt und faktenbasiert: Name max 12 Zeichen, Spec max 5 Zeichen mit Hunter-Kurzlabels `MM`/`BM`, Sprache nur Flagge, Key-Code max 4 Zeichen und kein numerischer mapID-Fallback.
- Erforderliche Tests:
  - Units GetShortSpecLabel prefers readable five-character labels
  - Roster display truncates names to Blizzard 12-character limit
  - Roster display truncates spec labels to five characters
  - Roster display shows flag only without language letters
  - Roster display clamps key short code to four letters
  - Roster display falls back to '?' for numeric-only key short codes

### RULE-WARTUNGSDATEI-NICHT-IM-PAKET
- Regelnummer: 37
- Status: aktiv
- Zusammenfassung: Die Wartungsdatei `WARTUNG.md` darf nicht im CurseForge-Paket landen.
- Erforderliche Tests:
  - Architecture pkgmeta excludes WARTUNG maintenance doc from release package

### RULE-WARTUNGSKETTE-WIEDEREINSTIEG
- Regelnummer: 38
- Status: aktiv
- Zusammenfassung: `WARTUNG.md` muss die verpflichtende Wartungskette fuer den Wiedereinstieg nennen: `CHANGELOG.md`, `TODO.md`, `TODO_RENAME.md`, `RULES_LOGIC.md`, `ARCHITECTURE_RULES.md`, `AGENTS.md`, `README.md`, `RELEASE.md`, `USECASES.md`, `ARCHITECTURE.md`.
- Erforderliche Tests:
  - Architecture WARTUNG runbook references the required maintenance document chain

## Hinweise

- Regel-IDs stabil halten (nicht umbenennen, wenn bereits in Doku/Kommunikation verwendet).
- Neue Regel immer in zwei Schritten erfassen: zuerst naechste Nummer in der `Regeluebersicht`, danach neuer Detailblock mit derselben `Regelnummer`.
- Keine Sortierung erzwingen: Reihenfolge entspricht dem Zeitpunkt, wann du die Regel eintraegst.
- Duplikate sind in `entwurf` erstmal ok; wir klaeren/mergen sie spaeter. Exakt gleiche Zusammenfassungen werden im Validator als Warnung ausgegeben.
- Lange Beschreibungen sind ok; fuer das Gate sind `Status` und `Erforderliche Tests` entscheidend.
- Regeln mit `Status: aktiv` brechen den Gate-Lauf, wenn verknuepfte Tests fehlen oder nicht existieren.
### RULE-ROSTER-AUTO-MARKER
- Regelnummer: 39
- Status: aktiv
- Zusammenfassung: Die Rollensymbole im Roster-Panel sind interaktive Buttons und ermoeglichen per Klick das manuelle Markieren von Tank (Blau) und Heiler (Gruen).
- Erforderliche Tests:
  - Roster role icon is a secure action button
  - Roster role icon click applies Blue Square to Tank unit
  - Roster role icon click applies Green Triangle to Healer unit

### RULE-ROSTER-RAID-NOTICE
- Regelnummer: 40
- Status: aktiv
- Zusammenfassung: Bei Gruppengroessen > 5 (Raid) wird im Roster-Panel in den H-Modus gewechselt, die Gruppenmitglieder-Zeilen werden ausgeblendet und die Raid-Benachrichtigung nur einmal pro Raid-Uebergang ausgegeben.
- Erforderliche Tests:
  - Raid group switches to H mode, keeps frame visible and prints notification

### RULE-UNIT-EXISTS-GUARD
- Regelnummer: 41
- Status: aktiv
- Zusammenfassung: API-Aufrufe mit Unit-Tokens muessen `UnitExists` pruefen, bevor sie aufgerufen werden, um Race-Conditions bei Gruppenaenderungen abzufangen.
- Erforderliche Tests:
  - Units GetUnitRole returns NONE for non-existing unit
  - Units GetUnitNameAndRealm returns nil for non-existing unit
