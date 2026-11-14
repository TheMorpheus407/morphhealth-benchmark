// Nutrient keys (canonical units, per 100 g / 100 ml unless noted).
// kcal: kcal, protein/carbs/fat/satFat/sugars/fiber/salt: g, sodium/caffeine: mg,
// vitA: ug, vitC: mg, vitD: ug, vitE: mg, vitK: ug, vitB1..B6: mg, vitB7/B9/B12: ug,
// calcium/iron/magnesium/potassium/zinc/phosphorus: mg, selenium/iodine: ug.
const nutrientKeys = [
  "kcal","protein","carbs","fat","satFat","sugars","fiber","salt","sodium","caffeine",
  "vitA","vitC","vitD","vitE","vitK","vitB1","vitB2","vitB3","vitB5","vitB6","vitB7","vitB9","vitB12",
  "calcium","iron","magnesium","potassium","zinc","selenium","iodine","phosphorus"
];
const microKeys = [
  "vitA","vitC","vitD","vitE","vitK","vitB1","vitB2","vitB3","vitB5","vitB6","vitB7","vitB9","vitB12",
  "calcium","iron","magnesium","potassium","zinc","selenium","iodine","phosphorus"
];
const nutrientUnit = {
  "kcal":"kcal","protein":"g","carbs":"g","fat":"g","satFat":"g","sugars":"g","fiber":"g","salt":"g","sodium":"mg","caffeine":"mg",
  "vitA":"ug","vitC":"mg","vitD":"ug","vitE":"mg","vitK":"ug","vitB1":"mg","vitB2":"mg","vitB3":"mg","vitB5":"mg","vitB6":"mg","vitB7":"ug","vitB9":"ug","vitB12":"ug",
  "calcium":"mg","iron":"mg","magnesium":"mg","potassium":"mg","zinc":"mg","selenium":"ug","iodine":"ug","phosphorus":"mg"
};
const nutrientLabelDe = {
  "kcal":"Energie","protein":"Protein","carbs":"Kohlenhydrate","fat":"Fett","satFat":"gesaettigte Fettsaeuren","sugars":"Zucker","fiber":"Ballaststoffe","salt":"Salz","sodium":"Natrium","caffeine":"Koffein",
  "vitA":"Vitamin A","vitC":"Vitamin C","vitD":"Vitamin D","vitE":"Vitamin E","vitK":"Vitamin K","vitB1":"Vitamin B1","vitB2":"Vitamin B2","vitB3":"Vitamin B3 (Niacin)","vitB5":"Vitamin B5","vitB6":"Vitamin B6","vitB7":"Vitamin B7 (Biotin)","vitB9":"Folsaeure (B9)","vitB12":"Vitamin B12",
  "calcium":"Kalzium","iron":"Eisen","magnesium":"Magnesium","potassium":"Kalium","zinc":"Zink","selenium":"Selen","iodine":"Jod","phosphorus":"Phosphor"
};
const nutrientLabelEn = {
  "kcal":"Energy","protein":"Protein","carbs":"Carbohydrates","fat":"Fat","satFat":"Saturated fat","sugars":"Sugars","fiber":"Fiber","salt":"Salt","sodium":"Sodium","caffeine":"Caffeine",
  "vitA":"Vitamin A","vitC":"Vitamin C","vitD":"Vitamin D","vitE":"Vitamin E","vitK":"Vitamin K","vitB1":"Vitamin B1","vitB2":"Vitamin B2","vitB3":"Vitamin B3 (niacin)","vitB5":"Vitamin B5","vitB6":"Vitamin B6","vitB7":"Vitamin B7 (biotin)","vitB9":"Folate (B9)","vitB12":"Vitamin B12",
  "calcium":"Calcium","iron":"Iron","magnesium":"Magnesium","potassium":"Potassium","zinc":"Zinc","selenium":"Selenium","iodine":"Iodine","phosphorus":"Phosphorus"
};

Map<String, double> emptyNutrients() => {for (final k in nutrientKeys) k: 0.0};
Map<String, double> nutrientsFrom(dynamic m) {
  final out = emptyNutrients();
  if (m is Map) for (final k in nutrientKeys) { final v = m[k]; if (v is num) out[k] = v.toDouble(); }
  return out;
}
String newId() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final r = (DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, "0");
  return "$t$r";
}
Map<String, dynamic> emptyDoc() => {
  "format": "morphhealth", "version": 1,
  "foods": [], "entries": [], "water": [], "caffeine": [], "weight": [], "cycles": [], "symptoms": [],
  "settings": {"lang": "de", "weightUnit": "kg", "visibleModules": ["nutrition", "cycle", "weight", "symptoms"],
    "goals": {"waterMl": 1500.0, "kcal": 2000.0, "protein": 60.0, "carbs": 250.0, "fat": 70.0},
    "foodBaseUrl": "https://world.openfoodfacts.org", "foodUserAgent": "MorphHealth/1.0"}
};
bool isValidDoc(dynamic d) {
  if (d is! Map) return false;
  if (d["format"] != "morphhealth" || d["version"] != 1) return false;
  for (final k in ["foods","entries","water","caffeine","weight","cycles","symptoms"]) { if (d[k] is! List) return false; }
  if (d["settings"] is! Map) return false;
  return true;
}
