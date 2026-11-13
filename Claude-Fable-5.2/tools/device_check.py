#!/usr/bin/env python3
"""Bedient die Release-APK auf dem Referenzgerät und prüft die Kernabläufe.

Aufruf:  tools/device_check.py --reset-app-data [--screenshots ORDNER] [--offline]

Der Test installiert artifacts/morphhealth.apk, LÖSCHT die Daten der App auf
dem Gerät (deshalb der ausdrückliche Schalter) und geht dann wie ein Nutzer
durch die Oberfläche – ausschließlich über adb (Bildschirmbaum lesen, tippen,
Text eingeben):

  Begrüßung, Lebensmittelsuche in Open Food Facts mit Einwilligung, Erfassen
  eines Treffers, Barcode-Abruf, Wasser, Periode, Gewicht, Symptom, gemeinsame
  Historie, Export über den Systemdialog, verschlüsselte Ablage, Neustart.

Gerät und adb stammen aus ENVIRONMENT.json (android_reference_device.adb_serial,
toolchain.adb_path); ein anderes Gerät wird nie angesprochen. Mit --offline
entfallen die beiden Schritte, die den Lebensmitteldienst brauchen.

Rückgabewert 0, wenn alles stimmt; sonst 1.
"""
import json
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE = 'de.themorpheus.morphhealth.local'
ACTIVITY = f'{PACKAGE}/.MainActivity'
DATA = f'/data/data/{PACKAGE}'

with open(os.path.join(ROOT, 'ENVIRONMENT.json'), encoding='utf-8') as _f:
    ENV = json.load(_f)
ADB = [ENV['toolchain']['adb_path'], '-s', ENV['android_reference_device']['adb_serial']]

failures = []
passed = 0
shots_dir = None


class StepFailed(Exception):
    pass


def adb(*args, binary=False, check=True, timeout=120):
    p = subprocess.run(ADB + list(args), capture_output=True, timeout=timeout)
    if check and p.returncode != 0:
        raise StepFailed(f'adb {" ".join(args)}: {p.stderr.decode(errors="replace")[:300]}')
    return p.stdout if binary else p.stdout.decode(errors='replace')


def nodes():
    """Die sichtbaren Elemente: Beschriftung, Mittelpunkt, Eigenschaften."""
    xml = ''
    for _ in range(5):
        adb('shell', 'uiautomator', 'dump', '/sdcard/window_dump.xml', check=False)
        xml = adb('shell', 'cat', '/sdcard/window_dump.xml', check=False)
        if '<hierarchy' in xml and xml.count('<node') > 3:
            break
        time.sleep(0.5)
    out = []
    if '<hierarchy' not in xml:
        return out
    for n in ET.fromstring(xml).iter('node'):
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.get('bounds') or '')
        if not m:
            continue
        x1, y1, x2, y2 = map(int, m.groups())
        label = (n.get('content-desc') or '').strip() or (n.get('text') or '').strip()
        out.append({
            'label': label.replace('\n', ' | '),
            'click': n.get('clickable') == 'true',
            'class': (n.get('class') or '').split('.')[-1],
            'center': ((x1 + x2) // 2, (y1 + y2) // 2),
            'area': (x2 - x1) * (y2 - y1),
        })
    return out


def find(text, exact=False, pattern=False):
    """Das Element mit dieser Beschriftung: genau, als Teiltext oder als Muster."""
    def matches(label):
        if pattern:
            return re.search(text, label) is not None
        return label == text if exact else text.lower() in label.lower()
    hits = [n for n in nodes() if matches(n['label'])]
    hits.sort(key=lambda n: (not n['click'], n['area']))
    return hits[0] if hits else None


def wait_for(text, seconds=20, exact=False, pattern=False):
    deadline = time.time() + seconds
    while True:
        n = find(text, exact, pattern)
        if n:
            return n
        if time.time() > deadline:
            visible = '; '.join(x['label'][:40] for x in nodes() if x['label'])[:600]
            raise StepFailed(f'"{text}" erscheint nicht. Sichtbar: {visible}')
        time.sleep(0.4)


def tap(text, exact=False, seconds=20):
    n = wait_for(text, seconds, exact)
    x, y = n['center']
    adb('shell', 'input', 'tap', str(x), str(y))
    time.sleep(0.6)


def tap_class(cls, index=0):
    hits = [n for n in nodes() if n['class'] == cls]
    if len(hits) <= index:
        raise StepFailed(f'kein Element der Klasse {cls}')
    x, y = hits[index]['center']
    adb('shell', 'input', 'tap', str(x), str(y))
    time.sleep(0.5)


def type_text(text):
    # adb gibt nur einfache ASCII-Zeichen verlässlich ein.
    adb('shell', 'input', 'text', text.replace(' ', '%s'))
    time.sleep(0.4)


def key(code):
    adb('shell', 'input', 'keyevent', code)
    time.sleep(0.5)


def swipe_up():
    adb('shell', 'input', 'swipe', '540', '1800', '540', '700', '250')
    time.sleep(0.7)


def scroll_to(text, pattern=False, swipes=6):
    """Blättert nach unten, bis das Element im sichtbaren Bereich liegt."""
    for _ in range(swipes):
        n = find(text, pattern=pattern)
        if n:
            return n
        swipe_up()
    return wait_for(text, 5, pattern=pattern)


def shot(name):
    if not shots_dir:
        return
    os.makedirs(shots_dir, exist_ok=True)
    data = adb('exec-out', 'screencap', '-p', binary=True)
    with open(os.path.join(shots_dir, f'{name}.png'), 'wb') as f:
        f.write(data)


def step(name, action):
    global passed
    try:
        action()
        passed += 1
        print(f'  ok    {name}', flush=True)
        return True
    except StepFailed as e:
        failures.append(name)
        print(f'  FEHLER {name}: {e}', flush=True)
        shot('fehler-' + re.sub(r'[^a-z0-9]+', '-', name.lower())[:40])
        # Zurück auf den Hauptbildschirm, damit die folgenden Schritte nicht
        # an diesem Fehler hängen.
        try:
            start_app()
            wait_for('Tab 1 von 5', 30)
        except StepFailed:
            pass
        return False


def start_app():
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'am', 'start', '-W', '-n', ACTIVITY)


def root(command):
    """Ein Befehl mit Systemrechten (userdebug-Abbild), nur zum Nachsehen."""
    assert "'" not in command
    return adb('shell', f"su 0 sh -c '{command}'", check=False)


def main():
    global shots_dir
    args = sys.argv[1:]
    if '--reset-app-data' not in args:
        sys.exit('device_check: dieser Test löscht die Daten der App auf dem '
                 'Referenzgerät. Bitte ausdrücklich mit --reset-app-data starten.')
    offline = '--offline' in args
    if '--screenshots' in args:
        shots_dir = os.path.abspath(args[args.index('--screenshots') + 1])
        # Bilder eines früheren Laufs entfernen, damit der Ordner zu diesem passt.
        if os.path.isdir(shots_dir):
            for name in os.listdir(shots_dir):
                if re.fullmatch(r'(\d\d|fehler)-[a-z0-9-]+\.png', name):
                    os.remove(os.path.join(shots_dir, name))
    apk = os.path.join(ROOT, 'artifacts', 'morphhealth.apk')
    if not os.path.isfile(apk):
        sys.exit('device_check: artifacts/morphhealth.apk fehlt; zuerst ./build.sh')

    state = adb('get-state', check=False).strip()
    if state != 'device':
        sys.exit(f'device_check: {ADB[2]} ist nicht erreichbar ({state or "kein Gerät"})')
    print(f'Gerät {ADB[2]}: Android {adb("shell", "getprop", "ro.build.version.release").strip()}, '
          f'{adb("shell", "getprop", "ro.product.cpu.abi").strip()}')

    def install():
        out = adb('install', '-r', apk, check=False, timeout=300)
        if 'Success' not in out:
            raise StepFailed(out.strip()[-300:] or 'Installation fehlgeschlagen')
        adb('shell', 'pm', 'clear', PACKAGE)
    if not step('APK installieren, Daten der App zurücksetzen', install):
        return finish()

    def welcome():
        start_app()
        wait_for('Willkommen bei MorphHealth', 30)
        wait_for('Deutsch')
        shot('01-begruessung')
        swipe_up()
        tap('Loslegen')
        wait_for('Tab 1 von 5')
        wait_for('Noch keine Periode erfasst')
    if not step('Begrüßung ohne Registrierung, Übersicht erscheint', welcome):
        return finish()

    def search_and_log():
        tap('Ernährung | Tab')
        tap('Lebensmittel erfassen', exact=True)
        wait_for('Lebensmittel hinzufügen')
        tap_class('EditText')
        type_text('haferflocken')
        key('KEYCODE_ENTER')
        # Vor der ersten Anfrage fragt die App nach.
        wait_for('Dein Tagebuch verlässt das Gerät nicht')
        tap('Online-Suche einschalten')
        header = wait_for(r'\d Treffer', 30, pattern=True)
        count = re.search(r'([\d.]+) Treffer', header['label'])
        if not count or int(count.group(1).replace('.', '')) < 20:
            raise StepFailed(f'unerwartete Trefferzahl: {header["label"]}')
        shot('02-suche')
        tap('kcal je 100')
        wait_for('Nährwerte dieser Menge')
        wait_for('aus Open Food Facts')
        shot('03-erfassen')
        tap('Speichern', exact=True)
        wait_for('Nährwerte des Tages')
        entry = scroll_to('kcal, Eiweiß')
        if not re.search(r'\d+ kcal', entry['label']):
            raise StepFailed(f'Eintrag ohne Kalorien: {entry["label"]}')

    def barcode():
        tap('Lebensmittel erfassen', exact=True)
        tap('Barcode eingeben')
        wait_for('Nachschlagen')
        type_text('3017620425035')
        tap('Nachschlagen')
        wait_for('Nutella', 30)
        tap('Speichern', exact=True)
        wait_for('Nährwerte des Tages')
        # Der Eintrag im Tagebuch, nicht die kurze Meldung am unteren Rand.
        entry = scroll_to(r'^Nutella \| .*kcal', pattern=True)
        if 'Portion' not in entry['label']:
            raise StepFailed(f'unerwarteter Eintrag: {entry["label"]}')

    if offline:
        print('  --    Lebensmittelsuche und Barcode übersprungen (--offline)')
        entries = 4
    else:
        step('Suche in Open Food Facts mit Einwilligung, Treffer erfassen', search_and_log)
        step('Barcode-Nummer nachschlagen und erfassen', barcode)
        entries = 6

    def water():
        tap('Ernährung | Tab')
        for _ in range(4):
            if find('250 ml Wasser erfassen'):
                break
            swipe_up()
        tap('250 ml Wasser erfassen')
        wait_for('Wasser: 250 ml')
        shot('04-tagebuch')
    step('Wasser mit einem Tipp erfassen', water)

    def period():
        tap('Zyklus | Tab')
        tap('Periode beginnt heute')
        wait_for('Periode, Tag 1')
        shot('05-zyklus')
    step('Periode mit einem Tipp beginnen', period)

    def weight():
        tap('Körper | Tab')
        tap('Gewicht eintragen')
        wait_for('Abbrechen')
        type_text('68.4')
        tap('Speichern', exact=True)
        wait_for('68,4 kg')
    step('Gewicht eintragen', weight)

    def symptom():
        tap('Symptome | Tab')
        tap('Symptom eintragen')
        tap('Kopfschmerzen', exact=True)
        tap('Stärker')
        tap('Speichern', exact=True)
        wait_for('Stärke 6 von 10')
        shot('06-symptome')
    step('Symptom mit Stärke eintragen', symptom)

    def history():
        tap('Verlauf | Tab')
        wait_for(f'{entries} Einträge')
        shot('07-verlauf')
        tap('Verläufe | Tab')
        wait_for('Größe: Kalorien')
        for _ in range(5):
            if find('1 Periodentag im Zeitraum'):
                break
            swipe_up()
        wait_for('1 Periodentag im Zeitraum')
        tap('Einträge | Tab')
    step(f'gemeinsame Historie zeigt alle {entries} Einträge', history)

    def export():
        tap('Einstellungen')
        for _ in range(3):
            swipe_up()
        tap('Daten | Export')
        tap('Daten exportieren')
        wait_for('im Klartext')
        tap('Unverschlüsselt exportieren')
        # Systemdialog "Speichern unter"; Beschriftung je nach Gerätesprache.
        time.sleep(1.5)
        button = find('SAVE', exact=True) or find('Save', exact=True) \
            or find('SPEICHERN', exact=True) or find('Speichern', exact=True)
        if not button:
            raise StepFailed('der Systemdialog zum Speichern erscheint nicht')
        adb('shell', 'input', 'tap', str(button['center'][0]), str(button['center'][1]))
        saved = wait_for('Gespeichert: ', 20)
        name = saved['label'].split('Gespeichert: ', 1)[1].strip()
        if "'" in name or '/' in name:
            raise StepFailed(f'unerwarteter Dateiname: {name}')
        # Der Name kann Leerzeichen und Klammern enthalten ("… (1).json").
        raw = adb('shell', f"cat '/sdcard/Download/{name}'", binary=True, check=False)
        adb('shell', f"rm -f '/sdcard/Download/{name}'", check=False)
        try:
            document = json.loads(raw.decode('utf-8'))
        except ValueError:
            raise StepFailed(f'{name} ist kein JSON ({len(raw)} Bytes)')
        total = sum(len(document.get(k, [])) for k in
                    ['intake', 'water', 'caffeine', 'weights', 'symptoms', 'periods',
                     'cycle_days'])
        if document.get('format') != 'morphhealth-export' or total != entries:
            raise StepFailed(f'Export enthält {total} statt {entries} Einträge')
        key('KEYCODE_BACK')
        key('KEYCODE_BACK')
    step('Export über den Systemdialog ist vollständig', export)

    def storage():
        listing = root(f'find {DATA} -type f')
        files = [line.strip() for line in listing.splitlines() if line.strip()]
        store = sorted(os.path.basename(f) for f in files if '/no_backup/' in f)
        if store != ['master.key', 'morphhealth.journal', 'morphhealth.lock',
                     'morphhealth.snapshot']:
            raise StepFailed(f'unerwartete Dateien: {store}')
        # Sucht in allen privaten Dateien nach Wörtern aus den Einträgen.
        hits = root(f'grep -rlia -e haferflocken -e nutella -e kopfschmerzen '
                    f'-e weight_kg {DATA}/no_backup {DATA}/files {DATA}/shared_prefs '
                    f'{DATA}/databases {DATA}/app_flutter 2>/dev/null').strip()
        if hits:
            raise StepFailed(f'Klartext gefunden in: {hits}')
        size = root(f'stat -c %s {DATA}/no_backup/master.key').strip()
        if size != '61':
            raise StepFailed(f'master.key hat {size} statt 61 Bytes')
    step('private Dateien: nur der verschlüsselte Bestand, kein Klartext', storage)

    def restart():
        start_app()
        wait_for('Tab 1 von 5', 30)
        tap('Verlauf | Tab')
        wait_for(f'{entries} Einträge')
        tap('Übersicht | Tab')
        wait_for('Periode, Tag 1')
        shot('08-uebersicht')
    step('nach einem Neustart sind alle Einträge wieder da', restart)

    def permissions():
        dump = adb('shell', 'dumpsys', 'package', PACKAGE)
        names = []
        collecting = False
        for line in dump.splitlines():
            text = line.strip()
            if text == 'requested permissions:':
                collecting = True
            elif collecting and (text.endswith(':') or not text):
                break
            elif collecting:
                names.append(text.split(':')[0])
        names = sorted(set(names))
        allowed = {'android.permission.INTERNET',
                   f'{PACKAGE}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'}
        if 'android.permission.INTERNET' not in names or not set(names) <= allowed:
            raise StepFailed(f'Berechtigungen: {names}')
    step('auf dem Gerät: einzige Berechtigung ist INTERNET', permissions)

    finish()


def finish():
    print(f'\nGerät: {passed} Schritte bestanden, {len(failures)} fehlgeschlagen')
    if failures:
        for name in failures:
            print(f'  - {name}')
        sys.exit(1)


if __name__ == '__main__':
    main()
