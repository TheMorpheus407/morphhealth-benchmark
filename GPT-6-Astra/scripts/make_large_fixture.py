#!/usr/bin/env python3
"""Generate a synthetic 10,000-meal fixture from the passing CLI export."""
import json, datetime, pathlib
root=pathlib.Path(__file__).resolve().parents[1]
doc=json.loads((root/'artifacts/ui-fixture.json').read_text())
food=doc['foods'][0];food['name']='Lasttest-Lebensmittel'
end=datetime.datetime(2026,9,26,20,0,0)
doc['meals']=[{'id':f'load-{i:05d}','food':food,'amount':100+(i%4)*25,'unit':'ml','at':(end-datetime.timedelta(hours=6*(9999-i))).isoformat(),'meal':['breakfast','lunch','dinner','snack'][i%4],'note':f'Synthetischer Lasttest {i:05d}'} for i in range(10000)]
p=root/'artifacts/large-fixture.json';p.write_text(json.dumps(doc,ensure_ascii=False,separators=(',',':')));print(p.name,p.stat().st_size)
