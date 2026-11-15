#!/usr/bin/python3
"""Validated desktop and lock appearance. Never modifies authentication settings."""
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
import waybar
HOME = Path.home()
KIND = sys.argv[1] if len(sys.argv) > 1 else 'desktop'
FILE = HOME / f'.config/rice-theme/{KIND}.json'
STATE = HOME / f'.local/state/rice-settings/{KIND}'
HYPR = HOME / '.config/hypr/hyprland.conf'
GENERATED = HOME / '.config/hypr/rice-desktop.conf'
SOURCE = 'source = ~/.config/hypr/rice-desktop.conf'
def number(key, label, lo, hi, value, factor=1):
    return dict(key=key,label=label,kind='number',min=lo,max=hi,factor=factor,default=value), value
def boolean(key, label, value):
    return dict(key=key,label=label,kind='bool'), value
def color(key, label, value, group=None, hint=None):
    return dict(key=key,label=label,kind='color',group=group,hint=hint), value
def choice(key, label, values, value, group=None, hint=None):
    return dict(key=key,label=label,kind='choice',values=values,group=group,hint=hint), value
def grouped(spec, group, hint=None, **extra):
    field, value = spec
    field = dict(field, group=group, **extra)
    if hint: field['hint'] = hint
    return field, value
ANIMATIONS = ['Мягкие', 'Быстрые', 'Упругие']
if KIND == 'desktop':
    specs = [grouped(number('gapsIn','Между окнами',0,40,5),'Геометрия',slider=True,unit=' px'),
             grouped(number('gapsOut','От краёв экрана',0,100,10),'Геометрия',slider=True,unit=' px'),
             grouped(number('rounding','Скругление углов',0,40,14),'Геометрия',slider=True,unit=' px'),
             grouped(number('borderSize','Толщина рамки',0,10,2),'Геометрия',slider=True,unit=' px'),
             grouped(boolean('resizeOnBorder','Менять размер за рамку',True),'Геометрия','Тянуть окно за край без модификатора'),
             color('activeBorder','Активное окно · начало','#c6acee','Рамки'),
             color('activeBorder2','Активное окно · конец','#a8c9f5','Рамки','Одинаковые цвета дают сплошную рамку'),
             grouped(number('borderAngle','Угол градиента',0,360,45),'Рамки',slider=True,unit='°',step=15),
             color('inactiveBorder','Неактивное окно','#493957','Рамки'),
             grouped(boolean('blur','Размытие под прозрачным',True),'Стекло и тени'),
             grouped(number('blurSize','Радиус размытия',1,20,8),'Стекло и тени',slider=True),
             grouped(number('blurPasses','Проходов размытия',1,4,2),'Стекло и тени',slider=True,hint='Чем больше, тем мягче размытие и выше нагрузка на видеокарту'),
             grouped(boolean('shadow','Тени окон',True),'Стекло и тени'),
             grouped(number('shadowRange','Размер тени',2,60,18),'Стекло и тени',slider=True,unit=' px'),
             grouped(number('inactiveOpacity','Непрозрачность неактивных',50,100,100),'Стекло и тени',slider=True,unit='%'),
             grouped(boolean('dimInactive','Приглушать неактивные',False),'Стекло и тени'),
             grouped(boolean('animations','Анимации окон',True),'Движение'),
             choice('animStyle','Характер анимаций',ANIMATIONS,'Мягкие','Движение','Упругие: с небольшим перелётом при открытии')]
else:
    if KIND != 'lock': raise ValueError('Неизвестный раздел')
    specs = [choice('style','Стиль',['Обложка','Чёрная дыра'],'Обложка','Стиль','Обложка: размытые обои, крупные часы и виджеты'),
             grouped(number('blur','Размытие обоев',0,100,55),'Фон',slider=True,unit='%',hint='Для стиля «Обложка»'),
             grouped(number('dim','Затемнение обоев',0,80,25),'Фон',slider=True,unit='%'),
             grouped(boolean('video','Анимированный фон',True),'Фон','Видео для стиля «Чёрная дыра»'),
             grouped(number('videoOpacity','Яркость анимации',10,100,1,100),'Фон',slider=True,unit='%'),
             grouped(boolean('clock24','24-часовой формат',True),'Часы'),
             grouped(number('clockSize','Размер часов',60,180,138),'Часы',slider=True,unit=' px'),
             grouped(boolean('showDate','Показывать дату',True),'Часы'),
             grouped(boolean('showUser','Показывать имя пользователя',True),'Часы'),
             grouped(number('inputWidth','Ширина поля',240,600,320),'Поле пароля',slider=True,unit=' px',step=10),
             grouped(number('rounding','Скругление поля',0,30,19),'Поле пароля',slider=True,unit=' px'),
             grouped((dict(key='placeholder',label='Подсказка в поле',kind='text',maxLength=64),'Введите пароль'),'Поле пароля'),
             grouped(boolean('showMedia','Плеер',True),'Виджеты','Текущий трек с кнопками паузы и переключения'),
             grouped(boolean('showWidgets','Батарея и раскладка',True),'Виджеты'),
             grouped(boolean('powerButtons','Кнопки сна и питания',True),'Виджеты','Сон, перезагрузка, выключение в углу')]
FIELDS = [{k:v for k,v in s[0].items() if v is not None} for s in specs]
DEFAULT = {s[0]['key']:s[1] for s in specs}
def palette_borders():
    """Window border colours that follow the active rice palette."""
    try: c = json.loads((HOME/'.config/rice-theme/palette.json').read_text())['colors']
    except (OSError, ValueError, KeyError, TypeError): return {}
    pick = {'activeBorder': c.get('accent'), 'activeBorder2': c.get('border'), 'inactiveBorder': c.get('surface')}
    return {k: v for k, v in pick.items() if isinstance(v, str) and re.fullmatch(r'#[0-9a-fA-F]{6}', v)}
if KIND == 'desktop': DEFAULT.update(palette_borders())
PRESETS = ([dict(name='Мягкий',settings=dict(gapsIn=5,gapsOut=10,rounding=14,borderSize=2,blur=True,shadow=True,animations=True,animStyle='Мягкие',inactiveOpacity=100,dimInactive=False)),
            dict(name='Стекло',settings=dict(gapsIn=6,gapsOut=14,rounding=18,borderSize=1,blur=True,blurSize=10,blurPasses=3,shadow=True,shadowRange=28,inactiveOpacity=88,animStyle='Мягкие')),
            dict(name='Строгий',settings=dict(gapsIn=3,gapsOut=6,rounding=0,borderSize=2,blur=False,shadow=False,animations=True,animStyle='Быстрые',inactiveOpacity=100,dimInactive=False)),
            dict(name='Без рамок',settings=dict(gapsIn=4,gapsOut=8,rounding=12,borderSize=0,shadow=True,shadowRange=24))]
           if KIND == 'desktop' else [dict(name='Обложка',settings=dict(style='Обложка',blur=55,dim=25,clockSize=138,showMedia=True,showWidgets=True)),dict(name='Кино',settings=dict(style='Чёрная дыра',video=True,videoOpacity=1,clockSize=138)),dict(name='Спокойный',settings=dict(style='Обложка',blur=85,dim=45,clockSize=110,showMedia=False))])
def read():
    data = DEFAULT.copy()
    if KIND == 'desktop' and not FILE.exists():
        text = HYPR.read_text()
        for key, option in [('gapsIn','gaps_in'),('gapsOut','gaps_out'),('rounding','rounding'),('borderSize','border_size')]:
            matches = re.findall(r'^\s*'+option+r'\s*=\s*(\d+)',text,re.M)
            if matches: data[key] = int(matches[-1])
    if FILE.exists(): data.update({k:v for k,v in json.loads(FILE.read_text()).items() if k in DEFAULT})
    return data

def validate(data):
    if not isinstance(data,dict) or set(data)!=set(DEFAULT): raise ValueError('Неверный набор настроек')
    for f in FIELDS:
        value=data[f['key']]
        if f['kind']=='bool':
            if type(value)!=bool: raise ValueError(f['label'])
        elif f['kind']=='number':
            if isinstance(value,bool) or not isinstance(value,(int,float)) or not f['min']<=value*f['factor']<=f['max']: raise ValueError(f['label'])
            if f['factor']==1 and int(value)!=value: raise ValueError('Нужно целое число: '+f['label'])
        elif f['kind']=='color':
            if not isinstance(value,str) or not re.fullmatch(r'#[0-9a-fA-F]{6}',value): raise ValueError('Цвет: '+f['label'])
        elif f['kind']=='choice':
            if value not in f['values']: raise ValueError(f['label'])
        elif not isinstance(value,str) or not 1<=len(value)<=64 or any(ord(c)<32 for c in value): raise ValueError('Неверная подсказка')
    return data

CURVES = {
    'Мягкие': ('soft', '0.16, 1, 0.3, 1', 5, 'popin 90%', 'slide'),
    'Быстрые': ('quick', '0.25, 0.9, 0.3, 1', 3, 'popin 95%', 'slide'),
    'Упругие': ('spring', '0.34, 1.4, 0.64, 1', 5, 'popin 80%', 'slidefade 15%'),
}
def rgb(value, alpha=None):
    return f'rgba({value[1:]}{alpha})' if alpha else f'rgb({value[1:]})'
def render(data):
    yes=lambda key:'true' if data[key] else 'false'
    name, curve, speed, popin, workspace = CURVES[data['animStyle']]
    gradient = rgb(data['activeBorder']) if data['activeBorder'].lower()==data['activeBorder2'].lower() else f"{rgb(data['activeBorder'])} {rgb(data['activeBorder2'])} {data['borderAngle']}deg"
    return f'''# Managed by Rice Settings (Super+I, Окна). Manual edits are overwritten.
general {{
    gaps_in = {data['gapsIn']}
    gaps_out = {data['gapsOut']}
    border_size = {data['borderSize']}
    resize_on_border = {yes('resizeOnBorder')}
    col.active_border = {gradient}
    col.inactive_border = {rgb(data['inactiveBorder'], 'aa')}
}}
decoration {{
    rounding = {data['rounding']}
    active_opacity = 1.0
    inactive_opacity = {data['inactiveOpacity']/100:.2f}
    dim_inactive = {yes('dimInactive')}
    dim_strength = 0.12
    blur {{
        enabled = {yes('blur')}
        size = {data['blurSize']}
        passes = {data['blurPasses']}
    }}
    shadow {{
        enabled = {yes('shadow')}
        range = {data['shadowRange']}
        render_power = 3
        color = rgba(0c091488)
    }}
}}
animations {{
    enabled = {yes('animations')}
    bezier = {name}, {curve}
    animation = windows, 1, {speed}, {name}, {popin}
    animation = windowsOut, 1, {speed}, {name}, popin 85%
    animation = fade, 1, {speed}, {name}
    animation = border, 1, 8, default
    animation = workspaces, 1, {speed}, {name}, {workspace}
    animation = layers, 1, {speed}, {name}, fade
}}
'''

def compositor(*args):
    p=subprocess.run(['hyprctl',*args],capture_output=True,text=True,timeout=10)
    if p.returncode or "Couldn't" in p.stdout: raise ValueError('Hyprland: '+(p.stderr or p.stdout).strip())
    return p.stdout

def save(data):
    FILE.parent.mkdir(parents=True,exist_ok=True)
    if KIND=='lock':
        waybar.atomic(FILE,json.dumps(data,ensure_ascii=False,indent=2)+'\n')
        return
    paths=[HYPR,GENERATED,FILE]
    before={p:p.read_text() if p.exists() else None for p in paths}
    try:
        config=HYPR.read_text()
        waybar.atomic(GENERATED,render(data))
        if SOURCE not in config.splitlines(): waybar.atomic(HYPR,config.rstrip()+'\n\n# Desktop appearance\n'+SOURCE+'\n')
        compositor('reload')
        errors=compositor('configerrors').strip()
        if errors and errors!='ok': raise ValueError(errors)
        waybar.atomic(FILE,json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    except Exception:
        for p,text in before.items():
            if text is None: p.unlink(missing_ok=True)
            else: waybar.atomic(p,text)
        try: compositor('reload')
        except Exception: pass
        raise

def main(action):
    if action=='read':return dict(settings=read(),fields=FIELDS,presets=PRESETS,canRestore=any(STATE.glob('*.json')))
    if action in ('apply','preview'):data=validate(json.load(sys.stdin))
    elif action=='restore':
        backups=sorted(STATE.glob('*.json'))
        if not backups:raise ValueError('Нет резервной копии')
        data=validate(dict(DEFAULT,**{k:v for k,v in json.loads(backups[-1].read_text()).items() if k in DEFAULT}))
    else:raise ValueError('Неизвестная команда')
    previous=read()
    save(data)
    if action=='preview':return dict(settings=data,canRestore=True,message='Применено вживую')
    STATE.mkdir(parents=True,exist_ok=True)
    waybar.atomic(STATE/(datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.json'),json.dumps(previous,ensure_ascii=False))
    return dict(settings=data,canRestore=True,message='Оформление рабочего стола применено' if KIND=='desktop' else 'Оформление блокировки сохранено. Будет видно при следующей блокировке.')
if __name__=='__main__':
    try: print(json.dumps(main(sys.argv[2]),ensure_ascii=False))
    except Exception as e: print(json.dumps(dict(error=str(e)),ensure_ascii=False));sys.exit(1)
