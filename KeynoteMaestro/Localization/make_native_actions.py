"""Explicitly translate the supplied reference's keyboard actions; never infer a mouse gesture as a key."""
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
rows=json.loads((root/'Resources/NativeShortcuts.json').read_text())
# Physical ANSI keys used for unshifted source letters/digits. Textual punctuation is resolved below.
letters=dict(zip('asdfhgzxcvbqwertyuiopljknm',[0,1,2,3,4,5,6,7,8,9,11,12,13,14,15,17,16,32,34,31,35,37,38,40,45,46]))
keys={**{k.upper():v for k,v in letters.items()},**dict(zip('1234567890',[18,19,20,21,23,22,26,28,25,29])),
      '←':123,'→':124,'↓':125,'↑':126,'Return':36,'Enter':76,'Tab':48,'Delete':51,'Forward Delete':117,
      'Esc':53,'Home':115,'End':119,'Page Up':116,'Page Down':121,'スペースバー':49,'¥':42}
modifiers={'Command':256,'Shift':512,'Option':2048,'Control':4096}
punctuation={'疑問符（?）':(44,512),'スラッシュ（/）':(44,0),'右山かっこ（>）':(47,512),
 '左山かっこ（<）':(43,512),'カンマ（,）':(43,0),'セミコロン（;）':(41,0),'コロン（:）':(41,512),
 '左角かっこ（[）':(33,0),'右角かっこ（]）':(30,0),'左波かっこ（{）':(33,512),
 '右波かっこ（}）':(30,512),'垂直バー（|）':(42,512),'グレイブ（`）':(50,0),
 'プラス記号（＋）':(24,512),'マイナス記号（－）':(27,0),'等号（＝）':(24,0)}
# Source alternatives with a keyboard path after a mouse alternative, repeated keys, or context prose.
overrides={'objects.01':'Command＋A','objects.02':'Shift＋Command＋A','editableShapes.03':'Delete',
 'tables.05':'Option＋Return','tables.06':'Tab','tables.14':'Tab','tables.15':'Esc','tables.25':'Return',
 'tables.46':'Option＋Return','presentation.07':'Shift＋←','tables.31':'Command＋Return',
 'textFormat.06':'Forward Delete','general.00':'Fn＋D'}
# Different arrow directions produce different actions, so every direction has its own assignment.
directional={
 'objects.10':('', '←→↑↓'),'objects.11':('Shift＋','←→↑↓'),
 'objects.12':('', '←→↑↓'),'objects.13':('Shift＋','←→↑↓'),
 'tables.32':('', '←→↑↓'),'tables.33':('Shift＋','←→↑↓'),
 'tables.39':('', '←→↑↓'),'tables.40':('Shift＋','←→↑↓'),
 'chartData.05':('', '←→'),'chartData.06':('', '↑↓'),
 'chartData.07':('', '←→↑↓'),'chartData.08':('Shift＋','←→↑↓'),
 'formulas.00':('Option＋','←→↑↓'),'formulas.01':('Option＋Shift＋','←→↑↓'),
 'formulas.02':('Option＋Command＋','←→↑↓')}

def stroke(text):
    text=text.replace('Control-Option','Control＋Option').replace('Control+Shift+F','Control＋Shift＋F')
    text=text.split('または')[0].split('/')[0].split('を押して')[0].strip()
    parts=text.split('＋');mods=0;fn=False
    while parts and parts[0] in set(modifiers)|{'Fn'}:
        name=parts.pop(0)
        if name=='Fn':fn=True
        else:mods|=modifiers[name]
    key='＋'.join(parts).strip()
    key=key.split('（キーボード')[0]
    key=key.replace('（Escape）','').replace('キーを押す','').replace('キー','').replace('（2回）','').strip()
    character=None;sourceMods=mods
    if key in punctuation:
        code,extra=punctuation[key];mods|=extra
        character={'疑問符（?）':'?','スラッシュ（/）':'/','右山かっこ（>）':'>','左山かっこ（<）':'<',
          'カンマ（,）':',','セミコロン（;）':';','コロン（:）':':','左角かっこ（[）':'[','右角かっこ（]）':']',
          '左波かっこ（{）':'{','右波かっこ（}）':'}','垂直バー（|）':'|','グレイブ（`）':'`',
          'プラス記号（＋）':'+','マイナス記号（－）':'-','等号（＝）':'='}[key]
    elif key in keys:code=keys[key]
    else:return None
    if fn and code==51:code=117;fn=False
    result=dict(code=code,modifiers=mods,fn=fn)
    if character:result.update(character=character,sourceModifiers=sourceMods)
    return result

actions=[];unsupported=[]
for row in rows:
    if row.get('commandID'):continue
    rid=row['id'];source=row['shortcut']
    if rid=='textFormat.01' or rid=='objects.00':continue # exact duplicate references are not displayed
    if rid in directional:
        prefix,directions=directional[rid]
        for d in directions:actions.append(dict(id=rid+'.'+str(keys[d]),sourceID=rid,label=d,strokes=[stroke(prefix+d)]))
        continue
    if rid=='presentation.14':
        for digit in '0123456789':actions.append(dict(id=rid+'.'+digit,sourceID=rid,label=digit,strokes=[stroke(digit)]))
        continue
    text=overrides.get(rid,source)
    result=stroke(text)
    if result:
        actions.append(dict(id=rid,sourceID=rid,label='',strokes=[result]*(2 if rid=='tables.31' else 1)))
    else:unsupported.append(dict(sourceID=rid,reason='configuredStyle' if rid=='textFormat.38' else ('gesture' if any(word in source for word in ['ドラッグ','クリック','スクロール','ポインタ','ハンドル','回転中']) else 'unresolved')))
assert not [x for x in unsupported if x['reason']=='unresolved'],unsupported
(root/'Resources/NativeActions.json').write_text(json.dumps(dict(actions=actions,unsupported=unsupported),ensure_ascii=False,indent=2)+'\n')
print('Native keyboard actions:',len(actions),'source entries:',len({x['sourceID'] for x in actions}),'gesture/style entries:',len(unsupported))
