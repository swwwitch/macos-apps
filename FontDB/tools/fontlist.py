"""Morisawa Fonts のフォントリスト（Excel）を読み、書体見本の書体名に割り当てる。"""
import re, unicodedata
import xlsx

PLAN_COLUMNS = ["スタンダード", "Select8", "Select24", "Webフォント", "Webフォント Pro"]
# 書体見本で1ページにまとめられている書体（Excelの書体名の先頭→書体見本の書体名）
GROUPED = [("くいこみ数字 縦", "くいこみ数字 縦"), ("くいこみ数字", "くいこみ数字"),
           ("数字書体", "数字224書体"), ("地紋", "地紋"), ("罫", "罫")]

def norm(s):
    return re.sub(r"\s+", "", unicodedata.normalize("NFKC", s)).lower()

def read(path):
    """Excelの各行を辞書にする。シート名はメーカーの区分。"""
    rows = []
    for sheet, table in xlsx.read(path).items():
        header = [h.strip() for h in table[1]]
        for r in table[2:]:
            r = r + [""] * (len(header) - len(r))
            rec = dict(zip(header, (v.strip() for v in r)))
            if not rec.get("書体名（日）"):
                continue
            rows.append({
                "sheet": sheet,
                "language": rec.get("言語", ""),
                "classification": rec.get("分類", ""),
                "name": rec["書体名（日）"],
                "charset": rec.get("文字セット", ""),
                "menuNameJa": rec.get("フォントメニュー名（日）", ""),
                "menuNameEn": rec.get("フォントメニュー名（英）", ""),
                "menuNameLocal": rec.get("フォントメニュー名（現地語）", ""),
                "postScriptName": rec.get("PostScript名", ""),
                "fileName": rec.get("ファイル名", ""),
                "version": rec.get("バージョン", ""),
                "plans": [p for p in PLAN_COLUMNS if rec.get(p) == "○"],
            })
    return rows

def candidates(name):
    """Excelの書体名から、書体見本で使われていそうな書体名を順に返す。"""
    yield name
    yield re.sub(r"（.*?）$", "", name)
    # Arphic のプロポーショナル版（SongP・H7P・PE1 など）は元の書体のページに載っている
    yield re.sub(r"P(?= |E1 |$)", "", name)
    for prefix, target in GROUPED:
        if name.startswith(prefix):
            yield target
            break

def assign(rows, fonts):
    """書体見本の書体（fonts）ごとに Excel の行を割り当てる。戻り値は割り当てられなかった行。"""
    index = {}
    for f in fonts:
        index.setdefault(norm(f["name"]), f)
    unmatched = []
    for row in rows:
        target = None
        for c in candidates(row["name"]):
            target = index.get(norm(c))
            if target:
                break
        if target is None:
            unmatched.append(row)
            continue
        target.setdefault("files", []).append(row)
    return unmatched
