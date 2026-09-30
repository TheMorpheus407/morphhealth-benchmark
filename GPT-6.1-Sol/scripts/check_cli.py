#!/usr/bin/env python3
"""Exercise the public JSONL contract, persistent encryption, OFF and 10k rows."""
import json, os, pathlib, subprocess, time, tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
TEST_ROOT = ROOT / 'artifacts' / 'test-data'
TEST_ROOT.mkdir(parents=True, exist_ok=True)
metrics = {}

def start(folder, key, *args):
    return subprocess.Popen([str(ROOT/'mh'), '--data-dir', str(folder), '--key-file', str(key),
                             '--now', '2026-09-20T12:00:00+02:00', *args],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

def request(proc, op, **fields):
    payload = {'request_id': op, 'op': op, **fields}
    proc.stdin.write(json.dumps(payload, ensure_ascii=False)+'\n'); proc.stdin.flush()
    line = proc.stdout.readline()
    assert line, proc.stderr.read()
    answer = json.loads(line)
    assert answer['request_id'] == op
    return answer

with tempfile.TemporaryDirectory(dir=TEST_ROOT, prefix='cli-') as work:
    work = pathlib.Path(work)
    key = work/'key.raw'; key.write_bytes(os.urandom(32)); key.chmod(0o600)
    folder = work/'vault'
    p = start(folder, key)
    contract = request(p, 'describe')
    assert contract['ok']
    doc = contract['data']['example_document']
    assert len(contract['data']['nutrient_units']) == 31
    assert not request(p, 'portable.export')['ok']
    assert not request(p, 'portable.import', document=doc)['ok']
    assert request(p, 'portable.import', document=doc, confirm_replace=True)['ok']
    exported = request(p, 'portable.export', ack_plaintext=True)['data']
    assert exported['foods'][0]['name'] == 'Haferflocken'
    assert exported['exported_at'] == '2026-09-20T12:00:00.000'
    day = request(p, 'nutrition.day', date='2026-09-20')['data']
    assert abs(day['nutrients']['calories']-148) < 1e-10
    assert abs(day['nutrients']['protein']-5.2) < 1e-10
    assert day['nutrients']['vitamin_b7'] is None
    assert day['water_ml'] == 250
    assert request(p, 'cycle.forecast', on='2026-09-20')['data']['predicted_start'] == '2026-10-19'
    invalid = {**doc, 'weights':[{'id':'bad','date':'2026-02-30','kg':70}]}
    assert not request(p, 'portable.import', document=invalid, confirm_replace=True)['ok']
    assert request(p, 'portable.export', ack_plaintext=True)['data']['weights'][0]['kg'] == 70
    assert not request(p, 'nutrition.day', date='not a date')['ok']
    p.stdin.write('{bad json}\n'); p.stdin.flush()
    assert json.loads(p.stdout.readline())['ok'] is False
    assert request(p, 'describe')['ok']  # parsing error did not kill the process
    search = request(p, 'food.search', q='milch', page=1)
    assert search['ok'], search
    foods = search['data']['products']
    assert foods and search['data']['page_size'] == 20
    found = request(p, 'food.lookup', barcode=foods[0]['barcode'])
    assert found['ok'] and found['data']['found'], found
    assert found['data']['product']['nutrients']['calcium'] is not None
    second = request(p, 'food.search', q='milch', page=2)
    assert second['ok'] and second['data']['products']
    assert {f['id'] for f in foods}.isdisjoint({f['id'] for f in second['data']['products']})
    missing = request(p, 'food.lookup', barcode='0000000000000')
    assert missing['ok'] and not missing['data']['found']
    metrics['off_search_count'] = search['data']['count']
    metrics['off_lookup_barcode'] = foods[0]['barcode']
    assert not request(p, 'food.lookup', barcode='abc')['ok']
    p.stdin.close(); assert p.wait(timeout=20) == 0
    raw = (folder/'health.mhv').read_text()
    assert 'Haferflocken' not in raw and 'Kopfschmerz' not in raw
    assert json.loads(raw)['cipher'] == 'AES-256-GCM'
    restarted = start(folder, key)
    assert request(restarted, 'nutrition.day', date='2026-09-20')['data']['water_ml'] == 250
    restarted.stdin.close(); assert restarted.wait(timeout=20) == 0
    wrong = work/'wrong.raw'; wrong.write_bytes(os.urandom(32))
    bad = start(folder, wrong); bad.stdin.close()
    assert bad.wait(timeout=20) == 2
    assert 'authentication_failed' in bad.stderr.read()
    # 10,000 daily rows spread over years, with all nutrients represented.
    import datetime
    large = {'format':'morphhealth','version':1,'foods':exported['foods'],'consumption':[]}
    food = exported['foods'][0]
    food['nutrients'] = {k:float(i+1) for i,k in enumerate(contract['data']['nutrient_units'])}
    food['serving_size'] = 40
    for i in range(10000):
        date = datetime.date(2018,1,1)+datetime.timedelta(days=i//4)
        large['consumption'].append({'id':f'e{i}','at':date.isoformat()+f'T{8+(i%4)*3:02}:00:00',
                                    'food_id':food['id'],'amount':100,'unit':'g','meal':'snack'})
    big = start(work/'large-vault', key)
    start_at = time.perf_counter()
    answer = request(big, 'portable.import', document=large, confirm_replace=True)
    metrics['10000_import_seconds'] = round(time.perf_counter()-start_at,3)
    assert answer['ok'] and answer['data']['counts']['consumption'] == 10000, answer
    start_at = time.perf_counter()
    for i in range(28):
        result = request(big,'nutrition.day',date=(datetime.date(2024,11,6)-datetime.timedelta(days=i)).isoformat())
        assert result['ok']
    metrics['28_day_queries_seconds'] = round(time.perf_counter()-start_at,3)
    start_at = time.perf_counter()
    complete = request(big,'portable.export',ack_plaintext=True)
    metrics['10000_export_seconds'] = round(time.perf_counter()-start_at,3)
    assert len(complete['data']['consumption']) == 10000
    big.stdin.close(); assert big.wait(timeout=20) == 0
    metrics['encrypted_10000_bytes'] = (work/'large-vault'/'health.mhv').stat().st_size

    # Android import fixture for verification: a complete but non-personal dataset.
    (ROOT/'artifacts'/'device-example.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2))
    (ROOT/'artifacts'/'device-10000.json').write_text(json.dumps(large,ensure_ascii=False))

(ROOT/'artifacts'/'cli-tests.json').write_text(json.dumps(metrics,indent=2)+'\n')
print('JSONL, persistent encryption, OFF v3.6/search, validation, restart and 10,000-row checks passed.')
print(json.dumps(metrics, ensure_ascii=False))
