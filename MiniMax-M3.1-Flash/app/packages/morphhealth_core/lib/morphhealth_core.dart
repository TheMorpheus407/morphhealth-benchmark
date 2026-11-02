/// MorphHealth core.
///
/// Shared, pure Dart implementation of the MorphHealth product logic:
/// data model, encrypted local store, nutrition and cycle calculations,
/// the Open Food Facts client, the portable export format and the
/// passphrase protected backup container.
///
/// The Flutter app and the `mh` maintenance CLI both use this library, so
/// there is exactly one implementation of the product behaviour.
library;

export 'src/clock.dart';
export 'src/generated/food_api_config.dart';
export 'src/l10n/strings.dart';
export 'src/models/food.dart';
export 'src/models/journal.dart';
export 'src/models/nutrients.dart';
export 'src/models/records.dart';
export 'src/portable/backup.dart';
export 'src/portable/portable_format.dart';
export 'src/services/cycle_service.dart';
export 'src/services/food_api.dart';
export 'src/services/history_service.dart';
export 'src/services/metrics_service.dart';
export 'src/services/nutrition_service.dart';
export 'src/store/crypto.dart';
export 'src/store/record_store.dart';
export 'src/store/repository.dart';
