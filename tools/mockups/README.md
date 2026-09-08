# Entwicklungs-Mockups

## M+-Designstudie

`mplus_modern_preview.html` ist eine eigenstaendige lokale HTML-Vorschau fuer
eine ruhigere M+-Hauptansicht. Im Browser oeffnen; Vorschaugroesse, Deckkraft
und Readycheck-Darstellung lassen sich direkt ausprobieren.

Die Studie orientiert sich an der 500-Pixel-Ansicht und der 272-Pixel-Basishoehe
aus `ui/isiLive_roster_layout.lua` sowie den Spalten aus
`ui/isiLive_roster_panel_chrome.lua`. Sie ist kein pixelgenauer Runtime-Nachbau.
Alle Spieler und Spielwerte sind ausschliesslich gestalterische Demodaten;
der Timerbereich folgt dem vom Benutzer gezeigten Screenshot: ein eigener
BR/BL-Rahmen mit Zaubericons links, rechts M+, farbig hinterlegte +3/+2/+1
und der Todeszaehler. Die inaktiven Werte erscheinen wie dort als Striche.
Die Rahmen und Flaechen sind an die kuehle Farbpalette angepasst; die
Kennungen verwenden normale Schriftstaerke. Die BR/BL-Icons stammen aus
derselben unten genannten Quelle fuer die Runtime-Zauber 20484 und 2825.
Rollen- und Statusicons sind schematische Platzhalter. Die Portalbilder sind
die Dungeon-Icons der acht Portalzauber aus dem Saisonmanifest, als JPEG-Daten
direkt in die HTML-Datei eingebettet. Die Kuerzel KR, TVS, RLB, DBT, ADL,
NB, MG und ADF stehen entsprechend der Benutzer-Bildreferenz gross, weiss
und mittig ueber den Icons, ohne separate Beschriftungsleiste. Alle Texte
verwenden denselben Schriftstapel Segoe UI/Arial/sans-serif; die Portaltexte
erben ihn. Die Runtime verwendet WoW-Schriftobjekte wie GameFontNormal.
Eine identische Spielschrift im Browser bleibt offen, solange deren
browserfaehige Schriftdatei nicht vorliegt.
Die Zuordnung wurde am 08.09.2026 ueber
`https://nether.wowhead.com/tooltip/spell/{spellID}` abgerufen (1286831,
1286828, 393256, 1286801, 1286804, 1286807, 1286809, 1286812).
Bildquelle: `https://wow.zamimg.com/images/wow/icons/large/{icon}.jpg`.
Die Blizzard-Spielgrafiken dienen ausschliesslich dieser Entwicklungsvorschau;
es wird keine eigene Urheberschaft oder zusaetzliche Lizenz behauptet.
Die Portalnamen stammen aus dem Saisonmanifest. Die ausklappbare Bildreferenz
`../../isiLive_MPlus_ui.png` ist historisch und kein aktueller Vorher-Vergleich.

Die Vorschau benoetigt keine externen Bibliotheken, Fonts oder Netzwerkdienste.
Sie schreibt keine Einstellungen und greift nicht auf WoW oder SavedVariables
zu. Der gesamte Ordner `tools/` ist durch `.pkgmeta` und den Release-Workflow
vom Addonpaket ausgeschlossen. Es gibt keine TOC-Einbindung.

## Center-Notice-Mockup

`center_notice_preview.html` ist ein oeffentliches, rein statisches
Entwicklungs-Mockup fuer die Center-Notice-Gestaltung. Es ist kein Runtime-Code
und wird nicht in das Addonpaket aufgenommen.

Verwendung:

1. Repository lokal auschecken.
2. `tools/mockups/center_notice_preview.html` im Browser oeffnen.
3. Layoutideen gegen die echte WoW-Umsetzung in `ui/isiLive_notice.lua`
   vergleichen.

Das Mockup verwendet `isiLive_M_ui.png` als lokalen Hintergrund. Deshalb bleibt
diese Bilddatei als dokumentierte Mockup-Abhaengigkeit im oeffentlichen
Repository.
