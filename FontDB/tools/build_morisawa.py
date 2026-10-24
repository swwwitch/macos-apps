#!/usr/bin/env python3
"""キャッシュした書体見本ページから morisawa.json / morisawa.csv を作る。

使い方: build_morisawa.py <キャッシュフォルダー> <出力フォルダー> [--tsv 発売日・作者TSV] [--fontlist フォントリスト.xlsx]
"""
import argparse, csv, html, json, os, re, sys, unicodedata
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I でも同じフォルダーの部品を読む
import fontlist

URL = "https://www.morisawa.co.jp/fonts/specimen/detail/%d"
CHARSET_RE = re.compile(r"(Pr6N|Pr6|Pr5N|Pr5|ProN|Pro|StdN|Std|Plus)(?=-|$)")

def text(s):
    s = re.sub(r"<br\s*/?>", "\n", s)
    s = re.sub(r"<[^>]+>", "", s)
    return html.unescape(s).strip()

def dd(page, cls):
    m = re.search(r'<dl class="%s">.*?<dd>(.*?)</dd>' % cls, page, re.S)
    return m.group(1) if m else ""

def parse(font_id, page):
    m = re.search(r'<h1 class="cnav-title">(.*?)</h1>', page, re.S)
    if not m:
        return None
    name = text(m.group(1))
    fam = re.search(r"<h2>(.*?)の特徴</h2>", page, re.S)
    desc = re.search(r'<h2>.*?の特徴</h2>\s*<div class="text-box[^"]*">(.*?)</div>', page, re.S)
    menu = re.search(r'<ul class="font-weight-menu[^"]*">(.*?)</ul>', page, re.S)
    weight, weight_order, siblings = "", 0, []
    if menu:
        for n, (href, label) in enumerate(re.findall(r'<a href="([^"]*)"[^>]*>(.*?)</a>', menu.group(1), re.S)):
            sm = re.search(r"/detail/(\d+)", href)
            if sm:
                siblings.append(int(sm.group(1)))
            else:
                weight, weight_order = text(label), n
    links = []
    lb = re.search(r'<div class="link-box">(.*?)</div>', page, re.S)
    if lb:
        for href, label in re.findall(r'<a href="([^"]*)"[^>]*>(.*?)</a>', lb.group(1), re.S):
            links.append({"title": text(label), "url": html.unescape(href)})
    products = [text(x) for x in re.findall(r'<li class="icon-[^"]*">(.*?)</li>', dd(page, "package"), re.S)]
    webfont = ""
    for blob in re.findall(r'\{"fonts":\[.*?\]\}', page):
        try:
            for f in json.loads(blob)["fonts"]:
                if f.get("id") == font_id:
                    webfont = f.get("web_font_param") or ""
        except ValueError:
            pass
    languages = [x for x in re.split(r"[、,\n]\s*", text(dd(page, "lang"))) if x]
    # 欧文の「Pro」は書体名の一部なので、和文のときだけ文字セットとして読む
    cm = CHARSET_RE.search(re.sub(r"-[^-]*$", "", webfont)) if webfont and "日本語" in languages else None
    img = re.search(r'<meta property="og:image" content="([^"]*)"', page)
    return {
        "id": font_id,
        "url": URL % font_id,
        "name": name,
        "family": text(fam.group(1)) if fam else "",
        "weight": weight,
        "weightOrder": weight_order,
        "reading": text(dd(page, "kana")),
        "maker": text(dd(page, "maker")),
        "languages": languages,
        "products": products,
        "description": text(desc.group(1)) if desc else "",
        "webfontName": webfont,
        "charsetHint": cm.group(1) if cm else "",
        "siblingIds": siblings,
        "links": links,
        "sampleImage": img.group(1) if img else "",
    }

def norm(s):
    return re.sub(r"\s+", "", unicodedata.normalize("NFKC", s)).lower()

def load_extra(path):
    """調査TSVの行を、書体見本のファミリー名で引ける形にする。

    TSV の表記は書体見本と揃っていないことがあるので、
    「A / B」「X Narrow/Condensed」は分けて読み、
    正規化して一致しないものは前方一致（最長）で簡体字・繁体字版や G/M などの派生に割り当てる。
    """
    names = []
    if path and os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for row in csv.DictReader(f, delimiter="\t"):
                fam = (row.get("family") or "").strip()
                for part in fam.split(" / "):
                    pieces = part.split("/")
                    if len(pieces) > 1 and "（" not in part:
                        base = pieces[0].rsplit(" ", 1)[0]
                        names.append((pieces[0], row))
                        for v in pieces[1:]:
                            names.append((base + " " + v.strip(), row))
                    else:
                        names.append((part, row))
    return names

def resolve(names, families):
    """ファミリー名→TSVの行"""
    exact = {norm(n): row for n, row in names}
    result, matched = {}, set()
    for fam in families:
        row = exact.get(norm(fam))
        if row is not None:
            result[fam] = row
            matched.add(norm(fam))
    prefixes = sorted({norm(n) for n, _ in names} - matched, key=len, reverse=True)
    for fam in families:
        if fam in result:
            continue
        key = norm(fam)
        for p in prefixes:
            if key.startswith(p):
                result[fam] = exact[p]
                break
    return result

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cache")
    ap.add_argument("out")
    ap.add_argument("--tsv")
    ap.add_argument("--fontlist")
    args = ap.parse_args()
    cache, out = args.cache, args.out
    names = load_extra(args.tsv)
    fonts = []
    for fn in os.listdir(cache):
        m = re.match(r"(\d+)\.html$", fn)
        if not m:
            continue
        with open(os.path.join(cache, fn), encoding="utf-8", errors="replace") as f:
            rec = parse(int(m.group(1)), f.read())
        if rec:
            fonts.append(rec)
    extra = resolve(names, sorted({r["family"] for r in fonts}))
    for rec in fonts:
        e = extra.get(rec["family"], {})
        rec["releaseDate"] = e.get("release_date", "")
        rec["originalRelease"] = e.get("original_release", "")
        rec["designer"] = e.get("designer", "")
        rec["releaseSource"] = e.get("source_url", "")
    unmatched = []
    if args.fontlist:
        unmatched = fontlist.assign(fontlist.read(args.fontlist), fonts)
    for rec in fonts:
        files = rec.pop("files", [])
        rec["classification"] = files[0]["classification"] if files else ""
        rec["vendorGroup"] = files[0]["sheet"] if files else ""
        rec["charsets"] = sorted({x["charset"] for x in files if x["charset"]})
        rec["plans"] = [p for p in fontlist.PLAN_COLUMNS if any(p in x["plans"] for x in files)]
        rec["files"] = [{k: x[k] for k in ("postScriptName", "fileName", "charset", "menuNameJa", "menuNameEn",
                                          "menuNameLocal", "version", "plans")} for x in files]
    fonts.sort(key=lambda r: r["id"])
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "morisawa.json"), "w", encoding="utf-8") as f:
        json.dump({"source": "https://www.morisawa.co.jp/fonts/specimen/", "count": len(fonts), "fonts": fonts,
                   "unmatchedFontlistRows": unmatched},
                  f, ensure_ascii=False, indent=1)
    # CSV は PostScript名（フォントファイル）ごとに1行。フォントリストに無い書体は1行で PostScript名が空
    font_cols = ["id", "name", "family", "weight", "reading", "maker", "vendorGroup", "classification", "languages"]
    file_cols = ["charset", "postScriptName", "fileName", "menuNameJa", "menuNameEn", "menuNameLocal", "version", "plans"]
    tail_cols = ["products", "webfontName", "releaseDate", "originalRelease", "designer", "url", "description",
                 "releaseSource"]
    cell = lambda v: " / ".join(v) if isinstance(v, list) else v
    with open(os.path.join(out, "morisawa.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(font_cols + file_cols + tail_cols)
        for r in fonts:
            for x in r["files"] or [{}]:
                w.writerow([cell(r[c]) for c in font_cols] + [cell(x.get(c, "")) for c in file_cols] +
                           [cell(r[c]) for c in tail_cols])
    print(len(fonts), "fonts,", len({r["family"] for r in fonts}), "families,",
          len(extra), "families with release/designer,",
          sum(len(r["files"]) for r in fonts), "font files,", len(unmatched), "unmatched fontlist rows")

if __name__ == "__main__":
    main()
