#!/usr/bin/env python3
"""メーカー別の JSON（data/<メーカー>.json）をまとめて、fonts.sqlite と公開ページ用の fonts.json を作る。

使い方: build_all.py <dataフォルダー> <公開用 fonts.json> [更新日]
読み込む JSON は SOURCES の順。無いものは飛ばす。
"""
import json, os, sqlite3, sys

SOURCES = ["morisawa", "flopdesign", "fontworks", "adobe"]

SCHEMA = """
CREATE TABLE fonts (
  uid TEXT PRIMARY KEY,            -- <メーカー>:<そのメーカー内のID>
  source TEXT NOT NULL, url TEXT,
  name TEXT NOT NULL, family TEXT, weight TEXT, weight_order INTEGER, reading TEXT,
  maker TEXT, vendor_group TEXT, series TEXT, classification TEXT,
  languages TEXT, products TEXT, plans TEXT, opentype_features TEXT, formats TEXT,   -- JSON 配列
  webfont_name TEXT, release_date TEXT, original_release TEXT, designer TEXT, release_source TEXT,
  glyph_count INTEGER, price INTEGER, shop_url TEXT, free_download TEXT,
  description TEXT, sample_image TEXT
);
CREATE TABLE files (
  postscript_name TEXT NOT NULL, font_uid TEXT NOT NULL REFERENCES fonts(uid),
  file_name TEXT, charset TEXT, menu_name_ja TEXT, menu_name_en TEXT, menu_name_local TEXT, version TEXT,
  plans TEXT                       -- JSON 配列
);
CREATE INDEX files_postscript_name ON files(postscript_name);
CREATE INDEX files_font_uid ON files(font_uid);
CREATE INDEX fonts_family ON fonts(family);
CREATE INDEX fonts_maker ON fonts(maker);
"""

def load(data_dir):
    """各メーカーの書体を共通の形にそろえて返す"""
    fonts = []
    for source in SOURCES:
        path = os.path.join(data_dir, source + ".json")
        if not os.path.exists(path):
            continue
        for f in json.load(open(path, encoding="utf-8"))["fonts"]:
            uid = str(f["id"])
            fonts.append({
                "uid": uid if uid.startswith(source + ":") else "%s:%s" % (source, uid),
                "source": source,
                "url": f.get("url", ""),
                "name": f["name"],
                "family": f.get("family") or f["name"],
                "familyEn": f.get("familyEn", ""),
                "weight": f.get("weight", ""),
                "weightOrder": f.get("weightOrder", 0),
                "reading": f.get("reading", ""),
                "maker": f.get("maker", ""),
                "vendorGroup": f.get("vendorGroup", ""),
                "series": f.get("series", ""),
                "classification": f.get("classification", ""),
                "languages": f.get("languages", []),
                "products": f.get("products", []),
                "plans": f.get("plans", []),
                "openTypeFeatures": f.get("openTypeFeatures", []),
                "formats": f.get("formats", []),
                "webfontName": f.get("webfontName", ""),
                "releaseDate": f.get("releaseDate", ""),
                "originalRelease": f.get("originalRelease", ""),
                "designer": f.get("designer", ""),
                "releaseSource": f.get("releaseSource", ""),
                "glyphCount": f.get("glyphCount"),
                "price": f.get("price"),
                "shopUrl": f.get("shopUrl", ""),
                "freeDownload": f.get("freeDownload", ""),
                "description": f.get("description", ""),
                "sampleImage": f.get("sampleImage", ""),
                "files": f.get("files", []),
            })
    return fonts

def write_sqlite(path, fonts):
    if os.path.exists(path):
        os.remove(path)
    db = sqlite3.connect(path)
    db.executescript(SCHEMA)
    j = lambda v: json.dumps(v, ensure_ascii=False)
    for r in fonts:
        db.execute("INSERT INTO fonts VALUES (%s)" % ",".join("?" * 28), (
            r["uid"], r["source"], r["url"], r["name"], r["family"], r["weight"], r["weightOrder"], r["reading"],
            r["maker"], r["vendorGroup"], r["series"], r["classification"], j(r["languages"]), j(r["products"]),
            j(r["plans"]), j(r["openTypeFeatures"]), j(r["formats"]), r["webfontName"], r["releaseDate"],
            r["originalRelease"], r["designer"], r["releaseSource"], r["glyphCount"], r["price"], r["shopUrl"],
            r["freeDownload"], r["description"], r["sampleImage"]))
        for x in r["files"]:
            db.execute("INSERT INTO files VALUES (?,?,?,?,?,?,?,?,?)", (
                x.get("postScriptName", ""), r["uid"], x.get("fileName", ""), x.get("charset", ""),
                x.get("menuNameJa", ""), x.get("menuNameEn", ""), x.get("menuNameLocal", ""), x.get("version", ""),
                j(x.get("plans", []))))
    db.commit()
    db.close()

# 公開ページ用。説明文・見本画像は載せない（公式ページへのリンクで代える）
FAMILY_KEYS = ["source", "family", "familyEn", "reading", "maker", "series", "classification", "languages", "releaseDate",
               "originalRelease", "designer", "releaseSource", "glyphCount", "price", "shopUrl"]
FONT_KEYS = ["uid", "url", "name", "weight", "products", "plans"]
FILE_KEYS = ["postScriptName", "fileName", "charset", "version"]

def export_public(path, fonts, updated):
    families, order = {}, []
    for f in fonts:
        key = (f["maker"], f["family"])
        fam = families.get(key)
        if fam is None:
            fam = families[key] = {k: f[k] for k in FAMILY_KEYS}
            fam["freeDownload"] = False
            fam["fonts"] = []
            order.append(key)
        if not fam["classification"]:
            fam["classification"] = f["classification"]
        fam["freeDownload"] = fam["freeDownload"] or bool(f["freeDownload"])
        font = {k: f[k] for k in FONT_KEYS}
        font["weightOrder"] = f["weightOrder"]
        font["files"] = [{k: x.get(k, "") for k in FILE_KEYS} for x in f["files"]]
        fam["fonts"].append(font)
    out = []
    for key in order:
        fam = families[key]
        fam["fonts"].sort(key=lambda x: x.pop("weightOrder"))
        out.append({k: v for k, v in fam.items() if v not in (None, "", [], False)})
    with open(path, "w", encoding="utf-8") as fp:
        json.dump({"updated": updated, "families": out}, fp, ensure_ascii=False, separators=(",", ":"))
    return len(out)

def main():
    data_dir, public = sys.argv[1], sys.argv[2]
    fonts = load(data_dir)
    write_sqlite(os.path.join(data_dir, "fonts.sqlite"), fonts)
    n = export_public(public, fonts, sys.argv[3] if len(sys.argv) > 3 else "")
    counts = {}
    for f in fonts:
        counts[f["maker"]] = counts.get(f["maker"], 0) + 1
    print(len(fonts), "fonts,", n, "families", counts)

if __name__ == "__main__":
    main()
