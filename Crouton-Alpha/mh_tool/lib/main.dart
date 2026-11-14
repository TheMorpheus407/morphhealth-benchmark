import "dart:convert";
import "dart:io";
import "core/store.dart";
import "core/logic.dart";
import "core/food_api.dart";
import "core/models.dart";

void main(List<String> args) async {
  String? dataDir, keyFile, foodBase, foodUA;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    String next() => i + 1 < args.length ? args[++i] : "";
    if (a == "--data-dir") dataDir = next();
    else if (a == "--key-file") keyFile = next();
    else if (a == "--food-base-url") foodBase = next();
    else if (a == "--food-user-agent") foodUA = next();
    else if (a == "--now") next(); // fachliche Uhr; Datums-Ops nutzen das Datum aus der Anfrage
  }
  if (dataDir == null || keyFile == null) {
    stderr.writeln("usage: mh --data-dir ABS --key-file ABS [--now RFC3339] [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]");
    exit(2);
  }
  final keyBytes = await File(keyFile).readAsBytes();
  if (keyBytes.length != 32) { stderr.writeln("key-file must contain 32 raw bytes"); exit(2); }
  final store = Store(dataDir, keyBytes);
  try { store.load(); } catch (e) { stderr.writeln("load failed: $e"); exit(2); }
  final settings = store.settings;
  final off = OffClient(foodBase ?? settings["foodBaseUrl"]?.toString() ?? "https://world.openfoodfacts.org",
      foodUA ?? settings["foodUserAgent"]?.toString() ?? "MorphHealth/1.0");

  Map<String, dynamic> describeData() => {
    "format": "morphhealth", "version": 1,
    "storeFile": "data.enc.json (AES-256-GCM, key = 32-byte key-file, nonce 12 bytes, base64)",
    "document": {
      "foods": "list of {id,name,brand,barcode,nutriments:{nutrientKeys per 100g/ml},servingQty,servingUnit,isCustom,favorite}",
      "entries": "list of {id,foodId,amount,unit(g|ml|portion),meal(breakfast|lunch|dinner|snack),eatenAt ISO8601}",
      "water": "list of {id,at ISO8601,amountMl}", "caffeine": "list of {id,at ISO8601,amountMg}",
      "weight": "list of {id,date:YYYY-MM-DD,kg}",
      "cycles": "list of {id,start:YYYY-MM-DD,end:YYYY-MM-DD,flow(light|medium|heavy|spotting),note}",
      "symptoms": "list of {id,name,intensity 0..10,at ISO8601,note}",
      "settings": "{lang:de|en,weightUnit:kg|lb,visibleModules:[nutrition,cycle,weight,symptoms],goals:{waterMl,kcal,protein,carbs,fat},foodBaseUrl,foodUserAgent}"
    },
    "nutrientKeys": nutrientKeys,
    "exampleDocument": emptyDoc(),
    "ops": {
      "describe": "no extra input -> this description",
      "portable.export": "input {ack_plaintext:true} -> data is the full document",
      "portable.import": "input {document,confirm_replace:true} -> replaces store, data is a report",
      "nutrition.day": "input {date:YYYY-MM-DD} -> {date,totals,byMeal,items,entryCount,waterMl,caffeineMg,goals}",
      "cycle.forecast": "input {on:YYYY-MM-DD} -> personal median-based forecast with explanation_de/en",
      "food.search": "input {q,page:int default 1} -> {q,page,count,page_count,results:[{barcode,name,brand,nutriments_per_100}]}",
      "food.lookup": "input {barcode} -> {barcode,found:true,product:{...}} or {barcode,found:false,result,errors}"
    }
  };

  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    dynamic reqId;
    Map<String, dynamic> resp;
    try {
      final req = jsonDecode(line) as Map<String, dynamic>;
      reqId = req["request_id"];
      final op = req["op"]?.toString() ?? "";
      dynamic data;
      switch (op) {
        case "describe": data = describeData(); break;
        case "portable.export":
          if (req["ack_plaintext"] != true) throw const FormatException("ack_plaintext:true required");
          data = store.exportDoc(); break;
        case "portable.import":
          if (req["confirm_replace"] != true) throw const FormatException("confirm_replace:true required");
          if (!isValidDoc(req["document"])) throw const FormatException("invalid document");
          store.importDoc(req["document"]);
          data = {"ok": true, "foods": (store.doc["foods"] as List).length, "entries": (store.doc["entries"] as List).length};
          break;
        case "nutrition.day": data = nutritionDay(store.doc, req["date"].toString()); break;
        case "cycle.forecast": data = cycleForecast(store.doc, req["on"].toString()); break;
        case "food.search": data = await off.search(req["q"]?.toString() ?? "", (req["page"] as num?)?.toInt() ?? 1); break;
        case "food.lookup": data = await off.lookup(req["barcode"]?.toString() ?? ""); break;
        default: throw FormatException("unknown op: $op");
      }
      resp = {"request_id": reqId, "ok": true, "data": data};
    } catch (e) {
      resp = {"request_id": reqId, "ok": false, "error": e.toString()};
    }
    stdout.writeln(jsonEncode(resp));
    await stdout.flush();
  }
}
