#!/usr/bin/python3
import json, sys
from pathlib import Path
from datetime import datetime
import waybar
FILE=Path.home()/'.config/rice-theme/global.json'
STATE=Path.home()/'.local/state/rice-settings/global'
DEFAULT=dict(fontFamily='Noto Sans',textScale=1.0,glassOpacity=1.0)
def read():
    try: return dict(DEFAULT,**json.loads(FILE.read_text()))
    except FileNotFoundError: return DEFAULT.copy()
def main(action):
    if action=='read': return dict(settings=read(),canRestore=any(STATE.glob('*.json')))
    if action=='apply':
        data=json.load(sys.stdin)
        if set(data)!=set(DEFAULT): raise ValueError('Некорректные настройки')
        if not isinstance(data['fontFamily'],str) or not 1<=len(data['fontFamily'])<=150 or any(ord(c)<32 for c in data['fontFamily']): raise ValueError('Выбери шрифт')
        for key,lo,hi in [('textScale',.8,1.5),('glassOpacity',.3,1.5)]:
            if isinstance(data[key],bool) or not isinstance(data[key],(int,float)) or not lo<=data[key]<=hi: raise ValueError('Неверное значение: '+key)
    elif action=='restore':
        backups=sorted(STATE.glob('*.json'))
        if not backups: raise ValueError('Нет резервной копии')
        data=json.loads(backups[-1].read_text())
    else: raise ValueError('Неизвестная команда')
    STATE.mkdir(parents=True,exist_ok=True)
    (STATE/(datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.json')).write_text(json.dumps(read()))
    FILE.parent.mkdir(parents=True,exist_ok=True)
    css_path=waybar.BASE/'style.css'
    before_global=FILE.read_text() if FILE.exists() else '{}\n'
    before_css=css_path.read_text()
    appearance=waybar.read()['appearance']
    next_css=waybar.with_global(before_css,appearance,data)
    try:
        waybar.atomic(css_path,next_css)
        waybar.atomic(FILE,json.dumps(data,ensure_ascii=False)+'\n')
    except Exception:
        waybar.atomic(css_path,before_css)
        waybar.atomic(FILE,before_global)
        raise
    waybar.reload()
    return dict(settings=data,canRestore=True,message='Общее оформление применено')
if __name__=='__main__':
    try: print(json.dumps(main(sys.argv[1]),ensure_ascii=False))
    except Exception as e: print(json.dumps(dict(error=str(e)),ensure_ascii=False));sys.exit(1)
