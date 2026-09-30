# Datenvertrag v1 und JSONL

Der Vertrag ist im produktiven `app/lib/core/contract.dart` definiert. `describe` gibt ihn einschließlich eines vollständigen importierbaren `example_document` zurück. Android und Linux verwenden dieselben Modelle, Validatoren und Berechnungen.

## Anfrage und Antwort

Eine Anfrage ist ein JSON-Objekt auf einer UTF-8-Zeile. `request_id` muss vorhanden sein und darf String, Zahl oder null sein. `op` ist ein String. Die Antwort wird pro Anfrage sofort ausgegeben und geflusht; kein Banner. EOF beendet den Prozess.

```json
{"request_id":"a","op":"nutrition.day","date":"2026-09-20"}
{"request_id":"a","ok":true,"data":{"date":"2026-09-20","...":"..."}}
{"request_id":"b","ok":false,"error":{"code":"invalid_date","message":"invalid_date"}}
```

| Operation | Weitere Eingabe | Ergebnis |
|---|---|---|
| `describe` | — | Vertrag, Typen, Einheiten, `example_document` |
| `portable.export` | `ack_plaintext:true` | vollständiges portables Dokument |
| `portable.import` | `document`, `confirm_replace:true` | `{"replaced":true,"counts":{"foods":n,...}}` |
| `nutrition.day` | `date:YYYY-MM-DD` | Tagesresultat unten |
| `cycle.forecast` | `on:YYYY-MM-DD` | persönliche Einschätzung unten |
| `food.search` | `q` nichtleer, `page` Integer ≥1 | `query` String, `page` Integer, `page_size:20`, `count` Integer/null, `has_more` Boolean, `products` Lebensmittelarray, `attribution` Objekt |
| `food.lookup` | `barcode` String mit 4–24 Ziffern | `barcode` String, `found` Boolean, `product` Lebensmittel/null, `attribution` Objekt |

Fehlende Bestätigungen, unbekannte Operationen, Parsefehler und fachliche Validierungsfehler ergeben eine Fehlerantwort; weitere Zeilen werden weiter verarbeitet. Startfehler (Pfad, Schlüssel, Lock, Datenspeicher, Origin, Uhr) gehen auf stderr, Exitstatus 2. Keine Daten werden dabei still ersetzt.

## Portables Dokument

```json
{
  "format": "morphhealth",
  "version": 1,
  "settings": {
    "language": "de",
    "weight_unit": "kg",
    "sections": {"nutrition":true,"cycle":true,"weight":true,"symptoms":true},
    "goals": {"water":2000},
    "online_enabled": false,
    "cycle_prediction": true
  },
  "foods": [{
    "id":"oats", "name":"Haferflocken", "source":"custom", "base_unit":"g",
    "serving_size":40, "grams_per_ml":null, "favorite":true,
    "nutrients":{"calories":370,"protein":13,"carbs":59,"fat":7,"vitamin_b7":null}
  }],
  "consumption":[{
    "id":"meal-1","at":"2026-09-20T08:00:00","food_id":"oats",
    "amount":1,"unit":"portion","meal":"breakfast","note":""
  }],
  "drinks":[{"id":"water-1","at":"2026-09-20T08:15:00","kind":"water","amount":250}],
  "weights":[{"id":"weight-1","date":"2026-09-20","kg":70}],
  "periods":[
    {"id":"p1","start":"2026-07-25","end":"2026-07-29","strength":"medium"},
    {"id":"p2","start":"2026-08-22","end":"2026-08-26","strength":"light"},
    {"id":"p3","start":"2026-09-20","end":null,"strength":"medium"}
  ],
  "bleeding":[],
  "symptoms":[{"id":"s1","at":"2026-09-20T09:00:00","name":"Kopfschmerz","intensity":3}]
}
```

Das Beispiel ist synthetisch und direkt importierbar. `format` und `version` sind erforderlich. `exported_at` ist optionaler String; Export setzt ihn auf die fachliche Uhr. Einstellungen und Tabellen dürfen fehlen; sie bekommen die dokumentierten Standardwerte beziehungsweise leere Arrays. Unbekannte Felder und unbekannte Nährstoffnamen werden abgelehnt, damit keine Daten unbemerkt verloren gehen.

IDs sind nichtleere Strings, maximal 128 Zeichen, pro Tabelle eindeutig. Namen/Marken/Barcodes sind Strings. Notizen sind optionaler String oder null, maximal 10.000 Zeichen. Daten sind echte ISO-Kalendertage `YYYY-MM-DD`. `at` ist **lokale Wanduhrzeit ohne Zeitzone**, `YYYY-MM-DDTHH:mm:ss` mit optional 1–6 Nachkommastellen der Sekunde; Stunden 00–23, Minuten/Sekunden 00–59. Der gespeicherte Tag ändert sich durch Gerätezonenwechsel nicht. `--now` akzeptiert RFC3339 und übernimmt dessen lokale Datum-/Uhrzeitfelder; der Offset wird nicht für eine Verschiebung des Kalendertags verwendet.

### Lebensmittel und Verzehr

`foods`: erforderlich `id`, `name`, `source` (`custom|off`), `base_unit` (`g|ml`), `nutrients` (Objekt). Optional: `name_en`, `brand`, `barcode`, `serving_size` (positive Zahl in Basiseinheit pro Portion oder null), `grams_per_ml` (positive Dichte oder null), `favorite` (Boolean, Standard false), `estimated` (Liste von Nährstoff-IDs, Standard leer). Für `off` verwendet der normalisierte Datensatz ID `off_<barcode>` und speichert den Barcode als String.

Nährstoffwerte sind Zahlen ≥0 **je 100 Basiseinheiten**; null/fehlend heißt unbekannt. Exporte können sowohl null-Werte als auch weggelassene unbekannte Werte enthalten. Keine Normziele werden automatisch gesetzt.

`consumption`: `id`, `at`, `food_id` String, `amount` positive Zahl, `unit` (`g|ml|portion`), `meal` (`breakfast|lunch|dinner|snack`); optional `food` Snapshot und `note`. Fehlt `food` beim Import, wird ein Lebensmittel aus `foods` mit passender ID benötigt. Der Validator erzeugt daraus den Snapshot. Export enthält den vollständigen Snapshot, sodass gelöschte oder geänderte Stammdaten alte Verzehre nicht verändern. Snapshot-ID und `food_id` müssen identisch sein.

Skalierung: `Nährstoff × Basismenge / 100`. Portionen verwenden `amount × serving_size`. Bei g/ml-Wechsel ist `grams_per_ml` erforderlich: ml → g multipliziert mit Dichte, g → ml dividiert durch Dichte. Fehlt eine nötige Portionsgröße oder Dichte, wird der Eintrag abgelehnt.

| Nährstoff-ID | Einheit |
|---|---|
| `calories` | kcal |
| `protein`, `carbs`, `fat`, `saturated_fat`, `sugar`, `fiber`, `salt` | g |
| `sodium`, `caffeine` | mg |
| `vitamin_a`, `vitamin_d`, `vitamin_k` | µg |
| `vitamin_c`, `vitamin_e` | mg |
| `vitamin_b1`, `vitamin_b2`, `vitamin_b3`, `vitamin_b5`, `vitamin_b6` | mg |
| `vitamin_b7`, `vitamin_b9`, `vitamin_b12` | µg |
| `calcium`, `iron`, `magnesium`, `potassium`, `zinc`, `phosphorus` | mg |
| `selenium`, `iodine` | µg |

### Weitere Tabellen

| Tabelle | Erforderlich | Optional / Bedeutung |
|---|---|---|
| `drinks` | `id,at,kind,amount` | `note`; `kind=water` → ml, `kind=caffeine` → mg; Menge positiv |
| `weights` | `id,date,kg` | `note`; kg positiv, mehrere Einträge pro Datum erlaubt |
| `periods` | `id,start,strength` | `end` inklusiv oder null/laufend, `note`; Stärke `spotting|light|medium|heavy` |
| `bleeding` | `id,date,strength` | `note`; genau ein Override je Datum, Stärke zusätzlich `none`; kein neuer Periodenbeginn |
| `symptoms` | `id,at,name,intensity` | `note`; Name nichtleer, max. 200 Zeichen; Intensität ganzzahlig 0–10 |

Perioden dürfen sich einschließlich ihrer Randtage nicht überschneiden. Eine laufende Periode endet erst durch eine ausdrückliche Korrektur; ein späterer Beginn erfordert zuerst deren Ende. Ein Tagesoverride hat Vorrang vor einer Periodenstärke, auch bei `none`.

Bei `end:null` zeigt die Tages-/Kalenderauswertung Blutung nur zwischen Beginn und der heutigen fachlichen Uhr. Ein offenes Ende erzeugt keine aufgezeichneten Zukunftstage. Die Historie bewahrt den unveränderten offenen Periodeneintrag.

`settings`: Sprache `de|en` (de), Gewichtseinheit `kg|lb` (kg), `sections` mit vier Boolean-Werten (alle true), `online_enabled` (false), `cycle_prediction` (true). `goals` erlaubt `water` in ml, `calories` in kcal und `protein/carbs/fat` in g; positive Zahl oder null/fehlend. Import ersetzt Daten **einschließlich** Einstellungen.

## Tagesresultat

| Feld | Typ / Inhalt |
|---|---|
| `date` | ISO-Datum String |
| `nutrients` | Objekt mit allen 31 IDs → Zahl/null; Summe bekannter Beiträge |
| `units` | Objekt ID → Einheit String |
| `food_count` | Anzahl Verzehre, Integer |
| `known_food_count` | Objekt ID → Anzahl Verzehre mit bekanntem Wert, Integer |
| `incomplete_nutrients` | Liste IDs, für die nicht jeder Verzehr einen Wert hat |
| `water_ml` | Zahl, Summe Wasser |
| `additional_caffeine_mg` | Zahl, Summe separat erfasstes Koffein |
| `goals` | das Ziele-Objekt |
| `entries` | Verzehre einschließlich Snapshot, `base_amount` Zahl und berechneter `nutrients` |
| `drinks` | Wasser-/Koffein-Einträge dieses Tages |

Lebensmittel-Koffein und zusätzliches Koffein sind in `nutrients.caffeine` gemeinsam enthalten. Die Abdeckung bezieht sich ausschließlich auf Lebensmittel; zusätzliche Koffeinaufzeichnungen ergänzen die Summe und verändern die Lebensmittel-Abdeckungszahl nicht. Ohne bekannte Beiträge ist ein Nährstoff null; Wasser ohne Einträge ist 0. Ein unbekannter Lebensmittelwert ist kein Nullbeitrag. Ziele sind reine Nutzerwerte, keine Bewertung.

## Zyklusresultat

| Feld | Typ |
|---|---|
| `on` | betrachtetes ISO-Datum String |
| `enabled` | Boolean |
| `method` | `median_last_6_start_intervals|journal_only` |
| `recorded_starts` | Integer, verwertbare aufgezeichnete Beginne bis `on` |
| `intervals_days` | Array Integer, letzte höchstens sechs Startabstände |
| `sample_count` | Integer |
| `median_cycle_days` | Zahl/null, Median der Abstände |
| `median_absolute_deviation_days` | Zahl/null |
| `observed_min_days,observed_max_days` | Integer/null |
| `median_bleeding_days` | Integer/null, gerundeter Median der letzten höchstens sechs abgeschlossenen Dauern |
| `latest_start` | ISO-Datum/null |
| `cycle_day` | Integer/null, 1-basiert seit letztem aufgezeichnetem Beginn |
| `predicted_start,window_start,window_end,estimated_end` | ISO-Datum/null |
| `recorded_period` | Periodenobjekt am Betrachtungstag/null |
| `status` | `journal_only|insufficient_history|upcoming|in_window|past_window` |
| `variability` | `unknown|limited_history|variable|more_consistent` |
| `explanation` | Objekt mit dokumentierten Regeln |

Die Einschätzung verwendet nur Beginne ≤ `on` und schließt `strength=spotting` aus. Für die Dauer zählen nur abgeschlossene Perioden mit Ende ≤ `on`. Start = letzter aufgezeichneter Beginn + gerundeter Median; Fenster = Start ± `max(2,ceil(1.5×MAD))`; Ende = Start + Dauer −1. Bei wenig Historie (<3 Abständen) gilt `limited_history`; bei mindestens drei und einer beobachteten Spanne >7 Tage `variable`. Diese Bezeichnungen sind Beschreibungen der Datenbasis, keine klinischen Kategorien. Ein vergangenes Fenster wird nicht weitergeschoben. Tagebuchmodus lässt Vorhersagedaten null.

`explanation` enthält die Boolean-Felder `uses_recorded_starts_only`, `excludes_future_and_spotting_starts`, `missed_prediction_is_not_advanced` und den String `window_rule`.

## Open Food Facts

Verwendet werden exakt:

- `GET {origin}/api/v3.6/product/{barcode}.json`
- `GET {origin}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20`

Die Projektion enthält Code, Namen, Marken, Nährwerte (`nutriments` und `nutrition`), Portion und Nährwertbasis. v3.6-Resultate verwenden `nutrition.aggregated_set`; strukturierte Einheiten g/mg/µg und kcal/kJ werden explizit normalisiert. Legacy-`*_100g`-Massenwerte sind bereits in Gramm normalisiert; `*_unit` beschreibt dort die Eingabeeinheit und wird nicht nochmals auf `*_100g` angewendet. Bei `per=100ml` wird ml zur Basiseinheit. Portion-basierte strukturierte Angaben benötigen eine bekannte Portionsmenge für die Hochrechnung.

Energie nutzt kcal oder kJ/4,184. Für B3, B5, B7 und K werden die OFF-Namen `vitamin-pp`, `pantothenic-acid`, `biotin` und `vitamin-k/phylloquinone` sowie Aliasfelder unterstützt. Fehlt nur Salz oder Natrium, wird der andere Wert mit Verhältnis 2,5 abgeleitet und als geschätzt gekennzeichnet. Andere fehlende Werte bleiben null. Schätz-/Vergleichsmarker werden in `estimated` kenntlich gemacht. Der Zahlenwert eines qualifizierten Quellenwerts ist keine garantierte exakte Aufnahme.

`attribution` ist `{"name":"Open Food Facts","license":"ODbL 1.0","url":"https://world.openfoodfacts.org"}`. Die externe technische Referenz ist die [offizielle API-Dokumentation](https://openfoodfacts.github.io/openfoodfacts-server/api/), einschließlich [v3.6-Schema](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-v3/) und [Legacy-Nährwertschema](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-cheatsheet/). Die Testfixtures stammen aus dem bereitgestellten OFF-Dump-Origin, Produkt `5411188112709`, Datenstand 2026-09-22.
