#!/usr/bin/env python3
"""URLの一覧（1行1件、サイト内パス）を1秒に1件取得してキャッシュする。取得済みは飛ばす。

使い方: crawl_pages.py <サイトのURL> <パス一覧ファイル> <キャッシュフォルダー>
保存名はパスの「/」を「__」に置き換えたもの。
"""
import os, sys, time, urllib.parse, urllib.request, urllib.error

UA = "Mozilla/5.0 (Macintosh) FontDB-crawler (personal use)"

def main():
    base, listfile, out = sys.argv[1].rstrip("/"), sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    for path in open(listfile).read().split():
        dest = os.path.join(out, path.strip("/").replace("/", "__"))
        if os.path.exists(dest):
            continue
        # 名前解決の失敗など一時的なエラーは間をおいて3回まで試す
        for attempt in range(3):
            try:
                with urllib.request.urlopen(urllib.request.Request(base + urllib.parse.quote(path, safe="/%?=&"), headers={"User-Agent": UA}), timeout=30) as r:
                    data = r.read()
                with open(dest, "wb") as f:
                    f.write(data)
                break
            except urllib.error.HTTPError as e:
                print(path, e.code, flush=True)
                break
            except (urllib.error.URLError, OSError) as e:
                print(path, "retry", e, flush=True)
                time.sleep(15)
        time.sleep(1)

if __name__ == "__main__":
    main()
