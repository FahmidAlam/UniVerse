"""Batch invite-admin handler denial checks in universe-timetable-test only.

Deploy recovered invite-admin/index.ts as invite-admin-auth-test first.
All requests contain {}: none contains a recipient email or requests an invite.
"""
import argparse
import getpass
import json
import sys

from storage_api_probe import Api, ProbeFailure, require, validate_target


def check_invite_denials(api, tokens):
    cases = [
        (None, 401, 'Missing authorization header.', 'missing authorization'),
        ('synthetic-invalid-token', 401, 'Invalid session.', 'invalid session'),
        (tokens[0], 403, 'Only admins can invite admins.', 'ordinary user A'),
        (tokens[1], 403, 'Only admins can invite admins.', 'ordinary user B'),
    ]
    for token, expected_status, expected_error, label in cases:
        status, body = api.request('POST', '/functions/v1/invite-admin-auth-test', token, {})
        try:
            error = json.loads(body).get('error')
        except (ValueError, AttributeError):
            error = None
        require(status == expected_status and error == expected_error,
                f'{label}: unexpected handler response (HTTP {status}); '
                'response withheld. Check test deployment and its gateway JWT setting.')
    return len(cases)


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    if not sys.stdin.isatty():
        print('Use an interactive terminal for hidden credential input.')
        return 1
    try:
        ref = input('Test project reference: ').strip()
        validate_target(ref)
        api = Api(ref, getpass.getpass('Test publishable/legacy anon key (hidden): ').strip())
        tokens, ids = [], []
        for email in ('storage-a@example.invalid', 'storage-b@example.invalid'):
            password = getpass.getpass(f'Password for {email} (hidden): ')
            token, user_id = api.login(email, password)
            del password
            tokens.append(token)
            ids.append(user_id)
        require(ids[0] != ids[1], 'Two distinct controlled users are required')
        count = check_invite_denials(api, tokens)
        print(f'PASS: {count} invite-admin handler denial checks; only empty payloads sent')
        print('No invitation, whitelist write or email was requested.')
        return 0
    except (ProbeFailure, ValueError) as error:
        print('FAIL:', str(error))
        return 1
    except (KeyboardInterrupt, EOFError):
        print('Stopped; credentials were not printed.')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
