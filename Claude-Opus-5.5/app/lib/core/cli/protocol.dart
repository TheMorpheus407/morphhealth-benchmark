import 'dart:convert';

import '../cycle/forecast_json.dart';
import '../food/off_client.dart';
import '../portable/portable_codec.dart';
import '../service/morphhealth_service.dart';
import '../storage/encrypted_store.dart';
import '../util/clock.dart';
import '../util/json_reader.dart';
import '../util/local_date.dart';
import 'describe.dart';

/// Error with a stable code, reported as `{"ok": false, "error": …}`.
class ProtocolError implements Exception {
  ProtocolError(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Object? details;

  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    if (details != null) 'details': details,
  };
}

/// Context information used by `describe`.
class ProtocolContext {
  ProtocolContext({
    required this.dataDir,
    required this.clock,
    required this.clockSource,
    required this.foodApi,
  });

  final String dataDir;
  final Clock clock;
  final String clockSource;
  final FoodApiConfig foodApi;
}

/// The JSON-Lines maintenance protocol of the `mh` process.
///
/// Each request is one JSON object per line with `request_id` and `op`.
/// Each response echoes `request_id` and contains `ok` and either `data`
/// or `error`. All operations call the same [MorphHealthService] methods
/// as the Android app.
class MaintenanceProtocol {
  MaintenanceProtocol({
    required this.context,
    this.service,
    this.storeError,
  }) : assert(service != null || storeError != null);

  final ProtocolContext context;

  /// Null if the data store could not be opened.
  final MorphHealthService? service;
  final StoreException? storeError;

  static const List<String> operations = [
    'describe',
    'portable.export',
    'portable.import',
    'nutrition.day',
    'cycle.forecast',
    'food.search',
    'food.lookup',
  ];

  /// Handles one request line and returns the response object.
  Future<Map<String, Object?>> handleLine(String line) async {
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      return _failure(null, ProtocolError('invalid_json', 'The line is not valid JSON'));
    }
    if (decoded is! Map<String, Object?>) {
      return _failure(
        null,
        ProtocolError('invalid_request', 'A request must be a JSON object'),
      );
    }
    // Any JSON value is accepted as request_id and echoed unchanged.
    final requestId = decoded['request_id'];
    if (requestId == null) {
      return _failure(
        null,
        ProtocolError('invalid_request', 'request_id is required'),
      );
    }
    final op = decoded['op'];
    if (op is! String) {
      return _failure(requestId, ProtocolError('invalid_request', 'op is required'));
    }
    try {
      final data = await _dispatch(op, decoded);
      return {'request_id': requestId, 'ok': true, 'data': data};
    } on ProtocolError catch (e) {
      return _failure(requestId, e);
    } on ValidationException catch (e) {
      return _failure(
        requestId,
        ProtocolError(
          'validation_failed',
          'The document does not match the morphhealth.portable format',
          {
            'errors': [for (final i in e.errors.take(100)) i.toJson()],
            'error_count': e.errors.length,
          },
        ),
      );
    } on DomainException catch (e) {
      return _failure(
        requestId,
        ProtocolError(e.code, e.message.isEmpty ? e.code : e.message),
      );
    } on FoodApiException catch (e) {
      return _failure(
        requestId,
        ProtocolError(e.code, e.message, {
          if (e.statusCode != null) 'http_status': e.statusCode,
          'base_url': service?.foodApiConfig.baseUrl,
        }),
      );
    } on StoreException catch (e) {
      return _failure(requestId, ProtocolError(e.code, e.message));
    } catch (e) {
      return _failure(requestId, ProtocolError('internal_error', e.toString()));
    }
  }

  Map<String, Object?> _failure(Object? requestId, ProtocolError error) => {
    'request_id': requestId,
    'ok': false,
    'error': error.toJson(),
  };

  MorphHealthService _requireService() {
    final s = service;
    if (s == null) {
      final e = storeError!;
      throw ProtocolError(e.code, e.message);
    }
    return s;
  }

  Future<Object?> _dispatch(String op, Map<String, Object?> req) async {
    switch (op) {
      case 'describe':
        return describeInterface(context, service, storeError);
      case 'portable.export':
        if (req['ack_plaintext'] != true) {
          throw ProtocolError(
            'confirmation_required',
            'Set "ack_plaintext": true to receive the unencrypted export',
          );
        }
        return _requireService().exportDocument();
      case 'portable.import':
        if (req['confirm_replace'] != true) {
          throw ProtocolError(
            'confirmation_required',
            'Set "confirm_replace": true; the import replaces all data',
          );
        }
        if (!req.containsKey('document')) {
          throw ProtocolError(
            'invalid_parameter',
            'document is required',
            {'parameter': 'document'},
          );
        }
        final report = await _requireService().importDocument(req['document']);
        return report.toJson();
      case 'nutrition.day':
        final date = _date(req, 'date');
        return _requireService().nutritionDay(date).toJson();
      case 'cycle.forecast':
        final on = _date(req, 'on');
        final s = _requireService();
        return forecastToJson(s.cycleForecast(on), s.strings, s.fmt);
      case 'food.search':
        return _foodSearch(req);
      case 'food.lookup':
        return _foodLookup(req);
      default:
        throw ProtocolError('unknown_op', 'Unknown op "$op"', {
          'supported_ops': operations,
        });
    }
  }

  LocalDate _date(Map<String, Object?> req, String name) {
    final v = req[name];
    if (v is! String) {
      throw ProtocolError(
        'invalid_parameter',
        '$name is required as YYYY-MM-DD',
        {'parameter': name},
      );
    }
    final d = LocalDate.tryParse(v);
    if (d == null || !d.isInSupportedRange) {
      throw ProtocolError(
        'invalid_parameter',
        '$name must be a valid date YYYY-MM-DD between 1900 and 2100',
        {'parameter': name},
      );
    }
    return d;
  }

  Future<Object?> _foodSearch(Map<String, Object?> req) async {
    final q = req['q'];
    if (q is! String || q.trim().isEmpty) {
      throw ProtocolError(
        'invalid_parameter',
        'q is required and must be a non-empty string',
        {'parameter': 'q'},
      );
    }
    final pageValue = req['page'] ?? 1;
    if (pageValue is! num || pageValue != pageValue.roundToDouble() || pageValue < 1) {
      throw ProtocolError(
        'invalid_parameter',
        'page must be an integer ≥ 1',
        {'parameter': 'page'},
      );
    }
    final s = _requireService();
    final result = await s.searchFood(q, pageValue.toInt());
    if (result.onlineError != null) throw result.onlineError!;
    return {
      'query': result.query,
      'page': result.page,
      'online_enabled': result.onlineEnabled,
      'source': result.onlineEnabled
          ? {
              'name': 'Open Food Facts',
              'base_url': s.foodApiConfig.baseUrl,
              'endpoint': '/cgi/search.pl',
              'license': 'ODbL',
            }
          : null,
      'local_results': [for (final h in result.local) h.toJson()],
      'online': result.online?.toJson(),
    };
  }

  Future<Object?> _foodLookup(Map<String, Object?> req) async {
    var barcode = req['barcode'];
    if (barcode is num && barcode == barcode.roundToDouble() && barcode >= 0) {
      barcode = barcode.toInt().toString();
    }
    if (barcode is! String) {
      throw ProtocolError(
        'invalid_parameter',
        'barcode is required as a string of digits',
        {'parameter': 'barcode'},
      );
    }
    final s = _requireService();
    final result = await s.lookupBarcode(barcode);
    if (result.onlineError != null) throw result.onlineError!;
    return {
      'barcode': result.barcode,
      'found': result.found,
      'online_found': result.online != null,
      'check_digit_valid': result.checkDigitValid,
      'online_enabled': result.onlineEnabled,
      'source': result.onlineEnabled
          ? {
              'name': 'Open Food Facts',
              'base_url': s.foodApiConfig.baseUrl,
              'endpoint': '/api/v3.6/product/{barcode}.json',
              'license': 'ODbL',
            }
          : null,
      'product': result.online?.toJson(),
      'local_matches': [for (final h in result.local) h.toJson()],
    };
  }
}

/// Describes the clock for `describe`.
Map<String, Object?> clockInfo(ProtocolContext c) => {
  'source': c.clockSource,
  'now': formatInstant(c.clock.nowUtc()),
  'today': c.clock.today().toIso(),
};

/// Re-exported for the describe document.
const String portableFormatId = PortableFormat.formatId;
