# Store-Material Neon Frosh (1.0.0), öffentliche Veröffentlichung

Vom Agenten vorbereitet, von dir geprüft und hochgeladen. "Nicht verifiziert" heißt: keine Quelle in der
SDK-Dokumentation oder auf Garmins Seiten, oder ohne Login nicht einsehbar. Feldnamen im Upload-Formular können
leicht abweichen. Es gibt keine Beta-Version (Entscheidung: nur öffentlich).

## 0. Einmalig, vor der ersten Veröffentlichung
1. Garmin-Entwicklerkonto anlegen (Garmin Developer Agreement).
2. Entwicklerschlüssel `~/.garmin/developer_key.der` an mehreren Orten außerhalb des Projekts sichern. Jedes Update
   muss mit demselben Schlüssel signiert werden; ohne ihn gibt es keine Updates mehr.

## 1. Test auf deiner Uhr (empfohlen vor dem Upload)
1. Datei: `bin/fr165.prg` (`scripts/install-watch.sh fr165`), nach `GARMIN/APPS/` auf der Uhr kopieren, Ziffernblatt wählen.
2. Prüfen (Abschnitt 3 ohne die Handy-Einstellungen; die gibt es erst nach Store-Installation).
3. Die USB-Version danach von der Uhr löschen, bevor das Store-Ziffernblatt installiert wird.

## 2. Paket hochladen
1. Datei: `bin/store/NeonFrosh.iq` (App-ID `d064acde-a932-42bf-a3d8-7acf2462dcb8`, aus `manifest.xml`), 59 runde Uhren.
2. Entwicklerseite "Submit an App" (Connect IQ Developer), Datei hochladen. **Kein** Häkchen bei "Beta App".
3. Version: `1.0.0`.
4. Prüfen, dass `bin/store/NeonFrosh.iq` nach dem letzten Code-Stand gebaut wurde (Änderungsdatum, danach
   `tar -xOf bin/store/NeonFrosh.iq manifest.xml | grep -o '<iq:application[^>]*'` zeigt die ID oben).

## 3. Was auf der Uhr zu prüfen ist
- Zeit (12/24 h), Datum in der Uhrsprache, Akku- und Bluetooth-Symbol, Farbwechsel für Farbe 1 und 2, hell/dunkel.
- Alle sechs Felder mit verschiedenen Datenarten; fehlende Werte zeigen `--`.
- AMOLED: Always-on-Ansicht (nur weiße Umrisszeit, wandert minütlich leicht); MIP: normales Ziffernblatt.
- Touchscreen-Uhren: ein Feld gedrückt halten öffnet die passende Ansicht (Puls, Schritte, Wetter ...); bei Schwimmen, Klettern, Training passiert nichts.
- Einstellungen in der Handy-App (jede Option erscheint, Änderungen kommen auf der Uhr an) und im Menü auf der Uhr.

## 4. Welche Datei in welches Feld

| Datei | Inhalt | Feld im Store |
|---|---|---|
| `icon_500.png` | App-Icon, 500 x 500 px, sRGB, ohne Alpha, einfarbiger Hintergrund, ohne Text | Icon |
| `screenshot_01_overview.png` | Übersicht mit Beschriftungen | Screenshots (Reihenfolge 01 bis 05) |
| `screenshot_02_backgrounds.png` | Dunkel und hell | Screenshots |
| `screenshot_03_colors.png` | Farbvarianten | Screenshots |
| `screenshot_04_fields.png` | Auswahl der Datenfelder, Hinweis auf Gedrückt-halten | Screenshots |
| `screenshot_05_always_on.png` | Always-on-Ansicht | Screenshots |
| `hero_1440x720.png` | Hero-Bild, 1440 x 720 px (optional) | Hero image |
| `listing_en.md` | Name, Kurz- und Langbeschreibung, Neu in 1.0.0, Berechtigungen (Englisch) | Texte der Sprache English |
| `listing_de.md` | dasselbe auf Deutsch | Texte der Sprache Deutsch |

Aus den `listing_*.md` nur die Codeblöcke kopieren, die Hinweiszeilen oben bleiben draußen. Bei Screenshots
ggf. nur 4 hochladen, falls das Formular weniger zulässt (dann 05 weglassen).

## 5. Dateigrößen und Format
Icon 500 x 500 RGB (kein Alpha); Screenshots 1024 x 1024, indizierte PNG, jeweils unter 150 KB; Hero 1440 x 720.
Aktuelle Größen: `ls -l design/store/*.png`.

## 6. Nicht verifiziert
- Das Upload-Formular selbst (nur nach Login sichtbar): Feldnamen, Pflichtfelder, Sprachumschaltung, ob mehr als
  vier Screenshots möglich sind.
- Die Größenlimits (150 KB je Screenshot, 300 KB Icon) stammen aus Forenangaben, nicht von Garmin; das Hero-Limit
  (2048 KB) vom Formular.
- Der Store könnte die Beschreibungen kürzen, wenn ein Textfeld ein Zeichenlimit hat; Kurzbeschreibung ist knapp gehalten.
- Die Screenshots zeigen die Simulator-Ausgabe auf der größten Anzeige (466 px) mit Demo-Werten (10:08, 29. August,
  17 °C, 82, 76, 171, 3.420); die Symbole entsprechen dem Stand der Aufnahme (zweite Runde, neue Wetter-Symbole). Wurde danach
  an der Darstellung etwas geändert, müssen die Bilder neu erzeugt werden (Werkzeug in `design/drafts/store_tools/`).
- Echtgerät: nichts davon wurde auf einer echten Uhr geprüft.

## 7. Nach der Veröffentlichung
- Absturzberichte: ERA-Viewer der SDK-Werkzeuge.
- Updates: neue `.iq`, gleicher Schlüssel, höhere Versionsnummer.
- Bilder neu machen: Aufnahmen in `design/drafts/captures/` ersetzen (Anleitung im Kopf von
  `design/drafts/store_tools/main.swift`), dann neu kompilieren und ausführen.
