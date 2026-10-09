# Audit-Runde 6: Abschluss-Sweep und Nacharbeit

Stand: 2026-10-09. Basis: `aaa5fde`, TOC 0.9.426 plus lokale R5-Nacharbeit.
Die drei Findings sind in der Nacharbeit fuer 0.9.427 behoben.
Der abschliessende lokale Preflight wird unten dokumentiert.

Vollstaendige Reproduktion, Ursache, Risiko, Fixschritte und erforderliche
Tests stehen direkt in der privaten TODO unter
`C:\Git\isilive-workspace\isilive-project-private\TODO.md`.

## Findings

| ID | Prioritaet | Befund | Fix | Status |
|---|---|---|---|---|
| R6-01 | P1 | Unlesbare Lust-Daten nach einem aktiven Timer erzeugen einen falschen Ready-Sound. | Aktiv, bestaetigt abwesend und unresolved unterscheiden; Sound, Reminder und Ready-Anzeige brauchen verifizierte Readiness. | Behoben |
| R6-02 | P2 | Die Stress-Fixture ignoriert Parent-Sichtbarkeit und liefert OnShow an hidden Children. | Parent-Beziehungen, effektive Sichtbarkeit und echte Sichtbarkeitswechsel modellieren; anschliessend R5 erneut messen. | Behoben |
| R6-03 | P2 | Teleports Activity-Resolver nutzt vorhandene verifizierte Season-Zuordnungen bei Live-API-Ausfall nicht. | Aktuelles SeasonData.GetMapIDByActivityID vor Runtime-Cache/API verwenden; unbekannte ID-Domaenen bleiben unresolved. | Behoben |

## Reproduktionsnachweis

R6-01: Echte Factory-/Dispatcher-Probe mit vorher verifiziert aktiver Aura
57723: maskierte expiry, werfende API und maskierte Spell-ID erzeugen jeweils
einen falschen Ready-Sound. Normale Restzeiten vor den drei Transitions sind
594,9 / 594,7 / 594,5 Sekunden auf der Fixture-Uhr; danach 0 / nil / nil.
Ursachen: `game/isiLive_cd_tracker.lua:144` setzt fuer unbekannte expiry 0,
der Scan leert bei nicht aufloesbaren Treffern den Timer; der Factory-Pfad
`factory/isiLive_factory_cd_tracker.lua:326` wertet dessen Verschwinden als Ready.
Dies ist ein deterministischer produktiver Befund, kein Live-Nachweis.

R6-02: Ein hidden Child erhaelt ueber FireChildrenOnShow einen Callback.
Ein shown Child unter hidden Parent meldet IsShown=true und IsVisible=true.
BuildCreateFrame verwirft den Parent; IsVisible prueft nur lokales `_shown`.
Daraus folgt kein produktiver UI-Fehler, aber eine Abdeckungsluecke an
Parent-Versteckung und Sichtbarkeitswechseln. Gegenproben fuer verschachtelte,
reparentete und explizit hidden Frames sowie Settings unter verstecktem
Container sind vor einer korrigierten R5-Messung erforderlich.

R6-03: Das verifizierte Season-2-Manifest ordnet Activity 514 der Challenge-Map
249 und Portal 1286831 zu. Bei werfender Live-Activity-API liefern SeasonData
und LFGEntryResolver weiterhin 249; Teleports direkter Activity-Resolver
liefert nil und findet kein Portal. Es werden keine neuen IDs geraten.
Der alte D1-Nebenpunkt zum ID-Raum von activityInfo.mapID bleibt separat
unresolved; eine positive Zahl ist kein Domaenenbeweis.

Privates Repro-Skript: `tools/audit_round6_probes_2026-10-09.lua`, aus dem
Addon-Root ausfuehren. Es dokumentiert bewusst den damaligen Fehlerstand und
ist kein Desired-Behavior-Gate; nach Fixes durch Regressionen ersetzen.

## Pruefumfang und Validierung

Geprueft wurden die Audit-4-Tooltip-, LFG-, Settings-, TestMode- und CD-Fixes,
Mob-Tooltip, R5-Messung/CI-Verdrahtung/Fixture sowie Activity-Aufloesung.
Die bestehende Suite bleibt gruen; sie ersetzt die neuen Gegenproben nicht.
Dies ist kein unbeschraenkter Fehlerfreiheitsnachweis oder Live-WoW-Test.

Eine moegliche LFG-Flaggen-Luecke bei geaendertem Leiter unter unveraenderter
Ergebnis-ID wurde nicht als Finding gewertet: dafuer fehlt ein belastbarer
ID-Lifecycle-Beleg. Blizzards Source behandelt ein ausdrueckliches
[Delisting bei Leadership-Change](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_GroupFinder/Mainline/LFGList.lua).
Die aktiven stabilen negativen Flaggen-Cache-Antworten wurden nicht in neue
Bugs umgedeutet. E4 und die bereits offenen Ingame-Messungen bleiben offen.

- Usecase-Gate: 2658 bestanden, 0 fehlgeschlagen; git diff --check sauber.
- Kein neuer Coverage-Lauf in dieser reinen Review-Runde; R5-Preflight war
  gruen mit 93,53 %. Kein externer CI-Lauf.
- Die obigen Messungen dokumentieren den urspruenglichen Auditstand.

## Findings aus Runde 5

Alle vier R5-Findings sind lokal behoben: integrierter Pull fehlte (R5-01),
Arbeits-/Heap-Grenzen fehlten (R5-02), Unit-Filter/UnregisterAllEvents waren
unzureichend modelliert (R5-03), Owned-Keystone-API-Name war falsch (R5-04).
Details und damaliger Validierungsnachweis stehen in `docs/AUDIT_RUNDE_5.md`.

## Nacharbeit 0.9.427

R6-01: IsLustScanResolved trennt bestaetigte Abwesenheit/Restzeit von unknown.
Unlesbare Daten liefern keinen Timer und keinen Ready-Zustand. Ready-Reminder
werden verworfen; ein beobachteter aktiver Zyklus bleibt bis zum verifizierten
Folgescan erhalten. Der reale Factory-/Dispatcher-Test prueft visible/hidden,
maskierte expiry/ID/Container, API-Fehler und volle 40 Slots ohne Listenende.
Eine bestaetigte Entfernung erzeugt genau eine legitime Ready-Ansage.

R6-02: Parent-Verknuepfung, Reparenting, effektive Sichtbarkeit und rekursive
Show-/Hide-Transitions sind modelliert. Verdeckte Kinder bleiben verdeckt;
wiederholtes Show/Hide sowie der Hilfsaufruf liefern keine Doppelcallbacks.
R5-Budgets wurden unveraendert erneut bestanden: Lifecycle-Retention
6,54 KiB visible / 9,38 KiB hidden, Grenze jeweils 64 KiB. Wipe/Completion
visible benoetigen nun 252/2566 pcall statt 260/2582. Das sind Fixture-Messungen.

R6-03: Das aktuelle verifizierte Manifest wird vor Cache/API konsultiert.
Map-Caches werden bei Season-Wechsel geleert; ein Spell-Cache entfaellt.
Bekannte Activity 514 bleibt bei API-Fehler auf Map 249 / Spell 1286831.
Unbekannte Activities ohne Quelle bleiben unresolved. Der separate alte
D1-Nebenpunkt zum ID-Raum ungepruefter Live-API-Maps bleibt offen.

Regelzuordnung: Die neuen Runtime-Testnamen sind in Regeln 5, 54 und 71
zugeordnet. Maschinenpruefbare Intention: unbekannte Lust-Scans erzeugen niemals
Ready; bestaetigte Entfernung nach beobachtetem Timer erzeugt Ready;
verifizierte Activity-Portale bleiben bei API-Ausfall verfuegbar und alte
Season-Spells werden nicht wiederverwendet. Bestehende Regeltexte und
Reihenfolge bleiben unveraendert.

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
