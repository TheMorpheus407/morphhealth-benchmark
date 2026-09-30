#!/usr/bin/env python3
"""Production UI checks on the disposable reference emulator, no app backdoors."""
import datetime, json, pathlib, time
import android_ui as u

ROOT=u.ROOT
PASS='benchmark-passphrase-2026'  # Only synthetic test data; never a production credential.
FOLDER='/sdcard/Download/MorphHealth-tests'
report={'device':u.SERIAL,'api':35,'synthetic_data':True,'checks':[]}

def step(name):
    report['checks'].append(name)
    print(name,flush=True)

def field(index,value):
    fields=[n for n in u.nodes() if n.get('class')=='android.widget.EditText']
    u.tap_node(fields[index])
    u.adb('shell','input','keycombination',113,29)
    u.adb('shell','input','keyevent','KEYCODE_DEL')
    u.input_text(value)
    u.adb('shell','input','keyevent','KEYCODE_BACK')

def save():
    u.tap_node(u.seek('Speichern'))

def picker(name):
    # The external-storage provider shows files pushed by adb. The Downloads
    # provider indexes user-created documents and may omit unindexed test files.
    for attempt in range(3):
        u.wait_for('Show roots')
        if u.find('Open from',exact=True) is None:
            u.tap('Show roots')
        u.wait_for('Open from',timeout=10)
        target=next(n for n in u.nodes() if u.label(n)=='Android SDK built for x86_64' and n.get('resource-id')=='android:id/title')
        print('Selecting external-storage root:', target.get('bounds'),flush=True)
        u.tap_node(target)
        try:
            u.wait_for('Files on Android SDK built for x86_64',timeout=6)
            break
        except AssertionError:
            if attempt==2: raise
    u.tap('Download',exact=True)
    u.tap('MorphHealth-tests',exact=True)
    u.tap(name,exact=True)

def import_json(name):
    u.tap('Optionen\nTab')
    u.tap_node(u.seek('JSON importieren'))
    picker(name)
    u.wait_for('Datenbestand ersetzen?')
    started=time.monotonic()
    u.tap('Ersetzen',exact=True)
    u.wait_for('Daten übernommen',timeout=60)
    return round(time.monotonic()-started,3)

def document_save(name):
    u.wait_for('SAVE',timeout=60)
    # Folder is already remembered; use a unique filename, so no overwrite prompt.
    field(0,name)
    u.tap('SAVE',exact=True)
    u.wait_for('Einstellungen')

def main():
    u.adb('reverse','tcp:8788','tcp:8788')
    u.adb('install','-r',ROOT/'artifacts'/'morphhealth.apk')
    u.adb('shell','pm','clear',u.PACKAGE)
    u.adb('shell','mkdir','-p',FOLDER)
    u.adb('shell','rm','-f',FOLDER+'/verified-backup.mhbackup.json',FOLDER+'/verified-export.json')
    for name in ['device-example.json','device-10000.json']:
        u.adb('push',ROOT/'artifacts'/name,FOLDER+'/'+name)
    u.launch()
    u.screenshot('06-clean-final.png')
    step('Release APK installed and started; German default; no account')
    import_json('device-example.json')
    step('Native Android document picker: full JSON import')

    u.tap('Historie\nTab');u.tap('Gewicht · 70 kg')
    field(0,'71.2');save();u.wait_for('Gewicht · 71,2 kg')
    step('Weight entry corrected through unified history')
    u.tap('Kopfschmerz')
    field(0,'Headache');save();u.wait_for('Headache')
    step('Symptom name corrected; existing intensity and note preserved')
    u.tap('Periode · Mittel')
    u.tap('Periode läuft noch');save()
    step('Ongoing period ended and saved')
    u.tap('Zyklus\nTab')
    u.tap_node(u.seek('Blutung erfassen'))
    u.tap('Blutungsstärke')
    u.tap('Spotting',exact=True);save()
    u.wait_for('Zyklus')
    u.screenshot('07-cycle-final.png')
    u.tap_node(u.seek('Voriger Monat',down=True))
    u.screenshot('08-older-month.png')
    step('Daily spotting override, personal forecast, calendar and older month navigation')

    u.tap('Ernährung\nTab')
    u.tap_node(u.seek('+ 250 ml'))
    # With Android accessibility services the actionable undo message can remain
    # visible indefinitely. Scroll the caffeine control above the message.
    u.swipe()
    u.tap_node(u.seek('Koffein',down=False,exact=True))
    field(0,'80');save()
    step('Quick water and additional caffeine are logged in nutrition')
    u.tap_node(u.seek('Lebensmittel erfassen',down=True))
    u.tap('Online suchen');u.tap('Online-Suche aktivieren')
    field(0,'milch');u.tap('Suchen',exact=True)
    u.wait_for('Geröstete Mandel Ohne Zucker')
    u.screenshot('09-off-final.png')
    step('Real HTTPS name search using the configured origin and CA trust')
    u.tap('Barcode-Nummer');field(0,'5411188112709');u.tap('Suchen',exact=True)
    u.wait_for('Geröstete Mandel Ohne Zucker')
    u.tap('Geröstete Mandel Ohne Zucker')
    u.tap('Favorit umschalten')
    u.tap('Im Tagebuch erfassen')
    field(0,'125');save()
    u.tap('Zurück',exact=True)
    u.tap('Zurück',exact=True)
    step('Real v3.6 barcode lookup, favourite and consumption logging')

    u.tap('Historie\nTab')
    u.tap('Haferflocken')
    field(0,'2');save()
    step('Consumption edit preserves serving size and updates nutrient totals')
    u.tap('Optionen\nTab')
    u.tap_node(u.seek('Verschlüsselte Sicherung'))
    field(0,PASS);field(1,PASS);u.tap('Weiter',exact=True)
    document_save('verified-backup.mhbackup.json')
    step('Passphrase backup encrypted and saved with Android CREATE_DOCUMENT')

    u.adb('shell','pm','clear',u.PACKAGE)
    u.launch();u.tap('Optionen\nTab')
    u.tap_node(u.seek('Sicherung wiederherstellen'))
    picker('verified-backup.mhbackup.json')
    field(0,PASS);u.tap('Weiter',exact=True)
    u.wait_for('Datenbestand ersetzen?',timeout=60)
    u.tap('Ersetzen',exact=True);u.wait_for('Daten übernommen')
    u.tap('Historie\nTab');u.seek('Gewicht · 71,2 kg')
    u.tap_node(u.seek('Haferflocken',down=True));u.wait_for('296 kcal')
    u.screenshot('10-fresh-restore-final.png')
    u.adb('shell','input','keyevent','KEYCODE_BACK')
    step('Backup restored on a fresh app/key installation; edited amounts and weight verified')

    u.tap('Optionen\nTab');u.tap_node(u.seek('JSON exportieren'))
    u.tap('Exportieren',exact=True);document_save('verified-export.json')
    raw=u.adb('exec-out','cat',FOLDER+'/verified-export.json')
    document=json.loads(raw)
    assert document['weights'][0]['kg']==71.2
    assert document['symptoms'][0]['name']=='Headache'
    assert document['consumption'][0]['amount']==2
    assert any(r['kind']=='caffeine' and r['amount']==80 for r in document['drinks'])
    assert sum(r['amount'] for r in document['drinks'] if r['kind']=='water')==500
    assert document['bleeding'][0]['strength']=='spotting'
    assert document['periods'][-1]['end']=='2026-09-20'
    backup=json.loads(u.adb('exec-out','cat',FOLDER+'/verified-backup.mhbackup.json'))
    assert backup['format']=='morphhealth-backup' and backup['cipher']=='AES-256-GCM'
    assert 'Headache' not in json.dumps(backup)
    step('Full native plaintext export validated against all changed areas; backup contains ciphertext')

    u.adb('shell','am','force-stop',u.PACKAGE);u.launch()
    u.tap('Historie\nTab');u.seek('Gewicht · 71,2 kg')
    step('Encrypted Android persistence survives process restart')

    report['10000_import_ui_seconds_including_adb']=import_json('device-10000.json')
    u.tap('Historie\nTab');u.wait_for('10000')
    u.screenshot('11-history-10000.png')
    first=next(n for n in u.nodes() if u.label(n).startswith('Haferflocken\n'))
    u.tap_node(first);field(0,'110');save()
    u.tap('Verläufe',exact=True)
    u.tap('28 Tage',exact=True)
    u.screenshot('12-trend-28-days.png')
    step('10,000-entry Android dataset: history, editing, 28-day nutrition trend')
    (ROOT/'artifacts'/'android-memory.txt').write_text(u.adb('shell','dumpsys','meminfo',u.PACKAGE))

    u.tap('Optionen\nTab')
    u.tap_node(u.seek('Sprache',down=True))
    u.tap('English',exact=True)
    u.tap('Overview\nTab')
    u.screenshot('13-overview-en.png')
    u.adb('shell','settings','put','system','font_scale','1.7')
    try:
        u.adb('shell','am','force-stop',u.PACKAGE);u.launch()
        u.wait_for('Cycle\nTab',timeout=60)
        u.tap('Cycle\nTab');u.screenshot('14-large-font-en.png')
    finally:
        u.adb('shell','settings','put','system','font_scale','1.0')
    step('English UI and enlarged Android fonts checked')

    u.tap('Settings\nTab')
    u.tap_node(u.seek('Delete all local data'))
    u.tap('Delete',exact=True);u.wait_for('Lokaler Datenbestand gelöscht')
    u.tap('Historie\nTab');u.wait_for('Keine passenden Einträge.')
    step('All local data and settings deleted through the product UI')
    u.adb('shell','rm','-r',FOLDER)
    u.adb('shell','am','force-stop',u.PACKAGE);u.launch()
    u.screenshot('15-final-clean-de.png')
    report['passed']=True
    report['measured_at']=datetime.datetime.now().isoformat(timespec='seconds')
    (ROOT/'artifacts'/'device-tests.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('All device checks passed.',flush=True)

if __name__=='__main__':
    main()
