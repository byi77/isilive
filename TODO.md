# TODO

## Readycheck-Balken verschwinden zu schnell

- Problem: Die gruen/roten Readycheck-Balken verschwinden nach dem `READY_CHECK_FINISHED` oder kurz danach immer noch zu schnell.
- Beobachtung: Im UI sieht man die Farbbalken nur sehr kurz, obwohl der Hold laut Logik 20 Sekunden halten soll.
- Erwartung: Nach einem Readycheck sollen `ready` und `notready` als Hintergrundfarbe fuer die volle Hold-Zeit sichtbar bleiben.
- Vermutung: Ein spaeterer Refresh pflegt den Hold-State nicht mehr konsistent an die Rosterzeilen durch oder ueberschreibt ihn mit einem neutralen Render.
- Bisheriger Ansatz: Der 1-Sekunden-Ticker reassertet den Readycheck-State bereits, aber das Verhalten ist ingame noch nicht stabil genug.
- Naechster Schritt: Mit einem gezielten Live-Trace die genaue Stelle finden, an der der Hintergrund vor Ablauf der Hold-Zeit neutralisiert wird.
- Wichtiger Rahmen: Keine grosse Umbaustelle starten, zuerst den konkreten Ueberschreiber identifizieren.

## Hinweise

- Diese Datei ist absichtlich Teil des Git-Repos.
- Sie ist in `.pkgmeta` ausgeschlossen und darf nicht im CurseForge-Release landen.
