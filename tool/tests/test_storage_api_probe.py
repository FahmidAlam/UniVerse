import base64
import json
from pathlib import Path
import sys
import unittest
from contextlib import redirect_stdout
from io import StringIO

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    import storage_api_probe as probe
except ModuleNotFoundError:
    probe = None


def jwt(role):
    payload = base64.urlsafe_b64encode(json.dumps({"role": role}).encode()).decode().rstrip("=")
    return "eyJhbGciOiJIUzI1NiJ9." + payload + ".test"


class ProbeSafetyTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(probe, "Storage probe is not implemented")

    def test_production_or_arbitrary_target_is_rejected(self):
        for ref in ("yxqyrjyzxitrgkhgauli", "another-project", "oqwvxplteqtlrhktsplj.attacker"):
            with self.subTest(ref=ref), self.assertRaises(ValueError):
                probe.validate_target(ref)
        self.assertEqual(probe.validate_target("oqwvxplteqtlrhktsplj"),
                         "https://oqwvxplteqtlrhktsplj.supabase.co")

    def test_privileged_or_malformed_keys_are_rejected(self):
        for key in (jwt("service_role"), jwt("authenticated"), "sb_secret_private", "garbage"):
            with self.subTest(key_type=key[:9]), self.assertRaises(ValueError):
                probe.validate_public_key(key)
        self.assertEqual(probe.validate_public_key(jwt("anon")), jwt("anon"))
        self.assertEqual(probe.validate_public_key("sb_publishable_test"), "sb_publishable_test")

    def test_storage_wrapped_rls_denial_is_recognized_but_other_errors_are_not(self):
        self.assertTrue(probe.denied(400, b'{"statusCode":"403","error":"Unauthorized"}'))
        self.assertTrue(probe.denied(403, b'{}'))
        for status, body in ((400, b'{"statusCode":"404"}'), (500, b'failure'),
                             (200, b'[]'), (400, b'bad input')):
            self.assertFalse(probe.denied(status, body))

    def test_api_failure_does_not_include_response_secrets(self):
        with self.assertRaises(probe.ProbeFailure) as caught:
            probe.require_ok(400, b'{"access_token":"PRIVATE"}', "sign-in")
        self.assertNotIn("PRIVATE", str(caught.exception))
        self.assertIn("400", str(caught.exception))

    def test_existing_namespace_is_rejected_without_cleanup_deletion(self):
        class ExistingFolder:
            removed = False

            def listing(self, token, prefix):
                return [{"name": "user-a.txt"}]

            def remove(self, token, paths):
                self.removed = True

        api = ExistingFolder()
        with redirect_stdout(StringIO()), self.assertRaises(probe.ProbeFailure):
            probe.run_probe(api, "user-a", "user-b")
        self.assertFalse(api.removed, "Never clean up a namespace that was already populated")


if __name__ == "__main__":
    unittest.main()
