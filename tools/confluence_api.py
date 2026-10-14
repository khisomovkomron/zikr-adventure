#!/usr/bin/env python3
"""Confluence API client; shares local Atlassian credentials with the Jira client."""
import argparse, base64, json, os, sys, urllib.request, urllib.error
p = argparse.ArgumentParser()
p.add_argument('action', choices=['spaces', 'pages', 'get', 'create', 'update'])
p.add_argument('--space-id'); p.add_argument('--page-id'); p.add_argument('--body-file')
a = p.parse_args()
path = os.environ.get('JIRA_CREDENTIAL_FILE', '/private/tmp/zikr-jira-credentials.json')
with open(path) as f: creds = json.load(f)
email = os.environ.get('JIRA_EMAIL') or creds['email']
token = os.environ.get('JIRA_API_TOKEN') or creds['token']
cloud_id = os.environ.get('JIRA_CLOUD_ID') or creds.get('cloud_id')
base = f'https://api.atlassian.com/ex/confluence/{cloud_id}' if cloud_id else 'https://zikr-app.atlassian.net/wiki'
endpoint = '/api/v2/spaces?limit=100'
method = 'GET'; body = None
if a.action == 'pages':
    if not a.space_id or not a.space_id.isdigit(): p.error('--space-id is required (numeric)')
    endpoint = f'/api/v2/spaces/{a.space_id}/pages?limit=100'
elif a.action in ['get','update']:
    if not a.page_id or not a.page_id.isdigit(): p.error('--page-id is required (numeric)')
    endpoint = f'/api/v2/pages/{a.page_id}?body-format=storage'
elif a.action == 'create': endpoint = '/api/v2/pages'
if a.action in ['create','update']:
    if not a.body_file: p.error('--body-file is required')
    with open(a.body_file) as f: body = json.load(f)
    method = 'POST' if a.action == 'create' else 'PUT'
    endpoint = endpoint.split('?')[0]
req = urllib.request.Request(base + endpoint, method=method,
    data=json.dumps(body).encode() if body is not None else None,
    headers={'Authorization':'Basic '+base64.b64encode(f'{email}:{token}'.encode()).decode(),
             'Accept':'application/json','Content-Type':'application/json'})
try:
    with urllib.request.urlopen(req, timeout=30) as r: result=json.load(r)
except urllib.error.HTTPError as e:
    sys.exit(f'Confluence returned HTTP {e.code}. Check product access and token scopes.')
except urllib.error.URLError:
    sys.exit('Could not connect to Confluence.')
print(json.dumps(result,ensure_ascii=False,indent=2))
