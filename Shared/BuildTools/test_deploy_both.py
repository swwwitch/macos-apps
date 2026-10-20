import importlib.util
import os
from distribution_paths import latest_builds_dir, DEFAULT_LATEST_BUILDS
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
            with patch.object(deploy, 'latest_builds_dir', return_value=latest), patch.object(deploy, 'ROOT', root), patch.object(deploy, 'Path', side_effect=lambda p: apps if p == '/Applications' else Path(p)), patch.object(deploy, 'verify', side_effect=verify), patch.object(deploy.subprocess, 'run', side_effect=run), patch.object(deploy.sys, 'argv', ['deploy',str(source)]):
                with self.assertRaises(RuntimeError): deploy.main()
            self.assertEqual((apps/'Test.app/marker').read_text(), 'old-app')
            self.assertEqual((latest/'Test.app/marker').read_text(), 'old-latest')
            self.assertEqual((source/'marker').read_text(), 'new')
    def test_external_distribution_and_readme(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp); root = base/'checkout'; root.mkdir()
            apps = base/'Applications'; apps.mkdir()
            latest = base/'Dropbox'/'Latest Builds'; latest.mkdir(parents=True)
            (root/'Latest Builds').mkdir()
            (root/'Latest Builds/README.md').write_text('checkout unchanged')
            readme = latest/'README.md'
            readme.write_text('| [Test](Test.app) | 0 | 0 | description |\n')
            source = root/'build/Test.app'; (source/'Contents').mkdir(parents=True)
            (source/'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='test.app', CFBundleShortVersionString='2', CFBundleVersion='3', CFBundleExecutable='Test')))
            def run(args, **kwargs):
                if args[0] == 'pgrep': return SimpleNamespace(returncode=1)
                if args[0] == 'ditto': shutil.copytree(args[1], args[2]); return SimpleNamespace(returncode=0)
                raise AssertionError(args)
            with patch.dict(os.environ, {'SW_APP_LATEST_BUILDS': str(latest), 'NO_DEPLOY': '0'}), patch.object(deploy, 'ROOT', root), patch.object(deploy, 'Path', side_effect=lambda p: apps if p == '/Applications' else Path(p)), patch.object(deploy, 'verify'), patch.object(deploy.subprocess, 'run', side_effect=run), patch.object(deploy.sys, 'argv', ['deploy', str(source)]):
                deploy.main()
            self.assertEqual(deploy.manifest(source), deploy.manifest(latest/'Test.app'))
            self.assertEqual(deploy.manifest(source), deploy.manifest(apps/'Test.app'))
            self.assertIn('| 2 | 3 |', readme.read_text())
            self.assertEqual((root/'Latest Builds/README.md').read_text(), 'checkout unchanged')
            self.assertFalse((root/'Latest Builds/Test.app').exists())

    def test_default_distribution_path(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(latest_builds_dir(), DEFAULT_LATEST_BUILDS)
            self.assertEqual(latest_builds_dir(), Path.home()/'sw Dropbox/takano masahiro/Dropbox-shared/sw_app/Latest Builds')

    def test_process_check_failure_stops_before_replacement(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'Test.app'; (source/'Contents').mkdir(parents=True)
            (source/'Contents/Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='test.app', CFBundleShortVersionString='1', CFBundleVersion='1', CFBundleExecutable='Test')))
            with patch.object(deploy,'verify'), patch.object(deploy.subprocess,'run',return_value=SimpleNamespace(returncode=3)), patch.object(deploy.sys,'argv',['deploy',str(source)]):
                with self.assertRaisesRegex(SystemExit,'Cannot check'): deploy.main()

if __name__ == '__main__': unittest.main()
