import base64
import unittest
from configure import validate

class ConfigurationTests(unittest.TestCase):
    # Public key from RFC 8032 test vector 1, never used for a release.
    key = base64.b64encode(bytes.fromhex('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a')).decode()
    def config(self, **values):
        result = dict(SUFeedURL='https://updates.test/appcast.xml', SUPublicEDKey=self.key)
        result.update(values)
        return result
    def test_valid_shape(self):
        self.assertEqual(validate(self.config()), self.config())
    def test_reject_missing_fields(self):
        for config in ({}, {'SUFeedURL':'https://updates.test/appcast.xml'}):
            with self.assertRaises(ValueError): validate(config)
    def test_reject_insecure_or_fake_feed(self):
        for url in ['http://updates.test/appcast.xml','file:///tmp/appcast.xml','https://','https://u:p@updates.test/a','https://updates.test/a#fragment','https://example.com/a','https://app.invalid/a','https://localhost/a']:
            with self.subTest(url=url), self.assertRaises(ValueError): validate(self.config(SUFeedURL=url))
    def test_reject_invalid_key(self):
        for key in ['', 'not-base64', base64.b64encode(bytes(32)).decode(), base64.b64encode(bytes(31)).decode()]:
            with self.subTest(key_length=len(key)), self.assertRaises(ValueError): validate(self.config(SUPublicEDKey=key))
    def test_no_security_overrides(self):
        with self.assertRaises(ValueError): validate(self.config(SURequireSignedFeed=False))
if __name__ == '__main__': unittest.main()
