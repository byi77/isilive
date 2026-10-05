# Sechsfaches Performance-Audit vom 2026-10-05

Gepruefter Stand: `0.9.413`, Commit `75342984152ca847aea3c184ef53e3b70ff5d1cf`.
Die sechs Audit-Durchlaeufe verwenden unveraenderten Produktionscode; die
anschliessende Korrektur wird am Ende beschrieben. Die vor dem Audit geaenderte
`todo_temp1.md` bleibt unberuehrt.

## Sechs Durchlaeufe

Jeder Durchlauf startet `lua tools/validate_usecases.lua` in einem eigenen
Lua-Prozess und prueft die vollstaendige Suite einschliesslich der zehn
M+-Belastungsszenarien. Die zugeordneten Schwerpunkte betreffen die begleitende
Codepruefung; die ausgefuehrte Suite ist in allen sechs Durchlaeufen dieselbe.

| Durchlauf | Schwerpunkt | Bestanden | Fehler | Lokale Laufzeit |
|---|---|---:|---:|---:|
| 1 | Solo-Leerlauf: Settings, Statsbox, Inspect | 2526 | 0 | 17,81 s |
| 2 | Event-Schuebe: Dispatcher und CD-Coalescer | 2526 | 0 | 16,84 s |
| 3 | M+-Kampf: Aura-/Cast-Filter und gezielte Refreshes | 2526 | 0 | 16,15 s |
| 4 | Hidden-Sync: Heartbeats, Empfaenger und Logging | 2526 | 0 | 16,80 s |
| 5 | Key-Ende: Reset, Completion, ausstehende Callbacks | 2526 | 0 | 17,69 s |
| 6 | Gruppenwechsel: Solo, Raid, Party und Ticker-Ownership | 2526 | 0 | 17,79 s |

Gesamt: 15.156 erfolgreiche Testausfuehrungen, null fehlgeschlagene Tests.
Zusaetzlich bestehen Style-, Runtime-Regel- und Architektur-Regelpruefung.
Dies sind deterministische Lua-Fixtures, kein sechsfacher Live-WoW-Lauf.
Der wiederholte Prozessstart untersucht auch keine Persistenz zwischen echten
Spiel-Sitzungen. Die sechsfach gruene vorhandene Suite schliesst die unten
gefundenen Abdeckungsluecken nicht aus.

## Befund 1: Byte-Formatierung trotz ausgeschaltetem Logging

Status: im Audit-Stand nachgewiesen; durch den unten beschriebenen Patch korrigiert.

`logic/isiLive_sync_receive.lua` ruft `FormatBytes(sender)` bereits beim
Zusammenstellen der Argumente fuer `SyncLogDeep` auf.
`logic/isiLive_sync.lua` formatiert dabei jedes Byte ueber
`string.format("%02X", ...)`, bevor die Logger-Sperre entscheidet, ob ein
Logeintrag verarbeitet wird. Das beruehrt den Vertrag von Regel 56.

Reproduktionsprobe: echten Sync-Empfaenger laden, ausschliesslich die globale
`string.format`-Funktion mit einem delegierenden Zaehler fuer `%02X`
instrumentieren, 10.000 identische `KEY:2662:12:100:audit`-Pakete des Senders
`Peer-Realm` verarbeiten und den akzeptierten Level 12 pruefen.

| Logging-Modus | Pakete | Byte-Formatierungen | Trace-Callbacks |
|---|---:|---:|---:|
| Alle Logger aus | 10000 | 100000 | 0 |
| Nur normaler Trace, Builder verworfen | 10000 | 100000 | 10001 |
| Deep-Trace, Builder verworfen | 10000 | 100000 | 19999 |
| Deep-Trace, Builder ausgefuehrt | 10000 | 100000 | 19999 |

Die Messung belegt vermeidbare Log-Vorbereitung, ordnet aber weder die gesamten
Sync-Allokationen noch die gemeldete 945-ms-Solo-Spitze dieser Funktion zu.
Die bestehende Lazy-Builder-Abdeckung prueft diese vorbereitenden Argumente
nicht. Ein gezielter Regressionstest muss fuer ausgeschaltetes Logging und
verworfene Deep-Builder null Byte-Formatierungen verlangen; ausgefuehrtes
Deep-Logging muss die bestehenden verifizierten Hex-Bytes unveraendert liefern.

## Befund 2: CD-Polling startet nach Raid-Rueckkehr nicht von selbst

Status: im Audit-Stand reproduziert; durch den unten beschriebenen Patch korrigiert.

Die Zusatzprobe startet den Key durch den echten Event-Dispatcher und
wiederholt 20-mal: 100 Cooldown-/Charges-Eventpaare planen, Raid betreten,
eine Sekunde vorruecken, in die Party zurueckkehren und eine weitere Sekunde
vorruecken. Insgesamt werden 4000 CD-Events vor den Wechseln dispatcht.

Im Raid bleiben die Szenario-Lesungen und Sync-Sends stehen; Kick-, Forces-
und CD-Ticker sind abgebrochen, Inspect besitzt keinen `OnUpdate`.
Nach jeder Rueckkehr laufen genau ein Forces- und ein Kick-Ticker; der
Forces-Wert folgt dem neuen expliziten Fixture-Wert. Prozentwerte werden mit
einer numerischen Toleranz von 0,000001 verglichen, um reine Lua-Gleitkomma-
Rundung von einer falschen Datenuebernahme zu unterscheiden.

In allen 20 Rueckkehrzustaenden ist die Main-UI sichtbar und der M+-Timer
laeuft, aber es existiert kein CD-Ticker. Ein anschliessender expliziter
`runtime.RefreshCdTrackerPolling()` liefert `true` und startet genau einen
CD-Ticker. Damit ist in diesem Fixture der Kontext berechtigt; der fehlende
automatische Wiederaufnahme-Aufruf ist eine Lifecycle-Abdeckungsluecke.
Ein echtes Raid-/Key-Uebergangsszenario wurde nicht im Spiel beobachtet.

Die vorhandene Raid-Stress-Assertion prueft Forces-Wiederaufnahme, aber keine
CD-Ticker-Wiederaufnahme. Ein gezielter Regressionstest muss diesen
berechtigten sichtbaren Rueckkehrzustand ohne kuenstlichen Refresh pruefen
und bei wiederholten Uebergaengen hoechstens einen CD-Ticker nachweisen.

## Zusaetzlich bestaetigt

10.000 `SPELL_UPDATE_CHARGES` bei versteckter UI planen genau einen Callback.
Der Callback aktualisiert den erlaubten CD-Zustand mit hoechstens 80
zusaetzlichen Aura-Abfragen und startet keinen Hidden-CD-Ticker. Anschliessend
bleiben nach Completion und 30 weiteren Sekunden M+-Timer, Forces-Aktivitaet
und BR-/BL-Daten geloescht. Die 20 Gruppenwechsel lassen keine Kick-/Forces-
Ticker anwachsen.

## Reproduktionsartefakte

Die sechs Testlogs und die beiden Zusatzproben liegen lokal unter
`%TEMP%/isilive-six-loop-audit/`. Die privaten Audit-Artefakte werden unter
`C:/Git/isilive-workspace/isilive-project-private/docs/audit-artifacts/2026-10-05-six-loop/`
gesichert. Der private Workspace erhaelt denselben Bericht.
Fuer dieses Audit wurden keine Version erhoeht und keine Commits oder Pushes
ausgefuehrt.

## Anschliessende Korrektur auf Benutzeranweisung

Die neue Regression fuer Befund 1 scheitert am unveraenderten Produktionscode
mit 100.000 Byte-Formatierungen statt null. Die neue Regression fuer Befund 2
scheitert dort am fehlenden CD-Ticker nach dem ersten Raid-Rueckweg.

Jetzt akzeptiert der interne Sync-Logger neben Formatstrings einen lazy
Daten-Builder. Der Empfaenger berechnet die Sender-Bytes innerhalb dieses
Builders. Ohne Logger oder bei verworfenem Deep-Builder wird er nicht
ausgefuehrt; der direkte Logger fuehrt ihn aus und behaelt den bisherigen
Text. Die bestehenden Unicode-Byte-Dump-Tests bleiben bestehen.

Die Factory bewertet CD-Polling nach Gruppen-/Weltwechseln und bei Show/Hide
neu. Diese Bewertung startet oder stoppt das Handle ueber die vorhandenen
Sichtbarkeits-, Kontext- und Raid-Gates; sie fuehrt keinen zusaetzlichen
CD-Aura-Scan oder vollstaendigen Roster-Render aus.

Die Regression prueft 20 Raid-/Party-Zyklen ohne kuenstlichen Wiederaufnahme-
Aufruf: nach jeder sichtbaren Rueckkehr genau ein CD-Ticker, im Raid null,
hidden null; erneutes Show startet genau einen, Hide bricht sofort ab.
Die unveraenderte Zusatzmessung bestaetigt nun fuer je 10.000 Pakete null
Byte-Formatierungen bei ausgeschaltetem, normalem und verworfenem Deep-Log;
ausgefuehrtes Deep-Logging behaelt 100.000 Byte-Formatierungen.

Die aktive Regelquelle erhaelt ausschliesslich die zwei neuen eindeutigen
Testzuordnungen in Regeln 56 und 93; die Vertraege bleiben unveraendert.

Abschliessende Validierung des Patches: 2528 Tests bestanden, null Fehler.
Der vollstaendige `tools/check.ps1`-Preflight einschliesslich Coverage besteht;
Gesamt-Coverage 93,00 %, keine Produktionsdatei unter 80 %.
Die korrigierte Zusatzprobe bestaetigt 20 Rueckwege mit automatischem
CD-Ticker-Start und keine Vermehrung durch einen redundanten Refresh.

Die anschliessenden Korrekturen sind auf Benutzeranweisung der Version
`0.9.414` zugeordnet; der urspruengliche sechsfach gepruefte Stand bleibt
`0.9.413`. TOC, README und Release-Highlights unterscheiden diese Staende.
