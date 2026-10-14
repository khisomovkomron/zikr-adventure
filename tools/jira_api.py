#!/usr/bin/env python3
"""Jira REST client. Credentials stay in environment variables, never in output."""
import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['check', 'versions', 'version-create', 'inspect', 'get', 'transitions', 'transition', 'create', 'update'])
    parser.add_argument('--issue', help='Issue key for update')
    parser.add_argument('--body-file', help='JSON request body for create/update')
    args = parser.parse_args()
    credential_path = os.environ.get('JIRA_CREDENTIAL_FILE', '/private/tmp/zikr-jira-credentials.json')
    credentials = {}
    if os.path.exists(credential_path):
        with open(credential_path) as source:
            credentials = json.load(source)
    email = os.environ.get('JIRA_EMAIL') or credentials.get('email')
    token = os.environ.get('JIRA_API_TOKEN') or credentials.get('token')
    if not email or not token:
        sys.exit('Set JIRA_EMAIL and JIRA_API_TOKEN in the calling environment.')
    cloud_id = os.environ.get('JIRA_CLOUD_ID') or credentials.get('cloud_id')
    base = (f'https://api.atlassian.com/ex/jira/{cloud_id}' if cloud_id
            else 'https://zikr-app.atlassian.net')
    auth = base64.b64encode(f'{email}:{token}'.encode()).decode()

    def request(path, method='GET', body=None):
        req = urllib.request.Request(base + '/rest/api/3/' + path,
            data=json.dumps(body).encode() if body is not None else None,
            headers={'Authorization': 'Basic ' + auth,
                     'Accept': 'application/json', 'Content-Type': 'application/json'},
            method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                raw = response.read()
                return json.loads(raw) if raw else {'status': response.status}
        except urllib.error.HTTPError as error:
            sys.exit(f'Jira returned HTTP {error.code}. Check token scopes and project permissions.')
        except urllib.error.URLError:
            sys.exit('Could not connect to Jira.')

    if args.action == 'versions':
        print(json.dumps(request('project/KAN/versions'), indent=2))
    elif args.action == 'version-create':
        if not args.body_file: parser.error('--body-file is required')
        with open(args.body_file) as source: body = json.load(source)
        body['projectId'] = int(request('project/KAN')['id'])
        print(json.dumps(request('version', 'POST', body), indent=2))
    elif args.action in ['get', 'transitions', 'transition']:
        if not args.issue or not args.issue.startswith('KAN-') or not args.issue[4:].isdigit():
            parser.error('--issue must be a KAN issue key')
        path = 'issue/' + args.issue + ('/transitions' if args.action != 'get' else '')
        if args.action == 'transition':
            if not args.body_file: parser.error('--body-file is required')
            with open(args.body_file) as source: body = json.load(source)
            result = request(path, 'POST', body)
        else: result = request(path)
        print(json.dumps(result, indent=2))
    elif args.action == 'inspect':
        project = request('project/KAN')
        issues = request('search/jql?jql=project%3DKAN&maxResults=100&fields=summary,status,description,fixVersions')
        statuses = request('project/KAN/statuses')
        print(json.dumps({'issueTypes': project.get('issueTypes'), 'statuses': statuses, 'issues': issues}, indent=2))
    elif args.action == 'check':
        user = request('myself')
        project = request('project/KAN')
        print(json.dumps({'authenticated': bool(user.get('accountId')),
                          'project': project.get('key'), 'name': project.get('name')}, indent=2))
    else:
        if not args.body_file:
            parser.error('--body-file is required')
        if args.action == 'update' and (not args.issue or not args.issue.startswith('KAN-') or not args.issue[4:].isdigit()):
            parser.error('--issue must be a KAN issue key')
        with open(args.body_file) as source:
            body = json.load(source)
        if args.action == 'create':
            body.setdefault('fields', {})['project'] = {'key': 'KAN'}
        result = request('issue' if args.action == 'create' else 'issue/' + args.issue,
                         'POST' if args.action == 'create' else 'PUT', body)
        print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
