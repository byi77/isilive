# Herkunft gebuendelter Assets

Diese Datei dokumentiert die bekannte Herkunft und den Lizenzstand der im
oeffentlichen Repository gebuendelten Drittbibliotheken, Sounds und Texturen.
Unbekannte Zuordnungen bleiben ausdruecklich `unresolved`; sie werden nicht aus
Dateinamen, Metadaten oder Aehnlichkeiten abgeleitet.

Dokumentationsstand: `2026-11-21`.

Offen ist derzeit ausschliesslich die Einzelzuordnung der sechs
Effekt-Sounddateien; die Sprachansagen sind seit `2026-11-21` vollstaendig
lokal erzeugt, die Texturen seit `2026-07-22` als Eigenwerk des Maintainers
geklaert.

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

Am `2026-11-21` wurden die zehn englischen Sprachansagen (`TankDied.ogg`,
`HealerDied.ogg`, `Portal.ogg`, `GroupInvite.ogg`, `GroupRemoved.ogg`,
`BattleRezReady.ogg`, `BloodlustSoon.ogg`, `BloodlustReady.ogg`,
`PowerInfusionReceived.ogg`, `PetStuck.ogg`) unter gleichem Dateinamen durch
lokal erzeugte, synthetische Aufnahmen ersetzt: dasselbe Modell
`Qwen/Qwen3-TTS-12Hz-1.7B-Base` (Revision
`fd4b254389122332181a7c3db7f27e918eec64e3`), dieselbe Stimme 6 und dieselbe
gespeicherte synthetische Referenz, Sprache Englisch. Am selben Tag kamen
vierzehn neue Sprachansagen fuer die Option "Sprache statt Effekt" (Regel 266)
hinzu, je englisch und deutsch mit demselben Modell und derselben Stimme 6:
`LeaderTransfer.ogg`/`LeaderTransfer_deDE.ogg`,
`GroupFull.ogg`/`GroupFull_deDE.ogg`,
`ReadyCheckComplete.ogg`/`ReadyCheckComplete_deDE.ogg`,
`BattleResUsed.ogg`/`BattleResUsed_deDE.ogg`,
`BloodlustUsed.ogg`/`BloodlustUsed_deDE.ogg`, `Aggro.ogg`/`Aggro_deDE.ogg`
und `MissedKick.ogg`/`MissedKick_deDE.ogg`. Texte, Lautheit und
SHA256-Pruefsummen stehen in `docs/AUDIO_ASSETS.json` (fortgeschrieben mit
`tools/update_audio_assets.py` aus dem Erzeugungsmanifest). Fuer alle
Sprachansagen ist die Erzeugungsquelle damit geklaert; eine gesonderte Lizenz
fuer die erzeugten Aufnahmen ist hier nicht festgelegt.

Am `2026-11-21` wurden ausserdem 58 nie getrackte, ungenutzte Altdateien aus
dem lokalen Arbeitsordner `sounds/` entfernt und im privaten Workspace unter
`research/isilive-audio/ungenutzt-entfernt-2026-11-21` archiviert. Sie waren
nie Teil des Repositorys oder eines Addonpakets. Seitdem prueft
`tools/check_sound_assets.lua`, dass `sounds/` nur Dateien enthaelt, die die
Sound-Registry referenziert.

Die sechs Effektdateien wurden aus den bisherigen Originalen nur in Lautheit
und Ausgabeformat angeglichen (`BttF_Tinkle.wav` jetzt `BttF_Tinkle.ogg`).
Ihre bisherige Herkunfts-/Lizenzluecke bleibt unveraendert; sie fallen
weiterhin unter den folgenden historischen Herkunftsstand.

Der Maintainer hat am 2026-07-13 bestaetigt, dass die Sounddateien teilweise
selbst erstellt und teilweise aus anderen Quellen uebernommen wurden. Als
moegliche externe Herkunft wurde ein frueheres WeakAuras-Soundpaket genannt.
Welche konkrete Datei zu welcher Quelle gehoert und unter welcher Lizenz die
externen Dateien standen, ist derzeit nicht mehr belastbar zugeordnet.

| Pfade | Herkunft | Lizenzstatus |
| --- | --- | --- |
| `sounds/CartoonVoiceBaritone.ogg`, `sounds/SynthChord.ogg`, `sounds/BttF_Tinkle.ogg`, `sounds/ChickenAlarm.ogg`, `sounds/RoosterChickenCalls.ogg`, `sounds/BoxingArenaSound.ogg` | Effektdateien aus der historischen Mischung selbst erstellter und extern bezogener Dateien; Einzelzuordnung `unresolved` | `unresolved` |
| alle uebrigen `sounds/*.ogg` (Sprachansagen deutsch und englisch) | Lokal erzeugt mit `Qwen/Qwen3-TTS-12Hz-1.7B-Base`, Stimme 6 (deutsch `2026-10-20` bzw. `2026-11-21`, englisch `2026-11-21`); Einzelwerte in `docs/AUDIO_ASSETS.json` | Erzeugungsquelle geklaert; keine gesonderte Lizenz festgelegt |

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
| `media/defensive_clock.tga`, `media/defensive_border.tga` | Am `2026-11-22` fuer die Defensiv-Spalte (Regel 269) geometrisch erzeugt; reproduzierbar mit `python tools/generate_utility_markers.py` (Pillow) | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/plus_bonus_green.tga` | Am `2026-10-20` auf Benutzerwunsch geometrisch erzeugtes Pluszeichen mit Leuchthof und Glanzkante; derselbe Generator | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/role_tank.tga`, `media/role_healer.tga`, `media/role_dps.tga` | Am `2026-10-22` auf Benutzerwunsch als Rollen-Badges (Schild, Kreuz, Schwert) im Stil der Sprachflaggen geometrisch erzeugt; reproduzierbar mit `python tools/generate_role_badges.py` (Pillow) | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/spec_mask.tga`, `media/spec_frame_tank.tga`, `media/spec_frame_healer.tga`, `media/spec_frame_dps.tga`, `media/spec_frame_none.tga` | Am `2026-11-13` auf Benutzerwunsch als Maske und Rahmen der Spec-Icons (Form, Glanz und Rand der Rollen-Badges) geometrisch erzeugt; derselbe Generator. Das Spec-Icon selbst liefert der Client zur Laufzeit, es wird nicht mitgeliefert | Projekteigene geometrische Gestaltung, keine Drittvorlage |
| `media/arrow_bonus_green.tga` | Selbst erstellt vom Maintainer; bestaetigt `2026-07-22`. Bewusst im Repository behalten | Eigenes Werk des Maintainers |

## Screenshots und Mockups

Repository-Screenshots und das Center-Notice-Mockup dokumentieren isiLive selbst
und werden nicht in das Addonpaket aufgenommen. Das Mockup ist unter
`tools/mockups/README.md` beschrieben.
