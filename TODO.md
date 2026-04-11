# TODO

## Readycheck-Balken verschwinden zu schnell

- Status: Der Renderpfad ist jetzt getrennt, der normale Roster-Render setzt den Readycheck-Hintergrund nicht mehr selbst.
- Problem: Im Spiel muss noch verifiziert werden, ob der dedizierte Readycheck-Refresh den Hold-Zustand nach `READY_CHECK_FINISHED` wirklich bis zum Ablauf sichtbar haelt.
- Erwartung: Nach einem Readycheck sollen `ready` und `notready` als Hintergrundfarbe fuer die volle Hold-Zeit sichtbar bleiben.
- Live-Trace-Plan:
  - `READY_CHECK` und `READY_CHECK_CONFIRM` mit Zeitstempel, `readyCheckActive`, `readyUntil`, `declinedUntil` und betroffener Unit loggen.
  - Direkt nach `READY_CHECK_FINISHED` den naechsten Ausloeser von `RefreshReadyCheckState()` oder `RenderRoster()` protokollieren.
  - Den Zustand kurz vor Ablauf der 20 Sekunden und direkt nach dem Timer-Cleanup vergleichen.
  - Falls der Hintergrund vorher verschwindet, den exakten Event- oder Timer-Ausloeser identifizieren, statt einen pauschalen Umbau zu machen.
- Wichtiger Rahmen: Keine grosse Umbaustelle starten, zuerst den konkreten Live-Ueberschreiber oder Timerpfad identifizieren.

## Share-Keys in Gruppe: sichtbarer Post/linkbarer Key nicht robust

- Problem: Der Button `Keys teilen` funktioniert im Gruppenkontext nicht robust. Im Ausgangsfehler passierte fuer den Nutzer sichtbar gar nichts; spaeter liess sich der sichtbare Chat-Post nur mit Klartext stabil erzwingen, dann war der Key aber nicht mehr anklickbar.
- Zwischenstand: Der lokale Fallback erzeugt jetzt wieder einen klickbaren Keystone-Link, auch wenn die Owned-Link-API ausfaellt. Der Live-Fall mit fehlender Sichtbarkeit im Gruppenchat bleibt als separates Repro-Thema offen, falls er auf dem Zielclient noch auftritt.
- Erwartung: Ein Klick auf `Keys teilen` soll in der Gruppe den eigenen Key sichtbar im Gruppenchat posten und idealerweise als echter anklickbarer Keystone-Link erscheinen.
- Harter Sender-Befund aus dem Runtime-Trace:
  - Klickpfad lief an: `click inGroup=true ownLine=present`
  - sichtbarer Chatpfad wurde aufgerufen: `visible-chat attempt channel=PARTY ...`
  - Addon-Request wurde ausgelöst: `request dispatch`
  - Sync-Send lief an: `request invoke channel=PARTY`
  - Addon-Send wurde lokal ausgeführt: `sync-request send_ok=true accepted=0 channel=PARTY`
- Gesicherte Ingame-Beobachtungen:
  - Mit programmgesteuert gesendetem Keystone-Link erschien beim Nutzer zeitweise kein sichtbarer Gruppenchat-Post.
  - Nach Umstellung auf Klartext erschien der sichtbare Gruppenchat-Post sofort:
    - `[isiLive] PartyKeys: Terrasse der Magister +11`
  - In diesem Klartext-Fall war der Key nicht anklickbar, also funktional sichtbar aber nicht als Keystone-Link nutzbar.
- Was das Debugging belastbar gezeigt hat:
  - Der lokale Button-Klick kam an.
  - Der Sender hatte eigene Key-Daten verfuegbar.
  - Der sichtbare Chatpfad wurde programmgesteuert erreicht.
  - Der Addon-Sync-Request wurde senderseitig ausgelöst.
  - Das Problem sitzt damit nicht trivial im reinen Button-OnClick, sondern im Zusammenspiel aus Chat-Payload, Chat-API-Verhalten und/oder Empfaengerpfad.
- Was ausdruecklich noch nicht sauber bewiesen ist:
  - Ob ein programmgesteuert gesendeter echter Keystone-Link im Gruppenchat auf diesem Client/Setup generell belastbar sichtbar ist.
  - Ob das Remote-Teilen ueber andere isiLive-Clients korrekt reagiert oder ob zusaetzlich ein Empfaengerpfad-Problem vorliegt.
- Bereits verworfene Schnellschuesse:
  - Mehrere Diagnose-/ACK-/Retry-/Runtime-Log-Erweiterungen wurden ausprobiert und wieder verworfen.
  - Die Loesung wird nicht ueber weitere Fallback-Ketten oder Trial-and-Error gebaut.
- Naechster sauberer Schritt:
  - Neu ansetzen vom letzten Commit aus.
  - Den Fall isoliert und klein reproduzierbar machen.
  - Danach getrennt pruefen:
    1. sichtbarer Sender-Post mit echtem Keystone-Link
    2. sichtbarer Sender-Post mit Klartext
    3. Empfaenger-Reaktion eines zweiten isiLive-Clients
  - Erst auf Basis dieser drei Beweise die endgueltige Loesung bauen.

## Hinweise

- Diese Datei ist absichtlich Teil des Git-Repos.
- Sie ist in `.pkgmeta` ausgeschlossen und darf nicht im CurseForge-Release landen.
