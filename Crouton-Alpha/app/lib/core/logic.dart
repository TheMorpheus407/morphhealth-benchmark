import "dart:math";
import "models.dart";

// Scale nutrients of a food (stored per 100 g/ml) by an entry amount.
Map<String, double> scaledNutrients(Map<String, dynamic> food, Map<String, dynamic> entry) {
  final base = nutrientsFrom(food["nutriments"]);
  final amount = (entry["amount"] as num?)?.toDouble() ?? 0.0;
  final unit = (entry["unit"] ?? "g").toString();
  double grams;
  if (unit == "portion") {
    final sq = (food["servingQty"] as num?)?.toDouble() ?? 100.0;
    grams = amount * sq;
  } else { grams = amount; } // g or ml treated as per-100 basis
  final f = grams / 100.0;
  return {for (final k in nutrientKeys) k: (base[k] ?? 0.0) * f};
}

Map<String, dynamic> nutritionDay(Map<String, dynamic> doc, String date) {
  final foods = {for (final f in (doc["foods"] as List).cast<Map<String, dynamic>>()) f["id"].toString(): f};
  final totals = emptyNutrients();
  final byMeal = <String, Map<String, double>>{"breakfast": emptyNutrients(), "lunch": emptyNutrients(), "dinner": emptyNutrients(), "snack": emptyNutrients()};
  final items = <Map<String, dynamic>>[];
  var waterMl = 0.0, caffeineMg = 0.0;
  for (final e in (doc["entries"] as List).cast<Map<String, dynamic>>()) {
    final at = (e["eatenAt"] ?? "").toString();
    if (!at.startsWith(date)) continue;
    final food = foods[e["foodId"].toString()];
    if (food == null) continue;
    final sc = scaledNutrients(food, e);
    for (final k in nutrientKeys) { totals[k] = (totals[k] ?? 0) + (sc[k] ?? 0); }
    final meal = (e["meal"] ?? "snack").toString();
    final bm = byMeal.putIfAbsent(meal, () => emptyNutrients());
    for (final k in nutrientKeys) { bm[k] = (bm[k] ?? 0) + (sc[k] ?? 0); }
    items.add({"id": e["id"], "foodId": e["foodId"], "foodName": food["name"], "amount": e["amount"], "unit": e["unit"], "meal": meal, "eatenAt": at, "nutriments": sc});
  }
  items.sort((a, b) => (a["eatenAt"] as String).compareTo(b["eatenAt"] as String));
  for (final w in (doc["water"] as List).cast<Map<String, dynamic>>()) { if ((w["at"] ?? "").toString().startsWith(date)) waterMl += (w["amountMl"] as num?)?.toDouble() ?? 0; }
  for (final c in (doc["caffeine"] as List).cast<Map<String, dynamic>>()) {
    if ((c["at"] ?? "").toString().startsWith(date)) { caffeineMg += (c["amountMg"] as num?)?.toDouble() ?? 0; totals["caffeine"] = (totals["caffeine"] ?? 0) + ((c["amountMg"] as num?)?.toDouble() ?? 0); }
  }
  final goals = ((doc["settings"] as Map)["goals"] as Map?) ?? {};
  return {"date": date, "totals": totals, "byMeal": byMeal, "items": items, "entryCount": items.length,
    "waterMl": waterMl, "caffeineMg": caffeineMg,
    "goals": {"waterMl": goals["waterMl"] ?? 1500, "kcal": goals["kcal"] ?? 2000, "protein": goals["protein"] ?? 60, "carbs": goals["carbs"] ?? 250, "fat": goals["fat"] ?? 70}};
}

double _median(List<double> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}
String _d(DateTime d) => "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
DateTime _parse(String s) { final p = s.split("-"); return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])); }

// Personal, history-based forecast. No ovulation/contraception/diagnosis output.
Map<String, dynamic> cycleForecast(Map<String, dynamic> doc, String onDateStr) {
  final periods = (doc["cycles"] as List).cast<Map<String, dynamic>>().toList()
    ..sort((a, b) => (a["start"] as String).compareTo(b["start"] as String));
  final on = _parse(onDateStr);
  String? phase; bool inRecorded = false;
  for (final p in periods) {
    if (onDateStr.compareTo(p["start"] as String) >= 0 && onDateStr.compareTo(p["end"] as String) <= 0) { inRecorded = true; phase = "period_recorded"; }
  }
  if (periods.length < 2) {
    return {"on": onDateStr, "status": "insufficient_data", "periodCount": periods.length,
      "predictedStart": null, "predictedEnd": null, "cycleLengthDays": null, "durationDays": null,
      "phase": inRecorded ? "period_recorded" : "unknown",
      "explanation_de": "Noch zu wenige erfasste Perioden (mindestens 2 noetig). Die Einschätzung nutzt nur Deine erfassten Perioden; sie ist keine medizinische Aussage, keine Eisprung- und keine Verhuetungsberechnung.",
      "explanation_en": "Too few recorded periods (at least 2 needed). The estimate uses only your recorded periods; it is not a medical statement, not an ovulation or contraception calculation."};
  }
  final cycles = <double>[], durations = <double>[];
  for (var i = 1; i < periods.length; i++) {
    final d = _parse(periods[i]["start"] as String).difference(_parse(periods[i - 1]["start"] as String)).inDays;
    if (d >= 15 && d <= 60) cycles.add(d.toDouble());
  }
  for (final p in periods) {
    final d = _parse(p["end"] as String).difference(_parse(p["start"] as String)).inDays + 1;
    if (d >= 1 && d <= 14) durations.add(d.toDouble());
  }
  if (cycles.isEmpty) {
    return {"on": onDateStr, "status": "insufficient_data", "periodCount": periods.length, "predictedStart": null, "predictedEnd": null,
      "cycleLengthDays": null, "durationDays": null, "phase": inRecorded ? "period_recorded" : "unknown",
      "explanation_de": "Keine auswertbaren Zykluslaengen (15-60 Tage) in Deiner Historie. Bitte pruefe die Perioden-Eintraege.",
      "explanation_en": "No evaluable cycle lengths (15-60 days) in your history. Please check the period entries."};
  }
  final cycleLen = _median(cycles);
  final dur = durations.isEmpty ? 5.0 : _median(durations);
  final lastStart = _parse(periods.last["start"] as String);
  final predictedStart = lastStart.add(Duration(days: cycleLen.round()));
  final predictedEnd = predictedStart.add(Duration(days: dur.round() - 1));
  int? daysToStart;
  if (inRecorded) { phase = "period_recorded"; }
  else if (onDateStr == _d(predictedStart)) { phase = "period_predicted"; daysToStart = 0; }
  else if (on.isAfter(predictedStart) && on.isBefore(predictedStart.add(Duration(days: dur.round())))) { phase = "period_predicted"; }
  else if (on.isBefore(predictedStart)) { phase = "before_predicted_period"; daysToStart = predictedStart.difference(on).inDays; }
  else { phase = "after_predicted_period"; daysToStart = -on.difference(predictedStart).inDays; }
  final variance = cycles.length > 1 ? (cycles.reduce(max) - cycles.reduce(min)) : 0.0;
  final confidence = cycles.length >= 6 && variance <= 4 ? "higher" : (cycles.length >= 3 ? "medium" : "lower");
  final cycS = cycles.map((e) => e.toStringAsFixed(0)).join(", ");
  final explDe = "Basierend auf ${periods.length} erfassten Perioden: typische Zykluslaenge ${cycleLen.toStringAsFixed(0)} Tage (Median; erfasste Laengen: $cycS), typische Blutungsdauer ${dur.toStringAsFixed(0)} Tage. Naechste Periode vorhergesagt ab ${_d(predictedStart)} bis ${_d(predictedEnd)}. Vertrauenswuerdigkeit: $confidence (mehr Perioden und geringe Streuung erhoehen sie). Es wird kein Eisprung berechnet; dies ist keine Diagnose, keine Verhuetung und keine medizinische Behandlung.";
  final explEn = "Based on ${periods.length} recorded periods: typical cycle length ${cycleLen.toStringAsFixed(0)} days (median; recorded lengths: $cycS), typical bleeding duration ${dur.toStringAsFixed(0)} days. Next period predicted from ${_d(predictedStart)} to ${_d(predictedEnd)}. Confidence: $confidence (more periods and low variance increase it). No ovulation is calculated; this is not a diagnosis, not contraception and not medical treatment.";
  return {"on": onDateStr, "status": "ok", "periodCount": periods.length, "cycleLengthsDays": cycles, "durationsDays": durations,
    "predictedStart": _d(predictedStart), "predictedEnd": _d(predictedEnd), "cycleLengthDays": cycleLen, "durationDays": dur,
    "phase": phase, "daysToPredictedStart": daysToStart, "confidence": confidence, "inRecordedPeriod": inRecorded,
    "explanation_de": explDe, "explanation_en": explEn};
}

// Series for 7/28 day charts: list of {date, kcal, protein, waterMl, weightKg?}
List<Map<String, dynamic>> seriesDays(Map<String, dynamic> doc, String endDate, int days) {
  final end = _parse(endDate);
  final out = <Map<String, dynamic>>[];
  for (var i = days - 1; i >= 0; i--) {
    final d = _d(end.subtract(Duration(days: i)));
    final nd = nutritionDay(doc, d);
    double? w;
    for (final e in (doc["weight"] as List).cast<Map<String, dynamic>>()) { if (e["date"] == d) w = (e["kg"] as num).toDouble(); }
    out.add({"date": d, "kcal": (nd["totals"] as Map)["kcal"], "protein": (nd["totals"] as Map)["protein"], "waterMl": nd["waterMl"], "weightKg": w});
  }
  return out;
}

// Cross-module searchable history (in-memory index; fast for 10k+ entries via single pass).
List<Map<String, dynamic>> searchHistory(Map<String, dynamic> doc, {String? from, String? to, String? module, String? q}) {
  final foods = {for (final f in (doc["foods"] as List).cast<Map<String, dynamic>>()) f["id"].toString(): f};
  final out = <Map<String, dynamic>>[];
  bool inRange(String date) => (from == null || date.compareTo(from) >= 0) && (to == null || date.compareTo(to) <= 0);
  bool matchQ(String text) => q == null || q.isEmpty || text.toLowerCase().contains(q.toLowerCase());
  if (module == null || module == "nutrition") for (final e in (doc["entries"] as List).cast<Map<String, dynamic>>()) {
    final d = (e["eatenAt"] ?? "").toString().substring(0, 10);
    final name = foods[e["foodId"].toString()]?["name"]?.toString() ?? "";
    if (inRange(d) && matchQ("$name ${e["meal"] ?? ""}")) out.add({"module": "nutrition", "id": e["id"], "date": d, "title": name, "detail": e});
  }
  if (module == null || module == "weight") for (final e in (doc["weight"] as List).cast<Map<String, dynamic>>()) {
    final d = e["date"].toString();
    if (inRange(d) && matchQ("weight ${e["kg"]}")) out.add({"module": "weight", "id": e["id"], "date": d, "title": "Weight ${e["kg"]} kg", "detail": e});
  }
  if (module == null || module == "cycle") for (final e in (doc["cycles"] as List).cast<Map<String, dynamic>>()) {
    final d = e["start"].toString();
    if (inRange(d) && matchQ("period ${e["flow"] ?? ""} ${e["note"] ?? ""}")) out.add({"module": "cycle", "id": e["id"], "date": d, "title": "Period ${e["start"]}..${e["end"]} (${e["flow"]})", "detail": e});
  }
  if (module == null || module == "symptoms") for (final e in (doc["symptoms"] as List).cast<Map<String, dynamic>>()) {
    final d = (e["at"] ?? "").toString().substring(0, 10);
    if (inRange(d) && matchQ("${e["name"]} ${e["note"] ?? ""}")) out.add({"module": "symptoms", "id": e["id"], "date": d, "title": "${e["name"]} (${e["intensity"]}/10)", "detail": e});
  }
  if (module == null || module == "water") for (final e in (doc["water"] as List).cast<Map<String, dynamic>>()) {
    final d = (e["at"] ?? "").toString().substring(0, 10);
    if (inRange(d) && matchQ("water")) out.add({"module": "water", "id": e["id"], "date": d, "title": "Water ${e["amountMl"]} ml", "detail": e});
  }
  out.sort((a, b) => (b["date"] as String).compareTo(a["date"] as String));
  return out;
}
