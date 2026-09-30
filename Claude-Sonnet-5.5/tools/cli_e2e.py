#!/usr/bin/env python3
"""End-to-End-Prüfung des Wartungszugangs ./mh gegen das echte Programm.

Startet ./mh als eigenen Prozess, spricht JSON Lines und prüft Protokoll,
Rechenergebnisse, Verschlüsselung der Ablage, Persistenz, Schlüsselbehandlung,
Fehlerfälle und das Verhalten mit vielen Einträgen. Die Lebensmittelabfragen
laufen gegen den in ENVIRONMENT.json genannten Endpunkt, wenn er erreichbar ist.

Aufruf: tools/cli_e2e.py [--mh PFAD] [--keep]
Nur Standardbibliothek. Temporäre Daten liegen unter <Projekt>/.check-tmp.
"""
import argparse
import copy
import json
import os
import random
import shutil
import socket
import subprocess
import sys
import time
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TMP = os.path.join(ROOT, ".check-tmp", "cli")
NOW = "2026-09-29T10:00:00+02:00"

results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    print(("  ok   " if ok else "  FAIL ") + name + (f"  [{detail}]" if detail and not ok else ""))
    return ok


class Mh:
    """Ein ./mh-Prozess; Anfragen werden der Reihe nach beantwortet."""

    def __init__(self, mh, data_dir, key_file, now=NOW, extra=()):
        cmd = [mh, "--data-dir", data_dir, "--key-file", key_file]
        if now:
            cmd += ["--now", now]
        cmd += list(extra)
        self.proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
        self.next_id = 0

    def call(self, op, **fields):
        self.next_id += 1
        req = {"request_id": self.next_id, "op": op, **fields}
        self.proc.stdin.write(json.dumps(req, ensure_ascii=False) + "\n")
        self.proc.stdin.flush()
        line = self.proc.stdout.readline()
        if not line:
            raise RuntimeError("keine Antwort; stderr: " + self.proc.stderr.read())
        resp = json.loads(line)
        assert resp["request_id"] == self.next_id, resp
        return resp

    def raw(self, text):
        self.proc.stdin.write(text + "\n")
        self.proc.stdin.flush()
        return json.loads(self.proc.stdout.readline())

    def close(self):
        try:
            self.proc.stdin.close()
            self.proc.wait(timeout=30)
        except Exception:
            self.proc.kill()
        err = self.proc.stderr.read()
        rest = self.proc.stdout.read()
        return self.proc.returncode, rest, err


def session(mh, data_dir, key_file, requests, **kw):
    p = Mh(mh, data_dir, key_file, **kw)
    out = [p.call(op, **f) for op, f in requests]
    rc, rest, err = p.close()
    return out, rc, rest, err


def reachable(base_url):
    try:
        u = urllib.parse.urlparse(base_url)
        with socket.create_connection((u.hostname, u.port or 443), timeout=2):
            return True
    except OSError:
        return False


def strip_time(doc):
    d = copy.deepcopy(doc)
    d.pop("exported_at", None)
    return d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mh", default=os.path.join(ROOT, "mh"))
    ap.add_argument("--keep", action="store_true")
    args = ap.parse_args()
    mh = args.mh

    shutil.rmtree(TMP, ignore_errors=True)
    os.makedirs(TMP)
    key = os.path.join(TMP, "key.bin")
    with open(key, "wb") as f:
        f.write(os.urandom(32))
    data = os.path.join(TMP, "data")

    env = {}
    try:
        with open(os.path.join(ROOT, "ENVIRONMENT.json"), encoding="utf-8") as f:
            env = json.load(f)
    except OSError:
        pass

    print("== Protokoll und describe")
    p = Mh(mh, data, key)
    r = p.call("describe")
    check("describe: ok mit data", r["ok"] and isinstance(r["data"], dict))
    d = r["data"]
    check("describe: enthält Operationen, Formate und Beispieldokument",
          all(k in d for k in ("operations", "formats", "example_import_document", "protocol", "cli")))
    ops = d["operations"]
    for op in ("describe", "portable.export", "portable.import", "nutrition.day", "cycle.forecast", "food.search", "food.lookup"):
        check(f"describe: Operation {op} beschrieben", op in ops)
    example = d["example_import_document"]
    check("describe: 31 Nährstoffe dokumentiert", len(d["formats"]["nutrients"]) == 31)

    r = p.call("gibt.es.nicht")
    check("unbekannte Operation: ok=false, unknown_op", not r["ok"] and r["error"]["code"] == "unknown_op")
    r = p.raw("das ist kein json")
    check("ungültiges JSON: ok=false, invalid_json, request_id null", not r["ok"] and r["error"]["code"] == "invalid_json" and r["request_id"] is None)
    r = p.raw(json.dumps({"request_id": "abc", "op": "nutrition.day", "date": "2026-13-45"}))
    check("ungültiges Datum: invalid_argument, request_id als Text zurück", r["request_id"] == "abc" and r["error"]["code"] == "invalid_argument")
    r = p.raw(json.dumps({"request_id": {"a": [1, 2]}, "op": "describe"}))
    check("request_id beliebiger JSON-Wert wird unverändert zurückgegeben", r["request_id"] == {"a": [1, 2]} and r["ok"])
    r = p.raw(json.dumps([1, 2, 3]))
    check("Anfrage ohne Objekt: invalid_request", not r["ok"] and r["error"]["code"] == "invalid_request")

    print("== Export und Import verlangen Bestätigung")
    r = p.call("portable.export")
    check("Export ohne ack_plaintext abgelehnt", not r["ok"] and r["error"]["code"] == "ack_required")
    r = p.call("portable.import", document=example)
    check("Import ohne confirm_replace abgelehnt", not r["ok"] and r["error"]["code"] == "confirm_required")

    print("== Beispieldokument importieren und rechnen")
    r = p.call("portable.import", document=example, confirm_replace=True)
    check("Import des Beispieldokuments ok", r["ok"] and r["data"]["total_records"] == 16 and r["data"]["warning_count"] == 0, json.dumps(r)[:200])
    r = p.call("nutrition.day", date="2026-09-28")
    day = r["data"]
    # Haferflocken 60 g + 2 Portionen (80 g) + Cola 330 ml (1 ml = 1 g nicht nötig: Basis ml)
    check("nutrition.day: Energie 521,79 kcal", abs(day["totals"]["energy_kcal"] - 521.79) < 1e-6, str(day["totals"]["energy_kcal"]))
    check("nutrition.day: Eiweiß 18,9 g", abs(day["totals"]["protein_g"] - 18.9) < 1e-6)
    check("nutrition.day: Koffein 113 mg (33 aus Lebensmitteln + 80 zusätzlich)", abs(day["caffeine"]["total_mg"] - 113) < 1e-6 and abs(day["totals"]["caffeine_mg"] - 113) < 1e-6)
    check("nutrition.day: Wasser 750 ml", day["water_ml"] == 750)
    check("nutrition.day: Mikronährstoffe summiert (Vitamin B1, Eisen, Magnesium)",
          abs(day["totals"]["vitamin_b1_mg"] - 0.826) < 1e-6 and abs(day["totals"]["iron_mg"] - 6.44) < 1e-6 and abs(day["totals"]["magnesium_mg"] - 104) < 1e-6)
    check("nutrition.day: Abdeckung je Nährstoff (Eisen in 2 von 3 Einträgen)", day["entries_with_data"]["iron_mg"] == 2 and day["entries_with_data"]["energy_kcal"] == 3)
    check("nutrition.day: vier Mahlzeiten", [m["meal"] for m in day["meals"]] == ["breakfast", "lunch", "dinner", "snack"])
    check("nutrition.day: Ziele und Fortschritt", day["goal_progress"]["energy_kcal"]["goal"] == 2200 and day["goal_progress"]["water_ml"]["percent"] == 37.5)
    r0 = p.call("nutrition.day", date="2026-01-01")
    check("nutrition.day: leerer Tag liefert Nullen statt Fehler", r0["ok"] and r0["data"]["entry_count"] == 0 and r0["data"]["totals"]["energy_kcal"] == 0)
    exp = d["example_results"]["nutrition.day 2026-09-28"]
    check("nutrition.day entspricht dem Beispielergebnis aus describe", day["totals"] == exp["totals"])

    print("== Zyklusprognose")
    f = p.call("cycle.forecast", on="2026-09-20")["data"]
    check("Prognose: vorhergesagter Beginn 2026-09-28 (4 x 28 Tage)", f["status"] == "predicted" and f["predicted_start"] == "2026-09-28" and f["days_until_predicted"] == 8, json.dumps(f)[:200])
    check("Prognose: verwendete Abstände 28, 28, 28", f["cycle_lengths_used"] == [28, 28, 28] and f["average_cycle_length_days"] == 28.0)
    check("Prognose: Erklärung in Deutsch und Englisch", len(f["explanation"]["de"]) >= 4 and len(f["explanation"]["en"]) >= 4)
    f2 = p.call("cycle.forecast", on="2026-10-05")["data"]
    check("Prognose: überfällig nach dem berechneten Beginn", f2["status"] == "overdue" and f2["days_overdue"] == 7)
    f3 = p.call("cycle.forecast", on="2026-09-02")["data"]
    check("Prognose: läuft die Periode, ist sie 'in_period' mit Periodentag", f3["status"] == "in_period" and f3["period_day"] == 3)
    f4 = p.call("cycle.forecast", on="2026-07-20")["data"]
    check("Prognose: Stand des Betrachtungstags (nur frühere Perioden zählen)", f4["last_period_start"] == "2026-07-06" and f4["cycle_lengths_used"] == [28])
    f5 = p.call("cycle.forecast", on="2027-03-01")["data"]
    check("Prognose: sehr lange nach der letzten Periode 'stale' ohne Datum", f5["status"] == "stale" and f5["predicted_start"] is None)
    f6 = p.call("cycle.forecast", on="2026-06-01")["data"]
    check("Prognose: vor der ersten Periode 'no_data'", f6["status"] == "no_data")

    print("== Export, Rundreise und Persistenz")
    exp1 = p.call("portable.export", ack_plaintext=True)["data"]
    check("Export: Format, Version, Abschnitte", exp1["format"] == "morphhealth-portable" and exp1["version"] == 1 and len(exp1["food_entries"]) == 3 and len(exp1["periods"]) == 4)
    rc, rest, err = p.close()
    check("stdout enthält nur Antwortzeilen (nichts nach dem Ende)", rest == "" and rc == 0, f"rc={rc} rest={rest[:80]!r} err={err[:120]!r}")

    (o,), rc, _, _ = session(mh, data, key, [("nutrition.day", {"date": "2026-09-28"})])
    check("Persistenz: neuer Prozess liest dieselben Daten", o["ok"] and abs(o["data"]["totals"]["energy_kcal"] - 521.79) < 1e-6)

    data2 = os.path.join(TMP, "data2")
    (imp, exp2), _, _, _ = session(mh, data2, key, [("portable.import", {"document": exp1, "confirm_replace": True}), ("portable.export", {"ack_plaintext": True})])
    check("Rundreise: Export -> Import -> Export ist gleichwertig", imp["ok"] and strip_time(exp2["data"]) == strip_time(exp1))
    check("Export enthält exported_at gemäß --now", exp1["exported_at"].startswith("2026-09-29T10:00:00"), exp1["exported_at"])

    print("== Offene Periode (ohne Ende) bleibt über Neustarts lesbar")
    data_open = os.path.join(TMP, "data-open")
    open_doc = {"format": "morphhealth-portable", "version": 1, "periods": [{"id": "open1", "start": "2026-09-29", "flow": "medium"}]}
    (imp,), _, _, _ = session(mh, data_open, key, [("portable.import", {"document": open_doc, "confirm_replace": True})])
    check("Offene Periode wird importiert", imp["ok"], json.dumps(imp)[:200])
    (fc_open, ex_open), rc, _, err = session(mh, data_open, key, [("cycle.forecast", {"on": "2026-09-29"}), ("portable.export", {"ack_plaintext": True})])
    check("Neuer Prozess liest die offene Periode: sie läuft (Tag 1)", fc_open["ok"] and fc_open["data"]["status"] == "in_period" and fc_open["data"]["period_day"] == 1, json.dumps(fc_open)[:200] + err[:200])
    check("Export enthält die offene Periode mit end null", ex_open["ok"] and ex_open["data"]["periods"][0]["end"] is None)

    print("== Ungültige Dokumente")
    bad = copy.deepcopy(example)
    bad["food_entries"][0]["amount"] = -5
    bad["symptom_entries"][0]["intensity"] = 11
    bad["periods"][0]["end"] = "2026-06-01"
    (rb, after), _, _, _ = session(mh, data, key, [("portable.import", {"document": bad, "confirm_replace": True}), ("nutrition.day", {"date": "2026-09-28"})])
    paths = [i["path"] for i in rb["error"].get("details", [])] if not rb["ok"] else []
    check("Ungültiges Dokument: invalid_document mit Pfaden", not rb["ok"] and rb["error"]["code"] == "invalid_document" and "$.food_entries[0].amount" in paths and "$.symptom_entries[0].intensity" in paths and "$.periods[0].end" in paths, json.dumps(rb)[:300])
    check("Ungültiges Dokument: Bestand bleibt unverändert", after["data"]["entry_count"] == 3)

    print("== Verschlüsselung und Schlüssel")
    leaks = []
    secrets = ["Haferflocken", "Kopfschmerz", "Müdigkeit", "Krämpfe", "Beispielmarke", "food_entries", "2026-09-28", "72.4"]
    for name in sorted(os.listdir(data)):
        blob = open(os.path.join(data, name), "rb").read()
        for s in secrets:
            if s.encode("utf-8") in blob:
                leaks.append((name, s))
    check("Ablage: kein Klartext in den Dateien des Datenverzeichnisses", not leaks, str(leaks))
    check("Ablage: nur erwartete Dateien", sorted(os.listdir(data)) == ["store.lock", "store.mhj", "store.mhs"], str(os.listdir(data)))
    wrong = os.path.join(TMP, "wrong.key")
    with open(wrong, "wb") as f:
        f.write(os.urandom(32))
    (w,), _, _, err = session(mh, data, wrong, [("nutrition.day", {"date": "2026-09-28"})])
    check("Falscher Schlüssel: Fehler wrong_key statt Daten", not w["ok"] and w["error"]["code"] == "wrong_key")
    p = Mh(mh, data, wrong)
    check("Falscher Schlüssel: describe funktioniert weiter", p.call("describe")["ok"])
    p.close()
    short = os.path.join(TMP, "short.key")
    with open(short, "wb") as f:
        f.write(b"zu kurz")
    (s,), _, _, _ = session(mh, data, short, [("nutrition.day", {"date": "2026-09-28"})])
    check("Schlüsseldatei mit falscher Länge wird abgelehnt", not s["ok"] and s["error"]["code"] == "wrong_key")
    (m,), _, _, _ = session(mh, data, os.path.join(TMP, "gibt-es-nicht.key"), [("nutrition.day", {"date": "2026-09-28"})])
    check("Fehlende Schlüsseldatei: Fehler mit Grund", not m["ok"])
    # Manipulation im Journal-Ende (abgerissener Schreibvorgang) wird verkraftet, Mitte nicht.
    (o2,), _, _, _ = session(mh, data, key, [("nutrition.day", {"date": "2026-09-28"})])
    check("Daten nach den Fehlversuchen weiterhin lesbar", o2["ok"] and o2["data"]["entry_count"] == 3)

    print("== Uhr (--now)")
    (a, b), _, _, _ = session(mh, data, key, [("portable.export", {"ack_plaintext": True}), ("cycle.forecast", {"on": "2026-09-29"})], now="2031-01-02T03:04:05Z")
    check("--now bestimmt exported_at (umgerechnet in Ortszeit des Prozesses)", a["data"]["exported_at"][:4] == "2031")

    print("== Viele Einträge (10.000 Verzehreinträge)")
    rnd = random.Random(7)
    foods = [{"id": f"f{i}", "name": f"Testlebensmittel {i}", "basis": "g", "serving": {"amount": 30 + i % 70},
              "nutrients": {"energy_kcal": round(rnd.uniform(20, 600), 1), "protein_g": round(rnd.uniform(0, 30), 1),
                            "carbohydrates_g": round(rnd.uniform(0, 80), 1), "fat_g": round(rnd.uniform(0, 40), 1)}} for i in range(300)]
    entries, water, weights, symptoms = [], [], [], []
    import datetime
    start = datetime.date(2022, 1, 1)
    n, day_i = 0, 0
    while n < 10000:
        dte = start + datetime.timedelta(days=day_i)
        for meal, hour in zip(("breakfast", "lunch", "dinner", "snack"), (8, 12, 19, 15)):
            for k in range(rnd.choice((1, 2, 3))):
                fid = rnd.choice(foods)["id"]
                entries.append({"id": f"e{n}", "at": f"{dte}T{hour:02d}:{k * 7:02d}:00", "meal": meal, "amount": rnd.choice((30, 50, 100, 150, 250)), "unit": "g", "food_id": fid})
                n += 1
        water.append({"id": f"w{day_i}", "at": f"{dte}T09:00:00", "ml": 250})
        if day_i % 2 == 0:
            weights.append({"id": f"g{day_i}", "at": f"{dte}T07:00:00", "kg": round(72 + rnd.uniform(-2, 2), 1)})
        if day_i % 4 == 0:
            symptoms.append({"id": f"s{day_i}", "name": rnd.choice(("Kopfschmerz", "Müdigkeit")), "intensity": rnd.randint(0, 10), "at": f"{dte}T18:00:00"})
        day_i += 1
    big = {"format": "morphhealth-portable", "version": 1, "foods": foods, "food_entries": entries, "water_entries": water, "weight_entries": weights, "symptom_entries": symptoms}
    data3 = os.path.join(TMP, "data3")
    t = time.time()
    (imp,), _, _, _ = session(mh, data3, key, [("portable.import", {"document": big, "confirm_replace": True})])
    t_import = time.time() - t
    check(f"10.000 Einträge: Import in {t_import:.1f} s", imp["ok"] and imp["data"]["imported"]["food_entries"] == len(entries) >= 10000 and t_import < 20, json.dumps(imp)[:200])
    t = time.time()
    (q,), _, _, _ = session(mh, data3, key, [("nutrition.day", {"date": "2023-05-05"})])
    t_open = time.time() - t
    check(f"10.000 Einträge: Prozessstart und Tagesabfrage in {t_open:.2f} s", q["ok"] and t_open < 5)
    p = Mh(mh, data3, key)
    t = time.time()
    for k in range(200):
        p.call("nutrition.day", date=str(start + datetime.timedelta(days=k * 3)))
    per = (time.time() - t) / 200 * 1000
    check(f"10.000 Einträge: 200 Tagesabfragen im Mittel {per:.1f} ms", per < 100)
    t = time.time()
    p.call("cycle.forecast", on="2026-09-29")
    p.close()
    snap = os.path.getsize(os.path.join(data3, "store.mhs"))
    check(f"10.000 Einträge: verschlüsselte Ablage {snap // 1024} KiB", snap < 8 * 1024 * 1024)

    print("== Lebensmitteldienst")
    base = env.get("food_api_base_url", "")
    ua = env.get("food_api_user_agent", "")
    p = Mh(mh, os.path.join(TMP, "data4"), key, extra=["--food-base-url", "http://unsicher.example"])
    r = p.call("food.search", q="milch", page=1)
    check("http:// als Ursprung wird abgelehnt (invalid_base_url)", not r["ok"] and r["error"]["code"] == "invalid_base_url")
    r = p.call("food.lookup", barcode="12")
    check("Barcode mit falscher Länge: invalid_barcode", not r["ok"] and r["error"]["code"] in ("invalid_barcode", "invalid_base_url"))
    p.close()
    p = Mh(mh, os.path.join(TMP, "data4"), key, extra=["--food-base-url", "https://127.0.0.1:1"])
    r = p.call("food.search", q="milch", page=1)
    check("Nicht erreichbarer Dienst: Fehlercode offline", not r["ok"] and r["error"]["code"] in ("offline", "timeout", "tls"), json.dumps(r)[:200])
    p.close()
    if base and reachable(base):
        extra = ["--food-base-url", base] + (["--food-user-agent", ua] if ua else [])
        p = Mh(mh, os.path.join(TMP, "data4"), key, extra=extra)
        r = p.call("food.search", q="haferflocken", page=1)
        ok = r["ok"] and r["data"]["page"] == 1 and r["data"]["page_size"] == 20 and len(r["data"]["results"]) > 0 and r["data"]["total"] > 20
        check("food.search: echte Treffer über HTTPS", ok, json.dumps(r)[:200])
        first = r["data"]["results"][0] if ok else {}
        check("food.search: Ergebnis enthält Name, Barcode und Nährwerte je 100 g/ml", bool(first.get("name")) and bool(first.get("barcode")) and "energy_kcal" in first.get("nutrients", {}))
        r2 = p.call("food.search", q="haferflocken", page=2)
        check("food.search: Seite 2 liefert andere Treffer", r2["ok"] and r2["data"]["results"][0]["barcode"] != first.get("barcode"))
        r = p.call("food.lookup", barcode="4008400402222")
        f = r["data"]["food"] if r["ok"] else {}
        check("food.lookup: Nutella, 539 kcal, 6,3 g Eiweiß, Portion 15 g",
              r["ok"] and f["name"] == "Nutella" and f["nutrients"]["energy_kcal"] == 539 and f["nutrients"]["protein_g"] == 6.3 and f["serving"]["amount"] == 15, json.dumps(r)[:300])
        check("food.lookup: keine geschätzten Werte (Kalzium fehlt bei Nutella)", "calcium_mg" not in f.get("nutrients", {}))
        r = p.call("food.lookup", barcode="0000000000000")
        check("food.lookup: unbekannter Barcode: not_found", not r["ok"] and r["error"]["code"] == "not_found")
        r = p.call("food.lookup", barcode="4008-4004 02222")
        check("food.lookup: Leerzeichen und Bindestriche werden entfernt", r["ok"] and r["data"]["barcode"] == "4008400402222")
        # Einstellung online_food=false schaltet die Abfrage ab.
        doc = copy.deepcopy(example)
        doc["settings"]["online_food"] = False
        p.call("portable.import", document=doc, confirm_replace=True)
        r = p.call("food.search", q="milch", page=1)
        check("online_food=false: food.search meldet disabled", not r["ok"] and r["error"]["code"] == "disabled")
        p.close()
    else:
        print("  (Lebensmitteldienst nicht erreichbar: Live-Prüfungen übersprungen)")

    print("== Aufräumen")
    if not args.keep:
        # Nur das eigene Unterverzeichnis; .check-tmp gehört dem Aufrufer (check.sh legt dort Protokolle ab).
        shutil.rmtree(TMP, ignore_errors=True)
        try:
            os.rmdir(os.path.dirname(TMP))
        except OSError:
            pass
    failed = [r for r in results if not r[1]]
    print(f"\nCLI-Prüfung: {len(results) - len(failed)} von {len(results)} bestanden")
    for name, _, detail in failed:
        print(f"  FEHLGESCHLAGEN: {name} {detail}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
