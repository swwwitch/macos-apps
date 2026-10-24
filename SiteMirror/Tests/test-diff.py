#!/usr/bin/env python3
"""Run the real crawler against a local fixture; no user files or external sites."""
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import functools, subprocess, tempfile, threading
app = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='SiteMirror-diff-', dir='/private/tmp') as temp:
    work = Path(temp)
    site = work / 'site'
    site.mkdir()
    class Handler(SimpleHTTPRequestHandler):
        def do_GET(self):
            if self.path == '/temporary.html' and (site / 'stage2').exists():
                self.send_error(503)
            else:
                super().do_GET()
        def log_message(self, *args):
            pass
    server = ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Handler, directory=str(site)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        sources = [app / 'Sources/SiteMirror' / name for name in ['Localization.swift', 'SiteLinks.swift', 'Crawler.swift', 'MirrorDiff.swift']]
        binary = work / 'tests'
        subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(work / 'cache'), *map(str, sources), str(app / 'Tests/MirrorDiffTests.swift'), '-o', str(binary)], check=True)
        subprocess.run([str(binary), f'http://127.0.0.1:{server.server_port}', str(site)], check=True, timeout=60)
    finally:
        server.shutdown()
