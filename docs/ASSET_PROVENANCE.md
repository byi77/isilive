# Herkunft gebuendelter Assets

Diese Datei dokumentiert die bekannte Herkunft und den Lizenzstand der im
oeffentlichen Repository gebuendelten Drittbibliotheken, Sounds und Texturen.
Unbekannte Zuordnungen bleiben ausdruecklich `unresolved`; sie werden nicht aus
Dateinamen, Metadaten oder Aehnlichkeiten abgeleitet.

Dokumentationsstand: `2026-07-22`.

Offen ist derzeit ausschliesslich die Einzelzuordnung der Sounddateien; die
Texturen sind seit `2026-07-22` als Eigenwerk des Maintainers geklaert.

## Quellcode von Dritten

| Pfad | Herkunft | Lizenzstatus |
| --- | --- | --- |
| `libs/ChatThrottleLib/ChatThrottleLib.lua` | ChatThrottleLib von Mikk; Herkunft und Autor stehen im Dateikopf | Public Domain laut Dateikopf |

## Sounds

Am `2026-10-20` wurden die zehn deutschen Sprachansagen durch lokal erzeugte,
synthetische Aufnahmen mit der vom Maintainer ausgewaehlten maennlichen
Stimme 6 ersetzt. Erzeugung: `Qwen/Qwen3-TTS-12Hz-1.7B-Base`, Revision
`fd4b254389122332181a7c3db7f27e918eec64e3`, anhand einer gespeicherten
synthetischen VoiceDesign-Referenz (keine zugeordnete reale Sprecheraufnahme).
Die genaue Zuordnung, Texte, Lautheitswerte und SHA256-Pruefsummen der
eingebauten Dateien stehen in `docs/AUDIO_ASSETS.json`. Referenz und
reproduzierbarer Ablauf sind im privaten Projekt-Workspace archiviert.
Fuer diese neuen Sprachdateien ist die Erzeugungsquelle damit geklaert;
eine gesonderte Lizenz fuer die erzeugten Aufnahmen ist hier nicht festgelegt.

Die sechs Effektdateien wurden aus den bisherigen Originalen nur in Lautheit
und Ausgabeformat angeglichen (`BttF_Tinkle.wav` jetzt `BttF_Tinkle.ogg`).
Ihre bisherige Herkunfts-/Lizenzluecke bleibt unveraendert. Unveraenderte
englische Ansagen und uebrige Altdateien fallen weiterhin unter den folgenden
historischen Herkunftsstand.

Der Maintainer hat am 2026-07-13 bestaetigt, dass die Sounddateien teilweise
selbst erstellt und teilweise aus anderen Quellen uebernommen wurden. Als
moegliche externe Herkunft wurde ein frueheres WeakAuras-Soundpaket genannt.
Welche konkrete Datei zu welcher Quelle gehoert und unter welcher Lizenz die
externen Dateien standen, ist derzeit nicht mehr belastbar zugeordnet.

| Pfade | Herkunft | Lizenzstatus |
| --- | --- | --- |
| `sounds/*.wav`, `sounds/*.ogg`, `sounds/*.mp3` | Mischung aus selbst erstellten und extern bezogenen Dateien; Einzelzuordnung `unresolved` | `unresolved` |

Pflegepflicht:

- Fuer jede geklaerte Datei exakten Urheber, Quelle, Lizenz und Pruefdatum
  eintragen.
- Keine Datei allein aufgrund ihres Namens als selbst erstellt oder frei
  verwendbar einstufen.
- Bei einer externen Quelle den direkten Herkunftsnachweis oder die damalige
  Lizenz dokumentieren.
- Kann die Nutzungserlaubnis einer externen Datei nicht belegt werden, muss vor
  einer erneuten Veroeffentlichung ueber Ersatz oder Entfernung entschieden
  werden.

## Texturen

Der Maintainer hat am `2026-07-22` bestaetigt, dass alle gebuendelten Texturen
selbst erstellt wurden. Damit ist dieser Abschnitt vollstaendig geklaert.

| Pfade | Herkunft | Lizenzstatus |
| --- | --- | --- |
| `media/flags/*.tga` | Selbst erstellt vom Maintainer; bestaetigt `2026-07-22` | Eigenes Werk des Maintainers |
| `media/heart_bonus_green.tga` | Selbst erstellt vom Maintainer; bestaetigt `2026-07-22` | Eigenes Werk des Maintainers |
| `media/heart_sync.tga` | Selbst erstellt vom Maintainer; bestaetigt `2026-07-22` | Eigenes Werk des Maintainers |
| `media/diamond_bonus_green.tga`, `media/link_sync_blue.tga` | Am `2026-10-20` fuer den bestaetigten Benutzerentwurf geometrisch erzeugt; reproduzierbar mit `python tools/generate_utility_markers.py` (Pillow) | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/plus_bonus_green.tga` | Am `2026-10-20` auf Benutzerwunsch geometrisch erzeugtes Pluszeichen mit Leuchthof und Glanzkante; derselbe Generator | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/arrow_bonus_green.tga` | Selbst erstellt vom Maintainer; bestaetigt `2026-07-22`. Bewusst im Repository behalten | Eigenes Werk des Maintainers |

## Screenshots und Mockups

Repository-Screenshots und das Center-Notice-Mockup dokumentieren isiLive selbst
und werden nicht in das Addonpaket aufgenommen. Das Mockup ist unter
`tools/mockups/README.md` beschrieben.
