import "package:flutter_test/flutter_test.dart";
import "package:morphhealth/core/models.dart";
import "package:morphhealth/core/logic.dart";
import "package:morphhealth/core/crypto.dart";
import "package:morphhealth/core/store.dart";
import "dart:typed_data";
import "dart:io";

void main() {
  test("nutrition day sums calories", () {
    final doc = emptyDoc();
    final nuts = emptyNutrients(); nuts["kcal"] = 100; nuts["protein"] = 10;
    doc["foods"] = [{"id": "f1", "name": "Test", "brand": "", "barcode": "", "nutriments": nuts, "servingQty": 50.0, "servingUnit": "g", "isCustom": true, "favorite": false}];
    doc["entries"] = [{"id": "e1", "foodId": "f1", "amount": 200.0, "unit": "g", "meal": "lunch", "eatenAt": "2026-09-01T12:00:00"}];
    doc["water"] = [{"id": "w1", "at": "2026-09-01T08:00:00", "amountMl": 500}];
    final r = nutritionDay(doc, "2026-09-01");
    expect((r["totals"] as Map)["kcal"], 200.0);
    expect((r["totals"] as Map)["protein"], 20.0);
    expect(r["entryCount"], 1);
    expect(r["waterMl"], 500.0);
  });
  test("portion scales by servingQty", () {
    final doc = emptyDoc();
    final nuts = emptyNutrients(); nuts["kcal"] = 200;
    doc["foods"] = [{"id": "f1", "name": "X", "brand": "", "barcode": "", "nutriments": nuts, "servingQty": 50.0, "servingUnit": "g", "isCustom": true, "favorite": false}];
    doc["entries"] = [{"id": "e1", "foodId": "f1", "amount": 2.0, "unit": "portion", "meal": "snack", "eatenAt": "2026-09-01T12:00:00"}];
    final r = nutritionDay(doc, "2026-09-01");
    expect((r["totals"] as Map)["kcal"], 200.0);
  });
  test("cycle forecast uses history median", () {
    final doc = emptyDoc();
    doc["cycles"] = [
      {"id": "1", "start": "2026-06-01", "end": "2026-06-05", "flow": "medium", "note": ""},
      {"id": "2", "start": "2026-06-29", "end": "2026-07-03", "flow": "medium", "note": ""},
      {"id": "3", "start": "2026-07-27", "end": "2026-07-31", "flow": "medium", "note": ""},
    ];
    final f = cycleForecast(doc, "2026-08-20");
    expect(f["status"], "ok");
    expect(f["cycleLengthDays"], 28.0);
    expect(f["predictedStart"], "2026-08-24");
    expect(f["explanation_de"].toString().contains("28 Tage"), true);
  });
  test("crypto roundtrip and tamper detection", () {
    final key = Uint8List.fromList(List.generate(32, (i) => i));
    final e = CryptoBox.encryptWithKey(key, "hello world");
    expect(CryptoBox.decryptWithKey(key, e["nonce"]!, e["data"]!), "hello world");
    expect(() => CryptoBox.decryptWithKey(Uint8List(32), e["nonce"]!, e["data"]!), throwsFormatException);
  });
  test("store persists encrypted and reloads", () async {
    final dir = await Directory.systemTemp.createTemp("mh-test");
    final key = Uint8List.fromList(List.generate(32, (i) => i));
    final s = Store(dir.path, key); s.load();
    s.doc["weight"] = [{"id": "w1", "date": "2026-09-01", "kg": 70.0}]; s.save();
    final raw = await File("${dir.path}/data.enc.json").readAsString();
    expect(raw.contains("70.0"), false);
    final s2 = Store(dir.path, key); s2.load();
    expect((s2.doc["weight"] as List).length, 1);
  });
  test("backup passphrase roundtrip", () {
    final enc = CryptoBox.encryptPassphrase("secret", "{\"a\":1}");
    expect(CryptoBox.decryptPassphrase("secret", enc), "{\"a\":1}");
  });
  test("history search filters", () {
    final doc = emptyDoc();
    final nuts = emptyNutrients(); nuts["kcal"] = 50;
    doc["foods"] = [{"id": "f1", "name": "Quark", "brand": "", "barcode": "", "nutriments": nuts, "servingQty": 100.0, "servingUnit": "g", "isCustom": true, "favorite": false}];
    doc["entries"] = [{"id": "e1", "foodId": "f1", "amount": 100, "unit": "g", "meal": "snack", "eatenAt": "2026-09-01T12:00:00"}];
    doc["symptoms"] = [{"id": "s1", "name": "Kopfschmerz", "intensity": 3, "at": "2026-09-01T09:00:00", "note": ""}];
    expect(searchHistory(doc, q: "quark").length, 1);
    expect(searchHistory(doc, module: "symptoms", q: "kopf").length, 1);
    expect(searchHistory(doc, from: "2026-09-02").length, 0);
  });
  test("series 28 days", () {
    final doc = emptyDoc();
    final s = seriesDays(doc, "2026-09-28", 28);
    expect(s.length, 28);
    expect(s.first["date"], "2026-09-01");
  });
}
