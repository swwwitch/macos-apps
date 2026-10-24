#!/usr/bin/env python3
"""キャッシュしたフォントワークスの書体ページ（/fontsearch/<PostScript名>）から fontworks.json / fontworks.csv を作る。

使い方: build_fontworks.py <キャッシュフォルダー（pages）> <出力フォルダー> [releasenote.html]
発売年月は公式の「製品リリースノート」から、書体名とウェイトで突き合わせて補う。
"""
import csv, html, json, os, re, sys, unicodedata

BASE = "https://fontworks.co.jp"
RELEASE_NOTE = BASE + "/company/releasenote/"

def text(s):
    s = re.sub(r"<(script|style)[^>]*>.*?</\1>", "", s, flags=re.S)
    s = re.sub(r"<br\s*/?>|</p>|</h\d>|</li>|</div>|</dd>", "\n", s)
    s = re.sub(r"<[^>]+>", "", s)
    return re.sub(r"[ \t　]*\n[\s　]*", "\n", html.unescape(s)).strip()

def norm(s):
    return re.sub(r"[\s　・_\-－]+", "", unicodedata.normalize("NFKC", s)).lower()

def details(page):
    """「詳細」の dt/dd を {見出し: [値, ...]} にする"""
    out = {}
    for dt, dds in re.findall(r"<dt[^>]*>(.*?)</dt>((?:\s*<dd[^>]*>.*?</dd>)+)", page, re.S):
        key = text(dt).rstrip("：:")
        out[key] = [text(x) for x in re.findall(r"<dd[^>]*>(.*?)</dd>", dds, re.S) if text(x)]
    return out

def h3_block(page, head):
    """<h3>デザイナー</h3> などの直後から次の <h3> までのテキスト行"""
    m = re.search(r"<h3[^>]*>\s*%s\s*</h3>(.*?)(?=<h3|<h2)" % re.escape(head), page, re.S)
    return [x for x in text(m.group(1)).split("\n") if x] if m else []

def parse(slug, page):
    title = re.search(r"<title>(.*?)</title>", page, re.S)
    name = text(title.group(1)).split(" | ")[0].strip() if title else ""
    if not name:
        return None
    # 見本の font-family は「'メニュー名', 'PostScript名'」。メニュー名の無い書体は「'PostScript名', ''」
    css = re.search(r"font-family:\s*'([^']+)'(?:,\s*'([^']*)')?", page)
    menu, ps = (css.group(1), css.group(2) or "") if css else ("", "")
    if css and not ps:
        menu, ps = "", css.group(1)
    d = details(page)
    designers = re.findall(r"<h4[^>]*>(.*?)</h4>", re.search(r"<h3[^>]*>\s*デザイナー\s*</h3>(.*?)(?=<h3|<h2)", page, re.S).group(1), re.S) \
        if re.search(r"<h3[^>]*>\s*デザイナー\s*</h3>", page) else []
    about = re.search(r"<h2[^>]*>\s*フォントについて\s*</h2>(.*?)(?=<h3|さらに詳しく)", page, re.S)
    family, _, weight = name.rpartition(" ")
    if not family:
        family, weight = name, ""
    std = re.search(r"\b(Pr6N|Pr6|Pr5N|Pr5|ProN|Pro|StdN|Std)\b", menu)
    return {
        "id": "fontworks:" + slug,
        "url": "%s/fontsearch/%s/" % (BASE, slug),
        "name": name,
        "family": family,
        "weight": weight,
        "reading": " ".join(d.get("読み方", [])),
        "maker": " ".join(d.get("フォントメーカー", [])) or "Fontworks",
        "vendorGroup": " ".join(d.get("ファウンダリー", [])),
        "classification": " / ".join(d.get("カテゴリ", [])),
        "languages": d.get("言語", []),
        "designer": "、".join(text(x) for x in designers),
        "openTypeFeatures": d.get("OpenType機能", []),
        "standard": " / ".join(d.get("規格", [])),
        "fileSize": " ".join(d.get("ファイルサイズ", [])),
        "products": h3_block(page, "対応サービス"),
        "description": text(about.group(1)) if about else "",
        "files": [{"postScriptName": ps, "fileName": "", "charset": std.group(1) if std else "",
                   "menuNameJa": menu, "menuNameEn": "", "menuNameLocal": "", "version": "", "plans": []}] if ps else [],
    }

def release_notes(path):
    """製品リリースノートから {正規化した「書体名-ウェイト」または書体名: "YYYY-MM"} を作る（早いほうを残す）"""
    if not path or not os.path.exists(path):
        return {}
    lines = [x for x in text(open(path, encoding="utf-8").read()).split("\n") if x]
    year = month = None
    out = {}
    def put(key, ym):
        if key and (key not in out or ym < out[key]):
            out[key] = ym
    for line in lines:
        m = re.fullmatch(r"(\d{4})年", line)
        if m:
            year, month = m.group(1), None
            continue
        m = re.fullmatch(r"(\d{1,2})月", line)
        if m and year:
            month = int(m.group(1))
            continue
        if not (year and month):
            continue
        ym = "%s-%02d" % (year, month)
        body = re.sub(r"【[^】]*】", "", line)
        for item in re.split(r"[、,]", body):
            item = re.sub(r"[［\[（(].*?[］\])）]", "", item).strip()
            m = re.match(r"(.+?)[-－]([A-Za-zＡ-Ｚａ-ｚ0-9０-９/／]+)$", item)
            if m:
                base = m.group(1)
                put(norm(base), ym)
                for w in re.split(r"[/／]", m.group(2)):
                    put(norm(base + w), ym)
            elif item and len(item) <= 30:
                put(norm(item), ym)
    return out

def main():
    cache, out = sys.argv[1], sys.argv[2]
    notes = release_notes(sys.argv[3] if len(sys.argv) > 3 else None)
    fonts = []
    for fn in sorted(os.listdir(cache)):
        if not fn.startswith("fontsearch__"):
            continue
        with open(os.path.join(cache, fn), encoding="utf-8", errors="replace") as f:
            rec = parse(fn[len("fontsearch__"):], f.read())
        if not rec:
            continue
        ym = notes.get(norm(rec["family"] + rec["weight"])) or notes.get(norm(rec["family"]))
        rec["releaseDate"] = ym or ""
        rec["releaseSource"] = RELEASE_NOTE if ym else ""
        fonts.append(rec)
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "fontworks.json"), "w", encoding="utf-8") as f:
        json.dump({"source": BASE + "/fontsearch/", "count": len(fonts), "fonts": fonts}, f, ensure_ascii=False, indent=1)
    cols = ["id", "name", "family", "weight", "reading", "maker", "vendorGroup", "classification", "languages", "designer",
            "standard", "releaseDate", "url", "description"]
    cell = lambda v: " / ".join(v) if isinstance(v, list) else v
    with open(os.path.join(out, "fontworks.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols + ["postScriptName", "menuNameJa"])
        for r in fonts:
            x = r["files"][0] if r["files"] else {}
            w.writerow([cell(r[c]) for c in cols] + [x.get("postScriptName", ""), x.get("menuNameJa", "")])
    print(len(fonts), "fonts,", sum(1 for r in fonts if r["releaseDate"]), "with release date")

if __name__ == "__main__":
    main()
