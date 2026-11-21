#!/usr/bin/env python3
"""Read-only ASC preflight; --apply-build updates both project files after a successful lookup.
Requires PyJWT + cryptography. Never prints the signing key or JWT.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


def main():
    # The ignored local file contains identifiers only; never source/evaluate shell code.
    local = {}
    local_file = Path(__file__).resolve().parents[1] / '.env.appstoreconnect'
    if local_file.exists():
        for line in local_file.read_text().splitlines():
            name, sep, value = line.partition('=')
            if sep and name.strip() == 'ASC_ISSUER_ID':
                local[name.strip()] = value.strip()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--issuer-id', default=os.environ.get('ASC_ISSUER_ID') or local.get('ASC_ISSUER_ID'))
    parser.add_argument('--key-path', type=Path, default=os.environ.get('ASC_KEY_PATH'))
    parser.add_argument('--apply-build', action='store_true')
    args = parser.parse_args()
    if not args.issuer_id:
        parser.error('Set ASC_ISSUER_ID or --issuer-id (not the private key).')
    key = args.key_path
    if key is None:
        keys = list((Path.home() / '.appstoreconnect/private_keys').glob('AuthKey_*.p8'))
        if len(keys) != 1:
            parser.error('Select ASC_KEY_PATH; expected exactly one AuthKey_*.p8.')
        key = keys[0]
    match = re.fullmatch(r'AuthKey_([A-Za-z0-9]+)\.p8', key.name)
    if not match:
        parser.error('Key filename must be AuthKey_KEYID.p8.')
    import jwt
    now = int(time.time())
    token = jwt.encode({'iss': args.issuer_id, 'iat': now, 'exp': now + 600,
                        'aud': 'appstoreconnect-v1'}, key.read_bytes(), algorithm='ES256',
                       headers={'kid': match[1], 'typ': 'JWT'})

    def get(url):
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme != 'https' or parsed.netloc != 'api.appstoreconnect.apple.com':
            raise RuntimeError('Unexpected ASC pagination host.')
        request = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token})
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)

    base = 'https://api.appstoreconnect.apple.com/v1/'
    query = urllib.parse.urlencode({'filter[bundleId]': 'com.komronkhisomov.zikradventure', 'limit': 5})
    apps = get(base + 'apps?' + query)['data']
    if len(apps) != 1:
        raise RuntimeError('Expected one Zikr Adventure app; no project files changed.')
    app_id = apps[0]['id']
    url = base + 'builds?' + urllib.parse.urlencode({'filter[app]': app_id, 'limit': 200})
    builds = []
    while url:
        response = get(url)
        builds.extend(b['attributes']['version'] for b in response['data'])
        url = response.get('links', {}).get('next')
    if any(not re.fullmatch(r'[0-9]+', value) for value in builds):
        raise RuntimeError('Non-integer existing build numbers: manual version selection required.')
    root = Path(__file__).resolve().parents[1]
    project = root / 'ZikrAdventure-1.0.1'
    yml = project / 'project.yml'
    pbx = project / 'ZikrAdventure.xcodeproj/project.pbxproj'
    ytext, ptext = yml.read_text(), pbx.read_text()
    current = int(re.search(r'CURRENT_PROJECT_VERSION:\s*"?([0-9]+)', ytext)[1])
    last = max(map(int, builds), default=0)
    selected = max(last, current) + 1
    print(json.dumps({'app_id': app_id, 'last_uploaded_build': last,
                      'proposed_version': '1.2.0', 'proposed_build': selected,
                      'project_updated': False}))
    if args.apply_build:
        branch = subprocess.check_output(['git', 'branch', '--show-current'], cwd=root, text=True).strip()
        if not branch.startswith('codex/'):
            raise RuntimeError('Apply only on a codex task branch; never main/release directly.')
        ytext, yn = re.subn(r'CURRENT_PROJECT_VERSION:\s*"?[0-9]+"?',
                            f'CURRENT_PROJECT_VERSION: "{selected}"', ytext)
        ptext, pn = re.subn(r'CURRENT_PROJECT_VERSION = [0-9]+;',
                            f'CURRENT_PROJECT_VERSION = {selected};', ptext)
        if yn != 1 or pn != 2:
            raise RuntimeError('Unexpected project format; no files changed.')
        if 'MARKETING_VERSION: "1.2.0"' not in ytext or ptext.count('MARKETING_VERSION = 1.2.0;') != 2:
            raise RuntimeError('Set version 1.2.0 consistently before choosing the build.')
        yml.write_text(ytext)
        pbx.write_text(ptext)
        print(json.dumps({'project_updated': True, 'build': selected}))


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        try:
            payload = json.loads(error.read())
            details = [{k: e.get(k) for k in ('code', 'title', 'detail')} for e in payload.get('errors', [])]
        except (ValueError, TypeError):
            details = [{'title': 'ASC request rejected'}]
        print(json.dumps({'http_status': error.code, 'errors': details, 'project_updated': False}), file=sys.stderr)
        sys.exit(2)
    except (RuntimeError, OSError, ImportError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
