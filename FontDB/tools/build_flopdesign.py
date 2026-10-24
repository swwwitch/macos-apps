#!/usr/bin/env python3
"""キャッシュしたフロップデザインの書体ページ・販売ページから flopdesign.json / flopdesign.csv を作る。

使い方: build_flopdesign.py <キャッシュフォルダー（pages）> <出力フォルダー> [フォントファイルの名前 .jsonl]
作者・発売日はサイトに書かれていないので空欄。
PostScript名・フォント名は、製品版のフォントファイルを read_fonts.swift で読んだ .jsonl から書体ページに割り当てる。
ページの無いフォント（特典フォントなど）は、製品版のフォルダー名をシリーズにして1書体ずつ加える。
"""
import csv, html, json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I でも同じフォルダーの部品を読む
import flopdesign_files

BASE = "https://www.flopdesign.com"
SERIES = {
    "syotai": "書体転生", "marugothic": "本丸ゴシック", "himemincho-font": "姫明朝体", "font7": "フォントオノマトペ",
    "font4": "フォント物語", "oyatsu": "フォントのおやつ", "font3": "フォントスタイルズ", "font2": "みんなのフォント",
    "fontcollection": "フォントコレクション", "freefont": "日本語フリーフォント",
}
# 欧文のシリーズ。ほかは和文（かな）として扱う
LATIN_SERIES = {"フォントスタイルズ"}
# 販売ページのうち、書体に関係しない案内ページ
SHOP_GENERIC = {"fontshop", "webfont", "apri-game", "downloadstore", "faq", "kounyuu", "ryosyusho", "shop-info", "souryou"}
# シリーズまとめ売りの販売ページ（書体専用のページがあればそちらを優先）
SHOP_PACKS = {"fontcollection", "fontstory", "fontstyles", "minnanofont", "fontonomatopee", "honmaru"}

def text(s):
    s = re.sub(r"<(script|style)[^>]*>.*?</\1>", "", s, flags=re.S)
    s = re.sub(r"<br\s*/?>|</p>|</h\d>|</li>|</div>", "\n", s)
    s = re.sub(r"<[^>]+>", "", s)
    return re.sub(r"[ \t　]*\n[\s　]*", "\n", html.unescape(s)).strip()

def body(page):
    """ヘッダーのあと、使用許諾・シリーズ一覧の手前までの本文"""
    start = max(page.find("item-page"), 0)
    hs = [m for m in re.finditer(r"<h1[^>]*>(.*?)</h1>", page[start:], re.S) if text(m.group(1))]
    if hs:
        start += hs[0].end()
    end = len(page)
    for marker in ("フリーフォント使用許諾", "使用にあたっての注意事項", "フォントご使用の前に", "決済・返品について"):
        i = page.find(marker, start)
        if i >= 0:
            end = min(end, i)
    return page[start:end]

def font_name(page):
    title = re.search(r"<title>(.*?)</title>", page, re.S)
    title = text(title.group(1)) if title else ""
    title = re.sub(r"(無料ダウンロード|日本語手書き書体|のフリーフォント)$", "", title).strip()
    h1 = [text(m) for m in re.findall(r"<h1[^>]*>(.*?)</h1>", page, re.S) if text(m)]
    h = re.split(r"[：:　]", h1[0])[-1].strip() if h1 else ""
    names = [x for x in (h, title) if x]
    name = min(names, key=len) if names else ""
    # 「あゆむフォント手書き風日本語書体」「うつくし明朝体+オープンソースフォント商用可能」などの説明を外す
    name = re.sub(r"手書き風(日本語)?(書体|フォント)?$", "", name)
    name = re.sub(r"(-フリーフォント|\+オープンソース.*)$", "", name)
    return name.strip()

def section(t, head, stops):
    """「OpenType機能」などの見出しの次から、次の見出しの手前まで"""
    i = t.find(head)
    if i < 0:
        return []
    rest = t[i + len(head):]
    cut = min([rest.find(s) for s in stops if rest.find(s) >= 0] or [len(rest)])
    return [x.strip() for x in rest[:cut].split("\n") if x.strip()]

def shop_info(page):
    t = text(page)
    price = re.search(r"価格[\s　]*(?:[^\d\n]{0,30})?([\d,]+)円", t)
    glyphs = re.search(r"収録文字数\s*([\d,]+)\s*(?:字|文字)", t)
    fmt = re.search(r"フォント形式[：:]\s*([^\n※]+)", t)
    return {
        "price": int(price.group(1).replace(",", "")) if price else None,
        "glyphCount": int(glyphs.group(1).replace(",", "")) if glyphs else None,
        "formats": [x.strip() for x in re.split(r"[、,]", fmt.group(1)) if x.strip()] if fmt else [],
    }

def pick_shop(page):
    slugs = []
    for s in re.findall(r'href="(?:https?://(?:www\.)?flopdesign\.com)?/shop/([a-z0-9_-]+)\.html"', page):
        if s not in SHOP_GENERIC and s not in slugs:
            slugs.append(s)
    own = [s for s in slugs if s not in SHOP_PACKS]
    return (own or slugs or [None])[0]

def parse(path, page, shops):
    series = SERIES.get(path.split("/")[1], "")
    t = text(body(page))
    lines = [x for x in t.split("\n") if x.strip()]
    stop = ("商用利用する", "無料ダウンロード", "文字デザイン", "OpenType機能", "グリフ", "フォント組み見本", "← 前のフォント")
    desc = []
    for x in lines:
        if any(x.startswith(s) for s in stop):
            break
        desc.append(x)
    glyphs = re.search(r"(?:全|収録文字数)\s*([\d,]+)\s*(?:字|文字)", t)
    dl = re.search(r'href="([^"]*(?:/images/datafont/[^"]+\.(?:zip|lzh)|booth\.pm[^"]*))"', page)
    shop = pick_shop(page)
    info = shops.get(shop, {}) if shop else {}
    name = font_name(page)
    return {
        "id": "flopdesign:" + path.strip("/").replace(".html", ""),
        "url": BASE + path,
        "name": name,
        "family": name,
        "weight": "",
        "reading": "",
        "maker": "フロップデザイン",
        "series": series,
        "languages": ["ラテン文字（アルファベット）"] if series in LATIN_SERIES else ["日本語"],
        "description": "\n".join(desc),
        "openTypeFeatures": section(t, "OpenType機能", ("グリフ", "フォント組み見本", "グラフィク")),
        "glyphCount": int(glyphs.group(1).replace(",", "")) if glyphs else info.get("glyphCount"),
        "freeDownload": html.unescape(dl.group(1)) if dl else "",
        "shopUrl": "%s/shop/%s.html" % (BASE, shop) if shop else "",
        "price": info.get("price"),
        "formats": info.get("formats", []),
        "designer": "",
        "releaseDate": "",
    }

def file_record(x):
    return {"postScriptName": x["postScriptName"], "fileName": x["fileName"], "charset": "",
            "menuNameJa": x["fullNameJa"], "menuNameEn": x["fullName"], "menuNameLocal": "",
            "version": x["version"].split(";")[0].replace("Version ", ""), "plans": [], "path": x["path"]}

def main():
    cache, out = sys.argv[1], sys.argv[2]
    shops = {}
    for fn in os.listdir(cache):
        if fn.startswith("shop__"):
            with open(os.path.join(cache, fn), encoding="utf-8", errors="replace") as f:
                shops[fn[6:-5]] = shop_info(f.read())
    fonts = []
    for fn in sorted(os.listdir(cache)):
        d = fn.split("__")[0]
        if d not in SERIES:
            continue
        with open(os.path.join(cache, fn), encoding="utf-8", errors="replace") as f:
            rec = parse("/" + fn.replace("__", "/"), f.read(), shops)
        if rec["name"]:
            fonts.append(rec)
    rest = flopdesign_files.assign(flopdesign_files.load(sys.argv[3]), fonts) if len(sys.argv) > 3 else []
    for rec in fonts:
        rec["files"] = [file_record(x) for x in rec.pop("_files", [])]
    # ページの無いフォントは PostScript名の「-」より前でまとめ、日本語のファミリー名があればそれを名前にする
    extra = {}
    for x in rest:
        extra.setdefault(x["postScriptName"].split("-")[0].lower(), []).append(x)
    for xs in extra.values():
        name = next((x["familyJa"] for x in xs if x["familyJa"]), xs[0]["family"]).strip()
        series = flopdesign_files.FOLDER_SERIES.get(xs[0]["path"].split("/")[1], "")
        fonts.append({"id": "flopdesign:file/" + xs[0]["postScriptName"], "url": "", "name": name, "family": name,
                      "weight": "", "reading": "", "maker": "フロップデザイン", "series": series,
                      "languages": ["日本語"], "description": "", "openTypeFeatures": [], "glyphCount": xs[0]["glyphCount"],
                      "freeDownload": "", "shopUrl": "", "price": None, "formats": [], "designer": "", "releaseDate": "",
                      "files": [file_record(x) for x in xs]})
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "flopdesign.json"), "w", encoding="utf-8") as f:
        json.dump({"source": BASE + "/fonts.html", "count": len(fonts), "fonts": fonts}, f, ensure_ascii=False, indent=1)
    cols = ["id", "name", "series", "languages", "glyphCount", "price", "formats", "openTypeFeatures", "url", "shopUrl",
            "freeDownload", "description"]
    cell = lambda v: " / ".join(v) if isinstance(v, list) else ("" if v is None else v)
    with open(os.path.join(out, "flopdesign.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for r in fonts:
            w.writerow([cell(r[c]) for c in cols])
    print(len(fonts), "fonts,", sum(len(r["files"]) for r in fonts), "font files,", len(extra), "fonts without a page")

if __name__ == "__main__":
    main()
