import 'civil.dart';
import 'ids.dart';
import 'issues.dart';
import 'nutrients.dart';

/// Die vier Bereiche der Übersicht.
enum Area { nutrition, cycle, weight, symptoms }

enum Meal { breakfast, lunch, dinner, snack }

/// Einheit einer erfassten Menge.
enum AmountUnit { g, ml, portion }

/// Bezugsgröße der Nährwerte eines Lebensmittels: je 100 g oder je 100 ml.
enum Basis { g, ml }

enum FoodSource { custom, off }

/// Blutungsstärke, aufsteigend.
enum FlowLevel { spotting, light, medium, heavy }

enum WeightUnit { kg, lb }

const double kLbPerKg = 2.2046226218487757;

double kgToLb(double kg) => kg * kLbPerKg;
double lbToKg(double lb) => lb / kLbPerKg;

String enumName(Enum e) => e.name;

// ---------------------------------------------------------------------------
// Lebensmittel
// ---------------------------------------------------------------------------

/// Eine Portionsgröße, angegeben in der Bezugseinheit des Lebensmittels.
final class Serving {
  final double amount;
  final String? label;

  const Serving(this.amount, [this.label]);

  Map<String, Object?> toJson() => {'amount': amount, if (label != null) 'label': label};

  static Serving? read(Obj? o) {
    if (o == null) return null;
    final a = o.number('amount', required: true, min: 0, minExclusive: true, max: 100000);
    final l = o.string('label', max: 100);
    o.finish();
    return a == null ? null : Serving(a, l);
  }

  @override
  bool operator ==(Object other) => other is Serving && other.amount == amount && other.label == label;

  @override
  int get hashCode => Object.hash(amount, label);
}

/// Die inhaltlichen Angaben eines Lebensmittels. Ein Verzehreintrag trägt eine
/// Kopie davon, damit der Verlauf stabil bleibt.
final class FoodInfo {
  final String name;
  final String? brand;
  final String? barcode;
  final FoodSource source;
  final Basis basis;
  final Serving? serving;

  /// Nährwerte je 100 g beziehungsweise je 100 ml.
  final Nutrients nutrients;

  /// Open Food Facts: Die Werte beziehen sich auf das zubereitete Produkt.
  final bool prepared;

  const FoodInfo({
    required this.name,
    this.brand,
    this.barcode,
    this.source = FoodSource.custom,
    this.basis = Basis.g,
    this.serving,
    this.nutrients = Nutrients.none,
    this.prepared = false,
  });

  FoodInfo copyWith({
    String? name,
    String? Function()? brand,
    String? Function()? barcode,
    FoodSource? source,
    Basis? basis,
    Serving? Function()? serving,
    Nutrients? nutrients,
    bool? prepared,
  }) => FoodInfo(
    name: name ?? this.name,
    brand: brand != null ? brand() : this.brand,
    barcode: barcode != null ? barcode() : this.barcode,
    source: source ?? this.source,
    basis: basis ?? this.basis,
    serving: serving != null ? serving() : this.serving,
    nutrients: nutrients ?? this.nutrients,
    prepared: prepared ?? this.prepared,
  );

  Map<String, Object?> toJson({bool rounded = false}) => {
    'name': name,
    'brand': brand,
    'barcode': barcode,
    'source': source.name,
    'basis': basis.name,
    'serving': serving?.toJson(),
    'nutrients': nutrients.toJson(rounded: rounded),
    if (prepared) 'prepared': true,
  };

  static FoodInfo? read(Obj? o) {
    if (o == null) return null;
    final name = o.string('name', required: true, max: 200);
    final brand = o.string('brand', max: 200);
    final barcode = o.string('barcode', max: 32);
    final source = o.choice<FoodSource>('source', FoodSource.values, enumName, def: FoodSource.custom)!;
    final basis = o.choice<Basis>('basis', Basis.values, enumName, def: Basis.g)!;
    final serving = Serving.read(o.object('serving'));
    final nutrients = Nutrients.read(o.object('nutrients'));
    final prepared = o.boolean('prepared', def: false)!;
    o.finish();
    if (name == null) return null;
    return FoodInfo(
      name: name,
      brand: brand,
      barcode: barcode,
      source: source,
      basis: basis,
      serving: serving,
      nutrients: nutrients,
      prepared: prepared,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FoodInfo &&
      other.name == name &&
      other.brand == brand &&
      other.barcode == barcode &&
      other.source == source &&
      other.basis == basis &&
      other.serving == serving &&
      other.nutrients == nutrients &&
      other.prepared == prepared;

  @override
  int get hashCode => Object.hash(name, brand, barcode, source, basis, serving, nutrients, prepared);
}

/// Ein Lebensmittel der eigenen Bibliothek (eigene Lebensmittel, Favoriten und
/// zuletzt aus Open Food Facts übernommene Produkte).
final class Food {
  final String id;
  final FoodInfo info;
  final bool favorite;
  final LocalDateTime? createdAt;

  const Food({required this.id, required this.info, this.favorite = false, this.createdAt});

  Food copyWith({FoodInfo? info, bool? favorite}) =>
      Food(id: id, info: info ?? this.info, favorite: favorite ?? this.favorite, createdAt: createdAt);

  Map<String, Object?> toJson({bool rounded = false}) => {
    'id': id,
    ...info.toJson(rounded: rounded),
    'favorite': favorite,
    if (createdAt != null) 'created_at': createdAt.toString(),
  };

  static Food? read(Obj o) {
    final id = o.string('id', max: 64) ?? newId();
    final favorite = o.boolean('favorite', def: false)!;
    final created = o.dateTime('created_at');
    // FoodInfo liest dieselbe Ebene; Felder, die zu Food gehören, sind oben
    // schon als gelesen markiert.
    final info = FoodInfo.read(o);
    if (info == null) return null;
    return Food(id: id, info: info, favorite: favorite, createdAt: created);
  }
}

/// Ein Verzehreintrag.
final class FoodEntry {
  final String id;
  final String? foodId;
  final FoodInfo food;
  final double amount;
  final AmountUnit unit;
  final Meal meal;
  final LocalDateTime at;
  final String? note;

  const FoodEntry({
    required this.id,
    this.foodId,
    required this.food,
    required this.amount,
    required this.unit,
    required this.meal,
    required this.at,
    this.note,
  });

  /// Menge in der Bezugseinheit (g oder ml). Bei Portionen: Anzahl mal
  /// Portionsgröße. Eine Portion ohne Portionsgröße ergibt 0 und wird beim
  /// Speichern verhindert.
  double get baseAmount => unit == AmountUnit.portion ? amount * (food.serving?.amount ?? 0) : amount;

  /// Nährwerte dieses Eintrags.
  Nutrients get nutrients => food.nutrients.scaled(baseAmount / 100);

  Day get day => at.day;

  FoodEntry copyWith({
    String? Function()? foodId,
    FoodInfo? food,
    double? amount,
    AmountUnit? unit,
    Meal? meal,
    LocalDateTime? at,
    String? Function()? note,
  }) => FoodEntry(
    id: id,
    foodId: foodId != null ? foodId() : this.foodId,
    food: food ?? this.food,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    meal: meal ?? this.meal,
    at: at ?? this.at,
    note: note != null ? note() : this.note,
  );

  Map<String, Object?> toJson({bool rounded = false}) => {
    'id': id,
    'at': at.toString(),
    'meal': meal.name,
    'amount': amount,
    'unit': unit.name,
    'food_id': foodId,
    'food': food.toJson(rounded: rounded),
    'note': note,
  };

  /// Liest einen Eintrag. Fehlt `food`, wird [foodLookup] mit `food_id`
  /// befragt (Verweis auf die Bibliothek im selben Dokument).
  static FoodEntry? read(Obj o, {FoodInfo? Function(String id)? foodLookup}) {
    final id = o.string('id', max: 64) ?? newId();
    final at = o.dateTime('at', required: true);
    final meal = o.choice<Meal>('meal', Meal.values, enumName, def: Meal.snack)!;
    final amount = o.number('amount', required: true, min: 0, minExclusive: true, max: 1000000);
    final unit = o.choice<AmountUnit>('unit', AmountUnit.values, enumName, def: AmountUnit.g)!;
    final foodId = o.string('food_id', max: 64);
    FoodInfo? food;
    if (o.has('food')) {
      food = FoodInfo.read(o.object('food'));
    } else {
      o.raw('food');
      if (foodId != null && foodLookup != null) food = foodLookup(foodId);
      if (food == null) {
        o.issues.error(o.at('food'), 'Pflichtfeld fehlt (oder food_id verweist auf kein Lebensmittel)');
      }
    }
    final note = o.string('note', max: 2000);
    o.finish();
    if (at == null || amount == null || food == null) return null;
    if (unit == AmountUnit.portion && food.serving == null) {
      o.issues.error(o.at('unit'), 'Portion setzt food.serving voraus');
      return null;
    }
    return FoodEntry(id: id, foodId: foodId, food: food, amount: amount, unit: unit, meal: meal, at: at, note: note);
  }
}

// ---------------------------------------------------------------------------
// Wasser, Koffein, Gewicht, Symptome
// ---------------------------------------------------------------------------

final class WaterEntry {
  final String id;
  final LocalDateTime at;
  final double ml;

  const WaterEntry({required this.id, required this.at, required this.ml});

  Day get day => at.day;

  WaterEntry copyWith({LocalDateTime? at, double? ml}) => WaterEntry(id: id, at: at ?? this.at, ml: ml ?? this.ml);

  Map<String, Object?> toJson() => {'id': id, 'at': at.toString(), 'ml': ml};

  static WaterEntry? read(Obj o) {
    final id = o.string('id', max: 64) ?? newId();
    final at = o.dateTime('at', required: true);
    final ml = o.number('ml', required: true, min: 0, minExclusive: true, max: 20000);
    o.finish();
    return at == null || ml == null ? null : WaterEntry(id: id, at: at, ml: ml);
  }
}

/// Zusätzlich aufgenommenes Koffein (Kaffee, Tee, Tabletten, ...), das nicht
/// über ein Lebensmittel erfasst wurde.
final class CaffeineEntry {
  final String id;
  final LocalDateTime at;
  final double mg;
  final String? label;

  const CaffeineEntry({required this.id, required this.at, required this.mg, this.label});

  Day get day => at.day;

  CaffeineEntry copyWith({LocalDateTime? at, double? mg, String? Function()? label}) =>
      CaffeineEntry(id: id, at: at ?? this.at, mg: mg ?? this.mg, label: label != null ? label() : this.label);

  Map<String, Object?> toJson() => {'id': id, 'at': at.toString(), 'mg': mg, 'label': label};

  static CaffeineEntry? read(Obj o) {
    final id = o.string('id', max: 64) ?? newId();
    final at = o.dateTime('at', required: true);
    final mg = o.number('mg', required: true, min: 0, minExclusive: true, max: 5000);
    final label = o.string('label', max: 100);
    o.finish();
    return at == null || mg == null ? null : CaffeineEntry(id: id, at: at, mg: mg, label: label);
  }
}

final class WeightEntry {
  final String id;
  final LocalDateTime at;

  /// Intern immer in Kilogramm.
  final double kg;
  final String? note;

  const WeightEntry({required this.id, required this.at, required this.kg, this.note});

  Day get day => at.day;

  WeightEntry copyWith({LocalDateTime? at, double? kg, String? Function()? note}) =>
      WeightEntry(id: id, at: at ?? this.at, kg: kg ?? this.kg, note: note != null ? note() : this.note);

  Map<String, Object?> toJson() => {'id': id, 'at': at.toString(), 'kg': kg, 'note': note};

  static WeightEntry? read(Obj o) {
    final id = o.string('id', max: 64) ?? newId();
    final at = o.dateTime('at', required: true);
    final kg = o.number('kg', required: true, min: 1, max: 700);
    final note = o.string('note', max: 2000);
    o.finish();
    return at == null || kg == null ? null : WeightEntry(id: id, at: at, kg: kg, note: note);
  }
}

final class SymptomEntry {
  final String id;
  final String name;
  final int intensity;
  final LocalDateTime at;
  final String? note;

  const SymptomEntry({required this.id, required this.name, required this.intensity, required this.at, this.note});

  Day get day => at.day;

  /// Schlüssel zum Zusammenfassen gleicher Symptome (ohne Groß-/Kleinschreibung).
  String get key => symptomKey(name);

  SymptomEntry copyWith({String? name, int? intensity, LocalDateTime? at, String? Function()? note}) => SymptomEntry(
    id: id,
    name: name ?? this.name,
    intensity: intensity ?? this.intensity,
    at: at ?? this.at,
    note: note != null ? note() : this.note,
  );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'intensity': intensity, 'at': at.toString(), 'note': note};

  static SymptomEntry? read(Obj o) {
    final id = o.string('id', max: 64) ?? newId();
    final name = o.string('name', required: true, max: 80);
    final intensity = o.integer('intensity', required: true, min: 0, max: 10);
    final at = o.dateTime('at', required: true);
    final note = o.string('note', max: 2000);
    o.finish();
    if (name == null || intensity == null || at == null) return null;
    return SymptomEntry(id: id, name: name, intensity: intensity, at: at, note: note);
  }
}

String symptomKey(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

// ---------------------------------------------------------------------------
// Zyklus
// ---------------------------------------------------------------------------

/// Eine Periode: Beginn, optional Ende, Blutungsstärke und Notizen.
final class PeriodRecord {
  /// Eine Periode ohne erfasstes Ende gilt höchstens so viele Tage als laufend.
  static const int openMaxDays = 10;

  /// Längste erlaubte Periode in Tagen.
  static const int maxDays = 60;

  final String id;
  final Day start;
  final Day? end;

  /// Blutungsstärke der gesamten Periode (Vorgabe für alle Tage ohne eigene Angabe).
  final FlowLevel? flow;

  /// Abweichende Blutungsstärke einzelner Tage.
  final Map<Day, FlowLevel> dayFlows;
  final String? notes;

  const PeriodRecord({
    required this.id,
    required this.start,
    this.end,
    this.flow,
    this.dayFlows = const {},
    this.notes,
  });

  bool get isOpen => end == null;

  /// Letzter Tag der Periode. Bei offenem Ende: höchstens [openMaxDays] Tage
  /// ab Beginn, aber nie nach [asOf].
  Day lastDay(Day asOf) {
    if (end != null) return end!;
    final cap = start.addDays(openMaxDays - 1);
    final upto = asOf.isBefore(cap) ? asOf : cap;
    return upto.isBefore(start) ? start : upto;
  }

  bool coversDay(Day d, Day asOf) => !d.isBefore(start) && !d.isAfter(lastDay(asOf));

  FlowLevel? flowOn(Day d) => dayFlows[d] ?? flow;

  /// Nur Spotting: Der Eintrag zählt nicht als Periodenbeginn.
  bool get spottingOnly {
    final known = <FlowLevel>[?flow, ...dayFlows.values];
    return known.isNotEmpty && known.every((f) => f == FlowLevel.spotting);
  }

  /// Dauer in Tagen (Beginn und Ende zählen mit), null bei offenem Ende.
  int? get lengthDays => end == null ? null : start.daysUntil(end!) + 1;

  PeriodRecord copyWith({
    Day? start,
    Day? Function()? end,
    FlowLevel? Function()? flow,
    Map<Day, FlowLevel>? dayFlows,
    String? Function()? notes,
  }) => PeriodRecord(
    id: id,
    start: start ?? this.start,
    end: end != null ? end() : this.end,
    flow: flow != null ? flow() : this.flow,
    dayFlows: dayFlows ?? this.dayFlows,
    notes: notes != null ? notes() : this.notes,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'start': start.toString(),
    'end': end?.toString(),
    'flow': flow?.name,
    if (dayFlows.isNotEmpty)
      'day_flows': {for (final k in (dayFlows.keys.toList()..sort())) k.toString(): dayFlows[k]!.name},
    'notes': notes,
  };

  static PeriodRecord? read(Obj o) {
    final id = o.string('id', max: 64) ?? newId();
    final start = o.day('start', required: true);
    final end = o.day('end');
    final flow = o.choice<FlowLevel>('flow', FlowLevel.values, enumName);
    final notes = o.string('notes', max: 2000);
    final dayFlows = <Day, FlowLevel>{};
    final dfObj = o.object('day_flows');
    if (dfObj != null) {
      for (final k in dfObj.map.keys) {
        final d = Day.tryParse(k);
        final f = dfObj.choice<FlowLevel>(k, FlowLevel.values, enumName);
        if (d == null) {
          o.issues.error(dfObj.at(k), 'Schlüssel muss ein Datum YYYY-MM-DD sein');
        } else if (f != null) {
          dayFlows[d] = f;
        }
      }
    }
    o.finish();
    if (start == null) return null;
    if (end != null && end.isBefore(start)) {
      o.issues.error(o.at('end'), 'Ende liegt vor dem Beginn');
      return null;
    }
    // Eine Periode ohne Ende ist erlaubt und darf bis zu [maxDays] Tage laufen.
    final last = end ?? start.addDays(maxDays - 1);
    if (start.daysUntil(last) + 1 > maxDays) {
      o.issues.error(o.at('end'), 'Eine Periode darf höchstens $maxDays Tage umfassen');
      return null;
    }
    for (final d in dayFlows.keys) {
      if (d.isBefore(start) || d.isAfter(last)) {
        o.issues.error(o.at('day_flows'), 'Tag $d liegt außerhalb der Periode');
        return null;
      }
    }
    return PeriodRecord(id: id, start: start, end: end, flow: flow, dayFlows: dayFlows, notes: notes);
  }
}

// ---------------------------------------------------------------------------
// Ziele und Einstellungen
// ---------------------------------------------------------------------------

/// Freiwillige Tagesziele. Ein leeres Feld bedeutet: kein Ziel.
final class Goals {
  final double? waterMl;
  final double? energyKcal;
  final double? proteinG;
  final double? carbohydratesG;
  final double? fatG;

  const Goals({this.waterMl, this.energyKcal, this.proteinG, this.carbohydratesG, this.fatG});

  static const Goals none = Goals();

  bool get isEmpty =>
      waterMl == null && energyKcal == null && proteinG == null && carbohydratesG == null && fatG == null;

  Goals copyWith({
    double? Function()? waterMl,
    double? Function()? energyKcal,
    double? Function()? proteinG,
    double? Function()? carbohydratesG,
    double? Function()? fatG,
  }) => Goals(
    waterMl: waterMl != null ? waterMl() : this.waterMl,
    energyKcal: energyKcal != null ? energyKcal() : this.energyKcal,
    proteinG: proteinG != null ? proteinG() : this.proteinG,
    carbohydratesG: carbohydratesG != null ? carbohydratesG() : this.carbohydratesG,
    fatG: fatG != null ? fatG() : this.fatG,
  );

  /// Ziel für einen Nährstoffschlüssel, falls vorhanden.
  double? forNutrient(String key) => switch (key) {
    kEnergy => energyKcal,
    kProtein => proteinG,
    kCarbs => carbohydratesG,
    kFat => fatG,
    _ => null,
  };

  Map<String, Object?> toJson() => {
    'water_ml': waterMl,
    'energy_kcal': energyKcal,
    'protein_g': proteinG,
    'carbohydrates_g': carbohydratesG,
    'fat_g': fatG,
  };

  static Goals read(Obj? o) {
    if (o == null) return none;
    final g = Goals(
      waterMl: o.number('water_ml', min: 0, minExclusive: true, max: 20000),
      energyKcal: o.number('energy_kcal', min: 0, minExclusive: true, max: 20000),
      proteinG: o.number('protein_g', min: 0, minExclusive: true, max: 2000),
      carbohydratesG: o.number('carbohydrates_g', min: 0, minExclusive: true, max: 3000),
      fatG: o.number('fat_g', min: 0, minExclusive: true, max: 2000),
    );
    o.finish();
    return g;
  }

  @override
  bool operator ==(Object other) =>
      other is Goals &&
      other.waterMl == waterMl &&
      other.energyKcal == energyKcal &&
      other.proteinG == proteinG &&
      other.carbohydratesG == carbohydratesG &&
      other.fatG == fatG;

  @override
  int get hashCode => Object.hash(waterMl, energyKcal, proteinG, carbohydratesG, fatG);
}

/// Anzeige- und Verhaltenseinstellungen der Installation.
final class AppSettings {
  /// `de` (Voreinstellung) oder `en`.
  final String language;
  final WeightUnit weightUnit;

  /// Sichtbare Bereiche der Übersicht.
  final Set<Area> areas;

  /// Online-Lebensmittelsuche erlaubt.
  final bool onlineFood;

  /// Eigener Ursprung der Lebensmittel-API; null = Vorgabe des Builds.
  final String? foodBaseUrl;

  /// Zyklusprognose anzeigen. Aus = reines Tagebuch.
  final bool cycleForecast;

  /// Vom Nutzer gewählte typische Zykluslänge in Tagen, solange noch keine
  /// eigene Historie vorliegt.
  final int? expectedCycleLength;

  /// `system`, `light` oder `dark`.
  final String theme;

  /// Bildschirmaufnahmen und die Vorschau in der App-Übersicht sperren.
  final bool secureScreen;

  const AppSettings({
    this.language = 'de',
    this.weightUnit = WeightUnit.kg,
    this.areas = const {Area.nutrition, Area.cycle, Area.weight, Area.symptoms},
    this.onlineFood = true,
    this.foodBaseUrl,
    this.cycleForecast = true,
    this.expectedCycleLength,
    this.theme = 'system',
    this.secureScreen = false,
  });

  bool shows(Area a) => areas.contains(a);

  AppSettings copyWith({
    String? language,
    WeightUnit? weightUnit,
    Set<Area>? areas,
    bool? onlineFood,
    String? Function()? foodBaseUrl,
    bool? cycleForecast,
    int? Function()? expectedCycleLength,
    String? theme,
    bool? secureScreen,
  }) => AppSettings(
    language: language ?? this.language,
    weightUnit: weightUnit ?? this.weightUnit,
    areas: areas ?? this.areas,
    onlineFood: onlineFood ?? this.onlineFood,
    foodBaseUrl: foodBaseUrl != null ? foodBaseUrl() : this.foodBaseUrl,
    cycleForecast: cycleForecast ?? this.cycleForecast,
    expectedCycleLength: expectedCycleLength != null ? expectedCycleLength() : this.expectedCycleLength,
    theme: theme ?? this.theme,
    secureScreen: secureScreen ?? this.secureScreen,
  );

  /// [portable] lässt gerätespezifische Verbindungsdaten weg.
  Map<String, Object?> toJson({bool portable = false}) => {
    'language': language,
    'weight_unit': weightUnit.name,
    'areas': {for (final a in Area.values) a.name: areas.contains(a)},
    'online_food': onlineFood,
    if (!portable) 'food_base_url': foodBaseUrl,
    'cycle_forecast': cycleForecast,
    'expected_cycle_length_days': expectedCycleLength,
    'theme': theme,
    'secure_screen': secureScreen,
  };

  static AppSettings read(Obj? o) {
    if (o == null) return const AppSettings();
    final language = o.choice<String>('language', const ['de', 'en'], (s) => s, def: 'de')!;
    final unit = o.choice<WeightUnit>('weight_unit', WeightUnit.values, enumName, def: WeightUnit.kg)!;
    var areas = const {Area.nutrition, Area.cycle, Area.weight, Area.symptoms};
    final ao = o.object('areas');
    if (ao != null) {
      areas = {
        for (final a in Area.values)
          if (ao.boolean(a.name, def: true)!) a,
      };
      ao.finish();
    }
    final online = o.boolean('online_food', def: true)!;
    final base = o.string('food_base_url', max: 300);
    final forecast = o.boolean('cycle_forecast', def: true)!;
    final expected = o.integer('expected_cycle_length_days', min: 15, max: 60);
    final theme = o.choice<String>('theme', const ['system', 'light', 'dark'], (s) => s, def: 'system')!;
    final secure = o.boolean('secure_screen', def: false)!;
    o.finish();
    return AppSettings(
      language: language,
      weightUnit: unit,
      areas: areas,
      onlineFood: online,
      foodBaseUrl: base,
      cycleForecast: forecast,
      expectedCycleLength: expected,
      theme: theme,
      secureScreen: secure,
    );
  }
}
