import os
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import audit_installed_apps as audit


class AuditTests(unittest.TestCase):
    def make(self, path, binary=True):
        (path / 'Contents/MacOS').mkdir(parents=True)
        (path / 'Contents/Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': 'test.app', 'CFBundleExecutable': 'Test',
            'CFBundleVersion': '3', 'CFBundleShortVersionString': '1.0'}))
        if binary:
            target = path / 'Contents/MacOS/Test'
            target.write_bytes(b'test binary')
            target.chmod(0o755)

    @patch.object(audit.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='Mach-O', stderr=''))
    def test_missing_executable_despite_successful_signature_command(self, run):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp) / 'Test.app'
            self.make(app, False)
            self.assertIn('executable_missing', audit.inspect(app)['issues'])

    @patch.object(audit.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='Mach-O', stderr=''))
    def test_permission_and_content_difference(self, run):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for location in ('Applications', 'Latest'):
                self.make(root / location / 'Test.app')
            binary = root / 'Applications/Test.app/Contents/MacOS/Test'
            binary.chmod(0o644)
            row = audit.audit_pair('Test.app', root / 'Latest', root / 'Applications')
            self.assertIn('executable_not_executable', row['Applications']['issues'])
            self.assertFalse(row['content_matches'])
            self.assertEqual(binary.read_bytes(), b'test binary')

    def test_absent_app_and_invalid_plist(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp) / 'Test.app'
            self.assertEqual(audit.inspect(app)['issues'], ['app_missing'])
            (app / 'Contents').mkdir(parents=True)
            (app / 'Contents/Info.plist').write_text('broken')
            self.assertIn('inspection_failed', audit.inspect(app)['issues'])

    @patch.object(audit.subprocess, 'run', return_value=SimpleNamespace(returncode=1, stdout='', stderr='invalid resource'))
    def test_signature_error_kept(self, run):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp) / 'Test.app'; self.make(app)
            row = audit.inspect(app)
            self.assertIn('signature_invalid', row['issues'])
            self.assertEqual(row['signature_error'], 'invalid resource')


if __name__ == '__main__':
    unittest.main()
