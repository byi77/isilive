# TODO

## Readycheck-Balken verschwinden zu schnell

- Problem: Die gruen/roten Readycheck-Balken verschwinden nach dem `READY_CHECK_FINISHED` oder kurz danach immer noch zu schnell.
- Beobachtung: Im UI sieht man die Farbbalken nur sehr kurz, obwohl der Hold laut Logik 20 Sekunden halten soll.
- Erwartung: Nach einem Readycheck sollen `ready` und `notready` als Hintergrundfarbe fuer die volle Hold-Zeit sichtbar bleiben.
- Vermutung: Ein spaeterer Refresh pflegt den Hold-State nicht mehr konsistent an die Rosterzeilen durch oder ueberschreibt ihn mit einem neutralen Render.
- Bisheriger Ansatz: Der 1-Sekunden-Ticker reassertet den Readycheck-State bereits, aber das Verhalten ist ingame noch nicht stabil genug.
- Naechster Schritt: Mit einem gezielten Live-Trace die genaue Stelle finden, an der der Hintergrund vor Ablauf der Hold-Zeit neutralisiert wird.
- Wichtiger Rahmen: Keine grosse Umbaustelle starten, zuerst den konkreten Ueberschreiber identifizieren.

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
