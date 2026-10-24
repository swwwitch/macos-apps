#!/usr/bin/env python3
"""キャッシュした Adobe Fonts の Adobe Originals 一覧（/foundries/adobe?page=N）から adobe.json / adobe.csv を作る。

使い方: build_adobe.py <キャッシュフォルダー（pages）> <出力フォルダー>
一覧ページに埋め込まれた /neue/preloaded_foundry_data を読む。発売日は Adobe Fonts での公開日（public_at）。
"""
import csv, glob, json, os, re, sys

BASE = "https://fonts.adobe.com"
# 分類（filters の cl:）。未知のものはそのまま残す
CLASSES = {"se": "セリフ", "ss": "サンセリフ", "sl": "スラブセリフ", "sc": "スクリプト", "bl": "ブラックレター",
           "mo": "等幅", "hm": "手書き", "de": "装飾", "mi": "明朝体", "go": "ゴシック体", "ma": "丸ゴシック体",
           "ka": "楷書体", "he": "黒体（中文ゴシック）", "so": "宋体（中文明朝）", "fa": "仿宋体", "do": "ドウム（韓文ゴシック）",
           "ba": "バタン（韓文明朝）", "mg": "丸ゴシック体", "br": "筆書体", "st": "装飾", "an": "アンチック", "ms": "等幅"}
LANGS = {"ja": "日本語", "zh-Hans": "中国語（簡体字）", "zh-Hant": "中国語（繁体字）", "zh-HK": "中国語（繁体字）", "HK": "中国語（繁体字）", "Deva": "デーヴァナーガリー", "Guru": "グルムキー文字",
         "ko": "ハングル", "en": "ラテン文字（アルファベット）", "ar": "アラビア文字", "he": "ヘブライ文字",
         "hi": "デーヴァナーガリー", "th": "タイ文字", "gu": "グジャラーティ文字", "pa": "グルムキー文字",
         "bn": "ベンガル文字", "ta": "タミル文字", "te": "テルグ文字", "kn": "カンナダ文字", "ml": "マラヤーラム文字",
         "ru": "キリル文字", "el": "ギリシャ文字", "hy": "アルメニア文字", "ka": "ジョージア文字"}
CHARSET_RE = re.compile(r"\b(Pr6N|Pr6|Pr5|ProN|Pro|StdN|Std|PlusN|Plus|SP2N)\b")

def families(cache):
    for path in sorted(glob.glob(os.path.join(cache, "*.html"))):
        s = open(path, encoding="utf-8").read()
        m = re.search(r'<script id="/neue/preloaded_foundry_data" type="text/ng-data">(.*?)</script>', s, re.S)
        if m:
            yield from json.loads(m.group(1))["familiesData"]["families"]

def ja(names, fallback):
    return (names or {}).get("ja_JP") or fallback

def main():
    cache, out = sys.argv[1], sys.argv[2]
    fonts = []
    for fam in families(cache):
        url = "%s/fonts/%s" % (BASE, fam["slug"])
        classes = [CLASSES.get(f[3:], f[3:]) for f in fam.get("filters", []) if f.startswith("cl:")]
        designers = "、".join(d["name"] for d in fam.get("designers", []))
        for order, f in enumerate(fam["fonts"]):
            sync = (f.get("font") or {}).get("sync") or {}
            family_name = ja(f.get("localized_family_name"), f.get("preferred_family_name") or fam["name"])
            cs = CHARSET_RE.search(f.get("preferred_family_name") or fam["name"])
            fonts.append({
                "id": "adobe:%s" % f["id"],
                "url": url,
                "name": ja(f.get("localized_names"), f["name"]),
                "nameEn": f["name"],
                "family": family_name,
                "familyEn": fam["name"],
                "weight": ja(f.get("localized_subfamily_name"), f.get("preferred_subfamily_name", "")),
                "weightOrder": order,
                "reading": "",
                "maker": "Adobe",
                "vendorGroup": (fam.get("foundry") or {}).get("name", ""),
                "classification": " / ".join(classes),
                "languages": [LANGS.get(f.get("default_language", ""), f.get("default_language", ""))],
                "designer": designers,
                "releaseDate": (fam.get("public_at") or "")[:10],
                "releaseSource": url if fam.get("public_at") else "",
                "standard": " / ".join(fam.get("character_standards_with_default_language") or []),
                "isVariableFont": bool(f.get("is_variable_font")),
                "openTypeFeatures": [x.strip('"') for x in ((f.get("font") or {}).get("web") or {}).get("sample_text_features", "").split(",") if x],
                "products": ["Adobe Fonts"],
                "description": fam.get("description", ""),
                "files": [{"postScriptName": f.get("postscript_name", ""), "fileName": "",
                           "charset": cs.group(1) if cs else "", "menuNameJa": ja(f.get("localized_names"), ""),
                           "menuNameEn": f["name"], "menuNameLocal": "", "version": "", "plans": [],
                           "format": sync.get("type", "")}] if f.get("postscript_name") else [],
            })
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "adobe.json"), "w", encoding="utf-8") as fp:
        json.dump({"source": BASE + "/foundries/adobe", "count": len(fonts), "fonts": fonts}, fp, ensure_ascii=False, indent=1)
    cols = ["id", "name", "nameEn", "family", "familyEn", "weight", "classification", "languages", "designer",
            "standard", "releaseDate", "isVariableFont", "url", "description"]
    cell = lambda v: " / ".join(v) if isinstance(v, list) else v
    with open(os.path.join(out, "adobe.csv"), "w", encoding="utf-8-sig", newline="") as fp:
        w = csv.writer(fp)
        w.writerow(cols + ["postScriptName", "charset"])
        for r in fonts:
            x = r["files"][0] if r["files"] else {}
            w.writerow([cell(r[c]) for c in cols] + [x.get("postScriptName", ""), x.get("charset", "")])
    print(len(fonts), "fonts,", len({r["familyEn"] for r in fonts}), "families")

if __name__ == "__main__":
    main()
