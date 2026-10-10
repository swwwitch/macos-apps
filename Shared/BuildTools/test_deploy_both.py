import importlib.util
from pathlib import Path
import plistlib
import shutil
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location('deploy', Path(__file__).with_name('deploy_both.py'))
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)

class DeploymentTests(unittest.TestCase):
    def test_rollback_restores_both_copies(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); apps = root/'Applications'; apps.mkdir()
            latest = root/'Latest Builds'; latest.mkdir()
            source = root/'build'/'Test.app'
            def make(p, marker):
                (p/'Contents').mkdir(parents=True)
                (p/'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='test.app', CFBundleShortVersionString='1', CFBundleVersion='1', CFBundleExecutable='Test')))
                (p/'marker').write_text(marker)
            make(source, 'new'); make(apps/'Test.app', 'old-app'); make(latest/'Test.app', 'old-latest')
            def run(args, **kwargs):
                if args[0] == 'pgrep': return SimpleNamespace(returncode=1)
                if args[0] == 'ditto': shutil.copytree(args[1], args[2]); return SimpleNamespace(returncode=0)
                raise AssertionError(args)
            def verify(p):
                if p == latest/'Test.app' and (p/'marker').read_text() == 'new': raise RuntimeError('injected verification failure')
            with patch.object(deploy, 'ROOT', root), patch.object(deploy, 'Path', side_effect=lambda p: apps if p == '/Applications' else Path(p)), patch.object(deploy, 'verify', side_effect=verify), patch.object(deploy.subprocess, 'run', side_effect=run), patch.object(deploy.sys, 'argv', ['deploy',str(source)]):
                with self.assertRaises(RuntimeError): deploy.main()
            self.assertEqual((apps/'Test.app/marker').read_text(), 'old-app')
            self.assertEqual((latest/'Test.app/marker').read_text(), 'old-latest')
            self.assertEqual((source/'marker').read_text(), 'new')
    def test_process_check_failure_stops_before_replacement(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'Test.app'; (source/'Contents').mkdir(parents=True)
            (source/'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='test.app', CFBundleShortVersionString='1', CFBundleVersion='1', CFBundleExecutable='Test')))
            with patch.object(deploy,'verify'), patch.object(deploy.subprocess,'run',return_value=SimpleNamespace(returncode=3)), patch.object(deploy.sys,'argv',['deploy',str(source)]):
                with self.assertRaisesRegex(SystemExit,'Cannot check'): deploy.main()

if __name__ == '__main__': unittest.main()
