import json, subprocess, sys
from pathlib import Path
root = Path('/Users/takano/Git/macos-apps')
scratch = Path(__file__).parent
langs = ['ja', 'en', 'zh-Hans', 'ko']
common = ['about','settings','settingsTitle','services','hide','hideOthers','showAll','quit','file','openMainWindow','closeWindow','edit','undo','redo','cut','copy','paste','selectAll','window','minimize','zoom','bringAllToFront','help','appHelp','lastResult','settingsButton','login','loginSettings','loginEnabled','loginApproval','loginDisabled','loginNotFound','loginFailed','keepRunning','keepRunningHint','hotkeyTab','pause','hotkeyDisabled','hotkeyPaused','notifyTitle','notifySuccess','notifyHint','commandsOff','commandsRegisterFailed']
def load(lang):
    p = root/'SpreadsheetHelper/Resources'/f'{lang}.lproj'/'Localizable.strings'
    return json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(p)]))
out = {l: {} for l in langs}
for i, l in enumerate(langs):
    src = load(l)
    for k in common:
        out[l][k] = src[k].replace('SpreadsheetHelper', 'KeynoteHelper')
own = json.loads((scratch/'own.json').read_text())
for k, vals in own.items():
    for l, v in zip(langs, vals): out[l][k] = v
for line in (scratch/'commands.tsv').read_text().strip().split('\n'):
    k, *vals = line.split('\t')
    for l, v in zip(langs, vals): out[l]['command.'+k] = v
for l in langs:
    d = root/'KeynoteHelper/Resources'/f'{l}.lproj'; d.mkdir(parents=True, exist_ok=True)
    esc = lambda s: s.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n')
    (d/'Localizable.strings').write_text(''.join(f'"{k}" = "{esc(v)}";\n' for k, v in out[l].items()))
    ip = (root/'SpreadsheetHelper/Resources'/f'{l}.lproj'/'InfoPlist.strings').read_text()
    usage = {'ja':'Keynoteのオブジェクトやスライドの変更（不透明度・大きさ・トランジション・図形）と、表示中のスライドのPNG書き出しに使用します。',
             'en':'Used to change Keynote objects and slides (opacity, size, transitions, shapes) and to export the current slide as PNG.',
             'zh-Hans':'用于更改 Keynote 的对象和幻灯片（不透明度、大小、过渡、形状），以及将当前幻灯片导出为 PNG。',
             'ko':'Keynote의 객체와 슬라이드(불투명도, 크기, 트랜지션, 도형)를 변경하고 현재 슬라이드를 PNG로 내보내는 데 사용합니다.'}[l]
    (d/'InfoPlist.strings').write_text(f'"CFBundleDisplayName" = "KeynoteHelper";\n"NSAppleEventsUsageDescription" = "{usage}";\n')
print({l: len(v) for l, v in out.items()})
