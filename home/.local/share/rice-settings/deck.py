#!/usr/bin/python3
import json
import re
import sys
from datetime import datetime
from pathlib import Path
import waybar

FILE = Path.home()/'.config/rice-theme/deck.json'
PALETTE = Path.home()/'.config/rice-theme/palette.json'
STATE = Path.home()/'.local/state/rice-settings/deck'
DEFAULT_APPS = [dict(id=i, name=n, icon=ico, match=m) for i,n,ico,m in [
    ('kitty','Терминал','kitty','^kitty$'), ('org.kde.dolphin','Файлы','org.kde.dolphin','dolphin'),
    ('google-chrome','Chrome','google-chrome','google-chrome|chrome'), ('code','VS Code','vscode','^code$|code-oss'),
    ('org.telegram.desktop','Telegram','org.telegram.desktop','telegram'), ('discord','Discord','discord','discord'), ('spotify','Spotify','spotify','spotify')]]
DEFAULT = dict(parts=1, radius=23, gap=0, padding=7, opacity=.86, borderOpacity=.5, borderWidth=1,
               scale=1.25, iconRadius=13, bottomMargin=10, gradient=True, autoHide=True, zoom=True,
               showRunning=True, showLauncher=True, alignment='center', hideDelay=450, tintIcons=True, background='#211a2e', highlight='#493957',
               accent='#bd9ce9', foreground='#eee7fa', border='#beadd9', apps=DEFAULT_APPS)

def load(path):
    try: return json.loads(path.read_text())
    except FileNotFoundError: return {}

def read():
    palette=load(PALETTE); data=DEFAULT.copy(); data['apps']=list(DEFAULT_APPS)
    colors=palette.get('colors',{})
    for key in ('background','accent','foreground','border'): data[key]=colors.get(key,data[key])
    data['highlight']=colors.get('surface', data['highlight'])
    data.update({k:v for k,v in palette.get('deck',{}).items() if k in data})
    data.update(load(FILE))
    return data

def validate(data):
    if set(data) != set(DEFAULT): raise ValueError('Некорректный набор настроек дока')
    for key in ('background','highlight','accent','foreground','border'):
        if not isinstance(data[key],str) or not re.fullmatch(r'#[0-9a-fA-F]{6}',data[key]): raise ValueError('Цвет: #RRGGBB ('+key+')')
    if data['alignment'] not in ('left','center','right'): raise ValueError('Неверное положение дока')
    for key,lo,hi in [('parts',1,4),('radius',0,40),('gap',0,60),('padding',0,24),('opacity',0,1),('borderOpacity',0,1),('borderWidth',0,5),('scale',.7,1.8),('iconRadius',0,25),('bottomMargin',0,100),('hideDelay',0,3000)]:
        value=data[key]
        if isinstance(value,bool) or not isinstance(value,(int,float)) or not lo<=value<=hi: raise ValueError('Недопустимое значение: '+key)
    if int(data['parts']) != data['parts']: raise ValueError('Число частей должно быть целым')
    for key in ('gradient','autoHide','zoom','showRunning','showLauncher','tintIcons'):
        if not isinstance(data[key],bool): raise ValueError('Неверный переключатель: '+key)
    apps=data['apps']
    if not isinstance(apps,list) or len(apps)>40: raise ValueError('Не более 40 приложений')
    ids=set()
    for app in apps:
        if not isinstance(app,dict) or set(app)!={'id','name','icon','match'}: raise ValueError('Некорректное приложение')
        if any(not isinstance(app[k],str) or not 0<len(app[k])<=500 for k in app): raise ValueError('Некорректные данные приложения')
        if app['id'] in ids: raise ValueError('Приложение уже закреплено')
        ids.add(app['id'])
        try: re.compile(app['match'])
        except re.error: raise ValueError('Неверный шаблон окна')
    if not apps and not data['showLauncher']: raise ValueError('Оставь хотя бы приложение или кнопку поиска')
    return data

def save(data):
    FILE.parent.mkdir(parents=True,exist_ok=True)
    waybar.atomic(FILE,json.dumps(data,ensure_ascii=False,indent=2)+'\n')

def main(args):
    action=args[0]
    if action=='read': return dict(settings=read(),canRestore=any(STATE.glob('*.json')))
    if action in ('apply','preview'): data=validate(json.load(sys.stdin))
    elif action=='restore':
        backups=sorted(STATE.glob('*.json'))
        if not backups: raise ValueError('Нет резервных копий дока')
        data=json.loads(backups[-1].read_text())
    else: raise ValueError('Неизвестная команда')
    if action!='preview':
      STATE.mkdir(parents=True,exist_ok=True)
      (STATE/(datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.json')).write_text(json.dumps(load(FILE)))
    save(data)
    return dict(ok=True,settings=read(),canRestore=True,message='Настройки дока применены' if action=='apply' else 'Предыдущие настройки дока восстановлены')

if __name__=='__main__':
    try: print(json.dumps(main(sys.argv[1:]),ensure_ascii=False))
    except Exception as e: print(json.dumps(dict(error=str(e)),ensure_ascii=False));sys.exit(1)
