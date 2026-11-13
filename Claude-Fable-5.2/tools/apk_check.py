#!/usr/bin/env python3
"""Prüft artifacts/morphhealth.apk, ohne sie zu installieren.

Aufruf:  tools/apk_check.py [PFAD_ZUR_APK]

Geprüft werden Package-ID, Version, Zielplattformen (x86_64 muss enthalten
sein), Berechtigungen, Sicherungs- und Netzwerkeinstellungen des Manifests,
die Signatur und dass die Werte aus ENVIRONMENT.json eingebaut sind.

Verwendet aapt2 und apksigner aus den Build-Tools des Android SDK
(ENVIRONMENT.json: toolchain.android_sdk_path, android_build_tools).
"""
import json
import os
import re
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE = 'de.themorpheus.morphhealth.local'

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


def environment():
    try:
        with open(os.path.join(ROOT, 'ENVIRONMENT.json'), encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def build_tools(env):
    toolchain = env.get('toolchain') or {}
    sdk = (toolchain.get('android_sdk_path') or os.environ.get('ANDROID_SDK_ROOT')
           or os.environ.get('ANDROID_HOME') or os.path.expanduser('~/Android/Sdk'))
    base = os.path.join(sdk, 'build-tools')
    wanted = toolchain.get('android_build_tools')
    if wanted and os.path.isdir(os.path.join(base, wanted)):
        return os.path.join(base, wanted)
    versions = sorted(os.listdir(base)) if os.path.isdir(base) else []
    if not versions:
        sys.exit(f'apk_check: keine Build-Tools unter {base}')
    return os.path.join(base, versions[-1])


def run(command):
    p = subprocess.run(command, capture_output=True, text=True, timeout=180)
    return p.returncode, p.stdout + p.stderr


def main():
    apk = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        ROOT, 'artifacts', 'morphhealth.apk')
    if not os.path.isfile(apk):
        sys.exit(f'apk_check: {apk} fehlt; zuerst ./build.sh ausführen')
    env = environment()
    tools = build_tools(env)
    aapt2 = os.path.join(tools, 'aapt2')

    print(f'APK {os.path.relpath(apk, ROOT)} ({os.path.getsize(apk) / 1e6:.1f} MB)')
    code, badging = run([aapt2, 'dump', 'badging', apk])
    check('aapt2 liest die APK', code == 0, badging[:300])
    package = re.search(r"package: name='([^']+)' versionCode='([^']+)' "
                        r"versionName='([^']+)'", badging)
    check(f'Package-ID {PACKAGE}', bool(package) and package.group(1) == PACKAGE,
          package.group(1) if package else badging[:200])
    if package:
        print(f'        Version {package.group(3)} (Code {package.group(2)})')
    min_sdk = re.search(r"minSdkVersion:'(\d+)'", badging)
    target_sdk = re.search(r"targetSdkVersion:'(\d+)'", badging)
    check('läuft auf dem Referenzgerät (API 35)',
          bool(min_sdk) and int(min_sdk.group(1)) <= 35,
          min_sdk.group(1) if min_sdk else '')
    if min_sdk and target_sdk:
        print(f'        minSdk {min_sdk.group(1)}, targetSdk {target_sdk.group(1)}')
    check('Release-Build (nicht debuggable)', 'application-debuggable' not in badging)

    permissions = set(re.findall(r"uses-permission: name='([^']+)'", badging))
    # Die zweite Berechtigung legt androidx.core selbst an (Schutzstufe
    # "signature", nur für die eigene App); sie gewährt keinen Zugriff.
    allowed = {'android.permission.INTERNET',
               f'{PACKAGE}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'}
    check('einzige Berechtigung: INTERNET',
          'android.permission.INTERNET' in permissions and permissions <= allowed,
          ', '.join(sorted(permissions)))

    with zipfile.ZipFile(apk) as z:
        names = z.namelist()
        abis = sorted({n.split('/')[1] for n in names
                       if n.startswith('lib/') and n.count('/') == 2})
        check('enthält x86_64', 'x86_64' in abis, ', '.join(abis))
        print(f'        Plattformen: {", ".join(abis)}')
        for abi in abis:
            check(f'{abi}: Flutter-Engine und App-Code vorhanden',
                  f'lib/{abi}/libflutter.so' in names and f'lib/{abi}/libapp.so' in names)
        check('nativer Flutter-Code, kein WebView-Inhalt',
              not any(n.endswith(('.html', '.js')) for n in names
                      if n.startswith('assets/')))
        base_url = env.get('food_api_base_url')
        agent = env.get('food_api_user_agent')
        if base_url and agent and 'x86_64' in abis:
            code_blob = z.read('lib/x86_64/libapp.so')
            check('Adresse des Lebensmitteldienstes aus ENVIRONMENT.json eingebaut',
                  base_url.encode() in code_blob, base_url)
            check('Kennung (User-Agent) aus ENVIRONMENT.json eingebaut',
                  agent.encode() in code_blob, agent)

    code, manifest = run([aapt2, 'dump', 'xmltree', '--file', 'AndroidManifest.xml', apk])
    check('Manifest lesbar', code == 0, manifest[:300])

    def attribute(name):
        m = re.search(rf':{name}\([^)]*\)=(\S+)', manifest)
        return m.group(1) if m else None

    check('Android-Sicherung ausgeschaltet (allowBackup=false)',
          attribute('allowBackup') == 'false', str(attribute('allowBackup')))
    check('Regeln gegen Geräteübertragung vorhanden (dataExtractionRules)',
          attribute('dataExtractionRules') is not None)
    check('kein unverschlüsselter Netzverkehr (usesCleartextTraffic=false)',
          attribute('usesCleartextTraffic') == 'false',
          str(attribute('usesCleartextTraffic')))
    exported = []
    component = None
    for line in manifest.splitlines():
        m = re.search(r'E: (activity|service|receiver|provider)\b', line)
        if m:
            component = [m.group(1), None, False]
            exported.append(component)
            continue
        if re.search(r'E: (manifest|application|uses-|permission|meta-data|'
                     r'intent-filter|action|category)', line):
            if not re.search(r'E: (meta-data|intent-filter|action|category)', line):
                component = None
            continue
        if component is not None:
            m = re.search(r':name\([^)]*\)="([^"]+)"', line)
            if m and component[1] is None:
                component[1] = m.group(1)
            if re.search(r':exported\([^)]*\)=true', line):
                component[2] = True
    public = sorted(c[1] or '?' for c in exported if c[2])
    check('von außen erreichbar ist nur der Startbildschirm',
          public == [f'{PACKAGE}.MainActivity'], ', '.join(public))

    signer = os.path.join(tools, 'lib', 'apksigner.jar')
    code, output = run(['java', '-jar', signer, 'verify', '--verbose',
                        '--print-certs', apk])
    check('Signatur gültig', code == 0 and 'Verifies' in output, output[:300])
    check('Signaturschema v2 oder neuer',
          re.search(r'v(2|3|3\.1) scheme[^\n]*: true', output) is not None)
    name = re.search(r'certificate DN: (.+)', output)
    digest = re.search(r'certificate SHA-256 digest: (\S+)', output)
    if name and digest:
        print(f'        signiert von: {name.group(1)}')
        print(f'        Zertifikat SHA-256: {digest.group(1)}')

    print(f'\nAPK: {passed} Prüfungen bestanden, {len(failures)} fehlgeschlagen')
    if failures:
        for failure in failures:
            print(f'  - {failure}')
        sys.exit(1)


if __name__ == '__main__':
    main()
