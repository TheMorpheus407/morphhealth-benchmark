library morphhealth.core.model.nutrients;

/// Nährwerte pro 100 g (bzw. pro angegebener Portion bei Koffein).
///
/// Alle Mengen sind in einheitlichen Einheiten gespeichert:
/// Energie kcal, Makro- und Ballaststoffe g, Salz/Natrium g, Koffein mg,
/// Vitamine µg, Mineralstoffe mg. Fehlende Werte sind null.
class NutrientProfile {
  const NutrientProfile({
    this.energyKcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.saturatedFatG,
    this.sugarG,
    this.fiberG,
    this.saltG,
    this.sodiumG,
    this.caffeineMg,
    this.vitaminAG,
    this.vitaminCG,
    this.vitaminDG,
    this.vitaminEG,
    this.vitaminKG,
    this.vitaminB1G,
    this.vitaminB2G,
    this.vitaminB3G,
    this.vitaminB5G,
    this.vitaminB6G,
    this.vitaminB7G,
    this.vitaminB9G,
    this.vitaminB12G,
    this.calciumMg,
    this.ironMg,
    this.magnesiumMg,
    this.potassiumMg,
    this.zincMg,
    this.seleniumMg,
    this.iodineMg,
    this.phosphorusMg,
  });

  final double? energyKcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? saturatedFatG;
  final double? sugarG;
  final double? fiberG;
  final double? saltG;
  final double? sodiumG;
  final double? caffeineMg;
  // Vitamine in µg
  final double? vitaminAG;
  final double? vitaminCG;
  final double? vitaminDG;
  final double? vitaminEG;
  final double? vitaminKG;
  final double? vitaminB1G;
  final double? vitaminB2G;
  final double? vitaminB3G;
  final double? vitaminB5G;
  final double? vitaminB6G;
  final double? vitaminB7G;
  final double? vitaminB9G;
  final double? vitaminB12G;
  // Mineralstoffe in mg
  final double? calciumMg;
  final double? ironMg;
  final double? magnesiumMg;
  final double? potassiumMg;
  final double? zincMg;
  final double? seleniumMg;
  final double? iodineMg;
  final double? phosphorusMg;

  static const List<String> vitaminFields = [
    'vitaminA', 'vitaminC', 'vitaminD', 'vitaminE', 'vitaminK',
    'vitaminB1', 'vitaminB2', 'vitaminB3', 'vitaminB5', 'vitaminB6',
    'vitaminB7', 'vitaminB9', 'vitaminB12',
  ];

  static const List<String> mineralFields = [
    'calcium', 'iron', 'magnesium', 'potassium', 'zinc', 'selenium',
    'iodine', 'phosphorus',
  ];

  Map<String, dynamic> toJson() => <String, dynamic>{
    'energyKcal': energyKcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'saturatedFatG': saturatedFatG,
    'sugarG': sugarG,
    'fiberG': fiberG,
    'saltG': saltG,
    'sodiumG': sodiumG,
    'caffeineMg': caffeineMg,
    'vitaminA': vitaminAG,
    'vitaminC': vitaminCG,
    'vitaminD': vitaminDG,
    'vitaminE': vitaminEG,
    'vitaminK': vitaminKG,
    'vitaminB1': vitaminB1G,
    'vitaminB2': vitaminB2G,
    'vitaminB3': vitaminB3G,
    'vitaminB5': vitaminB5G,
    'vitaminB6': vitaminB6G,
    'vitaminB7': vitaminB7G,
    'vitaminB9': vitaminB9G,
    'vitaminB12': vitaminB12G,
    'calcium': calciumMg,
    'iron': ironMg,
    'magnesium': magnesiumMg,
    'potassium': potassiumMg,
    'zinc': zincMg,
    'selenium': seleniumMg,
    'iodine': iodineMg,
    'phosphorus': phosphorusMg,
  };

  factory NutrientProfile.fromJson(Map<String, dynamic> json) =>
      NutrientProfile(
        energyKcal: _num(json['energyKcal']),
        proteinG: _num(json['proteinG']),
        carbsG: _num(json['carbsG']),
        fatG: _num(json['fatG']),
        saturatedFatG: _num(json['saturatedFatG']),
        sugarG: _num(json['sugarG']),
        fiberG: _num(json['fiberG']),
        saltG: _num(json['saltG']),
        sodiumG: _num(json['sodiumG']),
        caffeineMg: _num(json['caffeineMg']),
        vitaminAG: _num(json['vitaminA']),
        vitaminCG: _num(json['vitaminC']),
        vitaminDG: _num(json['vitaminD']),
        vitaminEG: _num(json['vitaminE']),
        vitaminKG: _num(json['vitaminK']),
        vitaminB1G: _num(json['vitaminB1']),
        vitaminB2G: _num(json['vitaminB2']),
        vitaminB3G: _num(json['vitaminB3']),
        vitaminB5G: _num(json['vitaminB5']),
        vitaminB6G: _num(json['vitaminB6']),
        vitaminB7G: _num(json['vitaminB7']),
        vitaminB9G: _num(json['vitaminB9']),
        vitaminB12G: _num(json['vitaminB12']),
        calciumMg: _num(json['calcium']),
        ironMg: _num(json['iron']),
        magnesiumMg: _num(json['magnesium']),
        potassiumMg: _num(json['potassium']),
        zincMg: _num(json['zinc']),
        seleniumMg: _num(json['selenium']),
        iodineMg: _num(json['iodine']),
        phosphorusMg: _num(json['phosphorus']),
      );

  /// Offene Nährwerte (alles was nicht null ist) als lesbare Map für die UI.
  Map<String, String> presentedValues({required bool showMicronutrients}) {
    final result = <String, String>{};
    void add(String label, double? value, String unit) {
      if (value != null) result[label] = '${_fmt(value)} $unit';
    }

    add('Energie', energyKcal, 'kcal');
    add('Protein', proteinG, 'g');
    add('Kohlenhydrate', carbsG, 'g');
    add('Fett', fatG, 'g');
    if (saturatedFatG != null) add('gesättigte Fettsäuren', saturatedFatG, 'g');
    add('Zucker', sugarG, 'g');
    add('Ballaststoffe', fiberG, 'g');
    add('Salz', saltG, 'g');
    add('Natrium', sodiumG, 'g');
    if (caffeineMg != null) add('Koffein', caffeineMg, 'mg');

    if (showMicronutrients) {
      _addMicro(result, 'Vitamin A', vitaminAG, 'µg');
      _addMicro(result, 'Vitamin C', vitaminCG, 'µg');
      _addMicro(result, 'Vitamin D', vitaminDG, 'µg');
      _addMicro(result, 'Vitamin E', vitaminEG, 'µg');
      _addMicro(result, 'Vitamin K', vitaminKG, 'µg');
      _addMicro(result, 'Vitamin B1', vitaminB1G, 'µg');
      _addMicro(result, 'Vitamin B2', vitaminB2G, 'µg');
      _addMicro(result, 'Vitamin B3', vitaminB3G, 'µg');
      _addMicro(result, 'Vitamin B5', vitaminB5G, 'µg');
      _addMicro(result, 'Vitamin B6', vitaminB6G, 'µg');
      _addMicro(result, 'Vitamin B7', vitaminB7G, 'µg');
      _addMicro(result, 'Vitamin B9', vitaminB9G, 'µg');
      _addMicro(result, 'Vitamin B12', vitaminB12G, 'µg');
      _addMicro(result, 'Kalzium', calciumMg, 'mg');
      _addMicro(result, 'Eisen', ironMg, 'mg');
      _addMicro(result, 'Magnesium', magnesiumMg, 'mg');
      _addMicro(result, 'Kalium', potassiumMg, 'mg');
      _addMicro(result, 'Zink', zincMg, 'mg');
      _addMicro(result, 'Selen', seleniumMg, 'mg');
      _addMicro(result, 'Jod', iodineMg, 'mg');
      _addMicro(result, 'Phosphor', phosphorusMg, 'mg');
    }
    return result;
  }

  static void _addMicro(Map<String, String> map, String label, double? value,
      String unit) {
    if (value != null) map[label] = '${_fmt(value)} $unit';
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String _fmt(double v) {
    final rounded = (v * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) {
      return rounded.round().toString();
    }
    return rounded.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  /// Skaliert das Profil auf einen Faktor (z. B. Menge / 100 g).
  NutrientProfile scaled(double factor) => NutrientProfile(
        energyKcal: energyKcal == null ? null : energyKcal! * factor,
        proteinG: proteinG == null ? null : proteinG! * factor,
        carbsG: carbsG == null ? null : carbsG! * factor,
        fatG: fatG == null ? null : fatG! * factor,
        saturatedFatG: saturatedFatG == null ? null : saturatedFatG! * factor,
        sugarG: sugarG == null ? null : sugarG! * factor,
        fiberG: fiberG == null ? null : fiberG! * factor,
        saltG: saltG == null ? null : saltG! * factor,
        sodiumG: sodiumG == null ? null : sodiumG! * factor,
        caffeineMg: caffeineMg == null ? null : caffeineMg! * factor,
        vitaminAG: vitaminAG == null ? null : vitaminAG! * factor,
        vitaminCG: vitaminCG == null ? null : vitaminCG! * factor,
        vitaminDG: vitaminDG == null ? null : vitaminDG! * factor,
        vitaminEG: vitaminEG == null ? null : vitaminEG! * factor,
        vitaminKG: vitaminKG == null ? null : vitaminKG! * factor,
        vitaminB1G: vitaminB1G == null ? null : vitaminB1G! * factor,
        vitaminB2G: vitaminB2G == null ? null : vitaminB2G! * factor,
        vitaminB3G: vitaminB3G == null ? null : vitaminB3G! * factor,
        vitaminB5G: vitaminB5G == null ? null : vitaminB5G! * factor,
        vitaminB6G: vitaminB6G == null ? null : vitaminB6G! * factor,
        vitaminB7G: vitaminB7G == null ? null : vitaminB7G! * factor,
        vitaminB9G: vitaminB9G == null ? null : vitaminB9G! * factor,
        vitaminB12G: vitaminB12G == null ? null : vitaminB12G! * factor,
        calciumMg: calciumMg == null ? null : calciumMg! * factor,
        ironMg: ironMg == null ? null : ironMg! * factor,
        magnesiumMg: magnesiumMg == null ? null : magnesiumMg! * factor,
        potassiumMg: potassiumMg == null ? null : potassiumMg! * factor,
        zincMg: zincMg == null ? null : zincMg! * factor,
        seleniumMg: seleniumMg == null ? null : seleniumMg! * factor,
        iodineMg: iodineMg == null ? null : iodineMg! * factor,
        phosphorusMg: phosphorusMg == null ? null : phosphorusMg! * factor,
      );

  /// Addiert zwei Profile.
  NutrientProfile add(NutrientProfile other) => NutrientProfile(
        energyKcal: _sum(energyKcal, other.energyKcal),
        proteinG: _sum(proteinG, other.proteinG),
        carbsG: _sum(carbsG, other.carbsG),
        fatG: _sum(fatG, other.fatG),
        saturatedFatG: _sum(saturatedFatG, other.saturatedFatG),
        sugarG: _sum(sugarG, other.sugarG),
        fiberG: _sum(fiberG, other.fiberG),
        saltG: _sum(saltG, other.saltG),
        sodiumG: _sum(sodiumG, other.sodiumG),
        caffeineMg: _sum(caffeineMg, other.caffeineMg),
        vitaminAG: _sum(vitaminAG, other.vitaminAG),
        vitaminCG: _sum(vitaminCG, other.vitaminCG),
        vitaminDG: _sum(vitaminDG, other.vitaminDG),
        vitaminEG: _sum(vitaminEG, other.vitaminEG),
        vitaminKG: _sum(vitaminKG, other.vitaminKG),
        vitaminB1G: _sum(vitaminB1G, other.vitaminB1G),
        vitaminB2G: _sum(vitaminB2G, other.vitaminB2G),
        vitaminB3G: _sum(vitaminB3G, other.vitaminB3G),
        vitaminB5G: _sum(vitaminB5G, other.vitaminB5G),
        vitaminB6G: _sum(vitaminB6G, other.vitaminB6G),
        vitaminB7G: _sum(vitaminB7G, other.vitaminB7G),
        vitaminB9G: _sum(vitaminB9G, other.vitaminB9G),
        vitaminB12G: _sum(vitaminB12G, other.vitaminB12G),
        calciumMg: _sum(calciumMg, other.calciumMg),
        ironMg: _sum(ironMg, other.ironMg),
        magnesiumMg: _sum(magnesiumMg, other.magnesiumMg),
        potassiumMg: _sum(potassiumMg, other.potassiumMg),
        zincMg: _sum(zincMg, other.zincMg),
        seleniumMg: _sum(seleniumMg, other.seleniumMg),
        iodineMg: _sum(iodineMg, other.iodineMg),
        phosphorusMg: _sum(phosphorusMg, other.phosphorusMg),
      );

  static double? _sum(double? a, double? b) {
    if (a == null && b == null) return null;
    return ((a ?? 0) + (b ?? 0));
  }

  bool get isEmpty =>
      energyKcal == null &&
      proteinG == null &&
      carbsG == null &&
      fatG == null &&
      saturatedFatG == null &&
      sugarG == null &&
      fiberG == null &&
      saltG == null &&
      sodiumG == null &&
      caffeineMg == null &&
      vitaminAG == null &&
      vitaminCG == null &&
      vitaminDG == null &&
      vitaminEG == null &&
      vitaminKG == null &&
      vitaminB1G == null &&
      vitaminB2G == null &&
      vitaminB3G == null &&
      vitaminB5G == null &&
      vitaminB6G == null &&
      vitaminB7G == null &&
      vitaminB9G == null &&
      vitaminB12G == null &&
      calciumMg == null &&
      ironMg == null &&
      magnesiumMg == null &&
      potassiumMg == null &&
      zincMg == null &&
      seleniumMg == null &&
      iodineMg == null &&
      phosphorusMg == null;
}