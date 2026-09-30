#!/usr/bin/env python3
"""Real JSON-lines process, persistence, validation and provided HTTPS API checks."""
import json, os, pathlib, select, subprocess, tempfile, time, math, shutil
ROOT=pathlib.Path(__file__).resolve().parents[1]
TEMP=pathlib.Path(tempfile.mkdtemp(prefix='cli-',dir=ROOT/'artifacts'))
KEY=TEMP/'key.bin'; KEY.write_bytes(os.urandom(32)); KEY.chmod(0o600)
DATA=TEMP/'data'
CMD=[str(ROOT/'mh'),'--data-dir',str(DATA),'--key-file',str(KEY),'--now','2026-09-26T10:15:00+02:00']
results=[]
def start():
 return subprocess.Popen(CMD,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1,cwd=ROOT)
def request(proc,op,**fields):
 message={'request_id':len(results)+1,'op':op,**fields}
 t=time.perf_counter();proc.stdin.write(json.dumps(message)+'\n');proc.stdin.flush()
 assert select.select([proc.stdout],[],[],45)[0],f'{op}: no flushed response'
 line=proc.stdout.readline();assert line,f'{op}: CLI closed stdout: {proc.stderr.read()}'
 response=json.loads(line);assert response['request_id']==message['request_id']
 results.append({'op':op,'ok':response['ok'],'milliseconds':round((time.perf_counter()-t)*1000,2)})
 return response
p=None
try:
 p=start()
 description=request(p,'describe');assert description['ok'],description
 doc=description['data']['exampleDocument']
 assert request(p,'portable.import',document=doc,confirm_replace=True)['ok']
 exported=request(p,'portable.export',ack_plaintext=True)['data']
 assert exported['format']=='morphhealth' and exported['version']==1
 # Public example is independently editable and covers all required categories.
 doc=exported
 food={'id':'test-food','name':'Prueflebensmittel','source':'custom','basis':'ml','servingSize':40,'favorite':True,'nutrients':{'energy':200,'protein':5,'carbs':20,'fat':8,'caffeine':50,'vitaminC':30,'vitaminD':2,'iodine':12,'sodium':0.2}}
 doc['foods']=[food]
 doc['meals']=[{'id':'meal','food':food,'amount':1.5,'unit':'serving','at':'2026-09-26T08:30:00+02:00','meal':'breakfast','note':'unique-sensitive-fixture'}]
 doc['drinks']=[{'id':'water','kind':'water','amount':250,'at':'2026-09-26T09:00:00','note':''},{'id':'caffeine','kind':'caffeine','amount':70,'at':'2026-09-26T09:15:00','note':''}]
 doc['periods']=[{'id':str(i),'start':a,'end':b,'flow':'medium','note':''} for i,(a,b) in enumerate([('2026-07-01','2026-07-05'),('2026-07-29','2026-08-02'),('2026-08-26','2026-08-30')])]
 doc['weights']=[{'id':'w','at':'2026-09-26T08:00:00','kg':65.5,'note':''}]
 doc['symptoms']=[{'id':'s','at':'2026-09-26T10:00:00','name':'Kopfschmerz','intensity':3,'note':'Nach einem langen Tag'}]
 assert request(p,'portable.import',document=doc,confirm_replace=True)['ok']
 n=request(p,'nutrition.day',date='2026-09-26');assert n['ok'],n
 n=n['data'];assert math.isclose(n['totals']['energy'],120);assert math.isclose(n['totals']['vitaminD'],1.2)
 assert n['waterMl']==250 and n['caffeineMg']==100 and n['totals']['iron'] is None
 f=request(p,'cycle.forecast',on='2026-09-26');assert f['ok'] and f['data']['cycleLength']==28 and f['data']['predictedStart']=='2026-09-23',f
 assert not request(p,'portable.export')['ok']
 bad=json.loads(json.dumps(doc));bad['meals'][0]['amount']=-1
 assert not request(p,'portable.import',document=bad,confirm_replace=True)['ok']
 snapshot=request(p,'portable.export',ack_plaintext=True)['data']
 assert snapshot['meals'][0]['amount']==1.5
 assert not request(p,'nutrition.day',date='2026-02-30')['ok']
 assert not request(p,'unknown')['ok']
 # Real requests target the manifest origin, never the public OFF API.
 search=request(p,'food.search',q='Hafer',page=1);assert search['ok'] and search['data']['products'],search
 lookup=request(p,'food.lookup',barcode='5411188115366');assert lookup['ok'] and lookup['data'],lookup
 assert lookup['data']['nutrients']['energy'] is not None,lookup
 missing=request(p,'food.lookup',barcode='0000000000000');assert missing['ok'] and missing['data'] is None,missing
 p.stdin.close();assert p.wait(timeout=10)==0,p.stderr.read();p=None
 data_bytes=b''.join(x.read_bytes() for x in DATA.iterdir() if x.is_file())
 assert b'unique-sensitive-fixture' not in data_bytes and b'Prueflebensmittel' not in data_bytes
 p=start();again=request(p,'portable.export',ack_plaintext=True)['data'];assert again==snapshot
 p.stdin.close();assert p.wait(timeout=10)==0;p=None
 (ROOT/'artifacts'/'ui-fixture.json').write_text(json.dumps(snapshot,ensure_ascii=False,indent=2))
 (ROOT/'artifacts'/'cli-check.json').write_text(json.dumps({'passed':True,'checks':results},indent=2))
 print(f'CLI: {len(results)} checks passed (flush, example, import/export, nutrition, forecast, validation, encrypted persistence, real HTTPS food API).')
finally:
 if p is not None:
  p.kill();p.wait()
 shutil.rmtree(TEMP)
