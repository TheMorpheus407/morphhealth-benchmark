#!/usr/bin/env python3
"""Gerätetest der Release-APK auf dem Referenzemulator.

Installiert artifacts/morphhealth.apk frisch, bedient die App über adb (Eingaben und
UI-Hierarchie per uiautomator) und prüft die Produktabläufe: Übersicht, Wasser,
Lebensmittel per Barcode und Name (echter Abruf über den Lebensmittel-Endpunkt),
eigenes Lebensmittel, Favoriten und "Zuletzt", Gewicht, Symptome, Zyklus, Historie,
Sprache und Bereiche, Export/Import/Sicherung/Wiederherstellung/Löschen über den
Android-Dateiauswahldialog, Neustart und Übereinstimmung mit dem Wartungszugang ./mh.

Aufruf: tools/device_smoke.py [--apk PFAD] [--shots ORDNER] [--keep-installed]
Nur Standardbibliothek. Nutzt ausschließlich das Gerät aus ENVIRONMENT.json
(emulator-5560) und das SDK-adb von dort; verändert weder Systemvertrauen noch
adb-Root. Temporäre Dateien liegen unter <Projekt>/.check-tmp.
Endet mit Exit-Code 0 (alles bestanden), 1 (Fehler) oder 3 (Gerät nicht erreichbar).
"""
import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TMP = os.path.join(ROOT, ".check-tmp", "device")
PKG = "de.themorpheus.morphhealth.local"
PASSPHRASE = "Test-Passphrase-2026"

with open(os.path.join(ROOT, "ENVIRONMENT.json"), encoding="utf-8") as _f:
    ENV = json.load(_f)
ADB = ENV["toolchain"]["adb_path"]
SERIAL = ENV["android_reference_device"]["adb_serial"]
FOOD_URL = ENV["food_api_base_url"]

results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    print(("  ok   " if ok else "  FAIL ") + name + (f"  [{detail}]" if detail and not ok else ""), flush=True)
    return bool(ok)


class Node:
    def __init__(self, e):
        self.text = e.get("text") or ""
        self.desc = e.get("content-desc") or ""
        self.cls = (e.get("class") or "").split(".")[-1]
        self.clickable = e.get("clickable") == "true"
        self.checked = e.get("checked") == "true"
        self.selected = e.get("selected") == "true"
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", e.get("bounds") or "")
        self.b = tuple(int(v) for v in m.groups()) if m else (0, 0, 0, 0)

    @property
    def center(self):
        return (self.b[0] + self.b[2]) // 2, (self.b[1] + self.b[3]) // 2

    def matches(self, sub, exact):
        if exact:
            return sub in (self.text, self.desc)
        s = sub.lower()
        return s in self.text.lower() or s in self.desc.lower()

    def __repr__(self):
        return f"<{self.cls} {self.b} t={self.text!r} d={self.desc!r}>"


class Device:
    def __init__(self, shots):
        self.shots = shots
        self._cache = None
        os.makedirs(shots, exist_ok=True)

    def adb(self, *a, check_rc=True, binary=False, timeout=120, keep=False):
        # Jede Eingabe (oder Installation, Start) verändert die Anzeige: Der Zwischenspeicher der
        # UI-Hierarchie gilt danach nicht mehr. Reine Abfragen (keep=True) lassen ihn stehen.
        if not keep:
            self._cache = None
        r = subprocess.run([ADB, "-s", SERIAL, *a], capture_output=True, text=not binary, timeout=timeout)
        if check_rc and r.returncode != 0:
            raise RuntimeError(f"adb {' '.join(a)} -> {r.returncode}: {(r.stderr or b'')[:200]}")
        return r.stdout

    def nodes(self, fresh=False):
        if self._cache is not None and not fresh:
            return self._cache
        for attempt in range(6):
            r = subprocess.run([ADB, "-s", SERIAL, "exec-out", "uiautomator", "dump", "/dev/tty"], capture_output=True, text=True)
            x = r.stdout
            if r.returncode == 0 and "<?xml" in x and "</hierarchy>" in x:
                root = ET.fromstring(x[x.index("<?xml"):x.rindex("</hierarchy>") + len("</hierarchy>")])
                self._cache = [Node(e) for e in root.iter("node")]
                return self._cache
            time.sleep(0.6)
        raise RuntimeError("uiautomator dump fehlgeschlagen")

    def find(self, sub, exact=False, nth=0):
        def hits_in(nodes):
            return [n for n in nodes if n.matches(sub, exact) and n.b[2] > n.b[0] and n.b[3] > n.b[1]]

        # Ein Treffer im Zwischenspeicher genügt. Fehlt er, gilt erst eine frische Aufnahme:
        # Meldungen (Snackbars) erscheinen kurz nach der Eingabe.
        hits = hits_in(self.nodes())
        if len(hits) <= nth:
            hits = hits_in(self.nodes(fresh=True))
        return hits[nth] if len(hits) > nth else None

    def wait(self, sub, exact=False, timeout=10, nth=0):
        end = time.time() + timeout
        fresh = False
        while True:
            hits = [n for n in self.nodes(fresh=fresh) if n.matches(sub, exact) and n.b[2] > n.b[0] and n.b[3] > n.b[1]]
            if len(hits) > nth:
                return hits[nth]
            if time.time() > end:
                return None
            fresh = True
            time.sleep(0.3)

    def gone(self, sub, exact=False, timeout=6):
        end = time.time() + timeout
        while time.time() < end:
            if not [n for n in self.nodes(fresh=True) if n.matches(sub, exact)]:
                return True
            time.sleep(0.3)
        return False

    def texts(self):
        out = []
        for n in self.nodes():
            for t in (n.text, n.desc):
                if t:
                    out.extend(part for part in t.split("\n") if part)
        return out

    def tap_xy(self, x, y):
        self.adb("shell", "input", "tap", str(x), str(y))

    def tap(self, sub, exact=False, nth=0, timeout=10, settle=0.7):
        n = self.wait(sub, exact, timeout, nth)
        if not n:
            raise RuntimeError(f"nicht gefunden: {sub!r}")
        self.tap_xy(*n.center)
        time.sleep(settle)
        return n

    def edits(self):
        return sorted([n for n in self.nodes() if n.cls == "EditText"], key=lambda n: (n.b[1], n.b[0]))

    def set_field(self, index, value):
        node = self.edits()[index]
        self.tap_xy(*node.center)
        time.sleep(0.35)
        self.adb("shell", "input", "keyevent", "KEYCODE_MOVE_END")
        self.adb("shell", "input", "keyevent", *(["67"] * (len(node.text) + 3)))
        if value:
            self.adb("shell", "input", "text", value.replace(" ", "%s"))
        time.sleep(0.4)

    def keyboard_shown(self):
        return "mInputShown=true" in self.adb("shell", "dumpsys", "input_method", keep=True)

    def hide_keyboard(self):
        if self.keyboard_shown():
            self.adb("shell", "input", "keyevent", "4")
            for _ in range(10):
                time.sleep(0.3)
                if not self.keyboard_shown():
                    break
            time.sleep(0.4)

    def nav_top(self):
        """Oberkante der System-Navigationsleiste in Pixeln (aus den Fenster-Insets)."""
        out = self.adb("shell", "dumpsys", "window", keep=True)
        m = re.search(r"type=navigationBars frame=\[\d+,(\d+)\]\[\d+,\d+\]", out)
        return int(m.group(1)) if m else 2274

    def back(self, settle=0.7):
        self.adb("shell", "input", "keyevent", "4")
        time.sleep(settle)

    def swipe_up(self, settle=0.6):
        self.adb("shell", "input", "swipe", "540", "1700", "540", "700", "300")
        time.sleep(settle)

    def swipe_down(self, settle=0.6):
        self.adb("shell", "input", "swipe", "540", "700", "540", "1700", "300")
        time.sleep(settle)

    def scroll_to(self, sub, exact=False, tries=8):
        for _ in range(tries):
            n = self.find(sub, exact)
            if n and 220 < n.b[1] and n.b[3] < 2060:
                return n
            self.swipe_up()
        return self.find(sub, exact)

    def shot(self, name):
        path = os.path.join(self.shots, name + ".png")
        with open(path, "wb") as f:
            f.write(self.adb("exec-out", "screencap", "-p", binary=True, keep=True))
        return path

    def launch(self, fresh=False):
        self.adb("shell", "am", "force-stop", PKG)
        if fresh:
            self.adb("shell", "pm", "clear", PKG)
        out = self.adb("shell", "am", "start", "-W", "-n", f"{PKG}/.MainActivity")
        m = re.search(r"TotalTime:\s*(\d+)", out)
        return int(m.group(1)) if m else None

    def now(self):
        s = self.adb("shell", "date", "+%Y-%m-%dT%H:%M:%S%z", keep=True).strip()
        return s[:-2] + ":" + s[-2:]


class Section:
    """Fasst einen Ablauf zusammen: Ein Fehler wird gemeldet und stoppt nur diesen Abschnitt."""

    def __init__(self, dev, title, home=True):
        self.dev, self.title, self.home = dev, title, home

    def __enter__(self):
        print(f"== {self.title}", flush=True)
        if self.home:
            self.dev.launch()
            self.dev.wait("Übersicht", exact=True, timeout=15)
        return self

    def __exit__(self, et, ev, tb):
        if et is None:
            return False
        check(f"{self.title}: Ablauf unterbrochen", False, f"{et.__name__}: {ev}")
        try:
            self.dev.shot("FEHLER_" + re.sub(r"\W+", "_", self.title))
            self.dev.launch()
            time.sleep(2)
        except Exception:
            pass
        return True


def mh_call(mh, data_dir, key_file, now, requests):
    p = subprocess.Popen([mh, "--data-dir", data_dir, "--key-file", key_file, "--now", now], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    out, err = p.communicate("".join(json.dumps({"request_id": i, **r}) + "\n" for i, r in enumerate(requests, 1)))
    return [json.loads(line) for line in out.splitlines()], err


def entry_tiles(d, name):
    """Tagebucheinträge eines Lebensmittels (Kacheln „Name\nUhrzeit · Menge · kcal“), von oben nach unten."""
    return sorted([n for n in d.nodes() if n.desc.startswith(name + "\n")], key=lambda n: n.b[1])


def menu_of(d, tile):
    """Das Menü „Mehr“ in der Höhe einer Eintragskachel."""
    hits = [n for n in d.nodes() if n.desc == "Mehr" and tile.b[1] <= n.center[1] <= tile.b[3]]
    if not hits:
        raise RuntimeError("kein Menü zur Eintragskachel")
    return hits[0]


def open_data_screen(d):
    """Vom Übersichts-Bildschirm zu "Daten und Sicherung"."""
    d.tap("Einstellungen", exact=True)
    n = d.scroll_to("Daten und Sicherung\nExport")
    d.tap_xy(*n.center)
    time.sleep(1.0)


def remove_download(d, pattern):
    """Entfernt Dateien samt Eintrag in der Medienablage (sonst zeigt die Dateiauswahl Geisterdateien)."""
    d.adb("shell", f"content delete --uri content://media/external/file --where \"_display_name LIKE '{pattern}'\"", check_rc=False)
    d.adb("shell", f"rm -f /sdcard/Download/{pattern.replace('%', '*')}", check_rc=False)


def pick_file(d, name):
    """Wählt eine Datei in der Android-Dateiauswahl (mit Blättern, falls sie nicht sichtbar ist)."""
    n = d.scroll_to(name, exact=True, tries=6)
    if not n:
        raise RuntimeError(f"Datei nicht in der Auswahl: {name}")
    d.tap_xy(*n.center)
    time.sleep(1.5)


def kcal_from(texts):
    for t in texts:
        m = re.match(r"^([\d.]+)( von [\d.]+)? kcal$", t)
        if m:
            return int(m.group(1).replace(".", ""))
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apk", default=os.path.join(ROOT, "artifacts", "morphhealth.apk"))
    ap.add_argument("--shots", default=os.path.join(ROOT, "artifacts", "screenshots"))
    ap.add_argument("--keep-installed", action="store_true", help="App am Ende frisch installiert und leer lassen (Standard)")
    args = ap.parse_args()

    if not os.path.exists(ADB):
        print(f"SKIP: adb nicht gefunden ({ADB})")
        return 3
    state = subprocess.run([ADB, "-s", SERIAL, "get-state"], capture_output=True, text=True)
    if state.stdout.strip() != "device":
        print(f"SKIP: {SERIAL} ist nicht erreichbar")
        return 3
    if not SERIAL.startswith("emulator-"):
        print("Abbruch: Es wird nur ein Emulator verwendet.")
        return 1

    shutil.rmtree(TMP, ignore_errors=True)
    os.makedirs(TMP)
    d = Device(args.shots)
    mh = os.path.join(ROOT, "mh")
    key = os.path.join(TMP, "key.bin")
    with open(key, "wb") as f:
        f.write(os.urandom(32))
    run = time.strftime("%H%M%S")
    f_export = f"morphhealth-smoke-{run}-export.json"
    f_example = f"morphhealth-smoke-{run}-example.json"
    f_backup = f"morphhealth-smoke-{run}.mhbackup"
    remove_download(d, "morphhealth-smoke-%")
    port = re.search(r":(\d+)", FOOD_URL.split("//", 1)[-1])
    port = port.group(1) if port else None

    with Section(d, "Installation", home=False) as s:
        rev = d.adb("reverse", "--list")
        if port and f"tcp:{port}" not in rev:
            d.adb("reverse", f"tcp:{port}", f"tcp:{port}")
        d.adb("uninstall", PKG, check_rc=False)
        out = d.adb("install", args.apk)
        check("APK installiert (frische Installation)", "Success" in out, out.strip())
        pk = d.adb("shell", "dumpsys", "package", PKG)
        check("Version 1.0.0", "versionName=1.0.0" in pk)
        granted = sorted(set(re.findall(r"(android\.permission\.[A-Z_]+): granted=true", pk)))
        check("Einzige Berechtigung: INTERNET", granted == ["android.permission.INTERNET"], str(granted))
        check("Keine Sicherung durch das System (allowBackup=false)", "ALLOW_BACKUP" not in pk.split("flags=[")[1].split("]")[0] if "flags=[" in pk else True)
        ms = d.launch()
        check(f"Kaltstart bis zur ersten Anzeige in {ms} ms", ms is not None and ms < 4000, str(ms))
        n = d.wait("Übersicht", exact=True, timeout=15)
        check("Übersicht erscheint", n is not None)
        d.shot("01_uebersicht")

    with Section(d, "Navigation und Übersicht"):
        tabs = ["Übersicht", "Ernährung", "Zyklus", "Gewicht", "Symptome"]
        nodes = d.nodes()
        for t in tabs:
            check(f"Navigation: {t}", any(n.desc.startswith(t + "\nTab") for n in nodes))
        check("Datum von heute ist gewählt", any("Heute" in n.desc or n.text == "Heute" or "Heute" in n.desc for n in nodes) or d.find("Datum wählen") is not None)
        check("Bereiche der Übersicht: Ernährung und Zyklus sichtbar", d.find("Ernährung", exact=True) is not None and d.find("Zyklus", exact=True) is not None)

    with Section(d, "Wasser: Schnellerfassung"):
        d.tap("250 ml Wasser hinzufügen")
        n = d.wait("Wasser, 250 ml", timeout=6)
        check("Wasser: 250 ml erfasst", n is not None)
        check("Wasser: Rückgängig angeboten", d.find("Rückgängig", exact=True) is not None)
        d.tap("Rückgängig", exact=True)
        check("Wasser: Rückgängig nimmt zurück", d.wait("Wasser, 0 ml", timeout=6) is not None)
        d.tap("500 ml Wasser hinzufügen")
        check("Wasser: 500 ml erfasst", d.wait("Wasser, 500 ml", timeout=6) is not None)

    with Section(d, "Lebensmittel per Barcode (echter Abruf)"):
        d.tap("Lebensmittel hinzufügen")
        d.tap("Barcode", exact=True)
        d.set_field(0, "4008400402222")
        d.hide_keyboard()
        d.tap("Suchen", exact=True, settle=1.5)
        hit = d.wait("Nutella", timeout=15)
        check("Barcode 4008400402222 findet Nutella (Open Food Facts)", hit is not None)
        check("Nährwerte je 100 g angezeigt (539 kcal)", d.find("539 kcal je 100 g") is not None)
        d.shot("02_barcode_treffer")
        d.tap("Nutella")
        check("Eintragsformular zeigt Marke, Barcode und Quelle", d.wait("4008400402222", exact=True, timeout=6) is not None and d.find("Open Food Facts", exact=True) is not None)
        d.tap("g", exact=True)
        d.set_field(0, "30")
        d.hide_keyboard()
        check("Vorschau für 30 g: 162 kcal", d.wait("162 kcal", exact=True, timeout=5) is not None)
        d.shot("03_eintrag")
        d.tap("Hinzufügen", exact=True, settle=1.5)
        check("Eintrag im Tagebuch: „Nutella“ zu Frühstück hinzugefügt", d.wait("zu Frühstück hinzugefügt", timeout=6) is not None)
        check("Übersicht zeigt 162 kcal", d.wait("162 kcal", exact=True, timeout=6) is not None)

    with Section(d, "Lebensmittel per Name (echter Abruf)"):
        d.tap("Lebensmittel hinzufügen")
        d.tap("Name", exact=True)
        d.set_field(0, "Haferflocken")
        d.hide_keyboard()
        d.tap("Suchen", exact=True, settle=1.5)
        hit = d.wait("kcal je 100", timeout=15)
        check("Namenssuche liefert Treffer mit Nährwerten", hit is not None)
        cnt = [t for t in d.texts() if re.match(r"^[\d.]+ Treffer", t)]
        check("Trefferanzahl wird genannt", bool(cnt), str(cnt))
        d.shot("04_namenssuche")
        n = d.find("kcal je 100")
        d.tap_xy(*n.center)
        time.sleep(1.5)
        check("Treffer öffnet Eintragsformular", d.wait("Eintrag hinzufügen", timeout=6) is not None)
        d.back()
        d.back()

    with Section(d, "Eigenes Lebensmittel, Favoriten, Zuletzt"):
        d.tap("Lebensmittel hinzufügen")
        d.tap("Eigenes Lebensmittel anlegen")
        d.set_field(0, "Testmuesli")
        ed = d.edits()
        # Reihenfolge: Name, Marke, Barcode, Portionsmenge, Portionsbezeichnung, Energie, Eiweiß, Kohlenhydrate, Fett, ...
        d.set_field(5, "400")
        d.set_field(6, "10")
        d.hide_keyboard()
        n = d.scroll_to("Speichern", exact=True, tries=12)
        d.tap_xy(*n.center)
        time.sleep(1.5)
        check("Eigenes Lebensmittel gespeichert", d.wait("Testmuesli", timeout=8) is not None)
        d.tap("Testmuesli")
        d.tap("g", exact=True)
        d.set_field(0, "50")
        d.hide_keyboard()
        check("Eigenes Lebensmittel: 50 g ergeben 200 kcal", d.wait("200 kcal", exact=True, timeout=5) is not None)
        d.tap("Zu Favoriten hinzufügen", exact=True)
        d.tap("Hinzufügen", exact=True, settle=1.5)
        check("Eigener Eintrag hinzugefügt", d.wait("zu Frühstück hinzugefügt", timeout=6) is not None)
        check("Übersicht summiert 362 kcal (162 + 200)", d.wait("362 kcal", exact=True, timeout=6) is not None)
        d.tap("Lebensmittel hinzufügen")
        d.tap("Zuletzt", nth=0)
        check("Zuletzt: bereits erfasste Lebensmittel erneut wählbar", d.wait("Nutella", timeout=6) is not None)
        d.tap("Favoriten", nth=0)
        check("Favoriten: Testmuesli", d.wait("Testmuesli", timeout=6) is not None)
        d.back()

    with Section(d, "Einträge erneut erfassen, korrigieren, löschen"):
        d.tap("Ernährung\nTab 2", settle=1.0)
        d.scroll_to("Nutella\n")
        tiles = entry_tiles(d, "Nutella")
        check("Tagebuch zeigt den Nutella-Eintrag", len(tiles) == 1, str([t.desc for t in tiles]))
        d.tap_xy(*menu_of(d, tiles[0]).center)
        time.sleep(1.0)
        d.tap("Erneut erfassen", exact=True, settle=1.3)
        tiles = entry_tiles(d, "Nutella")
        check("Erneut erfassen legt einen zweiten Eintrag an", len(tiles) == 2, str(len(tiles)))
        d.tap_xy(300, tiles[1].center[1])
        check("Eintrag antippen öffnet „Eintrag bearbeiten“", d.wait("Eintrag bearbeiten", timeout=8) is not None)
        d.set_field(0, "60")
        d.hide_keyboard()
        d.tap("Speichern", exact=True, settle=1.5)
        tiles = entry_tiles(d, "Nutella")
        check("Korrigierte Menge: 60 g = 323 kcal", any("60 g · 323 kcal" in t.desc for t in tiles), str([t.desc[:40] for t in tiles]))
        edited = [t for t in tiles if "60 g" in t.desc][0]
        d.tap_xy(*menu_of(d, edited).center)
        time.sleep(1.0)
        d.tap("Löschen", exact=True, settle=1.3)
        check("Löschen meldet „Eintrag gelöscht“ mit Rückgängig", d.wait("Eintrag gelöscht", timeout=5) is not None and d.find("Rückgängig", exact=True) is not None)
        check("Nach dem Löschen bleibt ein Nutella-Eintrag", len(entry_tiles(d, "Nutella")) == 1)
        d.tap("Rückgängig", exact=True, settle=1.3)
        tiles = entry_tiles(d, "Nutella")
        check("Rückgängig stellt den Eintrag wieder her", len(tiles) == 2, str(len(tiles)))
        edited = [t for t in tiles if "60 g" in t.desc][0]
        d.tap_xy(*menu_of(d, edited).center)
        time.sleep(1.0)
        d.tap("Löschen", exact=True, settle=1.3)
        check("Endgültig gelöscht: ein Nutella-Eintrag bleibt", len(entry_tiles(d, "Nutella")) == 1)

    with Section(d, "Verlauf über 7 und 28 Tage"):
        d.tap("Ernährung\nTab 2", settle=1.0)
        d.tap("Verlauf\nTab 2", settle=1.2)
        check("7 Tage: Durchschnitt 362 kcal an 1 von 7 Tagen", d.wait("Durchschnitt: 362 kcal (1 von 7 Tagen erfasst)", timeout=6) is not None)
        check("7 Tage: Balken für heute ist beschriftet", any(re.search(r"^\S+, \d\d\.\d\d\.\d{4}: 362$", n.desc) for n in d.nodes()))
        d.tap("28 Tage", exact=True, settle=1.2)
        check("28 Tage: Durchschnitt 362 kcal an 1 von 28 Tagen", d.wait("Durchschnitt: 362 kcal (1 von 28 Tagen erfasst)", timeout=6) is not None)
        d.shot("14_verlauf_28")

    with Section(d, "Gewicht"):
        d.tap("Gewicht\nTab 4", settle=1.0)
        d.tap("Gewicht erfassen")
        d.set_field(0, "72.5")
        d.hide_keyboard()
        d.tap("Speichern", exact=True, settle=1.2)
        check("Gewicht 72,5 kg im Verlauf", d.wait("72,5 kg", timeout=6) is not None)
        d.shot("05_gewicht")

    with Section(d, "Symptome"):
        d.tap("Symptome\nTab 5", settle=1.0)
        d.tap("Symptom erfassen")
        d.set_field(0, "Kopfschmerz")
        d.hide_keyboard()
        d.tap("Speichern", exact=True, settle=1.2)
        check("Symptom mit Intensität gespeichert", d.wait("Kopfschmerz, Intensität 3 von 10", timeout=6) is not None)
        d.shot("06_symptome")

    with Section(d, "Zyklus"):
        d.tap("Zyklus\nTab 3", settle=1.0)
        n = d.wait("Periode beginnt heute", timeout=6)
        check("Zyklus: Schnellaktion „Periode beginnt heute“", n is not None)
        d.tap("Periode beginnt heute", settle=1.2)
        check("Zyklus: Periode läuft (Tag 1)", d.wait("Tag 1 der Periode", timeout=6) is not None)
        d.shot("07_zyklus")

    with Section(d, "Historie"):
        d.tap("Übersicht\nTab 1", settle=1.0)
        d.tap("Historie", exact=True)
        d.set_field(0, "Nutella")
        d.hide_keyboard()
        check("Historie: Freitextsuche findet den Eintrag", d.wait("Nutella", nth=1, timeout=6) is not None or d.find("Nutella") is not None)
        d.shot("08_historie")
        d.back()

    with Section(d, "Blätter liegen über der Navigationsleiste"):
        nav = d.nav_top()

        def sheet_ok(label):
            d.hide_keyboard()
            clickable = [n for n in d.nodes() if n.clickable and n.b[3] > 1200 and n.b[2] - n.b[0] < 1080]
            low = max((n.b[3] for n in clickable), default=0)
            check(f"Blatt „{label}“: Schaltflächen enden über der Navigationsleiste ({low} <= {nav})", 0 < low <= nav, str(low))
            d.shot("blatt_" + re.sub(r"\W+", "_", label).lower()) if label in ("Gewicht erfassen", "Symptom erfassen") else None
            d.back()

        d.tap("Gewicht\nTab 4", settle=1.0)
        d.tap("Gewicht erfassen")
        sheet_ok("Gewicht erfassen")
        d.tap("Symptome\nTab 5", settle=1.0)
        d.tap("Symptom erfassen")
        sheet_ok("Symptom erfassen")
        d.tap("Zyklus\nTab 3", settle=1.0)
        d.tap("Periode erfassen")
        sheet_ok("Periode erfassen")
        d.tap("Ernährung\nTab 2", settle=1.0)
        n = d.scroll_to("Andere Menge", exact=True)
        d.tap_xy(*n.center)
        time.sleep(1.0)
        sheet_ok("Wassermenge")
        d.tap("Übersicht\nTab 1", settle=1.0)
        d.tap("Bereiche anpassen")
        sheet_ok("Bereiche anpassen")

    with Section(d, "Einstellungen: Sprache, Bereiche, Einheit"):
        d.tap("Bereiche anpassen")
        d.tap("Gewicht", exact=True, nth=0) if d.find("Gewicht", exact=True) else None
        time.sleep(0.6)
        d.tap("Fertig", exact=True)
        check("Bereich Gewicht ausgeblendet: Navigation hat 4 Einträge", d.wait("Tab 4 von 4", timeout=5) is not None)
        d.tap("Bereiche anpassen")
        d.tap("Gewicht", exact=True, nth=0)
        d.tap("Fertig", exact=True)
        check("Bereich Gewicht wieder eingeblendet", d.wait("Tab 5 von 5", timeout=5) is not None)
        d.tap("Einstellungen", exact=True)
        d.tap("English", exact=True)
        check("Sprache umgestellt: Überschrift „Settings“", d.wait("Settings", exact=True, timeout=6) is not None)
        d.back()
        check("Englische Navigation", d.wait("Overview", exact=True, timeout=6) is not None and d.find("Nutrition\nTab 2") is not None)
        d.shot("09_english")
        d.tap("Settings", exact=True)
        d.tap("Deutsch", exact=True)
        check("Sprache zurück auf Deutsch", d.wait("Einstellungen", exact=True, timeout=6) is not None)
        d.back()

    dl = "/sdcard/Download"
    with Section(d, "Datenexport (JSON) über den Dateiauswahldialog"):
        open_data_screen(d)
        d.tap("Exportieren", exact=True)
        check("Export warnt vor Klartext", d.wait("Unverschlüsselter Export", timeout=5) is not None)
        d.tap("Exportieren", exact=True, nth=0)
        n = d.wait("SAVE", exact=True, timeout=10)
        check("Dateiauswahl (Speichern) erscheint", n is not None)
        d.set_field(0, f_export)
        d.tap("SAVE", exact=True, settle=2.5)
        check("Export gespeichert", d.wait("Export gespeichert", timeout=6) is not None)
        local = os.path.join(TMP, "export.json")
        d.adb("pull", f"{dl}/{f_export}", local)
        doc = json.load(open(local, encoding="utf-8"))
        check("Export: Format morphhealth-portable v1", doc.get("format") == "morphhealth-portable" and doc.get("version") == 1)
        check("Export: Lebensmitteleinträge (Nutella 30 g, Testmuesli 50 g)", sorted(e["food"]["name"] for e in doc["food_entries"]) == ["Nutella", "Testmuesli"], str([e.get("food", {}).get("name") for e in doc["food_entries"]]))
        check("Export: Wasser 500 ml, Gewicht 72,5 kg, Symptom, Periode",
              [w["ml"] for w in doc["water_entries"]] == [500] and [w["kg"] for w in doc["weight_entries"]] == [72.5]
              and [s["name"] for s in doc["symptom_entries"]] == ["Kopfschmerz"] and len(doc["periods"]) == 1)
        check("Export: eigenes Lebensmittel mit Nährwerten", any(f["name"] == "Testmuesli" and f["nutrients"].get("energy_kcal") == 400 for f in doc["foods"]))
        # Gleiche Daten im Wartungszugang: Tagessumme muss der Anzeige der App entsprechen.
        dd = os.path.join(TMP, "mh-data")
        res, err = mh_call(mh, dd, key, d.now(), [
            {"op": "portable.import", "document": doc, "confirm_replace": True},
            {"op": "nutrition.day", "date": d.now()[:10]},
        ])
        day = res[1]["data"] if len(res) > 1 and res[1]["ok"] else {}
        check("Wartungszugang liest den App-Export (./mh)", res[0]["ok"], json.dumps(res[0])[:200])
        check("Wartungszugang: Tagessumme 362 kcal wie in der App", round(day.get("totals", {}).get("energy_kcal", -1)) == 362, str(day.get("totals", {}).get("energy_kcal")))
        d.back()
        d.back()

    with Section(d, "Import des Beispieldokuments und Zyklusprognose"):
        res, _ = mh_call(mh, os.path.join(TMP, "mh-desc"), key, d.now(), [{"op": "describe"}])
        example = res[0]["data"]["example_import_document"]
        ex_path = os.path.join(TMP, f_example)
        with open(ex_path, "w", encoding="utf-8") as f:
            json.dump(example, f, ensure_ascii=False)
        d.adb("push", ex_path, f"{dl}/{f_example}")
        d.adb("shell", f"am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file://{dl}/{f_example}", check_rc=False)
        open_data_screen(d)
        d.tap("Datei wählen", exact=True)
        pick_file(d, f_example)
        check("Import: Vorschau nennt 16 Datensätze", d.wait("16 Datensätze", timeout=8) is not None)
        d.tap("Ersetzen", exact=True, settle=2.5)
        check("Import abgeschlossen", d.wait("Import abgeschlossen", timeout=8) is not None)
        d.back()
        d.back()
        d.tap("Vorheriger Tag", settle=1.0)
        check("28.09.2026: 522 von 2.200 kcal", d.wait("522 von 2.200 kcal", timeout=6) is not None)
        check("28.09.2026: Wasser 750 von 2.000 ml", d.find("Wasser, 750 von 2.000 ml") is not None)
        check("28.09.2026: Koffein 113 mg gesamt", d.find("Koffein: 113 mg gesamt") is not None)
        d.shot("10_import_tag")
        # Prognose: Erklärung der App gegen die Rechnung des Wartungszugangs. Die App zeigt den
        # gewählten Tag (hier der Vortag), also fragt der Wartungszugang denselben Tag ab.
        shown_day = (datetime.date.fromisoformat(d.now()[:10]) - datetime.timedelta(days=1)).isoformat()
        res, _ = mh_call(mh, os.path.join(TMP, "mh-fc"), key, d.now(), [
            {"op": "portable.import", "document": example, "confirm_replace": True},
            {"op": "cycle.forecast", "on": shown_day},
        ])
        fc = res[1]["data"]
        d.tap("Zyklus\nTab 3", settle=1.0)
        d.tap("Wie kommt die Einschätzung zustande?", settle=1.2)
        shown = d.texts()
        d.swipe_up()
        shown += d.texts()
        lines = fc["explanation"]["de"]
        missing = [ln for ln in lines if not any(ln in t or t in ln for t in shown)]
        check(f"Erklärung in der App entspricht dem Wartungszugang ({len(lines)} Zeilen)", not missing, str(missing)[:300])
        d.shot("11_erklaerung")
        d.back()
        d.shot("12_zyklus_prognose")

    backup_name = f_backup
    with Section(d, "Verschlüsselte Sicherung"):
        open_data_screen(d)
        n = d.scroll_to("Sicherung erstellen", exact=True)
        d.tap_xy(*n.center)
        time.sleep(1.2)
        d.set_field(0, PASSPHRASE)
        d.set_field(1, PASSPHRASE)
        d.hide_keyboard()
        d.tap("OK", exact=True, settle=5.0)
        n = d.wait("SAVE", exact=True, timeout=10)
        check("Sicherung: Dateiauswahl erscheint", n is not None)
        d.set_field(0, backup_name)
        d.tap("SAVE", exact=True, settle=3.0)
        local = os.path.join(TMP, backup_name)
        d.adb("pull", f"{dl}/{backup_name}", local)
        blob = open(local, "rb").read()
        check("Sicherung: Kopf MHB1, Argon2id (Kennung 2), 64 MiB, 3 Durchgänge", blob[:4] == b"MHB1" and blob[4] == 2 and int.from_bytes(blob[5:9], "big") == 65536 and int.from_bytes(blob[9:13], "big") == 3,
              blob[:16].hex())
        check("Sicherung: kein Klartext (Name, Lebensmittel, Datum)", not any(w in blob for w in (b"Haferflocken", b"Kopfschmerz", b"food_entries", b"2026-09-28")))
        check(f"Sicherung: Größe plausibel ({len(blob)} Byte)", 200 < len(blob) < 50000)

    with Section(d, "Löschen, frische Installation und Wiederherstellung"):
        open_data_screen(d)
        n = d.scroll_to("Alles löschen", exact=True)
        d.tap_xy(*n.center)
        time.sleep(1.0)
        check("Löschen verlangt Bestätigung", d.wait("Wirklich alles löschen?", timeout=5) is not None)
        d.tap("Alles löschen", exact=True, nth=0, settle=2.5)
        check("Alle Daten wurden gelöscht", d.wait("Alle Daten wurden gelöscht", timeout=6) is not None)
        # Frische Installation: App entfernen, neu installieren, Sicherung einspielen.
        d.adb("uninstall", PKG)
        out = d.adb("install", args.apk)
        check("Neuinstallation", "Success" in out)
        d.launch()
        check("Frische Installation startet leer", d.wait("Noch keine Perioden erfasst", timeout=15) is not None and d.wait("Wasser, 0 ml", timeout=5) is not None)
        open_data_screen(d)
        n = d.scroll_to("Sicherung wählen", exact=True)
        d.tap_xy(*n.center)
        time.sleep(2.5)
        pick_file(d, backup_name)
        # falsche Passphrase zuerst
        d.set_field(0, "falsche-Passphrase-1")
        d.hide_keyboard()
        d.tap("OK", exact=True, settle=5.0)
        check("Falsche Passphrase wird abgelehnt", d.wait("Passphrase", timeout=6) is not None and d.find("Ersetzen", exact=True) is None)
        d.shot("13_falsche_passphrase")
        if d.find("OK", exact=True) is None:
            d.tap("Sicherung wählen", exact=True)
            pick_file(d, backup_name)
        d.set_field(0, PASSPHRASE)
        d.hide_keyboard()
        d.tap("OK", exact=True, settle=5.0)
        check("Wiederherstellung: Vorschau nennt 16 Datensätze", d.wait("16 Datensätze", timeout=10) is not None)
        d.tap("Ersetzen", exact=True, settle=3.0)
        check("Wiederhergestellt: 16 Datensätze", d.wait("Wiederhergestellt", timeout=8) is not None)
        d.back()
        d.back()
        d.tap("Vorheriger Tag", settle=1.0)
        check("Nach der Wiederherstellung: 28.09.2026 mit 522 von 2.200 kcal", d.wait("522 von 2.200 kcal", timeout=8) is not None)

    with Section(d, "Neustart: Daten bleiben erhalten"):
        d.launch()
        d.wait("Übersicht", exact=True, timeout=15)
        d.tap("Vorheriger Tag", settle=1.0)
        check("Nach Neustart weiterhin 522 von 2.200 kcal", d.wait("522 von 2.200 kcal", timeout=8) is not None)

    with Section(d, "Aufräumen"):
        remove_download(d, "morphhealth-smoke-%")
        d.adb("shell", "rm", "-f", "/sdcard/mh_ui.xml", check_rc=False)
        d.adb("uninstall", PKG, check_rc=False)
        out = d.adb("install", args.apk)
        check("App am Ende frisch und leer installiert", "Success" in out)
        d.launch()

    # Nur das eigene Unterverzeichnis; .check-tmp gehört dem Aufrufer (check.sh legt dort Protokolle ab).
    shutil.rmtree(TMP, ignore_errors=True)
    try:
        os.rmdir(os.path.dirname(TMP))
    except OSError:
        pass
    failed = [r for r in results if not r[1]]
    print(f"\nGerätetest: {len(results) - len(failed)} von {len(results)} bestanden")
    for name, _, detail in failed:
        print(f"  FEHLGESCHLAGEN: {name} {detail}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
