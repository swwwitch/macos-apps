# Builds the blank documents in Resources/FileTemplates (real, openable files instead of 0 KB ones).
# Run: python3 Assets/make-file-templates.py   (re-run only when changing them; the results are checked in)
from pathlib import Path
import struct, subprocess, zipfile, zlib

out = Path(__file__).resolve().parents[1] / "Resources" / "FileTemplates"
out.mkdir(parents=True, exist_ok=True)
W, H = 1920, 1080
A4 = (595, 842)


def write_zip(name, files):
    path = out / name
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        # [Content_Types].xml first, as Office writes it.
        for arcname, text in files:
            z.writestr(arcname, text)


XML = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG = "http://schemas.openxmlformats.org/package/2006/relationships"

# --- Word
write_zip("template.docx", [
    ("[Content_Types].xml", XML + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
     '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
     '<Default Extension="xml" ContentType="application/xml"/>'
     '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
     '</Types>'),
    ("_rels/.rels", XML + f'<Relationships xmlns="{PKG}"><Relationship Id="rId1" Type="{REL}/officeDocument" Target="word/document.xml"/></Relationships>'),
    ("word/document.xml", XML + '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/>'
     '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>'
     '</w:body></w:document>'),
])

# --- Excel
write_zip("template.xlsx", [
    ("[Content_Types].xml", XML + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
     '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
     '<Default Extension="xml" ContentType="application/xml"/>'
     '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
     '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
     '</Types>'),
    ("_rels/.rels", XML + f'<Relationships xmlns="{PKG}"><Relationship Id="rId1" Type="{REL}/officeDocument" Target="xl/workbook.xml"/></Relationships>'),
    ("xl/workbook.xml", XML + f'<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="{REL}">'
     '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>'),
    ("xl/_rels/workbook.xml.rels", XML + f'<Relationships xmlns="{PKG}"><Relationship Id="rId1" Type="{REL}/worksheet" Target="worksheets/sheet1.xml"/></Relationships>'),
    ("xl/worksheets/sheet1.xml", XML + '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>'),
])

# --- PowerPoint: presentation, one master, one layout, theme, one blank 16:9 slide.
A = "http://schemas.openxmlformats.org/drawingml/2006/main"
P = "http://schemas.openxmlformats.org/presentationml/2006/main"
NS = f'xmlns:a="{A}" xmlns:r="{REL}" xmlns:p="{P}"'
TREE = ('<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>'
        '<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>'
        '</p:spTree></p:cSld>')
CLR = ''.join(f'<a:{n}><a:srgbClr val="{v}"/></a:{n}>' for n, v in [
    ("dk1", "000000"), ("lt1", "FFFFFF"), ("dk2", "44546A"), ("lt2", "E7E6E6"), ("accent1", "4472C4"), ("accent2", "ED7D31"),
    ("accent3", "A5A5A5"), ("accent4", "FFC000"), ("accent5", "5B9BD5"), ("accent6", "70AD47"), ("hlink", "0563C1"), ("folHlink", "954F72")])
FILL = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
LN = '<a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>'
THEME = (XML + f'<a:theme xmlns:a="{A}" name="Office"><a:themeElements><a:clrScheme name="Office">{CLR}</a:clrScheme>'
         '<a:fontScheme name="Office"><a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>'
         '<a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont></a:fontScheme>'
         f'<a:fmtScheme name="Office"><a:fillStyleLst>{FILL * 3}</a:fillStyleLst><a:lnStyleLst>{LN * 3}</a:lnStyleLst>'
         '<a:effectStyleLst>' + '<a:effectStyle><a:effectLst/></a:effectStyle>' * 3 + '</a:effectStyleLst>'
         f'<a:bgFillStyleLst>{FILL * 3}</a:bgFillStyleLst></a:fmtScheme></a:themeElements></a:theme>')
write_zip("template.pptx", [
    ("[Content_Types].xml", XML + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
     '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
     '<Default Extension="xml" ContentType="application/xml"/>'
     '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>'
     '<Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>'
     '<Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>'
     '<Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>'
     '<Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>'
     '</Types>'),
    ("_rels/.rels", XML + f'<Relationships xmlns="{PKG}"><Relationship Id="rId1" Type="{REL}/officeDocument" Target="ppt/presentation.xml"/></Relationships>'),
    ("ppt/presentation.xml", XML + f'<p:presentation {NS}>'
     '<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>'
     '<p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst>'
     '<p:sldSz cx="12192000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>'),
    ("ppt/_rels/presentation.xml.rels", XML + f'<Relationships xmlns="{PKG}">'
     f'<Relationship Id="rId1" Type="{REL}/slideMaster" Target="slideMasters/slideMaster1.xml"/>'
     f'<Relationship Id="rId2" Type="{REL}/slide" Target="slides/slide1.xml"/>'
     f'<Relationship Id="rId3" Type="{REL}/theme" Target="theme/theme1.xml"/></Relationships>'),
    ("ppt/slideMasters/slideMaster1.xml", XML + f'<p:sldMaster {NS}>{TREE}'
     '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>'
     '<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst></p:sldMaster>'),
    ("ppt/slideMasters/_rels/slideMaster1.xml.rels", XML + f'<Relationships xmlns="{PKG}">'
     f'<Relationship Id="rId1" Type="{REL}/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>'
     f'<Relationship Id="rId2" Type="{REL}/theme" Target="../theme/theme1.xml"/></Relationships>'),
    ("ppt/slideLayouts/slideLayout1.xml", XML + f'<p:sldLayout {NS} type="blank" preserve="1">{TREE}<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>'),
    ("ppt/slideLayouts/_rels/slideLayout1.xml.rels", XML + f'<Relationships xmlns="{PKG}"><Relationship Id="rId1" Type="{REL}/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>'),
    ("ppt/slides/slide1.xml", XML + f'<p:sld {NS}>{TREE}<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>'),
    ("ppt/slides/_rels/slide1.xml.rels", XML + f'<Relationships xmlns="{PKG}"><Relationship Id="rId1" Type="{REL}/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>'),
    ("ppt/theme/theme1.xml", THEME),
])

# --- PDF (A4, one blank page); the same file as .ai opens in Illustrator (PDF-compatible).
def pdf(width, height):
    objects = [b"<< /Type /Catalog /Pages 2 0 R >>",
               b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
               f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {width} {height}] /Contents 4 0 R /Resources << >> >>".encode(),
               b"<< /Length 0 >>\nstream\n\nendstream"]
    body = b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n"
    offsets = []
    for i, obj in enumerate(objects, 1):
        offsets.append(len(body))
        body += f"{i} 0 obj\n".encode() + obj + b"\nendobj\n"
    xref = len(body)
    body += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n".encode()
    body += b"".join(f"{o:010d} 00000 n \n".encode() for o in offsets)
    body += f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    return body
(out / "template.pdf").write_bytes(pdf(*A4))
(out / "template.ai").write_bytes(pdf(*A4))

# --- PNG (white, 1920x1080), JPEG via sips.
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
raw = b"".join(b"\x00" + b"\xff" * (W * 3) for _ in range(H))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
(out / "template.png").write_bytes(png)
subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "90", str(out / "template.png"), "--out", str(out / "template.jpg")],
               check=True, stdout=subprocess.DEVNULL)

# --- PSD (white RGB, 1920x1080, one background, RLE/PackBits).
def packbits_row(width, value=0xff):
    data = b""
    left = width
    while left > 0:
        n = min(128, left)
        data += bytes([257 - n, value]) if n > 1 else bytes([0, value])
        left -= n
    return data
row = packbits_row(W)
counts = struct.pack(">H", len(row)) * (H * 3)
psd = (b"8BPS" + struct.pack(">H6xHIIHH", 1, 3, H, W, 8, 3)  # header: version 1, 3 channels, 8-bit RGB
       + struct.pack(">I", 0)   # color mode data
       + struct.pack(">I", 0)   # image resources
       + struct.pack(">I", 0)   # layer and mask info (flattened image only)
       + struct.pack(">H", 1) + counts + row * (H * 3))
(out / "template.psd").write_bytes(psd)

# --- Text formats with a little content.
(out / "template.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n  <title>{{{{project}}}}</title>\n  <rect width="100%" height="100%" fill="#ffffff"/>\n</svg>\n')
(out / "template.rtf").write_text("{\\rtf1\\ansi\\ansicpg1252\\cocoartf2822\n{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}\n\\paperw11900\\paperh16840\\margl1440\\margr1440\n\\f0\\fs24 \\cf0 \\\n}\n")
(out / "template.json").write_text("{\n  \"name\": \"{{project}}\",\n  \"date\": \"{{date}}\"\n}\n")
(out / "template.xml").write_text('<?xml version="1.0" encoding="UTF-8"?>\n<!-- {{project}} — {{file}} ({{date}}) -->\n<root/>\n')
# UTF-8 BOM: Excel then reads Japanese text in the CSV correctly.
(out / "template.csv").write_bytes(b"\xef\xbb\xbf")
(out / "template.txt").write_text("{{project}}\n{{date}}\n")
print("\n".join(sorted(f"{p.name}\t{p.stat().st_size}" for p in out.iterdir())))
