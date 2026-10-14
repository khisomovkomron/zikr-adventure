#!/usr/bin/env python3
"""Run manually to save a Jira token outside the repository without echoing it."""
import getpass
import json
import os

email = input('Atlassian email: ').strip()
token = getpass.getpass('API token (hidden): ').strip()
cloud_id = input('Cloud ID (scoped token only; otherwise Enter): ').strip()
if not email or not token:
    raise SystemExit('Email and token are required.')
path = '/private/tmp/zikr-jira-credentials.json'
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
os.fchmod(fd, 0o600)
with os.fdopen(fd, 'w') as target:
    json.dump({'email': email, 'token': token, 'cloud_id': cloud_id}, target)
print('Credentials saved locally. Token was not printed.')
