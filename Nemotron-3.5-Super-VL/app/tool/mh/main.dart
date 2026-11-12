library morphhealth.cli.mh;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:morphhealth/core/model/entries.dart';
import 'package:morphhealth/core/model/food.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/core/service/off_client.dart';
import 'package:morphhealth/core/storage/encrypted_store.dart';

/// Lokaler JSON-Lines-Wartungszugang zu den tatsächlichen Daten und
/// Funktionen der MorphHealth-App (P10). Gleiche Core-Implementierung.
void main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed == null) return;

  final dataDir = Directory(parsed['data-dir']!);
  await dataDir.create(recursive: true);
  final dataPath = '${dataDir.path}/data.json.enc';

  final keyFile = File(parsed['key-file']!);
  final key = await keyFile.readAsBytes();
  if (key.length != 32) {
    _fail('Schlüsseldatei muss genau 32 Rohbyte enthalten (${key.length} vorgefunden)');
  }

  final store = EncryptedStore(Uint8List.fromList(key));
  final repository = HealthRepository(
    store: store,
    dataPath: dataPath,
    now: () {
      final nowOverride = parsed['now'] ?? '';
      if (nowOverride.isNotEmpty) {
        return DateTime.parse(nowOverride).toLocal();
      }
      return DateTime.now();
    },
    foodClient: OpenFoodFactsClient(
      baseUrl: parsed['food-base-url'] ?? 'https://localhost:8788',
      userAgent: parsed['food-user-agent'] ?? 'MorphHealth/1.0-rc3 (benchmark build)',
    ),
  );
  await repository.load();

  final lines = utf8.decoder.bind(stdin).transform(const LineSplitter());
  await for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final response = await _handle(trimmed, repository);
    stdout.write(jsonEncode(response));
    stdout.write('\n');
    stdout.flush();
  }
  repository.foodClient?.dispose();
  exit(0);
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      _usage();
      exit(0);
    }
    if (!arg.startsWith('--')) continue;
    final name = arg.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      result[name] = args[++i];
    } else {
      result[name] = '';
    }
  }
  if (!result.containsKey('data-dir') || !result.containsKey('key-file')) {
    _usage();
    exit(0);
  }
  return result;
}

void _usage() {
  stderr.writeln('Verwendung: ./mh --data-dir ABS --key-file ABS [--now RFC3339]');
  stderr.writeln('    [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]');
}

Future<Map<String, dynamic>> _handle(String line, HealthRepository repository) async {
  Map<String, dynamic> request;
  try {
    request = jsonDecode(line) as Map<String, dynamic>;
  } on Exception {
    return _error(null, 'invalid_json', 'Anfrage ist kein gültiges JSON-Objekt');
  }
  final requestId = request['request_id'];
  final op = request['op'] as String?;

  try {
    switch (op) {
      case 'describe':
        return _ok(requestId, describe());
      case 'portable.export':
        if (request['ack_plaintext'] != true) {
          return _error(requestId, 'ack_required', 'ack_plaintext: true ist erforderlich');
        }
        return _ok(requestId, await repository.exportDocument());
      case 'portable.import':
        if (request['confirm_replace'] != true) {
          return _error(requestId, 'confirm_required', 'confirm_replace: true ist erforderlich');
        }
        final document = request['document'];
        if (document == null) {
          return _error(requestId, 'missing_argument', 'document fehlt');
        }
        final report = await repository.importDocument(
          Map<String, dynamic>.from(document as Map<dynamic, dynamic>),
        );
        return _ok(requestId, report);
      case 'nutrition.day':
        final date = request['date'] as String?;
        if (date == null || date.isEmpty) {
          return _error(requestId, 'missing_argument', 'date (YYYY-MM-DD) fehlt');
        }
        return _ok(requestId, _nutritionDayMap(repository, DateTime.parse(date)));
      case 'cycle.forecast':
        final on = request['on'] as String?;
        if (on == null || on.isEmpty) {
          return _error(requestId, 'missing_argument', 'on (YYYY-MM-DD) fehlt');
        }
        return _ok(requestId, _cycleForecastMap(repository, DateTime.parse(on)));
      case 'food.search':
        final q = request['q'] as String? ?? '';
        final page = int.tryParse((request['page'] ?? '1').toString()) ?? 1;
        return _ok(requestId, await _foodSearch(repository, q, page: page));
      case 'food.lookup':
        final barcode = request['barcode'] as String?;
        if (barcode == null || barcode.isEmpty) {
          return _error(requestId, 'missing_argument', 'barcode fehlt');
        }
        return _ok(requestId, await _foodLookup(repository, barcode));
      default:
        return _error(requestId, 'unknown_op', 'Unbekannte Operation: $op');
    }
  } on FormatException catch (e) {
    return _error(requestId, 'invalid_argument', e.message);
  } on Exception catch (e) {
    return _error(requestId, 'internal', e.toString());
  }
}

Map<String, dynamic> _ok(Object? requestId, dynamic data) =>
    <String, dynamic>{
      'request_id': requestId,
      'ok': true,
      'data': data,
    };

Map<String, dynamic> _error(Object? requestId, String code, String message) =>
    <String, dynamic>{
      'request_id': requestId,
      'ok': false,
      'error': <String, dynamic>{
        'code': code,
        'message': message,
      },
    };

void _fail(String message) {
  stderr.writeln(message);
  exit(64);
}

Map<String, dynamic> describe() => <String, dynamic>{
      'format': 'morphhealth.v1',
      'description':
          'MorphHealth-Dokumentenformat. Ein Dokument ist ein JSON-Objekt mit '
          'Feldern format, createdAt und document. document enthält den vollen '
          'Gesundheitsdatenbestand (HealthData): localFoods, cachedProducts, '
          'nutritionEntries, waterEntries, caffeineEntries, cycleEntries, '
          'symptomEntries, weightEntries, goals, settings. Datumsangaben sind '
          'ISO-8601-Strings; Zeitstempel mit Ortszeit, Kalendertage als YYYY-MM-DD.',
      'operations': <String, dynamic>{
        'describe': 'Diese Beschreibung und ein importgeeignetes Beispieldokument.',
        'portable.export': 'Eingabe: ack_plaintext: true. Ausgabe: vollständiger Datenexport.',
        'portable.import': 'Eingabe: document, confirm_replace: true. Ersetzt den Datenbestand.',
        'nutrition.day': 'Eingabe: date (YYYY-MM-DD). Ausgabe: Ernährung des Tages.',
        'cycle.forecast': 'Eingabe: on (YYYY-MM-DD). Ausgabe: persönliche Zykluseinschätzung.',
        'food.search': 'Eingabe: q, page. Ausgabe: Lebensmittelsuche.',
        'food.lookup': 'Eingabe: barcode. Ausgabe: Produktabruf.',
      },
      'example': <String, dynamic>{
        'format': 'morphhealth.v1',
        'createdAt': '2026-09-23T10:00:00+02:00',
        'document': <String, dynamic>{
          'format': 'morphhealth.v1',
          'localFoods': <dynamic>[],
          'nutritionEntries': <dynamic>[],
          'waterEntries': <dynamic>[],
          'caffeineEntries': <dynamic>[],
          'cycleEntries': <dynamic>[],
          'symptomEntries': <dynamic>[],
          'weightEntries': <dynamic>[],
          'goals': <String, dynamic>{},
          'settings': <String, dynamic>{
            'locale': 'de',
            'visibleAreas': <String>['nutrition', 'cycle', 'weight', 'overview'],
          },
        },
      },
    };

Map<String, dynamic> _nutritionDayMap(HealthRepository repository, DateTime day) {
  final summary = repository.nutritionDaySummary(day);
  final wc = repository.waterCaffeineDaySummary(day);
  return <String, dynamic>{
    'date': _dateOnly(day),
    'entries': summary.entries.map((e) => _entryMap(e)).toList(),
    'totals': <String, dynamic>{
      'energyKcal': summary.energyKcal,
      'proteinG': summary.proteinG,
      'carbsG': summary.carbsG,
      'fatG': summary.fatG,
    },
    'waterMilliliters': wc.waterMilliliters,
    'caffeineMg': wc.caffeineMg,
  };
}

Map<String, dynamic> _entryMap(NutritionEntry e) => <String, dynamic>{
      'id': e.id,
      'foodSource': e.foodSource == FoodSource.local ? 'local' : 'off',
      'foodId': e.foodId,
      'foodName': e.foodName,
      'amountGrams': e.amountGrams,
      'amountMilliliters': e.amountMilliliters,
      'servingCount': e.servingCount,
      'occurredAt': e.occurredAt.toIso8601String(),
      'meal': e.meal.key,
      'energyKcal': e.energyKcal,
      'proteinG': e.proteinG,
      'carbsG': e.carbsG,
      'fatG': e.fatG,
    };

Map<String, dynamic> _cycleForecastMap(HealthRepository repository, DateTime on) {
  final forecast = repository.forecastFor(on, locale: repository.settings.locale);
  return <String, dynamic>{
    'on': _dateOnly(on),
    'lastPeriodStart': forecast.lastPeriodStart?.toIso8601String(),
    'averageCycleLengthDays': forecast.averageCycleLengthDays,
    'averagePeriodLengthDays': forecast.averagePeriodLengthDays,
    'cyclesRecorded': forecast.cyclesRecorded,
    'predictedNextStart': forecast.predictedNextStart?.toIso8601String(),
    'predictedNextEnd': forecast.predictedNextEnd?.toIso8601String(),
    'explanation': forecast.explanation,
    'hasPrediction': forecast.hasPrediction,
  };
}

Future<Map<String, dynamic>> _foodSearch(HealthRepository repository, String q, {int page = 1}) async {
  final client = repository.foodClient;
  if (client == null) {
    return <String, dynamic>{
      'query': q,
      'page': page,
      'products': <Map<String, dynamic>>[],
      'count': 0,
    };
  }
  final result = await client.search(q, page: page);
  return <String, dynamic>{
    'query': q,
    'page': result.page,
    'pageSize': result.pageSize,
    'count': result.count,
    'pageCount': result.pageCount,
    'products': result.products.map(_productMap).toList(),
  };
}

Future<Map<String, dynamic>> _foodLookup(HealthRepository repository, String barcode) async {
  final client = repository.foodClient;
  if (client == null) {
    return <String, dynamic>{
      'barcode': barcode,
      'product': null,
    };
  }
  final product = await client.lookup(barcode);
  return <String, dynamic>{
    'barcode': barcode,
    'product': product == null ? null : _productMap(product),
  };
}

Map<String, dynamic> _productMap(OffProduct p) => <String, dynamic>{
      'id': p.id,
      'name': p.name,
      'brand': p.brand,
      'profile': p.profile.toJson(),
      'servingSizeGrams': p.servingSizeGrams,
      'imageUrl': p.imageUrl,
      'categories': p.categories,
      'fetchedAt': p.fetchedAt?.toIso8601String(),
    };

String _dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';