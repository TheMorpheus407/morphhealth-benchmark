import "dart:convert";
import "dart:io";
import "dart:math" as math;
import "dart:typed_data";
import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";
import "package:file_picker/file_picker.dart";
import "core/store.dart";
import "core/crypto.dart";
import "core/logic.dart";
import "core/food_api.dart";
import "core/models.dart";

void main() => runApp(const MorphApp());

const _s = {
 "de": {
  "appTitle":"MorphHealth","overview":"Übersicht","nutrition":"Ernährung","cycle":"Zyklus","weight":"Gewicht","symptoms":"Symptome","history":"Verlauf","settings":"Einstellungen",
  "today":"Heute","kcal":"kcal","protein":"Protein","carbs":"Kohlenhydrate","fat":"Fett","water":"Wasser","caffeine":"Koffein","add":"Hinzufügen","edit":"Bearbeiten","delete":"Löschen","save":"Speichern","cancel":"Abbrechen","search":"Suchen","close":"Schließen",
  "breakfast":"Frühstück","lunch":"Mittagessen","dinner":"Abendessen","snack":"Snack","meal":"Mahlzeit","amount":"Menge","unit":"Einheit","gram":"g","ml":"ml","portion":"Portion",
  "customFood":"Eigenes Lebensmittel","newFood":"Neues Lebensmittel","name":"Name","brand":"Marke","barcode":"Barcode","favorite":"Favorit","favorites":"Favoriten",
  "log":"Verzehr erfassen","relog":"Erneut erfassen","customAmount":"Eigene Menge","quickWater":"Wasser schnell erfassen",
  "start":"Beginn","end":"Ende","flow":"Blutungsstärke","note":"Notiz","forecast":"Persönliche Einschätzung","historyList":"Historie",
  "intensity":"Intensität","date":"Datum","language":"Sprache","weightUnit":"Gewichtseinheit","visibleModules":"Sichtbare Bereiche",
  "goals":"Tagesziele","waterGoal":"Wasser (ml)","kcalGoal":"Kalorien","proteinGoal":"Protein (g)","carbsGoal":"Kohlenhydrate (g)","fatGoal":"Fett (g)",
  "foodBase":"Open-Food-Facts-Basis-URL","foodUA":"User-Agent","exportData":"Daten exportieren (JSON)","importData":"Daten importieren","backup":"Verschlüsselte Sicherung erstellen","restore":"Sicherung wiederherstellen","wipe":"Alle Daten löschen","passphrase":"Passphrase",
  "noData":"Noch keine Einträge.","offlineSearchFirst":"Zuerst lokale Lebensmittel, dann Online-Suche.","onlineSearch":"Online suchen","lookupBarcode":"Per Barcode suchen",
  "predicted":"Vorhergesagt","recorded":"Erfasst","selectDay":"Tag auswählen","dayDetail":"Tagesdetail","charts":"Verläufe","last7":"7 Tage","last28":"28 Tage",
  "searchHistory":"Verlauf durchsuchen","filterModule":"Bereich","allModules":"Alle","from":"Von","to":"Bis","query":"Freitext",
  "emptySearch":"Keine Treffer.","added":"Gespeichert.","deleted":"Gelöscht.","spotting":"Spotting","light":"Leicht","medium":"Mittel","heavy":"Stark",
  "nutrientsPer100":"Nährstoffe pro 100 g/ml","servingQty":"Portionsmenge (g/ml)","filter":"Filter","applied":"Übernommen","confirmWipe":"Wirklich alle lokalen Daten löschen?",
  "confirmImport":"Import ersetzt den gesamten aktuellen Datenbestand. Fortfahren?"," symptomName":"Symptomname","chartNutrient":"Verlauf (Nährstoff wählen)",
  "symptomFilter":"Symptom wählen","weightChart":"Gewichtsverlauf","detail":"Details","tools":"Wasser / Koffein","settingsSaved":"Einstellungen gespeichert."
 },
 "en": {
  "appTitle":"MorphHealth","overview":"Overview","nutrition":"Nutrition","cycle":"Cycle","weight":"Weight","symptoms":"Symptoms","history":"History","settings":"Settings",
  "today":"Today","kcal":"kcal","protein":"Protein","carbs":"Carbohydrates","fat":"Fat","water":"Water","caffeine":"Caffeine","add":"Add","edit":"Edit","delete":"Delete","save":"Save","cancel":"Cancel","search":"Search","close":"Close",
  "breakfast":"Breakfast","lunch":"Lunch","dinner":"Dinner","snack":"Snack","meal":"Meal","amount":"Amount","unit":"Unit","gram":"g","ml":"ml","portion":"Portion",
  "customFood":"Custom food","newFood":"New food","name":"Name","brand":"Brand","barcode":"Barcode","favorite":"Favorite","favorites":"Favorites",
  "log":"Log food","relog":"Log again","customAmount":"Custom amount","quickWater":"Quick water logging",
  "start":"Start","end":"End","flow":"Flow","note":"Note","forecast":"Personal estimate","historyList":"History",
  "intensity":"Intensity","date":"Date","language":"Language","weightUnit":"Weight unit","visibleModules":"Visible modules",
  "goals":"Daily goals","waterGoal":"Water (ml)","kcalGoal":"Calories","proteinGoal":"Protein (g)","carbsGoal":"Carbohydrates (g)","fatGoal":"Fat (g)",
  "foodBase":"Open Food Facts base URL","foodUA":"User agent","exportData":"Export data (JSON)","importData":"Import data","backup":"Create encrypted backup","restore":"Restore backup","wipe":"Delete all data","passphrase":"Passphrase",
  "noData":"No entries yet.","offlineSearchFirst":"Local foods first, then online search.","onlineSearch":"Search online","lookupBarcode":"Look up by barcode",
  "predicted":"Predicted","recorded":"Recorded","selectDay":"Select day","dayDetail":"Day detail","charts":"Trends","last7":"7 days","last28":"28 days",
  "searchHistory":"Search history","filterModule":"Module","allModules":"All","from":"From","to":"To","query":"Free text",
  "emptySearch":"No results.","added":"Saved.","deleted":"Deleted.","spotting":"Spotting","light":"Light","medium":"Medium","heavy":"Heavy",
  "nutrientsPer100":"Nutrients per 100 g/ml","servingQty":"Serving qty (g/ml)","filter":"Filter","applied":"Applied","confirmWipe":"Really delete all local data?",
  "confirmImport":"Import replaces the entire current dataset. Continue?","symptomName":"Symptom name","chartNutrient":"Trend (choose nutrient)",
  "symptomFilter":"Choose symptom","weightChart":"Weight trend","detail":"Details","tools":"Water / Caffeine","settingsSaved":"Settings saved."
 }
};

class MorphApp extends StatefulWidget {
  const MorphApp({super.key});
  @override State<MorphApp> createState() => _MorphAppState();
}
class _MorphAppState extends State<MorphApp> {
  Store? store;
  bool loading = true;
  String error = "";
  @override void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final keyFile = File("${dir.path}/morphhealth.key");
      if (!keyFile.existsSync()) { keyFile.writeAsBytesSync(CryptoBox.randomBytes(32)); }
      final key = keyFile.readAsBytesSync();
      store = Store("${dir.path}/morphhealth", key);
      store!.load();
    } catch (e) { error = e.toString(); }
    setState(() => loading = false);
  }
  @override Widget build(BuildContext context) {
    if (loading) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    if (store == null) return MaterialApp(home: Scaffold(body: Center(child: Text("Error: $error"))));
    return MaterialApp(title: "MorphHealth", debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light), useMaterial3: true, visualDensity: VisualDensity.adaptivePlatformDensity, textTheme: ThemeData.light().textTheme.apply(fontSizeFactor: 1.0)),
      home: Shell(store: store!, keyFile: null));
  }
}

String ymd(DateTime d) => "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";

class Shell extends StatefulWidget {
  final Store store; final dynamic keyFile;
  const Shell({super.key, required this.store, this.keyFile});
  @override State<Shell> createState() => _ShellState();
}
class _ShellState extends State<Shell> {
  int tab = 0;
  DateTime selected = DateTime.now();
  void refresh() => setState(() {});
  String get lang => (widget.store.settings["lang"] ?? "de").toString();
  String t(String k) => (_s[lang] ?? _s["de"]!)[k] ?? k;
  @override Widget build(BuildContext context) {
    final pages = <Widget>[
      OverviewPage(store: widget.store, t: t, selected: selected, onDay: (d) { setState(() => selected = d); }, go: (i) => setState(() => tab = i), refresh: refresh),
      NutritionPage(store: widget.store, t: t, selected: selected, refresh: refresh),
      CyclePage(store: widget.store, t: t, selected: selected, onDay: (d) => setState(() => selected = d), refresh: refresh),
      HistoryPage(store: widget.store, t: t, refresh: refresh),
      SettingsPage(store: widget.store, t: t, refresh: refresh),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t("appTitle")), actions: [
        IconButton(icon: const Icon(Icons.calendar_month), tooltip: t("selectDay"), onPressed: () async {
          final d = await showDatePicker(context: context, initialDate: selected, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) setState(() => selected = d);
        }),
        TextButton(onPressed: () => setState(() => selected = DateTime.now()), child: Text(t("today"))),
      ]),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: [
        NavigationDestination(icon: const Icon(Icons.home), label: t("overview")),
        NavigationDestination(icon: const Icon(Icons.restaurant), label: t("nutrition")),
        NavigationDestination(icon: const Icon(Icons.calendar_month), label: t("cycle")),
        NavigationDestination(icon: const Icon(Icons.history), label: t("history")),
        NavigationDestination(icon: const Icon(Icons.settings), label: t("settings")),
      ]),
    );
  }
}

Widget nutriTiles(BuildContext context, Map<String, double> totals, String lang) {
  final labels = lang == "de" ? nutrientLabelDe : nutrientLabelEn;
  Widget row(String k) => ListTile(dense: true, title: Text("${labels[k]}"), trailing: Text("${(totals[k] ?? 0).toStringAsFixed(1)} ${nutrientUnit[k] ?? ""}"));
  return Column(children: [
    Wrap(spacing: 8, runSpacing: 8, children: [
      Chip(label: Text("${(totals["kcal"] ?? 0).toStringAsFixed(0)} kcal")),
      Chip(label: Text("P ${(totals["protein"] ?? 0).toStringAsFixed(1)} g")),
      Chip(label: Text("C ${(totals["carbs"] ?? 0).toStringAsFixed(1)} g")),
      Chip(label: Text("F ${(totals["fat"] ?? 0).toStringAsFixed(1)} g")),
    ]),
    ExpansionTile(title: Text("Details / ${lang == "de" ? "Mikronährstoffe" : "Micronutrients"}"), children: [for (final k in nutrientKeys) row(k)]),
  ]);
}

class OverviewPage extends StatelessWidget {
  final Store store; final String Function(String) t; final DateTime selected; final void Function(DateTime) onDay; final void Function(int) go; final VoidCallback refresh;
  const OverviewPage({super.key, required this.store, required this.t, required this.selected, required this.onDay, required this.go, required this.refresh});
  @override Widget build(BuildContext context) {
    final date = ymd(selected);
    final nd = nutritionDay(store.doc, date);
    final fc = cycleForecast(store.doc, date);
    final visible = ((store.settings["visibleModules"] as List?) ?? []).cast<String>();
    final weights = (store.doc["weight"] as List).cast<Map<String, dynamic>>().where((e) => e["date"] == date).toList();
    final syms = (store.doc["symptoms"] as List).cast<Map<String, dynamic>>().where((e) => (e["at"] as String).startsWith(date)).toList();
    final cycles = (store.doc["cycles"] as List).cast<Map<String, dynamic>>().where((e) => date.compareTo(e["start"].toString()) >= 0 && date.compareTo(e["end"].toString()) <= 0).toList();
    return RefreshIndicator(onRefresh: () async => refresh(), child: ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => onDay(selected.subtract(const Duration(days: 1)))), Expanded(child: Text(date, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center)), IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => onDay(selected.add(const Duration(days: 1))))]),
      if (visible.contains("nutrition")) Card(child: ListTile(title: Text(t("nutrition")), subtitle: nutriTiles(context, (nd["totals"] as Map).cast<String, double>(), store.settings["lang"].toString()), trailing: const Icon(Icons.arrow_forward), onTap: () => go(1))),
      if (visible.contains("cycle")) Card(child: ListTile(title: Text(t("cycle")), subtitle: Text("${fc["phase"] ?? ""} · ${fc["predictedStart"] ?? "—"}"), trailing: const Icon(Icons.arrow_forward), onTap: () => go(2))),
      if (visible.contains("weight")) Card(child: ListTile(title: Text(t("weight")), subtitle: Text(weights.isEmpty ? t("noData") : weights.map((e) => "${e["kg"]} kg / ${((e["kg"] as num) * 2.20462).toStringAsFixed(1)} lb").join(", ")), trailing: const Icon(Icons.add), onTap: () => showWeightDialog(context, store, refresh, date: date))),
      if (visible.contains("symptoms")) Card(child: ListTile(title: Text(t("symptoms")), subtitle: Text(syms.isEmpty ? t("noData") : syms.map((e) => "${e["name"]} ${e["intensity"]}/10").join(", ")), trailing: const Icon(Icons.add), onTap: () => showSymptomDialog(context, store, refresh, at: selected))),
      Card(child: ListTile(title: Text(t("tools")), subtitle: Text("${t("water")}: ${(nd["waterMl"] as num).toStringAsFixed(0)} ml · ${t("caffeine")}: ${(nd["caffeineMg"] as num).toStringAsFixed(0)} mg"), onTap: () => go(1))),
      if (cycles.isNotEmpty) Card(child: ListTile(title: Text(t("recorded")), subtitle: Text(cycles.map((e) => "${e["start"]}..${e["end"]} ${e["flow"]}").join(", ")))),
      Card(child: ListTile(title: Text(t("charts")), subtitle: Text("${t("last7")} / ${t("last28")}"), onTap: () => showCharts(context, store, t, date))),
    ]));
  }
}

class NutritionPage extends StatefulWidget {
  final Store store; final String Function(String) t; final DateTime selected; final VoidCallback refresh;
  const NutritionPage({super.key, required this.store, required this.t, required this.selected, required this.refresh});
  @override State<NutritionPage> createState() => _NutritionPageState();
}
class _NutritionPageState extends State<NutritionPage> {
  final qCtrl = TextEditingController(); final bcCtrl = TextEditingController();
  List<Map<String, dynamic>> online = []; String msg = ""; bool busy = false; int page = 1;
  OffClient get off => OffClient(widget.store.settings["foodBaseUrl"]?.toString() ?? "https://world.openfoodfacts.org", widget.store.settings["foodUserAgent"]?.toString() ?? "MorphHealth/1.0");
  Future<void> _search() async {
    setState(() { busy = true; msg = ""; });
    try { final r = await off.search(qCtrl.text.trim(), page); online = (r["results"] as List).cast<Map<String, dynamic>>(); msg = "${r["count"]}"; }
    catch (e) { msg = e.toString(); }
    setState(() => busy = false);
  }
  Future<void> _lookup() async {
    setState(() { busy = true; msg = ""; });
    try {
      final r = await off.lookup(bcCtrl.text.trim());
      if (r["found"] == true) { online = [(r["product"] as Map).cast<String, dynamic>()]; msg = "found"; }
      else { msg = "not found: ${r["result"]}"; }
    } catch (e) { msg = e.toString(); }
    setState(() => busy = false);
  }
  void _addFood(Map<String, dynamic> src) {
    final id = "off-${(src["barcode"] ?? "").toString()}-${newId()}";
    final food = {"id": id, "name": "${src["name"]} ${src["brand"] ?? ""}".trim(), "brand": src["brand"] ?? "", "barcode": src["barcode"] ?? "",
      "nutriments": nutrientsFrom(src["nutriments_per_100"] ?? src["nutriments"]), "servingQty": 100.0, "servingUnit": "g", "isCustom": false, "favorite": false};
    widget.store.foods.add(food); widget.store.save();
    showLogDialog(context, widget.store, widget.refresh, food, widget.selected, widget.t);
    widget.refresh();
  }
  @override Widget build(BuildContext context) {
    final date = ymd(widget.selected);
    final nd = nutritionDay(widget.store.doc, date);
    final totals = (nd["totals"] as Map).cast<String, double>();
    final myFoods = widget.store.foods;
    final q = qCtrl.text.toLowerCase();
    final local = myFoods.where((f) => q.isEmpty || f["name"].toString().toLowerCase().contains(q)).toList();
    final favs = myFoods.where((f) => f["favorite"] == true).toList();
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text(date, style: Theme.of(context).textTheme.titleLarge),
      nutriTiles(context, totals, widget.store.settings["lang"].toString()),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        ElevatedButton(onPressed: () async { widget.store.doc["water"].add({"id": newId(), "at": widget.selected.toIso8601String(), "amountMl": 250.0}); widget.store.save(); widget.refresh(); }, child: const Text("+250 ml")),
        ElevatedButton(onPressed: () async { widget.store.doc["water"].add({"id": newId(), "at": widget.selected.toIso8601String(), "amountMl": 500.0}); widget.store.save(); widget.refresh(); }, child: const Text("+500 ml")),
        ElevatedButton(onPressed: () => showQuickAdd(context, widget.store, widget.refresh, widget.selected, widget.t), child: Text(widget.t("quickWater"))),
      ]),
      TextField(decoration: InputDecoration(labelText: widget.t("offlineSearchFirst"))),
      Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
        Expanded(child: TextField(controller: qCtrl, decoration: InputDecoration(labelText: widget.t("search"), prefixIcon: const Icon(Icons.search)))),
        IconButton(icon: const Icon(Icons.search), onPressed: () { setState(() {}); _search(); }),
      ])),
      Row(children: [Expanded(child: TextField(controller: bcCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: widget.t("lookupBarcode")))), IconButton(icon: const Icon(Icons.qr_code), onPressed: _lookup)]),
      if (busy) const Center(child: CircularProgressIndicator()),
      if (msg.isNotEmpty) Text(msg),
      if (favs.isNotEmpty) ...[Text(widget.t("favorites"), style: Theme.of(context).textTheme.titleMedium), for (final f in favs) ListTile(title: Text(f["name"].toString()), trailing: const Icon(Icons.star), onTap: () => showLogDialog(context, widget.store, widget.refresh, f, widget.selected, widget.t))],
      Text(widget.t("customFood"), style: Theme.of(context).textTheme.titleMedium),
      for (final f in local) ListTile(
        title: Text(f["name"].toString()), subtitle: Text("100g: ${((nutrientsFrom(f["nutriments"])["kcal"] ?? 0.0).toStringAsFixed(0))} kcal · ${f["brand"]} · ${f["barcode"]}"),
        leading: IconButton(icon: Icon(f["favorite"] == true ? Icons.star : Icons.star_border), tooltip: widget.t("favorite"), onPressed: () { f["favorite"] = !(f["favorite"] == true); widget.store.save(); widget.refresh(); }),
        trailing: PopupMenuButton(onSelected: (v) async {
          if (v == "log") showLogDialog(context, widget.store, widget.refresh, f, widget.selected, widget.t);
          if (v == "edit") { await showFoodDialog(context, widget.store, widget.refresh, widget.t, existing: f); }
          if (v == "del") { widget.store.foods.removeWhere((x) => x["id"] == f["id"]); widget.store.save(); widget.refresh(); }
        }, itemBuilder: (_) => [PopupMenuItem(value: "log", child: Text(widget.t("log"))), PopupMenuItem(value: "edit", child: Text(widget.t("edit"))), PopupMenuItem(value: "del", child: Text(widget.t("delete")))])),
      for (final f in online.where((e) => e["barcode"].toString().isNotEmpty)) ListTile(title: Text("${f["name"]} (${f["brand"]})"), subtitle: Text("${f["barcode"]} · ${((nutrientsFrom(f["nutriments_per_100"] ?? f["nutriments"])["kcal"] ?? 0.0).toStringAsFixed(0))} kcal /100"), trailing: IconButton(icon: const Icon(Icons.add), tooltip: widget.t("add"), onPressed: () => _addFood(f))),
      Padding(padding: const EdgeInsets.all(8), child: ElevatedButton.icon(onPressed: () => showFoodDialog(context, widget.store, widget.refresh, widget.t), icon: const Icon(Icons.add), label: Text(widget.t("newFood")))),
      Text(widget.t("nutrition"), style: Theme.of(context).textTheme.titleLarge),
      for (final item in (nd["items"] as List).cast<Map<String, dynamic>>()) ListTile(
        title: Text("${item["foodName"]} — ${item["amount"]} ${item["unit"]} (${item["meal"]})"),
        subtitle: Text("${((nutrientsFrom(item["nutriments"])["kcal"] ?? 0.0).toStringAsFixed(0))} kcal · ${item["eatenAt"]}"),
        trailing: PopupMenuButton(onSelected: (v) async {
          final entries = widget.store.entries;
          final e = entries.firstWhere((x) => x["id"] == item["id"], orElse: () => {});
          if (v == "edit") await showLogDialog(context, widget.store, widget.refresh, widget.store.foods.firstWhere((f) => f["id"] == e["foodId"], orElse: () => {}), widget.selected, widget.t, existing: e);
          if (v == "del") { entries.removeWhere((x) => x["id"] == item["id"]); widget.store.save(); widget.refresh(); }
          if (v == "relog") { entries.add({"id": newId(), "foodId": item["foodId"], "amount": item["amount"], "unit": item["unit"], "meal": item["meal"], "eatenAt": DateTime.now().toIso8601String()}); widget.store.save(); widget.refresh(); }
        }, itemBuilder: (_) => [PopupMenuItem(value: "edit", child: Text(widget.t("edit"))), PopupMenuItem(value: "relog", child: Text(widget.t("relog"))), PopupMenuItem(value: "del", child: Text(widget.t("delete")))])),
    ]);
  }
}

Future<void> showQuickAdd(BuildContext context, Store store, VoidCallback refresh, DateTime day, String Function(String) t) async {
  final ml = TextEditingController(); final caf = TextEditingController();
  await showDialog(context: context, builder: (_) => AlertDialog(title: Text(t("tools")), content: Column(mainAxisSize: MainAxisSize.min, children: [
    TextField(controller: ml, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "${t("water")} (ml)")),
    TextField(controller: caf, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "${t("caffeine")} (mg)")),
  ]), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text(t("cancel"))),
    ElevatedButton(onPressed: () {
      final m = double.tryParse(ml.text.replaceAll(",", ".")) ?? 0; if (m > 0) { store.doc["water"].add({"id": newId(), "at": day.toIso8601String(), "amountMl": m}); }
      final c = double.tryParse(caf.text.replaceAll(",", ".")) ?? 0; if (c > 0) { store.doc["caffeine"].add({"id": newId(), "at": day.toIso8601String(), "amountMg": c}); }
      store.save(); refresh(); Navigator.pop(context);
    }, child: Text(t("save"))),
  ]));
}

Future<void> showLogDialog(BuildContext context, Store store, VoidCallback refresh, Map<String, dynamic> food, DateTime day, String Function(String) t, {Map<String, dynamic>? existing}) async {
  if (food.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("food missing"))); return; }
  final amt = TextEditingController(text: existing?["amount"]?.toString() ?? "100");
  String unit = existing?["unit"]?.toString() ?? "g";
  String meal = existing?["meal"]?.toString() ?? "snack";
  TimeOfDay time = existing != null ? TimeOfDay.fromDateTime(DateTime.parse(existing["eatenAt"].toString())) : TimeOfDay.now();
  await showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(title: Text(food["name"].toString()), content: Column(mainAxisSize: MainAxisSize.min, children: [
    TextField(controller: amt, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t("amount"))),
    DropdownButtonFormField<String>(initialValue: unit, items: [for (final u in ["g", "ml", "portion"]) DropdownMenuItem(value: u, child: Text(u))], onChanged: (v) => setD(() => unit = v!), decoration: InputDecoration(labelText: t("unit"))),
    DropdownButtonFormField<String>(initialValue: meal, items: [for (final m in ["breakfast", "lunch", "dinner", "snack"]) DropdownMenuItem(value: m, child: Text(t(m)))], onChanged: (v) => setD(() => meal = v!), decoration: InputDecoration(labelText: t("meal"))),
    ListTile(title: Text(time.format(context)), trailing: const Icon(Icons.access_time), onTap: () async { final nt = await showTimePicker(context: context, initialTime: time); if (nt != null) setD(() => time = nt); }),
  ]), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text(t("cancel"))),
    ElevatedButton(onPressed: () {
      final a = double.tryParse(amt.text.replaceAll(",", ".")) ?? 0;
      final at = DateTime(day.year, day.month, day.day, time.hour, time.minute).toIso8601String();
      if (existing != null) { existing["amount"] = a; existing["unit"] = unit; existing["meal"] = meal; existing["eatenAt"] = at; }
      else { store.entries.add({"id": newId(), "foodId": food["id"], "amount": a, "unit": unit, "meal": meal, "eatenAt": at}); }
      store.save(); refresh(); Navigator.pop(context);
    }, child: Text(t("save"))),
  ])));
}

Future<void> showFoodDialog(BuildContext context, Store store, VoidCallback refresh, String Function(String) t, {Map<String, dynamic>? existing}) async {
  final name = TextEditingController(text: existing?["name"]?.toString() ?? "");
  final brand = TextEditingController(text: existing?["brand"]?.toString() ?? "");
  final bc = TextEditingController(text: existing?["barcode"]?.toString() ?? "");
  final serving = TextEditingController(text: existing?["servingQty"]?.toString() ?? "100");
  final ctrls = <String, TextEditingController>{};
  final init = existing != null ? nutrientsFrom(existing["nutriments"]) : emptyNutrients();
  for (final k in nutrientKeys) ctrls[k] = TextEditingController(text: (init[k] ?? 0).toStringAsFixed(2));
  final labels = store.settings["lang"] == "de" ? nutrientLabelDe : nutrientLabelEn;
  await showDialog(context: context, builder: (_) => AlertDialog(title: Text(existing != null ? t("edit") : t("newFood")), content: SizedBox(width: 560, child: ListView(children: [
    TextField(controller: name, decoration: InputDecoration(labelText: t("name"))),
    TextField(controller: brand, decoration: InputDecoration(labelText: t("brand"))),
    TextField(controller: bc, decoration: InputDecoration(labelText: t("barcode"))),
    TextField(controller: serving, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t("servingQty"))),
    for (final k in nutrientKeys) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: TextField(controller: ctrls[k], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: "${labels[k]} (${nutrientUnit[k]})"))),
  ])), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text(t("cancel"))),
    ElevatedButton(onPressed: () {
      final nuts = {for (final k in nutrientKeys) k: double.tryParse(ctrls[k]!.text.replaceAll(",", ".")) ?? 0.0};
      final sq = double.tryParse(serving.text.replaceAll(",", ".")) ?? 100.0;
      if (existing != null) { existing["name"] = name.text; existing["brand"] = brand.text; existing["barcode"] = bc.text; existing["nutriments"] = nuts; existing["servingQty"] = sq; }
      else { store.foods.add({"id": newId(), "name": name.text, "brand": brand.text, "barcode": bc.text, "nutriments": nuts, "servingQty": sq, "servingUnit": "g", "isCustom": true, "favorite": false}); }
      store.save(); refresh(); Navigator.pop(context);
    }, child: Text(t("save"))),
  ]));
}

class CyclePage extends StatefulWidget {
  final Store store; final String Function(String) t; final DateTime selected; final void Function(DateTime) onDay; final VoidCallback refresh;
  const CyclePage({super.key, required this.store, required this.t, required this.selected, required this.onDay, required this.refresh});
  @override State<CyclePage> createState() => _CyclePageState();
}
class _CyclePageState extends State<CyclePage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  @override Widget build(BuildContext context) {
    final date = ymd(widget.selected);
    final fc = cycleForecast(widget.store.doc, date);
    final lang = widget.store.settings["lang"].toString();
    final expl = lang == "de" ? fc["explanation_de"] : fc["explanation_en"];
    final periods = (widget.store.doc["cycles"] as List).cast<Map<String, dynamic>>().toList()..sort((a, b) => b["start"].toString().compareTo(a["start"].toString()));
    final first = DateTime(month.year, month.month, 1);
    final daysIn = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final cells = <Widget>[];
    for (var i = 0; i < offset; i++) cells.add(const SizedBox());
    for (var d = 1; d <= daysIn; d++) {
      final dt = DateTime(month.year, month.month, d); final ds = ymd(dt);
      bool rec = false, pred = false;
      for (final p in widget.store.doc["cycles"] as List) { if (ds.compareTo(p["start"].toString()) >= 0 && ds.compareTo(p["end"].toString()) <= 0) rec = true; }
      final ps = fc["predictedStart"]?.toString(); final pe = fc["predictedEnd"]?.toString();
      if (ps != null && pe != null && ds.compareTo(ps) >= 0 && ds.compareTo(pe) <= 0) pred = true;
      cells.add(GestureDetector(onTap: () => widget.onDay(dt), child: Container(margin: const EdgeInsets.all(2), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: rec ? Colors.red.shade300 : (pred ? Colors.orange.shade200 : (ds == date ? Colors.blue.shade100 : null)), borderRadius: BorderRadius.circular(8)), child: Text("$d", textAlign: TextAlign.center))));
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(children: [IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => month = DateTime(month.year, month.month - 1, 1))), Expanded(child: Text("${month.year}-${month.month.toString().padLeft(2, "0")}", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)), IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => month = DateTime(month.year, month.month + 1, 1)))]),
      GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: cells),
      const SizedBox(height: 8),
      Text("${widget.t("forecast")} (${date}):", style: Theme.of(context).textTheme.titleMedium),
      Text("$expl", style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 8),
      ElevatedButton.icon(onPressed: () => showPeriodDialog(context, widget.store, widget.refresh, widget.t, day: widget.selected), icon: const Icon(Icons.add), label: Text(widget.t("add"))),
      Text(widget.t("historyList"), style: Theme.of(context).textTheme.titleMedium),
      for (final p in periods) ListTile(title: Text("${p["start"]} → ${p["end"]} · ${p["flow"]}"), subtitle: Text((p["note"] ?? "").toString()), trailing: PopupMenuButton(onSelected: (v) async {
        if (v == "edit") await showPeriodDialog(context, widget.store, widget.refresh, widget.t, existing: p);
        if (v == "del") { (widget.store.doc["cycles"] as List).removeWhere((x) => x["id"] == p["id"]); widget.store.save(); widget.refresh(); }
      }, itemBuilder: (_) => [PopupMenuItem(value: "edit", child: Text(widget.t("edit"))), PopupMenuItem(value: "del", child: Text(widget.t("delete")))])),
      const SizedBox(height: 8),
      Text(widget.t("symptoms"), style: Theme.of(context).textTheme.titleMedium),
      for (final s in (widget.store.doc["symptoms"] as List).cast<Map<String, dynamic>>().where((e) => (e["at"] as String).startsWith(date))) ListTile(title: Text("${s["name"]} ${s["intensity"]}/10"), subtitle: Text((s["note"] ?? "").toString()), trailing: PopupMenuButton(onSelected: (v) async {
        if (v == "edit") await showSymptomDialog(context, widget.store, widget.refresh, at: widget.selected, existing: s);
        if (v == "del") { (widget.store.doc["symptoms"] as List).removeWhere((x) => x["id"] == s["id"]); widget.store.save(); widget.refresh(); }
      }, itemBuilder: (_) => [PopupMenuItem(value: "edit", child: Text(widget.t("edit"))), PopupMenuItem(value: "del", child: Text(widget.t("delete")))])),
      ElevatedButton(onPressed: () => showSymptomDialog(context, widget.store, widget.refresh, at: widget.selected), child: Text("+ ${widget.t("symptoms")}")),
      const SizedBox(height: 16),
      Text(widget.t("weight"), style: Theme.of(context).textTheme.titleMedium),
      for (final w in (widget.store.doc["weight"] as List).cast<Map<String, dynamic>>().where((e) => e["date"] == date)) ListTile(title: Text("${w["kg"]} kg"), trailing: PopupMenuButton(onSelected: (v) async {
        if (v == "edit") await showWeightDialog(context, widget.store, widget.refresh, date: date, existing: w);
        if (v == "del") { (widget.store.doc["weight"] as List).removeWhere((x) => x["id"] == w["id"]); widget.store.save(); widget.refresh(); }
      }, itemBuilder: (_) => [PopupMenuItem(value: "edit", child: Text(widget.t("edit"))), PopupMenuItem(value: "del", child: Text(widget.t("delete")))])),
      ElevatedButton(onPressed: () => showWeightDialog(context, widget.store, widget.refresh, date: date), child: Text("+ ${widget.t("weight")}")),
    ]);
  }
}

Future<void> showPeriodDialog(BuildContext context, Store store, VoidCallback refresh, String Function(String) t, {Map<String, dynamic>? existing, DateTime? day}) async {
  DateTime start = existing != null ? DateTime.parse(existing["start"].toString()) : (day ?? DateTime.now());
  DateTime end = existing != null ? DateTime.parse(existing["end"].toString()) : start;
  String flow = existing?["flow"]?.toString() ?? "medium";
  final note = TextEditingController(text: existing?["note"]?.toString() ?? "");
  final flows = ["spotting", "light", "medium", "heavy"];
  await showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(title: Text(t("cycle")), content: Column(mainAxisSize: MainAxisSize.min, children: [
    ListTile(title: Text("${t("start")}: ${ymd(start)}"), trailing: const Icon(Icons.edit_calendar), onTap: () async { final d = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setD(() { start = d; if (end.isBefore(start)) end = start; }); }),
    ListTile(title: Text("${t("end")}: ${ymd(end)}"), trailing: const Icon(Icons.edit_calendar), onTap: () async { final d = await showDatePicker(context: context, initialDate: end, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setD(() => end = d); }),
    DropdownButtonFormField<String>(value: flow, items: [for (final f in flows) DropdownMenuItem(value: f, child: Text(t(f)))], onChanged: (v) => setD(() => flow = v!), decoration: InputDecoration(labelText: t("flow"))),
    TextField(controller: note, decoration: InputDecoration(labelText: t("note"))),
  ]), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: Text(t("cancel"))),
    ElevatedButton(onPressed: () {
      if (existing != null) { existing["start"] = ymd(start); existing["end"] = ymd(end); existing["flow"] = flow; existing["note"] = note.text; }
      else { store.doc["cycles"].add({"id": newId(), "start": ymd(start), "end": ymd(end), "flow": flow, "note": note.text}); }
      store.save(); refresh(); Navigator.pop(context);
    }, child: Text(t("save"))),
  ])));
}

Future<void> showWeightDialog(BuildContext context, Store store, VoidCallback refresh, {String? date, Map<String, dynamic>? existing}) async {
  final c = TextEditingController(text: existing?["kg"]?.toString() ?? "");
  final d = date ?? existing?["date"]?.toString() ?? ymd(DateTime.now());
  final unit = store.settings["weightUnit"]?.toString() ?? "kg";
  await showDialog(context: context, builder: (_) => AlertDialog(title: Text("Weight $d"), content: TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: "Weight ($unit)")), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
    ElevatedButton(onPressed: () {
      var v = double.tryParse(c.text.replaceAll(",", ".")) ?? 0;
      if (unit == "lb") v = v / 2.20462;
      if (existing != null) { existing["kg"] = v; existing["date"] = d; }
      else { store.doc["weight"].add({"id": newId(), "date": d, "kg": v}); }
      store.save(); refresh(); Navigator.pop(context);
    }, child: const Text("Save")),
  ]));
}

Future<void> showSymptomDialog(BuildContext context, Store store, VoidCallback refresh, {DateTime? at, Map<String, dynamic>? existing}) async {
  final name = TextEditingController(text: existing?["name"]?.toString() ?? "");
  final note = TextEditingController(text: existing?["note"]?.toString() ?? "");
  final dt = at ?? (existing != null ? DateTime.parse(existing["at"].toString()) : DateTime.now());
  double intensity = existing?["intensity"]?.toDouble() ?? 3;
  await showDialog(context: context, builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(title: const Text("Symptom"), content: Column(mainAxisSize: MainAxisSize.min, children: [
    TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
    Slider(value: intensity, min: 0, max: 10, divisions: 10, label: "${intensity.toStringAsFixed(0)}/10", onChanged: (v) => setD(() => intensity = v)),
    TextField(controller: note, decoration: const InputDecoration(labelText: "Note")),
  ]), actions: [
    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
    ElevatedButton(onPressed: () {
      final obj = {"name": name.text, "intensity": intensity.round(), "at": dt.toIso8601String(), "note": note.text};
      if (existing != null) { existing.addAll(obj); }
      else { store.doc["symptoms"].add({"id": newId(), ...obj}); }
      store.save(); refresh(); Navigator.pop(context);
    }, child: const Text("Save")),
  ])));
}

class HistoryPage extends StatefulWidget {
  final Store store; final String Function(String) t; final VoidCallback refresh;
  const HistoryPage({super.key, required this.store, required this.t, required this.refresh});
  @override State<HistoryPage> createState() => _HistoryPageState();
}
class _HistoryPageState extends State<HistoryPage> {
  String? from, to, module; final q = TextEditingController();
  @override Widget build(BuildContext context) {
    final res = searchHistory(widget.store.doc, from: from, to: to, module: module, q: q.text);
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text(widget.t("searchHistory"), style: Theme.of(context).textTheme.titleLarge),
      TextField(controller: q, decoration: InputDecoration(labelText: widget.t("query")), onChanged: (_) => setState(() {})),
      DropdownButtonFormField<String>(value: module, hint: Text(widget.t("filterModule")), items: [const DropdownMenuItem(value: null, child: Text("All")), for (final m in ["nutrition", "cycle", "weight", "symptoms", "water"]) DropdownMenuItem(value: m, child: Text(m))], onChanged: (v) => setState(() => module = v)),
      Row(children: [
        Expanded(child: ElevatedButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now().subtract(const Duration(days: 365)), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => from = ymd(d)); }, child: Text("${widget.t("from")}: ${from ?? "—"}"))),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(onPressed: () async { final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setState(() => to = ymd(d)); }, child: Text("${widget.t("to")}: ${to ?? "—"}"))),
      ]),
      Text("${res.length} / 10000+", style: Theme.of(context).textTheme.labelSmall),
      for (final h in res.take(500)) ListTile(title: Text(h["title"].toString()), subtitle: Text("${h["module"]} · ${h["date"]}"), trailing: const Icon(Icons.edit), onTap: () => _open(h)),
    ]);
  }
  void _open(Map<String, dynamic> h) {
    final d = h["detail"] as Map<String, dynamic>;
    switch (h["module"]) {
      case "weight": showWeightDialog(context, widget.store, widget.refresh, date: d["date"].toString(), existing: d); break;
      case "cycle": showPeriodDialog(context, widget.store, widget.refresh, widget.t, existing: d); break;
      case "symptoms": showSymptomDialog(context, widget.store, widget.refresh, at: DateTime.parse(d["at"].toString()), existing: d); break;
      case "nutrition": {
        final foods = widget.store.foods;
        showLogDialog(context, widget.store, widget.refresh, foods.where((f) => f["id"] == d["foodId"]).firstOrNull ?? <String, dynamic>{}, DateTime.parse(d["eatenAt"].toString()), widget.t, existing: d);
        break;
      }
    }
  }
}

class SettingsPage extends StatefulWidget {
  final Store store; final String Function(String) t; final VoidCallback refresh;
  const SettingsPage({super.key, required this.store, required this.t, required this.refresh});
  @override State<SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController baseC, uaC;
  final goals = <String, TextEditingController>{};
  @override void initState() {
    super.initState();
    baseC = TextEditingController(text: widget.store.settings["foodBaseUrl"]?.toString() ?? "https://world.openfoodfacts.org");
    uaC = TextEditingController(text: widget.store.settings["foodUserAgent"]?.toString() ?? "MorphHealth/1.0");
    final g = widget.store.settings["goals"] as Map;
    for (final k in ["waterMl", "kcal", "protein", "carbs", "fat"]) goals[k] = TextEditingController(text: (g[k] ?? 0).toString());
  }
  @override Widget build(BuildContext context) {
    final lang = widget.store.settings["lang"].toString();
    final visible = ((widget.store.settings["visibleModules"] as List?) ?? []).cast<String>().toSet();
    return ListView(padding: const EdgeInsets.all(12), children: [
      DropdownButtonFormField<String>(value: lang, items: const [DropdownMenuItem(value: "de", child: Text("Deutsch")), DropdownMenuItem(value: "en", child: Text("English"))], decoration: InputDecoration(labelText: widget.t("language")), onChanged: (v) { widget.store.settings["lang"] = v; widget.store.save(); widget.refresh(); }),
      DropdownButtonFormField<String>(value: widget.store.settings["weightUnit"]?.toString() ?? "kg", items: const [DropdownMenuItem(value: "kg", child: Text("kg")), DropdownMenuItem(value: "lb", child: Text("lb"))], decoration: InputDecoration(labelText: widget.t("weightUnit")), onChanged: (v) { widget.store.settings["weightUnit"] = v; widget.store.save(); widget.refresh(); }),
      Text(widget.t("visibleModules"), style: Theme.of(context).textTheme.titleMedium),
      for (final m in ["nutrition", "cycle", "weight", "symptoms"]) CheckboxListTile(value: visible.contains(m), title: Text(widget.t(m)), onChanged: (v) { if (v == true) visible.add(m); else visible.remove(m); widget.store.settings["visibleModules"] = visible.toList(); widget.store.save(); widget.refresh(); }),
      Text(widget.t("goals"), style: Theme.of(context).textTheme.titleMedium),
      TextField(controller: goals["waterMl"], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: widget.t("waterGoal"))),
      TextField(controller: goals["kcal"], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: widget.t("kcalGoal"))),
      TextField(controller: goals["protein"], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: widget.t("proteinGoal"))),
      TextField(controller: goals["carbs"], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: widget.t("carbsGoal"))),
      TextField(controller: goals["fat"], keyboardType: TextInputType.number, decoration: InputDecoration(labelText: widget.t("fatGoal"))),
      TextField(controller: baseC, decoration: InputDecoration(labelText: widget.t("foodBase"))),
      TextField(controller: uaC, decoration: InputDecoration(labelText: widget.t("foodUA"))),
      ElevatedButton(onPressed: () {
        widget.store.settings["foodBaseUrl"] = baseC.text.trim(); widget.store.settings["foodUserAgent"] = uaC.text.trim();
        (widget.store.settings["goals"] as Map).update("waterMl", (_) => double.tryParse(goals["waterMl"]!.text) ?? 1500);
        (widget.store.settings["goals"] as Map).update("kcal", (_) => double.tryParse(goals["kcal"]!.text) ?? 2000);
        (widget.store.settings["goals"] as Map).update("protein", (_) => double.tryParse(goals["protein"]!.text) ?? 60);
        (widget.store.settings["goals"] as Map).update("carbs", (_) => double.tryParse(goals["carbs"]!.text) ?? 250);
        (widget.store.settings["goals"] as Map).update("fat", (_) => double.tryParse(goals["fat"]!.text) ?? 70);
        widget.store.save(); widget.refresh(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.t("settingsSaved"))));
      }, child: Text(widget.t("save"))),
      const Divider(),
      ListTile(title: Text(widget.t("exportData")), leading: const Icon(Icons.download), onTap: () async {
        final s = jsonEncode(widget.store.exportDoc());
        try { await Share.shareXFiles([XFile.fromData(Uint8List.fromList(utf8.encode(s)), name: "morphhealth-export.json", mimeType: "application/json")]); } catch (_) {}
      }),
      ListTile(title: Text(widget.t("importData")), leading: const Icon(Icons.upload), onTap: () async {
        final r = await FilePicker.platform.pickFiles();
        if (r != null && r.files.single.bytes != null) {
          final doc = jsonDecode(utf8.decode(r.files.single.bytes!));
          final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(widget.t("importData")), content: Text(widget.t("confirmImport")), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(widget.t("cancel"))), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.t("save")))]));
          if (ok == true) { widget.store.importDoc(doc); widget.refresh(); }
        }
      }),
      ListTile(title: Text(widget.t("backup")), leading: const Icon(Icons.lock), onTap: () async {
        final pw = TextEditingController();
        final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(widget.t("backup")), content: TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: widget.t("passphrase"))), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(widget.t("cancel"))), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.t("save")))]));
        if (ok == true && pw.text.isNotEmpty) {
          final enc = CryptoBox.encryptPassphrase(pw.text, jsonEncode(widget.store.exportDoc()));
          final s = jsonEncode(enc);
          try { await Share.shareXFiles([XFile.fromData(Uint8List.fromList(utf8.encode(s)), name: "morphhealth-backup.json", mimeType: "application/json")]); } catch (_) {}
        }
      }),
      ListTile(title: Text(widget.t("restore")), leading: const Icon(Icons.lock_open), onTap: () async {
        final r = await FilePicker.platform.pickFiles();
        if (r == null || r.files.single.bytes == null) return;
        final docEnc = jsonDecode(utf8.decode(r.files.single.bytes!)) as Map<String, dynamic>;
        final pw = TextEditingController();
        final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(widget.t("restore")), content: TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: widget.t("passphrase"))), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(widget.t("cancel"))), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.t("save")))]));
        if (ok == true) {
          try { final plain = CryptoBox.decryptPassphrase(pw.text, docEnc); widget.store.importDoc(jsonDecode(plain)); widget.refresh(); }
          catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
        }
      }),
      ListTile(title: Text(widget.t("wipe")), leading: const Icon(Icons.delete_forever), textColor: Colors.red, onTap: () async {
        final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text(widget.t("wipe")), content: Text(widget.t("confirmWipe")), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(widget.t("cancel"))), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(widget.t("delete")))]));
        if (ok == true) { widget.store.wipe(); widget.refresh(); }
      }),
    ]);
  }
}

Future<void> showCharts(BuildContext context, Store store, String Function(String) t, String endDate) async {
  await showDialog(context: context, builder: (_) => Dialog(child: SizedBox(width: 640, child: ChartsBody(store: store, t: t, endDate: endDate))));
}
class ChartsBody extends StatefulWidget {
  final Store store; final String Function(String) t; final String endDate;
  const ChartsBody({super.key, required this.store, required this.t, required this.endDate});
  @override State<ChartsBody> createState() => _ChartsBodyState();
}
class _ChartsBodyState extends State<ChartsBody> {
  int days = 7; String metric = "kcal";
  @override Widget build(BuildContext context) {
    final series = seriesDays(widget.store.doc, widget.endDate, days);
    final vals = series.map((e) {
      if (metric == "kcal") return ((e["kcal"] as num?) ?? 0).toDouble();
      if (metric == "protein") return ((e["protein"] as num?) ?? 0).toDouble();
      if (metric == "water") return ((e["waterMl"] as num?) ?? 0).toDouble();
      if (metric == "weight") return ((e["weightKg"] as num?) ?? 0).toDouble();
      return 0.0;
    }).toList();
    return ListView(padding: const EdgeInsets.all(12), shrinkWrap: true, children: [
      Row(children: [
        TextButton(onPressed: () => setState(() => days = 7), child: Text(widget.t("last7"))),
        TextButton(onPressed: () => setState(() => days = 28), child: Text(widget.t("last28"))),
        Expanded(child: DropdownButtonFormField<String>(value: metric, items: const [DropdownMenuItem(value: "kcal", child: Text("kcal")), DropdownMenuItem(value: "protein", child: Text("Protein")), DropdownMenuItem(value: "water", child: Text("Wasser")), DropdownMenuItem(value: "weight", child: Text("Gewicht"))], onChanged: (v) => setState(() => metric = v!))),
      ]),
      SizedBox(height: 180, child: CustomPaint(painter: _BarPainter(vals, series.map((e) => e["date"].toString()).toList()))),
      for (var i = 0; i < series.length; i++) Text("${series[i]["date"]}: ${vals[i].toStringAsFixed(1)}"),
    ]);
  }
}
class _BarPainter extends CustomPainter {
  final List<double> vals; final List<String> labels;
  _BarPainter(this.vals, this.labels);
  @override void paint(Canvas canvas, Size size) {
    if (vals.isEmpty) return;
    final maxV = vals.reduce(math.max);
    final w = size.width / vals.length;
    final paint = Paint()..color = Colors.teal;
    final paint2 = Paint()..color = Colors.grey;
    for (var i = 0; i < vals.length; i++) {
      final h = maxV == 0 ? 0.0 : (vals[i] / maxV) * (size.height - 20);
      canvas.drawRect(Rect.fromLTWH(i * w + 2, size.height - h - 12, w - 4, h), paint);
      canvas.drawRect(Rect.fromLTWH(i * w + 2, size.height - 8, w - 4, 2), paint2);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
