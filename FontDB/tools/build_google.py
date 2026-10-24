#!/usr/bin/env python3
"""Google Fonts の METADATA.pb（google/fonts リポジトリ）と公式の一覧データから google.json / google.csv を作る。

使い方: build_google.py <google/fonts の作業コピー> <metadata.json> <出力フォルダー>
METADATA.pb は 1 ファミリー 1 ファイル。PostScript名・ファイル名・デザイナー・追加日はこちらから、
分類・文字の種類・人気順などは fonts.google.com/metadata/fonts から取る。
サイトの一覧に無いファミリー（掲載を終えたものなど）も、公式ページへのリンクなしで残す。
"""
import csv, glob, json, os, re, sys, urllib.parse

CATEGORY = {"SANS_SERIF": "サンセリフ", "SERIF": "セリフ", "DISPLAY": "ディスプレイ", "HANDWRITING": "手書き",
            "MONOSPACE": "等幅", "Sans Serif": "サンセリフ", "Serif": "セリフ", "Display": "ディスプレイ",
            "Handwriting": "手書き", "Monospace": "等幅"}
SUBSETS = {"japanese": "日本語", "korean": "ハングル", "chinese-simplified": "中国語（簡体字）",
           "chinese-traditional": "中国語（繁体字）", "chinese-hongkong": "中国語（繁体字）", "thai": "タイ文字",
           "arabic": "アラビア文字", "hebrew": "ヘブライ文字", "devanagari": "デーヴァナーガリー", "bengali": "ベンガル文字",
           "cyrillic": "キリル文字", "greek": "ギリシャ文字", "latin": "ラテン文字（アルファベット）"}

def parse_pb(text):
    """METADATA.pb（テキスト形式の protobuf）から、使う項目だけを読む"""
    top = {}
    depth = 0
    fonts, cur = [], None
    for line in text.splitlines():
        s = line.strip()
        if s.endswith("{"):
            depth += 1
            if depth == 1 and s.startswith("fonts"):
                cur = {}
            continue
        if s == "}":
            depth -= 1
            if depth == 0 and cur is not None:
                fonts.append(cur)
                cur = None
            continue
        m = re.match(r'(\w+):\s*(?:"((?:[^"\\]|\\.)*)"|(\S+))', s)
        if not m:
            continue
        key, val = m.group(1), m.group(2) if m.group(2) is not None else m.group(3)
        if depth == 0:
            top.setdefault(key, []).append(val)
        elif depth == 1 and cur is not None:
            cur[key] = val
    return top, fonts

def site_metadata(path):
    s = open(path, encoding="utf-8").read()
    data = json.loads(s[s.find("{"):])
    return {f["family"]: f for f in data["familyMetadataList"]}

def main():
    repo, meta_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
    site = site_metadata(meta_path)
    fonts, seen = [], set()
    for pb in sorted(glob.glob(os.path.join(repo, "*", "*", "METADATA.pb"))):
        top, styles = parse_pb(open(pb, encoding="utf-8").read())
        family = top.get("name", [""])[0]
        if not family or not styles:
            continue
        info = site.get(family, {})
        listed = bool(info)
        url = "https://fonts.google.com/specimen/" + urllib.parse.quote(family.replace(" ", "+"), safe="+") if listed else ""
        subsets = info.get("subsets") or top.get("subsets", [])
        langs = [SUBSETS[x] for x in subsets if x in SUBSETS]
        # 主な文字を先頭に（和文なら日本語）。キリル・ギリシャ・ラテンは多くの書体に付くので後ろへ
        tail = ["キリル文字", "ギリシャ文字", "ラテン文字（アルファベット）"]
        langs = sorted(set(langs), key=lambda x: (tail.index(x) + 1 if x in tail else 0, list(SUBSETS.values()).index(x)))
        designers = info.get("designers") or [d.strip() for d in top.get("designer", [""])[0].split(",") if d.strip()]
        license_ = top.get("license", [""])[0] or os.path.basename(os.path.dirname(os.path.dirname(pb))).upper()
        for st in styles:
            weight = int(st.get("weight", "400") or 400)
            italic = st.get("style") == "italic"
            full = st.get("full_name", "")
            style_name = full[len(family):].strip() if full.startswith(family) else full
            # 同じ PostScript名が別のフォルダー（ライセンス違いの旧版など）にもあるので、フォルダー名とウェイトで一意にする
            uid = "google:%s/%s-%d%s" % (os.path.basename(os.path.dirname(pb)), st.get("post_script_name") or st.get("filename"),
                                         weight, "i" if italic else "")
            # 同じ METADATA.pb に同じ書体が2回書かれていることがある（Wix Madefor Text）
            if uid in seen:
                continue
            seen.add(uid)
            fonts.append({
                "id": uid,
                "url": url,
                "name": full or family,
                "family": family,
                "weight": style_name or ("Italic" if italic else "Regular"),
                "weightOrder": weight * 2 + int(italic),
                "reading": "",
                "maker": "Google Fonts",
                "vendorGroup": license_,
                "classification": CATEGORY.get(info.get("category") or top.get("category", [""])[0], ""),
                "languages": langs,
                "designer": "、".join(designers),
                "releaseDate": info.get("dateAdded") or top.get("date_added", [""])[0],
                "releaseSource": url,
                "products": ["Google Fonts"] + (["Noto"] if info.get("isNoto") else []),
                "description": "",
                "files": [{"postScriptName": st.get("post_script_name", ""), "fileName": st.get("filename", ""),
                           "charset": "", "menuNameJa": "", "menuNameEn": full, "menuNameLocal": "",
                           "version": "", "plans": []}],
            })
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "google.json"), "w", encoding="utf-8") as f:
        json.dump({"source": "https://github.com/google/fonts", "count": len(fonts), "fonts": fonts}, f, ensure_ascii=False, indent=1)
    cols = ["id", "name", "family", "weight", "classification", "languages", "designer", "releaseDate", "vendorGroup", "url"]
    cell = lambda v: " / ".join(v) if isinstance(v, list) else v
    with open(os.path.join(out, "google.csv"), "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols + ["postScriptName", "fileName"])
        for r in fonts:
            x = r["files"][0]
            w.writerow([cell(r[c]) for c in cols] + [x["postScriptName"], x["fileName"]])
    print(len(fonts), "fonts,", len({r["family"] for r in fonts}), "families,",
          sum(1 for r in fonts if not r["url"]), "fonts not listed on fonts.google.com")

if __name__ == "__main__":
    main()
