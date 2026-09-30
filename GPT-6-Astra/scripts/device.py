#!/usr/bin/env python3
"""Small UI test helper; always targets the assigned emulator."""
import pathlib, subprocess, xml.etree.ElementTree as ET, re, sys, time
ROOT=pathlib.Path(__file__).resolve().parents[1]
ADB='/home/morpheus/Android/Sdk/platform-tools/adb'
def adb(*args):return subprocess.check_output([ADB,'-s','emulator-5560',*args])
def nodes():
 for attempt in range(4):
  result=adb('shell','uiautomator','dump','/sdcard/mh-window.xml')
  if b'dumped' in result: break
  time.sleep(0.5)
 else: raise AssertionError('Android UI hierarchy unavailable')
 raw=adb('shell','cat','/sdcard/mh-window.xml');(ROOT/'artifacts/window.xml').write_bytes(raw)
 return list(ET.fromstring(raw).iter('node'))
def dump():
 for n in nodes():
  s=n.get('text') or n.get('content-desc')
  if s: print(repr(s),n.get('bounds'),n.get('class'))
def tap(label,contains=False):
 for n in nodes():
  s=n.get('text') or n.get('content-desc') or ''
  if s==label or (contains and label in s):
   v=list(map(int,re.findall(r'\d+',n.get('bounds'))));adb('shell','input','tap',str((v[0]+v[2])//2),str((v[1]+v[3])//2));return
 raise AssertionError(f'Not visible: {label}')
def swipe():adb('shell','input','swipe','540','1860','540','580','350')
def screenshot(name): (ROOT/'artifacts/screenshots'/name).write_bytes(adb('exec-out','screencap','-p'))
if __name__=='__main__':
 cmd=sys.argv[1]
 if cmd=='dump':dump()
 elif cmd=='tap':tap(sys.argv[2],True)
 elif cmd=='swipe':swipe()
 elif cmd=='shot':screenshot(sys.argv[2])
 elif cmd=='text':adb('shell','input','text',sys.argv[2].replace(' ','%s'))
 elif cmd=='back':adb('shell','input','keyevent','4')
