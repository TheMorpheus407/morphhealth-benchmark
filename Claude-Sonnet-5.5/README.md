# MorphHealth

MorphHealth ist eine Android-App (Flutter) für den Alltag: ein Ernährungstagebuch mit echtem Zugriff auf Open Food
Facts, ein persönlicher Periodentracker mit nachvollziehbarer Prognose, Gewicht und Symptome. Alle Daten liegen
verschlüsselt auf dem Gerät. Es gibt kein Konto, keine Werbung, keine Telemetrie und keine Laufzeit-KI. Die
Oberfläche ist auf Deutsch (Voreinstellung) und Englisch bedienbar.

Dieses Dokument beschreibt Bedienung, Build und Start, den lokalen Wartungszugang `./mh`, die Datenformate, die
wesentlichen Entscheidungen, die tatsächlich ausgeführten Tests und die bekannten Grenzen. Das Sicherheitskonzept
steht in [`SECURITY.md`](SECURITY.md).

## 1. Lieferumfang

| Pfad | Inhalt |
|---|---|
| `app/` | Flutter-Quellen (`app/lib/main.dart` als Einstieg), Android-Projekt, Übersetzungen (`lib/l10n/*.arb`), Tests, `pubspec.lock` |
| `artifacts/morphhealth.apk` | Release-APK, Package `de.themorpheus.morphhealth.local`, `x86_64` und `arm64-v8a` |
| `artifacts/mh-cli` | Ahead-of-time übersetztes Kommandozeilenprogramm, das `mh` ausführt |
| `artifacts/screenshots/` | Bildschirmfotos vom Referenzgerät, erzeugt vom Gerätetest |
| `build.sh` | baut APK und Kommandozeilenprogramm (`./build.sh [all\|apk\|cli]`) |
| `check.sh` | Formatierung, Analyse, Tests, Build, Wartungszugang und Gerätetest |
| `mh` | Starter des Wartungszugangs (JSON Lines) |
| `tools/` | `cli_e2e.py` (Ende-zu-Ende-Prüfung von `mh`), `device_smoke.py` (Gerätetest per adb) |
| `README.md`, `SECURITY.md` | diese Dokumentation und das Sicherheitskonzept |

`SPEC.md` und `ENVIRONMENT.json` sind unverändert. Die Build-Zwischenstände (`app/build`, `app/.dart_tool`, rund
750 MB) gehören nicht zur Abgabe; `build.sh` und `check.sh` erzeugen sie bei Bedarf neu.

## 2. Bedienung

Unten liegt die Navigation mit fünf Zielen: **Übersicht**, **Ernährung**, **Zyklus**, **Gewicht**, **Symptome**.
Auf breiten Bildschirmen (ab 720 dp) wird daraus eine Navigationsleiste am Rand. Die Bereiche sind unabhängig
voneinander nutzbar; in der Übersicht lassen sich alle vier Bereiche ein- und ausblenden.

### Übersicht

- Tageswahl (zurück, vor, Datum antippen für den Kalender, „Heute“) und Umschalter **Tag / 7 Tage / 28 Tage**.
- Je sichtbarem Bereich eine Karte mit dem Wichtigsten und den häufigen Erfassungen: Wasser (150, 250, 330, 500 ml),
  „Lebensmittel hinzufügen“, „Periode beginnt/endet heute“, „Gewicht erfassen“, „Symptom erfassen“.
- **Tagesdetail** führt Ernährung, Wasser und Koffein, Gewicht, Periodenaufzeichnungen und Symptome eines Tages
  zusammen und erlaubt überall das Bearbeiten.
- Symbole oben: **Historie** (Suche), **Bereiche anpassen**, **Einstellungen**.

### Ernährung

- **Tagebuch**: Tagessumme (kcal, Protein, Kohlenhydrate, Fett; mit Fortschritt zu freiwilligen Zielen), Wasser,
  vier Mahlzeiten (Frühstück, Mittagessen, Abendessen, Snack) und Koffein. „Alle Nährwerte“ zeigt die Tagessumme aller
  31 Nährstoffe mit der Angabe, in wie vielen Einträgen ein Wert vorlag.
- **Lebensmittel hinzufügen**: Reiter *Suche* (nach **Name** oder **Barcode-Nummer** in Open Food Facts), *Zuletzt*,
  *Favoriten* und *Eigene*. Ein Treffer öffnet das Eintragsformular: Menge in **g, ml oder Portionen**, Mahlzeit, Datum
  und Uhrzeit, Notiz, Vorschau der Nährwerte für genau diese Menge, ein Stern für Favoriten.
- **Eigene Lebensmittel** haben Name, Marke, Barcode, Bezug (je 100 g oder je 100 ml), Portionsgröße und alle Nährwerte:
  Energie, Protein, Kohlenhydrate, Fett, gesättigte Fettsäuren, Zucker, Ballaststoffe, Salz, Natrium, Koffein, die
  Vitamine A, C, D, E, K, B1, B2, B3, B5, B6, B7, B9, B12 und Kalzium, Eisen, Magnesium, Kalium, Zink, Selen, Jod,
  Phosphor. Sie sind jederzeit bearbeitbar.
- **Einträge** lassen sich antippen und korrigieren; im Menü stehen *Bearbeiten*, *Erneut erfassen* und *Löschen*
  (mit „Rückgängig“). Ein Eintrag aus Open Food Facts lässt sich als eigenes Lebensmittel kopieren.
- **Wasser**: Schnellerfassung (150, 250, 330, 500 ml) und „Andere Menge“. **Koffein** zusätzlich zum Koffein aus
  Lebensmitteln.
- **Verlauf**: 7 oder 28 Tage, ein auswählbarer Nährstoff (oder Wasser) als Balkendiagramm mit Ziellinie, Durchschnitt,
  niedrigstem und höchstem Wert. Jeder Balken hat eine Beschriftung für Screenreader.
- **Tagesziele** (Wasser, Kalorien, Protein, Kohlenhydrate, Fett) sind freiwillig: Einstellungen → Tagesziele.

### Zyklus

- **Einschätzung** mit nächstem voraussichtlichem Beginn, Zeitfenster, Verlässlichkeit und der Frage „Wie kommt die
  Einschätzung zustande?“ (Erklärung in Klartext mit den verwendeten Abständen).
- **Periode beginnt heute / endet heute** als Schnellaktion; **Periode erfassen** für frühere Perioden mit Beginn, Ende,
  Blutungsstärke (Spotting, leicht, mittel, stark, auch je Tag) und Notiz. Perioden sind änderbar und löschbar.
- **Kalender** (Monat wählen, ältere Monate erreichbar) mit Periodentagen, Voraussage, Zeitfenster und Markierung für
  Tage mit Symptomen; **Historie** als Liste. Ein Tag im Kalender führt in den Tageskontext mit Blutungsstärke und Symptomen.
- Wer den Bereich nur als Tagebuch nutzen will, schaltet unter Einstellungen die Prognose aus.

### Gewicht und Symptome

- **Gewicht**: Einträge für ein gewähltes Datum, in kg oder lb (Einstellung), bearbeiten und löschen, Verlauf über
  7, 28, 90 Tage oder alles. Intern speichert die App Kilogramm.
- **Symptome**: frei wählbarer Name, Intensität 0 bis 10, Datum und Uhrzeit, optionale Notiz; bearbeiten und löschen.
  Der Reiter *Verlauf* zeigt ein gewähltes Symptom über die Zeit.

### Historie

Über die Suche in der Übersicht und in jedem Bereich: durchsuchbar über alle vier Bereiche mit den Filtern
**Datumsbereich** (Vorgaben 7, 28, 90 Tage oder frei), **Bereich** und **Freitext** (jedes Wort muss vorkommen; gesucht
werden Namen, Notizen, Marken, Barcodes, Mahlzeiten). Ein Treffer öffnet den Eintrag zum Bearbeiten.

### Einstellungen

Sprache (Deutsch, English), Darstellung (System, Hell, Dunkel), Gewichtseinheit, Bereiche der Übersicht, Tagesziele,
Zyklus (Prognose, erwartete Zykluslänge), Open Food Facts (an/aus, Serveradresse), „Bildschirmaufnahmen sperren“, **Daten
und Sicherung**, Über MorphHealth, Open-Source-Lizenzen.

**Daten und Sicherung**: JSON-Export (unverschlüsselt, mit Warnung), JSON-Import (ersetzt den Bestand nach
Bestätigung und Vorschau), verschlüsselte Sicherung mit Passphrase, Wiederherstellung (auch auf einer frischen
Installation) und „Alle lokalen Daten löschen“. Die Dateiauswahl übernimmt Android.

### Barrierefreiheit

Alle Bedienelemente haben Beschriftungen für Screenreader, Tippflächen mindestens 48 dp, Kontraste nach WCAG in
hellem und dunklem Thema, Schrift bis 200 % ohne Überläufe, Ansicht im Quer- und Hochformat, Diagramme mit einzeln
beschrifteten Balken. Gruppen von Bedienelementen sind eigene Knoten, sodass Fokus und Reihenfolge der visuellen
Anordnung folgen.

## 3. Build und Start

Voraussetzungen (siehe `ENVIRONMENT.json`): Flutter 3.41.9 mit Dart 3.11.5, Android-SDK 36 mit Build-Tools 36.1.0,
JDK für Gradle (die JetBrains Runtime 21 aus Android Studio, von Flutter gewählt), Python 3 für die Prüfskripte.

```bash
./build.sh            # APK und Kommandozeilenprogramm (Standard: all)
./build.sh apk        # nur artifacts/morphhealth.apk
./build.sh cli        # nur artifacts/mh-cli
./check.sh            # alles prüfen (mit Gerätetest, einige Minuten)
./check.sh --quick    # ohne Build und ohne Gerät
./check.sh --require-device   # ein nicht erreichbarer Emulator zählt als Fehler
```

`build.sh` liest `food_api_base_url` und `food_api_user_agent` aus `ENVIRONMENT.json` und übergibt sie als
`--dart-define` (`MH_FOOD_BASE_URL`, `MH_FOOD_USER_AGENT`). Die Umgebungsvariablen gleichen Namens haben Vorrang. Die
Abhängigkeiten sind mit `pubspec.lock` gesperrt (`flutter pub get --enforce-lockfile`). Die Release-APK ist mit
dem Debug-Schlüssel signiert (kein Store-Schlüssel vorhanden).

Installieren und starten auf dem Referenzgerät:

```bash
ADB=/home/morpheus/Android/Sdk/platform-tools/adb
$ADB -s emulator-5560 install -r artifacts/morphhealth.apk
$ADB -s emulator-5560 reverse tcp:8788 tcp:8788      # Zugang zum Lebensmittelendpunkt vom Gerät aus
$ADB -s emulator-5560 shell am start -n de.themorpheus.morphhealth.local/.MainActivity
```

Der Emulator erreicht `https://localhost:8788` nur über `adb reverse`; die Organisatoren richten das ein. Das
Zertifikat des Endpunkts vertraut das Android-System, die App schaltet die Prüfung nirgends ab. Auf dem
Referenzemulator darf `adb root` nicht laufen: Der Neustart von `adbd` verwirft die Weiterleitungen, danach zeigt die
App bei der Online-Suche „Keine Verbindung“, bis `adb reverse tcp:8788 tcp:8788` erneut gesetzt ist. Der Gerätetest
prüft die Weiterleitung und setzt sie bei Bedarf selbst.

## 4. Lebensmitteldienst (Open Food Facts)

Die App fragt ausschließlich lesend an (`GET`):

```text
{base}/api/v3.6/product/{barcode}.json?fields=...
{base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20&fields=...
```

- **Ursprung ({base})**: Vorrang hat die Einstellung „Server der Lebensmittel-API“ (App) beziehungsweise
  `--food-base-url` (Wartungszugang), dann die Vorgabe des Builds aus `ENVIRONMENT.json`, sonst
  `https://world.openfoodfacts.org`. Es gilt nur `https://host[:port]`. Ein anderer Ursprung desselben Vertrags läuft
  ohne Änderung der Fachlogik. Der Ursprung wird nirgends im Fachcode festgeschrieben.
- **User-Agent**: `food_api_user_agent` aus der Umgebung beziehungsweise `--food-user-agent`.
- **Übertragen** wird nur der Suchbegriff oder die Barcode-Nummer (Seite, Feldliste, User-Agent). Produktbilder werden
  nicht geladen. Die Suche lässt sich in den Einstellungen ausschalten.
- **Auswertung** eines Produkts (beide Schemata werden verstanden):
  - Neues Schema (`nutrition.input_sets`, `nutrition.aggregated_set`): bevorzugt ein Satz „wie verkauft“ je 100 g
    oder 100 ml aus den Quellen `manufacturer` oder `packaging`, danach je Portion (auf 100 g umgerechnet), danach
    „zubereitet“; Schätzungen (`source: estimate`) werden nie verwendet; fehlende Werte ergänzen weitere
    angegebene Sätze derselben Art. Ohne Angaben dient der aggregierte Satz.
  - Klassisches Schema (`nutriments`): `<name>_100g`.
  - Getränke (Angabe in ml) beziehen sich auf 100 ml, sonst auf 100 g. Energie in kJ wird in kcal umgerechnet
    (÷ 4,184). Gramm-Angaben werden für Mineralstoffe und Vitamine in mg oder µg umgerechnet.
  - Die Portionsgröße stammt aus `serving_quantity` oder wird aus `serving_size` gelesen.
- **Fehler** erhalten stabile Codes: `offline`, `timeout`, `tls`, `rate_limited`, `http_error`, `not_found`,
  `bad_response`, `invalid_barcode`, `empty_query`, `disabled`. Die App zeigt sie verständlich mit „Erneut versuchen“
  an, das Tagebuch bleibt nutzbar.

## 5. Wartungszugang `./mh`

```text
./mh --data-dir ABS --key-file ABS [--now RFC3339]
     [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]
```

Ein eigener Linux-Prozess ohne Netzwerkdienst. Er ruft dieselben Funktionen auf wie die App: Der gesamte Fachkern
(`app/lib/core`, reines Dart) wird von der Android-App und von `bin/mh.dart` gemeinsam verwendet. Es gibt keine
zweite Implementierung.

- `--data-dir`: persistenter Arbeitsdatenbestand, wird angelegt. Er enthält die verschlüsselten Dateien
  `store.mhs`, `store.mhj` und `store.lock` im selben Format wie auf dem Gerät.
- `--key-file`: genau **32 rohe Byte**, außerhalb des Datenverzeichnisses. Diese Bytes sind der Hauptschlüssel;
  daraus leitet der Kern per HKDF-SHA-256 den AES-256-GCM-Schlüssel ab (SECURITY.md, Abschnitt 3). Beispiel:
  `head -c 32 /dev/urandom > key.bin`. Ein falscher Schlüssel ergibt `wrong_key`, eine Datei falscher Länge ebenfalls.
- `--now`: setzt die fachliche Uhr des Prozesses (RFC 3339). Sie bestimmt „heute“ und `exported_at` und wird in die
  Ortszeit des Prozesses (`TZ`) umgerechnet. Ohne die Option gilt die Systemuhr.
- Ohne `artifacts/mh-cli` startet `mh` ersatzweise den Quelltext mit `dart run` (langsamer, mit Hinweis auf stderr).

**Protokoll.** Je Zeile eine JSON-Anfrage auf stdin, je Zeile eine Antwort auf stdout, sofort geleert. Es gibt kein
Banner auf stdout (Diagnose nur auf stderr). EOF beendet den Prozess. Anfragen werden der Reihe nach bearbeitet.

```json
{"request_id": 1, "op": "nutrition.day", "date": "2026-09-28"}
{"request_id": 1, "ok": true, "data": {...}}
{"request_id": 2, "ok": false, "error": {"code": "invalid_argument", "message": "...", "details": ...}}
```

`request_id` ist ein beliebiger JSON-Wert und wird unverändert zurückgegeben (bei unlesbarer Zeile `null`).
Startfehler (falscher Schlüssel, beschädigter Bestand) beantwortet der Prozess je Anfrage mit dem Fehlercode,
`describe` funktioniert immer.

| `op` | Eingabe | Ergebnis in `data` |
|---|---|---|
| `describe` | – | Beschreibung aller Operationen, Fehlercodes, Datenformate, 31 Nährstoffschlüssel, ein gültiges **Beispieldokument** für den Import, Beispielanfragen und live gerechnete Beispielergebnisse |
| `portable.export` | `ack_plaintext: true` | das vollständige Exportdokument (Abschnitt 6) |
| `portable.import` | `document`, `confirm_replace: true` | Ergebnisbericht: `replaced`, `imported` (je Abschnitt), `total_records`, `settings_imported`, `goals_imported`, `warning_count`, `warnings` |
| `nutrition.day` | `date` (`YYYY-MM-DD`) | Ernährungsangaben des Tages, wie die App sie ausgibt (unten) |
| `cycle.forecast` | `on` (`YYYY-MM-DD`) | persönliche Zykluseinschätzung für diesen Betrachtungstag (unten) |
| `food.search` | `q`, `page` (ab 1) | `query`, `page`, `page_size` (20), `total`, `has_more`, `results` (Lebensmittel je 100 g/ml) |
| `food.lookup` | `barcode` (8 bis 14 Ziffern) | `food`, `nutrition_source`, `barcode` |

`portable.export` ohne `ack_plaintext: true` ergibt `ack_required`, `portable.import` ohne `confirm_replace: true`
ergibt `confirm_required`. Ein ungültiges Dokument ergibt `invalid_document` mit `details` als Liste aus `path` und
`message`; der Bestand bleibt unverändert. Weitere Codes: `invalid_json`, `invalid_request`, `unknown_op`,
`invalid_argument`, `wrong_key`, `corrupt`, `locked`, `store_error`, `disabled`, `invalid_base_url`, `invalid_barcode`,
`empty_query`, `not_found`, `offline`, `timeout`, `tls`, `rate_limited`, `http_error`, `bad_response`,
`internal_error`. `describe` listet alle mit Bedeutung.

**`nutrition.day`** liefert unter anderem:

| Feld | Bedeutung |
|---|---|
| `date`, `entry_count` | Tag und Zahl der Verzehreinträge |
| `totals` | Tagessumme aller 31 Nährstoffe (Schlüssel wie im Export, mit Einheit im Namen, etwa `energy_kcal`, `iron_mg`, `vitamin_b12_ug`); `caffeine_mg` enthält auch zusätzlich erfasstes Koffein; 0, wenn nichts erfasst wurde |
| `entries_with_data` | je Nährstoff die Zahl der Einträge mit Angabe (0 heißt „unbekannt“, nicht „Wert 0“) |
| `water_ml`, `caffeine` | Wassersumme und Koffein `{total_mg, from_foods_mg, additional_mg}` |
| `meals` | vier Mahlzeiten mit `entry_count` und Summen für Energie, Protein, Kohlenhydrate, Fett |
| `entries` | Einträge mit Zeit, Name, Menge, `amount_base` (g oder ml) und den Nährwerten dieses Eintrags |
| `goals`, `goal_progress` | freiwillige Ziele und je Ziel `value`, `goal`, `remaining`, `percent` |

Nährwerte eines Eintrags = Nährwerte je 100 g/ml × Menge in g/ml ÷ 100; bei Portionen ist die Menge
`amount × food.serving.amount`. Weicht die Einheit des Eintrags von der Bezugsgröße des Lebensmittels ab, gilt
1 ml = 1 g. Summen werden vor dem Runden gebildet; Werte sind auf vier Nachkommastellen gerundet.

**`cycle.forecast`** liefert unter anderem `status` (`no_data`, `insufficient_data`, `in_period`, `predicted`, `overdue`,
`stale`, `disabled`), `predicted_start`, `window_earliest`, `window_latest`, `days_until_predicted`, `days_overdue`,
`cycle_day`, `period_day`, `average_cycle_length_days`, `cycle_length_std_days`, `cycle_lengths_used`,
`cycle_intervals` (mit `used` und `excluded_reason`), `upcoming` (drei weitere Beginne), `confidence`, `rules` und
`explanation` (`de` und `en`, Liste von Absätzen). Das Verfahren steht in Abschnitt 7.

Beispiel (Ausschnitt; `describe` liefert das komplette Beispieldokument):

```bash
cd "$(mktemp -d)" && head -c 32 /dev/urandom > key.bin
{
  echo '{"request_id":1,"op":"describe"}'
} | /pfad/zu/mh --data-dir "$PWD/data" --key-file "$PWD/key.bin" --now 2026-09-29T10:00:00+02:00 \
  | python3 -c 'import sys,json; d=json.loads(sys.stdin.readline()); json.dump(d["data"]["example_import_document"], open("doc.json","w"))'
python3 - <<'EOF' | /pfad/zu/mh --data-dir "$PWD/data" --key-file "$PWD/key.bin" --now 2026-09-29T10:00:00+02:00
import json
doc = json.load(open("doc.json"))
print(json.dumps({"request_id": 2, "op": "portable.import", "confirm_replace": True, "document": doc}))
print(json.dumps({"request_id": 3, "op": "nutrition.day", "date": "2026-09-28"}))
print(json.dumps({"request_id": 4, "op": "cycle.forecast", "on": "2026-09-20"}))
EOF
```

Für das Beispieldokument ergibt `nutrition.day` für den 28.09.2026 unter anderem `energy_kcal` 521,79,
`protein_g` 18,9, `caffeine_mg` 113 und `water_ml` 750; `cycle.forecast` für den 20.09.2026 ergibt `predicted` mit
`predicted_start` 2026-09-28 und dem Zeitfenster 27.09. bis 29.09.

## 6. Datenformate

### Exportdokument (`morphhealth-portable`, Version 1)

Ein JSON-Objekt. `portable.export` und der Export in der App erzeugen es; `portable.import` und der Import in der App
lesen es. `describe` enthält dieselbe Beschreibung maschinenlesbar samt Beispieldokument.

| Abschnitt | Inhalt |
|---|---|
| `format`, `version` | `"morphhealth-portable"`, `1`. `exported_at` (RFC 3339) und `app` sind nur Information |
| `settings` | `language` (de, en), `weight_unit` (kg, lb), `areas` {nutrition, cycle, weight, symptoms}, `online_food`, `cycle_forecast`, `expected_cycle_length_days` (15 bis 60 oder null), `theme` (system, light, dark), `secure_screen` |
| `goals` | `water_ml`, `energy_kcal`, `protein_g`, `carbohydrates_g`, `fat_g` (null = kein Ziel) |
| `foods` | Bibliothek: `id`, `name`\*, `brand`, `barcode`, `source` (custom, off), `basis` (g, ml), `serving` {`amount`>0 in der Bezugseinheit, `label`}, `nutrients`, `favorite`, `prepared`, `created_at` |
| `food_entries` | `id`, `at`\*, `meal` (breakfast, lunch, dinner, snack), `amount`\*>0, `unit` (g, ml, portion), `food` (Momentaufnahme) **oder** `food_id` (Verweis auf `foods`), `note` |
| `water_entries` | `id`, `at`\*, `ml`\*>0 |
| `caffeine_entries` | `id`, `at`\*, `mg`\*>0, `label` |
| `weight_entries` | `id`, `at`\*, `kg`\* (1 bis 700), `note` |
| `periods` | `id`, `start`\*, `end` (fehlt oder null = läuft noch), `flow` (spotting, light, medium, heavy), `day_flows` {Tag: Stärke}, `notes`; höchstens 60 Tage |
| `symptom_entries` | `id`, `name`\* (1 bis 80 Zeichen), `intensity`\* (ganze Zahl 0 bis 10), `at`\*, `note` |

(\* = Pflichtfeld.)

- **Nährwerte** (`nutrients`) sind je 100 g beziehungsweise 100 ml angegeben. Schlüssel tragen die Einheit:
  `energy_kcal`, `protein_g`, `carbohydrates_g`, `fat_g`, `saturated_fat_g`, `sugars_g`, `fiber_g`, `salt_g`,
  `sodium_mg`, `caffeine_mg`, `vitamin_a_ug`, `vitamin_c_mg`, `vitamin_d_ug`, `vitamin_e_mg`, `vitamin_k_ug`,
  `vitamin_b1_mg`, `vitamin_b2_mg`, `vitamin_b3_mg`, `vitamin_b5_mg`, `vitamin_b6_mg`, `vitamin_b7_ug`,
  `vitamin_b9_ug`, `vitamin_b12_ug`, `calcium_mg`, `iron_mg`, `magnesium_mg`, `potassium_mg`, `zinc_mg`,
  `selenium_ug`, `iodine_ug`, `phosphorus_mg`. Ein fehlender Schlüssel bedeutet „keine Angabe“, das ist etwas anderes
  als der Wert 0. Der Import versteht zusätzlich die Kurzformen `kcal`, `protein`, `carbs`, `fat`, `sugar`, `fiber`,
  `salt`.
- **Zeit**: Tage als `YYYY-MM-DD`, Zeitpunkte als `YYYY-MM-DDTHH:MM[:SS]` in der Ortszeit des Nutzers ohne Zeitzone.
  Eine angehängte Zeitzone (`Z`, `+02:00`) wird ignoriert; es gilt die notierte Uhrzeit.
- **Prüfung**: Der Import prüft das ganze Dokument, bevor er etwas ändert, und nennt Fehler mit Pfad
  (`$.food_entries[3].amount: ...`). Unbekannte Felder werden ignoriert und als Warnung gemeldet. Fehlende `id`s
  werden erzeugt. Ein Abschnitt, der fehlt, ist nach dem Import leer: Der Import **ersetzt** den Bestand.
- **Einträge tragen eine Momentaufnahme** des Lebensmittels (`food`). Statt der Momentaufnahme genügt in einem
  Importdokument `food_id`, wenn das Lebensmittel unter `foods` steht.

### Verschlüsselte Sicherung (`.mhbackup`) und lokale Ablage

Kurzfassung; die Byte-Layouts stehen in `SECURITY.md`.

- `.mhbackup`: `MHB1`, Argon2id (64 MiB, 3 Durchläufe, 1 Lane) aus der Passphrase, AES-256-GCM über das gzip-komprimierte
  Exportdokument. Eine Sicherung stellt sich auf einer frischen Installation wieder her (im Gerätetest geprüft).
- Lokale Ablage: `store.mhs` (Snapshot) und `store.mhj` (Journal), AES-256-GCM, Schlüssel per HKDF-SHA-256 aus dem
  Hauptschlüssel (Keystore auf dem Gerät, Schlüsseldatei beim Wartungszugang).

## 7. Wesentliche Entscheidungen

- **Ein Kern für App und Wartungszugang.** `app/lib/core` ist reines Dart ohne Flutter. Die Oberfläche
  (`app/lib/ui`) ruft ihn auf, ebenso `app/bin/mh.dart`. Ausgaben wie `nutrition.day` und `cycle.forecast` entstehen
  in genau dem Code, der auch die App-Anzeige speist (`nutritionDay`, `computeForecast`).
- **Lokal und verschlüsselt.** Snapshot und Journal statt einer Datenbank: Jede Änderung ist ein einzeln
  authentifizierter Eintrag, ein Absturz kostet höchstens die letzte Änderung. Der Bestand liegt im Speicher, 10.000
  Einträge öffnen in unter einer Zehntelsekunde. Was sich nicht wieder lesen ließe, wird nicht gespeichert (`Db._put`).
- **Einträge sind Momentaufnahmen.** Ein Verzehreintrag trägt die Nährwerte des Lebensmittels zum Zeitpunkt der
  Erfassung; der Verlauf bleibt stabil, wenn sich Open Food Facts ändert. Bei **eigenen** Lebensmitteln gilt eine
  Korrektur auch für bestehende Einträge (wer einen Tippfehler in seinem Müsli behebt, will ihn überall behoben haben).
- **Fehlende Werte sind nicht Null.** Ein Nährstoff ohne Angabe fließt nicht als 0 in Summen ein. `entries_with_data`
  und die Anzeige „Angaben in x von y Einträgen“ machen Lücken sichtbar. Fehlt bei einem Produkt die Kalorienangabe,
  bleibt sie leer.
- **Mengen.** Gramm und Milliliter gelten 1:1, wenn die Einheit vom Bezug des Lebensmittels abweicht (1 ml = 1 g).
  Portionen rechnen über die Portionsgröße; fehlt sie, fragt das Eintragsformular danach („Eine Portion entspricht“).
- **Zeit ohne Zeitzonen.** Daten und Zeitpunkte sind Kalendertage und Ortszeiten. So verschieben Reisen oder
  Sommerzeit keinen Eintrag; der Nachteil steht in den Grenzen.
- **Zyklusprognose (Verfahren).** Es zählen Perioden mit Beginn bis einschließlich dem Betrachtungstag; Einträge, die nur
  Spotting enthalten, zählen nicht als Beginn. Abstände zwischen aufeinanderfolgenden Beginnen von 15 bis 60 Tagen
  gelten als Zyklus, andere gelten als fehlender oder doppelter Eintrag und werden in der Erklärung ausgewiesen. Aus
  den letzten sechs brauchbaren Abständen entsteht der Mittelwert; der nächste Beginn ist der letzte Beginn plus der
  gerundete Mittelwert. Das **Zeitfenster** ist ± Standardabweichung, aufgerundet (mindestens ±1 Tag, höchstens ±7;
  bei zwei Zyklen mindestens ±2, bei einem ±3). Die **Verlässlichkeit** ist *hoch* ab vier Zyklen mit Standardabweichung
  bis 2 Tage, *mittel* ab drei Zyklen bis 4 Tage, sonst *niedrig*. Ohne eigene Abstände nutzt die App die in den
  Einstellungen gewählte Zykluslänge (Verlässlichkeit niedrig) oder meldet zu wenig Daten. Liegt der berechnete Beginn
  in der Vergangenheit, ohne dass eine neue Periode erfasst ist, lautet der Status *überfällig*; liegt der letzte Beginn
  mehr als 60 Tage zurück, *veraltet* ohne Vorhersage. Die typische Periodendauer stammt aus abgeschlossenen
  Perioden. Eine Periode ohne Ende gilt bis zu zehn Tage als laufend. Die App berechnet weder Eisprung noch fruchtbare
  Tage und macht keine medizinischen Aussagen.
- **Prognose als Stand eines Tages.** `cycle.forecast` und die Anzeige verwenden nur Perioden mit Beginn bis zum
  Betrachtungstag. Wer einen Tag in der Vergangenheit betrachtet, sieht, was die App an jenem Tag gewusst hat.
- **Nährwertauswahl bei Open Food Facts**: erst Angaben „wie verkauft“ von Hersteller oder Verpackung, keine Schätzungen
  (Abschnitt 4).
- **Ohne Druck.** Die App zählt keine Serien, beschämt weder bei Essen noch bei Gewicht, sendet keine Mitteilungen und
  zeigt keine Werbebotschaften. Ziele sind freiwillig, Überschreitungen erscheinen sachlich („350 kcal über dem Ziel“).
- **Wenige, direkte Abläufe.** Erfassen ist in einem Schritt möglich (Wasser, Periode beginnt heute). Jedes Löschen
  eines Eintrags bietet „Rückgängig“ an. Zusätzlich fragt die App nur dort, wo mehr als ein Eintrag oder Klartext
  betroffen ist: beim Löschen einer Periode oder eines eigenen Lebensmittels, beim Import, bei der
  Wiederherstellung, beim Löschen aller Daten und beim unverschlüsselten Export.
- **Barrierefreiheit im Test verankert**: Tippflächen, Beschriftungen, Kontrast und die Semantik-Struktur werden von
  Widget-Tests geprüft (Abschnitt 8).

## 8. Tests und tatsächliche Ergebnisse

Alle Ergebnisse stammen vom Lauf von `./check.sh` am 29.09.2026 auf diesem Rechner mit dem Referenzemulator
(`emulator-5560`, Android 15, x86_64, 1080 × 2400 bei 420 dpi).

| Prüfung | Umfang | Ergebnis |
|---|---|---|
| `dart format` | gesamter Quelltext und alle Tests | keine Abweichungen |
| `flutter analyze` | gesamtes Projekt | keine Hinweise |
| `flutter test` | 140 Tests | alle bestanden |
| `tools/cli_e2e.py` | 69 Prüfungen des Wartungszugangs | alle bestanden |
| `tools/device_smoke.py` | 87 Prüfungen auf dem Gerät | alle bestanden |
| APK-Prüfung | Package, x86_64, Berechtigungen, Signatur | bestanden |

**`flutter test`** (Kern, Oberfläche, Barrierefreiheit):

- *Kern*: Datum und Zeit; Zyklusprognose (Abstände, Ausreißer, Spotting, Stand des Betrachtungstags, Grenzfälle);
  Nährwertberechnung (Portionen, ml/g, fehlende Werte, Koffein); Datenbank (Änderungen, Überschneidungen von
  Perioden, Eigenes-Lebensmittel-Änderung wirkt auf Einträge, Symptomgruppen, Dauerhaftigkeit); verschlüsselte
  Ablage (Testvektoren für HKDF RFC 5869, AES-256-GCM NIST, Argon2id RFC 9106; Manipulation, falscher Schlüssel,
  abgerissenes Journal, Sperre, Kompaktierung); Sicherung (Umlaufen, falsche Passphrase, Manipulation, Parametergrenzen);
  Export/Import (Umlauf, Fehler mit Pfad, Aliase, Zeitzonen, 10.000 Einträge); Protokoll des Wartungszugangs;
  Open-Food-Facts-Auswertung mit echten Antworten des Endpunkts (`test/fixtures/off`), beide Schemata; ein Test gegen den
  echten Endpunkt (übersprungen, wenn er nicht erreichbar ist); **Zufallsdaten**: Alles, was die Oberfläche
  speichern kann (drei Startwerte, Randwerte eingeschlossen), überlebt Neustart, Export und Import unverändert.
- *Oberfläche*: Übersicht, Ernährungsabläufe (Wasser, Koffein, eigene Lebensmittel mit allen Nährstoffen, Suche und
  Barcode mit Fehlerfällen, Portionen), Bearbeiten und Löschen, Zyklus (Erfassen, Spotting, Erklärung, Tagebuchmodus),
  Gewicht (kg, lb), Symptome, Historie, Sprache und Bereiche, **Barrierefreiheit** (Tippflächen, Beschriftungen, Kontrast
  in Hell und Dunkel, 200 % Schrift, Englisch), **Semantik-Struktur** (kein Textfeld oder Schalter verdeckt Nachbarn)
  und **Abstände** (Blätter liegen über der Navigationsleiste).

**`tools/cli_e2e.py`** startet `./mh` als Prozess und prüft: Protokoll (JSON Lines, Fehlercodes, `request_id`),
`describe` samt Beispieldokument, Import, Tagessummen mit Handrechnung, Prognose (alle Status), Umlauf
Export → Import → Export, Persistenz über Prozesse, offene Periode über Neustarts, ungültige Dokumente, Verschlüsselung
(kein Klartext im Datenverzeichnis, falscher/fehlender/zu kurzer Schlüssel), `--now`, 10.000 Einträge
(Import in unter 1 s, Prozessstart mit Tagesabfrage etwa 0,1 s, eine Tagesabfrage etwa 1 ms), und gegen den Endpunkt
`food.search`, `food.lookup`, Fehlerfälle und `disabled`.

**`tools/device_smoke.py`** installiert die Release-APK **frisch** (deinstallieren, installieren), bedient sie über
adb und prüft: Kaltstart (rund 0,5 s), Berechtigungen, alle Navigationsziele, Wasser mit „Rückgängig“, Lebensmittel per
Barcode und Namen mit **echtem Abruf**, eigenes Lebensmittel, Favoriten, „Zuletzt“, Erneut erfassen, Bearbeiten,
Löschen, Verläufe über 7 und 28 Tage, Gewicht, Symptome, Zyklus, Historie, Bereiche ein- und ausblenden, Sprache,
**Blätter über der Navigationsleiste**, Export als JSON über die Dateiauswahl (Inhalt vom Host geprüft und mit `./mh`
gegengerechnet), Import des Beispieldokuments (Tagessumme und Erklärung der Prognose stimmen mit `./mh` überein),
verschlüsselte Sicherung (Kopf, Parameter, kein Klartext), Löschen, **Neuinstallation und Wiederherstellung**
(falsche Passphrase wird abgelehnt), Neustart mit erhaltenen Daten. Der Test lässt das Gerät mit frisch installierter,
leerer App zurück.

**Leistung** (Messwerte dieser Läufe): 10.000 Verzehreinträge samt Beiwerk ergeben einen Snapshot von 200 bis 290 KiB
(gzip und AES); der Import von 10.000 Einträgen dauert im Kommandozeilenprogramm etwa 0,3 s, im Test-JIT rund 0,9 s. Auf
dem Gerät öffnet ein Bestand mit 15.500 Datensätzen in unter einer Sekunde; die Historie filtert ohne Wartezeit.

**Bei der Prüfung gefundene und behobene Fehler** (jeweils mit Regressionstest):

- Eine laufende Periode („Periode beginnt heute“) ließ die App beim nächsten Start den Bestand als beschädigt melden;
  Ursache war eine um einen Tag zu strenge Längenprüfung beim Lesen. Zusätzlich speichert die Datenbank nur noch
  Datensätze, die sich wieder lesen lassen.
- Textlängen zählten UTF-16-Einheiten statt Zeichen (Emoji), die Eingabefelder zählen Zeichen.
- Schaltflächen in Blättern lagen unter der Android-Navigationsleiste.
- Textfelder und Schalter in Zeilen meldeten fremde Nachbarn als Kinder und hatten falsche Flächen für Fokus und
  Automatisierung.
- Weiterleitungen des Lebensmitteldienstes wurden auch auf `http://` befolgt; jetzt nur `https` zum selben Host.

## 9. Bekannte Grenzen

- **Kein Kamerascanner** (nicht Teil des Auftrags): Barcodes werden als Zahl eingegeben.
- **Prognose ist Statistik.** Sie beruht auf den eigenen Abständen, nicht auf Symptomen, Hormonen oder Temperatur.
  Bei unregelmäßigen Zyklen ist das Zeitfenster breit, bei zu wenig Daten gibt es keine Vorhersage.
- **Keine Zeitzonen im Datenmodell.** Wer die Zeitzone wechselt, behält die notierten Uhrzeiten. Der Tag, an dem
  „heute“ beginnt, folgt der Systemzeit des Geräts.
- **Open Food Facts**: Die Datenqualität wird nicht verbessert. Produkte ohne Nährwerte erscheinen ohne Zahlen, die
  Namen bleiben in der Originalsprache. Es werden keine Bilder geladen. Ohne Netz bleibt die lokale Nutzung
  vollständig möglich.
- **Datenmenge**: Der Bestand wird im Speicher gehalten. Für die vorgesehenen bis zu 10.000 Tagebucheinträge
  (gemessen bis 15.500 Datensätze) ist das schnell; weit größere Bestände würden mehr Speicher brauchen.
- **Sicherheit**: Es gibt keine App-Sperre, keine Erkennung zurückgespielter alter Stände und keine
  Unicode-Normalisierung der Passphrase; der Export ist bewusst unverschlüsselt. Einzelheiten in `SECURITY.md`.
- **Signatur**: Die APK trägt den Debug-Schlüssel und eignet sich für die Prüfung, nicht für die Veröffentlichung.
- **TalkBack** stand im Referenzabbild nicht zur Verfügung. Die Bedienung mit Screenreader ist über die
  Semantik-Struktur (Beschriftungen, Gruppen, Reihenfolge) und Widget-Tests abgesichert, aber nicht mit TalkBack selbst
  durchgespielt.
- **Dauer des Gerätetests**: rund 10 Minuten, weil jede Abfrage der Bedienoberfläche per `uiautomator` etwa zwei
  Sekunden braucht. `./check.sh --no-device` dauert unter einer Minute.
- **Ein Prozess je Datenverzeichnis**: `./mh` und die App sperren ihr Verzeichnis. Ein zweiter Prozess wartet bis zu
  10 Sekunden und meldet dann `locked`.
- **Plattform**: nur Android (API 26 und höher). iOS, Web und Wearables gehören nicht zum Auftrag.
