#!/usr/bin/env python3
"""Small adb helper; always targets the reference device from ENVIRONMENT.json."""
import json, pathlib, re, subprocess, time, xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
ENV = json.loads((ROOT/'ENVIRONMENT.json').read_text())
ADB = ENV['toolchain']['adb_path']
SERIAL = ENV['android_reference_device']['adb_serial']
PACKAGE = 'de.themorpheus.morphhealth.local'

def adb(*args, binary=False):
    return subprocess.check_output([ADB,'-s',SERIAL,*map(str,args)], text=not binary)

def nodes():
    raw=adb('exec-out','uiautomator','dump','/dev/tty')
    start=raw.find('<?xml')
    end=raw.find('</hierarchy>')
    if start<0 or end<0: raise RuntimeError(raw)
    return list(ET.fromstring(raw[start:end+12]).iter('node'))

def label(n):
    return n.get('text') or n.get('content-desc') or ''

def find(text, exact=False):
    matches=[n for n in nodes() if label(n).casefold()==text.casefold() or (not exact and label(n).casefold().startswith(text.casefold()))]
    return next((n for n in matches if n.get('clickable')=='true'),matches[0] if matches else None)

def tap_node(n):
    if n is None: raise AssertionError('Control not found')
    x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
    adb('shell','input','tap',(x1+x2)//2,(y1+y2)//2)
    time.sleep(.5)

def tap(text, exact=False):
    n=find(text,exact)
    if n is None: raise AssertionError('Missing control: '+text+'\n'+'\n'.join(label(x) for x in nodes()))
    tap_node(n)

def swipe(down=False):
    # History has fixed filters above its independently scrolling result list.
    # Start a downward swipe below those controls so it reaches that list.
    adb('shell','input','swipe',540,1300 if down else 1850,540,1850 if down else 650,350)
    time.sleep(.2)

def seek(text, down=False, attempts=12, exact=False):
    for _ in range(attempts):
        n=find(text,exact)
        if n is not None:
            bounds=list(map(int,re.findall(r'\d+',n.get('bounds'))))
            if n.get('clickable')=='true' and bounds[3]-bounds[1]>60: return n
        swipe(down)
    raise AssertionError('Could not scroll to '+text)

def input_text(text):
    adb('shell','input','text',text.replace(' ','%s'))

def fill(text, value):
    n=find(text)
    if n is None: raise AssertionError('Missing field: '+text)
    tap_node(n)
    adb('shell','input','keyevent','KEYCODE_MOVE_END')
    # Long-press select all via CTRL+A is supported by Android input keycombination.
    adb('shell','input','keycombination','113','29')
    adb('shell','input','keyevent','KEYCODE_DEL')
    input_text(value)
    adb('shell','input','keyevent','KEYCODE_BACK')
    time.sleep(.2)

def screenshot(name):
    target=ROOT/'artifacts'/'screenshots'/name
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(adb('exec-out','screencap','-p',binary=True))

def launch():
    adb('shell','am','start','-n',PACKAGE+'/.MainActivity')
    until=time.monotonic()+60
    while time.monotonic()<until:
        if any(label(n).startswith(('Übersicht\nTab','Overview\nTab')) for n in nodes()):
            return
        time.sleep(.3)
    raise AssertionError('Application did not finish loading')

def wait_for(text, timeout=30):
    until=time.monotonic()+timeout
    while time.monotonic()<until:
        n=find(text)
        if n is not None:return n
        time.sleep(.3)
    raise AssertionError('Timed out waiting for '+text)

def wait_absent(text, timeout=30):
    until=time.monotonic()+timeout
    while time.monotonic()<until:
        if find(text) is None:return
        time.sleep(.3)
    raise AssertionError('Timed out waiting for control to disappear: '+text)

if __name__=='__main__':
    for n in nodes():
        if label(n):print(repr(label(n)),n.get('bounds'),n.get('class'))
