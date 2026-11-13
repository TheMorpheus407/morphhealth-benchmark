import 'dart:convert';

import '../model/settings.dart';
import '../nutrition/nutrition_day.dart';
import '../nutrition/off_client.dart';
import '../portable/portable.dart';
import '../store/data_store.dart';
import '../store/repository.dart';
import '../util/dates.dart';
import 'describe.dart';

/// A request could not be carried out; becomes the `error` of the answer.
class MhError implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  const MhError(this.code, this.message, [this.details]);

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (details != null) 'details': details,
  };
}

/// The JSON Lines maintenance access: turns one request into one answer.
///
/// The service holds no domain logic. Each operation calls the function the
/// Android app calls for the same purpose:
///
/// | op                | function of the app                              |
/// |-------------------|--------------------------------------------------|
/// | `portable.export` | [PortableService.exportDocument]                 |
/// | `portable.import` | [PortableService.importDocument]                 |
/// | `nutrition.day`   | [NutritionDay.compute]                           |
/// | `cycle.forecast`  | [cycleAssessment]                                |
/// | `food.search`     | [FoodApiClient.search]                           |
/// | `food.lookup`     | [FoodApiClient.lookup]                           |
class MhService {
  final Clock clock;
  final bool clockIsFixed;
  final String foodBaseUrl;
  final String foodUserAgent;

  /// Creates the food client for the given name languages.
  final FoodApiClient Function(List<String> languages) _foodClient;

  /// Opens the repository of the data directory. Called on first use and
  /// again after a failure.
  final Future<HealthRepository> Function() _openRepository;

  HealthRepository? _repository;

  MhService({
    required this.clock,
    required this.clockIsFixed,
    required this.foodBaseUrl,
    required this.foodUserAgent,
    required FoodApiClient Function(List<String> languages) foodClient,
    required Future<HealthRepository> Function() openRepository,
  }) : _foodClient = foodClient,
       _openRepository = openRepository;

  /// Handles one input line. Returns null for an empty line (no answer).
  Future<Map<String, dynamic>?> handleLine(String line) async {
    var text = line.trim();
    if (text.startsWith('﻿')) text = text.substring(1).trim();
    if (text.isEmpty) return null;
    final Object? request;
    try {
      request = jsonDecode(text);
    } on FormatException catch (e) {
      return _failure(
        null,
        MhError('invalid_json', 'The line is not valid JSON: ${e.message}'),
      );
    }
    return handle(request);
  }

  /// Handles one decoded request.
  Future<Map<String, dynamic>> handle(Object? request) async {
    if (request is! Map) {
      return _failure(
        null,
        const MhError('invalid_json', 'A request must be a JSON object.'),
      );
    }
    final map = request.cast<String, dynamic>();
    final id = map['request_id'];
    if (id == null || !(id is String || id is num)) {
      return _failure(
        null,
        const MhError(
          'invalid_request',
          'request_id is required and must be a string or a number.',
        ),
      );
    }
    final op = map['op'];
    if (op is! String || op.isEmpty) {
      return _failure(
        id,
        const MhError(
          'invalid_request',
          'op is required and must be a string.',
        ),
      );
    }
    try {
      final Object data = switch (op) {
        'describe' => _describe(),
        'portable.export' => await _export(map),
        'portable.import' => await _import(map),
        'nutrition.day' => await _nutritionDay(map),
        'cycle.forecast' => await _cycleForecast(map),
        'food.search' => await _foodSearch(map),
        'food.lookup' => await _foodLookup(map),
        _ => throw MhError(
          'unknown_op',
          'Unknown operation "$op". Known: describe, portable.export, '
              'portable.import, nutrition.day, cycle.forecast, food.search, '
              'food.lookup.',
        ),
      };
      return {'request_id': id, 'ok': true, 'data': data};
    } on MhError catch (e) {
      return _failure(id, e);
    } on StoreException catch (e) {
      _repository = null;
      return _failure(id, MhError('store_${e.code}', e.message));
    } on FoodApiException catch (e) {
      return _failure(
        id,
        MhError(
          e.code == 'invalid_argument' ? 'invalid_argument' : 'food_${e.code}',
          e.message,
          {
            if (e.statusCode != null) 'http_status': e.statusCode,
            if (e.retryAfterSeconds != null)
              'retry_after_seconds': e.retryAfterSeconds,
            'food_base_url': foodBaseUrl,
          },
        ),
      );
    } on ImportRejected catch (e) {
      return _failure(
        id,
        MhError(
          'import_rejected',
          'The document was not imported because it has '
              '${e.errorCount} error${e.errorCount == 1 ? '' : 's'}. '
              'Nothing was changed.',
          e.toJson(),
        ),
      );
    } on Object catch (e) {
      return _failure(id, MhError('internal_error', '$e'));
    }
  }

  static Map<String, dynamic> _failure(Object? id, MhError error) => {
    'request_id': id,
    'ok': false,
    'error': error.toJson(),
  };

  Future<T> _withRepository<T>(
    Future<T> Function(HealthRepository repository) action,
  ) async {
    final repo = _repository ??= await _openRepository();
    return repo.session(() => action(repo));
  }

  // ----------------------------------------------------------- operations

  Map<String, dynamic> _describe() => describeAccess(
    foodBaseUrl: foodBaseUrl,
    foodUserAgent: foodUserAgent,
    now: clock.now(),
    clockIsFixed: clockIsFixed,
  );

  Future<Map<String, dynamic>> _export(Map<String, dynamic> request) {
    if (request['ack_plaintext'] != true) {
      throw const MhError(
        'acknowledgement_required',
        'The export contains all health data unencrypted. Repeat the '
            'request with "ack_plaintext": true.',
        {'field': 'ack_plaintext'},
      );
    }
    return _withRepository(
      (repo) async => PortableService(repo).exportDocument(),
    );
  }

  Future<Map<String, dynamic>> _import(Map<String, dynamic> request) {
    if (!request.containsKey('document') || request['document'] == null) {
      throw const MhError(
        'invalid_argument',
        'document is required: an export document as a JSON object.',
        {'field': 'document'},
      );
    }
    if (request['confirm_replace'] != true) {
      throw const MhError(
        'confirmation_required',
        'The import replaces the complete working data set. Repeat the '
            'request with "confirm_replace": true. Nothing was changed.',
        {'field': 'confirm_replace'},
      );
    }
    Object? document = request['document'];
    if (document is String) {
      try {
        document = jsonDecode(document);
      } on FormatException catch (e) {
        throw MhError(
          'invalid_argument',
          'document is a string but not JSON text: ${e.message}',
          const {'field': 'document'},
        );
      }
    }
    return _withRepository(
      (repo) async =>
          (await PortableService(repo).importDocument(document)).toJson(),
    );
  }

  Future<Map<String, dynamic>> _nutritionDay(Map<String, dynamic> request) {
    final day = _day(request, 'date');
    return _withRepository(
      (repo) async => NutritionDay.compute(repo.data, day).toJson(),
    );
  }

  Future<Map<String, dynamic>> _cycleForecast(Map<String, dynamic> request) {
    final on = _day(request, 'on');
    return _withRepository((repo) async => cycleAssessment(repo.data, on));
  }

  Future<Map<String, dynamic>> _foodSearch(Map<String, dynamic> request) async {
    final q = request['q'];
    if (q is! String || q.trim().isEmpty) {
      throw const MhError(
        'invalid_argument',
        'q is required: the search text as a string.',
        {'field': 'q'},
      );
    }
    var page = 1;
    final rawPage = request['page'];
    if (rawPage != null) {
      final parsed = rawPage is num && rawPage == rawPage.roundToDouble()
          ? rawPage.toInt()
          : (rawPage is String ? int.tryParse(rawPage.trim()) : null);
      if (parsed == null || parsed < 1) {
        throw const MhError(
          'invalid_argument',
          'page must be an integer of 1 or more.',
          {'field': 'page'},
        );
      }
      page = parsed;
    }
    final client = _foodClient(await _foodLanguages());
    try {
      return (await client.search(q, page: page)).toJson();
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _foodLookup(Map<String, dynamic> request) async {
    final raw = request['barcode'];
    final String barcode;
    if (raw is String && raw.trim().isNotEmpty) {
      barcode = raw.trim();
    } else if (raw is int) {
      barcode = '$raw';
    } else {
      throw const MhError(
        'invalid_argument',
        'barcode is required: 7 to 14 digits as a string.',
        {'field': 'barcode'},
      );
    }
    final client = _foodClient(await _foodLanguages());
    try {
      return (await client.lookup(barcode)).toJson();
    } finally {
      client.close();
    }
  }

  /// Reads the language preference and enforces an explicit "disabled" of the
  /// online lookup. A data directory that cannot be opened does not prevent a
  /// lookup: it needs no stored data.
  Future<List<String>> _foodLanguages() async {
    Settings settings;
    try {
      settings = await _withRepository((repo) async => repo.data.settings);
    } on StoreException {
      _repository = null;
      return const ['de', 'en'];
    } on MhError {
      return const ['de', 'en'];
    }
    if (settings.onlineFoodSearch == OnlineFoodSearch.disabled) {
      throw const MhError(
        'online_disabled',
        'The stored settings switch the online food lookup off '
            '("online_food_search": "disabled"). No request was sent.',
      );
    }
    return settings.language == 'en' ? const ['en', 'de'] : const ['de', 'en'];
  }

  static Day _day(Map<String, dynamic> request, String field) {
    final raw = request[field];
    final day = raw is String ? Day.tryParse(raw) : null;
    if (day == null) {
      throw MhError(
        'invalid_argument',
        '$field is required: a calendar day as YYYY-MM-DD.',
        {'field': field},
      );
    }
    return day;
  }
}
