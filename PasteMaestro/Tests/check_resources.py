from pathlib import Path
import subprocess,json,re
root=Path(__file__).resolve().parents[1]
for table in ['Localizable','Increment','Style','Maestro']:
    data={}
    for lang in ['ja','en','zh-Hans','ko']:
        p=root/'Resources'/f'{lang}.lproj'/f'{table}.strings'
        data[lang]=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(p)]))
        assert all(data[lang].values()), (lang,table,'empty translation')
    assert all(set(d)==set(data['ja']) for d in data.values()),table
    for key in data['ja']:
        formats=lambda s: sorted(re.findall(r'%(?:\d+\$)?(?:@|d|ld|lu|f|s)',s.replace('%%','')))
        assert all(formats(d[key])==formats(data['ja'][key]) for d in data.values()),(table,key)
    print(table+': 4 languages, keys and placeholders PASS')
