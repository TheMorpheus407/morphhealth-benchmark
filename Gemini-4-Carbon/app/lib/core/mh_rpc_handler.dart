/// JSON-Lines RPC request dispatcher for P10 (`./mh`).
///
/// Directly invokes the productive `MorphHealthStore`, `PortableCodec`,
/// `NutritionService`, `CycleForecastEngine`, and `OpenFoodFactsClient`.
library;

import 'dart:convert';

import 'clock.dart';
import 'crypto_vault.dart';
import 'open_food_facts_client.dart';
import 'portable_codec.dart';
import 'store.dart';

class MhRpcHandler {
  final MorphHealthStore store;
  final OpenFoodFactsClient foodClient;
  final AppClock clock;

  const MhRpcHandler({
    required this.store,
    required this.foodClient,
    required this.clock,
  });

  Future<Map<String, dynamic>> handleRawJsonLine(String rawLine) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(rawLine);
    } catch (e) {
      return _errorResponse(
        null,
        'INVALID_JSON',
        'Input line is not valid JSON: $e',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return _errorResponse(
        null,
        'INVALID_REQUEST',
        'Each JSON-Lines request must be a JSON object.',
      );
    }

    if (!decoded.containsKey('request_id')) {
      return _errorResponse(
        null,
        'MISSING_REQUEST_ID',
        'Request object must contain "request_id".',
      );
    }
    final requestId = decoded['request_id'];
    final op = decoded['op'];
    if (op is! String || op.trim().isEmpty) {
      return _errorResponse(
        requestId,
        'MISSING_OP',
        'Request object must contain a non-empty string "op".',
      );
    }

    try {
      final data = await _dispatch(op, decoded);
      return {
        'request_id': requestId,
        'ok': true,
        'data': data,
      };
    } on FoodNotFoundException catch (e) {
      return _errorResponse(requestId, e.code, e.message);
    } on FoodApiException catch (e) {
      return _errorResponse(requestId, e.code, e.message);
    } on FormatValidationException catch (e) {
      return _errorResponse(requestId, 'INVALID_ARGUMENT', e.message);
    } on VaultSecurityException catch (e) {
      return _errorResponse(requestId, e.code, e.message);
    } on _RpcError catch (e) {
      return _errorResponse(requestId, e.code, e.message);
    } catch (e) {
      return _errorResponse(
        requestId,
        'INTERNAL_ERROR',
        'Unexpected error handling "$op": $e',
      );
    }
  }

  Future<Map<String, dynamic>> _dispatch(
    String op,
    Map<String, dynamic> req,
  ) async {
    switch (op) {
      case 'describe':
        return PortableCodec.buildProtocolDescription(
          nowRfc3339: clock.nowRfc3339(),
          foodBaseUrl: foodClient.baseUrl,
          foodUserAgent: foodClient.userAgent,
        );

      case 'portable.export':
        if (req['ack_plaintext'] != true) {
          throw const _RpcError(
            'ACK_REQUIRED',
            'portable.export requires "ack_plaintext": true because exported JSON is unencrypted.',
          );
        }
        return store.exportPortableDocument();

      case 'portable.import':
        if (req['confirm_replace'] != true) {
          throw const _RpcError(
            'CONFIRMATION_REQUIRED',
            'portable.import requires "confirm_replace": true to replace the working dataset.',
          );
        }
        final doc = req['document'];
        if (doc is! Map<String, dynamic>) {
          throw const _RpcError(
            'INVALID_DOCUMENT',
            'portable.import requires a JSON object in "document".',
          );
        }
        try {
          return await store.importPortableDocument(doc);
        } on FormatValidationException catch (e) {
          throw _RpcError('INVALID_DOCUMENT', e.message);
        }

      case 'nutrition.day':
        final date = req['date'];
        if (date is! String || !IsoDate.isValid(date.trim())) {
          throw const _RpcError(
            'INVALID_ARGUMENT',
            'nutrition.day requires "date" in YYYY-MM-DD format.',
          );
        }
        final summary = store.nutritionForDay(date.trim());
        return summary.toJson(locale: store.preferences.localeCode);

      case 'cycle.forecast':
        final onDate = req['on'];
        if (onDate is! String || !IsoDate.isValid(onDate.trim())) {
          throw const _RpcError(
            'INVALID_ARGUMENT',
            'cycle.forecast requires "on" in YYYY-MM-DD format.',
          );
        }
        final forecast = store.cycleForecastOn(onDate.trim());
        return forecast.toJson();

      case 'food.search':
        final q = req['q'];
        if (q is! String || q.trim().isEmpty) {
          throw const _RpcError(
            'INVALID_ARGUMENT',
            'food.search requires a non-empty string "q".',
          );
        }
        final pageRaw = req.containsKey('page') ? req['page'] : 1;
        if (pageRaw is! int || pageRaw < 1) {
          throw const _RpcError(
            'INVALID_ARGUMENT',
            'food.search requires "page" as an integer >= 1.',
          );
        }
        final result = await foodClient.searchProducts(
          query: q.trim(),
          page: pageRaw,
          pageSize: 20,
        );
        return result.toJson();

      case 'food.lookup':
        final barcode = req['barcode'];
        if (barcode is! String || barcode.trim().isEmpty) {
          throw const _RpcError(
            'INVALID_ARGUMENT',
            'food.lookup requires a non-empty string "barcode".',
          );
        }
        final item = await foodClient.lookupBarcode(barcode.trim());
        return {
          'barcode': item.barcode ?? barcode.trim(),
          'item': item.toJson(),
        };

      default:
        throw _RpcError(
          'UNKNOWN_OP',
          'Unsupported operation "$op". Use "describe" to inspect supported operations.',
        );
    }
  }

  static Map<String, dynamic> _errorResponse(
    dynamic requestId,
    String code,
    String message,
  ) {
    return {
      'request_id': requestId,
      'ok': false,
      'error': {
        'code': code,
        'message': message,
      },
    };
  }
}

class _RpcError implements Exception {
  final String code;
  final String message;
  const _RpcError(this.code, this.message);
}
