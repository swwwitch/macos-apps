"""Creates small CSV / TSV / XLSX fixtures (no third-party modules). The XLSX has shared strings, numbers
and a formula with a cached value, which pandoc should read as the value."""
import zipfile
from pathlib import Path
root = Path(__file__).parent / 'Fixtures'
(root / 'sample.csv').write_text('商品,価格,数量\nりんご,120,3\n"バナナ, 輸入",80,12\n', encoding='utf-8')
(root / 'sample.tsv').write_text('商品\t価格\t数量\nりんご\t120\t3\nみかん\t60\t20\n', encoding='utf-8')
strings = ['商品', '価格', '数量', '合計', 'りんご', 'みかん', '入荷日']
def cell(ref, value, kind):
    if kind == 'd': return f'<c r="{ref}" s="1"><v>{value}</v></c>'
    if kind == 's': return f'<c r="{ref}" t="s"><v>{strings.index(value)}</v></c>'
    if kind == 'f': return f'<c r="{ref}"><f>{value[0]}</f><v>{value[1]}</v></c>'
    return f'<c r="{ref}"><v>{value}</v></c>'
rows = [[('A1','商品','s'),('B1','価格','s'),('C1','数量','s'),('D1','合計','s'),('E1','入荷日','s')],
        [('A2','りんご','s'),('B2',120,'n'),('C2',3,'n'),('D2',('B2*C2',360),'f'),('E2',46302,'d')],
        [('A3','みかん','s'),('B3',12.5,'n'),('C3',20,'n'),('D3',('B3*C3',250),'f'),('E3',46303.5,'d')]]
sheet = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' + ''.join(
    f'<row r="{i+1}">' + ''.join(cell(*c) for c in r) + '</row>' for i, r in enumerate(rows)) + '</sheetData></worksheet>'
shared = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="%d" uniqueCount="%d">%s</sst>' % (
    len(strings), len(strings), ''.join(f'<si><t>{s}</t></si>' for s in strings))
files = {
 '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/></Types>',
 '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
 'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="売上" sheetId="1" r:id="rId1"/></sheets></workbook>',
 'xl/_rels/workbook.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
 'xl/worksheets/sheet1.xml': sheet,
 'xl/sharedStrings.xml': shared,
 'xl/styles.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><cellXfs count="2"><xf numFmtId="0"/><xf numFmtId="14"/></cellXfs></styleSheet>',
}
with zipfile.ZipFile(root / 'sample.xlsx', 'w', zipfile.ZIP_DEFLATED) as z:
    for name, data in files.items(): z.writestr(name, data)
print('fixtures written')
