#!/usr/bin/env python3
"""Prüft den Wartungszugang ./mh von außen, als gesonderter Prozess.

Aufruf:  tools/mh_check.py [--offline]

Der Test legt einen leeren Datenbestand in einem temporären Ordner an und
führt echte Sitzungen über stdin/stdout:

  * describe liefert ein Beispieldokument, das sich unverändert importieren lässt
  * Import (mit und ohne Bestätigung), Export (mit und ohne Bestätigung)
  * Export nach Import ist inhaltsgleich; ein zweiter Prozess sieht dieselben Daten
  * nutrition.day und cycle.forecast liefern die erwarteten Fachwerte
  * --now setzt die fachliche Uhr
  * falscher Schlüssel, Schlüssel im Datenordner, kaputte Zeilen, unbekannte op
  * im Datenordner steht nichts im Klartext
  * food.search und food.lookup gegen den Dienst aus ENVIRONMENT.json
    (mit --offline übersprungen)

Rückgabewert 0, wenn alles stimmt; sonst 1 und eine Liste der Abweichungen.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MH = os.path.join(ROOT, 'mh')
NOW = '2026-09-23T20:00:00+02:00'

failures = []
passed = 0


def check(name, condition, detail=''):
    global passed
    if condition:
        passed += 1
        print(f'  ok    {name}')
    else:
        failures.append(name)
        print(f'  FEHLER {name}' + (f': {detail}' if detail else ''))


def session(data_dir, key_file, requests, extra=(), raw_lines=None):
    """Startet ./mh, sendet die Anfragen, liefert (Antworten, Exitcode, stderr)."""
    lines = raw_lines if raw_lines is not None else [
        json.dumps(r, ensure_ascii=False) for r in requests
    ]
    started = time.monotonic()
    p = subprocess.run(
        [MH, '--data-dir', data_dir, '--key-file', key_file, *extra],
        input=('\n'.join(lines) + '\n').encode('utf-8'),
        capture_output=True,
        timeout=180,
    )
    elapsed = time.monotonic() - started
    answers = []
    for line in p.stdout.decode('utf-8').splitlines():
        try:
            answers.append(json.loads(line))
        except ValueError:
            answers.append({'_not_json': line})
    return answers, p.returncode, p.stderr.decode('utf-8', 'replace'), elapsed


def content(document):
    """Das Exportdokument ohne den Zeitpunkt des Exports."""
    return {k: v for k, v in document.items() if k != 'exported_at'}


def main():
    offline = '--offline' in sys.argv[1:]
    work = tempfile.mkdtemp(prefix='mh-check-')
    try:
        run(work, offline)
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print(f'\nmh: {passed} Prüfungen bestanden, {len(failures)} fehlgeschlagen')
    if failures:
        for name in failures:
            print(f'  - {name}')
        sys.exit(1)


def run(work, offline):
    data_dir = os.path.join(work, 'data')
    key_file = os.path.join(work, 'key.bin')
    with open(key_file, 'wb') as f:
        f.write(os.urandom(32))
    fixed = ['--now', NOW]

    print('Protokoll und Beschreibung')
    answers, code, err, elapsed = session(
        data_dir, key_file, [{'request_id': 'd1', 'op': 'describe'}], fixed)
    check('describe antwortet mit genau einer Zeile', len(answers) == 1 and code == 0,
          f'{len(answers)} Zeilen, Exit {code}, stderr {err[:200]}')
    describe = answers[0] if answers else {}
    check('describe: request_id und ok', describe.get('request_id') == 'd1'
          and describe.get('ok') is True)
    check('nichts auf stderr', err == '', err[:200])
    data = describe.get('data') or {}
    for key in ['protocol', 'operations', 'formats', 'example_document',
                'invocation', 'nutrients', 'food_service']:
        check(f'describe enthält "{key}"', key in data)
    operations = data.get('operations') or {}
    for op in ['describe', 'portable.export', 'portable.import', 'nutrition.day',
               'cycle.forecast', 'food.search', 'food.lookup']:
        check(f'describe dokumentiert {op}', op in operations)
    check('describe nennt die gesetzte Uhr',
          (data.get('invocation') or {}).get('current', {}).get('now') == NOW,
          json.dumps((data.get('invocation') or {}).get('current')))
    check('describe nennt alle 31 Nährstoffe', len(data.get('nutrients') or []) == 31,
          str(len(data.get('nutrients') or [])))
    example = data.get('example_document') or {}
    check('Start des Programms unter einer Sekunde', elapsed < 1.0, f'{elapsed:.2f} s')

    print('Import, Auswertung, Export')
    requests = [
        {'request_id': 1, 'op': 'portable.export', 'ack_plaintext': True},
        {'request_id': 2, 'op': 'portable.import', 'document': example},
        {'request_id': 3, 'op': 'portable.import', 'document': example,
         'confirm_replace': True},
        {'request_id': 4, 'op': 'nutrition.day', 'date': '2026-09-22'},
        {'request_id': 5, 'op': 'cycle.forecast', 'on': '2026-09-23'},
        {'request_id': 6, 'op': 'portable.export'},
        {'request_id': 7, 'op': 'portable.export', 'ack_plaintext': True},
        {'request_id': 8, 'op': 'nutrition.day', 'date': '2026-02-30'},
        {'request_id': 9, 'op': 'cycle.forecast', 'on': '2026-07-01'},
    ]
    answers, code, err, _ = session(data_dir, key_file, requests, fixed)
    by_id = {a.get('request_id'): a for a in answers}
    check('eine Antwort je Anfrage, in Reihenfolge',
          [a.get('request_id') for a in answers] == [r['request_id'] for r in requests])

    empty = by_id.get(1, {}).get('data') or {}
    check('leerer Bestand lässt sich exportieren',
          by_id.get(1, {}).get('ok') is True and empty.get('format') == 'morphhealth-export'
          and empty.get('intake') == [])
    check('Import ohne Bestätigung wird abgelehnt',
          by_id.get(2, {}).get('ok') is False
          and by_id[2]['error'].get('code') == 'confirmation_required')
    report = by_id.get(3, {}).get('data') or {}
    check('Import mit Bestätigung ersetzt den Bestand',
          by_id.get(3, {}).get('ok') is True and report.get('replaced') is True
          and report.get('entries_total') == 36, json.dumps(report)[:300])
    check('Importbericht zählt je Art',
          report.get('counts') == {'foods': 5, 'intake': 7, 'water': 5, 'caffeine': 2,
                                   'weights': 4, 'symptoms': 9, 'periods': 8,
                                   'cycle_days': 1}, json.dumps(report.get('counts')))

    day = by_id.get(4, {}).get('data') or {}
    totals = day.get('totals') or {}
    check('nutrition.day: Kalorien des 22.09.2026',
          abs(totals.get('energy_kcal', 0) - 595.9) < 0.05, str(totals.get('energy_kcal')))
    check('nutrition.day: Makronährstoffe',
          abs(totals.get('protein_g', 0) - 17.24) < 0.01
          and abs(totals.get('carbohydrates_g', 0) - 79.17) < 0.01
          and abs(totals.get('fat_g', 0) - 20.82) < 0.01, json.dumps(totals)[:200])
    check('nutrition.day: alle 31 Nährstoffe mit Abdeckung',
          len(totals) == 31 and len(day.get('coverage') or {}) == 31)
    check('nutrition.day: Mahlzeiten, Wasser, Koffein, Ziele',
          [m.get('meal') for m in day.get('meals', [])]
          == ['breakfast', 'lunch', 'dinner', 'snack']
          and (day.get('water') or {}).get('total_ml') == 1080
          and (day.get('caffeine') or {}).get('total_mg') == 60
          and set(day.get('goals') or {}) == {'water_ml', 'energy_kcal', 'protein_g',
                                              'carbohydrates_g', 'fat_g'})

    forecast = by_id.get(5, {}).get('data') or {}
    nxt = forecast.get('next_period') or {}
    check('cycle.forecast: nächste Periode um den 14.10.2026',
          forecast.get('status') == 'upcoming'
          and nxt.get('expected_start') == '2026-10-14'
          and nxt.get('window') == {'earliest': '2026-10-12', 'latest': '2026-10-16'},
          json.dumps(nxt)[:300])
    check('cycle.forecast: Grundlage und Erklärung in beiden Sprachen',
          (forecast.get('basis') or {}).get('cycles_used') == 7
          and len((forecast.get('explanation') or {}).get('de', [])) >= 3
          and len((forecast.get('explanation') or {}).get('en', [])) >= 3
          and 'de' in (forecast.get('disclaimer') or {}))
    check('Export ohne Bestätigung wird abgelehnt',
          by_id.get(6, {}).get('ok') is False
          and by_id[6]['error'].get('code') == 'acknowledgement_required')
    exported = by_id.get(7, {}).get('data') or {}
    check('Export nach Import ist inhaltsgleich mit dem Beispieldokument',
          content(exported) == content(example))
    check('ungültiges Datum wird mit Feldangabe abgelehnt',
          by_id.get(8, {}).get('ok') is False
          and by_id[8]['error'].get('code') == 'invalid_argument'
          and (by_id[8]['error'].get('details') or {}).get('field') == 'date',
          json.dumps(by_id.get(8))[:300])
    earlier = by_id.get(9, {}).get('data') or {}
    check('cycle.forecast für einen früheren Betrachtungstag nutzt nur, was damals bekannt war',
          earlier.get('on') == '2026-07-01'
          and (earlier.get('basis') or {}).get('cycles_recorded') == 4
          and (earlier.get('next_period') or {}).get('expected_start', '') < '2026-08-01',
          json.dumps(earlier.get('next_period'))[:200])

    print('Dauerhaftigkeit und Schlüssel')
    answers, code, err, _ = session(
        data_dir, key_file, [{'request_id': 'again', 'op': 'portable.export',
                              'ack_plaintext': True}], fixed)
    check('ein neuer Prozess sieht dieselben Daten',
          answers and answers[0].get('ok') is True
          and content(answers[0]['data']) == content(example))

    plain = False
    names = []
    for folder, _, files in os.walk(data_dir):
        for name in files:
            names.append(name)
            with open(os.path.join(folder, name), 'rb') as f:
                blob = f.read()
            for needle in [b'Haferflocken', b'weight_kg', b'period', b'Kopfschmerzen']:
                if needle in blob:
                    plain = True
    check('der Datenordner enthält nur die drei Dateien des Bestands',
          sorted(names) == ['morphhealth.journal', 'morphhealth.lock',
                            'morphhealth.snapshot'], str(sorted(names)))
    check('im Datenordner steht nichts im Klartext', not plain)

    wrong_key = os.path.join(work, 'wrong.bin')
    with open(wrong_key, 'wb') as f:
        f.write(os.urandom(32))
    answers, code, err, _ = session(
        data_dir, wrong_key, [{'request_id': 'k', 'op': 'nutrition.day',
                               'date': '2026-09-22'}], fixed)
    check('falscher Schlüssel: Fehler store_wrong_key, keine Daten',
          answers and answers[0].get('ok') is False
          and answers[0]['error'].get('code') == 'store_wrong_key',
          json.dumps(answers)[:300])

    short_key = os.path.join(work, 'short.bin')
    with open(short_key, 'wb') as f:
        f.write(os.urandom(31))
    answers, code, err, _ = session(
        data_dir, short_key, [{'request_id': 'k', 'op': 'portable.export',
                               'ack_plaintext': True}], fixed)
    check('Schlüsseldatei mit 31 Bytes: Fehler key_file_invalid',
          answers and answers[0].get('ok') is False
          and answers[0]['error'].get('code') == 'key_file_invalid')

    inside = os.path.join(data_dir, 'key.bin')
    shutil.copyfile(key_file, inside)
    answers, code, err, _ = session(
        data_dir, inside, [{'request_id': 'k', 'op': 'portable.export',
                            'ack_plaintext': True}], fixed)
    os.remove(inside)
    check('Schlüsseldatei im Datenordner: Fehler key_file_invalid',
          answers and answers[0].get('ok') is False
          and answers[0]['error'].get('code') == 'key_file_invalid')

    print('Fehlerhafte Eingaben')
    answers, code, err, _ = session(data_dir, key_file, None, fixed, raw_lines=[
        'das ist kein JSON',
        '',
        '[1, 2, 3]',
        '{"op": "describe"}',
        '{"request_id": 5, "op": "gibt.es.nicht"}',
        '{"request_id": "ä", "op": "nutrition.day"}',
        '{"request_id": 7, "op": "describe"}',
    ])
    codes = [(a.get('request_id'), a.get('ok'), (a.get('error') or {}).get('code'))
             for a in answers]
    check('kaputte Zeilen beenden die Sitzung nicht', codes == [
        (None, False, 'invalid_json'),
        (None, False, 'invalid_json'),
        (None, False, 'invalid_request'),
        (5, False, 'unknown_op'),
        ('ä', False, 'invalid_argument'),
        (7, True, None),
    ], json.dumps(codes, ensure_ascii=False))
    check('EOF beendet den Prozess mit 0', code == 0, str(code))

    p = subprocess.run([MH, '--data-dir', 'relativ', '--key-file', key_file],
                       input=b'', capture_output=True, timeout=60)
    check('ungültige Optionen: Exit 64, nichts auf stdout',
          p.returncode == 64 and p.stdout == b'', f'{p.returncode} {p.stdout[:80]!r}')
    p = subprocess.run([MH, '--data-dir', data_dir, '--key-file', key_file,
                        '--food-base-url', 'http://unverschluesselt.example'],
                       input=b'', capture_output=True, timeout=60)
    check('Lebensmitteldienst ohne HTTPS wird abgelehnt',
          p.returncode == 64 and p.stdout == b'', f'{p.returncode}')

    print('Lebensmitteldienst')
    if offline:
        print('  übersprungen (--offline)')
        return
    requests = [
        {'request_id': 'l1', 'op': 'food.lookup', 'barcode': '3017620425035'},
        {'request_id': 'l2', 'op': 'food.lookup', 'barcode': '4000000000013'},
        {'request_id': 'l3', 'op': 'food.lookup', 'barcode': '30176-20425035 '},
        {'request_id': 'l4', 'op': 'food.lookup', 'barcode': 'abc'},
        {'request_id': 's1', 'op': 'food.search', 'q': 'haferflocken', 'page': 1},
        {'request_id': 's2', 'op': 'food.search', 'q': 'haferflocken', 'page': 2},
        {'request_id': 's3', 'op': 'food.search', 'q': '', 'page': 1},
    ]
    answers, code, err, _ = session(data_dir, key_file, requests, fixed)
    by_id = {a.get('request_id'): a for a in answers}
    found = by_id.get('l1', {}).get('data') or {}
    product = found.get('product') or {}
    check('food.lookup findet ein Produkt mit Nährwerten',
          by_id.get('l1', {}).get('ok') is True and found.get('found') is True
          and product.get('barcode') == '3017620425035'
          and (product.get('nutrients') or {}).get('energy_kcal', 0) > 400,
          json.dumps(by_id.get('l1'), ensure_ascii=False)[:400])
    missing = by_id.get('l2', {}).get('data') or {}
    check('food.lookup: unbekannter Barcode ist ein Ergebnis, kein Fehler',
          by_id.get('l2', {}).get('ok') is True and missing.get('found') is False
          and missing.get('reason') == 'product_not_found')
    check('food.lookup: Barcode mit Leer- und Trennzeichen wird bereinigt',
          (by_id.get('l3', {}).get('data') or {}).get('found') is True)
    check('food.lookup: ungültiger Barcode wird ohne Abruf abgelehnt',
          by_id.get('l4', {}).get('ok') is False
          and by_id['l4']['error'].get('code') == 'invalid_argument')
    page1 = by_id.get('s1', {}).get('data') or {}
    page2 = by_id.get('s2', {}).get('data') or {}
    check('food.search liefert Treffer mit Seitenangaben',
          by_id.get('s1', {}).get('ok') is True and len(page1.get('products') or []) == 20
          and page1.get('total_count', 0) > 20 and page1.get('has_more') is True,
          json.dumps({k: v for k, v in page1.items() if k != 'products'}))
    codes1 = {p.get('barcode') for p in page1.get('products') or []}
    codes2 = {p.get('barcode') for p in page2.get('products') or []}
    check('food.search: Seite 2 liefert andere Produkte',
          by_id.get('s2', {}).get('ok') is True and codes2 and not (codes1 & codes2))
    check('food.search: leerer Suchbegriff wird abgelehnt',
          by_id.get('s3', {}).get('ok') is False
          and by_id['s3']['error'].get('code') == 'invalid_argument')

    # Die Nutzereinstellung "Online-Suche aus" gilt auch hier.
    disabled = dict(example)
    disabled['settings'] = dict(example['settings'], online_food_search='disabled')
    answers, code, err, _ = session(data_dir, key_file, [
        {'request_id': 1, 'op': 'portable.import', 'document': disabled,
         'confirm_replace': True},
        {'request_id': 2, 'op': 'food.search', 'q': 'haferflocken', 'page': 1},
    ], fixed)
    check('ausgeschaltete Online-Suche wird respektiert',
          len(answers) == 2 and answers[1].get('ok') is False
          and answers[1]['error'].get('code') == 'online_disabled',
          json.dumps(answers[-1] if answers else None)[:200])


if __name__ == '__main__':
    main()
