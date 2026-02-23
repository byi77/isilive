# Regellogik

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

1. Queue-Zielaufloesung darf ohne konkrete `activityID -> mapID`-Aufloesung kein Ziel setzen.
2. Die UI darf per STRG-F9 nur ausserhalb des Kampfes geoeffnet werden und muss per STRG-F9 jederzeit schliessbar bleiben.
3. Negative Queue-Status-Folgeevents duerfen ein bereits gesetztes gruppiertes Ziel nicht loeschen.
4. RIO-Delta wird erst nach erfolgreichem verzoegertem Post-Run-Refresh aktiviert.
5. Teleport-Zielaufloesung per Dungeon-Name ohne `activityID` ist verboten.
6. Identische KEY-Sync-Zustaende duerfen keinen zusaetzlichen State- oder Refresh-Folgeeffekt ausloesen.
7. Queue-Capture ignoriert `pending`-Anwendungsstatus und dedupliziert identische Apply-Signaturen.
8. Highlight-Aufloesung arbeitet nur mit eindeutigem `activityID/mapID`-Kontext und ohne Gruppen-freies Fallback.
9. QueueFlow ignoriert Queue-Events waehrend aktiver Challenge und unterdrueckt doppelte Updates/Announces.
10. Secure-Button-Updates werden im Kampf nur verzoegert angewendet; nicht-Hotkey-Oeffnen bleibt als pending erlaubt.
11. Bei Raid-Groesse bleibt die UI ausgeblendet; beim Rueckwechsel wird Sichtbarkeit/Hinweiszustand korrekt zurueckgesetzt.
12. Locale-Tabellen bleiben schluesselsymmetrisch; Fallback fuer unbekannte Tags ist enUS.
13. Voll-Refresh laeuft nur in erlaubten Zustaenden und setzt bei Stop oder aktivem M+ aus.
14. Slash-Commands fuehren State-Zyklen stabil aus (`test/stop/start/pause/resume/lang`).
15. Roster-RIO-Delta bleibt nicht-negativ und im Prefix-Format, inklusive unit-basiertem Live-Update.
16. Addon-Sync-Nachrichten verarbeiten rosterrelevante Aenderungen, deduplizieren und refreshen nur bei Aenderung.
17. Die Statuszeile zeigt den Target Dungeon konsistent (inkl. Key-Level falls bekannt) und immer am Ende.
18. Advanced Combat Logging bleibt ueber Startup-Events hinweg erzwungen aktiv.
19. Beim `PLAYER_ENTERING_WORLD` darf kein doppelter forced Key-Snapshot versendet werden.
20. TestMode-State-Wechsel sind nur in gueltigen Zustaenden erlaubt.
21. Guards validieren Pflichtmodule/Pflichtfunktionen hart und brechen den Main-Start bei Fehlern sauber ab.
22. Non-Mythic-Dungeonstatus wird korrekt erkannt und bei Kontextwechsel robust signalisiert.

## Regelbloecke

### RULE-QUEUE-NO-GUESS
- Regelnummer: 1
- Status: aktiv
- Zusammenfassung: Queue-Zielaufloesung darf ohne konkrete `activityID -> mapID`-Aufloesung kein Ziel setzen.
- Erforderliche Tests:
  - Queue does not guess first candidate when no concrete map is available
  - Teleport does not resolve by dungeon name without activityID
  - Teleport does not resolve localized dungeon names without activityID

### RULE-UI-HOTKEY-KAMPF-TOGGLE
- Regelnummer: 2
- Status: aktiv
- Zusammenfassung: Die UI darf per STRG-F9 nur ausserhalb des Kampfes geoeffnet werden und muss per STRG-F9 jederzeit schliessbar bleiben.
- Erforderliche Tests:
  - UI toggle allows closing frame during combat
  - UI toggle blocks opening frame during combat and does not queue delayed open

### RULE-QUEUE-NEGATIV-GRUPPE-STABIL
- Regelnummer: 3
- Status: entwurf
- Zusammenfassung: Negative Queue-Status-Folgeevents duerfen ein bereits gesetztes gruppiertes Ziel nicht loeschen.
- Erforderliche Tests:
  - Event handlers keep target on negative updates when group fills to five

### RULE-RIO-DELTA-POSTRUN-AKTIVIERUNG
- Regelnummer: 4
- Status: entwurf
- Zusammenfassung: RIO-Delta wird erst nach erfolgreichem verzoegertem Post-Run-Refresh aktiviert.
- Erforderliche Tests:
  - Event handlers enable RIO delta only after delayed post-run refresh
  - Event handlers retry post-run refresh when first delayed attempt is blocked

### RULE-TELEPORT-KEIN-NAME-GUESSING
- Regelnummer: 5
- Status: entwurf
- Zusammenfassung: Teleport-Zielaufloesung per Dungeon-Name ohne `activityID` ist verboten.
- Erforderliche Tests:
  - Teleport does not resolve by dungeon name without activityID
  - Teleport does not resolve localized dungeon names without activityID

### RULE-SYNC-KEY-DEDUP
- Regelnummer: 6
- Status: entwurf
- Zusammenfassung: Identische KEY-Sync-Zustaende duerfen keinen zusaetzlichen State- oder Refresh-Folgeeffekt ausloesen.
- Erforderliche Tests:
  - Sync SetPlayerKeyInfo deduplicates identical key updates

### RULE-QUEUE-CAPTURE-PENDING-DEDUP
- Regelnummer: 7
- Status: entwurf
- Zusammenfassung: Queue-Capture ignoriert `pending`-Anwendungsstatus und dedupliziert identische Apply-Signaturen.
- Erforderliche Tests:
  - Queue capture ignores pending application updates
  - Queue capture deduplicates duplicate apply signatures
  - Queue capture resolves numeric values via search-result info

### RULE-HIGHLIGHT-STRIKTER-MAP-KONTEXT
- Regelnummer: 8
- Status: entwurf
- Zusammenfassung: Highlight-Aufloesung arbeitet nur mit eindeutigem `activityID/mapID`-Kontext und ohne Gruppen-freies Fallback.
- Erforderliche Tests:
  - Highlight joined-key resolver requires activity-based map context
  - Highlight listing resolver requires unique activity map
  - Highlight queue fallback is disabled while not in group

### RULE-QUEUEFLOW-CHALLENGE-UND-DEDUP
- Regelnummer: 9
- Status: entwurf
- Zusammenfassung: QueueFlow ignoriert Queue-Events waehrend aktiver Challenge und unterdrueckt doppelte Updates/Announces.
- Erforderliche Tests:
  - QueueFlow capture ignores queue events while in challenge mode
  - QueueFlow update suppresses exact duplicate updates
  - QueueFlow deduplicates repeated grouped announce for same target

### RULE-TELEPORT-SECURE-COMBAT-DEFER
- Regelnummer: 10
- Status: entwurf
- Zusammenfassung: Secure-Button-Updates werden im Kampf nur verzoegert angewendet; nicht-Hotkey-Oeffnen bleibt als pending erlaubt.
- Erforderliche Tests:
  - Teleport secure button updates are deferred during combat and applied after regen
  - UI direct SetVisible(true) in combat still queues pending open for non-hotkey flows

### RULE-GRUPPE-RAID-SICHTBARKEIT
- Regelnummer: 11
- Status: entwurf
- Zusammenfassung: Bei Raid-Groesse bleibt die UI ausgeblendet; beim Rueckwechsel wird Sichtbarkeit/Hinweiszustand korrekt zurueckgesetzt.
- Erforderliche Tests:
  - Group leave clears roster and hides frame
  - Raid group hides frame and prints notification
  - Raid notification prints again after leaving raid-size group

### RULE-LOCALE-SYMMETRIE-FALLBACK
- Regelnummer: 12
- Status: entwurf
- Zusammenfassung: Locale-Tabellen bleiben schluesselsymmetrisch; Fallback fuer unbekannte Tags ist enUS.
- Erforderliche Tests:
  - All enUS keys exist in deDE locale
  - All deDE keys exist in enUS locale
  - Locale tag resolver returns enUS as default fallback

### RULE-REFRESH-STATE-GATES
- Regelnummer: 13
- Status: entwurf
- Zusammenfassung: Voll-Refresh laeuft nur in erlaubten Zustaenden und setzt bei Stop oder aktivem M+ aus.
- Erforderliche Tests:
  - Refresh RunFullRefresh executes all refresh steps
  - Refresh RunFullRefresh skips when stopped
  - Refresh RunFullRefresh skips during active M+

### RULE-COMMANDS-STATE-ZYKLEN
- Regelnummer: 14
- Status: entwurf
- Zusammenfassung: Slash-Commands fuehren State-Zyklen stabil aus (`test/stop/start/pause/resume/lang`).
- Erforderliche Tests:
  - Commands routes test command to toggle
  - Commands stop/start cycle works correctly
  - Commands pause/resume cycle works correctly
  - Commands lang sets language for valid args

### RULE-ROSTER-RIO-DELTA-FORMAT
- Regelnummer: 15
- Status: entwurf
- Zusammenfassung: Roster-RIO-Delta bleibt nicht-negativ und im Prefix-Format, inklusive unit-basiertem Live-Update.
- Erforderliche Tests:
  - Roster display prepends positive RIO delta in parentheses
  - Roster display clamps negative RIO delta to +0
  - Roster display keeps plain RIO text when no baseline delta exists
  - Roster display forwards unit to delta callback and renders live-updated rio

### RULE-EVENT-SYNC-ROSTER-REFRESH
- Regelnummer: 16
- Status: entwurf
- Zusammenfassung: Addon-Sync-Nachrichten verarbeiten rosterrelevante Aenderungen, deduplizieren und refreshen nur bei Aenderung.
- Erforderliche Tests:
  - Event handlers process addon sync messages and refresh changed roster
  - Sync ProcessAddonMessage handles HELLO and KEY payloads
  - Sync SetPlayerKeyInfo deduplicates identical key updates

### RULE-STATUS-TARGET-DUNGEON-KONSISTENZ
- Regelnummer: 17
- Status: entwurf
- Zusammenfassung: Die Statuszeile zeigt den Target Dungeon konsistent (inkl. Key-Level falls bekannt) und immer am Ende.
- Erforderliche Tests:
  - Status line includes target dungeon and key level when available
  - Status line places target dungeon at the end
  - Status line keeps target placeholder when no target is available

### RULE-ACL-HARD-ENFORCED-STARTUP
- Regelnummer: 18
- Status: entwurf
- Zusammenfassung: Advanced Combat Logging bleibt ueber Startup-Events hinweg erzwungen aktiv.
- Erforderliche Tests:
  - Event handlers keep advanced combat logging hard-enabled across startup events

### RULE-KEY-SNAPSHOT-ENTERING-WORLD-NO-DUP
- Regelnummer: 19
- Status: entwurf
- Zusammenfassung: Beim `PLAYER_ENTERING_WORLD` darf kein doppelter forced Key-Snapshot versendet werden.
- Erforderliche Tests:
  - Event handlers avoid duplicate forced key snapshot sends on PLAYER_ENTERING_WORLD

### RULE-TESTMODE-STATE-GUARDS
- Regelnummer: 20
- Status: entwurf
- Zusammenfassung: TestMode-State-Wechsel sind nur in gueltigen Zustaenden erlaubt.
- Erforderliche Tests:
  - TestMode toggle enters and exits test mode
  - TestMode toggle blocked when stopped
  - TestMode toggle blocked when paused
  - TestMode full dummy preview sets testall state

### RULE-GUARDS-BOOTSTRAP-HARD-FAIL
- Regelnummer: 21
- Status: entwurf
- Zusammenfassung: Guards validieren Pflichtmodule/Pflichtfunktionen hart und brechen den Main-Start bei Fehlern sauber ab.
- Erforderliche Tests:
  - Guards validates all required modules are present
  - Guards fails when a required module is missing
  - Guards fails when a required function is missing from module stub
  - Main addon exits gracefully when Guards validation fails

### RULE-STATUS-NON-MYTHIC-KONTEXT
- Regelnummer: 22
- Status: entwurf
- Zusammenfassung: Non-Mythic-Dungeonstatus wird korrekt erkannt und bei Kontextwechsel robust signalisiert.
- Erforderliche Tests:
  - Status maps heroic fallback difficulty IDs as non-mythic heroic
  - Status warns when switching from normal to heroic without leaving dungeon context

## Hinweise

- Regel-IDs stabil halten (nicht umbenennen, wenn bereits in Doku/Kommunikation verwendet).
- Neue Regel immer in zwei Schritten erfassen: zuerst naechste Nummer in der `Regeluebersicht`, danach neuer Detailblock mit derselben `Regelnummer`.
- Keine Sortierung erzwingen: Reihenfolge entspricht dem Zeitpunkt, wann du die Regel eintraegst.
- Duplikate sind in `entwurf` erstmal ok; wir klaeren/mergen sie spaeter. Exakt gleiche Zusammenfassungen werden im Validator als Warnung ausgegeben.
- Lange Beschreibungen sind ok; fuer das Gate sind `Status` und `Erforderliche Tests` entscheidend.
- Regeln mit `Status: aktiv` brechen den Gate-Lauf, wenn verknuepfte Tests fehlen oder nicht existieren.
