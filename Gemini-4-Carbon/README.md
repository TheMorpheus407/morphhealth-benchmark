# MorphHealth

MorphHealth (`de.themorpheus.morphhealth.local`) ist eine lokal arbeitende Android-Gesundheitsanwendung in Flutter für eine Person pro Installation. Die App verbindet ein vollständiges Ernährungstagebuch samt Open-Food-Facts-Anbindung, Wasser- und Koffeinprotokollierung, einen persönlichen Periodentracker mit nachvollziehbarer Verlaufsauswertung, Gewichtsverlauf sowie Symptomerfassung unter einer ruhigen zweisprachigen Oberfläche (Deutsch voreingestellt, Englisch jederzeit umschaltbar).

Ergänzend stellt `./mh` denselben produktiven Fach- und Speicherkern als lokalen JSON-Lines-Wartungsprozess unter Linux bereit.

---

## 1. Funktionsumfang und Bedienung in Android

Die Hauptnavigation gliedert sich in fünf Bereiche am unteren Bildschirmrand sowie übergreifende Detail- und Einstellungsansichten:

1. **Übersicht (`Übersicht` / `Overview`)**
   - Zeigt die vier Bereiche *Ernährung*, *Zyklus*, *Gewicht* und *Symptome* für den gewählten Kalendertag.
   - Über das Regler-Symbol oben rechts lassen sich einzelne Bereiche frei ein- und ausblenden. Ernährung und Zyklus funktionieren vollständig unabhängig voneinander.
   - Bietet Direktaktionen (`+ Mahlzeit`, `+250 ml`, `+ Koffein`, `Periode / Spotting`, `Gewicht`, `Symptom`) sowie den Einstieg in das **Gemeinsame Tagesdetail** und die **7-/28-Tage-Verläufe**.
2. **Ernährungstagebuch (`Ernährung` / `Nutrition`)**
   - **Lebensmittelsuche & Barcode-Abruf:** Über *Lebensmittel erfassen* durchsucht der Reiter *Open Food Facts* den konfigurierten HTTPS-Dienst nach Namen (`/cgi/search.pl`) oder ruft ein Produkt direkt über dessen Barcode-Nummer (`/api/v3.6/product/{barcode}.json`) ab.
   - **Wiedererfassung, Favoriten & eigene Lebensmittel:** Bereits protokollierte Mahlzeiten erscheinen im Reiter *Erneut* sowie mit einem Wiederholen-Symbol direkt in der Tagesliste zur Übernahme mit einem Tippen. Häufig genutzte Produkte lassen sich per Stern als Favorit markieren. Eigene Lebensmittel können mit sämtlichen **31 Nährwerten** angelegt, korrigiert und gelöscht werden.
   - **Mengen & Mahlzeiten:** Jeder Verzehreintrag unterstützt `g`, `ml` und `portion` sowie die Zuordnung zu *Frühstück*, *Mittagessen*, *Abendessen* oder *Snack* samt Datum, Uhrzeit und Notiz.
   - **31 Nährwerte:** Neben Kalorien, Protein, Kohlenhydraten und Fett verarbeitet und zeigt MorphHealth gesättigte Fettsäuren, Zucker, Ballaststoffe, Salz, Natrium, Koffein, alle **13 Vitamine** (`A, C, D, E, K, B1, B2, B3, B5, B6, B7, B9, B12`) und alle **8 Mineralstoffe** (`Kalzium, Eisen, Magnesium, Kalium, Zink, Selen, Jod, Phosphor`).
   - **Wasser, Koffein & freiwillige Tagesziele:** Häufige Wassermengen (`150 ml`, `250 ml`, `330 ml`, `500 ml` oder eigene Menge) und zusätzliches Koffein (z. B. Espresso, Kaffee, Tee oder eigene Milligramm-Angabe) werden unmittelbar im Ernährungstagebuch protokolliert. Über das Flaggen-Symbol lassen sich freiwillige Tagesziele für Wasser, Kalorien und Makronährstoffe setzen oder leeren.
3. **Persönlicher Periodentracker (`Zyklus` / `Cycle`)**
   - Erfasst vergangene und laufende Perioden mit Beginn, optionalem Ende, Blutungsstärke (`Spotting`, `Leicht`, `Mittel`, `Stark`), tagesgenauen Stärken innerhalb einer Periode sowie Notizen. Einzelne Zwischenblutungen lassen sich als eigenständiges Spotting markieren, ohne einen neuen Zyklusbeginn auszulösen.
   - Der interaktive Monatskalender erlaubt den Wechsel in beliebig ältere oder zukünftige Monate, hebt protokollierte Perioden, Spotting, Symptome und das persönliche Planungsfenster hervor und zeigt darunter den Tageskontext samt direkter Symptomerfassung.
   - Über *Einschätzung erklären* öffnet sich eine transparente Herleitung der persönlichen Prognose mit den ausgewerteten Zykluslängen, der Spanne und der persönlichen Streuung. Über den Schalter *Nur als Tagebuch* werden sämtliche Vorhersagen ausgeblendet.
4. **Gewicht und Symptome (`Werte` / `Body`)**
   - **Gewicht:** Protokollierung für beliebige Daten, nachträgliche Bearbeitung und Löschung, verlustfreie Umschaltung zwischen `kg` und `lb` sowie 7- und 28-Tage-Linienverlauf.
   - **Symptome:** Frei wählbare Bezeichnung mit Schnellvorschlägen, Intensität auf der Skala `0` bis `10`, Datum/Uhrzeit, optionale Notiz und gezielter Verlauf für jedes einzelne erfasste Symptom.
5. **Durchsuchbare Historie (`Historie` / `History`)**
   - Durchsucht sämtliche Einträge über alle vier Bereiche hinweg nach Freitext, Bereich und Zeitraum (`Gesamter Zeitraum`, `7 Tage`, `28 Tage`, `90 Tage` oder frei gewählter Datumsbereich). Ein Tippen auf einen Treffer öffnet unmittelbar den zugehörigen Bearbeitungsdialog.
6. **Einstellungen, Privatsphäre & Portabilität (`Einstellungen & Daten`)**
   - Umschaltung zwischen Deutsch (`de`) und Englisch (`en`), Gewichtseinheit (`kg`/`lb`), Sichtbarkeit der Übersichtsbereiche, Abschalten der Online-Lebensmittelsuche sowie Konfiguration des Open-Food-Facts-Origins.
   - Passphrasengeschützte Sicherung und Wiederherstellung (`.mhbackup.json`, geeignet für frische Installationen), dokumentierter Klartext-Export und -Import (`morphhealth.portable` v1) sowie vollständiges Löschen aller lokalen Daten inklusive Schlüsselrotation.

---

## 2. Build, Prüfungen und Installation

### Voraussetzungen

Das Projekt verwendet die in `ENVIRONMENT.json` bereitgestellte lokale Toolchain (`Flutter 3.41.9`, `Dart 3.11.5`, Android SDK Platform 36 / Referenzgerät API 35 `x86_64`). Alle Dart-Abhängigkeiten sind in `app/pubspec.lock` gesperrt.

### Kompletten Release-Build ausführen

```bash
./build.sh
```

`build.sh` liest `food_api_base_url` und `food_api_user_agent` automatisch aus `ENVIRONMENT.json` (mit Rückfall auf `https://world.openfoodfacts.org` für reguläre Produktinstallationen) und erzeugt:

- `artifacts/morphhealth.apk` — signierte Release-APK (`de.themorpheus.morphhealth.local`) mit nativer Unterstützung für `x86_64`, `arm64-v8a` und `armeabi-v7a`.
- `artifacts/mh-bin` — nativ kompiliertes Linux-Binary für den Starter `./mh`.

### Statische Analyse, Tests und CLI-Verifikation ausführen

```bash
./check.sh
```

`check.sh` führt nacheinander `flutter analyze`, die komplette Test-Suite (`flutter test` inklusive Kryptografie-, Domain-, 10.000-Einträge-Performance- und UI-Widget-Tests), eine End-to-End-Sitzung über `./mh` gegen den lokalen Open-Food-Facts-Endpunkt sowie die Prüfung der erzeugten APK aus.

### Installation und Start auf dem Android-Referenzgerät

```bash
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 reverse tcp:8788 tcp:8788
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 install -r artifacts/morphhealth.apk
/home/morpheus/Android/Sdk/platform-tools/adb -s emulator-5560 shell am start -n de.themorpheus.morphhealth.local/.MainActivity
```

---

## 3. Wesentliche Produkt- und Architekturentscheidungen

1. **Ein einziger produktiver Fachkern (`app/lib/core/`):**
   Speicherverwaltung (`MorphHealthStore`), Verschlüsselung (`VaultCrypto`, `EncryptedBackupCodec`), Nährwertberechnung (`NutritionService`), Zyklusauswertung (`CycleForecastEngine`), Open-Food-Facts-Client (`OpenFoodFactsClient`) und Portabilitäts-Codec (`PortableCodec`) liegen in reinem Dart ohne UI-Abhängigkeiten vor. Sowohl die Flutter-App (`app/lib/main.dart`) als auch `./mh` (`app/bin/mh.dart`) rufen exakt denselben produktiven Code auf.
2. **Harmonisierung der Open-Food-Facts-Endpunkte v3.6 und `search.pl`:**
   Im Open-Food-Facts-Vertrag liefert `/cgi/search.pl` Nährwerte im Objekt `product.nutriments` (`*_100g`, überwiegend in Gramm normiert), während `/api/v3.6/product/{barcode}.json` strukturierte Angaben unter `product.nutrition.aggregated_set.nutrients` samt Herkunftskennzeichnung (`packaging` gegenüber `estimate`) bereitstellt. `OpenFoodFactsClient` wertet beide Darstellungen einheitlich aus, rechnet `mg`/`µg`/`g`/`kJ` präzise auf die internen Zieleinheiten um und verwirft reine Schätzwerte (`source == "estimate"`), damit Namenssuche und Barcode-Abruf konsistente Werte liefern.
3. **Nachvollziehbare persönliche Zyklusauswertung ohne Scheinpräzision:**
   `CycleForecastEngine` berechnet Abstände ausschließlich zwischen tatsächlichen Periodenbeginnen (`counts_as_period == true`). Unplausible Lücken außerhalb von `15..90` Tagen (etwa vergessene Protokollmonate) werden als Ausreißer markiert und aus der Mittelwertbildung herausgehalten. Die erwartete Zykluslänge kombiniert den robusten Median mit einem stärker auf die jüngsten sechs Zyklen gewichteten Mittelwert; das Planungsfenster skaliert mit der persönlichen Standardabweichung (mindestens `±2`, höchstens `±6` Tage). Es erfolgen keinerlei Eisprung-, Fruchtbarkeits-, Verhütungs- oder Diagnoseaussagen.
4. **Nährwert-Schnappschüsse in Verzehreinträgen:**
   Jeder `FoodDiaryEntry` speichert neben der `food_id` einen Schnappschuss der 100-g-/100-ml-Nährwerte zum Erfassungszeitpunkt, nutzt bei vorhandenen eigenen Lebensmitteln jedoch aktuelle Katalogkorrekturen und bleibt selbst nach dem Löschen eines Katalogeintrags vollständig auswertbar.
5. **Hohe Geschwindigkeit bei 10.000 Tagebucheinträgen:**
   Der lokale Tresor hält nach dem Entschlüsseln tagessortierte Hash-Indizes im Arbeitsspeicher bereit und schreibt Einzeländerungen über ein kompaktes AEAD-Write-Ahead-Log (`vault.wal.mhv1`) mit periodischer Snapshot-Kompaktierung (`vault.mhv1`). Tagesansichten arbeiten dadurch in konstanter Zeit `O(1)`, und Volltextsuchen über 10.000 Einträge antworten im einstelligen Millisekundenbereich.

---

## 4. Lokaler Wartungszugang `./mh` (JSON-Lines-Protokoll)

### Aufruf

```bash
./mh --data-dir /absoluter/pfad/daten \
     --key-file /absoluter/pfad/ausserhalb/master.key \
     [--now 2026-09-23T10:00:00+02:00] \
     [--food-base-url https://localhost:8788] \
     [--food-user-agent "MorphHealth/1.0-rc3 (benchmark build)"]
```

- `--data-dir ABS` *(Pflicht)*: Absoluter Pfad zum persistenten verschlüsselten Arbeitsverzeichnis (`vault.mhv1`, optional `vault.wal.mhv1`). Wird bei Bedarf angelegt.
- `--key-file ABS` *(Pflicht)*: Absoluter Pfad zu einer Datei mit exakt **32 rohen Schlüsselbytes** außerhalb von `--data-dir`.
- `--now RFC3339` *(Optional)*: Setzt die fachliche Uhr für diesen Prozess deterministisch auf den angegebenen Zeitstempel (einschließlich Kalendertag des angegebenen Offsets). Ohne `--now` gilt die Systemuhr.
- `--food-base-url HTTPS_ORIGIN` *(Optional)*: Überschreibt den HTTPS-Origin für `food.search` und `food.lookup`. Standard ist `food_api_base_url` aus `ENVIRONMENT.json` bzw. `https://world.openfoodfacts.org`.
- `--food-user-agent STRING` *(Optional)*: Überschreibt den `User-Agent`-Header für Open-Food-Facts-Anfragen.

### Ein- und Ausgabeformat

`./mh` gibt beim Start kein Banner aus, liest UTF-8-kodierte JSON-Zeilen von `stdin`, schreibt nach jeder Anfrage genau eine Antwortzeile auf `stdout` inklusive sofortigem `flush` und beendet sich bei `EOF` mit Rückgabewert `0`.

**Anfrage:**
```json
{"request_id": "req-1", "op": "nutrition.day", "date": "2026-09-23"}
```

**Erfolgsantwort:**
```json
{"request_id": "req-1", "ok": true, "data": { ... }}
```

**Fehlerantwort:**
```json
{"request_id": "req-1", "ok": false, "error": {"code": "INVALID_ARGUMENT", "message": "..."}}
```

### Unterstützte Operationen (`op`)

| `op` | Zusätzliche Anfragefelder | Inhalt von `data` | Mögliche Fehlercodes |
|---|---|---|---|
| `describe` | keine | Vollständige Selbstbeschreibung der Formate, aller 31 Nährstoffschlüssel, aller Operationen sowie ein direkt importierbares Beispieldokument unter `example_portable_document`. | — |
| `portable.export` | `"ack_plaintext": true` | Vollständiges Dokument im Format `morphhealth.portable` (`schema_version: 1`). | `ACK_REQUIRED` |
| `portable.import` | `"document": { ... }`, `"confirm_replace": true` | Ersetzt den Arbeitsdatenbestand atomar durch `document` und liefert `{ "replaced": true, "imported_at": "<RFC3339>", "counts": { ... } }`. | `CONFIRMATION_REQUIRED`, `INVALID_DOCUMENT` |
| `nutrition.day` | `"date": "YYYY-MM-DD"` | Tagesauswertung mit `date`, `water_ml`, `caffeine_from_foods_mg`, `caffeine_direct_mg`, `total_caffeine_mg`, `nutrients` (alle 31 Schlüssel), `goals`, `meals` (`breakfast`, `lunch`, `dinner`, `snack`), `meal_entries`, `water_entries`, `caffeine_entries`. | `INVALID_ARGUMENT` |
| `cycle.forecast` | `"on": "YYYY-MM-DD"` | Zykluseinschätzung zum Betrachtungstag `on`: `status`, `confidence`, `diary_only_mode`, `is_period_active_on_date`, `active_flow_intensity`, `current_cycle_day`, `last_period_start`, `predicted_next_start`, `predicted_next_end`, `predicted_window_start`, `predicted_window_end`, `days_until_expected_start`, `expected_cycle_length_days`, `expected_period_duration_days`, `variability_days`, `statistics` sowie `explanation` (`de` und `en`). | `INVALID_ARGUMENT` |
| `food.search` | `"q": "<Suchbegriff>"`, `"page": 1` (Ganzzahl `>= 1`, optional, Standard `1`) | Suchergebnisse `{ "query", "page", "page_size": 20, "total_count", "page_count", "items": [ FoodItem, ... ] }`. | `INVALID_ARGUMENT`, `NETWORK_ERROR`, `TIMEOUT`, `UPSTREAM_HTTP_ERROR` |
| `food.lookup` | `"barcode": "<EAN/GTIN>"` | `{ "barcode": "<Code>", "item": FoodItem }`. | `INVALID_ARGUMENT`, `PRODUCT_NOT_FOUND`, `NETWORK_ERROR`, `TIMEOUT`, `UPSTREAM_HTTP_ERROR` |

### Beispielsitzung mit `./mh`

```bash
head -c 32 /dev/urandom > ./demo.key
mkdir -p ./demo_data

./mh --data-dir "$(pwd)/demo_data" --key-file "$(pwd)/demo.key" --now 2026-09-23T10:00:00+02:00 <<'EOF'
{"request_id": 1, "op": "describe"}
{"request_id": 2, "op": "food.lookup", "barcode": "5411188112709"}
{"request_id": 3, "op": "food.search", "q": "haferflocken", "page": 1}
{"request_id": 4, "op": "nutrition.day", "date": "2026-09-23"}
{"request_id": 5, "op": "cycle.forecast", "on": "2026-09-23"}
EOF
```

---

## 5. Dokumentiertes Datenformat `morphhealth.portable` (Version 1)

Sowohl `portable.export` / `portable.import` als auch die entschlüsselte Nutzlast einer `.mhbackup.json`-Sicherung verwenden dasselbe maschinenlesbare JSON-Schema:

```json
{
  "format": "morphhealth.portable",
  "schema_version": 1,
  "app_version": "1.0.0",
  "exported_at": "2026-09-23T10:00:00+02:00",
  "preferences": {
    "locale_code": "de",
    "weight_unit": "kg",
    "visible_overview_modules": ["nutrition", "cycle", "weight", "symptoms"],
    "cycle_diary_only_mode": false,
    "online_food_enabled": true,
    "custom_food_api_base_url": null,
    "water_quick_amounts_ml": [150, 250, 330, 500]
  },
  "goals": {
    "water_ml": 2200.0,
    "calories_kcal": 2100.0,
    "protein_g": 90.0,
    "carbs_g": 240.0,
    "fat_g": 70.0
  },
  "foods": [ /* FoodItem[] */ ],
  "meal_entries": [ /* FoodDiaryEntry[] */ ],
  "water_entries": [ /* WaterEntry[] */ ],
  "caffeine_entries": [ /* CaffeineEntry[] */ ],
  "periods": [ /* PeriodEntry[] */ ],
  "weight_entries": [ /* WeightEntry[] */ ],
  "symptom_entries": [ /* SymptomEntry[] */ ]
}
```

### Entitätsfelder im Überblick

- **`FoodItem` (`foods[]`):**
  `id` (`String`), `source` (`"custom"` | `"open_food_facts"`), `barcode` (`String?`), `name` (`String`), `name_de` (`String?`), `name_en` (`String?`), `brand` (`String?`), `nutrition_basis` (`"100g"` | `"100ml"`), `serving_quantity` (`double > 0`, Gramm bzw. Milliliter je Portion), `serving_label` (`String?`), `nutrients_per_100` (`Map<NutrientKey, double>`), `is_favorite` (`bool`), `created_at` (`RFC3339`), `updated_at` (`RFC3339`).
- **`FoodDiaryEntry` (`meal_entries[]`):**
  `id`, `date` (`YYYY-MM-DD`), `recorded_at` (`RFC3339`), `meal_type` (`"breakfast"` | `"lunch"` | `"dinner"` | `"snack"`), `food_id`, `food_name_snapshot`, `brand_snapshot`, `amount` (`double > 0`), `unit` (`"g"` | `"ml"` | `"portion"`), `serving_quantity_snapshot` (`double > 0`), `nutrients_per_100_snapshot` (`Map<NutrientKey, double>`), `note` (`String?`).
- **`WaterEntry` (`water_entries[]`):**
  `id`, `date` (`YYYY-MM-DD`), `recorded_at` (`RFC3339`), `amount_ml` (`double > 0`), `note` (`String?`).
- **`CaffeineEntry` (`caffeine_entries[]`):**
  `id`, `date` (`YYYY-MM-DD`), `recorded_at` (`RFC3339`), `amount_mg` (`double > 0`), `source_label` (`String?`), `note` (`String?`).
- **`PeriodEntry` (`periods[]`):**
  `id`, `start_date` (`YYYY-MM-DD`), `end_date` (`YYYY-MM-DD?`, `null` bei laufender Periode), `intensity` (`"spotting"` | `"light"` | `"medium"` | `"heavy"`), `daily_flows` (`Map<YYYY-MM-DD, FlowIntensity>`), `counts_as_period` (`bool`, `false` für einzelnes Spotting ohne Zyklusneustart), `note` (`String?`).
- **`WeightEntry` (`weight_entries[]`):**
  `id`, `date` (`YYYY-MM-DD`), `recorded_at` (`RFC3339`), `weight_kg` (`double > 0`), `input_unit` (`"kg"` | `"lb"`), `input_value` (`double > 0`), `note` (`String?`).
- **`SymptomEntry` (`symptom_entries[]`):**
  `id`, `date` (`YYYY-MM-DD`), `recorded_at` (`RFC3339`), `name` (`String`), `intensity` (`int` von `0` bis `10`), `note` (`String?`).

### Alle 31 unterstützten Nährstoffschlüssel (`nutrients_per_100` & `nutrition.day`)

| Kategorie | JSON-Schlüssel | Einheit | Bezeichnung (DE / EN) |
|---|---|---|---|
| Makronährstoffe (4) | `calories_kcal` | `kcal` | Kalorien / Calories |
| | `protein_g` | `g` | Protein / Protein |
| | `carbs_g` | `g` | Kohlenhydrate / Carbohydrates |
| | `fat_g` | `g` | Fett / Fat |
| Erweiterte Angaben (6) | `saturated_fat_g` | `g` | Gesättigte Fettsäuren / Saturated fat |
| | `sugar_g` | `g` | Zucker / Sugars |
| | `fiber_g` | `g` | Ballaststoffe / Fiber |
| | `salt_g` | `g` | Salz / Salt |
| | `sodium_mg` | `mg` | Natrium / Sodium |
| | `caffeine_mg` | `mg` | Koffein / Caffeine |
| Vitamine (13) | `vitamin_a_ug` | `µg` | Vitamin A |
| | `vitamin_c_mg` | `mg` | Vitamin C |
| | `vitamin_d_ug` | `µg` | Vitamin D |
| | `vitamin_e_mg` | `mg` | Vitamin E |
| | `vitamin_k_ug` | `µg` | Vitamin K |
| | `vitamin_b1_mg` | `mg` | Vitamin B1 (Thiamin) |
| | `vitamin_b2_mg` | `mg` | Vitamin B2 (Riboflavin) |
| | `vitamin_b3_mg` | `mg` | Vitamin B3 (Niacin) |
| | `vitamin_b5_mg` | `mg` | Vitamin B5 (Pantothensäure / Pantothenic acid) |
| | `vitamin_b6_mg` | `mg` | Vitamin B6 |
| | `vitamin_b7_ug` | `µg` | Vitamin B7 (Biotin) |
| | `vitamin_b9_ug` | `µg` | Vitamin B9 (Folsäure / Folate) |
| | `vitamin_b12_ug` | `µg` | Vitamin B12 |
| Mineralstoffe (8) | `calcium_mg` | `mg` | Kalzium / Calcium |
| | `iron_mg` | `mg` | Eisen / Iron |
| | `magnesium_mg` | `mg` | Magnesium |
| | `potassium_mg` | `mg` | Kalium / Potassium |
| | `zinc_mg` | `mg` | Zink / Zinc |
| | `selenium_ug` | `µg` | Selen / Selenium |
| | `iodine_ug` | `µg` | Jod / Iodine |
| | `phosphorus_mg` | `mg` | Phosphor / Phosphorus |

---

## 6. Ausgeführte Tests und Prüfungen

1. **Statische Codeanalyse (`flutter analyze`):** 0 Warnungen, 0 Fehler über den gesamten Dart- und Flutter-Quellbaum.
2. **Kryptografie- und Tresortests (`app/test/core_domain_and_crypto_test.dart`):**
   - Verschlüsselung, WAL-Replay, Kompaktierung, Manipulationserkennung (`AUTH_FAILED`) und Ablehnung falscher Hauptschlüssel.
   - Passphrasengeschützte Sicherung (`Argon2id` + `ChaCha20-Poly1305`) inklusive Wiederherstellung auf einer frischen Speicherinstanz und Abweisung falscher Passphrasen.
3. **Fachlogik- und Vertragstests (`app/test/core_domain_and_crypto_test.dart`):**
   - Präzise Skalierung aller 31 Nährstoffe über `g`, `ml` und `portion`, Zusammenführung von Nahrungs- und Direktkoffein sowie Abgleich zwischen Open Food Facts `v3.6` und `search.pl`.
   - Persönliche Zyklusprognose, Ausreißerbehandlung, eigenständiges Spotting und Tagebuch-Modus.
   - Gewichtsumrechnung `kg` ↔ `lb` und Symptomverläufe (`0–10`).
4. **10.000-Einträge-Leistungstest (`app/test/core_domain_and_crypto_test.dart`):**
   - Mehrjähriger Bestand mit exakt **10.000 Tagebucheinträgen** (Mahlzeiten, Wasser, Koffein, Perioden, Gewicht, Symptome): verschlüsselter Snapshot-Schreib- und Ladevorgang, Volltext- und Bereichssuche sowie 28-Tage-Verlaufsberechnung zügig innerhalb der Zielgrenzen geprüft.
5. **UI-Widget-Tests in Referenzgeometrie (`app/test/widget_test.dart`):**
   - Geprüft auf `412 × 915 dp` (entspricht `1080 × 2400 px` bei `420 dpi` auf dem Referenzgerät): Übersicht mit Bereichsschaltern, gemeinsames Tagesdetail, 7-/28-Tage-Verläufe, Wasser-Schnellerfassung, Mahlzeiten-Wiedererfassung, Zyklus-Erklärungsdialog, `kg`/`lb`-Umschaltung, Historiensuche und Live-Sprachwechsel Deutsch/Englisch ohne Layout-Überläufe.
6. **End-to-End-Prüfung von `./mh` und Live-Lauf auf `emulator-5560`:**
   - Alle sieben JSON-Lines-Operationen gegen `https://localhost:8788` geprüft; Release-APK `artifacts/morphhealth.apk` auf dem Android-15-Referenzemulator (`emulator-5560`) installiert, gestartet und interaktiv inklusive echter Open-Food-Facts-Abrufe erprobt.

---

## 7. Bekannte Grenzen

- **Kein Kamerascanner:** Barcodes werden gemäß Auftrag per Nummerneingabe abgerufen; eine Kameravorschau ist bewusst weggelassen.
- **Mikronährstoffabdeckung öffentlicher Produktdaten:** Open Food Facts enthält für viele Handelsprodukte vollständige Makronährwerte, während Vitamine und Spurenelemente nur vorliegen, sofern sie auf der jeweiligen Produktverpackung deklariert und erfasst wurden. Nicht deklarierte Mikronährstoffe werden in der Produktdetailansicht transparent mit `—` gekennzeichnet und lassen sich in eigenen Lebensmitteln jederzeit vollständig hinterlegen.
- **Lokale Einzelnutzer-Datenhaltung:** Es findet keine automatische Synchronisation zwischen mehreren Endgeräten statt; der Gerätewechsel erfolgt kontrolliert über verschlüsselte `.mhbackup.json`-Sicherungen oder den dokumentierten `morphhealth.portable`-Export.
- **Keine medizinische Zweckbestimmung:** Die Zyklusauswertung dient ausschließlich der persönlichen Dokumentation und Alltagsplanung und gibt weder Diagnosen noch Empfehlungen zu Eisprung, Empfängnisverhütung oder medizinischer Behandlung ab.
