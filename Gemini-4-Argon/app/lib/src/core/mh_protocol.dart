import 'models.dart';
import 'nutrients.dart';
import 'off_client.dart';
import 'repository.dart';

class MhProtocolHandler {
  final MorphHealthRepository repository;
  final OpenFoodFactsClient offClient;

  const MhProtocolHandler({
    required this.repository,
    required this.offClient,
  });

  static final RegExp _ymdRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static dynamic _param(Map<String, dynamic> req, String key) {
    if (req.containsKey(key)) return req[key];
    for (final nestedKey in const ['params', 'args', 'input', 'payload']) {
      final sub = req[nestedKey];
      if (sub is Map && sub.containsKey(key)) {
        return sub[key];
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> handleRequest(Map<String, dynamic> req) async {
    final requestId = req['request_id'];
    final op = req['op']?.toString().trim();

    if (op == null || op.isEmpty) {
      return _errorResponse(
        requestId,
        'missing_op',
        'Request must include a non-empty "op" field.',
      );
    }

    try {
      switch (op) {
        case 'describe':
          return _okResponse(requestId, _handleDescribe());
        case 'portable.export':
          return _okResponse(requestId, _handlePortableExport(req));
        case 'portable.import':
          return _okResponse(requestId, await _handlePortableImport(req));
        case 'nutrition.day':
          return _okResponse(requestId, _handleNutritionDay(req));
        case 'cycle.forecast':
          return _okResponse(requestId, _handleCycleForecast(req));
        case 'food.search':
          return _okResponse(requestId, await _handleFoodSearch(req));
        case 'food.lookup':
          return _okResponse(requestId, await _handleFoodLookup(req));
        default:
          return _errorResponse(
            requestId,
            'unknown_op',
            'Unsupported operation "$op". Supported operations: describe, portable.export, portable.import, nutrition.day, cycle.forecast, food.search, food.lookup.',
          );
      }
    } on OffException catch (e) {
      return _errorResponse(requestId, e.code, e.message);
    } on FormatException catch (e) {
      return _errorResponse(requestId, 'invalid_format', e.message);
    } on ArgumentError catch (e) {
      return _errorResponse(
        requestId,
        'invalid_argument',
        e.message?.toString() ?? e.toString(),
      );
    } catch (e) {
      return _errorResponse(requestId, 'internal_error', e.toString());
    }
  }

  Map<String, dynamic> _handleDescribe() {
    final exampleDoc = MorphHealthRepository.buildExamplePortableDocument(
      referenceDate: repository.todayYmd,
    );
    return {
      'application': 'MorphHealth',
      'protocol': 'MH-PERSONAL-3',
      'schema_version': MorphHealthRepository.portableSchemaVersion,
      'clock_now': repository.nowIso,
      'today': repository.todayYmd,
      'food_api': {
        'base_url': offClient.baseUrl,
        'user_agent': offClient.userAgent,
        'endpoints': {
          'lookup': 'GET {base}/api/v3.6/product/{barcode}.json',
          'search':
              'GET {base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20',
        },
      },
      'encryption': {
        'vault_file': MorphHealthRepository.vaultFileName,
        'vault_cipher': 'AES-256-GCM',
        'vault_key': '32 raw bytes from --key-file (outside --data-dir)',
        'vault_header':
            'Magic "MHV1" (4B) + Version 0x01 (1B) + Flags 0x01 gzip (1B) + Nonce (12B) + GCM Tag (16B) + Ciphertext',
        'backup_format': 'morphhealth.encrypted_backup.v1',
        'backup_kdf': 'PBKDF2-HMAC-SHA256 (100,000 iterations, 16B salt)',
        'backup_cipher': 'AES-256-GCM (12B nonce, 16B tag)',
      },
      'nutrients': [
        for (final m in NutrientCatalog.all)
          {
            'key': m.key,
            'short_key': m.shortKey,
            'category': m.category.name,
            'unit': m.unit,
            'name_de': m.nameDe,
            'name_en': m.nameEn,
            'off_keys': m.offKeys,
          },
      ],
      'portable_format': {
        'schema_version': MorphHealthRepository.portableSchemaVersion,
        'top_level_fields': [
          'schema_version',
          'application',
          'exported_at',
          'settings',
          'custom_foods',
          'favorite_foods',
          'food_entries',
          'water_entries',
          'caffeine_entries',
          'period_entries',
          'weight_entries',
          'symptom_entries',
        ],
        'units': {
          'food_amount_units': FoodUnit.all,
          'meals': MealType.all,
          'bleeding_intensities': BleedingIntensity.all,
          'weight_units': ['kg', 'lb'],
          'symptom_intensity_range': [0, 10],
        },
      },
      'operations': {
        'describe': {
          'input': <String, dynamic>{},
          'output':
              'Schema description, nutrient catalog, operation contracts, and example_document suitable for portable.import.',
        },
        'portable.export': {
          'input': {'ack_plaintext': true},
          'output': 'Complete portable document in morphhealth.portable.v1 format.',
        },
        'portable.import': {
          'input': {
            'document': 'Map (morphhealth.portable.v1)',
            'confirm_replace': true,
          },
          'output':
              'Replacement confirmation report with imported item counts per collection.',
        },
        'nutrition.day': {
          'input': {'date': 'YYYY-MM-DD'},
          'output':
              'Daily totals (calories_kcal, water_ml, caffeine_mg, all 31 nutrients grouped and flat), voluntary goals, meal breakdown (breakfast, lunch, dinner, snack), and entries.',
        },
        'cycle.forecast': {
          'input': {'on': 'YYYY-MM-DD'},
          'output':
              'Personal cycle evaluation on reference date: status, current_cycle_day, statistics (weighted/mean/median/min/max cycle length, variability, period duration), prediction (expected_start_date, window_start_date, window_end_date), and localized explanations (de/en).',
        },
        'food.search': {
          'input': {'q': 'String', 'page': 'int (optional, default 1)'},
          'output':
              'Paginated Open Food Facts search results normalized to MorphHealth FoodItem objects with all 31 nutrients per 100g/100ml.',
        },
        'food.lookup': {
          'input': {'barcode': 'String'},
          'output':
              'Normalized Open Food Facts product for the barcode with all 31 nutrients per 100g/100ml.',
        },
      },
      'example_document': exampleDoc,
      'sample_document': exampleDoc,
    };
  }

  Map<String, dynamic> _handlePortableExport(Map<String, dynamic> req) {
    final ack = _param(req, 'ack_plaintext');
    if (ack != true) {
      throw ArgumentError(
        'ack_plaintext: true is required to export plaintext data.',
      );
    }
    return repository.exportPortableDocument(ackPlaintext: true);
  }

  Future<Map<String, dynamic>> _handlePortableImport(
    Map<String, dynamic> req,
  ) async {
    final confirm = _param(req, 'confirm_replace');
    if (confirm != true) {
      throw ArgumentError(
        'confirm_replace: true is required to replace the working dataset.',
      );
    }
    final rawDoc = _param(req, 'document');
    if (rawDoc is! Map) {
      throw ArgumentError(
        'A valid "document" JSON object is required for portable.import.',
      );
    }
    return repository.importPortableDocument(
      document: Map<String, dynamic>.from(rawDoc),
      confirmReplace: true,
    );
  }

  Map<String, dynamic> _handleNutritionDay(Map<String, dynamic> req) {
    final date = _param(req, 'date')?.toString().trim();
    if (date == null || !_ymdRegex.hasMatch(date)) {
      throw ArgumentError(
        'Parameter "date" is required in YYYY-MM-DD format.',
      );
    }
    if (DateTime.tryParse('${date}T00:00:00Z') == null) {
      throw ArgumentError('Invalid calendar date: $date');
    }
    return repository.getNutritionDay(date).toJson();
  }

  Map<String, dynamic> _handleCycleForecast(Map<String, dynamic> req) {
    final on = (_param(req, 'on') ?? _param(req, 'date'))?.toString().trim();
    if (on == null || !_ymdRegex.hasMatch(on)) {
      throw ArgumentError(
        'Parameter "on" is required in YYYY-MM-DD format.',
      );
    }
    if (DateTime.tryParse('${on}T00:00:00Z') == null) {
      throw ArgumentError('Invalid calendar date: $on');
    }
    return repository.getCycleForecast(on).toJson();
  }

  Future<Map<String, dynamic>> _handleFoodSearch(
    Map<String, dynamic> req,
  ) async {
    final q = (_param(req, 'q') ?? _param(req, 'query'))?.toString().trim();
    if (q == null || q.isEmpty) {
      throw ArgumentError('Parameter "q" must be a non-empty search string.');
    }
    final rawPage = _param(req, 'page');
    int page = 1;
    if (rawPage != null) {
      if (rawPage is int) {
        page = rawPage;
      } else if (rawPage is num) {
        page = rawPage.toInt();
      } else {
        final parsed = int.tryParse(rawPage.toString());
        if (parsed == null || parsed < 1) {
          throw ArgumentError('Parameter "page" must be a positive integer.');
        }
        page = parsed;
      }
    }
    if (page < 1) {
      throw ArgumentError('Parameter "page" must be >= 1.');
    }

    final res = await offClient.search(query: q, page: page);
    // Mark favorites from local repository
    final enriched = res.products
        .map(
          (p) => p.copyWith(
            isFavorite:
                repository.isFoodFavorite(p.id, barcode: p.barcode),
          ),
        )
        .toList();
    return FoodSearchResult(
      query: res.query,
      page: res.page,
      pageSize: res.pageSize,
      totalCount: res.totalCount,
      products: enriched,
    ).toJson();
  }

  Future<Map<String, dynamic>> _handleFoodLookup(
    Map<String, dynamic> req,
  ) async {
    final barcode =
        (_param(req, 'barcode') ?? _param(req, 'code'))?.toString().trim();
    if (barcode == null || barcode.isEmpty) {
      throw ArgumentError('Parameter "barcode" must be a non-empty string.');
    }
    final item = await offClient.lookupBarcode(barcode);
    final enriched = item.copyWith(
      isFavorite: repository.isFoodFavorite(item.id, barcode: item.barcode),
    );
    final jsonMap = enriched.toJson();
    return {
      ...jsonMap,
      'found': true,
      'product': jsonMap,
    };
  }

  static Map<String, dynamic> _okResponse(
    dynamic requestId,
    Map<String, dynamic> data,
  ) {
    return {
      'request_id': requestId,
      'ok': true,
      'data': data,
    };
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
