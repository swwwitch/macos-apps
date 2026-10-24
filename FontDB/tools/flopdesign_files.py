"""フロップデザインのフォントファイル（read_fonts.swift の出力）を書体ページに割り当てる。"""
import json, re, unicodedata

# 書体ページのスラッグの綴りがフォント名と異なるもの（スラッグ→フォント名側）
ALIASES = {"astlatic": "astoratic", "braek": "break", "calender": "calendar", "machindings": "machinedings",
           "natsukomi": "natsucomi", "abbyroad": "abbeyroad", "coffemilkcrazy": "coffeemilkcrazy", "skecthbook": "sketchbook",
           "ichigocharactar": "ichigocharacter"}
# 製品版フォルダー → ページの無いフォントに付けるシリーズ名
FOLDER_SERIES = {"FONT_Collection3": "フォントコレクション", "Font-onomatopee": "フォントオノマトペ",
                 "FONT_STORY": "フォント物語", "Fontstyles": "フォントスタイルズ", "MINNANO-FONT-PLUS": "みんなのフォント",
                 "HIME-Mincho": "姫明朝体", "HonmaruGothic": "本丸ゴシック", "Syotai-Tensei6": "書体転生",
                 "Tokuten_font": "特典フォント", "WebfontKit": "日本語ウェブフォントキット"}

def norm(s):
    s = re.sub(r"[\s\-_・]|フォント|font|体$", "", unicodedata.normalize("NFKC", s).lower())
    return ALIASES.get(s, s)

def load(path):
    return [json.loads(line) for line in open(path, encoding="utf-8") if line.strip()]

def assign(files, pages):
    """pages の各書体に files を割り当てる。戻り値は割り当てられなかったファイル。"""
    index = {}
    for p in pages:
        for k in (norm(p["name"]), norm(p["id"].split("/")[-1])):
            if k:
                index.setdefault(k, p)
    rest = []
    for f in files:
        keys = [norm(f["familyJa"]), norm(f["family"]), norm(f["postScriptName"].split("-")[0])]
        keys += [norm(x) for x in reversed(f["path"].split("/")[:-1])]
        target = next((index[k] for k in keys if k and k in index), None)
        if target is None:
            # 「applealphabet」と「apple」のような前方一致（4文字以上）
            for k in keys:
                if len(k) >= 4:
                    target = next((v for kk, v in index.items() if len(kk) >= 4 and (kk.startswith(k) or k.startswith(kk))), None)
                    if target:
                        break
        if target is None:
            rest.append(f)
        else:
            target.setdefault("_files", []).append(f)
    return rest
