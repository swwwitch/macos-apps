# The name rule in FolderName.swift must follow the Keyboard Maestro macro it replaces.
from pathlib import Path
import plistlib
root = Path(__file__).resolve().parents[1]
macro = plistlib.load(open(root / 'KM/Folder Maker（案件） Local__.kmmacros', 'rb'))[0]['Macros'][0]
actions = []
def walk(items):
    for a in items:
        actions.append(a)
        for k in ('Actions', 'ThenActions', 'ElseActions'):
            if isinstance(a.get(k), list): walk(a[k])
walk(macro['Actions'])
texts = {a['Variable']: a['Text'] for a in actions if a.get('MacroActionType') == 'SetVariableToText'}
name = texts['local__folder']
assert name == '%Variable%Local__クライアント%%Variable%Local__地域%-%Variable%Local__年%%Variable%Local__月%%Variable%Local__日%%Variable%Local__備考%', name
# 地域 and 備考 get a leading "-" only when they are not empty.
prefixed = [a for a in actions if a.get('MacroActionType') == 'SetVariableToText' and a['Text'].startswith('-%Variable%')]
assert sorted(a['Variable'] for a in prefixed) == ['Local__備考', 'Local__地域']
# 年: this year when the month is below 11, else next year.
cond = next(a for a in actions if a.get('MacroActionType') == 'IfThenElse' and a['Conditions']['ConditionList'][0].get('Variable') == 'Local__年')
assert cond['Conditions']['ConditionList'][0]['VariableValue'] == '11'
# 月・日 are zero padded.
assert {a['Format'] for a in actions if a.get('MacroActionType') == 'SetVariableToCalculation'} == {'00'}
# Prompt fields, in order.
prompt = next(a for a in actions if a.get('MacroActionType') == 'PromptForUserInput')
assert [v['Variable'].replace('Local__', '') for v in prompt['Variables']] == ['作成先__最前面のフォルダー', 'クライアント', '地域', '年', '月', '日', '今日', '備考']
source = (root / 'Sources/FolderName.swift').read_text()
assert 'month ?? 1) < 11' in source and 'defaultPattern = "{client}-{project}-{date}-{memo}"' in source and 'var dateStyle = DateStyle.compact' in source
print('PASS: name template, optional "-" parts, year rule, zero padding and field order match the KM macro')
