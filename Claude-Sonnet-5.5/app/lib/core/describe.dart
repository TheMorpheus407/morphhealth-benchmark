import 'civil.dart';
import 'clock.dart';
import 'core.dart';
import 'cycle.dart';
import 'models.dart';
import 'nutrients.dart';
import 'portable.dart';
import 'store.dart';

/// Ein gültiges Beispieldokument für `portable.import` (Format
/// `morphhealth-portable`, Version 1). Es deckt jeden Abschnitt ab und ist mit
/// echten Zahlen gerechnet, damit sich Ausgaben nachvollziehen lassen.
Map<String, Object?> exampleImportDocument() => {
  'format': portableFormat,
  'version': portableVersion,
  'settings': {
    'language': 'de',
    'weight_unit': 'kg',
    'areas': {'nutrition': true, 'cycle': true, 'weight': true, 'symptoms': true},
    'online_food': true,
    'cycle_forecast': true,
    'expected_cycle_length_days': null,
    'theme': 'system',
  },
  'goals': {'water_ml': 2000, 'energy_kcal': 2200, 'protein_g': 110, 'carbohydrates_g': 250, 'fat_g': 70},
  'foods': [
    {
      'id': 'food-oats',
      'source': 'custom',
      'name': 'Haferflocken (eigene Angabe)',
      'brand': 'Beispielmarke',
      'barcode': null,
      'basis': 'g',
      'serving': {'amount': 40, 'label': '1 Portion'},
      'nutrients': {
        'energy_kcal': 372,
        'protein_g': 13.5,
        'carbohydrates_g': 58.7,
        'fat_g': 7,
        'saturated_fat_g': 1.3,
        'sugars_g': 1.2,
        'fiber_g': 10,
        'salt_g': 0.02,
        'sodium_mg': 8,
        'vitamin_b1_mg': 0.59,
        'vitamin_b9_ug': 87,
        'calcium_mg': 54,
        'iron_mg': 4.6,
        'magnesium_mg': 130,
        'zinc_mg': 4.3,
      },
      'favorite': true,
    },
    {
      'id': 'food-cola',
      'source': 'off',
      'name': 'Cola Zero',
      'brand': 'Beispiel-Getränke',
      'barcode': '5000112611762',
      'basis': 'ml',
      'serving': {'amount': 330, 'label': '1 Dose (330 ml)'},
      'nutrients': {'energy_kcal': 0.3, 'sugars_g': 0, 'salt_g': 0.01, 'caffeine_mg': 10},
      'favorite': false,
    },
  ],
  'food_entries': [
    {
      'id': 'entry-1',
      'at': '2026-09-28T07:45:00',
      'meal': 'breakfast',
      'amount': 60,
      'unit': 'g',
      'food_id': 'food-oats',
      'food': {
        'name': 'Haferflocken (eigene Angabe)',
        'source': 'custom',
        'basis': 'g',
        'serving': {'amount': 40, 'label': '1 Portion'},
        'nutrients': {
          'energy_kcal': 372,
          'protein_g': 13.5,
          'carbohydrates_g': 58.7,
          'fat_g': 7,
          'fiber_g': 10,
          'vitamin_b1_mg': 0.59,
          'iron_mg': 4.6,
        },
      },
      'note': null,
    },
    {
      // Statt `food` genügt `food_id`, wenn das Lebensmittel unter `foods` steht.
      'id': 'entry-2',
      'at': '2026-09-28T12:30:00',
      'meal': 'lunch',
      'amount': 2,
      'unit': 'portion',
      'food_id': 'food-oats',
    },
    {
      'id': 'entry-3',
      'at': '2026-09-28T15:10:00',
      'meal': 'snack',
      'amount': 330,
      'unit': 'ml',
      'food_id': 'food-cola',
      'note': 'aus der Dose',
    },
  ],
  'water_entries': [
    {'id': 'water-1', 'at': '2026-09-28T08:00:00', 'ml': 250},
    {'id': 'water-2', 'at': '2026-09-28T13:00:00', 'ml': 500},
  ],
  'caffeine_entries': [
    {'id': 'caffeine-1', 'at': '2026-09-28T08:15:00', 'mg': 80, 'label': 'Kaffee'},
  ],
  'weight_entries': [
    {'id': 'weight-1', 'at': '2026-09-21T07:00:00', 'kg': 72.4},
    {'id': 'weight-2', 'at': '2026-09-28T07:05:00', 'kg': 72.0, 'note': 'nüchtern'},
  ],
  'periods': [
    {'id': 'period-1', 'start': '2026-06-08', 'end': '2026-06-12', 'flow': 'medium'},
    {'id': 'period-2', 'start': '2026-07-06', 'end': '2026-07-10', 'flow': 'medium'},
    {
      'id': 'period-3',
      'start': '2026-08-03',
      'end': '2026-08-07',
      'flow': 'medium',
      'day_flows': {'2026-08-03': 'light', '2026-08-04': 'heavy'},
      'notes': 'Krämpfe am zweiten Tag',
    },
    {'id': 'period-4', 'start': '2026-08-31', 'end': '2026-09-04', 'flow': 'light'},
  ],
  'symptom_entries': [
    {'id': 'symptom-1', 'name': 'Kopfschmerz', 'intensity': 4, 'at': '2026-09-28T16:00:00', 'note': 'nach dem Mittag'},
    {'id': 'symptom-2', 'name': 'Müdigkeit', 'intensity': 3, 'at': '2026-09-28T20:30:00'},
  ],
};

Map<String, Object?> _field(String type, String description, {bool required = false, Object? allowed, Object? def}) => {
  'type': type,
  'required': required,
  'description': description,
  'allowed': ?allowed,
  'default': ?def,
};

/// Beschreibung der Datenformate und Operationen für `describe`.
Future<Map<String, Object?>> buildDescribe() async {
  // Beispielergebnisse live aus dem Beispieldokument rechnen.
  final mem = MemoryPersistence();
  final core = await MorphCore.open(persistence: mem, clock: FixedClock(DateTime(2026, 9, 29, 12)));
  await core.importDocument(exampleImportDocument());
  final dayResult = core.nutritionDay(Day.parse('2026-09-28')).toJson();
  final forecastResult = core.cycleForecast(Day.parse('2026-09-20')).toJson();
  await core.close();

  final nutrients = [
    for (final n in nutrientCatalog)
      {
        'key': n.key,
        'unit': n.unit,
        'group': n.group.name,
        'name_de': nutrientNames[n.key]!.$1,
        'name_en': nutrientNames[n.key]!.$2,
      },
  ];

  return {
    'app': {
      'name': 'MorphHealth',
      'version': kAppVersion,
      'package': 'de.themorpheus.morphhealth.local',
      'about':
          'Ernährungstagebuch (Open Food Facts), persönlicher Periodentracker, Gewicht und Symptome. '
          'Lokale, verschlüsselte Daten. Dieser Zugang ruft dieselben Funktionen auf wie die Android-App.',
    },
    'protocol': {
      'transport':
          'JSON Lines: eine Anfrage pro Zeile auf stdin, eine Antwort pro Zeile auf stdout (sofort geleert). '
          'Kein Banner auf stdout, Diagnose nur auf stderr. EOF auf stdin beendet den Prozess. '
          'Anfragen werden der Reihe nach bearbeitet.',
      'request': {
        'request_id': 'beliebiger JSON-Wert; wird unverändert zurückgegeben',
        'op': 'Name der Operation (siehe operations)',
        '...': 'weitere Eingaben je Operation',
      },
      'response_ok': {'request_id': '<echo>', 'ok': true, 'data': '<Ergebnis der Operation>'},
      'response_error': {
        'request_id': '<echo>',
        'ok': false,
        'error': {'code': '<stabiler Code>', 'message': '<Klartext>', 'details': '<optional: Liste oder Objekt>'},
      },
      'error_codes': {
        'invalid_json': 'Die Zeile ist kein gültiges JSON.',
        'invalid_request': 'Die Anfrage ist kein Objekt oder op fehlt.',
        'unknown_op': 'Die Operation gibt es nicht.',
        'invalid_argument': 'Eine Eingabe fehlt oder hat das falsche Format (message nennt das Feld).',
        'ack_required': 'portable.export verlangt ack_plaintext: true.',
        'confirm_required': 'portable.import verlangt confirm_replace: true.',
        'invalid_document': 'Das Dokument ist ungültig; details listet Pfad und Grund. Der Bestand bleibt unverändert.',
        'wrong_key': 'Die Schlüsseldatei passt nicht zum Datenverzeichnis.',
        'corrupt': 'Der Datenbestand ist beschädigt.',
        'locked': 'Ein anderer Prozess verwendet das Datenverzeichnis.',
        'store_error': 'Sonstiger Fehler der lokalen Ablage.',
        'disabled': 'Die Online-Lebensmittelsuche ist in den Einstellungen ausgeschaltet.',
        'invalid_base_url': '--food-base-url ist kein HTTPS-Ursprung.',
        'invalid_barcode': 'Barcode nicht 8 bis 14 Ziffern.',
        'empty_query': 'Suchbegriff leer.',
        'not_found': 'Kein Produkt zu diesem Barcode.',
        'offline': 'Keine Verbindung zum Lebensmitteldienst.',
        'timeout': 'Zeitüberschreitung beim Lebensmitteldienst.',
        'tls': 'Zertifikat oder TLS-Verbindung abgelehnt (die Prüfung lässt sich nicht abschalten).',
        'rate_limited': 'Lebensmitteldienst überlastet (HTTP 429/503).',
        'http_error': 'Unerwarteter HTTP-Status vom Lebensmitteldienst.',
        'bad_response': 'Antwort des Lebensmitteldienstes nicht auswertbar.',
        'internal_error': 'Unerwarteter Fehler.',
      },
    },
    'cli': {
      'usage':
          './mh --data-dir ABS --key-file ABS [--now RFC3339] [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]',
      'data_dir':
          'Persistenter Arbeitsdatenbestand (wird angelegt). Enthält nur verschlüsselte Dateien: '
          'store.mhs (Snapshot), store.mhj (Journal), store.lock.',
      'key_file':
          'Genau 32 rohe Byte, außerhalb des Datenverzeichnisses. Sie sind der Hauptschlüssel: '
          'daraus wird per HKDF-SHA-256 (Salt aus dem Snapshot) der AES-256-GCM-Schlüssel abgeleitet. '
          'Ohne diese Datei sind die Daten nicht lesbar; ein falscher Schlüssel ergibt den Fehler wrong_key. '
          'Beispiel: head -c 32 /dev/urandom > key.bin',
      'now':
          'Setzt die fachliche Uhr dieses Prozesses (angehalten, RFC 3339). Sie bestimmt "heute" und exported_at. '
          'Ohne die Option gilt die Systemuhr. Der Zeitpunkt wird in die Ortszeit des Prozesses (Umgebungsvariable TZ) '
          'umgerechnet, genau wie bei einer verstellten Systemuhr.',
      'food_base_url':
          'HTTPS-Ursprung des Lebensmitteldienstes (nur Schema, Host, Port). Vorrang vor Einstellung und Build-Vorgabe.',
      'food_user_agent': 'User-Agent der Lebensmittelabfragen. Vorrang vor der Build-Vorgabe.',
      'build_defaults': {'food_base_url': kDefaultFoodBaseUrl, 'food_user_agent': kDefaultFoodUserAgent},
    },
    'operations': {
      'describe': {'input': {}, 'output': 'Dieses Dokument.'},
      'portable.export': {
        'input': {
          'ack_plaintext': 'muss true sein: Der Export ist unverschlüsselter Klartext mit allen Gesundheitsdaten.',
        },
        'output':
            'Das vollständige Dokument im Format morphhealth-portable (siehe formats.portable_document). '
            'Nach portable.import wieder gleichwertig importierbar.',
      },
      'portable.import': {
        'input': {
          'document':
              'Dokument im Format morphhealth-portable (siehe example_import_document), als JSON-Objekt oder als JSON-Text.',
          'confirm_replace':
              'muss true sein: Der Arbeitsdatenbestand wird vollständig ersetzt (auch Einstellungen, wenn enthalten).',
        },
        'output': {
          'replaced': true,
          'imported':
              'Anzahl je Abschnitt: foods, food_entries, water_entries, caffeine_entries, weight_entries, periods, symptom_entries',
          'total_records': 'Summe',
          'settings_imported': 'bool',
          'goals_imported': 'bool',
          'warning_count': 'Zahl der Warnungen (unbekannte Felder, überschneidende Perioden, ...)',
          'warnings': '[{path, message}] (höchstens 50)',
        },
        'notes': [
          'Fehlt ein Abschnitt, ist er nach dem Import leer (Ersatz, kein Zusammenführen).',
          'Ist das Dokument ungültig, schlägt die Anfrage mit invalid_document fehl und der Bestand bleibt unverändert.',
          'Fehlende ids werden erzeugt; ids müssen je Abschnitt eindeutig sein.',
        ],
      },
      'nutrition.day': {
        'input': {'date': 'YYYY-MM-DD (ein angehängter Zeitanteil wird ignoriert)'},
        'output': {
          'date': 'Tag',
          'entry_count': 'Zahl der Verzehreinträge',
          'totals':
              'Tagessumme aller ${nutrientCatalog.length} Nährstoffe (Schlüssel siehe formats.nutrients), Zahl, 0 wenn nichts erfasst. '
              'caffeine_mg enthält auch zusätzlich erfasstes Koffein.',
          'entries_with_data':
              'Je Nährstoff: Zahl der Verzehreinträge mit Angabe (0 = keine Angabe, nicht dasselbe wie Wert 0).',
          'water_ml': 'Summe der Wassereinträge',
          'caffeine': '{total_mg, from_foods_mg, additional_mg}',
          'meals':
              'Vier Mahlzeiten (breakfast, lunch, dinner, snack) mit entry_count und totals (energy_kcal, protein_g, carbohydrates_g, fat_g).',
          'entries':
              'Verzehreinträge des Tages mit Menge, amount_base (in g/ml) und nutrients (nur Nährstoffe mit Angabe).',
          'water_entries': 'Wassereinträge',
          'caffeine_entries': 'Zusätzliche Koffeineinträge',
          'goals': 'Tagesziele (null = keines)',
          'goal_progress': 'Je gesetztem Ziel: value, goal, remaining, percent',
        },
        'notes': [
          'Nährwerte eines Eintrags = Nährwerte je 100 g/ml * Menge in g/ml / 100. '
              'Bei Portionen: Menge = amount * food.serving.amount.',
          'Ist die Einheit g oder ml und weicht von der Bezugsgröße des Lebensmittels ab, gilt 1 ml = 1 g.',
          'Zahlen sind auf 4 Nachkommastellen gerundet, Summen werden vor dem Runden gebildet.',
        ],
      },
      'cycle.forecast': {
        'input': {'on': 'YYYY-MM-DD, der Betrachtungstag (ein angehängter Zeitanteil wird ignoriert)'},
        'output': {
          'status': 'no_data | insufficient_data | in_period | predicted | overdue | stale | disabled',
          'available': 'true, wenn predicted_start vorhanden ist',
          'basis': 'history (eigene Abstände) | manual (eingestellte Zykluslänge) | none',
          'confidence': 'none | low | medium | high',
          'in_period / period_day': 'Betrachtungstag liegt in einer erfassten Periode (Tag 1 = Beginn)',
          'cycle_day': 'Tag im Zyklus (1 = Beginn der letzten Periode)',
          'last_period_start': 'letzter Periodenbeginn bis einschließlich on',
          'predicted_start': 'letzter Beginn + gerundeter Mittelwert der Abstände',
          'window_earliest / window_latest':
              'Zeitfenster (Mittelwert der Abstände +/- Standardabweichung, mindestens 1, höchstens 7 Tage)',
          'days_until_predicted': 'Tage bis predicted_start (0 = heute); bei overdue null',
          'days_overdue': 'Tage seit predicted_start (nur overdue)',
          'predicted_period_length_days / predicted_end': 'typische Periodendauer aus abgeschlossenen Perioden',
          'average_cycle_length_days / cycle_length_std_days':
              'Mittelwert und Standardabweichung der verwendeten Abstände',
          'cycles_used / cycle_lengths_used': 'die verwendeten Abstände (höchstens die letzten 6 plausiblen)',
          'cycle_intervals': 'alle Abstände mit used und excluded_reason',
          'upcoming': 'die nächsten drei voraussichtlichen Beginne mit Zeitfenster',
          'rules': 'Kurzfassung des Verfahrens',
          'explanation': '{de: [Absätze], en: [Absätze]} verständliche Erklärung',
        },
        'notes': [
          'Nur Perioden mit Beginn bis einschließlich on zählen (Stand des Betrachtungstags).',
          'Abstände zwischen zwei Periodenbeginnen unter $kMinCycleDays oder über $kMaxCycleDays Tagen werden nicht verwendet.',
          'Einträge, die nur Spotting enthalten, zählen nicht als Periodenbeginn.',
          'Es werden weder Eisprung noch fruchtbare Tage berechnet; keine medizinische Aussage.',
          'Ist die Prognose in den Einstellungen ausgeschaltet (cycle_forecast=false), ist status disabled.',
        ],
      },
      'food.search': {
        'input': {'q': 'Suchbegriff', 'page': 'Seite ab 1 (Standard 1)'},
        'output': {
          'query': 'Suchbegriff',
          'page': 'Seite',
          'page_size': 20,
          'total': 'Treffer insgesamt',
          'has_more': 'bool',
          'results':
              'Liste von Lebensmitteln (Format wie foods im Exportdokument, ohne id): '
              'name, brand, barcode, source=off, basis, serving, nutrients je 100 g/ml',
        },
        'notes': [
          'Anfrage: GET {base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20&fields=... '
              '(Feldprojektion erlaubt).',
          'Es zählen angegebene Werte (klassisches Feld nutriments, _100g). Geschätzte Werte gibt es dort nicht.',
        ],
      },
      'food.lookup': {
        'input': {'barcode': '8 bis 14 Ziffern (Leerzeichen und Bindestriche werden entfernt)'},
        'output': {
          'food': 'Lebensmittel wie in food.search',
          'nutrition_source':
              'input_set | input_set_per_serving | aggregated_set | legacy_nutriments: Herkunft der Nährwerte im Produktabruf',
          'barcode': 'normalisierte Barcode-Nummer',
        },
        'notes': [
          'Anfrage: GET {base}/api/v3.6/product/{barcode}.json?fields=...',
          'Neues Schema (nutrition.input_sets/aggregated_set): bevorzugt ein Satz "wie verkauft" je 100 g/100 ml von '
              'manufacturer/packaging; danach je Portion (umgerechnet), danach "zubereitet"; Schätzungen (source=estimate) '
              'werden nie verwendet. Fehlende Werte werden aus weiteren angegebenen Sätzen derselben Art ergänzt.',
          'Klassisches Schema (nutriments): <name>_100g.',
          'Kein Produkt: ok=false mit error.code not_found.',
        ],
      },
    },
    'formats': {
      'conventions': {
        'date': 'YYYY-MM-DD (Kalendertag, keine Zeitzone).',
        'timestamp':
            'YYYY-MM-DDTHH:MM[:SS] als Ortszeit des Nutzers. Nur ein Datum ist erlaubt (dann 00:00). '
            'Eine angehängte Zeitzone (Z, +02:00) wird ignoriert: Es gilt die notierte Uhrzeit.',
        'numbers': 'JSON-Zahlen (Zahlen als Text wie "12,5" werden beim Import ebenfalls verstanden).',
        'weights': 'Immer Kilogramm im Dokument; die Anzeige in kg oder lb ist eine Einstellung.',
        'ids': 'Textkennung, je Abschnitt eindeutig. Beim Import optional.',
        'unknown_fields': 'Unbekannte Felder werden ignoriert und als Warnung gemeldet.',
      },
      'portable_document': {
        'format': _field('string', 'Muss "$portableFormat" sein.', required: false, def: portableFormat),
        'version': _field('integer', 'Format-Version, aktuell $portableVersion.'),
        'exported_at': _field('string', 'RFC 3339, nur im Export gesetzt, beim Import ignoriert.'),
        'app': _field('object', '{name, version}, nur Information.'),
        'settings': _field(
          'object',
          'Einstellungen: language (de|en), weight_unit (kg|lb), '
              'areas {nutrition, cycle, weight, symptoms: bool}, online_food (bool), cycle_forecast (bool), '
              'expected_cycle_length_days (15..60 oder null), theme (system|light|dark). Alles optional.',
        ),
        'goals': _field(
          'object',
          'Freiwillige Tagesziele, null = kein Ziel: water_ml, energy_kcal, protein_g, carbohydrates_g, fat_g.',
        ),
        'foods': _field(
          'array',
          'Bibliothek (eigene Lebensmittel, Favoriten, übernommene Produkte). Objekt: '
              '{id, name*, brand, barcode, source (custom|off), basis (g|ml), serving {amount>0 in Bezugseinheit, label}, '
              'nutrients {...je 100 g/ml}, favorite, prepared, created_at}.',
        ),
        'food_entries': _field(
          'array',
          'Verzehreinträge. Objekt: {id, at*, meal (breakfast|lunch|dinner|snack), amount*>0, '
              'unit (g|ml|portion), food (Lebensmittel-Objekt wie oben, ohne id/favorite) ODER food_id (Verweis auf foods), note}. '
              'Bei unit=portion ist food.serving nötig.',
        ),
        'water_entries': _field('array', 'Wasser: {id, at*, ml*>0}'),
        'caffeine_entries': _field('array', 'Zusätzliches Koffein: {id, at*, mg*>0, label}'),
        'weight_entries': _field(
          'array',
          'Gewicht: {id, at*, kg* (1..700), note}. Mehrere Einträge je Tag möglich; '
              'der Tageswert ist der letzte Eintrag des Tages.',
        ),
        'periods': _field(
          'array',
          'Perioden: {id, start*, end (null = läuft), flow (spotting|light|medium|heavy), '
              'day_flows {YYYY-MM-DD: flow}, notes}. Höchstens 60 Tage je Periode.',
        ),
        'symptom_entries': _field(
          'array',
          'Symptome: {id, name* (1..80 Zeichen), intensity* (ganze Zahl 0..10), at*, note}',
        ),
      },
      'enums': {
        'meal': [for (final m in Meal.values) m.name],
        'unit': [for (final u in AmountUnit.values) u.name],
        'basis': [for (final b in Basis.values) b.name],
        'flow': [for (final f in FlowLevel.values) f.name],
        'source': [for (final s in FoodSource.values) s.name],
      },
      'nutrients': nutrients,
      'nutrient_aliases': {
        'hinweis':
            'Beim Import werden zusätzlich diese Kurzschreibweisen für Größen mit eindeutiger Einheit akzeptiert. '
            'Der Export verwendet immer die Schlüssel aus formats.nutrients.',
        'kcal': 'energy_kcal',
        'protein': 'protein_g',
        'carbs': 'carbohydrates_g',
        'fat': 'fat_g',
        'sugar': 'sugars_g',
        'fiber': 'fiber_g',
        'salt': 'salt_g',
      },
      'encrypted_at_rest': {
        'store.mhs':
            'Snapshot: "MHS1" | salt 16 | seq u64 | kcv 16 | AES-256-GCM(gzip(JSON)); Schlüssel = HKDF-SHA-256(Hauptschlüssel, salt).',
        'store.mhj':
            'Journal: "MHJ1" | salt | base_seq | kcv, dann Einträge len u32 | AES-256-GCM(JSON-Änderungen); '
            'Sequenznummer in den authentifizierten Zusatzdaten.',
      },
    },
    'example_import_document': exampleImportDocument(),
    'example_requests': [
      {'request_id': 1, 'op': 'describe'},
      {'request_id': 2, 'op': 'portable.import', 'confirm_replace': true, 'document': '<example_import_document>'},
      {'request_id': 3, 'op': 'nutrition.day', 'date': '2026-09-28'},
      {'request_id': 4, 'op': 'cycle.forecast', 'on': '2026-09-20'},
      {'request_id': 5, 'op': 'food.search', 'q': 'haferflocken', 'page': 1},
      {'request_id': 6, 'op': 'food.lookup', 'barcode': '4008400402222'},
      {'request_id': 7, 'op': 'portable.export', 'ack_plaintext': true},
    ],
    'example_results': {
      'note': 'Live aus example_import_document gerechnet.',
      'nutrition.day 2026-09-28': dayResult,
      'cycle.forecast 2026-09-20': forecastResult,
    },
  };
}
