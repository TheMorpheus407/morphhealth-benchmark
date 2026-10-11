// Fachlogik des Wartungszugangs `mh` (SPEC P10).
//
// Reiner Dart — dieselben Funktionen wie die App (Repository, Tagesauswertung,
// Zykluseinschätzung, OFF-Client). Die Ein-/Ausgabe (JSON Lines über
// stdin/stdout) liegt in bin/mh.dart.
library;

import 'dart:io';

import '../core/clock.dart';
import '../core/exceptions.dart';
import '../core/parse.dart';
import '../data/repository.dart';
import '../food/off_client.dart';
import '../food/off_mapping.dart';
import '../model/document.dart';
import '../nutrition/day.dart';
import '../cycle/forecast.dart';
import '../nutrients/nutrients.dart';
import 'example_document.dart';

/// Konfiguration des mh-Prozesses.
class MhConfig {
  final Directory dataDir;
  final File keyFile;
  final Clock clock;
  final OffConfig offConfig;
  final AppInfo appInfo;
  final String clockSource; // 'system' | '--now'

  const MhConfig({
    required this.dataDir,
    required this.keyFile,
    required this.clock,
    required this.offConfig,
    required this.clockSource,
    this.appInfo = const AppInfo(),
  });
}

/// Verarbeitet eine einzelne Anfrage und liefert die Antwort.
class MhService {
  final MorphRepository repo;
  final OffConfig offConfig;
  final Clock clock;
  final AppInfo appInfo;
  final MhConfig config;
  final OffClient _off;

  MhService(this.repo, this.config)
      : offConfig = config.offConfig,
        clock = config.clock,
        appInfo = config.appInfo,
        _off = OffClient(config.offConfig);

  /// Verarbeitet eine Anfrage-Zeile (JSON-Objekt) und liefert die Antwort
  /// als Map (mit request_id, ok, data bzw. error).
  Future<Map<String, dynamic>> handleRequest(Map<String, dynamic> request) async {
    final dynamic requestId = request['request_id'];
    try {
      final dynamic op = request['op'];
      if (op is! String) {
        throw MorphException('request.invalid', 'Das Feld "op" fehlt oder ist keine Zeichenkette.');
      }
      final Map<String, dynamic> data = await _dispatch(op, request);
      return <String, dynamic>{
        'request_id': requestId,
        'ok': true,
        'data': data,
      };
    } on MorphException catch (e) {
      return <String, dynamic>{
        'request_id': requestId,
        'ok': false,
        'error': <String, dynamic>{'code': e.code, 'message': e.message},
      };
    } catch (e) {
      return <String, dynamic>{
        'request_id': requestId,
        'ok': false,
        'error': <String, dynamic>{'code': 'internal', 'message': 'Interner Fehler: $e'},
      };
    }
  }

  Future<Map<String, dynamic>> _dispatch(String op, Map<String, dynamic> request) async {
    switch (op) {
      case 'describe':
        return describe();
      case 'portable.export':
        return _export(request);
      case 'portable.import':
        return await _import(request);
      case 'nutrition.day':
        return _nutritionDay(request);
      case 'cycle.forecast':
        return _cycleForecast(request);
      case 'food.search':
        return await _foodSearch(request);
      case 'food.lookup':
        return await _foodLookup(request);
      default:
        throw MorphException('request.unknown_op', 'Unbekannte Operation: $op');
    }
  }

  // ---------------------------------------------------------------- describe

  Map<String, dynamic> describe() {
    return <String, dynamic>{
      'app': <String, dynamic>{'name': appInfo.name, 'version': appInfo.version},
      'process': <String, dynamic>{
        'pid': pid,
        'data_dir': config.dataDir.path,
        'key_file': config.keyFile.path,
        'clock': <String, dynamic>{
          'source': config.clockSource,
          'now': clock.now().toUtc().toIso8601String(),
        },
      },
      'food_api': <String, dynamic>{
        'base_url': offConfig.normalizedBaseUrl,
        'user_agent': offConfig.userAgent,
        'endpoints': <String>[
          'GET {base}/api/v3.6/product/{barcode}.json',
          'GET {base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20',
        ],
      },
      'data_formats': <String, dynamic>{
        'key_file': <String, dynamic>{
          'description': 'Die Schlüsseldatiei enthält 32 rohe Bytes (AES-256-Schlüssel) '
              'und liegt außerhalb des Datenverzeichnisses. Ohne diese Datei sind die '
              'verschlüsselten Daten nicht lesbar. Sie wird nicht exportiert.',
          'length_bytes': 32,
        },
        'store': <String, dynamic>{
          'file': 'morphhealth.store (im data-dir)',
          'encoding': 'AES-256-GCM (12-Byte-Nonce, 16-Byte-MAC)',
          'layout': '"MHST" | version u16 LE | reserved u16 LE | nonce 12 | ciphertext | mac 16',
          'payload': 'UTF-8 JSON des Daten-Dokuments (siehe "portable")',
        },
        'portable': <String, dynamic>{
          'description': 'Vollständiger, maschinenlesbarer Export/Import des Datenbestands. '
              'Dies ist zugleich die Nutzlast der verschlüsselten Sicherung.',
          'format': portableFormat,
          'format_version': portableFormatVersion,
          'top_level_fields': <String>['format', 'format_version', 'generator', 'data'],
          'data_fields': <String, dynamic>{
            'settings': 'language (de|en|null), weight_unit (kg|lb), visible_areas, goals',
            'foods': 'id, name, brand, barcode, source (custom|off), per100 (31 Nährstoffe, '
                'kanonisch pro 100 g), serving, is_favorite, image_url, off_origin, created_at, updated_at',
            'nutrition_entries': 'id, food_id, food_name, food_per100 (Schnappschuss), '
                'food_serving_grams, date (YYYY-MM-DD), time (HH:MM|null), meal '
                '(breakfast|lunch|dinner|snack), quantity, unit (g|ml|portion), note, created_at',
            'water_entries': 'id, date, time, amount_ml, note',
            'caffeine_entries': 'id, date, time, amount_mg, note',
            'periods': 'id, start (YYYY-MM-DD), end (YYYY-MM-DD|null = läuft), flow '
                '(spotting|light|medium|heavy), flow_by_day (Datum → 0..3), note',
            'weight_entries': 'id, date, time, weight_kg (kanonisch kg), note',
            'symptom_entries': 'id, name, intensity (0..10), date, time, note',
          },
          'nutrient_keys': <String>[for (final NutrientDef d in nutrientDefs) d.key],
          'nutrient_units': 'energy_kcal: kcal; *_g: g; *_mg: mg; *_ug: µg (Mikrogramm)',
          'quantity_units': <String, dynamic>{
            'g': 'Gramm',
            'ml': 'Milliliter (Dichte 1 g/ml)',
            'portion': 'Portionen (1 Portion = serving.grams, sonst 100 g)',
          },
        },
        'backup': <String, dynamic>{
          'encoding': 'AES-256-GCM, Schlüssel aus PBKDF2-HMAC-SHA256 (600000 Iterationen, 16-Byte-Salt)',
          'layout': '"MHBK" | version u16 LE | kdfId u8 | iterations u32 LE | salt 16 | nonce 12 | ciphertext | mac 16',
          'payload': 'UTF-8 JSON des portablen Dokuments',
        },
      },
      'requests': <dynamic>[
        _opDoc('describe', <String>[], 'Beschreibung der Datenformate und Operationen, inkl. Beispieldokument.'),
        _opDoc('portable.export', <String>['ack_plaintext: true (bool, erforderlich)'],
            'Vollständiger Datenexport im portablen Format (data = Dokument).'),
        _opDoc('portable.import', <String>['document (object, erforderlich)', 'confirm_replace: true (bool, erforderlich)'],
            'Übernimmt das Dokument als Ersatz des Arbeitsdatenbestands; data = Ergebnisbericht.'),
        _opDoc('nutrition.day', <String>['date (YYYY-MM-DD, erforderlich)'],
            'Ernährungsangaben, die die Anwendung für diesen Tag ausgibt.'),
        _opDoc('cycle.forecast', <String>['on (YYYY-MM-DD, erforderlich)'],
            'Persönliche Zykluseinschätzung der Anwendung für diesen Betrachtungstag.'),
        _opDoc('food.search', <String>['q (string, erforderlich)', 'page (int, optional, Standard 1)'],
            'Ergebnisse der implementierten Lebensmittelsuche (Open Food Facts).'),
        _opDoc('food.lookup', <String>['barcode (string, erforderlich)'],
            'Ergebnis des implementierten Produktabrufs; data = null, wenn unbekannt.'),
      ],
      'responses': 'Jede Antwort ist eine JSON-Zeile: {"request_id": <echo>, "ok": true, "data": ...} '
          'bzw. {"request_id": <echo>, "ok": false, "error": {"code": ..., "message": ...}}. '
          'Nach jeder Antwort wird geflusht. EOF beendet den Prozess. Auf stdout '
          'erscheint kein Banner.',
      'example_document': examplePortableDocument(),
    };
  }

  static Map<String, dynamic> _opDoc(String op, List<String> params, String description) =>
      <String, dynamic>{'op': op, 'params': params, 'description': description};

  // ---------------------------------------------------------------- export

  Map<String, dynamic> _export(Map<String, dynamic> request) {
    final dynamic ack = request['ack_plaintext'];
    if (ack is! bool || ack != true) {
      throw MorphException('export.requires_ack',
          'Ein Klartext-Export muss mit "ack_plaintext": true bestätigt werden.');
    }
    return repo.exportPortable();
  }

  // ---------------------------------------------------------------- import

  Future<Map<String, dynamic>> _import(Map<String, dynamic> request) async {
    final dynamic confirm = request['confirm_replace'];
    if (confirm is! bool || confirm != true) {
      throw MorphException('import.requires_confirm',
          'Ein Import ersetzt den Arbeitsdatenbestand und muss mit "confirm_replace": true bestätigt werden.');
    }
    final dynamic doc = request['document'];
    if (doc is! Map<String, dynamic>) {
      throw MorphException('import.invalid_document', 'Das Feld "document" fehlt oder ist kein Objekt.');
    }
    final MorphDocument parsed = MorphDocument.fromPortableJson(doc);
    final Map<String, int> report = await repo.replaceDocument(parsed);
    return <String, dynamic>{
      'replaced': true,
      'report': <String, dynamic>{for (final MapEntry<String, int> e in report.entries) e.key: e.value},
    };
  }

  // ---------------------------------------------------------------- nutrition.day

  Map<String, dynamic> _nutritionDay(Map<String, dynamic> request) {
    final String? date = getString(request, 'date');
    if (date == null || parseDate(date) == null) {
      throw MorphException('nutrition.invalid_date',
          'Das Feld "date" fehlt oder ist kein gültiges Datum (YYYY-MM-DD).');
    }
    final DayNutrition day = computeDayNutrition(repo.document, date);
    return day.toJson(goals: repo.settings.goals);
  }

  // ---------------------------------------------------------------- cycle.forecast

  Map<String, dynamic> _cycleForecast(Map<String, dynamic> request) {
    final String? on = getString(request, 'on');
    if (on == null || parseDate(on) == null) {
      throw MorphException('cycle.invalid_date',
          'Das Feld "on" fehlt oder ist kein gültiges Datum (YYYY-MM-DD).');
    }
    final CycleForecast f = computeCycleForecast(repo.document, on);
    final Map<String, dynamic> json = f.toJson();
    json['explanation'] = <String, dynamic>{
      'de': f.explanationDe(),
      'en': f.explanationEn(),
    };
    return json;
  }

  // ---------------------------------------------------------------- food.*

  Future<Map<String, dynamic>> _foodSearch(Map<String, dynamic> request) async {
    final String? q = getString(request, 'q');
    if (q == null || q.trim().isEmpty) {
      throw MorphException('food.invalid_query', 'Das Feld "q" fehlt oder ist leer.');
    }
    final int page = getInt(request, 'page') ?? 1;
    if (page < 1) {
      throw MorphException('food.invalid_page', '"page" muss >= 1 sein.');
    }
    final OffSearchResult result = await _off.search(q, page: page);
    return result.toJson();
  }

  Future<Map<String, dynamic>> _foodLookup(Map<String, dynamic> request) async {
    final String? barcode = getString(request, 'barcode');
    if (barcode == null || barcode.trim().isEmpty) {
      throw MorphException('food.invalid_barcode', 'Das Feld "barcode" fehlt oder ist leer.');
    }
    // Formale Prüfung vor dem HTTP-Aufruf (konsistenter CLI-Fehlercode).
    if (OffClient.normalizeBarcode(barcode) == null) {
      throw MorphException('food.invalid_barcode', 'Ungültige Barcode-Nummer: $barcode');
    }
    final OffProduct? product = await _off.lookup(barcode);
    return <String, dynamic>{
      'found': product != null,
      'product': product?.toJson(),
    };
  }
}
