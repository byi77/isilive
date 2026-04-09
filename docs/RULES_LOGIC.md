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
2. Die UI muss per STRG-F9 in allen Nicht-Raid-Zustaenden toggelbar bleiben; im Raid bleibt die Main-UI aus. Blockierte Show/Hide-Wechsel werden im Kampf gependelt und bei `PLAYER_REGEN_ENABLED` angewendet.
3. Negative Queue-Folgeevents duerfen ein bereits gruppiertes Ziel nicht unerwartet loeschen.
4. RIO-Delta darf erst nach erfolgreichem verzoegertem Post-Run-Refresh aktiviert werden.
5. Teleport-Ziel darf ohne Activity-Kontext nicht per Name geraten werden.
6. Identische KEY-Sync-Zustaende duerfen keine unnoetigen Folgeupdates erzeugen.
7. Queue-Capture darf pending/applied Rauschen nicht als neues Ziel behandeln und muss Doppler ignorieren.
8. Highlight-Aufloesung darf nur mit eindeutigem activity/map-Kontext arbeiten und kein Gruppen-freies Fallback nutzen.
9. Der aktive Queue-Join-Runtimepfad muss waehrend aktiver Challenge Queue-Events ignorieren und ausserhalb davon Pending-Queue-Infos fuer den Gruppenbeitritts-Announce deterministisch setzen und wieder leeren.
10. Secure-Button-Updates duerfen im Kampf nur verzoegert angewendet werden; blockierte Main-UI-Sichtbarkeitswechsel werden ausser im Raid gependelt und bei `PLAYER_REGEN_ENABLED` angewendet.
11. In Raid-Groesse wird die Main-UI sofort ausgeblendet, die Raid-Option wird auf `hide` normalisiert und es laeuft weder UI- noch Hintergrund-Sync weiter; beim Verlassen einer Kleingruppe bleibt die bisherige Sichtbarkeit standardmaessig erhalten und ehemalige Gruppenmitglieder werden als Geister weiter angezeigt.
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
26. die ui kann in allen Nicht-Raid-Zustaenden mit STRG+F9 geöffnet und geschlossen werden; im raid bleibt sie aus
27. das schliessen der ui ist jederzeit anforderbar, entweder per klick auf das rote x rechts oben (windows like) oder per STRG+F9; ausser im Raidmodus bleiben blockierte hide-wechsel bis `PLAYER_REGEN_ENABLED` gependelt und werden dann nachgezogen
28. während die ui ausgeblendet ist, laufen roster/addon-sync im hintergrund weiter und dürfen eventgetrieben vor-rendern; queue-scanning und sonstige dauerhafte polling-last stoppen jedoch, der kick-sync bleibt fuer isiLive-gruppenmitglieder aktiv. Im Raid sind UI und Hintergrund-Sync komplett aus.
29. teleport-eintraege fuer shared spells bleiben deterministisch sortiert und doppelte grid-eintraege werden entfernt.
30. falls ein anderer user entdeckt wird welcher auch "isiLive" benutzt, hängen wir hinter seinen Namen ein <3 (blaues herz) an
31. main ui auto-open bleibt bei gruppenbeitritt erhalten, ausser im Raidmodus; key-ende auto-open ist standardmaessig an, aber abschaltbar; automatisches schliessen bei key start ist standardmaessig aus.
32. verlaesst ein gruppenmitglied die gruppe, bleibt es als "geist" (ausgegraut) in der liste, bis der slot neu besetzt wird oder ein reload erfolgt
33. spieler, die sich bereits im zieldungeon befinden, werden mit einem portal-icon markiert
34. waehrend eines ready-checks wird der name jedes spielers entsprechend dem status (bereit=gruen/nicht bereit=rot/wartend=gelb) eingefaerbt, danach auf die klassenfarbe zurueckgesetzt und ueber einen dedizierten Ready-Check-Refreshpfad aktualisiert, der keine Secure-Rollenbutton-Attribute neu schreibt.
35. die kompakten roster-datenspalten behalten ihr festes breitenbudget fuer spec, name, ilvl, key, rio, dps und flagge.
36. roster-kurztexte bleiben kompakt und faktenbasiert: name max 12 zeichen, spec max 5 zeichen mit hunter-kurzlabels `MM`/`BM`, sprache nur flagge, key-code max 4 zeichen und kein numerischer mapID-Fallback.
37. die wartungsdatei `WARTUNG.md` darf nicht im curseforge-paket landen.
38. `WARTUNG.md` muss die verpflichtende wartungskette fuer den wiedereinstieg nennen: `CHANGELOG.md`, `TODO.md`, `RULES_LOGIC.md`, `ARCHITECTURE_RULES.md`, `AGENTS.md`, `README.md`, `RELEASE.md`, `USECASES.md`, `ARCHITECTURE.md`.
39. Die Rollensymbole im Roster-Panel sind interaktive Buttons und ermoeglichen per Klick das manuelle Markieren von Tank (Blau) und Heiler (Gruen).
40. Bei Gruppengroessen > 5 (Raid) wird die Main-UI sofort ausgeblendet, es wird keine Raid-Benachrichtigung ausgegeben und kein H-Modus erzwungen; Hintergrundverarbeitung fuer Raid ist aus.
41. API-Aufrufe mit Unit-Tokens muessen `UnitExists` pruefen, bevor sie aufgerufen werden, um Race-Conditions bei Gruppenaenderungen abzufangen.
42. Die Behavior-Option `Auto-Close bei Key-Start / Solo` ist standardmaessig aus; nur wenn sie aktiv ist, darf die Main-UI bei Key-Start und beim Solo-Uebergang automatisch schliessen.
43. Der aktuelle Gruppenleiter wird im Roster mit einer 16x16-Krone markiert; bei bekannten isiLive-Nutzern bleibt das blaue Herz zusaetzlich sichtbar und steht vor der Krone.
44. Alle Center-Meldungen starten mit derselben Portal-Navigator-Basistypografie fuer Body-Text, Schriftgroesse und Standardfarbe.
45. Beim Login oder UI-Reload wird die Main-UI standardmaessig eingeblendet, ausser im Raidmodus; die Startup-Option kann diesen Auto-Show-Pfad weiterhin abschalten.
46. Manuelle Layout-Umschaltungen der Main-UI duerfen auch im Kampf angefordert werden, ausser im Raidmodus; direkte Mutationen an Secure-Kindern bleiben dabei ausgesetzt und werden spaetestens bei `PLAYER_REGEN_ENABLED` ueber den sichtbaren UI-Refresh nachgezogen.
47. Die ESC-Panel-Overlays muessen im Kampf als bereits gemountete `GameMenuFrame`-Kinder sichtbar bleiben; waehrend Kampf-Lockdown sind an ihnen keine Show/Hide- oder Layout-Mutationen erlaubt, unsichere Shortcuts bleiben sichtbar, duerfen ihre Aktion aber erst ausserhalb des Kampfes ausfuehren.
48. Der isiLive-Last-Run-Sync transportiert nur den belastbar verifizierten `DPS`-Wert eines Snapshots; das Roster nutzt `syncDps` nur als Fallback, wenn lokal kein Last-Run-DPS vorliegt.
49. Der Kick-Tracker bildet den aktuell verfuegbaren Interrupt der aktuellen Spezialisierung ab; Holy Paladin nutzt `Rebuke`, Devourer Demon Hunter nutzt `Disrupt`, und verfuegbare pet-basierte Warlock-Interrupts zaehlen als eigener Kick.
50. Die Kicks-Spalte zeigt fuer den lokalen Spieler und fuer isiLive-Gruppenmitglieder den aktuellen Kick-Status an; `ready` ist gruen, laufende Cooldowns zeigen rote Restsekunden, `-` steht fuer keinen verfuegbaren Kick oder fehlenden isiLive-Sync, und aktive Kick-Statusaenderungen werden spaetestens einmal pro Sekunde synchronisiert.
51. Bei ausgeblendeter UI bleibt der komplette isiLive-Gruppensync aktiv; nur nicht-sync-bezogenes Polling wie Queue-Scanning bleibt deaktiviert. Im Raid ist diese Hintergrundverarbeitung komplett aus.
52. Hidden-Clients senden weiterhin alle gruppenrelevanten isiLive-Sync-Buckets einschliesslich `KEY`, `STATS`, `DPS`, `LOC`, `TARGET` und `KICK`; sichtbarkeitsabhängige Unterdrückung ist nur ohne explizite Hidden-Freigabe erlaubt. Im Raid ist das deaktiviert.
53. Der Share-Keys-Button ist 30 Sekunden gegen Spam gesperrt; die Sperre gilt lokal nach eigenem Klick und wird auf allen anderen isiLive-Clients ausgeloest, sobald ein eingehender SHAREKEYS-Sync empfangen wird. Ein bereits laufender lokaler Cooldown wird dabei nicht zurueckgesetzt.
54. Wenn fuer eine Runtime-Aufloesung keine eindeutige, belastbare Quelle vorliegt, muss das Ergebnis unresolved bleiben; fehlende oder mehrdeutige Laufzeitdaten duerfen nicht durch spekulative Fallbacks, Namens-/Token-Raten, heuristische Standardwerte oder synthetische Zustaende ersetzt werden.

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
- Zusammenfassung: Die UI muss per STRG-F9 in allen Nicht-Raid-Zustaenden toggelbar bleiben; im Raid bleibt die Main-UI aus. Wenn Kampf-Lockdown `Show` oder `Hide` blockiert, wird die angeforderte Sichtbarkeit bei `PLAYER_REGEN_ENABLED` deterministisch nachgezogen.
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
  - Event handlers defer post-run refresh while raid mode is active and resume after raid exit

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
- Zusammenfassung: Der aktive Queue-Join-Runtimepfad muss waehrend aktiver Challenge Queue-Events ignorieren und ausserhalb davon Pending-Queue-Infos fuer den Gruppenbeitritts-Announce deterministisch setzen und wieder leeren.
- Erforderliche Tests:
  - Factory runtime queue capture ignores queue events while challenge mode is active
  - Factory runtime queue capture stores pending info when not in group
  - Factory runtime queue capture announces immediately when already grouped
  - Factory runtime queue capture resets stale pending info when a new search starts outside a group
  - Factory runtime queue announce prints queue joined message for members and clears pending
  - Factory runtime queue announce clears pending for leaders without printing
  - Architecture queue join callbacks stay wired through runtime setup and controller wiring

### RULE-TELEPORT-SECURE-COMBAT-DEFER
- Regelnummer: 10
- Status: aktiv
- Zusammenfassung: Secure-Button-Updates und Layout-Mutationen an Secure-Buttons duerfen im Kampf nicht direkt ausgefuehrt werden; direkte Main-UI-Sichtbarkeitswechsel werden bei Kampf-Lockdown gependelt und bei `PLAYER_REGEN_ENABLED` angewendet.
- Erforderliche Tests:
  - Teleport secure button updates are deferred during combat and applied after regen
  - UI game-menu secure button updates are deferred during combat and applied after regen
  - UI direct SetVisible defers during combat and applies after regen
  - TAINT: M2 roster rerender skips secure tank-helper layout mutations during combat

### RULE-GRUPPE-RAID-SICHTBARKEIT
- Regelnummer: 11
- Status: aktiv
- Zusammenfassung: In Raid-Groesse wird die Main-UI sofort ausgeblendet, die Raid-Option wird auf `hide` normalisiert und es laeuft weder UI- noch Hintergrund-Sync weiter; beim Verlassen einer Kleingruppe bleibt die bisherige Sichtbarkeit standardmaessig erhalten und ehemalige Gruppenmitglieder werden als Geister weiter angezeigt. Nur mit aktivierter Auto-Close-Option darf der Solo-Uebergang die Main-UI ausblenden.
- Erforderliche Tests:
  - Group leave keeps frame state and ghosts former party members
  - Group leave auto-close hides frame when option is enabled
  - Old ghosts are cleared when joining a new group
  - Raid group hides the UI and suppresses background processing
  - Factory raid kick tracker suppresses sync until raid ends and then recovers
  - Frame bridge blocks show requests while raid mode is active
  - Event handlers suppress background processing while raid mode is active
  - Settings panel defaults Raid behavior to Raid Off and persists user choice
  - Factory raid behavior resolver defaults to raid off and normalizes legacy values

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
  - Event handlers refresh target-dependent UI when addon sync updates exact target only
  - Sync ProcessAddonMessage handles HELLO, REQSYNC, and KEY payloads
  - Sync ProcessAddonMessage parses KICK payloads with no-interrupt state
  - Sync ProcessAddonMessage parses TARGET payload and stores it
  - Sync SetPlayerKeyInfo deduplicates identical key updates
  - KeySync ApplyKnownKeyToRosterEntry preserves synced no-interrupt state
  - KeySync pending forced refresh backfills missing sync fallback fields while inspect is pending

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
  - Highlight queue fallback is disabled while not in group

### RULE-TARGET-DUNGEON-CHAT-DEDUP
- Regelnummer: 22
- Status: aktiv
- Zusammenfassung: Es gibt keinen wiederholten Target-Dungeon-Chatspam; bei identischem erkanntem Ziel reicht eine einmalige Ausgabe.
- Erforderliche Tests:
  - Status target dungeon chat announces grouped key once and resets after target clears

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
- Zusammenfassung: das schliessen der ui ist jederzeit anforderbar, entweder per klick auf das rote x rechts oben (windows like) oder per STRG+F9; ausser im Raidmodus bleibt die UI aus und falls Kampf-Lockdown das Ausblenden blockiert, wird es bei `PLAYER_REGEN_ENABLED` deterministisch nachgezogen.
- Erforderliche Tests:
  - UI close button hides frame directly
  - UI toggle defers closing frame during combat and applies after regen

### RULE-UI-HIDDEN-SPARFLAMME
- Regelnummer: 28
- Status: aktiv
- Zusammenfassung: waehrend die ui ausgeblendet ist, laeuft der daten-sync (roster/addon-msgs) im hintergrund weiter und darf eventgetrieben ui-zustand vor-rendern; queue-scanning und sonstige dauerhafte polling-last bleiben aus. Der Kick-Sync fuer isiLive-Gruppenmitglieder bleibt davon ausgenommen und darf weiterlaufen, damit ausgeblendete Clients keine Kick-Nachteile erzeugen. Ein expliziter Refresh-Request darf Hidden-Clients genau eine forciert eventgetriebene Antwort entlocken (alle Sync-Buckets: KEY, STATS, DPS, LOC, TARGET, KICK); gestoppte oder pausierte Runs antworten dabei nicht. Im Raid sind UI und Hintergrund-Sync komplett aus.
- Erforderliche Tests:
  - Bootstrap gate allows sync events while frame is hidden if configured
  - Hidden grouped roster updates keep pre-rendered UI fresh
  - Event handlers pre-render UI for hidden addon sync updates
  - Event handlers process addon sync messages and refresh changed roster
  - Event handlers answer refresh requests while frame is hidden
  - Architecture kick tracker uses lightweight kick-column refresh hooks
  - Sync SendKick encodes no-interrupt state and deduplicates payloads
  - Event handlers send sparse background snapshot on hidden zone changes
  - Event handlers send sparse background snapshot only for player-owned state changes
  - Refresh HandleOwnedKeyRefresh sends force snapshot when key changed
  - Refresh HandleOwnedKeyRefresh sends background snapshot when key unchanged
  - Refresh HandleOwnedKeyRefresh sends force snapshot when post-challenge flag is set
  - KeySync SendOwnBackgroundSnapshot publishes sparse hidden changes without DPS spam
  - Config builders gate allows sparse local change events while frame is hidden
  - KeySync SendRefreshResponse can answer hidden refresh requests
  - KeySync SendRefreshResponse skips while paused or stopped
  - Bootstrap gate keeps hidden auto-open triggers for group join and key end
  - Event handlers run regen teleport refresh when frame is visible
  - Factory hidden CD ticker skips polling while frame is hidden
  - Factory hidden explicit CD refresh keeps pre-rendered state current
  - Factory hidden kick ticker keeps syncing while frame is hidden
  - Roster panel first visible render rescans cd tracker after hidden mode
  - Roster panel visible render does not rescan cd tracker after an explicit cd refresh

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
- Zusammenfassung: Die Main-UI oeffnet weiterhin automatisch bei Gruppenbeitritt. Bei Key-Ende bleibt Auto-Open standardmaessig aktiv, muss aber ueber die Behavior-Option abschaltbar sein. Bei Key-Start darf sie standardmaessig nicht automatisch schliessen; das alte Auto-Close-Verhalten ist nur ueber die Behavior-Option aktivierbar.
- Erforderliche Tests:
  - Group join builds roster with player and 4 party members
  - Existing grouped roster updates do not re-open a manually hidden frame
  - Event handlers do not auto-hide main frame on challenge start by default
  - Event handlers auto-hide main frame on challenge start when auto-close is enabled
  - Event handlers auto-show main frame on challenge completion while grouped
  - Event handlers skip auto-show on challenge completion when key-end setting is disabled
  - Settings panel defaults Login / Reload auto-show and Key-End auto-open to enabled

### RULE-ROSTER-GHOST-MEMBER
- Regelnummer: 32
- Status: aktiv
- Zusammenfassung: verlaesst ein gruppenmitglied die gruppe, bleibt es als "geist" (ausgegraut) in der liste, bis der slot neu besetzt wird oder ein reload erfolgt. Solche Geister duerfen bei der sichtbaren Roster-Sortierung niemals aktive Gruppenmitglieder verdraengen; aktive Eintraege muessen immer vor Geistern gerendert werden.
- Erforderliche Tests:
  - Group member leaving becomes ghost
  - Ghost is removed and data restored when player rejoins
  - Roster panel keeps active members visible ahead of persisted ghosts

### RULE-ROSTER-AT-DUNGEON-MARKER
- Regelnummer: 33
- Status: aktiv
- Zusammenfassung: spieler, die sich bereits im zieldungeon befinden, werden mit einem portal-icon markiert.
- Erforderliche Tests:
  - Roster shows at-dungeon marker when unit map matches target

### RULE-ROSTER-READY-CHECK-INDICATOR
- Regelnummer: 34
- Status: aktiv
- Zusammenfassung: waehrend eines ready-checks bleibt die schrift in der roster-zeile bei ihrer normalen farbe; stattdessen wird der zeilenhintergrund entsprechend dem status (bereit=gruen/nicht bereit=rot/wartend=gelb) eingefaerbt, wartende spieler erhalten zusaetzlich eine sanduhr vor dem namen, explizit bereit- und abgelehnte spieler bleiben nach `READY_CHECK_FINISHED` jeweils noch 20 sekunden in ihrer statusfarbe markiert und danach verschwindet diese sonderdarstellung wieder; die Events `READY_CHECK`, `READY_CHECK_CONFIRM` und `READY_CHECK_FINISHED` muessen dafuer den dedizierten Ready-Check-Refreshpfad nutzen, ohne den generischen Voll-Renderpfad zu verwenden oder Secure-Rollenbutton-Attribute neu zu schreiben.
- Erforderliche Tests:
  - Roster ready check uses row backgrounds and waiting icon without recoloring text
  - Roster ready check stays green for 20 seconds after finish
  - Roster declined ready check stays red for 20 seconds after finish
  - Ready-check dedicated refresh clears declined row background after hold expiry
  - Event handlers route ready check lifecycle through refreshReadyCheckUI without generic rerender
  - Event handlers keep ready-check rows green for 20 seconds after finish
  - Event handlers keep declined ready-check rows red for 20 seconds after finish
  - TAINT: Ready-check refresh preserves secure role button attributes
  - Architecture ready check refresh stays wired through runtime setup and controller wiring

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
  - Teleport active Midnight Season 1 uses shared short codes for enUS and deDE

### RULE-WARTUNGSDATEI-NICHT-IM-PAKET
- Regelnummer: 37
- Status: aktiv
- Zusammenfassung: Die Wartungsdatei `WARTUNG.md` darf nicht im CurseForge-Paket landen.
- Erforderliche Tests:
  - Architecture pkgmeta excludes WARTUNG maintenance doc from release package

### RULE-WARTUNGSKETTE-WIEDEREINSTIEG
- Regelnummer: 38
- Status: aktiv
- Zusammenfassung: `WARTUNG.md` muss die verpflichtende Wartungskette fuer den Wiedereinstieg nennen: `CHANGELOG.md`, `TODO.md`, `RULES_LOGIC.md`, `ARCHITECTURE_RULES.md`, `AGENTS.md`, `README.md`, `RELEASE.md`, `USECASES.md`, `ARCHITECTURE.md`.
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
- Status: veraltet
- Zusammenfassung: Duplikat zu Regel 11; bei Gruppengroessen > 5 (Raid) wird die Main-UI sofort ausgeblendet, es wird keine Raid-Benachrichtigung ausgegeben und kein H-Modus erzwungen; Hintergrundverarbeitung fuer Raid ist aus.
- Erforderliche Tests:
  - Raid group hides the UI and suppresses background processing
  - Factory raid behavior resolver defaults to raid off and normalizes legacy values

### RULE-UNIT-EXISTS-GUARD
- Regelnummer: 41
- Status: aktiv
- Zusammenfassung: API-Aufrufe mit Unit-Tokens muessen `UnitExists` pruefen, bevor sie aufgerufen werden, um Race-Conditions bei Gruppenaenderungen abzufangen.
- Erforderliche Tests:
  - Units GetUnitRole returns NONE for non-existing unit
  - Units GetUnitNameAndRealm returns nil for non-existing unit

### RULE-MAIN-UI-AUTO-CLOSE-OPTION
- Regelnummer: 42
- Status: aktiv
- Zusammenfassung: Die Behavior-Option `Auto-Close bei Key-Start / Solo` ist standardmaessig deaktiviert. Nur wenn `autoCloseMainFrame == true` gesetzt ist, darf die Main-UI bei `CHALLENGE_MODE_START` und beim Wechsel von Gruppe zu Solo automatisch verborgen werden.
- Erforderliche Tests:
  - Settings panel defaults Auto-Close on Key Start / Solo to disabled until the user turns it on
  - Factory auto-close main frame defaults to disabled unless explicitly enabled
  - Event handlers auto-hide main frame on challenge start when auto-close is enabled
  - Group leave auto-close hides frame when option is enabled

### RULE-ROSTER-LEADER-CROWN-MARKER
- Regelnummer: 43
- Status: aktiv
- Zusammenfassung: Der Gruppencontroller muss den echten `UnitIsGroupLeader`-Status fuer `player` und `partyN` deterministisch in den Roster-Eintrag spiegeln; die Roster-Anzeige muss fuer genau diese Eintraege eine 16x16-Kronenmarkierung rendern und bei bekannten isiLive-Nutzern das blaue Herz zusaetzlich beibehalten und vor der Krone anordnen.
- Erforderliche Tests:
  - Group roster stores current group leader flag for player and party units
  - Roster display appends crown marker for group leader
  - Roster display renders blue-heart marker before crown marker for synced leader
  - Architecture leader marker stays wired through runtime setup and controller wiring

### RULE-CENTER-NOTICE-PORTAL-TYPOGRAFIE
- Regelnummer: 44
- Status: aktiv
- Zusammenfassung: Alle Aufrufe der gemeinsamen `CenterNotice` muessen fuer den Notice-Body denselben Basis-Font wie die Portal-Navigator-Eintraege (`GameFontNormal`) sowie die Standardfarbe `(1, 0.92, 0.7)` verwenden; explizite `fontScale`- und `textColor`-Overrides duerfen nur deterministisch auf dieser Basis aufsetzen.
- Erforderliche Tests:
  - Center notice font scale does not grow across repeated notices
  - Center notice uses portal navigator typography defaults
  - Architecture center notice and portal entries share the same notice body typography helper

### RULE-MAIN-UI-STARTUP-AUTO-SHOW
- Regelnummer: 45
- Status: aktiv
- Zusammenfassung: Beim `PLAYER_LOGIN` wird die Main-UI standardmaessig eingeblendet, ausser im Raidmodus, damit Login und UI-Reload sichtbar starten; mit deaktivierter Behavior-Option `autoShowMainFrameOnStartup == false` muss dieser Auto-Show-Pfad ausbleiben.
- Erforderliche Tests:
  - Event handlers auto-show main frame on PLAYER_LOGIN for startup login and reload
  - Event handlers skip PLAYER_LOGIN auto-show when startup setting is disabled
  - Settings panel defaults Login / Reload auto-show and Key-End auto-open to enabled

### RULE-MAIN-UI-LAYOUT-SWITCH-IN-COMBAT
- Regelnummer: 46
- Status: aktiv
- Zusammenfassung: Ein manueller Klick auf einen Layout-Button (`M2`, `H`, `V`, `M`) muss den gewuenschten `layoutMode` auch waehrend Kampf-Lockdown sofort uebernehmen duerfen, ausser im Raidmodus. Direkte Show/Hide- oder Layout-Mutationen an Secure-Kindern bleiben im Kampf weiterhin unterbunden; sobald `PLAYER_REGEN_ENABLED` eintritt und die Main-UI sichtbar ist, muss genau ein normaler UI-Refresh laufen, damit die sichtbaren Secure-Kinder den bereits gesetzten `layoutMode` deterministisch nachziehen.
- Erforderliche Tests:
  - TAINT: Collapse click switches layout during combat while secure roster buttons exist
  - TAINT: Horizontal collapse click switches layout during combat while secure roster buttons exist
  - Event handlers rerender visible UI on regen after combat-safe layout changes

### RULE-ESC-PANEL-COMBAT-MOUNT
- Regelnummer: 47
- Status: aktiv
- Zusammenfassung: Die ESC-Panel-Overlays muessen als direkte, vorab erzeugte Kinder von `GameMenuFrame` gemountet bleiben. Waehrend Kampf-Lockdown duerfen weder `OnShow` noch nachgelagerte Callback-Pfade an diesen Overlays `Show`, `Hide`, `ClearAllPoints`, `SetPoint`, `SetSize`, `EnableMouse` oder `SetAlpha` ausfuehren. Unsichere ESC-Shortcuts bleiben sichtbar, duerfen ihre Aktion im Kampf aber nicht ausfuehren; Secure-Button-Refreshes bleiben bis `PLAYER_REGEN_ENABLED` verzoegert.
- Erforderliche Tests:
  - UI game-menu panel stays mounted as GameMenuFrame child while reload button remains secure
  - UI game-menu panels rely on parent visibility instead of deferred host callbacks
  - UI game-menu first combat open keeps mounted panel visible while insecure shortcuts are combat-blocked
  - UI second game-menu panel also stays visible during combat
  - UI game-menu secure button updates are deferred during combat and applied after regen

### RULE-SYNC-LAST-RUN-METRIKEN
- Regelnummer: 48
- Status: aktiv
- Zusammenfassung: Der Sync-Pfad fuer Last-Run-Metriken nutzt weiterhin den `DPS`-Nachrichtentyp als rueckwaertskompatiblen Transportkanal, transportiert darin aber nur den belastbar verifizierten `DPS`-Wert. Beim Backfill ins Roster darf nur `syncDps` angezeigt werden, wenn lokal noch kein Last-Run-DPS vorliegt.
- Erforderliche Tests:
  - Sync ProcessAddonMessage parses DPS payload and stores it
  - KeySync ApplyKnownKeyToRosterEntry backfills syncDps and syncLocMapID
  - KeySync ApplyKnownKeyToRosterEntry clears stale synced DPS fallback fields when sync data disappears

### RULE-KICKTRACKER-PERSOENLICHER-INTERRUPT
- Regelnummer: 49
- Status: aktiv
- Zusammenfassung: Der Kick-Tracker bildet den aktuell verfuegbaren Interrupt der aktuellen Spezialisierung ab. Holy Paladin muss `Rebuke` aufloesen, Devourer Demon Hunter muss `Disrupt` aufloesen, und Warlock-Spezialisierungen muessen verfuegbare pet-basierte Interrupts als eigenen Kick behandeln; ohne verfuegbaren Pet-Interrupt bleibt kein aufloesbarer Kick uebrig.
- Erforderliche Tests:
  - KickTracker resolves Holy Paladin to Rebuke
  - KickTracker resolves Warlock pet-based Spell Lock for Affliction and Destruction
  - KickTracker resolves Demonology Warlock pet interrupt when available
  - KickTracker shows no kick when Warlock pet interrupt is unavailable
  - KickTracker resolves Devourer Demon Hunter to Disrupt

### RULE-KICK-UI-UND-SYNC
- Regelnummer: 50
- Status: aktiv
- Zusammenfassung: Die Kicks-Spalte zeigt fuer den lokalen Spieler und fuer isiLive-Gruppenmitglieder den aktuellen Kick-Status an: benutzbar ergibt `ready` in Gruen, laufender Cooldown ergibt rote Restsekunden, und ohne verfuegbaren Kick oder ohne isiLive-Sync bleibt `-`. Kick-Statusaenderungen und aktive Cooldowns muessen spaetestens einmal pro Sekunde an isiLive-Gruppenmitglieder synchronisiert werden; wenn ein `ready`-Paket verloren geht, muss der periodische Sync wieder auf `ready` konvergieren. Ein laufender Kick-Cooldown darf nur aus beobachtetem Cast oder aus exakten Blizzard-Cooldown-Daten abgeleitet werden; ohne belastbare Live-Daten darf kein Cooldown geraten werden. Malformed KICK-Payloads werden fail-closed verworfen und duerfen keinen synthetischen Kick-Zustand erzeugen. Nach Raid-Hard-off bleibt der Kick-Status unresolved und ungesendet, bis exakte Blizzard-Cooldown-Daten, ein danach neu beobachteter Kick-Cast oder ein danach exakt aufgeloester `kein Kick verfuegbar`-Zustand ihn wieder belastbar belegen; beliebige andere Casts duerfen diese Suppression nicht aufheben. `kein Kick verfuegbar` und `unresolved` sind getrennte Zustaende; ein `spellID == nil` darf nur dann als exakter No-Kick-Zustand synchronisiert werden, wenn die Kick-Verfuegbarkeit selbst eindeutig aufgeloest wurde. Nach `ClearKnownUsers()` darf ein identischer lokaler Kick-Status beim naechsten Sendeversuch nicht von altem Dedup- oder Cooldown-Zustand unterdrueckt werden.
- Erforderliche Tests:
  - Architecture kick tracker uses lightweight kick-column refresh hooks
  - KickTracker tracks pet-based Warlock interrupt cooldown from pet casts
  - KickTracker reconstructs active cooldown from Blizzard cooldown data without guessing
  - KickTracker keeps observed active cooldown when Blizzard cooldown fields are unreadable
  - Sync SendKick encodes no-interrupt state and deduplicates payloads
  - Sync SendKick rejects malformed kick payload inputs without guessing
  - Sync ClearKnownUsers resets kick send cooldowns so next identical payload fires immediately
  - Sync ProcessAddonMessage rejects malformed KICK payloads without inventing a state
  - Event handlers answer refresh requests while frame is hidden
  - Factory explicit kick sync reply uses recovered cooldown state instead of stale ready state
  - Factory post-raid kick reply stays unresolved until exact recovery succeeds
  - Factory post-raid kick recovery sends exact no-kick state when spell is unavailable
  - Factory post-raid unresolved kick availability does not invent a no-kick state
  - Factory post-raid kick recovery emits exactly one sync after exact cooldown change
  - Factory post-raid unrelated cast keeps kick state unresolved until the tracked kick is observed

### RULE-UI-HIDDEN-VOLLER-GRUPPENSYNC
- Regelnummer: 51
- Status: aktiv
- Zusammenfassung: Wenn die Main-UI ausgeblendet ist, bleibt der komplette isiLive-Gruppensync fuer aktuelle Gruppenmitglieder aktiv. Hidden-Clients muessen weiterhin eingehende Sync-Nachrichten empfangen und verarbeiten sowie ausgehende Sync-Zustaende fuer Gruppe und Kick senden duerfen; nur nicht-sync-bezogenes Polling wie Queue-Scanning bleibt deaktiviert. Im Raid ist diese Hintergrundverarbeitung komplett aus.
- Erforderliche Tests:
  - Bootstrap gate allows sync events while frame is hidden if configured
  - Config builders gate allows sparse local change events while frame is hidden
  - Event handlers pre-render UI for hidden addon sync updates
  - Event handlers process addon sync messages and refresh changed roster
  - Event handlers answer refresh requests while frame is hidden
  - Event handlers send sparse background snapshot on hidden zone changes
  - Event handlers send sparse background snapshot only for player-owned state changes
  - KeySync SendOwnBackgroundSnapshot publishes sparse hidden changes without DPS spam
  - KeySync SendRefreshResponse can answer hidden refresh requests
  - Architecture kick tracker uses lightweight kick-column refresh hooks

### RULE-HIDDEN-SYNC-BUCKETS-VOLLSTAENDIG
- Regelnummer: 52
- Status: aktiv
- Zusammenfassung: Hidden-Clients duerfen sichtbarkeitsabhaengige Sync-Unterdrueckung nur ohne explizite Hidden-Freigabe anwenden. Fuer gruppenrelevante Hidden-Sync-Pfade muessen weiterhin alle Buckets `KEY`, `STATS`, `DPS`, `LOC`, `TARGET` und `KICK` gesendet werden koennen. Im Raid ist das deaktiviert.
- Erforderliche Tests:
  - KeySync SendOwnBackgroundSnapshot publishes sparse hidden changes without DPS spam
  - Sync SendTarget respects visibility and deduplicates payloads
  - Event handlers answer refresh requests while frame is hidden
  - Architecture kick tracker uses lightweight kick-column refresh hooks

### RULE-SHAREKEYS-SPAMSCHUTZ
- Regelnummer: 53
- Status: aktiv
- Zusammenfassung: Der Share-Keys-Button ist 30 Sekunden gegen Spam gesperrt. Die Sperre wird lokal nach eigenem Klick gesetzt und zusaetzlich auf allen anderen isiLive-Clients ausgeloest, sobald ein eingehender SHAREKEYS-Sync empfangen wird. Ein bereits laufender lokaler Cooldown wird dabei nicht zurueckgesetzt.
- Erforderliche Tests:
  - Roster panel share keys button debounces rapid clicks
  - Roster panel share keys button locks on remote SHAREKEYS signal
  - Event handlers answer SHAREKEYS requests while frame is hidden

### RULE-NO-GUESS-LAUFZEITAUFLOESUNG
- Regelnummer: 54
- Status: aktiv
- Zusammenfassung: Wenn fuer eine Runtime-Aufloesung keine eindeutige, belastbare Quelle vorliegt, muss das Ergebnis unresolved bleiben. Fehlende oder mehrdeutige Laufzeitdaten duerfen nicht durch spekulative Fallbacks, Namens-/Token-Raten, heuristische Standardwerte oder synthetische Cooldown-/Map-Zustaende ersetzt werden. Eindeutige Aufloesungen duerfen nur aus beobachteten Live-Daten, explizit persistierten verifizierten Daten oder eindeutig bestimmten Runtime-Zusammenhaengen entstehen.
- Erforderliche Tests:
  - Factory target dungeon stays unresolved without queue or joined-key map context
  - Factory target dungeon resolves from synced exact target context
  - Factory target dungeon stays unresolved on conflicting synced exact targets
  - Teleport does not resolve by dungeon name without activityID
  - Teleport keeps activity unresolved when mapID is missing and retries unresolved lookups
  - Teleport short-code resolver keeps unknown maps unresolved instead of showing map ids
