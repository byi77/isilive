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

1. Queue-Zielaufloesung darf ohne konkreten map/activity-Kontext niemals raten.
2. Die UI darf per STRG-F9 nur ausserhalb des Kampfes geoeffnet werden und muss per STRG-F9 jederzeit schliessbar bleiben.
3. Negative Queue-Folgeevents duerfen ein bereits gruppiertes Ziel nicht unerwartet loeschen.
4. RIO-Delta darf erst nach erfolgreichem verzoegertem Post-Run-Refresh aktiviert werden.
5. Teleport-Ziel darf ohne Activity-Kontext nicht per Name geraten werden.
6. Identische KEY-Sync-Zustaende duerfen keine unnoetigen Folgeupdates erzeugen.
7. Queue-Capture darf pending/applied Rauschen nicht als neues Ziel behandeln und muss Doppler ignorieren.
8. Highlight-Aufloesung darf nur mit eindeutigem activity/map-Kontext arbeiten und kein Gruppen-freies Fallback nutzen.
9. QueueFlow muss waehrend aktiver Challenge Queue-Events ignorieren und doppelte Updates/Announces unterdruecken.
10. Secure-Button-Updates duerfen im Kampf nur verzoegert angewendet werden; nicht-Hotkey-Oeffnen darf pending bleiben.
11. In Raid-Groesse bleibt die UI ausgeblendet; beim Gruppenwechsel werden Hinweise und Sichtbarkeit korrekt rueckgesetzt.
12. Locale-Tabellen muessen schluesselsymmetrisch sein; Fallback fuer unbekannte Tags bleibt enUS.
13. Voll-Refresh laeuft nur in erlaubten Zustaenden und muss bei Stop oder aktivem M+ sauber aussetzen.
14. Slash-Commands muessen State-Zyklen stabil ausfuehren (test/stop/start/pause/resume/lang).
15. Roster-RIO-Delta bleibt nicht-negativ und im Prefix-Format, inklusive unit-basiertem Live-Update.
16. Addon-Sync-Nachrichten muessen rosterrelevante Aenderungen verarbeiten, deduplizieren und refreshen.
17. Die Buttons `Readycheck`, `Countdown10` und `Countdown 0` werden nur angezeigt, wenn man Gruppenleiter ist.
18. Der Button `Refresh` wird nur angezeigt, wenn kein aktiver M+-Run laeuft (`ChallengeMode` inaktiv).
19. Die Buttons `Share Keys` und `Refresh` sind gegen Klick-Spam geschuetzt (Debounce/Rate-Limit).
20. In den Gruppenmitglieder-Zeilen ist kein Zeilenumbruch erlaubt.
21. Es gibt kein Dungeon-Portal-Highlight, wenn das Ziel nicht eindeutig aufloesbar ist.
22. Es gibt keinen wiederholten Target-Dungeon-Chatspam; bei identischem erkanntem Ziel reicht eine einmalige Ausgabe.
23. coding: NO fallbacks of fallbacks
24. coding: kein raten, schätzen oder herbeizaubern von aussagen. fakten zählen! robust und qualitativ hochwertig bleiben!
25. der rio delta kann niemals negativ sein also zb. -15, der kann nur 0 oder höher sein.



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
- Zusammenfassung: Die UI darf per STRG-F9 nur ausserhalb des Kampfes geoeffnet werden und muss per STRG-F9 jederzeit schliessbar bleiben.
- Erforderliche Tests:
  - UI toggle allows closing frame during combat
  - UI toggle blocks opening frame during combat and does not queue delayed open

### RULE-QUEUE-NEGATIV-GRUPPE-STABIL
- Regelnummer: 3
- Status: entwurf
- Zusammenfassung: Negative Queue-Folgeevents duerfen ein bereits gruppiertes Ziel nicht unerwartet loeschen.
- Erforderliche Tests:
  - Event handlers keep target on negative updates when group fills to five

### RULE-RIO-DELTA-POSTRUN-AKTIVIERUNG
- Regelnummer: 4
- Status: entwurf
- Zusammenfassung: RIO-Delta darf erst nach erfolgreichem verzoegertem Post-Run-Refresh aktiviert werden.
- Erforderliche Tests:
  - Event handlers enable RIO delta only after delayed post-run refresh
  - Event handlers retry post-run refresh when first delayed attempt is blocked

### RULE-TELEPORT-KEIN-NAME-GUESSING
- Regelnummer: 5
- Status: entwurf
- Zusammenfassung: Teleport-Ziel darf ohne Activity-Kontext nicht per Name geraten werden.
- Erforderliche Tests:
  - Teleport does not resolve by dungeon name without activityID
  - Teleport does not resolve localized dungeon names without activityID

### RULE-SYNC-KEY-DEDUP
- Regelnummer: 6
- Status: entwurf
- Zusammenfassung: Identische KEY-Sync-Zustaende duerfen keine unnoetigen Folgeupdates erzeugen.
- Erforderliche Tests:
  - Sync SetPlayerKeyInfo deduplicates identical key updates

### RULE-QUEUE-CAPTURE-PENDING-DEDUP
- Regelnummer: 7
- Status: entwurf
- Zusammenfassung: Queue-Capture darf pending/applied Rauschen nicht als neues Ziel behandeln und muss Doppler ignorieren.
- Erforderliche Tests:
  - Queue capture ignores pending application updates
  - Queue capture deduplicates duplicate apply signatures
  - Queue capture resolves numeric values via search-result info

### RULE-HIGHLIGHT-STRIKTER-MAP-KONTEXT
- Regelnummer: 8
- Status: entwurf
- Zusammenfassung: Highlight-Aufloesung darf nur mit eindeutigem activity/map-Kontext arbeiten und kein Gruppen-freies Fallback nutzen.
- Erforderliche Tests:
  - Highlight joined-key resolver requires activity-based map context
  - Highlight listing resolver requires unique activity map
  - Highlight queue fallback is disabled while not in group

### RULE-QUEUEFLOW-CHALLENGE-UND-DEDUP
- Regelnummer: 9
- Status: entwurf
- Zusammenfassung: QueueFlow muss waehrend aktiver Challenge Queue-Events ignorieren und doppelte Updates/Announces unterdruecken.
- Erforderliche Tests:
  - QueueFlow capture ignores queue events while in challenge mode
  - QueueFlow update suppresses exact duplicate updates
  - QueueFlow deduplicates repeated grouped announce for same target

### RULE-TELEPORT-SECURE-COMBAT-DEFER
- Regelnummer: 10
- Status: entwurf
- Zusammenfassung: Secure-Button-Updates duerfen im Kampf nur verzoegert angewendet werden; nicht-Hotkey-Oeffnen darf pending bleiben.
- Erforderliche Tests:
  - Teleport secure button updates are deferred during combat and applied after regen
  - UI direct SetVisible(true) in combat still queues pending open for non-hotkey flows

### RULE-GRUPPE-RAID-SICHTBARKEIT
- Regelnummer: 11
- Status: entwurf
- Zusammenfassung: In Raid-Groesse bleibt die UI ausgeblendet; beim Gruppenwechsel werden Hinweise und Sichtbarkeit korrekt rueckgesetzt.
- Erforderliche Tests:
  - Group leave clears roster and hides frame
  - Raid group hides frame and prints notification
  - Raid notification prints again after leaving raid-size group

### RULE-LOCALE-SYMMETRIE-FALLBACK
- Regelnummer: 12
- Status: entwurf
- Zusammenfassung: Locale-Tabellen muessen schluesselsymmetrisch sein; Fallback fuer unbekannte Tags bleibt enUS.
- Erforderliche Tests:
  - All enUS keys exist in deDE locale
  - All deDE keys exist in enUS locale
  - Locale tag resolver returns enUS as default fallback

### RULE-REFRESH-STATE-GATES
- Regelnummer: 13
- Status: entwurf
- Zusammenfassung: Voll-Refresh laeuft nur in erlaubten Zustaenden und muss bei Stop oder aktivem M+ sauber aussetzen.
- Erforderliche Tests:
  - Refresh RunFullRefresh executes all refresh steps
  - Refresh RunFullRefresh skips when stopped
  - Refresh RunFullRefresh skips during active M+

### RULE-COMMANDS-STATE-ZYKLEN
- Regelnummer: 14
- Status: entwurf
- Zusammenfassung: Slash-Commands muessen State-Zyklen stabil ausfuehren (test/stop/start/pause/resume/lang).
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
- Zusammenfassung: Addon-Sync-Nachrichten muessen rosterrelevante Aenderungen verarbeiten, deduplizieren und refreshen.
- Erforderliche Tests:
  - Event handlers process addon sync messages and refresh changed roster
  - Sync ProcessAddonMessage handles HELLO and KEY payloads
  - Sync SetPlayerKeyInfo deduplicates identical key updates

### RULE-LEADER-BUTTONS-SICHTBARKEIT
- Regelnummer: 17
- Status: entwurf
- Zusammenfassung: Die Buttons `Readycheck`, `Countdown10` und `Countdown 0` werden nur angezeigt, wenn man Gruppenleiter ist.
- Erforderliche Tests:
  - LeaderWatch detects leader gain via PARTY_LEADER_CHANGED
  - LeaderWatch detects leader loss

### RULE-REFRESH-BUTTON-CHALLENGE-SICHTBARKEIT
- Regelnummer: 18
- Status: entwurf
- Zusammenfassung: Der Button `Refresh` wird nur angezeigt, wenn kein aktiver M+-Run laeuft (`ChallengeMode` inaktiv).
- Erforderliche Tests:
  - Refresh RunFullRefresh skips during active M+

### RULE-BUTTON-SPAM-GUARD
- Regelnummer: 19
- Status: entwurf
- Zusammenfassung: Die Buttons `Share Keys` und `Refresh` sind gegen Klick-Spam geschuetzt (Debounce/Rate-Limit).
- Erforderliche Tests:
  - Replace with exact deterministic test name

### RULE-ROSTER-ZEILENUMBRUCH-VERBOT
- Regelnummer: 20
- Status: entwurf
- Zusammenfassung: In den Gruppenmitglieder-Zeilen ist kein Zeilenumbruch erlaubt.
- Erforderliche Tests:
  - Replace with exact deterministic test name

### RULE-HIGHLIGHT-NUR-BEI-EINDEUTIGEM-ZIEL
- Regelnummer: 21
- Status: entwurf
- Zusammenfassung: Es gibt kein Dungeon-Portal-Highlight, wenn das Ziel nicht eindeutig aufloesbar ist.
- Erforderliche Tests:
  - Highlight listing resolver requires unique activity map
  - Highlight joined-key resolver requires activity-based map context
  - Queue does not guess first candidate when no concrete map is available

### RULE-TARGET-DUNGEON-CHAT-DEDUP
- Regelnummer: 22
- Status: entwurf
- Zusammenfassung: Es gibt keinen wiederholten Target-Dungeon-Chatspam; bei identischem erkanntem Ziel reicht eine einmalige Ausgabe.
- Erforderliche Tests:
  - QueueFlow deduplicates repeated grouped announce for same target

## Hinweise

- Regel-IDs stabil halten (nicht umbenennen, wenn bereits in Doku/Kommunikation verwendet).
- Neue Regel immer in zwei Schritten erfassen: zuerst naechste Nummer in der `Regeluebersicht`, danach neuer Detailblock mit derselben `Regelnummer`.
- Keine Sortierung erzwingen: Reihenfolge entspricht dem Zeitpunkt, wann du die Regel eintraegst.
- Duplikate sind in `entwurf` erstmal ok; wir klaeren/mergen sie spaeter. Exakt gleiche Zusammenfassungen werden im Validator als Warnung ausgegeben.
- Lange Beschreibungen sind ok; fuer das Gate sind `Status` und `Erforderliche Tests` entscheidend.
- Regeln mit `Status: aktiv` brechen den Gate-Lauf, wenn verknuepfte Tests fehlen oder nicht existieren.
