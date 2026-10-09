# Audit-Runde 5: Regressionsmessung

Stand: 2026-10-09. Basis: lokaler Commit `aaa5fde`, TOC 0.9.426.
Die Nacharbeit ist noch nicht committet. Runtime-Verhalten bleibt unveraendert.

## Einstieg und Umfang

`lua tools/simulate_mplus_regression.lua` fuehrt denselben Runner aus wie
`tools/validate_usecases.lua`. Lokaler Preflight und GitHub-Workflow rufen
den Simulator explizit auf; `check_simulator_ci_coverage.lua` prueft die
Verdrahtung. Der neue Runner liegt unter
`testmodul/isilive_test_mplus_regression.lua`.

Factory, zentrale Event-Gates, Controller-Wiring, Sync-Sender und -Empfaenger,
Timer und Nameplate-Renderer sind produktiv. Gemockt werden Client-APIs,
Widgets und Zeit. Events erreichen alle registrierten Frames ueber deren
echte OnEvent-Scripts; RegisterUnitEvent-Filter bleiben wirksam.
Der bestehende Factory-Fixture-Code wurde ohne produktive Modulverschiebung
nach `testmodul/isilive_test_factory_fixture.lua` extrahiert.

Beide UI-Zustaende durchlaufen denselben Ablauf:

1. Login, Gruppenbeitritt, Key-Start und Warmup von vier Peers und acht Overlays.
2. 4.000 Aura-/Health-Events: irrelevante und relevante Player-Auren,
   Party- und Nameplate-Health; genau ein nachlaufender Aura-Scan.
3. 60 veraenderte KICK-Pakete von vier verifizierten Roster-Peers ueber den
   echten Wire-Encoder; am Ende sind alle vier Kicks bereit.
4. Zweimal 100 Add/Remove-Zyklen mit je acht aktiven Nameplates: 1.600
   Unit-Wechsel bzw. 3.200 Add/Remove-Events, ohne neue Frames nach Warmup.
5. Wipe mit fuenf vom Timer gelesenen Toden, danach Wiederbelebung und Kampfende.
6. Completion bei 1.000 vorgemerkten Charge-Events, Solo-Uebergang und 30
   simulierte Sekunden: kein laufender Key, Forces- oder CD-Zustand und keine
   Kick-, Forces- oder CD-Ticker. Completion setzt den Timer gemaess bestehendem
   Runtime-Vertrag zurueck; ein persistentes completed-Flag wird nicht verlangt.

Die Nameplates verwenden Map 249 und NPC 133935 aus der eingecheckten
Forces-DB; der echte Season-/Frische-Gate laeuft mit deren Generierungsdatum.
Andere Client-Werte sind explizite Test-Fixtures. Unbekannte MapUI-/Instance-
Zuordnungen werden nicht hinzugefuegt. Die reale DB-Frist wird weiterhin im
separaten Lifetime-Gate geprueft. Der maskierte GUID-/API-Fallback aus E4
bleibt bewusst ausserhalb der Messung; jeder unerwartete Aufruf scheitert.

## Arbeitsbudgets

Zaehler werden vor und nach jeder Phase gelesen. Der pcall-Wrapper erhaelt
alle Rueckgabewerte; fehlgeschlagene Aufrufe sind ebenfalls sichtbar.
Jede Phase sowie der gesamte Lifecycle verlangen null abgefangene Fehler.
CreateFrame zaehlt tatsaechliche Fixture-Frame-Erzeugungen; Blizzard-Plates
werden vor dem Messfenster angelegt. Der Warmup muss genau acht Addon-Overlays
erzeugen. Render- und Kick-Spalten-Wrapper rufen die echten Renderer weiter auf.

| Phase | pcall sichtbar / hidden gemessen | pcall-Obergrenze | Neue Frames | Voll-Render maximal | Retained-KiB maximal |
|---|---:|---:|---:|---:|---:|
| Aura/Health | 30015 / 30015 | 31000 | 0 | 1 | 4 |
| Vier KICK-Peers | 1131 / 936 | 1200 | 0 | 0 | 32 |
| Churn, je Durchlauf | 13600 / 13600 | 14400 | 0 | 0 | 4 |
| Wipe/Recovery | 260 / 141 | 300 | 0 | 1 | 8 |
| Completion/Solo | 2582 / 2326 | 2700 | 0 | 2 | 16 |

Weitere Obergrenzen im Code: Aura-Burst genau ein Scan und hoechstens ein
After; KICK-Phase hoechstens 90 Spaltenupdates, 15 Aura- und 30 Scenario-Reads;
Churn null Aura-/Scenario-Reads und After; Wipe hoechstens vier Spaltenupdates,
zwei Aura- und fuenf Scenario-Reads sowie ein After; Completion null
Aura-Reads, ein Scenario-Read und zwei After.

Baseline auf Lua 5.4.6: Retained nach dem ganzen Lifecycle etwa 6,53 KiB
sichtbar und 9,38 KiB hidden. Beide Churn-Durchlaeufe behalten jeweils unter
0,2 KiB. Der Lifecycle-Gate erlaubt maximal 64 KiB. Diese bewusst gerundeten
Budgets sind Regressionsgrenzen fuer diesen festen Mock-Workload und keine
Behauptung ueber Ingame-Speicher, CPU, FPS oder Eventfrequenzen.

Heap vor GC und Retained nach GC werden getrennt ausgegeben. Bei normalem
Lauf wird GC waehrend der Phase angehalten und auch im Fehlerfall wieder
gestartet. Coverage laesst GC laufen und ueberspringt ausschliesslich die
Heap-Messung/Grenzen, weil Instrumentierungsallokationen nicht Addon-Allokationen
sind. Alle Arbeits-, Zustands- und Fehlerbudgets bleiben unter Coverage aktiv.

Ein Negativtest injiziert echte zusaetzliche CreateFrame- bzw. pcall-Aufrufe
in den Eventpfad. Beide muessen an ihrem jeweiligen Budget scheitern.

## Findings und Fixes

- R5-01: Integrierter Pull fehlte. Behoben durch gemeinsamen Runner,
  Standalone-Simulator und Usecase-/CI-Verdrahtung.
- R5-02: Heap wurde nur ausgegeben; pcall-/Frame-Gesamtbudgets fehlten.
  Behoben durch Phasen- und Lifecycle-Grenzen sowie Negativtests.
- R5-03: Die Stress-Fixture ignorierte gespeicherte Unit-Filter;
  UnregisterAllEvents war im Widget-Catch-all wirkungslos. Behoben durch
  gefilterte Zustellung und echtes Leeren der Eventregistrierungen.
- R5-04: Die Factory-Fixture definierte GetOwnedKeystoneMapID, waehrend der
  produktive Reader GetOwnedKeystoneChallengeMapID aufruft. Dadurch wurden
  nil-Aufrufe still abgefangen. Fixture korrigiert; gesamter Pull jetzt ohne
  fehlgeschlagene pcall-Aufrufe. Kein produktiver API-Ausfall abgeleitet.

Alle Findings werden mit Reproduktion, Risiko, Fix und Validierungsnachweis
direkt in der privaten TODO unter
`C:\Git\isilive-workspace\isilive-project-private\TODO.md` gepflegt.
In diesem Workload ist bisher kein neuer produktiver Runtime-Fehler belegt.
Runde 6 und die ausstehenden Ingame-Messungen werden dadurch nicht abgeschlossen.

## Regelzuordnung und maschinenpruefbare Intention

Die zwei integrierten Testnamen sind den bestehenden Regeln 93 und 148
zugeordnet. Deren Zusammenfassungen und Reihenfolge bleiben unveraendert.
Intention: Der feste sichtbare und versteckte Pull muss seine Arbeitsbudgets
einhalten, Overlays nach Warmup wiederverwenden und nach Completion/Solo
Timer-/CD-/Forces-Verarbeitung stoppen. Die Zusatztests erzwingen, dass
Frame-/pcall-Amplifikation scheitert und Unit-Filter sowie UnregisterAllEvents
die Frame-Zustellung tatsaechlich begrenzen. Es werden keine neuen
Runtime-Daten oder Produktentscheidungen aus den Mock-Zahlen abgeleitet.


## Abschlussnachweis

Audit-Runde 5 ist am 2026-10-09 lokal abgeschlossen. Vier Findings an
Testabdeckung/Fixtures sind behoben; kein neuer produktiver Runtime-Fehler
ist im beschriebenen Workload belegt.

- Standalone-Simulator: 4 bestanden, 0 fehlgeschlagen.
- `lua tools/validate_usecases.lua`: 2658 bestanden, 0 fehlgeschlagen.
- Vollstaendiger Preflight `tools/check.ps1`: gruen, inklusive Simulatoren,
  Regel-/Architekturvalidierung, statischer Gates und Coverage-Lauf.
- Coverage: 93,53 % insgesamt; keine produktive Datei unter 80 %.
- `check_simulator_ci_coverage.lua`: 32 Simulatoren in beiden CI-Pfaden.
- `git diff --check`: sauber. Kein externer GitHub-CI-Lauf durchgefuehrt.
- Kein Versionsbump, Commit, Push, Tag oder Deploy. `todo_temp1.md` unberuehrt.

## Wiederholung nach R6 / 0.9.427

R6 korrigiert die Parent-Sichtbarkeit der gemeinsamen Fixture. Alle R5-Grenzen
bleiben unveraendert und wurden erneut bestanden. Lifecycle-Retention:
6,54 KiB visible / 9,38 KiB hidden (Grenze 64 KiB). Visible Wipe/Completion:
252/2566 pcall statt 260/2582. Keine Live-Kosten aus diesen Zahlen abgeleitet.
R5 und R6 werden gemeinsam lokal als 0.9.427 committet; kein Push oder Deploy.

## Finaler Abschlussnachweis 0.9.427

- Alle vier R5- und drei R6-Findings behoben; Gegenproben ohne weiteren
  reproduzierten Befund im beschriebenen Pruefumfang.
- `lua tools/validate_usecases.lua`: 2661 bestanden, 0 fehlgeschlagen.
- `tools/check.ps1`: vollstaendiger lokaler Preflight gruen, einschliesslich
  Format, Lint, Syntax, Metriken, Regel-/Architektur-Gates, aller Simulatoren
  und erneutem Usecase-Lauf unter Coverage.
- Coverage 93,53 %; keine produktive Datei unter 80 %.
- R5-Budgets normal und unter Coverage gruen, keine Grenze erhoeht.
- Release-Doku und TOC 0.9.427; gemeinsamer lokaler Commit R5/R6.
- Kein Push, Tag, Deploy oder externer CI-Lauf. Ingame-Probes und der
  separate D1-Nebenpunkt zum API-ID-Raum bleiben offen.
