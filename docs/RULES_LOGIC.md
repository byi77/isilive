﻿﻿﻿﻿﻿# Regellogik

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
14. Slash-Commands muessen oeffentliche Hilfe, Admin-Hilfe und die verbleibenden State-Zyklen stabil ausfuehren.
15. Roster-RIO-Delta bleibt nicht-negativ und im Prefix-Format, inklusive unit-basiertem Live-Update.
16. Addon-Sync-Nachrichten muessen rosterrelevante Aenderungen verarbeiten, deduplizieren und refreshen.
17. Die Buttons `Readycheck`, `Countdown10` und `Countdown 0` sind fuer Nicht-Leader deaktiviert und optisch abgedimmt; der Readycheck-Button muss seinen Secure-Macro-OnClick behalten.
18. Voll-Refresh wird waehrend aktivem M+-Run nicht ausgefuehrt.
19. Die Aktionen `Share Keys` und `Refresh` sind gegen Klick-Spam geschuetzt (Debounce/Rate-Limit).
20. In den Gruppenmitglieder-Zeilen ist kein Zeilenumbruch erlaubt.
21. Es gibt kein Dungeon-Portal-Highlight, wenn das Ziel nicht eindeutig aufloesbar ist.
22. Es gibt keinen wiederholten Target-Dungeon-Chatspam; bei identischem erkanntem Ziel reicht eine einmalige Ausgabe.
23. (veraltet — ersetzt durch Regel 54) Resolver sollen keine Ratefallbacks starten, wenn der primaere Resolver bereits unresolved meldet.
24. (veraltet — Duplikat zu Regeln 1 und 5) Keine geratenen, geschaetzten oder synthetischen Laufzeitwerte.
25. (veraltet — Duplikat zu Regel 15) RIO-Delta bleibt immer bei `+0` oder hoeher.
26. (veraltet — Duplikat zu Regel 2) UI-Toggle per STRG+F9 ausserhalb des Raids.
27. das schliessen der ui ist jederzeit anforderbar, entweder per klick auf das rote x rechts oben (windows like) oder per STRG+F9; ausser im Raidmodus bleiben blockierte hide-wechsel bis `PLAYER_REGEN_ENABLED` gependelt und werden dann nachgezogen
28. während die ui ausgeblendet ist, laufen roster/addon-sync im hintergrund weiter und dürfen eventgetrieben vor-rendern; queue-scanning und sonstige dauerhafte polling-last stoppen jedoch, der kick-sync bleibt fuer isiLive-gruppenmitglieder aktiv. Eventgetriebene CD-Refreshes fuer Bloodlust-ready- und Battle-Res-ready-Klanghinweise bleiben hidden erlaubt. `LFG_LIST_APPLICATION_STATUS_UPDATED` bleibt hidden fuer Queue- und Invite-Listenverarbeitung blockiert. Im Raid sind UI und Hintergrund-Sync komplett aus.
29. teleport-eintraege fuer shared spells bleiben deterministisch sortiert und doppelte grid-eintraege werden entfernt.
30. falls ein anderer user entdeckt wird welcher auch "isiLive" benutzt, hängen wir hinter seinen Namen ein <3 (blaues herz) an
31. main ui auto-open bleibt bei gruppenbeitritt erhalten, ausser im Raidmodus; key-ende auto-open ist standardmaessig an, aber abschaltbar; automatisches schliessen bei key start ist standardmaessig aus.
32. verlaesst ein gruppenmitglied die gruppe, bleibt es als "geist" (ausgegraut) in der liste, bis der slot neu besetzt wird oder ein reload erfolgt
33. spieler, die sich bereits im zieldungeon befinden, werden mit einem portal-icon markiert
34. waehrend eines ready-checks bleibt die schrift in der roster-zeile unveraendert; stattdessen markiert ein statusfarbener zeilenhintergrund bereit=gruen, nicht bereit=rot und wartend=gelb. nach `READY_CHECK_FINISHED` bleiben bereit-antworten 20 sekunden gruen und sowohl explizit nicht bereite als auch unbeantwortete spieler 20 sekunden rot; die aktualisierung laeuft ueber einen dedizierten Ready-Check-Refreshpfad ohne Secure-Rollenbutton-Neuschreibung.
35. die kompakten roster-datenspalten behalten ihr festes breitenbudget fuer spec, name, ilvl, key, rio, dps, kick und flagge.
36. roster-kurztexte bleiben kompakt und faktenbasiert: name max 12 zeichen, spec max 5 zeichen mit hunter-kurzlabels `MM`/`BM`, sprache nur flagge, key-code max 4 zeichen und kein numerischer mapID-Fallback.
37. die wartungsdatei `WARTUNG.md` darf nicht im curseforge-paket landen.
38. `WARTUNG.md` muss die verpflichtende wartungskette fuer den wiedereinstieg nennen: `CHANGELOG.md`, `TODO.md`, `RULES_LOGIC.md`, `ARCHITECTURE_RULES.md`, `AGENTS.md`, `README.md`, `RELEASE.md`, `USECASES.md`, `ARCHITECTURE.md`.
39. Die Rollensymbole im Roster-Panel sind interaktive Buttons und ermoeglichen per Klick das manuelle Markieren von Tank (Blau) und Heiler (Gruen).
40. (veraltet — Duplikat zu Regel 11) Raid-Gruppen: UI aus, keine Raid-Notice, keine H-Mode-Erzwingung, kein Hintergrund-Sync.
41. API-Aufrufe mit Unit-Tokens muessen `UnitExists` pruefen, bevor sie aufgerufen werden, um Race-Conditions bei Gruppenaenderungen abzufangen.
42. Die Behavior-Option `Auto-Close bei Key-Start / Solo` ist standardmaessig aus; nur wenn sie aktiv ist, darf die Main-UI bei Key-Start und beim Solo-Uebergang automatisch schliessen.
43. Der aktuelle Gruppenleiter wird im Roster mit einer 16x16-Krone markiert; bei bekannten isiLive-Nutzern bleibt das blaue Herz zusaetzlich sichtbar und steht vor der Krone.
44. Alle Center-Meldungen starten mit derselben Portal-Navigator-Basistypografie fuer Body-Text, Schriftgroesse und Standardfarbe.
45. Beim Login oder UI-Reload wird die Main-UI standardmaessig eingeblendet, ausser im Raidmodus; die Startup-Option kann diesen Auto-Show-Pfad weiterhin abschalten.
46. Manuelle Layout-Umschaltungen der Main-UI duerfen auch im Kampf angefordert werden, ausser im Raidmodus; direkte Mutationen an Secure-Kindern bleiben dabei ausgesetzt und werden spaetestens bei `PLAYER_REGEN_ENABLED` ueber den sichtbaren UI-Refresh nachgezogen.
47. Die ESC-Panel-Overlays muessen im Kampf als bereits gemountete `GameMenuFrame`-Kinder sichtbar bleiben; waehrend Kampf-Lockdown sind an ihnen keine Show/Hide- oder Layout-Mutationen erlaubt, unsichere Shortcuts bleiben sichtbar, duerfen ihre Aktion aber erst ausserhalb des Kampfes ausfuehren, und sichere Mount-Shortcuts muessen als Secure-Macro-Buttons mit verifiziertem Spellnamen vorkonfiguriert sein; wenn Mount-Daten beim Initialisieren noch nicht verifizierbar sind, bleibt das Mount-Panel als gemountetes Kind vorhanden und aktualisiert seine sichtbaren Shortcuts beim naechsten ESC-Menue-Oeffnen ausserhalb des Kampfes.
48. Der isiLive-Last-Run-Sync transportiert nur den belastbar verifizierten `DPS`-Wert eines Snapshots; das Roster nutzt `syncDps` nur als Fallback, wenn lokal kein Last-Run-DPS vorliegt.
49. Der Kick-Tracker bildet den aktuell verfuegbaren Interrupt der aktuellen Spezialisierung ab; Heal-Specs ohne Interrupt (Holy Paladin, Mistweaver Monk, Restoration Druid, Discipline / Holy Priest) melden `hasKick=false`, Devourer Demon Hunter nutzt `Disrupt`, und verfuegbare pet-basierte Warlock-Interrupts zaehlen als eigener Kick.
50. Die Kicks-Spalte zeigt fuer den lokalen Spieler und fuer isiLive-Gruppenmitglieder den aktuellen Kick-Status an; der kompakte `SYNC_KICK_READY_SHORT`-Marker ist gruen, laufende Cooldowns zeigen rote Restsekunden, `-` steht fuer keinen verfuegbaren Kick oder fehlenden isiLive-Sync, und aktive Kick-Statusaenderungen werden spaetestens einmal pro Sekunde synchronisiert.
51. Bei ausgeblendeter UI bleibt der komplette isiLive-Gruppensync aktiv; nur nicht-sync-bezogenes Polling wie Queue-Scanning bleibt deaktiviert. Im Raid ist diese Hintergrundverarbeitung komplett aus.
52. Hidden-Clients senden weiterhin alle gruppenrelevanten isiLive-Sync-Buckets einschliesslich `KEY`, `STATS`, `DPS`, `LOC`, `TARGET` und `KICK`; sichtbarkeitsabhängige Unterdrückung ist nur ohne explizite Hidden-Freigabe erlaubt. Im Raid ist das deaktiviert.
53. Der Share-Keys-Button ist 30 Sekunden gegen Spam gesperrt; beim eigenen Klick wird der `SHAREKEYS`-Sync vor dem sichtbaren Party-Post dispatcht, lokal startet die Sperre nur nach einem wirksamen Klick mit erfolgreichem eigenem Party-Post oder erfolgreichem `SHAREKEYS`-Sync, und empfangende isiLive-Clients sperren ihren Button bei jedem eingehenden `SHAREKEYS`-Pfad unabhaengig davon, ob sie dabei einen eigenen Party-Post ausloesen koennen. Ein bereits laufender lokaler Cooldown wird dabei nicht zurueckgesetzt.
54. Wenn fuer eine Runtime-Aufloesung keine eindeutige, belastbare Quelle vorliegt, muss das Ergebnis unresolved bleiben; fehlende oder mehrdeutige Laufzeitdaten duerfen nicht durch spekulative Fallbacks, Namens-/Token-Raten, heuristische Standardwerte oder synthetische Zustaende ersetzt werden.
55. Die Main-UI kann ueber `lockMainFramePosition` gesperrt werden; bei aktivem Lock duerfen Frame und Drag-Handle keinen Positions-Drag starten und die gespeicherte Position bleibt unveraendert.
56. Runtime-Log-Eintraege werden nur bei aktivem Runtime-Logging geschrieben; jeder Eintrag traegt eine stabile Sequenznummer und einen praezisen Zeitstempel, `[TAG] action`-Nachrichten werden zu `[TAG] event=action` normalisiert, teure Formatierung und Trace-Builder duerfen bei ausgeschaltetem Log oder deaktivierter Deep-Stufe nicht laufen, und der Logspeicher muss seine Tail-Reihenfolge und sein Cap auch bei grossen Log-, Sync- und Roster-Bursts behalten.
57. Der Ingame-Testmodus muss die aktuellen Demo-Daten fuer M+-Timer, Combat-CDs, den unteren M+-Forces-Tracker, Multi-Kick-Tooltip-Extras, Statsbox, Portal-Navigator, Centerbox-Portal, Non-Mythic-Dungeon-Entry-Centerbox, M+-Forces-Nameplates/-Tooltip, LFG-Bonusmarker, Ready-Check-Hold-Zeilen, Share-Keys-Cooldown, Death-Alert-Preview, Sound-/TTS-Preview und das verschiebbare Demo-Simulations-Tablet setzen und beim Verlassen wieder bereinigen; die Centerbox-Portal- und Non-Mythic-Dungeon-Entry-Demos muessen parallel sichtbar sein und duerfen sich im Demomodus nicht gegenseitig verdraengen.
58. `CHALLENGE_MODE_COMPLETED` und `CHALLENGE_MODE_RESET` muessen den M+-Timer-Snapshot sofort vollstaendig wegraeumen und die CD-Tracker-Zeile neu rendern; `PLAYER_ENTERING_WORLD` waehrend eines laufenden Keys darf den Timer nicht stoppen.
59. Der untere M+-Killtracker zeigt vor Key-Start verifizierte Ziel-Dungeon-Daten aus der Target-Dungeon-Aufloesung rechtsbuendig an; eine Keystufe wird nur bei positiver numerischer Aufloesung ergaenzt. Ab Key-Start wechselt er zur Prozentanzeige zurueck; waehrend aktiver Prozentdaten darf der verifizierte Dungeonname linksbuendig als helles Outline-Label mit dunkler Hinterlegung auf dem Prozentbalken sichtbar bleiben, und die daneben angezeigte aktive Keystufe darf nur aus dem gestarteten M+-Timer-Keylevel stammen.
60. Der M+-Killtracker muss den sichtbaren Gesamtfortschritt am Kampfende und ueber seinen aktiven Refresh-Ticker aus den Live-Scenario-Daten aktualisieren, damit abgeschlossene Pulls nicht erst beim naechsten Kampf sichtbar werden.
61. Die verworfene LFG-Invite-Liste bleibt entfernt: Es gibt kein Modul, keinen TOC-Eintrag, kein Settings-Control, kein SavedVariable-Feld und kein Runtime-Wiring; `LFG_LIST_APPLICATION_STATUS_UPDATED` darf keine Invite-Listenverarbeitung ausloesen.
62. Addon-eigene sichtbare FontStrings und private Tooltips muessen fuer `ruRU` und konkrete kyrillische Payload-Texte einen kyrillisch-faehigen Font verwenden, unabhaengig vom WoW-Client-Locale.
63. Die M+Marker-Leiste muss native SecureActionButton-Worldmarker-Attribute verwenden, ihre sicheren Klickflaechen ueber konkurrierenden UI-Sibling-Frames halten und darf keine geschuetzten Marker-APIs direkt aufrufen.
64. Ein Reload-Roster-Mirror darf verifizierte Gruppenanzeigedaten und den verifizierten aktuellen Gruppen-Ziel-Key nur wiederherstellen, wenn die aktuelle Gruppensignatur exakt zur gespeicherten Signatur passt; ein erfolgreicher Mirror-Restore ist kein neuer Gruppenbeitritt und darf keine Join-Sideeffects ausloesen; Kick-Zustaende werden daraus nicht wiederhergestellt.
65. Die eigenstaendige Spieler-Stats-Box zeigt den Primärstat klassen- beziehungsweise spezialisierungsgenau, zeigt nur direkt aus Blizzard-Live-APIs gelesene Werte, kann Leech, Speed, Haltbarkeit, Ausdauer und Vermeidung einzeln ein- oder ausblenden, kann Werte und Prozente zusammen oder jeweils einzeln anzeigen, aktiviert Leech und Speed standardmaessig und deaktiviert Haltbarkeit, Ausdauer und Vermeidung standardmaessig, haelt ihre Werte-Spalte auch bei drei- und vierstelligen Zahlen stabil, haelt ihre Prozent-Spalte breit genug fuer `(999.99%)`, bleibt trotz Spaltentrennung, Primärstat-Akzent, Hover-Hintergrund und dezenter zeilenweiser Hintergrundtoenung rahmenlos und ohne Titelzeile, ist standardmaessig aus, ueber Settings einschaltbar und gegen Positions-Drag sperrbar, und speichert ihre Position getrennt von der Main-UI.
66. Alle frei verschiebbaren isiLive-Fenster muessen an den WoW-Sichtbereich geklemmt sein, sodass ihre Raender beim Ziehen nicht ausserhalb des WoW-Fensters verschwinden.
67. Das ESC-Addons-Panel darf Shortcut-Buttons fuer Addons anzeigen, die installiert und auf dem aktuellen Charakter aktiviert sind; beim Klick muss ein noch nicht geladenes externes Ziel-Addon verifiziert geladen werden, bevor dessen registrierter Slash-Alias nach beobachtet geschlossenem `GameMenuFrame` mit Blizzard-kompatibler Handler-Signatur ausgefuehrt wird. Der isiLive-eigene Shortcut darf stattdessen direkt die isiLive-Settings oeffnen und darf keinen Self-Load versuchen.
68. Die LFG-Klassenbonus-Herzchen zaehlen nur relevante, nicht stapelnde Gruppenboni; Utility-Effekte wie PI, BL, BR, Devotion Aura und Atrophic Poison erzeugen keine Herzchen, und Applicant-Zeilen rendern diese Herzchen als grüne Texturmarker rechts neben dem Klassenbadge. Roster-Zeilen zeigen dieselben grünen Bonus-Herzchen direkt am Spielernamen, wenn die Roster-Klasse und optional die Spec-ID verifiziert vorliegen. Applicant-Zeilen zeigen Sprachflaggen nur aus verifizierter Realm-Sprache und muessen den Namensanker beim Ausblenden wiederherstellen. Der Settings-Schalter ist standardmaessig aktiv, kann die Buff-Rating-Herzchen ein- und ausschalten und beschreibt mit untereinander stehenden Herz-Textur-Beispielzeilen, dass 1/2/3/4 Herzchen einen, zwei, drei beziehungsweise vier oder mehr relevante Buffs bedeuten. Beim Programmieren werden Deutsch und Englisch gepflegt; weitere vorbereitete Locales duerfen bis zur Nachbearbeitung englischen Fallback verwenden oder nachbearbeitete Uebersetzungen tragen.
69. Wenn nach einem LFG-Gruppenbeitritt kein `inviteaccepted`-Event beim Accepted-Invite-Pfad angekommen ist, darf die Centerbox nur bei aktiviertem Gruppenbeitritts-Zielhinweis aus einem bereits verifizierten lokalen Ziel-Dungeon-Kontext gerendert werden und muss ohne diesen Kontext, bei deaktiviertem Gruppenbeitritts-Zielhinweis oder bei einem Reload-Roster-Mirror-Restore einer bestehenden Gruppe stumm bleiben. Die direkte Accepted-Invite-Notice und der Gruppenbeitritts-Zielhinweis muessen getrennt schaltbar bleiben.
70. Center-Notice- und Portal-Navigator-Ueberschriften muessen mit `isiLive - ` beginnen und den gemeinsamen warmen Goldton verwenden.
71. Der Bloodlust-ready-Klanghinweis darf nur waehrend eines laufenden M+-Timers mit aktiver Gruppe und erst nach einem zuvor beobachteten aktiven Erschoepfungsdebuff abgespielt werden, sobald der beobachtete angezeigte Erschoepfungs-Timer null erreicht oder ein spaeterer natuerlicher Scan keinen aktiven Erschoepfungsdebuff mehr findet; wenn Bloodlust danach unbenutzt verfuegbar bleibt und der Bloodlust-ready-Erinnerungsloop nicht per Settings deaktiviert ist, muss der Klanghinweis alle 60 Sekunden wiederholt werden, bis ein neuer aktiver Erschoepfungsdebuff beobachtet wird; er darf bei Key-Ende-, Key-Abbruch-, Dungeon-Verlassen-, Gruppen-Verlassen- oder sonstigem Nicht-laufend-Refresh nicht ausloesen, muss dabei seinen beobachteten Ready-Zyklus verwerfen, muss UNIT_AURA-Removal-Payloads als moegliches natuerliches Auslaufen scannen und muss die eigenen Settings-Optionen respektieren.
72. Der Battle-Res-ready-Klanghinweis darf nur waehrend eines laufenden M+-Timers mit aktiver Gruppe und erst nach einem zuvor beobachteten Battle-Res-Cooldown oder null verfuegbaren Battle-Res-Aufladungen abgespielt werden, sobald der beobachtete angezeigte Battle-Res-Cooldown null erreicht oder ein spaeterer natuerlicher Scan mindestens eine verfuegbare Aufladung findet; der erste verfuegbare Battle-Res-Zustand direkt nach Key-Start bleibt stumm, danach muss jede weitere beobachtete Wiederverfuegbarkeit angesagt werden; sichtbare UI-Rescans muessen denselben Ready-Transition-Pfad nutzen wie der Factory-CD-Tracker; der Klanghinweis darf bei Key-Ende-, Key-Abbruch-, Dungeon-Verlassen-, Gruppen-Verlassen- oder sonstigem Nicht-laufend-Refresh nicht ausloesen, muss dabei seinen beobachteten Ready-Zyklus verwerfen und muss die eigene Settings-Option respektieren.
73. Der Pre-Accept-LFG-Invite-Hint bleibt entfernt; ein `invited`-Status darf kein oberes Einladungsfenster rendern und es gibt kein Factory-Wiring, kein Settings-Control, kein SavedVariable-Feld und keine Testmodus-Demo dafuer.
74. Queued `INSTANCE_CHAT`-Addon-Sync darf nach dem Verlassen der Instanzgruppe nicht mehr an Blizzard gesendet werden und muss als nicht gesendet gemeldet werden.
75. Die M+-Forces-Namensplakettenanzeige muss mit Blizzard-Namensplaketten, Plater und Platynator funktionieren; die Settings-Vorschau muss denselben Renderer nutzen wie die Runtime.
76. Die Roster-Rolle muss bei vorhandener verifizierter Inspect-Spezialisierung aus Blizzards Spezialisierungsrollen-API korrigiert werden; stale Gruppenrollenzuweisungen duerfen die Spec-Rolle nicht dauerhaft ueberstimmen.
77. CurseForge- und WowUp-Pakete muessen denselben Nutzerinhalt enthalten; jede Paket-Ausschlussaenderung muss beide Paketpfade synchron aktualisieren.
78. Eingebaute Soundausgaben laufen standardmaessig ueber `Master`; `soundOutputChannel` akzeptiert nur `Master`/`SFX` und faellt geschlossen auf `Master` zurueck.
79. Nach dem SavedVariables-Restore muss `ADDON_LOADED` gespeicherte Anzeige-Settings erneut ueber den echten `ApplyDBSettings`-Callback anwenden.
80. Der Tank-/Heiler-Todesalarm zeigt nur waehrend eines aktiven M+-Runs beim Uebergang lebendig zu tot einmalig eine grosse rote Bildschirmwarnung mit TTS-Ansage; ein einzelner Settings-Schalter schaltet Text und Sound gemeinsam.
81. Der Ready-Check-Komplett-Klang spielt `BttF_Tinkle.wav` genau einmal, wenn exakt fuenf gueltige Ready-Check-Teilnehmer im aktiven Ready-Check als bereit markiert sind, und ist per Settings abschaltbar.

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
  - Highlight listing resolver rejects partially unresolved activity maps
  - Highlight queue fallback is disabled while not in group
  - Highlight invite-accepted state survives transient non-group roster updates
  - Highlight invite-accepted state survives late roster false negatives while group members are still present
  - Highlight queue path ignores active challenge map before actual dungeon entry
  - Factory target dungeon clear waits for actual player map entry
  - Factory primary highlight forwards local target map to shared resolver

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
  - UI second game-menu hearthstone settings change defers secure attributes during combat
  - UI game-menu hearthstone settings change defers secure attributes during active challenge key
  - Architecture secure button mutation surface is explicitly audited for combat and key safety
  - UI direct SetVisible defers during combat and applies after regen
  - TAINT: M2 roster rerender skips secure tank-helper layout mutations during combat
  - TAINT: Leader button update defers secure ready-check state during combat
  - PLAYER_REGEN_ENABLED applies pending leader button updates

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
  - Settings panel renders raid behavior as a status note instead of a single-option selector
  - Factory raid behavior resolver defaults to raid off and normalizes legacy values
  - Sync GetAddonSyncChannel returns nil in raid
  - Sync SendShareKeysRequest does not publish in raid

### RULE-LOCALE-SYMMETRIE-FALLBACK
- Regelnummer: 12
- Status: aktiv
- Zusammenfassung: Locale-Tabellen muessen schluesselsymmetrisch sein; Fallback fuer unbekannte Tags bleibt enUS. Die Umwandlung von Locale-Tags in Sprachflaggen-Tags muss tooltip-hotpath-tauglich ueber eine konstante Lookup-Tabelle laufen und darf nicht pro Tooltip-Aufruf die unterstuetzten Sprachen iterieren.
- Erforderliche Tests:
  - All enUS keys exist in deDE locale
  - All deDE keys exist in enUS locale
  - Locale tag resolver returns enUS as default fallback
  - Locale.LocaleToLanguageTag resolves from static lookup without iterating supported languages
  - Settings panel refresh localizes behavior auto and raid notes
  - Locale hearthstone settings strings are localized per supported language
  - Settings hearthstone selector shows English toy names for non-German addon locales
  - Settings hearthstone selector uses client-localized toy names for German addon locale
  - German settings stats-box descriptions are localized
  - LI.BuildBonusSuffix localizes class bonuses and keeps German text for deDE only
  - LI.ApplyGroupBonusTooltipLines matches exact member lines without a German or English section header

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
- Zusammenfassung: Slash-Commands muessen die oeffentliche Hilfe und die getrennte Admin-Hilfe stabil ausfuehren. Entfernte Legacy-Commands wie `test`, `pause`, `resume`, `lead`, `stop`, `start` und `lang` duerfen nicht mehr als Spezialbefehle ausgefuehrt werden.
- Erforderliche Tests:
  - Commands help lists only public commands
  - Commands admin input prints admin command list
  - Commands removed legacy commands fall back to public help

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
  - Sync ProcessAddonMessage stores ACK version as hello info
  - Sync ProcessAddonMessage handles LibKeystone requests and payloads
  - Sync ProcessAddonMessage ignores LibKeystone payloads for kick state
  - Sync ProcessAddonMessage keeps richer isiLive stats when LibKeystone only refreshes rio
  - Sync ProcessAddonMessage parses KICK payloads with no-interrupt state
  - Sync ProcessAddonMessage parses TARGET payload and stores it
  - Sync SetPlayerKeyInfo deduplicates identical key updates
  - KeySync ApplyKnownKeyToRosterEntry preserves synced no-interrupt state
  - KeySync pending forced refresh backfills missing sync fallback fields while inspect is pending

### RULE-LEADER-BUTTONS-SICHTBARKEIT
- Regelnummer: 17
- Status: aktiv
- Zusammenfassung: Die Buttons `Readycheck`, `Countdown10` und `Countdown 0` sind fuer Nicht-Leader deaktiviert und optisch abgedimmt. Der Readycheck-Button muss als Secure-Macro-Button mit `/readycheck` fuer Default-, Links- und Rechtsklick konfiguriert bleiben, Mouse-Up- und Mouse-Down-Klicks registrieren und darf den Secure-Action-OnClick nicht durch einen normalen Lua-Clickhandler ersetzen.
- Erforderliche Tests:
  - Roster panel leader-only buttons disable when player is not leader
  - Roster panel ready-check button uses a secure macro action
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
  - Roster panel share keys button ignores no-op clicks without chat or sync success

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
- Zusammenfassung: Es gibt keinen wiederholten Target-Dungeon-Chatspam; bei identischem erkanntem Ziel reicht eine einmalige Ausgabe. Der Announce wartet bis zu drei Sekunden auf die aufgeloeste Keystufe, faellt erst danach auf eine stufenlose Zeile zurueck und darf nach einem LFG-Invite-Accept erst nach beobachtetem Gruppenbeitritt ausgegeben werden.
- Erforderliche Tests:
  - Status target dungeon chat defers the level-less announce and fires once the level resolves
  - Status target dungeon chat falls back to a level-less announce once the deferred wait elapses
  - Status AnnounceTargetDungeonFromPayload emits exact Blizzard keystone level markup
  - LFGDetect direct-push carries exact Blizzard keystone level markup
  - LFGDetect direct-push waits for GROUP_ROSTER_UPDATE when IsInGroup is transient false
  - LFGDetect GROUP_ROSTER_UPDATE recovery fires target-dungeon-chat callback once

### RULE-UI-STRG-F9-JEDERZEIT
- Regelnummer: 26
- Status: veraltet
- Zusammenfassung: Ersetzt durch Regel 2 (`RULE-UI-HOTKEY-KAMPF-TOGGLE`); der STRG+F9-Toggle und die Kampf-Lockdown-Defer-Logik werden dort verbindlich erzwungen.
- Erforderliche Tests:
  - (siehe Regel 2)

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
- Zusammenfassung: waehrend die ui ausgeblendet ist, laeuft der daten-sync (roster/addon-msgs) im hintergrund weiter und darf eventgetrieben ui-zustand vor-rendern; queue-scanning und sonstige dauerhafte polling-last bleiben aus. `LFG_LIST_APPLICATION_STATUS_UPDATED` bleibt hidden fuer Queue- und Invite-Listenverarbeitung blockiert. Eventgetriebene CD-Refreshes duerfen hidden fuer Bloodlust-ready- und Battle-Res-ready-Klanghinweise laufen, ohne den dauerhaften Hidden-CD-Ticker zu aktivieren. Der Kick-Sync fuer isiLive-Gruppenmitglieder bleibt davon ausgenommen und darf weiterlaufen, damit ausgeblendete Clients keine Kick-Nachteile erzeugen. Ein expliziter Refresh-Request darf Hidden-Clients genau eine forciert eventgetriebene Antwort entlocken (alle Sync-Buckets: KEY, STATS, DPS, LOC, TARGET, KICK); gestoppte oder pausierte Runs antworten dabei nicht. Im Raid sind UI und Hintergrund-Sync komplett aus.
- Erforderliche Tests:
  - Bootstrap gate allows sync events while frame is hidden if configured
  - Bootstrap gate allows addon sync during combat for in-key BRLUST announces
  - factory composition root: natural in-key spellcast announces BR through runtime gate
  - ConfigBuilders hidden gate keeps LFG status blocked
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
  - KeySync SendIsiLiveHello allows hidden version sync
  - Config builders gate allows sparse local change events while frame is hidden
  - KeySync SendRefreshResponse can answer hidden refresh requests
  - KeySync SendRefreshResponse skips while paused or stopped
  - Bootstrap gate keeps hidden lifecycle triggers for key start/end and summon
  - Bootstrap gate keeps hidden CD refresh triggers for ready sounds
  - Config builders gate allows CD refresh events while frame is hidden
  - INCOMING_SUMMON_CHANGED plays incoming-summon sound for pending player summons
  - INCOMING_SUMMON_CHANGED ignores non-player and non-pending summon updates
  - INCOMING_SUMMON_CHANGED fails closed when pending summon enum is unavailable
  - INCOMING_SUMMON_CHANGED suppresses incoming-summon sound in raid mode
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
  - DBSchema.Sanitize migrates legacy autoCloseMainFrame into split auto-close fields
  - Event handlers forward challenge start to LFGDetect
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
  - KeySync ApplyKnownKeyToRosterEntry clears stale synced LOC fallback fields when sync data disappears

### RULE-ROSTER-READY-CHECK-INDICATOR
- Regelnummer: 34
- Status: aktiv
- Zusammenfassung: waehrend eines ready-checks bleibt die schrift in der roster-zeile bei ihrer normalen farbe; stattdessen wird der zeilenhintergrund entsprechend dem status (bereit=gruen/nicht bereit=rot/wartend=gelb) eingefaerbt, wartende spieler erhalten zusaetzlich eine sanduhr vor dem namen, explizit bereit-antworten bleiben nach `READY_CHECK_FINISHED` noch 20 sekunden gruen markiert und sowohl explizit nicht bereite als auch unbeantwortete spieler bleiben noch 20 sekunden rot markiert; danach verschwindet diese sonderdarstellung wieder. Die Events `READY_CHECK`, `READY_CHECK_CONFIRM` und `READY_CHECK_FINISHED` muessen dafuer den dedizierten Ready-Check-Refreshpfad nutzen, ohne den generischen Voll-Renderpfad zu verwenden oder Secure-Rollenbutton-Attribute neu zu schreiben.
- Erforderliche Tests:
  - Roster ready check uses row backgrounds and waiting icon without recoloring text
  - Roster ready check stays green for 20 seconds after finish
  - Roster declined ready check stays red for 20 seconds after finish
  - Ready-check dedicated refresh clears declined row background after hold expiry
  - Event handlers toggle ready check state and refresh UI on ready check events
  - Event handlers write ready check trace entries when runtime logging is available
  - Event handlers keep ready-check rows green for 20 seconds after finish
  - Event handlers keep declined ready-check rows red for 20 seconds after finish
  - Event handlers keep unanswered ready-check rows red for 20 seconds after finish
  - TAINT: Ready-check refresh preserves secure role button attributes
  - Architecture ready check refresh stays wired through runtime setup and controller wiring

### RULE-CODING-KEINE-FALLBACK-KETTEN
- Regelnummer: 23
- Status: veraltet
- Zusammenfassung: Ersetzt durch Regel 54 (`RULE-NO-GUESS-LAUFZEITAUFLOESUNG`); der dortige No-Guess-Vertrag deckt ratebasierte Resolver-Fallback-Ketten mit ab.
- Erforderliche Tests:
  - (siehe Regel 54)

### RULE-CODING-KEIN-RATEN
- Regelnummer: 24
- Status: veraltet
- Zusammenfassung: Ersetzt durch Regeln 1 (`RULE-QUEUE-NO-GUESS`) und 5 (`RULE-TELEPORT-KEIN-NAME-GUESSING`); das generelle No-Guess-Dach liegt heute in Regel 54.
- Erforderliche Tests:
  - (siehe Regel 1 und Regel 5)

### RULE-RIO-DELTA-NIE-NEGATIV
- Regelnummer: 25
- Status: veraltet
- Zusammenfassung: Ersetzt durch Regel 15 (`RULE-ROSTER-RIO-DELTA-FORMAT`); der aktive RIO-Delta-Vertrag deckt non-negative Anzeige mit `(+X)`-Prefix ab.
- Erforderliche Tests:
  - (siehe Regel 15)

### RULE-ROSTER-KOMPAKT-SPALTENBREITEN
- Regelnummer: 35
- Status: aktiv
- Zusammenfassung: Die Roster-Datenspalten behalten ein festes Kompaktlayout mit den Breiten Spec=52, Name=122, iLvl=32, Key=62, Rio=70, DPS=40, Kick=40 und Flagge=18.
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
  - Roster Tank role button targets by character name (not unit token)
  - Roster Healer role button targets by character name with cross-realm suffix

### RULE-ROSTER-RAID-NOTICE
- Regelnummer: 40
- Status: veraltet
- Zusammenfassung: Ersetzt durch Regel 11 (`RULE-GRUPPE-RAID-SICHTBARKEIT`); der Raid-Hard-off-Vertrag (UI aus, keine Notice, kein Hintergrund-Sync) liegt dort.
- Erforderliche Tests:
  - (siehe Regel 11)

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
- Zusammenfassung: Die Behavior-Optionen `Auto-Close bei Key-Start` und `Auto-Close bei Verlassen der Gruppe` sind beide standardmaessig deaktiviert. Sie haben getrennte Persistenz-Felder (`autoCloseOnKeyStart`, `autoCloseOnSoloChange`); jeder Trigger feuert nur, wenn sein eigenes Feld `== true` gesetzt ist.
- Erforderliche Tests:
  - Settings panel defaults Auto-Close on Key Start / Solo to disabled until the user turns it on
  - Factory key-start and solo-change auto-close resolvers default to disabled
  - DBSchema.Sanitize migrates legacy autoCloseMainFrame into split auto-close fields
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
- Zusammenfassung: Die ESC-Panel-Overlays muessen als direkte, vorab erzeugte Kinder von `GameMenuFrame` gemountet bleiben. Waehrend Kampf-Lockdown duerfen weder `OnShow` noch nachgelagerte Callback-Pfade an diesen Overlays `Show`, `Hide`, `ClearAllPoints`, `SetPoint`, `SetSize`, `EnableMouse` oder `SetAlpha` ausfuehren. Unsichere ESC-Shortcuts bleiben sichtbar, duerfen ihre Aktion im Kampf aber nicht ausfuehren; Secure-Button-Refreshes bleiben bis `PLAYER_REGEN_ENABLED` verzoegert. Das Mounts-Panel sitzt unter dem Travel-Panel und darf Mount-Aktionen nur als sichere Macro-Buttons fuer verifizierte Favoriten-/Mount-Verfuegbarkeit und verifizierte Spellnamen anzeigen; der Favoriten-Shortcut muss einen konkret verifizierten favorisierten Mount-Spell casten. Wenn Mount-Daten oder Spellnamen beim ersten Initialisieren noch nicht verifizierbar sind, bleibt das Panel als `GameMenuFrame`-Kind gemountet, aber verborgen, und aktualisiert beim naechsten `GameMenuFrame`-`OnShow` ausserhalb des Kampfes seine sichtbaren Shortcuts.
- Erforderliche Tests:
  - UI game-menu panel stays mounted as GameMenuFrame child while reload button remains secure
  - UI game-menu panels rely on parent visibility instead of deferred host callbacks
  - UI game-menu first combat open keeps mounted panel visible while insecure shortcuts are combat-blocked
  - UI second game-menu panel also stays visible during combat
  - UI third game-menu addon panel also stays visible during combat
  - UI mount game-menu panel shows verified mount shortcuts under travel panel
  - UI mount game-menu panel stays hidden when no verified mount shortcut is available
  - UI mount game-menu panel stays hidden when spell names cannot be verified
  - UI mount game-menu panel refreshes mounted shortcuts when verified spell names become available
  - UI mount game-menu panel also stays visible during combat
  - UI game-menu secure button updates are deferred during combat and applied after regen

### RULE-SYNC-LAST-RUN-METRIKEN
- Regelnummer: 48
- Status: aktiv
- Zusammenfassung: Der Sync-Pfad fuer Last-Run-Metriken nutzt weiterhin den `DPS`-Nachrichtentyp als rueckwaertskompatiblen Transportkanal, transportiert darin aber nur den belastbar verifizierten `DPS`-Wert. Beim Backfill ins Roster darf nur `syncDps` angezeigt werden, wenn lokal noch kein Last-Run-DPS vorliegt.
- Erforderliche Tests:
  - Sync ProcessAddonMessage parses DPS payload and stores it
  - KeySync ApplyKnownKeyToRosterEntry backfills syncDps and syncLocMapID
  - KeySync ApplyKnownKeyToRosterEntry clears stale synced DPS fallback fields when sync data disappears
  - Stats controller does not use stale local DPS when the fresh run snapshot misses the player

### RULE-KICKTRACKER-PERSOENLICHER-INTERRUPT
- Regelnummer: 49
- Status: aktiv
- Zusammenfassung: Der Kick-Tracker bildet den aktuell verfuegbaren Interrupt der aktuellen Spezialisierung ab. Heal-Specs ohne Interrupt (Holy Paladin, Mistweaver Monk, Restoration Druid, Discipline/Holy Priest) muessen `hasKick=false` melden; Devourer Demon Hunter muss `Disrupt` aufloesen; Warlock-Spezialisierungen muessen verfuegbare pet-basierte Interrupts als eigenen Kick behandeln; ohne verfuegbaren Pet-Interrupt bleibt kein aufloesbarer Kick uebrig.
- Erforderliche Tests:
  - KickTracker reports no interrupt for Holy Paladin (no Rebuke in Midnight)
  - KickTracker resolves interrupt matrix for all mapped specs
  - KickTracker resolves exact no-kick matrix for supported specs
  - KickTracker resolves Warlock pet-based Spell Lock for Affliction and Destruction
  - KickTracker resolves Demonology Warlock pet interrupt when available
  - KickTracker tracks Demonology Axe Toss cooldown from the pet-cast spell alias
  - KickTracker shows no kick when Warlock pet interrupt is unavailable
  - KickTracker resolves Devourer Demon Hunter to Disrupt

### RULE-KICK-UI-UND-SYNC
- Regelnummer: 50
- Status: aktiv
- Zusammenfassung: Die Kicks-Spalte zeigt fuer den lokalen Spieler und fuer isiLive-Gruppenmitglieder den aktuellen Kick-Status an: benutzbar ergibt den kompakten `SYNC_KICK_READY_SHORT`-Marker in Gruen, laufender Cooldown ergibt rote Restsekunden, und ohne verfuegbaren Kick oder ohne isiLive-Sync bleibt `-`. Kick-Statusaenderungen und aktive Cooldowns muessen spaetestens einmal pro Sekunde an isiLive-Gruppenmitglieder synchronisiert werden; wenn ein `ready`-Paket verloren geht, muss der periodische Sync wieder auf den benutzbaren Kick-Zustand konvergieren. Ein laufender Kick-Cooldown darf nur aus beobachtetem Cast oder aus exakten Blizzard-Cooldown-Daten abgeleitet werden; ohne belastbare Live-Daten darf kein Cooldown geraten werden. Malformed KICK-Payloads werden fail-closed verworfen und duerfen keinen synthetischen Kick-Zustand erzeugen. Ein von Peers empfangener Kick-Status wird nach mehr als 45 Sekunden ohne neues KICK-Paket wieder unresolved, weil der Hintergrund-Heartbeat alle 15 Sekunden sendet. Nach Raid-Hard-off bleibt der Kick-Status unresolved und ungesendet, bis exakte Blizzard-Cooldown-Daten, ein danach neu beobachteter Kick-Cast oder ein danach exakt aufgeloester `kein Kick verfuegbar`-Zustand ihn wieder belastbar belegen; beliebige andere Casts duerfen diese Suppression nicht aufheben. `kein Kick verfuegbar` und `unresolved` sind getrennte Zustaende; ein `spellID == nil` darf nur dann als exakter No-Kick-Zustand synchronisiert werden, wenn die Kick-Verfuegbarkeit selbst eindeutig aufgeloest wurde. Nach `ClearKnownUsers()` darf ein identischer lokaler Kick-Status beim naechsten Sendeversuch nicht von altem Dedup- oder Cooldown-Zustand unterdrueckt werden.
- Erforderliche Tests:
  - Architecture kick tracker uses lightweight kick-column refresh hooks
  - KickTracker scans all talent trees for cooldown reductions
  - KickTracker tracks pet-based Warlock interrupt cooldown from pet casts
  - KickTracker reconstructs active cooldown from Blizzard cooldown data without guessing
  - KickTracker keeps observed active cooldown when Blizzard cooldown fields are unreadable
  - KickTracker refines an observed kick cooldown from exact Blizzard data
  - KickTracker does not clear an observed kick when exact data is not yet active
  - Sync SendKick encodes no-interrupt state and deduplicates payloads
  - Sync SendKick retries identical payload after a rejected dispatch
  - Sync SendKick appends primary spell suffix when spellID is explicit
  - Sync SendKick rejects malformed kick payload inputs without guessing
  - Sync ClearKnownUsers resets kick send cooldowns so next identical payload fires immediately
  - KeySync ApplyKnownKeyToRosterEntry clears peer kick state after stale heartbeat window
  - KeySync ApplyKnownKeyToRosterEntry backfills primary kick spellID when synced
  - Sync ProcessAddonMessage reports kick updates when remaining cooldown changes
  - Sync ProcessAddonMessage rejects malformed KICK payloads without inventing a state
  - Event handlers answer refresh requests while frame is hidden
  - Factory explicit kick sync reply uses recovered cooldown state instead of stale ready state
  - Factory post-raid kick reply stays unresolved until exact recovery succeeds
  - Factory post-raid kick recovery sends exact no-kick state when spell is unavailable
  - Factory post-raid unresolved kick availability does not invent a no-kick state
  - Factory post-raid kick recovery emits exactly one sync after exact cooldown change
  - Factory post-raid unrelated cast keeps kick state unresolved until the tracked kick is observed
  - kick tracker: observed casts schedule a post-cast exact cooldown reconcile
  - SetKickCellText renders compact green ready marker using locale string when available
  - SetKickCellText falls back to compact ready marker when getL returns no string
  - roster_tooltip: ShowRosterInfoTooltip renders multi-kick extras sorted by spellID

### RULE-UI-HIDDEN-VOLLER-GRUPPENSYNC
- Regelnummer: 51
- Status: aktiv
- Zusammenfassung: Wenn die Main-UI ausgeblendet ist, bleibt der komplette isiLive-Gruppensync fuer aktuelle Gruppenmitglieder aktiv. Hidden-Clients muessen weiterhin eingehende Sync-Nachrichten empfangen und verarbeiten sowie ausgehende Sync-Zustaende fuer Gruppe und Kick senden duerfen; nur nicht-sync-bezogenes Polling wie Queue-Scanning bleibt deaktiviert. Im Raid ist diese Hintergrundverarbeitung komplett aus.
- Erforderliche Tests:
  - Bootstrap gate allows sync events while frame is hidden if configured
  - Config builders gate allows sparse local change events while frame is hidden
  - Event handlers pre-render UI for hidden addon sync updates
  - Event handlers process addon sync messages and refresh changed roster
  - Event handlers answer LibKeystone requests while frame is hidden
  - Event handlers answer refresh requests while frame is hidden
  - Event handlers send sparse background snapshot on hidden zone changes
  - Event handlers send sparse background snapshot only for player-owned state changes
  - KeySync SendOwnBackgroundSnapshot publishes sparse hidden changes without DPS spam
  - Sync ProcessAddonMessage deep trace exposes raw bucket payloads and sender bytes
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
- Zusammenfassung: Der Share-Keys-Button ist 30 Sekunden gegen Spam gesperrt. Beim eigenen Klick wird der `SHAREKEYS`-Sync vor dem sichtbaren `PARTY`-Post dispatcht. Die Sperre wird lokal nur nach einem wirksamen eigenen Klick gesetzt, also wenn dabei entweder der eigene Key erfolgreich in `PARTY` angekuendigt oder ein erfolgreicher `SHAREKEYS`-Sync ausgeloest wurde; ein lokaler Print-Fallback zaehlt dafuer nicht als Chat-Share. Empfangende isiLive-Clients sperren ihren Button bei jedem eingehenden `SHAREKEYS`-Pfad, auch wenn sie keinen eigenen `PARTY`-Post ausloesen koennen. Ein bereits laufender lokaler Cooldown wird dabei nicht zurueckgesetzt. Waehrend einer laufenden Sperre muss der Button die Restzeit als Cooldown-Text stabil anzeigen; Lokalisierungs- oder Layout-Refreshes duerfen ihn nicht auf den nackten Buttontext zuruecksetzen. Im Hello-Ack-/REQSYNC-Fan-out spiegelt jeder Client eine laufende Button-Sperre als `SKCD:<rest>`-Payload an neue Gruppenmitglieder; der Empfaenger uebernimmt die Restzeit per Max-Merge (verlaengern ja, verkuerzen nie) und klemmt sie auf das lokale 30s-Fenster. Gespiegelt wird ausschliesslich eine lokal entstandene Sperre (eigener wirksamer Klick oder empfangenes `SHAREKEYS`); eine Sperre, die selbst durch einen empfangenen `SKCD`-Mirror gesetzt oder verlaengert wurde, verliert die lokale Ownership und darf nicht erneut gebroadcastet werden, damit der Cooldown nicht endlos zwischen den Clients reflektiert. Die Button-Sperre wirkt zusaetzlich als gemeinsames Ruhefenster fuer den Antwortpfad: solange sie laeuft, wird auf eingehende `SHAREKEYS` kein eigener Key erneut in den Chat gepostet (der eigene Klick schreibt den Antwort-Zeitstempel nicht, die Button-Sperre schliesst diese Luecke).
- Erforderliche Tests:
  - Roster panel share keys button debounces rapid clicks
  - Roster panel share keys button dispatches SHAREKEYS before party chat
  - Roster panel share keys button drives full sender receiver chat chain
  - Roster panel share keys button does not treat the local print fallback as a successful party share
  - Roster panel share keys button ignores no-op clicks without chat or sync success
  - Roster panel share keys button locks on remote SHAREKEYS signal
  - Roster panel share keys cooldown text survives localization and layout refresh
  - Roster panel share keys button mirrors a partial remote cooldown with max-merge
  - Roster panel share keys button reports only locally owned locks for SKCD mirroring
  - ControllerWiring sendShareKeysCooldownState mirrors only the locally owned cooldown
  - Share keys SKCD reflection dies after one hop across real wiring and buttons
  - Share keys cooldown mirror drives full sender receiver SKCD chain
  - Sync SendShareKeysRequest returns false without an addon sync channel
  - Sync SendShareKeysRequest returns false when addon message dispatch fails
  - Sync SendShareKeysCooldown publishes SKCD with ceiled and clamped remain
  - Sync SendShareKeysCooldown returns false for invalid remain or missing channel
  - Sync routes send through ChatThrottleLib with correct priority per message type
  - Sync ProcessAddonMessage handles SHAREKEYS payloads
  - Sync ProcessAddonMessage handles SHAREKEYS from UTF-8 sender names
  - Sync ProcessAddonMessage suppresses SHAREKEYS self-echo for UTF-8 names
  - Sync ProcessAddonMessage mirrors SKCD payloads with clamping
  - Sync ProcessAddonMessage suppresses SKCD self-echo
  - ControllerWiring sendOwnKeystoneToChat uses ContextHelpers loaded after wiring
  - ControllerWiring SHAREKEYS send and receive paths use the same real payload
  - sendOwnKeystoneToChat aborts while the share-keys button cooldown is active
  - sendOwnKeystoneToChat proceeds when the share-keys button cooldown is idle
  - Event handlers answer SHAREKEYS requests while frame is hidden
  - Event handlers process SHAREKEYS through the real sync parser and trigger cooldown
  - Event handlers trigger SHAREKEYS cooldown even when no own key chat share was posted
  - CHAT_MSG_ADDON mirrors a peer SKCD lock via triggerShareKeysCooldown
  - CHAT_MSG_ADDON ignores invalid SKCD remain values
  - CHAT_MSG_ADDON hello-ack fan-out includes the share-keys cooldown state
  - CHAT_MSG_ADDON reqsync fan-out includes the share-keys cooldown state

### RULE-NO-GUESS-LAUFZEITAUFLOESUNG
- Regelnummer: 54
- Status: aktiv
- Zusammenfassung: Wenn fuer eine Runtime-Aufloesung keine eindeutige, belastbare Quelle vorliegt, muss das Ergebnis unresolved bleiben. Fehlende oder mehrdeutige Laufzeitdaten duerfen nicht durch spekulative Fallbacks, Namens-/Token-Raten, heuristische Standardwerte oder synthetische Cooldown-/Map-Zustaende ersetzt werden. Eindeutige Aufloesungen duerfen nur aus beobachteten Live-Daten, explizit persistierten verifizierten Daten oder eindeutig bestimmten Runtime-Zusammenhaengen entstehen. Opaque Blizzard-Keystone-Markup darf nur dann als Target-Level-Text weitergegeben werden, wenn es exakt dem verifizierten `|Kk<number>|k`-Format entspricht; freier Titeltext ohne eindeutig geparstes `+N` bleibt unresolved. Ein eindeutig geparstes `+N` im LFG-Gruppentitel gilt als belastbare Listing-Quelle fuer die Keystufe.
- Erforderliche Tests:
  - Factory target dungeon stays unresolved without queue or joined-key map context
  - Factory target dungeon resolves from synced exact target context
  - Factory target dungeon stays unresolved on conflicting synced exact targets
  - Teleport does not resolve by dungeon name without activityID
  - Teleport keeps activity unresolved when mapID is missing and retries unresolved lookups
  - Teleport short-code resolver keeps unknown maps unresolved instead of showing map ids
  - LFGDetect keeps unknown invite activity unresolved instead of guessing from dungeon name
  - LFGDetect keeps conflicting invite activity maps unresolved
  - LFGDetect keeps partially unresolved invite activity maps unresolved
  - LFGDetect active listing stays unresolved when only dungeon name text is available
  - LFGDetect exact invite stays pending until inviteaccepted and then highlights without sound
  - LFGDetect inviteaccepted refreshes incomplete invited listing before direct-push
  - LFGDetect direct-push carries exact Blizzard keystone level markup
  - LFGDetect ResolveEntryTitleLevel recovers level from groupName when titleLevel is nil
  - LFGDetect ParseTitleKeyLevel resolves 'N+' trailing-plus form via OnInvited title
  - LFGDetect ParseTitleKeyLevel picks the highest level when multiple +N tags appear
  - factory_controllers.status: GetStatusTargetDungeonInfo carries LFG level markup when numeric level is unresolved
  - factory_controllers.status: SendOwnTargetSnapshot carries LFG level markup when numeric level is unresolved
  - UI third game-menu addon shortcut fails closed without a registered slash alias
  - Settings hearthstone selector shows English toy names for non-German addon locales
  - Settings hearthstone selector uses client-localized toy names for German addon locale
  - Sync RegisterVerifiedAlias exposes exact sender data through a verified roster name
  - Sync RegisterVerifiedAlias rejects cross-realm and unknown sender aliases
  - KeySync RegisterVerifiedSyncAliasForRoster maps one same-realm sender to one roster row
  - KeySync RegisterVerifiedSyncAliasForRoster fails closed for ambiguous same-realm candidates
  - SpellUtils.GetTeleportCooldownRemaining normalizes wrapped portal cooldown start times
  - TeleportUI applies visible cooldown frame from normalized remaining time
  - factory_controllers: RenderAcceptedInviteNotice uses verified mapID when activityID is missing
  - AcceptedInviteNotice does not replay after challenge start
  - AcceptedInviteNotice does not replay via GROUP_ROSTER_UPDATE recovery after ClearAllState
  - LI.BuildSearchResultMemberBonuses resolves German Verstärkung only for Evoker
  - LI.BuildApplicantBonusBadge treats Devotion Aura and Atrophic Poison as utility
  - LI.BuildSearchResultBonusBadge accepts tuple spec IDs only for their matching class
  - LI.BuildSearchResultBonusBadge counts relevant non-utility bonuses as markers
  - LI.BuildSearchResultBonusBadge counts each non-stacking bonus only once
  - LI.UpdateButton renders search-result bonus markers as one right-aligned stack below the badge area
  - LI.ApplyApplicantBonusToMemberFrame writes applicant bonus markers next to the class badge and clears them
  - LI.BuildApplicantBonusMarkerBadge ignores applicant utility bonuses

### RULE-MAIN-UI-POSITION-LOCK
- Regelnummer: 55
- Status: aktiv
- Zusammenfassung: Die Main-UI kann ueber `lockMainFramePosition` oder die Slash-Commands `/isilive lock`, `/isilive unlock` und `/isilive resetui` gesperrt, entsperrt oder wieder auf die Bildschirmmitte zentriert werden; `resetui` setzt zusaetzlich die UI-Skalierung und die Hintergrund-Deckkraft auf ihre Default-Werte zurueck, zeigt den Default-Hinweis als separate Textzeile unter dem Button und fragt die Aktion vor dem Reset noch einmal bestaetigend ab. Bei aktivem Lock duerfen Frame und Drag-Handle keinen Positions-Drag starten und die gespeicherte Position bleibt unveraendert.
- Erforderliche Tests:
  - Settings panel defaults main frame position lock to enabled and persists unlocks
  - UI main frame drag lock blocks accidental movement until unlocked
  - UI main frame lock button toggles the drag lock state
  - Commands lock and unlock update main frame lock state
  - Commands resetui restores main frame defaults

### RULE-RUNTIME-LOG-TRACE-DIAGNOSE
- Regelnummer: 56
- Status: aktiv
- Zusammenfassung: Runtime-Log-Eintraege werden nur bei aktivem Runtime-Logging geschrieben; jeder Eintrag traegt eine stabile Sequenznummer und einen praezisen Zeitstempel, `[TAG] action`-Nachrichten werden zu `[TAG] event=action` normalisiert, teure Formatierung und Trace-Builder duerfen bei ausgeschaltetem Log oder deaktivierter Deep-Stufe nicht laufen, und der Logspeicher muss seine Tail-Reihenfolge und sein Cap auch bei grossen Log-, Sync- und Roster-Bursts behalten.
- Erforderliche Tests:
  - Runtime log controller appends entries only when enabled
  - Runtime log controller prefixes entries with sequence and timestamp
  - Runtime log controller normalizes tag action messages to event field
  - Runtime log controller uses precise GetTime timestamp by default
  - Runtime log controller formats lazily only when enabled
  - Runtime log controller trace builder runs only when enabled
  - Runtime log controller writes session header only when enabling
  - Runtime log controller filters deep trace unless deep level is enabled
  - Runtime log controller preserves tail order across ring overwrite
  - Runtime log controller keeps cap and tail stable across 2000 entry burst
  - Sync runtime logger keeps capped trace across 2000 message burst
  - Sync runtime trace logger passes a lazy builder to runtime logging
  - LFGDetect runtime trace logger passes a lazy builder to runtime logging
  - Group roster runtime logger stays capped across 2000 roster burst
  - Event handlers write ready check trace entries when runtime logging is available

### RULE-TESTMODE-DEMO-MODULE-VOLLSTAENDIG
- Regelnummer: 57
- Status: aktiv
- Zusammenfassung: Der Ingame-Testmodus muss beim Aktivieren die Demo-Daten fuer M+-Timer, Combat-CDs, den unteren M+-Forces-Tracker, Statsbox, Portal-Navigator, Centerbox-Portal, Non-Mythic-Dungeon-Entry-Centerbox, M+-Forces-Nameplates/-Tooltip, LFG-Bonusmarker, Ready-Check-Hold-Zeilen, Share-Keys-Cooldown, Death-Alert-Preview, Sound-/TTS-Preview und das verschiebbare Demo-Simulations-Tablet setzen, beim Deaktivieren wieder loeschen und im Dummy-Roster Multi-Kick-Extras fuer den Tooltip-Preview bereitstellen. Das Tablet muss auch ueber `/isilive sim` umschaltbar sein, darf nur lokale Vorschau-Hooks ausfuehren, muss nicht mehr vorhandene oder regelblockierte Pre-Accept-Invite-Simulationen sichtbar rot blockieren und darf keine echten Chatposts oder Gruppenaktionen senden. Demo-Feature-Schalter duerfen nur temporaer fuer die Vorschau gesetzt werden und muessen die vorherigen User-Settings danach wiederherstellen. Die Nameplate-Demo darf die Nutzer-Settings fuer Prozentformat, Position, Schriftgroesse und Offsets nicht ueberschreiben. Wenn die Centerbox einen verifizierten mapID-Kontext und einen Activity-Kontext erhaelt, muss der Portalbutton den mapID-Kontext priorisieren. Die Centerbox-Portal- und Non-Mythic-Dungeon-Entry-Demos muessen im Demomodus parallel sichtbar sein und duerfen sich nicht gegenseitig verdraengen.
- Erforderliche Tests:
  - Factory test mode populates timer, cooldown and kill-track demo data
  - Factory demo simulation tablet builds safe actions and runs preview hooks
  - Simulation tablet renders actions and runs only executable buttons
  - Simulation tablet toggles, hides stale buttons, and handles tooltip paths
  - Commands sim toggles the simulation tablet
  - Factory test mode shows portal navigator demo with matching header texts
  - MobNameplate.SetTestMode can render remaining percent from explicit demo map context
  - Factory test mode does not resize the stats box font setting
  - Factory test mode temporarily enables notice demo settings
  - Demo dummy roster exposes multi-kick extras for tooltip preview
  - StatsBox uses explicit demo rows only while demo data is set
  - Center notice teleport button resolves directly from verified mapID
  - Center notice teleport button prioritizes verified mapID over unresolved activityID
  - factory_frame_bridge: Initialize forwards map teleport resolver to center notice

### RULE-MPLUS-TIMER-PEW-RESET
- Regelnummer: 58
- Status: aktiv
- Zusammenfassung: `CHALLENGE_MODE_COMPLETED` und `CHALLENGE_MODE_RESET` muessen den M+-Timer-Snapshot sofort vollstaendig wegraeumen (`completed=false`, `timer=0`, `timeLimit=0`, `keyLevel=0`, `deaths=0`) und die CD-Tracker-Zeile neu rendern, damit die Timer-Box nach abgeschlossenem oder abgebrochenem Key nicht mit veralteten Werten stehen bleibt. `PLAYER_ENTERING_WORLD` waehrend eines aktiv laufenden Keys (`running=true`) darf den Timer nicht stoppen und keine Zeitstaende zuruecksetzen; ein spaeteres `PLAYER_ENTERING_WORLD` nach bereits geloeschtem Snapshot bleibt wirkungslos.
- Erforderliche Tests:
  - mplus_timer: CHALLENGE_MODE_COMPLETED wipes timer, deaths, and time limits
  - mplus_timer: PLAYER_ENTERING_WORLD stays cleared after completed key reset
  - mplus_timer: PLAYER_ENTERING_WORLD is a no-op while the key is still running
  - mplus_timer: PLAYER_ENTERING_WORLD before any key is a no-op
  - mplus_timer: CHALLENGE_MODE_RESET wipes timer, deaths, and time limits
  - Event handlers refresh CD tracker on challenge completion and reset

### RULE-MPLUS-KILLTRACKER-PREKEY-ZIEL
- Regelnummer: 59
- Status: aktiv
- Zusammenfassung: Der untere M+-Killtracker darf vor Key-Start einen verifizierten Dungeon rechtsbuendig anzeigen, sobald die Target-Dungeon-Aufloesung einen konkreten Namen liefert; die Keystufe darf nur als farbiger Zusatz erscheinen, wenn sie positiv verifiziert als ganze Zahl vorliegt. Rohe Titel-Strings des Gruppen-Erstellers oder unverarbeitetes Blizzard-Keystone-Markup duerfen nicht in das Keystufe-Feld geschrieben werden. Sobald der Key gestartet ist, darf diese Vor-Key-Anzeige nicht mehr sichtbar bleiben; danach gilt wieder die Prozentanzeige des Killtrackers beziehungsweise deren Platzhalter, bis aktive Prozentdaten vorliegen. Bei aktiven Prozentdaten darf der verifizierte Dungeonname linksbuendig auf dem Prozentbalken sichtbar bleiben (Outline-Schrift, hell, mit dunklem Hinterlegungslabel fuer stabilen Kontrast); die aktive Keystufe darf dort nur angehaengt werden, wenn sie positiv aus dem gestarteten M+-Timer-Keylevel stammt, nicht aus der Target-Dungeon-Aufloesung.
- Erforderliche Tests:
  - UpdateKillTrackRow renders verified target key as right-aligned combined text before challenge start
  - UpdateKillTrackRow renders literal pipe characters in verified pre-key dungeon names
  - UpdateKillTrackRow renders verified pre-key dungeon when level is unresolved
  - UpdateKillTrackRow drops raw level text when no numeric level resolves
  - factory_controllers.status: GetStatusTargetDungeonInfo carries LFG level markup when numeric level is unresolved
  - factory_controllers: direct-push persists accepted target for killtracker refresh
  - UpdateKillTrackRow suppresses target key after challenge start until percent data is active
  - UpdateKillTrackRow restores percent bar after pre-key target display
  - CreateKillTrackRow anchors active dungeon text to the full row overlay
  - UpdateKillTrackRow keeps dungeon context visible while active percent data is visible
  - UpdateKillTrackRow omits active key level when MplusTimer has no started level

### RULE-MPLUS-KILLTRACKER-LIVE-FORCES-REFRESH
- Regelnummer: 60
- Status: aktiv
- Zusammenfassung: Der M+-Killtracker muss nach `PLAYER_REGEN_ENABLED` die Live-Scenario-Daten erneut lesen, den sichtbaren Gesamtfortschritt sofort aktualisieren und die aktualisierte Rohmenge als Basis fuer den naechsten Pull verwenden. Solange der Key aktiv ist, muss auch der Killtracker-Refresh-Ticker Live-Scenario-Daten neu lesen, bevor er die UI benachrichtigt.
- Erforderliche Tests:
  - PLAYER_REGEN_ENABLED refreshes live forces before the next pull starts
  - refresh ticker callback reads live forces and notifies subscribers while state is active
  - Architecture combat utility ticker rerenders UI while Mythic+ timer is active

### RULE-LFG-INVITE-LISTE-KEIN-GUESSING
- Regelnummer: 61
- Status: aktiv
- Zusammenfassung: Die verworfene LFG-Invite-Liste bleibt entfernt. Es gibt kein Invite-Listen-Modul, keinen TOC-Eintrag, kein Settings-Control, kein SavedVariable-Feld und kein Runtime-Wiring. `LFG_LIST_APPLICATION_STATUS_UPDATED` darf keine Invite-Listenverarbeitung ausloesen; die bestehende LFGDetect-/Queue-Verarbeitung fuer sichtbare, positive Status-Events bleibt davon unberuehrt.
- Erforderliche Tests:
  - DBSchema.Sanitize fills all defaults on an empty db
  - DBSchema.GetKnownFieldNames includes core persistent fields
  - Settings panel keeps the removed LFG invite list out of the UI
  - Architecture removed LFG invite list modules stay absent from TOC and harness
  - ConfigBuilders hidden gate keeps LFG status blocked
  - APPLICATION_STATUS_UPDATED does not forward removed invite-list handling

### RULE-RURU-KYRILLISCHER-UI-FONT
- Regelnummer: 62
- Status: aktiv
- Zusammenfassung: Bei aktivierter Addon-Sprache `ruRU` muessen lokalisierte Hauptfenster-Texte und gefittete Button-Labels einen kyrillisch-faehigen WoW-Font verwenden. Addon-eigene sichtbare FontStrings und private isiLive-Tooltips, die lokalisierte Strings, Blizzard-API-Daten, Spieler-/Realmnamen, Dungeon-/Mapnamen oder andere konkrete UI-Payload-Strings mit kyrillischen UTF-8-Zeichen rendern, muessen vor dem Schreiben des Textes auf einen kyrillisch-faehigen Font wechseln, damit russische Strings auch auf nicht-russischen Clients nicht als Platzhalterkaestchen gerendert werden. Blizzard-eigene Fenster werden von dieser Regel nicht umgebaut. Nicht ueberschriebene Locales und nicht-kyrillische Payload-Texte duerfen ihren bestehenden Font unveraendert behalten beziehungsweise nach einem vorherigen kyrillischen Payload wiederherstellen.
- Erforderliche Tests:
  - UICommon.ApplyLocaleFont uses Cyrillic-capable font for ruRU addon locale
  - UICommon.ApplyLocaleFont leaves non-overridden locales unchanged
  - UICommon.ApplyReadableFontForText uses Cyrillic-capable font for Cyrillic payload text
  - UICommon.ApplyReadableFontForText restores the baseline font after Cyrillic payload text clears
  - UICommon.SetReadableText applies Cyrillic-capable font before writing Cyrillic text
  - UICommon private tooltip lines use Cyrillic-capable font for Cyrillic payload text
  - Center notice rich field values use Cyrillic-capable font for Cyrillic leader names
  - Roster render uses Cyrillic-capable font for Cyrillic player names
  - UpdateKillTrackRow uses Cyrillic-capable font for verified Cyrillic dungeon names
  - RosterLayout SetFlatButtonText uses ruRU font override before fitting Cyrillic labels
  - RosterLayout SetPanelHeaderText fits ruRU headers to fixed roster columns

### RULE-MPLUS-MARKER-SECURE-WORLDMARKER
- Regelnummer: 63
- Status: aktiv
- Zusammenfassung: Die M+Marker-Leiste muss ihre Buttons als `SecureActionButtonTemplate` mit nativen Worldmarker-Attributen konfigurieren: `type="worldmarker"` und `marker=<id>` muessen auf dem Button selbst gesetzt sein, `action1="set"` setzt per Linksklick und `action2="clear"` loescht per Rechtsklick. Die sicheren Klickflaechen muessen per Frame-Level ueber konkurrierenden UI-Sibling-Frames liegen. Die Runtime darf dafuer keine geschuetzten Marker-APIs direkt aufrufen.
- Erforderliche Tests:
  - M+Marker buttons use native world-marker secure attributes
  - TAINT: M+Marker buttons stay secure world-marker buttons and touch no protected globals

### RULE-RELOAD-ROSTER-MIRROR-SIGNATUR
- Regelnummer: 64
- Status: aktiv
- Zusammenfassung: Der Reload-Roster-Mirror darf verifizierte Gruppenanzeigedaten nach `/reload` nur dann in den Runtime-Roster vorbefuellen, wenn die aktuelle Gruppensignatur aus den konkret lesbaren `player`/`partyN`-Mitgliedern exakt der gespeicherten Signatur entspricht. Der verifizierte aktuelle Gruppen-Ziel-Key mit Dungeon-mapID, Dungeonname und optionaler positiver numerischer Keystufe oder exaktem Leveltext darf nur mit derselben Signatur gespeichert und wiederhergestellt werden. Bei fehlender, unvollstaendiger oder abweichender Signatur muss der gespeicherte Mirror verworfen werden. Ein erfolgreicher Mirror-Restore einer bestehenden Gruppe darf keine Queue-Capture-, Queue-Announce-, Auto-Open- oder Group-Join-Notice-Sideeffects ausloesen. Kick-Zustaende duerfen nicht aus dem Reload-Roster-Mirror wiederhergestellt werden. Nach einer erfolgreichen Vorbefuellung muss der normale Live-Sync-Refresh weiter angefordert werden.
- Erforderliche Tests:
  - Reload roster mirror restores verified data when group signature matches
  - Reload roster mirror restores verified target key when group signature matches
  - Reload roster mirror suppresses group-join side effects outside active key
  - Reload roster mirror is discarded when group signature differs
  - factory_controllers.status: reload roster target snapshot restores target level before roster owner
  - DBSchema.Sanitize gives each db an isolated reload roster mirror

### RULE-STATS-BOX-LIVE-QUELLE
- Regelnummer: 65
- Status: aktiv
- Zusammenfassung: Die eigenstaendige Spieler-Stats-Box darf Attribute, Combat-Ratings und Prozentwerte ausserhalb des expliziten Ingame-Demomodus nur anzeigen, wenn der jeweilige Wert direkt aus einer erfolgreichen Blizzard-Live-API-Lesung stammt; fehlende API-Werte bleiben unsichtbar und werden nicht durch Default-, Cache- oder Guess-Werte ersetzt. Der Ingame-Demomodus darf ausdruecklich markierte Demo-Zeilen anzeigen, muss diese beim Verlassen wieder entfernen und danach zur Live-API-Sammlung zurueckkehren. Als Secret Value markierte API-Werte duerfen fuer die Anzeige nur direkt per `string.format` in Text gewandelt werden; Lua-Arithmetik, `tonumber` oder Vergleiche auf diesen Secret Values sind verboten. Bei Klassen mit eindeutigem Primärstat wird dieser ueber den live gelesenen Klassentoken bestimmt; bei Hybridklassen wird der Primärstat nur bei exakt gelesener Spezialisierungs-ID angezeigt. Sichtbare Stat-Labels sind feste englische Kurzlabels ohne Locale-Varianten. Leech, Speed, Haltbarkeit, Ausdauer und Vermeidung sind einzeln per Settings abschaltbar; Leech und Speed sind standardmaessig aktiv, Haltbarkeit, Ausdauer und Vermeidung sind standardmaessig deaktiviert. Abgeschaltete optionale Zeilen duerfen keine zugehoerigen Live-APIs lesen und bleiben unsichtbar. Der Anzeige-Modus `both` zeigt Werte und Prozente, `value` zeigt nur Werte, und `percent` zeigt nur Prozente; im Prozent-Modus muessen Zeilen ohne direkt gelesenen Prozentwert unsichtbar bleiben, statt einen Prozentwert zu raten. Stat-Labels, Werte und Prozentwerte stehen rechtsbuendig, sichtbare Stats nutzen eine feste Blizzard-like Farbpalette, sichtbare Zeilen nutzen eine dezente Hintergrundtoenung aus derselben festen Palette, Primärstat-Zeilen nutzen dabei eine staerkere Toennung als Sekundaerzeilen, und eine dezente Trennlinie darf Werte und Prozente optisch separieren. Entsperrte Stats-Boxen duerfen auf Hover ihre Hintergrunddeckkraft bis zu einer niedrigen Mindestdeckkraft anheben, die Box darf keine Titelzeile rendern, alle sichtbaren Texte nutzen einen kontrastreichen dunklen Schatten ohne Outline, und die Werte-Spalte darf bei drei- und vierstelligen Zahlen nicht unter ihre kompakte Mindestbreite schrumpfen, damit die Prozent-Spalte nicht zeilenweise verschoben wird. Die Prozent-Spalte darf nicht unter ihre kompakte Mindestbreite fuer `(999.99%)` schrumpfen, damit Prozentwerte ueber `100.00%` keinen Zeilenumbruch erzeugen. Die Box ist rahmenlos, standardmaessig aus, nur bei `statsBoxEnabled=true` sichtbar, ueber `statsBoxLocked` gegen Positions-Drag sperrbar, ihre Hintergrund-Deckkraft ist ueber `statsBoxBgAlpha` separat steuerbar, ihre Schriftgroesse und Box-Geometrie sind ueber `statsBoxFontSizeOffset` von `-3` bis `+3` relativ zum Default `0` gemeinsam steuerbar, ihr Hintergrund passt sich an die tatsaechlich gerenderten sichtbaren Textgrenzen an, als Secret Value maskierte FontString-Breitenmessungen duerfen nicht ausgewertet werden und nutzen stattdessen die letzte verifizierte Messung oder kompakte feste Spaltenbreiten, und ihre gespeicherte Position liegt in `statsBoxPosition` ohne die Main-UI-Position zu veraendern.
- Erforderliche Tests:
  - StatsBox renders class primary stat and directly observed secondary values
  - StatsBox resolves hybrid primary stat only from exact specialization
  - StatsBox uses fixed English short labels without locale variants
  - StatsBox restores and saves its own position independently
  - StatsBox lock blocks dragging without changing its saved position
  - Settings panel exposes stats box position lock toggle
  - StatsBox applies enabled toggle and background opacity without a border
  - StatsBox renders subtle row tint backgrounds without a border
  - StatsBox renders separator primary highlight and unlocked hover affordance
  - StatsBox applies font size offset from settings
  - StatsBox applies high contrast text shadow
  - StatsBox renders labels and values right-aligned
  - StatsBox keeps value column stable for four-digit stats
  - StatsBox keeps percent column stable for 999.99 percent
  - StatsBox fits background to rendered text bounds
  - StatsBox ignores secret text width measurements
  - StatsBox reads haste percent from player spell haste
  - StatsBox renders stamina durability and avoidance from direct APIs
  - StatsBox optional row toggles suppress configured rows
  - StatsBox optional row defaults show leech and speed only
  - StatsBox display mode renders values only or percentages only
  - Settings panel exposes stats box detail checkboxes and display mode
  - StatsBox applies Blizzard-like fixed stat colors
  - StatsBox formats secret API values without arithmetic
  - StatsBox uses explicit demo rows only while demo data is set

### RULE-MOVABLE-UI-SCREEN-CLAMP
- Regelnummer: 66
- Status: aktiv
- Zusammenfassung: Alle frei verschiebbaren isiLive-Fenster muessen per Screen-Clamp an den WoW-Sichtbereich gebunden sein; beim Ziehen duerfen die Fensterraender nicht ausserhalb des WoW-Fensters verschwinden. Dies gilt fuer Main-UI, Stats-Box, Center-Notice und Portal-Navigator; der Minimap-Button bleibt an seine eigene Minimap-Kreis-Draglogik gebunden.
- Erforderliche Tests:
  - UI main frame is clamped to the WoW screen while movable
  - StatsBox clamps its movable frame to the screen
  - Notice movable frames are clamped to the WoW screen

### RULE-ESC-ADDON-PANEL-NUR-AKTIVIERTE-ADDONS
- Regelnummer: 67
- Status: aktiv
- Zusammenfassung: Das ESC-Addons-Panel darf einen Shortcut-Button anzeigen, wenn das Ziel-Addon installiert und auf dem aktuellen Charakter aktiviert ist. Eine globale Enable-State-Rueckgabe `Some` reicht ohne konkrete aktuelle Charakterzuordnung nicht als aktivierter Zustand. Ist ein externes Ziel-Addon beim Klick noch nicht geladen, muss der Klickpfad das Addon verifiziert laden und erst danach dessen registrierten Slash-Alias ausfuehren. Der externe Slash-Dispatch darf erst laufen, nachdem `GameMenuFrame` als geschlossen beobachtet wurde, und muss den registrierten `SlashCmdList`-Handler in Blizzard-kompatibler Form mit Argumentstring und Standard-Chat-EditBox aufrufen. Wenn der registrierte Slash-Alias unmittelbar nach einem verifiziert geladenen Ziel-Addon noch fehlt, darf der Klickpfad eine kurze begrenzte Retry-Kette nur fuer denselben exakten Slash-Alias starten. Wenn das Laden fehlschlaegt, nach den begrenzten Retries kein registrierter Slash-Alias existiert oder ein registrierter Handler fehlschlaegt, bleibt der Klick wirkungslos. Der isiLive-eigene Shortcut darf stattdessen direkt die isiLive-Settings oeffnen und darf keinen Self-Load versuchen.
- Erforderliche Tests:
  - UI third game-menu addon panel shows installed and enabled addon shortcuts
  - UI third game-menu addon shortcut loads enabled addon before running slash
  - UI third game-menu addon shortcut uses current-character enable state
  - UI third game-menu addon shortcut accepts character-scoped enabled state
  - UI third game-menu addon panel hides addons enabled only on another character
  - UI third game-menu isiLive shortcut can use direct settings action without self-load
  - UI third game-menu addon shortcuts resolve registered slash aliases and arguments
  - UI third game-menu addon shortcut repeatedly invokes the verified slash handler
  - UI third game-menu addon shortcut retries briefly when loaded addon registers slash late
  - UI third game-menu addon shortcut retry path is shared by supported external addons
  - UI third game-menu addon shortcut waits until the game menu is closed before slash dispatch
  - UI third game-menu addon close-before-slash path is shared by supported external addons
  - UI third game-menu addon shortcut passes the default chat edit box to slash handlers
  - UI third game-menu addon shortcut does not fall back to chat edit when handler fails
  - Commands settings opens the settings panel
  - UI third game-menu addon panel stays hidden when no supported addon is enabled

### RULE-LFG-KLASSENBONUS-HERZCHEN-NICHT-STAPELND
- Regelnummer: 68
- Status: aktiv
- Zusammenfassung: Die LFG-Klassenbonus-Herzchen duerfen nur relevante nicht-Utility-Gruppenboni zaehlen, die fuer den eingeloggten Spieler wirksam sind. Gleiche nicht stapelnde Buffs zaehlen pro Suchergebnis nur einmal, auch wenn mehrere Gruppenmitglieder denselben Buff liefern. Utility-Effekte wie PI, BL, BR, Devotion Aura und Atrophic Poison duerfen in Tooltips sichtbar bleiben, erzeugen aber keine Herzchen. Applicant-Zeilen muessen relevante Herzchen als grüne Texturmarker direkt rechts neben dem Klassenbadge rendern und dafuer echte Texturen aus der Datei `Interface\AddOns\isiLive\media\heart_bonus_green.tga` verwenden; der WoW-API-Pfad darf extensionless `Interface\AddOns\isiLive\media\heart_bonus_green` sein, aber FontString-Markup oder Font-Glyphen sind fuer Applicant-Zeilen verboten. Roster-Zeilen muessen dieselben relevanten grünen Bonus-Herzchen direkt am Spielernamen rendern, wenn die Roster-Klasse aus einem verifizierten Klassen-Token oder Blizzard-Klassennamen aufgeloest wurde; eine Spec-ID darf nur beruecksichtigt werden, wenn sie zur verifizierten Klasse passt. Applicant-Zeilen duerfen Sprachflaggen nur anzeigen, wenn die Sprache aus dem konkreten Bewerber-Realm oder dem lokalen Realm verifiziert aufgeloest wurde; beim Ausblenden oder bei wiederverwendeten Blizzard-Bewerberzeilen muss der urspruengliche Namensanker wiederhergestellt werden. Der Settings-Schalter fuer die Buff-Rating-Herzchen ist standardmaessig aktiv, kann die Anzeige ein- und ausschalten und muss lokalisiert mit untereinander stehenden fix grossen Herz-Textur-Beispielzeilen erklaeren, dass 1/2/3/4 Herzchen einen, zwei, drei beziehungsweise vier oder mehr relevante Buffs bedeuten. Beim Programmieren werden Deutsch und Englisch gepflegt; weitere vorbereitete Locales duerfen bis zur Nachbearbeitung englischen Fallback verwenden oder nachbearbeitete Uebersetzungen tragen. Jede Locale-Beschreibung muss die Datei `media/heart_bonus_green.tga` als Textur verwenden und darf keine instabilen Font-Herz-Glyphen verwenden.
- Erforderliche Tests:
  - LI.BuildApplicantBonusBadge treats Devotion Aura and Atrophic Poison as utility
  - LI.BuildSearchResultBonusBadge counts relevant non-utility bonuses as markers
  - LI.BuildSearchResultBonusBadge counts each non-stacking bonus only once
  - LI.ApplyApplicantBonusToMemberFrame writes applicant bonus markers next to the class badge and clears them
  - LI.HookApplicantButton applies bonus markers to visible applicant member frames
  - LI.ApplyApplicantBonusToMemberFrame anchors applicant markers to the visible name when no class icon exists
  - LI.ApplyApplicantBonusToMemberFrame resolves localized applicant class names through Blizzard tables
  - LI.ApplyApplicantBonusToMemberFrame creates applicant marker textures on parent when member cannot
  - LI.ApplyApplicantFlagToMemberFrame renders applicant language flag beside the name
  - LI.ApplyApplicantFlagToMemberFrame creates applicant flag texture on parent when member cannot
  - LI.BuildApplicantBonusMarkerBadge ignores applicant utility bonuses
  - Roster render appends green bonus-heart marker for relevant roster class buffs
  - Roster render hides green bonus-heart marker when group-bonus setting is disabled
  - Settings LFG group-bonus checkbox persists and invokes live toggle callback
  - Settings display checkboxes render descriptions below options and refresh localized text
  - Locale LFG group-bonus settings strings support prepared fallbacks and post-edited translations

### RULE-LFG-GRUPPENBEITRITT-CENTERBOX-VERIFIZIERT
- Regelnummer: 69
- Status: aktiv
- Zusammenfassung: Nach einem LFG-Gruppenbeitritt darf die Accepted-Invite-Fallback-Centerbox mit Portalbutton auch dann erscheinen, wenn kein `LFG_LIST_APPLICATION_STATUS_UPDATED=inviteaccepted` beim Accepted-Invite-Pfad angekommen ist, aber bereits ein verifizierter lokaler Ziel-Dungeon-Kontext (`ResolveLocalStatusTargetMapID` plus Status-Dungeon-Info) vorliegt und `groupJoinNoticeEnabled` nicht deaktiviert ist. Die Fallback-Centerbox darf keinen Dungeon, keine Keystufe, keinen Gruppentitel und keinen Portalbutton raten; eine Keystufe darf nur aus `Status-Dungeon-Info` oder aus einem konkret verifizierten `+N` im LFG-Gruppentitel der angenommenen Gruppe uebernommen werden. Ohne verifizierte lokale Ziel-Map, bei deaktiviertem Gruppenbeitritts-Zielhinweis oder bei einem erfolgreichen Reload-Roster-Mirror-Restore einer bereits bestehenden Gruppe bleibt sie stumm. `acceptedInviteNoticeEnabled` darf diesen Fallback nicht deaktivieren, weil direkte Accepted-Invite-Notice und Gruppenbeitritts-Zielhinweis getrennte Settings sind. Wenn die direkte Accepted-Invite-Centerbox bereits aus dem `inviteaccepted`-Pfad gerendert wurde, darf der Gruppenbeitritt keine zweite Centerbox fuer denselben Join erzeugen.
- Erforderliche Tests:
  - ControllerWiring CreateGroupControllerFromContext forwards group-joined callback
  - factory_controllers: ShowJoinedTargetNotice renders from verified local target when accept event is missing
  - factory_controllers: ShowJoinedTargetNotice derives notice dungeon level from verified LFG group title
  - factory_controllers: ShowJoinedTargetNotice stays silent without verified local target
  - factory_controllers: ShowJoinedTargetNotice ignores accepted invite notice setting
  - factory_controllers: ShowJoinedTargetNotice respects group join notice setting
  - factory_controllers: ShowJoinedTargetNotice suppresses duplicate after direct accepted notice
  - Reload roster mirror suppresses group-join side effects outside active key

### RULE-NOTICE-TITEL-BRAND-GOLD
- Regelnummer: 70
- Status: aktiv
- Zusammenfassung: Alle Center-Notice- und Portal-Navigator-Ueberschriften, die als Fenstertitel oder Headline gerendert werden, muessen textlich mit `isiLive - ` beginnen und im gemeinsamen warmen Goldton `1, 0.9, 0.45` angezeigt werden. Der Portal-Navigator muss seinen Header optisch an die Rich-Center-Notice-Header angleichen: cyanfarbene Eyebrow-Zeile `Portal - Navigation`, linksbuendige goldene Headline `isiLive - Midnight Season One M+ Navigator` in derselben Headline-Schriftgroesse und blaue Trennlinie unterhalb der vollstaendigen Headline. Der reine Addon-Name `TITLE = "isiLive"` sowie Tooltip- oder Feldtitel sind davon nicht betroffen.
- Erforderliche Tests:
  - Locale center-notice titles use isiLive prefix in every locale
  - Center notice headline titles use shared gold color
  - Portal navigator notice lays out the five portal positions in a crescent

### RULE-BLOODLUST-READY-KLANGHINWEIS
- Regelnummer: 71
- Status: aktiv
- Zusammenfassung: Der Bloodlust-ready-Klanghinweis wird nur waehrend eines laufenden M+-Timers mit aktiver Gruppe und erst abgespielt, nachdem die CD-Tracker-Anzeige zuvor einen aktiven Bloodlust-/Heroism-/Time-Warp-Erschoepfungs-Timer angezeigt hat und ein spaeterer natuerlicher Scan fuer denselben Anzeigezyklus keinen positiven Timer mehr liefert. Ein inaktiver Initialscan darf keinen Ready-Klang ausloesen. Wenn Bloodlust nach dieser ersten Ready-Ansage unbenutzt verfuegbar bleibt und `soundBloodlustReadyReminderEnabled` nicht deaktiviert ist, muss der Klanghinweis nach 60 Sekunden erneut abgespielt werden und danach in weiteren 60-Sekunden-Abstaenden wiederholen, bis ein neuer aktiver Erschoepfungs-Timer angezeigt wird. Wenn `soundBloodlustReadyReminderEnabled` deaktiviert ist, bleibt die erste Bloodlust-ready-Ansage erlaubt, aber der 60-Sekunden-Erinnerungsloop muss stumm bleiben. Ein spaeterer neuer Bloodlust-Zyklus darf wieder eine neue Ready-Ansage mit eigener 60-Sekunden-Erinnerung starten, sofern der Erinnerungsloop nicht deaktiviert ist. Die UI muss waehrend laufendem Key und aktiver Gruppe nach dem Ready-Uebergang `00:00` anzeigen; `BL: --` ist fuer fehlenden BL-Kontext wie kein laufender Key, keine Gruppe oder explizit verworfene Reset-/Key-Ende-Zyklen reserviert. UNIT_AURA-Removal- und Aura-Instance-Update-Payloads muessen einen CD-Scan ausloesen, weil Aura-Entfernungen und Instanz-Updates beim natuerlichen Auslaufen keine belastbare `spellId` mehr liefern muessen. Wenn eine bereits beobachtete Aura im Scan noch vorhanden ist, ihr Timer aber abgelaufen ist, muss der CD-Tracker den angezeigten Nullpunkt als `remain=0` liefern, damit der Factory-Pfad die Ready-Ansage waehrend des Keys ausloesen kann. Refreshes fuer Key-Ende, Key-Abbruch, Dungeon-Verlassen, Gruppen-Verlassen oder sonstige Scans mit nicht laufendem M+-Timer oder fehlender aktiver Gruppe duerfen keinen Ready-Klang und keine 60-Sekunden-Erinnerung ausloesen und muessen den beobachteten Ready-Zyklus verwerfen, weil die Aura dabei nicht als natuerlich ausgelaufen gilt und ein spaeterer Welt-/Zonen-Refresh keine nachtraegliche Ready-Ansage erzeugen darf. Rueckfallstrategie, falls diese Anzeigenstrategie zurueckgebaut werden muss: Der alte Vertrag war aura-event-zentriert und wertete den Uebergang von `lastLustActive == true` zu `lustActive == false` ohne dauerhaften `00:00`-Anzeigezustand aus. Wenn `soundBloodlustReadyEnabled` deaktiviert ist, muss der TTS-Klang stumm bleiben.
- Erforderliche Tests:
  - Factory CD refresh plays Bloodlust-ready sound and repeats while unused every 60 seconds
  - Factory CD refresh respects disabled Bloodlust-ready reminder loop setting
  - Factory CD refresh exposes BL: -- when ready display context is inactive
  - UpdateCdTrackerRow renders BL ready as 00:00 when cooldown reached zero
  - UpdateCdTrackerRow restores default BL icon and renders BL: -- when no BL context exists
  - CdTracker reports zero Lust remain when an observed aura timer expires
  - Event handlers call updateCdTracker on UNIT_AURA aura removals
  - Event handlers call updateCdTracker on UNIT_AURA aura instance updates
  - Factory CD refresh suppresses Bloodlust-ready sound on key reset refresh
  - Factory CD refresh clears Bloodlust-ready cycle when key ends during exhaustion
  - Factory CD refresh stops Bloodlust-ready reminders after key end or dungeon leave
  - Factory CD refresh suppresses Bloodlust-ready reminders after group leave with stale timer
  - factory_frame_bridge: CreateFactoryContext exposes live IsInGroup for ready sound gates
  - Bootstrap gate keeps hidden CD refresh triggers for ready sounds
  - Config builders gate allows CD refresh events while frame is hidden
  - SoundUtils Bloodlust-ready setting disables TTS playback
  - Settings panel exposes sound toggles with the intended defaults

### RULE-BATTLE-RES-READY-KLANGHINWEIS
- Regelnummer: 72
- Status: aktiv
- Zusammenfassung: Der Battle-Res-ready-Klanghinweis wird nur waehrend eines laufenden M+-Timers mit aktiver Gruppe und erst abgespielt, nachdem der CD-Tracker zuvor aus direkt gelesenen Battle-Res-Daten entweder null verfuegbare Aufladungen oder einen positiven angezeigten Cooldown beobachtet hat und ein spaeterer natuerlicher Scan entweder den angezeigten Cooldown bei null sieht oder mindestens eine verfuegbare Aufladung findet. Ein unbekannter Initialscan oder ein bereits verfuegbarer Initialscan darf keinen Ready-Klang ausloesen. Der erste verfuegbare Battle-Res-Zustand direkt nach Key-Start bleibt stumm, damit der Startzustand des Keys keine Ansage erzeugt; danach muss jeder neue Cooldown-zu-null- oder Null-zu-verfuegbar-Zyklus genau einen weiteren Ready-Klang ausloesen. Sichtbare UI-Rescans duerfen die Battle-Res-Anzeige nicht direkt am Factory-Ready-Zustand vorbei aktualisieren; sie muessen ueber denselben CD-Tracker-Transition-Pfad laufen, damit der angezeigte Nullpunkt den Ready-Klang waehrend des Keys ausloesen kann, ohne einen rekursiven Vollrender zu starten. Refreshes fuer Key-Ende, Key-Abbruch, Dungeon-Verlassen, Gruppen-Verlassen oder sonstige Scans mit nicht laufendem M+-Timer oder fehlender aktiver Gruppe duerfen keinen Ready-Klang ausloesen und muessen den beobachteten Ready-Zyklus verwerfen, weil die Aufladung dabei nicht als natuerlich wieder verfuegbar gilt und ein spaeterer Welt-/Zonen-Refresh keine nachtraegliche Ansage erzeugen darf. Wenn `soundBattleResReadyEnabled` deaktiviert ist, muss der TTS-Klang stumm bleiben.
- Erforderliche Tests:
  - Factory CD refresh plays Battle Res-ready sound once when cooldown reaches zero or charges recover
  - Factory CD refresh suppresses the first Battle Res-ready state after key start only
  - Factory visible CD rescan routes Battle Res-ready sound through the displayed timer path
  - Factory CD refresh suppresses Battle Res-ready sound on key reset refresh
  - Factory CD refresh clears Battle Res-ready cycle when key ends during cooldown
  - CdTracker scans later known Battle Res spell when Rebirth charges are unavailable
  - factory_frame_bridge: CreateFactoryContext exposes live IsInGroup for ready sound gates
  - Bootstrap gate keeps hidden CD refresh triggers for ready sounds
  - Config builders gate allows CD refresh events while frame is hidden
  - SoundUtils Battle Res-ready setting disables TTS playback

### RULE-LFG-PREACCEPT-INVITE-HINT-ENTFERNT
- Regelnummer: 73
- Status: aktiv
- Zusammenfassung: Der Pre-Accept-LFG-Invite-Hint ist entfernt. Ein `LFG_LIST_APPLICATION_STATUS_UPDATED`-Status `invited` darf kein oberes isiLive-Einladungsfenster rendern, auch wenn alte Invite-Hint-Callbacks noch gesetzt werden. Die Factory darf die entfernten Pre-Accept-Invite-Hint-Callbacks nicht mehr verdrahten. Es gibt kein Settings-Control `SETTINGS_INVITE_HINT_ENABLED`, kein SavedVariable-Feld `inviteHintEnabled` und keine Ingame-Testmodus-Demo fuer diesen entfernten Hint. Die Accepted-Invite-Centerbox und der Gruppenbeitritts-Zielhinweis bleiben davon unberuehrt.
- Erforderliche Tests:
  - LFGDetect.OnInvited keeps pre-accept invite hint removed
  - LFGDetect.OnInvited ignores removed pre-accept invite hint callbacks
  - Factory LFG wiring does not wire removed pre-accept invite hint callbacks
  - DBSchema.Sanitize does not create removed invite hint default
  - Settings panel keeps removed LFG invite hint out of the UI
  - Factory test mode does not show removed pre-accept invite hint demo

### RULE-SYNC-INSTANCECHAT-LEAVE-FAIL-CLOSED
- Regelnummer: 74
- Status: aktiv
- Zusammenfassung: Queued `INSTANCE_CHAT`-Addon-Sync darf nach dem Verlassen der Instanzgruppe nicht mehr an Blizzard gesendet werden. Der Throttle-Callback muss diesen spaeten Drop als `didSend == false` melden, damit keine lokale Erfolgsannahme aus einem verworfenen Send entsteht.
- Erforderliche Tests:
  - ChatThrottleLib drops queued INSTANCE_CHAT addon messages after instance group leave

### RULE-MPLUS-NAMEPLATE-KOMPATIBLE-VORSCHAU
- Regelnummer: 75
- Status: aktiv
- Zusammenfassung: Die M+-Forces-Namensplakettenanzeige muss nach expliziter Aktivierung unabhaengig davon rendern, ob kein externes Namensplaketten-Addon, Plater oder Platynator geladen ist. Externe Namensplaketten-Addons duerfen hoechstens eine Settings-Warnung ausloesen, aber den Runtime-Renderer nicht deaktivieren. Die Settings-Vorschau muss denselben Text-, Groessen-, Font- und Ankerpfad verwenden wie der Runtime-Renderer, damit Prozentanzeige, Restbedarf, Position, Schriftgroesse und Offsets nicht auseinanderlaufen; die Fake-Namensplatte der Vorschau muss dafuer einen `UnitFrame.healthBar`-Anker bereitstellen und die Prozentanzeige daran ankern. Wenn Plater auf der Namensplatte einen `unitFrame.healthBar` bereitstellt, muss dieser Healthbar-Frame als Runtime-Anker genutzt werden. Wenn Platynator auf der Blizzard-Namensplatte ein sichtbares Display mit `widgets` und einem Health-Widget `details.kind == "health"` bereitstellt, muss dieses sichtbare Health-Widget den Runtime-Anker bilden und vor einem versteckten Blizzard-`UnitFrame.healthBar` Vorrang haben. Das Runtime-Overlay muss die Strata der Namensplatte uebernehmen und darf nicht pauschal auf eine globale Top-Ebene wie `TOOLTIP` erzwingen; eine hoeherliegende Sortierung ist nur ueber das FrameLevel innerhalb derselben Strata erlaubt.
- Erforderliche Tests:
  - MobNameplate font-size pipeline is unaffected by Plater being loaded
  - MobNameplate overlay renders when Platynator is loaded
  - MobNameplate ApplyPosition keeps default offsets clear of the plate edge
  - MobNameplate ApplyPosition anchors to the observed healthbar child when available
  - MobNameplate ApplyPosition anchors to the Plater unitFrame healthBar when available
  - MobNameplate ApplyPosition anchors to the Platynator display health widget when available
  - MobNameplate ApplyPreview uses the runtime text, size and healthbar anchor path
  - Settings nameplate preview uses the shared MobNameplate renderer
  - Settings nameplate preview restores percent text after display mode is re-enabled

### RULE-ROSTER-ROLLE-AUS-INSPECT-SPEZIALISIERUNG
- Regelnummer: 76
- Status: aktiv
- Zusammenfassung: Sobald fuer eine Roster-Zeile eine verifizierte Inspect-Spezialisierung vorliegt, muss die angezeigte und sortierende Roster-Rolle aus Blizzards `GetSpecializationRoleByID` fuer genau diese Inspect-Spezialisierung korrigiert werden. Das gilt insbesondere fuer Spec-Wechsel wie Vergeltung-Paladin zu `DAMAGER` und Blut-Todesritter zu `TANK`, wenn `UnitGroupRolesAssigned` noch einen stale Wert liefert. Ohne verifizierte Inspect-Spezialisierung bleibt die bestehende Rollenquelle unveraendert; es darf keine Ableitung aus Namen, Textheuristiken oder unvollstaendigen Daten erfolgen.
- Erforderliche Tests:
  - Units GetInspectSpecRole resolves role from inspected specialization id
  - Inspect OnInspectReady updates roster role from inspected specialization role

### RULE-PAKETE-CURSEFORGE-WOWUP-GLEICH
- Regelnummer: 77
- Status: aktiv
- Zusammenfassung: CurseForge- und WowUp-Pakete muessen denselben Nutzerinhalt enthalten. Jede Aenderung an Paket-Ausschluessen fuer CurseForge muss im selben Change die GitHub/WowUp-Zip-Ausschlussliste im Stable-`Release`-Workflow gleichwertig aktualisieren, und jede Aenderung an der GitHub/WowUp-Zip-Ausschlussliste muss im selben Change die CurseForge-`.pkgmeta`-Ausschlussliste gleichwertig aktualisieren. Technische Workflow-Metadaten, die nur fuer den Buildprozess gebraucht werden und nicht Teil eines Nutzerpakets sind, duerfen separat behandelt werden, solange der ausgelieferte Addon-Inhalt identisch bleibt.
- Erforderliche Tests:
  - Architecture pkgmeta excludes root screenshot assets from release package
  - Architecture release workflow excludes root screenshot assets from WowUp package
  - Architecture release package ignore lists stay identical for CurseForge and WowUp
  - Architecture gitignore keeps incoming summon Portal sound trackable

### RULE-SOUNDKANAL-WAEHLBAR
- Regelnummer: 78
- Status: aktiv
- Zusammenfassung: Eingebaute isiLive-Soundausgaben muessen ohne gespeicherte Nutzerentscheidung ueber `Master` abgespielt werden. Die gespeicherte Option `soundOutputChannel` darf nur die Werte `Master` und `SFX` akzeptieren; ungueltige Werte fallen geschlossen auf `Master` zurueck. Wenn `soundOutputChannel = "SFX"` gespeichert ist, muessen Runtime-Playback und Preview-Playback der eingebauten Sound-Registry `SFX` verwenden, waehrend die einzelnen Sound-Enable-Toggles unveraendert pro Sound greifen. Die Settings-UI muss die Kanalwahl in der Sound-Sektion anbieten und den Default nicht schon beim Oeffnen persistieren.
- Erforderliche Tests:
  - SoundUtils uses Master by default and SFX when configured
  - Settings panel exposes sound toggles with the intended defaults
  - Locale sound-channel settings strings support prepared translations
  - DBSchema.Sanitize fills all defaults on an empty db
  - DBSchema.Sanitize resets invalid soundOutputChannel to Master and preserves SFX

### RULE-SAVEDVARIABLES-SETTINGS-REAPPLY
- Regelnummer: 79
- Status: aktiv
- Zusammenfassung: Settings-Werte, die beim Laden von Live-Modulen angewendet werden muessen, duerfen nicht dauerhaft am File-Load-Default haengen bleiben, wenn `IsiLiveDB` waehrend der Lua-Dateiladung noch nicht wiederhergestellt ist. Der `ADDON_LOADED`-Pfad muss nach dem SavedVariables-Restore die gespeicherten Werte erneut ueber den echten `ApplyDBSettings`-Callback auf MobNameplate, MobTooltip, LFGFlags, Gruppenbonus-Flags, Tooltip-Flags und StatsBox anwenden. Fehlt der Callback waehrend frueher Initialisierung noch, darf der spaetere Eventpfad nicht auf einen dauerhaft eingefrorenen No-Op zeigen.
- Erforderliche Tests:
  - factory composition root: ADDON_LOADED reapplies saved display settings after SavedVariables restore

### RULE-DEATH-ALERT-MPLUS
- Regelnummer: 80
- Status: aktiv
- Zusammenfassung: Der Todesalarm rendert nur waehrend eines aktiven M+-Runs eine grosse rote rahmenlose Bildschirmwarnung mit Scale-Punch-Animation. Diese Bildschirmwarnung ist strikt auf Tank und Heiler begrenzt und zeigt ausschliesslich den rollenbasierten Text ohne Namen (`Tank died` / `Healer died`). Die Erkennung laeuft edge-getriggert ueber `UNIT_HEALTH` pro GUID fuer `player` und `party1`-`party4` und feuert fuer Tank, Heiler und Schadensausteiler: nur der Uebergang lebendig zu tot loest genau einen Alarm aus, eine Wiederbelebung schaltet die Flanke neu scharf, Challenge-Lifecycle-Events setzen die Flags zurueck und Roster-Updates verwerfen Flags verlassener Spieler. Der eigene Tod alarmiert ebenfalls; Disconnects und Zustaende ausserhalb eines aktiven Keys bleiben stumm. Die aufgezeichnete WAV-Datei existiert nur fuer Tank und Heiler; ein Schadensausteiler-Tod erzeugt ausschliesslich eine gesprochene Ansage (kein Bildschirmtext, keine WAV) und bleibt bei deaktiviertem TTS stumm. Der Settings-Schalter (`deathAlertEnabled`, Default an) ist der Master-Gate fuer das ganze Feature; im Raid bleibt der Pfad ueber die Raid-Unterdrueckung des Event-Dispatches aus.
- Erforderliche Tests:
  - DeathWatch fires tank death alert once per active-key death
  - DeathWatch fires healer death alert with role resolved at death time
  - DeathWatch stays silent outside an active M+ key
  - DeathWatch stays silent when the death alert setting is disabled
  - DeathWatch fires again after revive and renewed death
  - DeathWatch fires for damage-dealer deaths so they can be announced
  - DeathWatch ignores disconnected units
  - DeathWatch alerts for the local player's own death
  - DeathWatch resets dead flags on challenge lifecycle events
  - DeathWatch roster update drops dead flags of departed players
  - DeathAlert renders big red death text and restarts animation on repeated show
  - Factory death alert wiring routes role deaths to alert and TTS sound
  - Factory death alert keeps the on-screen warning to tank and healer
  - SoundUtils registry gates both death TTS files behind the single death alert setting

### RULE-READYCHECK-KOMPLETT-KLANG
- Regelnummer: 81
- Status: aktiv
- Zusammenfassung: Der Ready-Check-Komplett-Klang nutzt `Interface\AddOns\isiLive\sounds\BttF_Tinkle.wav` und darf pro Ready-Check-Zyklus genau einmal abgespielt werden, sobald waehrend eines aktiven Ready-Checks exakt fuenf gueltige Roster-Units (`player` und `party1`-`party4`, keine Geister) als bereit markiert sind. Vor dem fuenften bereiten Spieler, bei weniger als fuenf gueltigen Teilnehmern, bei Geister-Zeilen, nach beendetem Ready-Check oder wenn `soundReadyCheckCompleteEnabled` deaktiviert ist, bleibt der Klang stumm. Der Klang muss in der Sound-Registry und in den Settings mit Preview-Schalter verfuegbar sein und dieselbe `soundOutputChannel`-Ausgabe wie andere eingebaute Sounds verwenden.
- Erforderliche Tests:
  - Event handlers play ready-check complete sound once when all five players are ready
  - Event handlers keep ready-check complete sound silent unless exactly five players are ready
  - Architecture ready check refresh stays wired through runtime setup and controller wiring
  - SoundUtils ready-check-complete setting disables BttF playback
  - Settings panel exposes ready-check-complete sound toggle and preview

### RULE-SYNC-HELLO-ACK-LOOP-BREAKER
- Regelnummer: 82
- Status: aktiv
- Zusammenfassung: Ein eingehendes `HELLO` loest den vollen Peer-State-Fan-out (hello-ack) nur aus, wenn es ein initiales HELLO ist (Source `local`, `group`, `refresh` oder legacy ohne Source-Feld). HELLOs mit Source `hello-ack` oder `reqsync-ack` sind selbst Fan-out-Antworten und duerfen keinen weiteren Ack-Fan-out ausloesen. Ohne diesen Loop-Breaker beantworten sich zwei Clients endlos gegenseitig (der Fan-out-Hello wird mit force am 8s-Hello-Rate-Limit vorbei gesendet), die Dauerflut staut die ChatThrottleLib-Sendequeue um ~30 Sekunden auf und gespiegelte `SKCD`-Sperren reflektieren endlos zwischen den Peers, sodass der Share-Keys-Button nie wieder frei wird.
- Erforderliche Tests:
  - Sync ProcessAddonMessage does not ack hello-ack or reqsync-ack fan-out hellos
  - Sync ProcessAddonMessage handles HELLO, REQSYNC, and KEY payloads
  - ControllerWiring sendShareKeysCooldownState mirrors only the locally owned cooldown
  - Roster panel share keys button reports only locally owned locks for SKCD mirroring
  - Share keys SKCD reflection dies after one hop across real wiring and buttons

### RULE-TTS-ANSAGEN
- Regelnummer: 83
- Status: aktiv
- Zusammenfassung: Gesprochene Text-to-Speech-Ansagen laufen ueber `SoundUtils.SpeakTts` mit der WoW-12.0-Signatur `C_VoiceChat.SpeakText(voiceID, text, rate, volume[, overlap])` (das `destination`-Argument wurde in 12.0 entfernt). Das Feature ist opt-in ueber `ttsAnnouncementsEnabled` (Default aus). `SpeakTts` ist fail-closed: ohne `C_VoiceChat.GetTtsVoices`/`SpeakText`, ohne verfuegbare Stimme oder bei leerem Text wird nichts gesprochen und `false` zurueckgegeben. Die Stimme ist die per `ttsVoiceID` gewaehlte, sofern sie in der Live-Stimmenliste existiert, sonst die erste Systemstimme; die Sprechgeschwindigkeit kommt aus `C_TTSSettings.GetSpeechRate()` (Fallback 0), die Lautstaerke aus `ttsVolume` (0..100, Default 100). TTS umgeht bewusst die Master/SFX-Soundkanaele (genehmigte Ausnahme der Sound-Channel-Policy). Es gilt dasselbe 1-Sekunden-Spam-Fenster wie bei `Play`. Der gesprochene Todes-Text wird aus zwei Templates und einem Deskriptor gebaut: `ttsAnnounceName` (Default an) bestimmt, ob der Spielername genannt wird (`TTS_NAMED_DIED_FMT` mit Name plus Deskriptor) oder nur der Deskriptor (`TTS_DIED_FMT`). `ttsAnnounceClass` (Default aus) bestimmt den Deskriptor: bei an der lokalisierte Klassenname via `UnitClass` (Secret-Value-guarded), sonst das lokalisierte Rollenwort (`TTS_ROLE_TANK` / `TTS_ROLE_HEALER` / `TTS_ROLE_DAMAGER`); ist die Klasse nicht lesbar, faellt der Deskriptor auf das Rollenwort zurueck. Ist der Name nicht aufloesbar (Secret-Value, leer), wird die namenlose Form gesprochen. Gesprochene Ansagen decken Tank, Heiler und Schadensausteiler ab. Schlaegt der TTS-Pfad fehl oder ist er deaktiviert, spielt der Death-Alert die WAV-Datei nur fuer Tank/Heiler; fuer Schadensausteiler gibt es keine WAV, ein DPS-Tod bleibt ohne TTS also stumm. Der `deathAlertEnabled`-Schalter und die Raid-Unterdrueckung bleiben vorgelagert wirksam; die TTS-Schalter waehlen nur die Klangform und den Wortlaut.
- Erforderliche Tests:
  - SoundUtils SpeakTts fails closed without the voice-chat API
  - SoundUtils SpeakTts fails closed when no system voice is available
  - SoundUtils SpeakTts speaks with the 12.0 argument order and honours the spam window
  - SoundUtils SpeakTts prefers the configured voice id and clamps the volume
  - SoundUtils IsTtsEnabled defaults to off and follows the setting
  - SoundUtils ShouldAnnounceName defaults on and follows the setting
  - SoundUtils ShouldAnnounceClass defaults off and follows the setting
  - Factory death alert speaks the player name when TTS is enabled
  - Factory death alert announces the role word when names are off
  - Factory death alert announces the class when class mode is on
  - Factory death alert announces a damage-dealer death via TTS only
  - Factory death alert falls back to a nameless announcement for a secret or missing name
  - Factory death alert falls back to the recorded wav when TTS is disabled or unavailable
  - Settings panel exposes the spoken-alert toggle and TTS preview
  - Settings panel exposes the TTS name and class toggles
