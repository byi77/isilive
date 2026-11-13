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
| `libs/LibEditMode/` | LibEditMode von Adrian L Lange (p3lim), https://github.com/p3lim-wow/LibEditMode, Release `19` (Commit `b4816be`, 2026-11-03), Namespace-Variante (`namespaced.lua` vor den Lib-Dateien, ohne LibStub) | "All rights reserved"; laut `libs/LibEditMode/LICENSE.txt` darf die Lib **unveraendert** zusammen mit anderen Werken als WoW-AddOn verteilt werden ("as long as the software is not modified in any way, except removing any files ... other than this license"). Eingebettet sind `LICENSE.txt`, `namespaced.lua`, `LibEditMode.lua`, `pools.lua` und `widgets/*.lua` byte-gleich zum Release; weggelassen sind `README.md`, `tests/`, `utils/`, Build-Dateien. Nie aendern, nur als Ganzes auf ein neues Release heben. |

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
| `media/flags/*.tga` | Am `2026-10-22` auf Benutzerwunsch als 32x24-RGBA-Abzeichen (abgerundet, Rahmen, Glanzverlauf) geometrisch neu erzeugt; reproduzierbar mit `python tools/generate_language_flags.py` (Pillow). Ersetzt die bisherigen 16x12-Eigenwerke des Maintainers | Projekteigene geometrische Gestaltung nach den amtlichen Flaggenmotiven, keine Drittvorlage |
| `media/corner_disc.tga`, `media/corner_ring6.tga`, `media/corner_shadow.tga` | Am `2026-11-03` fuer die abgerundeten Ecken des Modern-Designs geometrisch erzeugt (Viertelkreis, Viertelring und weicher Viertel-Schattenring, 32x32, weiss mit Alpha); reproduzierbar mit `python tools/generate_rounded_corners.py` (Pillow) | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/heart_bonus_green.tga` | Selbst erstellt vom Maintainer; bestaetigt `2026-07-22` | Eigenes Werk des Maintainers |
| `media/heart_sync.tga` | Selbst erstellt vom Maintainer; bestaetigt `2026-07-22` | Eigenes Werk des Maintainers |
| `media/diamond_bonus_green.tga`, `media/link_sync_blue.tga` | Am `2026-10-20` fuer den bestaetigten Benutzerentwurf geometrisch erzeugt; reproduzierbar mit `python tools/generate_utility_markers.py` (Pillow) | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/plus_bonus_green.tga` | Am `2026-10-20` auf Benutzerwunsch geometrisch erzeugtes Pluszeichen mit Leuchthof und Glanzkante; derselbe Generator | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/role_tank.tga`, `media/role_healer.tga`, `media/role_dps.tga` | Am `2026-10-22` auf Benutzerwunsch als Rollen-Badges (Schild, Kreuz, Schwert) im Stil der Sprachflaggen geometrisch erzeugt; reproduzierbar mit `python tools/generate_role_badges.py` (Pillow) | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/spec_mask.tga`, `media/spec_frame_tank.tga`, `media/spec_frame_healer.tga`, `media/spec_frame_dps.tga`, `media/spec_frame_none.tga` | Am `2026-11-13` auf Benutzerwunsch als Maske und Rahmen der Spec-Icons (Form, Glanz und Rand der Rollen-Badges) geometrisch erzeugt; derselbe Generator. Das Spec-Icon selbst liefert der Client zur Laufzeit, es wird nicht mitgeliefert | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/arrow_bonus_green.tga` | Selbst erstellt vom Maintainer; bestaetigt `2026-07-22`. Bewusst im Repository behalten | Eigenes Werk des Maintainers |

## Screenshots und Mockups

Repository-Screenshots und das Center-Notice-Mockup dokumentieren isiLive selbst
und werden nicht in das Addonpaket aufgenommen. Das Mockup ist unter
`tools/mockups/README.md` beschrieben.
