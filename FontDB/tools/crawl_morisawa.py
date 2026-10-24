#!/usr/bin/env python3
"""モリサワ書体見本の詳細ページ（/fonts/specimen/detail/<ID>）を ID 順に取得してキャッシュする。

使い方: crawl_morisawa.py <キャッシュフォルダー> [開始ID] [終了ID]
取得済みの ID は飛ばす。1秒に1件。
"""
import os, sys, time, urllib.request, urllib.error

BASE = "https://www.morisawa.co.jp/fonts/specimen/detail/%d"
UA = "Mozilla/5.0 (Macintosh) FontDB-crawler (personal use)"

def main():
    out = sys.argv[1]
    start = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    end = int(sys.argv[3]) if len(sys.argv) > 3 else 4000
    os.makedirs(out, exist_ok=True)
    missing_path = os.path.join(out, "_404.txt")
    missing = set()
    if os.path.exists(missing_path):
        missing = {int(x) for x in open(missing_path).read().split()}
    for i in range(start, end + 1):
        path = os.path.join(out, "%d.html" % i)
        if os.path.exists(path) or i in missing:
            continue
        req = urllib.request.Request(BASE % i, headers={"User-Agent": UA})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=30) as r:
                    data = r.read()
                with open(path, "wb") as f:
                    f.write(data)
                break
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    with open(missing_path, "a") as f:
                        f.write("%d\n" % i)
                    break
                time.sleep(10)
            except Exception:
                time.sleep(10)
        time.sleep(1)
        if i % 100 == 0:
            print(i, flush=True)

if __name__ == "__main__":
    main()
