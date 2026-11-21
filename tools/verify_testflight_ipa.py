#!/usr/bin/env python3
"""Verify exported IPA metadata, distribution signature/profile and requested entitlements."""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    project = root / 'ZikrAdventure-1.0.1'
    yml = (project / 'project.yml').read_text()
    version = re.search(r'MARKETING_VERSION:\s*"([^"]+)"', yml)[1]
    build = re.search(r'CURRENT_PROJECT_VERSION:\s*"?([0-9]+)', yml)[1]
    team = re.search(r'DEVELOPMENT_TEAM:\s*"([^"]+)"', yml)[1]
    requested = plistlib.loads((project / 'ZikrAdventure/ZikrAdventure.entitlements').read_bytes())
    with tempfile.TemporaryDirectory(prefix='zikr-ipa-check-') as directory:
        subprocess.run(['ditto', '-x', '-k', str(args.ipa.resolve()), directory], check=True)
        apps = list((Path(directory) / 'Payload').glob('*.app'))
        if len(apps) != 1:
            raise RuntimeError('Expected one iPhone app in IPA')
        app = apps[0]
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        expected = ('com.komronkhisomov.zikradventure', version, build)
        actual = tuple(info.get(k) for k in ('CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion'))
        if actual != expected:
            raise RuntimeError('IPA bundle/version/build does not match project')
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True, capture_output=True)
        signed = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)], check=True, capture_output=True)
        entitlements = plistlib.loads(signed.stdout)
        if entitlements.get('application-identifier') != team + '.' + expected[0] or entitlements.get('get-task-allow', False):
            raise RuntimeError('Unexpected Team/app identifier or development entitlement')
        if any(entitlements.get(key) != value for key, value in requested.items()):
            raise RuntimeError('Requested entitlements missing/changed in exported IPA')
        profile = subprocess.run(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')],
                                 check=True, capture_output=True)
        profile = plistlib.loads(profile.stdout)
        if profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices') or not profile['Entitlements'].get('beta-reports-active'):
            raise RuntimeError('Expected App Store distribution profile')
        if team not in profile.get('TeamIdentifier', []) or profile['ExpirationDate'] <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
            raise RuntimeError('Unexpected/expired distribution profile')
        firebase = plistlib.loads((app / 'GoogleService-Info.plist').read_bytes())
        if firebase.get('BUNDLE_ID') != expected[0]:
            raise RuntimeError('Firebase configuration missing or mismatched')
    result = {'version': version, 'build': build, 'bundle_id': expected[0],
              'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
              'ipa_sha256': hashlib.sha256(args.ipa.read_bytes()).hexdigest(), 'ipa_bytes': args.ipa.stat().st_size,
              'codesign_verified': True, 'requested_entitlements_verified': True,
              'firebase_bundle_matches': True, 'development_entitlement': False}
    if args.output:
        args.output.write_text(json.dumps(result, indent=2))
    print(json.dumps(result))


if __name__ == '__main__':
    main()
