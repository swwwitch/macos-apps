import urllib.request,json,pathlib,hashlib,tarfile,shutil
root=pathlib.Path(__file__).resolve().parent.parent
r=json.load(urllib.request.urlopen('https://api.github.com/repos/typst/typst/releases/tags/v0.15.1'))
a=next(x for x in r['assets'] if x['name']=='typst-aarch64-apple-darwin.tar.xz')
data=urllib.request.urlopen(a['browser_download_url']).read()
if 'sha256:'+hashlib.sha256(data).hexdigest()!=a['digest']: raise RuntimeError('Official asset digest mismatch')
p=pathlib.Path('/tmp/carma-typst.tar.xz');p.write_bytes(data)
with tarfile.open(p) as t:
 for m in t.getmembers():
  if m.name.startswith('/') or '..' in pathlib.PurePosixPath(m.name).parts or m.issym() or m.islnk(): raise RuntimeError('Unsafe archive member')
 t.extractall('/tmp/carma-typst')
s=pathlib.Path('/tmp/carma-typst/typst-aarch64-apple-darwin')
shutil.copy2(s/'typst',root/'Vendor/typst')
for n in ['LICENSE','NOTICE']:
 if (s/n).exists():shutil.copy2(s/n,root/'Resources'/('typst-'+n))
(root/'Vendor/typst-release.json').write_text(json.dumps({'version':'0.15.1','url':a['browser_download_url'],'sha256':hashlib.sha256(data).hexdigest()},indent=2)+'\n')
print('Verified Typst 0.15.1 bundled')
