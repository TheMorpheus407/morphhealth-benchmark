typedef Json = Map<String, dynamic>;

class Nutrient {
  final String id, de, en, unit, off;
  const Nutrient(this.id, this.de, this.en, this.unit, this.off);
  String name(String language) => language == 'de' ? de : en;
}

const nutrients = <Nutrient>[
  Nutrient('calories', 'Energie', 'Energy', 'kcal', 'energy-kcal'),
  Nutrient('protein', 'Protein', 'Protein', 'g', 'proteins'),
  Nutrient('carbs', 'Kohlenhydrate', 'Carbohydrates', 'g', 'carbohydrates'),
  Nutrient('fat', 'Fett', 'Fat', 'g', 'fat'),
  Nutrient(
    'saturated_fat',
    'Gesättigte Fettsäuren',
    'Saturated fat',
    'g',
    'saturated-fat',
  ),
  Nutrient('sugar', 'Zucker', 'Sugars', 'g', 'sugars'),
  Nutrient('fiber', 'Ballaststoffe', 'Fibre', 'g', 'fiber'),
  Nutrient('salt', 'Salz', 'Salt', 'g', 'salt'),
  Nutrient('sodium', 'Natrium', 'Sodium', 'mg', 'sodium'),
  Nutrient('caffeine', 'Koffein', 'Caffeine', 'mg', 'caffeine'),
  Nutrient('vitamin_a', 'Vitamin A', 'Vitamin A', 'µg', 'vitamin-a'),
  Nutrient('vitamin_c', 'Vitamin C', 'Vitamin C', 'mg', 'vitamin-c'),
  Nutrient('vitamin_d', 'Vitamin D', 'Vitamin D', 'µg', 'vitamin-d'),
  Nutrient('vitamin_e', 'Vitamin E', 'Vitamin E', 'mg', 'vitamin-e'),
  Nutrient('vitamin_k', 'Vitamin K', 'Vitamin K', 'µg', 'vitamin-k'),
  Nutrient(
    'vitamin_b1',
    'Vitamin B1 · Thiamin',
    'Vitamin B1 · Thiamin',
    'mg',
    'vitamin-b1',
  ),
  Nutrient(
    'vitamin_b2',
    'Vitamin B2 · Riboflavin',
    'Vitamin B2 · Riboflavin',
    'mg',
    'vitamin-b2',
  ),
  Nutrient(
    'vitamin_b3',
    'Vitamin B3 · Niacin',
    'Vitamin B3 · Niacin',
    'mg',
    'vitamin-pp',
  ),
  Nutrient(
    'vitamin_b5',
    'Vitamin B5 · Pantothensäure',
    'Vitamin B5 · Pantothenic acid',
    'mg',
    'pantothenic-acid',
  ),
  Nutrient('vitamin_b6', 'Vitamin B6', 'Vitamin B6', 'mg', 'vitamin-b6'),
  Nutrient(
    'vitamin_b7',
    'Vitamin B7 · Biotin',
    'Vitamin B7 · Biotin',
    'µg',
    'biotin',
  ),
  Nutrient(
    'vitamin_b9',
    'Vitamin B9 · Folat',
    'Vitamin B9 · Folate',
    'µg',
    'vitamin-b9',
  ),
  Nutrient('vitamin_b12', 'Vitamin B12', 'Vitamin B12', 'µg', 'vitamin-b12'),
  Nutrient('calcium', 'Kalzium', 'Calcium', 'mg', 'calcium'),
  Nutrient('iron', 'Eisen', 'Iron', 'mg', 'iron'),
  Nutrient('magnesium', 'Magnesium', 'Magnesium', 'mg', 'magnesium'),
  Nutrient('potassium', 'Kalium', 'Potassium', 'mg', 'potassium'),
  Nutrient('zinc', 'Zink', 'Zinc', 'mg', 'zinc'),
  Nutrient('selenium', 'Selen', 'Selenium', 'µg', 'selenium'),
  Nutrient('iodine', 'Jod', 'Iodine', 'µg', 'iodine'),
  Nutrient('phosphorus', 'Phosphor', 'Phosphorus', 'mg', 'phosphorus'),
];

Nutrient nutrientById(String id) => nutrients.firstWhere((n) => n.id == id);
double? number(dynamic value) {
  if (value is num) return value.isFinite ? value.toDouble() : null;
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

double gramsToUnit(double grams, String unit) =>
    grams *
    (unit == 'mg'
        ? 1000
        : unit == 'µg'
        ? 1000000
        : 1);
double? massConvert(double value, String from, String to) {
  const factors = {
    'g': 1.0,
    'mg': .001,
    'µg': .000001,
    'ug': .000001,
    'mcg': .000001,
    'μg': .000001,
  };
  if (!factors.containsKey(from) || !factors.containsKey(to)) return null;
  return value * factors[from]! / factors[to]!;
}

/// Cross-unit conversion requires explicit density, never an assumption.
double baseQuantity(Json food, double amount, String unit) {
  final base = food['base_unit'];
  if (unit == 'portion') {
    final serving = number(food['serving_size']);
    if (serving == null || serving <= 0) {
      throw const FormatException('serving_required');
    }
    return amount * serving;
  }
  if (unit == base) return amount;
  final density = number(food['grams_per_ml']);
  if (density == null || density <= 0) {
    throw const FormatException('density_required');
  }
  return base == 'g' ? amount * density : amount / density;
}

Json scaledNutrients(Json food, double amount, String unit) {
  final factor = baseQuantity(food, amount, unit) / 100;
  final values = food['nutrients'] as Map;
  return {
    for (final n in nutrients)
      n.id: number(values[n.id]) == null
          ? null
          : number(values[n.id])! * factor,
  };
}
