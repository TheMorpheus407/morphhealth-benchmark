import 'dart:convert';

import 'civil.dart';
import 'core.dart';
import 'db.dart';
import 'describe.dart';
import 'food_api.dart';
import 'issues.dart';
import 'store.dart';

/// Der JSON-Lines-Wartungszugang: nimmt eine geparste Anfrage entgegen und
/// liefert die Antwort. Alle Fachfunktionen kommen aus [MorphCore]; hier steht
/// nur die Zuordnung von Operationen auf Aufrufe und die Fehlerabbildung.
final class Protocol {
  /// Der geöffnete Kern oder null, wenn das Öffnen des Datenbestands
  /// gescheitert ist (dann liefert [startupError] den Grund).
  final MorphCore? core;
  final StoreException? startupError;

  Protocol({this.core, this.startupError});

  static Map<String, Object?> _ok(Object? id, Object? data) => {'request_id': id, 'ok': true, 'data': data};

  static Map<String, Object?> _err(Object? id, String code, String message, [Object? details]) => {
    'request_id': id,
    'ok': false,
    'error': {'code': code, 'message': message, 'details': ?details},
  };

  /// Fehler für Zeilen, die kein gültiges JSON sind.
  static Map<String, Object?> invalidJson(String message) => _err(null, 'invalid_json', message);

  /// Bearbeitet eine Anfrage. Wirft nie; Fehler stehen in der Antwort.
  Future<Map<String, Object?>> handle(Object? request) async {
    if (request is! Map) {
      return _err(null, 'invalid_request', 'Die Anfrage muss ein JSON-Objekt mit request_id und op sein');
    }
    final id = request['request_id'];
    final op = request['op'];
    if (op is! String || op.isEmpty) {
      return _err(id, 'invalid_request', 'Das Feld op fehlt oder ist kein Text');
    }
    try {
      if (op == 'describe') return _ok(id, await buildDescribe());
      const known = {
        'portable.export',
        'portable.import',
        'nutrition.day',
        'cycle.forecast',
        'food.search',
        'food.lookup',
      };
      if (!known.contains(op)) {
        return _err(id, 'unknown_op', 'Unbekannte Operation "$op"');
      }
      final c = core;
      if (c == null) {
        final e = startupError!;
        return _err(id, _storeCode(e), e.message);
      }
      switch (op) {
        case 'portable.export':
          if (request['ack_plaintext'] != true) {
            return _err(
              id,
              'ack_required',
              'Der Export ist unverschlüsselter Klartext. Zum Bestätigen ack_plaintext: true senden.',
            );
          }
          return _ok(id, c.exportDocument());
        case 'portable.import':
          if (request['confirm_replace'] != true) {
            return _err(
              id,
              'confirm_required',
              'Der Import ersetzt den gesamten Arbeitsdatenbestand. Zum Bestätigen confirm_replace: true senden.',
            );
          }
          if (!request.containsKey('document')) {
            return _err(id, 'invalid_argument', 'Das Feld document fehlt');
          }
          var document = request['document'];
          if (document is String) {
            // Ein als Text mitgegebenes Dokument (JSON-Zeichenkette) gilt wie das Objekt selbst.
            try {
              document = jsonDecode(document);
            } on FormatException {
              throw const FormatException('Das Feld document ist weder ein Objekt noch gültiges JSON');
            }
          }
          return _ok(id, (await c.importDocument(document)).toJson());
        case 'nutrition.day':
          return _ok(id, c.nutritionDay(_day(request, 'date')).toJson());
        case 'cycle.forecast':
          return _ok(id, c.cycleForecast(_day(request, 'on')).toJson());
        case 'food.search':
          final q = request['q'];
          if (q is! String) throw const FormatException('Das Feld q fehlt oder ist kein Text');
          final page = request['page'] == null ? 1 : _int(request['page'], 'page');
          if (page < 1) throw const FormatException('page beginnt bei 1');
          return _ok(id, (await c.foodSearch(q, page: page)).toJson());
        case 'food.lookup':
          final b = request['barcode'];
          if (b is! String && b is! num) throw const FormatException('Das Feld barcode fehlt oder ist kein Text');
          final r = await c.foodLookup(b.toString());
          return _ok(id, {
            'barcode': r.food.barcode,
            'nutrition_source': r.nutritionSource,
            'food': r.food.toJson(rounded: true),
          });
      }
      return _err(id, 'unknown_op', 'Unbekannte Operation "$op"');
    } on ValidationException catch (e) {
      return _err(id, 'invalid_document', e.message, [for (final i in e.issues.take(50)) i.toJson()]);
    } on FoodApiException catch (e) {
      return _err(id, e.code, e.message);
    } on StoreException catch (e) {
      return _err(id, _storeCode(e), e.message);
    } on DomainException catch (e) {
      return _err(id, e.code, e.message, e.details.isEmpty ? null : e.details);
    } on FormatException catch (e) {
      return _err(id, 'invalid_argument', e.message);
    } on Object catch (e) {
      return _err(id, 'internal_error', 'Unerwarteter Fehler: ${e.runtimeType}');
    }
  }

  static String _storeCode(StoreException e) => switch (e.code) {
    StoreErrorCode.wrongKey => 'wrong_key',
    StoreErrorCode.corrupt => 'corrupt',
    StoreErrorCode.locked => 'locked',
    _ => 'store_error',
  };

  static Day _day(Map<Object?, Object?> req, String field) {
    final v = req[field];
    if (v is! String) throw FormatException('Das Feld $field fehlt oder ist kein Text (erwartet YYYY-MM-DD)');
    // Ein angehängter Zeitanteil (YYYY-MM-DDTHH:MM..., auch mit Leerzeichen) wird ignoriert.
    final t = v.trim();
    final d = Day.tryParse(t.length > 10 && (t[10] == 'T' || t[10] == ' ') ? t.substring(0, 10) : t);
    if (d == null) throw FormatException('Das Feld $field ist kein gültiges Datum (erwartet YYYY-MM-DD): "$v"');
    return d;
  }

  static int _int(Object? v, String field) {
    if (v is int) return v;
    if (v is num && v == v.roundToDouble()) return v.toInt();
    if (v is String) {
      final n = int.tryParse(v.trim());
      if (n != null) return n;
    }
    throw FormatException('Das Feld $field muss eine ganze Zahl sein');
  }
}
