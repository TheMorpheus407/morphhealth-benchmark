# MorphHealth

MorphHealth ist ein lokales, zweisprachiges Gesundheitstagebuch für Android, geschrieben in Flutter. Es verbindet Ernährung und Open Food Facts mit einem persönlichen Periodenkalender, Gewicht und Symptomen. Es gibt kein Konto, kein eigenes Backend, keine Werbung, keine Telemetrie und keine Laufzeit-KI.

Package-ID: `de.themorpheus.morphhealth.local`  
App-Einstieg: `app/lib/main.dart`  
Wartungszugang: `./mh`

## Funktionen und Bedienung

Die Standardsprache ist Deutsch. Unter **Einstellungen → Sprache** steht die gesamte eigene Oberfläche auch auf Englisch zur Verfügung. Systemdatums-, Zeit-, Tastatur- und Screenreader-Metadaten folgen den Flutter-/Android-Localization-Delegates. Diagramme besitzen zusätzlich Textwerte; Kalender- und Periodenzustände werden nicht nur durch Farben unterschieden.

### Übersicht und gemeinsamer Tag

- Die untere Navigation enthält **Übersicht, Ernährung, Zyklus, Historie und Einstellungen**.
- Die vier Bereiche Ernährung, Zyklus, Gewicht und Symptome lassen sich unter Einstellungen einzeln ein-/ausblenden. Die Module bleiben trotzdem nutzbar.
- Pfeile und Datumsauswahl wechseln den gemeinsamen Tageskontext. **Tagesdetail öffnen** führt Verzehr, Wasser/Koffein, Gewicht, Perioden und Symptome zusammen.
- Jede Tageszeile öffnet den zugehörigen Editor. Gewichts- und Symptomverläufe sind auch direkt von der Übersicht erreichbar.
- Nährstoffverläufe umfassen 7 und 28 Tage sowie einen wählbaren Nährstoff. Gewichtsverläufe lassen fehlende Tage aus, statt künstlich 0 kg anzuzeigen.

### Ernährung

- **Tag**: Tagesbilanz, Mahlzeiten, Wasser/Koffein, Korrektur und Löschung, Wiederholung eines Eintrags.
- **Lebensmittel**: lokale Bibliothek, Suche, Favoriten, eigene Lebensmittel und Online-Suche.
- **Verläufe**: 7-/28-Tage-Werte für jeden implementierten Nährstoff.
- Die Online-Suche unterstützt Namen und Seitennavigation sowie eine eingegebene 8–14-stellige Barcode-Nummer. Eine Kamera ist bewusst nicht enthalten.
- Eigene Lebensmittel enthalten alle 31 Nährstofffelder. Leere Felder bedeuten **unbekannt**, nicht null. Werte gelten je 100 g oder 100 ml; eine optionale Portionsgröße erlaubt die Eingabe in Portionen.
- Verzehreinträge enthalten Menge (g, ml oder Portion), Mahlzeit, Datum/Uhrzeit und optionale Notiz. Nährwerte werden als Snapshot gespeichert, damit spätere Lebensmitteländerungen keine alten Tagebücher verändern.
- Wasser bietet 150/250/330/500 ml und einen freien Wert. Zusätzliches Koffein wird in mg erfasst. Beide Arten sind später bearbeitbar und löschbar.
- Unter dem Zielsymbol der Tagesbilanz stehen freiwillige Ziele für Wasser, Kalorien, Protein, Kohlenhydrate und Fett. Leere Ziele sind deaktiviert.

### Zyklus

- Perioden haben Beginn, optionales Ende, Blutungsstärke (Spotting, leicht, mittel, stark) und Notizen. Eine offene Periode stellt die aktuell laufende Periode dar.
- Der Monatskalender navigiert beliebig in ältere und spätere Monate. Ein Tag öffnet das gemeinsame Tagesdetail einschließlich Symptomerfassung.
- Die persönliche Einschätzung verwendet die letzten höchstens sechs plausiblen Start-zu-Start-Intervalle zwischen 15 und 90 Tagen. Angezeigt werden Median, erwarteter Beginn, Zeitraum, Datenlage und eine verständliche Erklärung.
- Der Zeitraum basiert auf der medianen absoluten Abweichung und ist mindestens ±2 Tage breit. Abgeschlossene Perioden von 1–30 Tagen liefern zusätzlich eine typische Periodendauer.
- **Nur als Zyklustagebuch verwenden** blendet die Einschätzung vollständig aus. Aufzeichnung und Kalender bleiben aktiv.
- Kalenderintervalle werden als UTC-Kalenderdifferenz berechnet; Sommerzeitwechsel verändern daher keine Tagesanzahl.
- Es gibt bewusst keine Eisprung-, Fruchtbarkeits-, Diagnose- oder Verhütungsfunktion.

### Gewicht und Symptome

- Gewicht wird mit Datum und optionaler Notiz erfasst, bearbeitet und gelöscht. Eingabe und Anzeige sind in kg oder lb möglich; gespeichert wird kanonisch in kg (`lb = kg × 2,2046226218`).
- Symptome haben freien Namen, ganzzahlige Intensität 0–10, Datum/Uhrzeit und optionale Notiz. Der Verlauf lässt sich nach einem bereits erfassten Symptomnamen filtern.

### Historie

Die Historie durchsucht Ernährung, Zyklus, Gewicht und Symptome gemeinsam. Freitext, Bereich sowie Von-/Bis-Datum lassen sich kombinieren. Ergebnisse sind absteigend nach Zeit sortiert und öffnen direkt den jeweiligen Editor.

## Build und Android-Start

Vorausgesetzt wird die in `ENVIRONMENT.json` beschriebene Flutter-/JDK-/Android-Toolchain. Pub-, Gradle- und temporäre Caches liegen standardmäßig innerhalb dieses Projektordners. `ENVIRONMENT.json` wird nur gelesen.

```bash
./build.sh
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 install -r artifacts/morphhealth.apk
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 reverse tcp:8788 tcp:8788
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 shell am start \
  -n de.themorpheus.morphhealth.local/de.themorpheus.morphhealth.MainActivity
```

`build.sh` führt `flutter pub get --enforce-lockfile`, baut einen x86_64-Release und den nativen `mh`-Starter, prüft Package-ID und native Bibliotheken und legt folgende Dateien an:

- `artifacts/morphhealth.apk`
- `artifacts/morphhealth.apk.sha256`
- `app/build/mh/bundle/bin/mh` (von `./mh` verwendet)

Der Build liest `food_api_base_url` und `food_api_user_agent` aus dem Manifest und übergibt sie als Dart-Defines. Ein manueller Flutter-Build ohne diese Defines verwendet den Produktions-Origin `https://world.openfoodfacts.org`. Ein anderer HTTPS-Origin mit demselben Vertrag kann ohne Fachlogikänderung per Define beziehungsweise CLI-Option gesetzt werden.

Die Release-APK ist für die lokale Abgabe mit dem Entwicklungs-/Debug-Signaturschlüssel der Flutter-Umgebung signiert. Store-Publishing und ein produktiver Signaturprozess sind nicht Bestandteil dieses Auftrags.

## Prüfungen

```bash
./check.sh
MH_LIVE_TESTS=1 ./check.sh
MH_ANDROID_TESTS=1 ./check.sh
```

- `check.sh`: Lockfile-Auflösung, Formatprüfung, `flutter analyze`, alle Host-/Widget-Tests, nativer JSON-Lines-Smoke-Test sowie Package-/ABI-Prüfung der fertigen APK.
- `MH_LIVE_TESTS=1`: zusätzlich echter Barcode-Abruf gegen den Manifest-Origin.
- `MH_ANDROID_TESTS=1`: zusätzlich der komplette Android-UI-Ablauf auf `emulator-5560`; kein anderes Gerät wird angesprochen.

Dokumentierter Arbeitsstand:

- **73 Host-/Widget-Tests bestanden**: Modelle, alle 31 Nährstoffe, g/ml/Portionen, Wasser/Koffein, Sommerzeit, Prognose, Historienfilter, Repository-CRUD, AES-Persistenz, falscher Schlüssel, Portable-Roundtrip, Backup-Roundtrip, falsche Passphrase und Manipulation, OFF-Mapping mit Mock-HTTP, 10.000 Einträge und echter CLI-Prozessvertrag.
- Lebensmittel- und Verzehrformulare sowie Backup-/Löschdialoge wurden zusätzlich mit 1080×2400 Pixeln, 420 dpi und **200 % Systemschrift** geprüft.
- `dart analyze app/lib app/bin app/integration_test`: **keine Probleme**.
- Finaler `MH_LIVE_TESTS=1 ./check.sh`: **alle Prüfungen bestanden**, einschließlich Formatierung, 73 Tests, JSON-Lines-Smoke, Package-/ABI-Prüfung und Live-Barcode-Abruf.
- Live-Suche nach `apfel` und Barcode `4000405002377` wurden erfolgreich über denselben `mh`-Code gegen `https://localhost:8788` ausgeführt.
- Native Messung mit 10.000 Verzehreinträgen: Ersatz-Import **0,45 s**, Tagesaggregation im Mittel **8,7 ms** (p95 **10,4 ms**), erneutes Öffnen inklusive erster Tagesabfrage **0,31 s**; verschlüsselter Bestand etwa **4,77 MB**.
- Der Android-End-to-End-Test auf dem Referenzgerät **bestand vollständig**: Wasser, eigenes Lebensmittel und Verzehr, Live-Suche und Barcode-Import, Gewicht, Symptom, Periode, Historienbearbeitung und gemeinsames Tagesdetail bei 200 % Systemschrift.
- Mit der installierten Release-APK wurden zusätzlich `CREATE_DOCUMENT` und `OPEN_DOCUMENT` real bedient: verschlüsselte Sicherung und Portable-JSON erzeugt und gezogen, beide Formate nach `pm clear` erfolgreich wiederhergestellt und die Gesamtlöschung anschließend über die Oberfläche bestätigt.

## Lokalen Wartungszugang `mh` verwenden

```bash
umask 077
mkdir -p .tmp/mh-example
python3 -c 'import os; open(".tmp/mh-example/key.bin", "wb").write(os.urandom(32))'
printf '%s\n' \
  '{"request_id":"d1","op":"describe"}' \
  '{"request_id":"n1","op":"nutrition.day","date":"2026-10-24"}' \
  | ./mh \
      --data-dir "$PWD/.tmp/mh-example/data" \
      --key-file "$PWD/.tmp/mh-example/key.bin" \
      --now 2026-10-24T12:00:00Z
```

Die Schlüsseldatei enthält **32 rohe Bytes**, nicht Hex, Base64 oder eine Passphrase. Sie muss außerhalb von `--data-dir` liegen und wird zusammen mit dem verschlüsselten Datenbestand für einen späteren Zugriff benötigt. Der Besitzer muss die Datei sicher aufbewahren und darf sie nicht verlieren. Ohne `--now` wird die Systemuhr verwendet; mit `--now` müssen RFC3339 und Zeitzone angegeben werden.

Weitere Optionen:

```text
--food-base-url HTTPS_ORIGIN
--food-user-agent STRING
```

Der Starter lädt API-Origin und User-Agent aus `ENVIRONMENT.json`; explizite Optionen haben Vorrang. Beim ersten Aufruf oder nach Core-Änderungen baut er das native Bundle mit `dart build cli`. Buildmeldungen gehen auf stderr. Während des Protokolls enthält stdout ausschließlich JSON-Zeilen.

### Transportvertrag

Jede Eingabezeile ist ein JSON-Objekt mit `request_id` und `op`. Leere Zeilen werden ignoriert; EOF beendet den Prozess. Nach jeder Antwort wird geflusht.

```json
{"request_id":"a1","ok":true,"data":{}}
{"request_id":"a2","ok":false,"error":{"code":"invalid_request","message":"Detail"}}
```

`request_id` wird unverändert zurückgegeben. Fehlerhaftes JSON oder eine fehlende ID erzeugt `request_id: null`. Stabile Fehlercodes sind unter anderem `invalid_request`, `online_disabled`, `timeout`, `network`, `http_<status>` und `operation_failed`.

### Operationen

| `op` | Eingabe zusätzlich zu `request_id`/`op` | `data` |
|---|---|---|
| `describe` | keine | Vollständige Formate, Einheiten, Operationen und ein importierbares Beispieldokument |
| `portable.export` | `ack_plaintext: true` | Das komplette Portable-Dokument direkt |
| `portable.import` | `document`, `confirm_replace: true` | `{replaced:true, counts:{foods,intakes,periods,weights,symptoms}}` |
| `nutrition.day` | `date: "YYYY-MM-DD"` | Tag, alle Summen/Einheiten/Ziele, Wasser, Coverage und Einträge mit berechneten Nährstoffen |
| `cycle.forecast` | `on: "YYYY-MM-DD"` | Persönliche Prognose, Quellintervalle, Zeitraum, Konfidenz und Erklärung |
| `food.search` | `q`, `page >= 1` | `query,page,page_size=20,total_results,returned,products` |
| `food.lookup` | `barcode` | `{barcode,found,food}`; `food` kann `null` sein |

Die beiden Food-Operationen respektieren die gespeicherte Online-Freigabe. Sie senden nur Suchtext beziehungsweise Barcode und die HTTP-Header, niemals Tagebuchdaten. Verwendet werden ausschließlich:

```text
GET {base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20
GET {base}/api/v3.6/product/{barcode}.json
```

Die Suche projiziert nur benötigte Produktfelder. TLS-Prüfung bleibt aktiviert.

## Datenformate

### Portable V1

Der Klartextexport und die App-/CLI-Importe verwenden `morphhealth.portable.v1`. Das Format ist versioniert und vollständig; es ist kein Sicherungsformat früherer Entwürfe.

```json
{
  "format": "morphhealth.portable.v1",
  "app_version": "1.0.0",
  "exported_at": "2026-01-01T00:00:00.000Z",
  "state": {
    "schema_version": 1,
    "foods": [],
    "intakes": [],
    "periods": [],
    "weights": [],
    "symptoms": [],
    "settings": {
      "language": "de",
      "weight_unit": "kg",
      "show_nutrition": true,
      "show_cycle": true,
      "show_weight": true,
      "show_symptoms": true,
      "online_enabled": true,
      "cycle_forecast_enabled": true,
      "goals": {
        "water_ml": null,
        "calories": null,
        "protein": null,
        "carbs": null,
        "fat": null
      }
    }
  }
}
```

Dieses leere Dokument ist direkt für `portable.import` geeignet und ersetzt nach Bestätigung den Bestand. `describe` liefert es unter `portable_import_example`.

Gemeinsame Regeln:

- Zeitstempel: UTC-RFC3339 mit `Z`. `occurred_at` wird für Tagesansichten in die lokale Geräte-/Prozesszeitzone umgerechnet.
- Kalenderdaten: striktes `YYYY-MM-DD`; ungültige Daten werden abgelehnt.
- IDs: nichtleere Strings, innerhalb jeder Sammlung eindeutig. Die App erzeugt 128-Bit-Zufalls-IDs hexadezimal.
- Zahlen: endliche JSON-Zahlen; Mengen sind positiv, Nährstoffe nicht negativ. Fehlende Nährstoffschlüssel bedeuten unbekannt.
- Importe werden komplett einschließlich Referenzen, doppelter IDs und Periodenüberlappungen geprüft, bevor der bisherige Bestand ersetzt wird.

### `foods[]`

| Feld | Inhalt |
|---|---|
| `id`, `name`, `brand`, `source` | `source`: `custom` oder `openfoodfacts`; Marke kann leer sein |
| `barcode` | String oder `null` |
| `measure` | `g` oder `ml`; kanonische Bezugsmaßeinheit |
| `portion_size` | positive Zahl in `measure` oder `null` |
| `nutrients_per_100` | Objekt `{nutrient_id: number}`; nur bekannte Werte |
| `favorite` | Boolean |
| `created_at`, `updated_at` | UTC-Zeitstempel |

### `intakes[]`

| Feld | Inhalt |
|---|---|
| `id`, `kind` | `kind`: `food`, `water`, `caffeine` |
| `occurred_at` | UTC-Zeitpunkt; bestimmt den lokalen Tag |
| `meal` | `breakfast`, `lunch`, `dinner`, `snack`; einfache Einträge verwenden `snack` |
| `food_id`, `food_name`, `brand` | Bei Food erforderlich beziehungsweise Snapshot; bei Wasser/Koffein `null` beziehungsweise leer |
| `amount`, `unit` | Food: g/ml/portion; Wasser: ml; Koffein: mg |
| `portion_size` | Für `unit=portion` erforderlich, sonst Zahl oder `null` |
| `nutrients_per_100_snapshot` | Historische kanonische Food-Nährwerte; einfache Einträge `{}` |
| `notes` | String, kann leer sein |
| `created_at`, `updated_at` | UTC-Zeitstempel |

Berechnung pro Nährstoff:

```text
g oder ml:  beitrag = snapshot_wert × amount / 100
Portion:    beitrag = snapshot_wert × amount × portion_size / 100
Wasser:     water_ml += amount
Koffein:    totals.caffeine += amount
```

`nutrition.day` enthält zusätzlich `food_entry_count` und `known_food_entries_per_nutrient`. Dadurch ist erkennbar, wenn eine Summe auf unvollständigen Produktangaben beruht.

### `periods[]`

```text
id, start, end, flow, notes, created_at, updated_at
```

`start` ist erforderlich, `end` ist Datum oder `null`. `flow`: `spotting`, `light`, `medium`, `heavy`. Überlappungen sind ungültig.

### `weights[]`

```text
id, date, kg, notes, created_at, updated_at
```

`kg` ist positiv und höchstens 2000. Die Anzeige kann in lb erfolgen.

### `symptoms[]`

```text
id, name, intensity, occurred_at, notes, created_at, updated_at
```

`name` ist nichtleer, `intensity` ist ein Integer von 0 bis 10.

### Nährstoff-IDs und kanonische Einheiten

```text
kcal: calories
g: protein, carbs, fat, saturated_fat, sugar, fiber, salt
mg: sodium, caffeine, vitamin_c, vitamin_e,
    vitamin_b1, vitamin_b2, vitamin_b3, vitamin_b5, vitamin_b6,
    calcium, iron, magnesium, potassium, zinc, phosphorus
µg: vitamin_a, vitamin_d, vitamin_k, vitamin_b7, vitamin_b9,
    vitamin_b12, selenium, iodine
```

OFF-Werte werden anhand der `_100g`- und `_unit`-Felder in diese Einheiten umgerechnet. Berücksichtigt werden unter anderem OFF-Aliase für B3, B5, B7 und B9.

## Export, Import, Backup und Löschen

Unter **Einstellungen → Daten und Privatsphäre**:

- **Vollständiger JSON-Export**: nach ausdrücklicher Klartextbestätigung über Androids Dokumentpicker.
- **JSON-Daten importieren**: Portable V1 auswählen; Validierung und Ersatzwarnung, danach atomarer Ersatz.
- **Sicherung erstellen**: Passphrase zweimal eingeben; verschlüsselte Datei über den Dokumentpicker speichern.
- **Sicherung wiederherstellen**: Datei und Passphrase eingeben; nach Prüfung wird der Bestand ersetzt. So funktioniert die Übernahme auf einer frischen Installation.
- **Alle lokalen Daten löschen**: Bestätigung durch `LÖSCHEN` beziehungsweise `DELETE`; entfernt den internen Bestand und setzt auch Einstellungen zurück.

Backup-Dateien erhalten die Endung `.encrypted-backup.json`, bleiben aber binär nicht dokumentenlesbar: ihr JSON-Envelope enthält ausschließlich Base64-Kryptofelder. Bereits exportierte Dateien außerhalb des App-Speichers werden durch das Löschen des App-Bestands nicht entfernt; sie bleiben unter Kontrolle des Nutzers.

Die genauen Kryptoparameter und Schutzgrenzen stehen in [SECURITY.md](SECURITY.md).

## Architektur und Entscheidungen

- `app/lib/core/`: Flutter-unabhängige Modelle, Aggregation, Prognose, Historie, Verschlüsselung, Portable/Backup und OFF-Client.
- `app/lib/ui/`: deutsch/englische Material-3-Oberfläche und gemeinsamer `AppController`.
- `app/bin/mh.dart`: JSON-Lines-Adapter auf **dieselben** Core-Funktionen; keine zweite Fachimplementierung.
- Der lokale Bestand ist ein versioniertes, AES-256-GCM-verschlüsseltes Dokument mit atomaren Ersetzungen und serialisierten Schreibvorgängen. Das vermeidet eine native SQLCipher-ABI und eignet sich für den geforderten Ein-Nutzer-Bestand.
- `provider` dient der UI-Aktualisierung. `path_provider` und `flutter_secure_storage` kapseln Android-Ablage und Schlüsselschutz.
- Die Suche lädt keine Produktbilder und vermeidet dadurch unnötige weitere Netzaufrufe.

## Tatsächliche Grenzen

- Open-Food-Facts-Werte sind Crowdsourcedaten und können fehlen oder fehlerhaft sein. MorphHealth kennzeichnet unbekannte Werte und warnt bei potenziell unvollständigen Summen, kann die Datenqualität aber nicht prüfen.
- Online-Suche benötigt Netzwerk und einen erreichbaren, vertrauenswürdigen HTTPS-Origin. Der Rest des Gesundheitstagebuchs bleibt offline nutzbar.
- Eine verlorene Backup-Passphrase oder ein verlorener CLI-Schlüssel kann nicht wiederhergestellt werden.
- Der verschlüsselte Gesamtbestand wird als Dokument verwaltet; es gibt keine Mehrbenutzer-, Gleichzeitigkeits- oder Synchronisationssemantik. Das ist bewusst kein Multi-Device-System.
- Die APK verwendet eine lokale Entwicklungssignatur und ist nicht für eine Store-Veröffentlichung signiert.

Produktdaten: **Open Food Facts**, Open Database License (ODbL), <https://world.openfoodfacts.org>. Eigene Lebensmittel werden ausschließlich lokal gespeichert und nicht hochgeladen.
