from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    from task1_invite_checks import check_invite_denials
except ModuleNotFoundError:
    check_invite_denials = None
from storage_api_probe import ProbeFailure


class InviteChecksTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(check_invite_denials, 'Invite denial probe is not implemented')

    def test_only_empty_payloads_are_sent_and_expected_denials_pass(self):
        class Api:
            calls = []

            def request(self, method, path, token=None, data=None):
                self.calls.append((method, path, token, data))
                if token is None:
                    return 401, b'{"error":"Missing authorization header."}'
                if token == 'synthetic-invalid-token':
                    return 401, b'{"error":"Invalid session."}'
                return 403, b'{"error":"Only admins can invite admins."}'

        api = Api()
        self.assertEqual(check_invite_denials(api, ['a', 'b']), 4)
        self.assertEqual(len(api.calls), 4)
        for method, path, _, body in api.calls:
            self.assertEqual((method, path, body), ('POST', '/functions/v1/invite-admin-auth-test', {}))

    def test_gateway_denial_is_not_mistaken_for_handler_verification(self):
        class Api:
            def request(self, *args, **kwargs):
                return 401, b'{"code":401,"message":"Missing authorization header"}'

        with self.assertRaises(ProbeFailure):
            check_invite_denials(Api(), ['a', 'b'])

    def test_unexpected_success_or_error_never_prints_response_secrets(self):
        for status in (200, 400, 500):
            class Api:
                def request(self, *args, **kwargs):
                    return status, b'{"access_token":"PRIVATE"}'

            with self.assertRaises(ProbeFailure) as caught:
                check_invite_denials(Api(), ['a', 'b'])
            self.assertNotIn('PRIVATE', str(caught.exception))


if __name__ == '__main__':
    unittest.main()
