#!/usr/bin/env python3
"""Check iOS Firebase client configuration without printing keys or tokens.
This is a local readiness check, not proof of provider enablement or login.
"""
import argparse
import plistlib
from pathlib import Path
import sys

BUNDLE_ID = 'com.komronkhisomov.zikradventure'


def check(path):
    if not path.is_file():
        return ['Configuration file not found.']
    try:
        with path.open('rb') as source:
            config = plistlib.load(source)
    except (OSError, plistlib.InvalidFileException, ValueError):
        return ['Cannot read a valid property list.']
    if not isinstance(config, dict):
        return ['Configuration must be a dictionary.']
    errors = []
    for field in ['API_KEY', 'GOOGLE_APP_ID', 'PROJECT_ID', 'GCM_SENDER_ID', 'CLIENT_ID', 'REVERSED_CLIENT_ID']:
        value = config.get(field)
        if not isinstance(value, str) or not value.strip():
            errors.append(f'{field} is missing or empty.')
        elif any(word in value.lower() for word in ['placeholder', 'replace_me', 'your_project', 'example']):
            errors.append(f'{field} contains a placeholder.')
    if config.get('BUNDLE_ID') != BUNDLE_ID:
        errors.append('BUNDLE_ID does not match the existing app.')
    client = config.get('CLIENT_ID', '')
    if isinstance(client, str) and client:
        if not client.endswith('.apps.googleusercontent.com'):
            errors.append('CLIENT_ID is not an iOS Google OAuth client ID.')
        elif config.get('REVERSED_CLIENT_ID') != '.'.join(reversed(client.split('.'))):
            errors.append('REVERSED_CLIENT_ID does not match CLIENT_ID.')
    if config.get('IS_SIGNIN_ENABLED') is False:
        errors.append('IS_SIGNIN_ENABLED is false; download current config after enabling Google.')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('plist', type=Path, nargs='?', default=Path('/private/tmp/zikr-firebase/GoogleService-Info.plist'))
    args = parser.parse_args()
    errors = check(args.plist)
    if errors:
        for error in errors:
            print('FAIL:', error)
        return 1
    print('PASS: local config is structurally consistent with this iOS app.')
    print('NOT VERIFIED: provider enablement, Firebase project ownership, Apple capability, signing, network login, and account deletion.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
