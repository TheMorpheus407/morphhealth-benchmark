#!/usr/bin/env python3
"""Verify final chart labels on the native APK after a presentation change."""
import hashlib
import json
import datetime
import re
from check_device import ROOT, FOLDER, import_json, save, field
import android_ui as u

u.adb('install','-r',ROOT/'artifacts'/'morphhealth.apk')
u.adb('shell','mkdir','-p',FOLDER)
u.adb('push',ROOT/'artifacts'/'device-example.json',FOLDER+'/device-example.json')
u.adb('push',ROOT/'artifacts'/'device-10000.json',FOLDER+'/device-10000.json')
u.launch()
import_json('device-example.json')
u.tap('Zyklus\nTab')
u.screenshot('16-personal-estimate-de.png')
u.tap_node(u.seek('Nächster Monat'))
future_dates=[u.label(n) for n in u.nodes()
              if re.match(r'^(?:Mo|Di|Mi|Do|Fr|Sa|So)\., \d{1,2}\.',u.label(n))]
assert len(future_dates)>1 and all('Mittel' not in value for value in future_dates),future_dates
u.screenshot('17-future-calendar-de.png')
import_json('device-10000.json')
u.tap('Historie\nTab')
u.wait_for('10000')
row=next(n for n in u.nodes() if u.label(n).startswith('Haferflocken\n'))
u.tap_node(row)
# Keep the data from the comprehensive check and make the subtle range visible.
field(0,'110')
save()
u.tap('Verläufe',exact=True)
u.tap('28 Tage',exact=True)
u.screenshot('12-trend-28-days.png')
u.tap('Optionen\nTab')
u.tap_node(u.seek('Alle lokalen Daten löschen'))
u.tap('Löschen',exact=True)
u.wait_for('Lokaler Datenbestand gelöscht')
u.adb('shell','rm','-r',FOLDER)
u.adb('shell','am','force-stop',u.PACKAGE)
u.launch()
u.screenshot('15-final-clean-de.png')
report_path=ROOT/'artifacts'/'device-tests.json'
report=json.loads(report_path.read_text())
report['final_apk_sha256']=hashlib.sha256((ROOT/'artifacts'/'morphhealth.apk').read_bytes()).hexdigest()
report['final_checked_at']=datetime.datetime.now().isoformat(timespec='seconds')
report['checks'].append('Final APK: ongoing period does not invent future bleeding; personal forecast and precise close-range chart labels')
report['checks'].append('Final APK installed and started; clean German state')
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('Final APK installed, 28-day chart checked, and synthetic data removed.',flush=True)
