#!/usr/bin/python3
"""Keyboard, pointer, touchpad gestures and night light (hyprsunset).

Writes ~/.config/hypr/rice-system.conf (sourced from hyprland.conf) and
~/.config/hypr/hyprsunset.conf. Every apply is checked with `hyprctl configerrors`
and rolled back on failure.
"""
import json
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
import waybar

HOME = Path.home()
FILE = HOME / '.config/rice-theme/system.json'
STATE = HOME / '.local/state/rice-settings/system'
HYPR = HOME / '.config/hypr/hyprland.conf'
GENERATED = HOME / '.config/hypr/rice-system.conf'
SUNSET = HOME / '.config/hypr/hyprsunset.conf'
SOURCE = 'source = ~/.config/hypr/rice-system.conf'

SWITCHES = {
    'Alt + Shift': 'grp:alt_shift_toggle',
    'Ctrl + Shift': 'grp:ctrl_shift_toggle',
    'Caps Lock': 'grp:caps_toggle',
    'Правый Alt': 'grp:toggle',
    'Alt + Пробел': 'grp:alt_space_toggle',
}
FOCUS = {'По клику': 0, 'За курсором': 1}
NIGHT = ['Выключен', 'Всегда', 'По расписанию']

def f(key, label, kind, group, value, **extra):
    return dict(key=key, label=label, kind=kind, group=group, **extra), value

SPECS = [
    f('layouts', 'Раскладки', 'text', 'Клавиатура', 'us,ru,ua', hint='Коды XKB через запятую: us, ru, ua, de', placeholder='us,ru', maxLength=40),
    f('layoutSwitch', 'Переключение раскладки', 'choice', 'Клавиатура', 'Alt + Shift', values=list(SWITCHES)),
    f('repeatDelay', 'Задержка автоповтора', 'number', 'Клавиатура', 600, min=150, max=1000, step=25, slider=True, unit=' мс'),
    f('repeatRate', 'Скорость автоповтора', 'number', 'Клавиатура', 25, min=10, max=60, step=1, slider=True, hint='Символов в секунду'),
    f('numlock', 'NumLock при входе', 'bool', 'Клавиатура', False),
    f('focus', 'Фокус окон', 'choice', 'Мышь и тачпад', 'По клику', values=list(FOCUS), hint='«За курсором»: окно активируется при наведении'),
    f('sensitivity', 'Скорость курсора', 'number', 'Мышь и тачпад', 0, min=-100, max=100, step=5, factor=100, slider=True),
    f('naturalScroll', 'Естественная прокрутка', 'bool', 'Мышь и тачпад', False, hint='Контент движется за пальцами, как на телефоне'),
    f('tapToClick', 'Касание вместо клика', 'bool', 'Мышь и тачпад', True),
    f('disableTyping', 'Выключать тачпад при наборе', 'bool', 'Мышь и тачпад', True),
    f('gestures', 'Свайп тремя пальцами', 'bool', 'Мышь и тачпад', False, hint='Влево и вправо: переключение рабочих столов'),
    f('nightMode', 'Ночной свет', 'choice', 'Ночной свет', 'Выключен', values=NIGHT, hint='Тёплый оттенок экрана вечером (hyprsunset)'),
    f('nightTemp', 'Теплота', 'number', 'Ночной свет', 4500, min=2500, max=6000, step=100, slider=True, unit=' K', hint='Чем меньше, тем теплее'),
    f('nightFrom', 'Включать в', 'text', 'Ночной свет', '21:00', placeholder='21:00', maxLength=5),
    f('nightTo', 'Выключать в', 'text', 'Ночной свет', '07:00', placeholder='07:00', maxLength=5),
]
FIELDS = [s[0] for s in SPECS]
DEFAULT = {s[0]['key']: s[1] for s in SPECS}
PRESETS = [
    dict(name='Ноутбук', settings=dict(naturalScroll=True, tapToClick=True, disableTyping=True, gestures=True)),
    dict(name='Мышь', settings=dict(naturalScroll=False, gestures=False, focus='По клику')),
    dict(name='Вечер', settings=dict(nightMode='По расписанию', nightTemp=4200, nightFrom='21:00', nightTo='07:00')),
]

def current_hypr():
    """Seed defaults from what hyprland.conf really uses, so the first apply changes nothing."""
    data = DEFAULT.copy()
    try: text = HYPR.read_text()
    except OSError: return data
    pick = lambda opt: (re.findall(r'^\s*' + opt + r'\s*=\s*(.+?)\s*$', text, re.M) or [None])[-1]
    if pick('kb_layout'): data['layouts'] = pick('kb_layout').replace(' ', '')
    options = pick('kb_options') or ''
    for name, option in SWITCHES.items():
        if option in options: data['layoutSwitch'] = name
    if pick('follow_mouse') in ('1', '2', '3'): data['focus'] = 'За курсором'
    return data

def read():
    data = current_hypr()
    if FILE.exists():
        data.update({k: v for k, v in json.loads(FILE.read_text()).items() if k in DEFAULT})
    return data

def clock(value, label):
    m = re.fullmatch(r'([01]?\d|2[0-3]):([0-5]\d)', value or '')
    if not m: raise ValueError(f'{label}: время в формате ЧЧ:ММ')
    return f'{int(m[1]):02d}:{m[2]}'

def validate(data):
    if not isinstance(data, dict) or set(data) != set(DEFAULT): raise ValueError('Неверный набор настроек')
    for field in FIELDS:
        value, label = data[field['key']], field['label']
        if field['kind'] == 'bool' and type(value) is not bool: raise ValueError(label)
        if field['kind'] == 'choice' and value not in field['values']: raise ValueError(label)
        if field['kind'] == 'number':
            if isinstance(value, bool) or not isinstance(value, (int, float)): raise ValueError(label)
            if not field['min'] <= round(value * field.get('factor', 1)) <= field['max']: raise ValueError(label)
    layouts = [x.strip() for x in data['layouts'].split(',') if x.strip()]
    if not 1 <= len(layouts) <= 4 or not all(re.fullmatch(r'[a-z]{2,3}(\([a-z_]+\))?', x) for x in layouts):
        raise ValueError('Раскладки: коды вроде us,ru,ua (до четырёх)')
    data['layouts'] = ','.join(layouts)
    data['nightFrom'] = clock(data['nightFrom'], 'Включать в')
    data['nightTo'] = clock(data['nightTo'], 'Выключать в')
    if data['nightMode'] != 'Выключен' and not shutil.which('hyprsunset'):
        raise ValueError('Ночной свет: не установлен hyprsunset')
    return data

def render(data):
    yes = lambda key: 'true' if data[key] else 'false'
    text = f'''# Managed by Rice Settings (Super+I, Ввод и экран). Manual edits are overwritten.
input {{
    kb_layout = {data['layouts']}
    kb_options = {SWITCHES[data['layoutSwitch']]}
    numlock_by_default = {yes('numlock')}
    repeat_delay = {data['repeatDelay']}
    repeat_rate = {data['repeatRate']}
    follow_mouse = {FOCUS[data['focus']]}
    sensitivity = {data['sensitivity']:.2f}
    touchpad {{
        natural_scroll = {yes('naturalScroll')}
        tap-to-click = {yes('tapToClick')}
        disable_while_typing = {yes('disableTyping')}
    }}
}}
'''
    if data['gestures']:
        text += 'gesture = 3, horizontal, workspace\n'
    if data['nightMode'] != 'Выключен':
        text += 'exec-once = hyprsunset\n'
    return text

def render_sunset(data):
    temp = data['nightTemp']
    if data['nightMode'] == 'Всегда':
        return f'# Managed by Rice Settings\nprofile {{\n    time = 00:00\n    temperature = {temp}\n}}\n'
    return (f'# Managed by Rice Settings\nprofile {{\n    time = {data["nightTo"]}\n    identity = true\n}}\n'
            f'profile {{\n    time = {data["nightFrom"]}\n    temperature = {temp}\n}}\n')

def hyprctl(*args):
    p = subprocess.run(['hyprctl', *args], capture_output=True, text=True, timeout=10)
    if p.returncode or "Couldn't" in p.stdout: raise ValueError('Hyprland: ' + (p.stderr or p.stdout).strip())
    return p.stdout

def restart_sunset(data):
    subprocess.run(['pkill', '-x', 'hyprsunset'], capture_output=True)
    if data['nightMode'] != 'Выключен':
        subprocess.Popen(['hyprsunset'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

def save(data):
    paths = [HYPR, GENERATED, SUNSET, FILE]
    before = {p: p.read_text() if p.exists() else None for p in paths}
    try:
        config = HYPR.read_text()
        waybar.atomic(GENERATED, render(data))
        if data['nightMode'] != 'Выключен': waybar.atomic(SUNSET, render_sunset(data))
        if SOURCE not in config.splitlines():
            waybar.atomic(HYPR, config.rstrip() + '\n\n# Input, gestures, night light\n' + SOURCE + '\n')
        hyprctl('reload')
        errors = hyprctl('configerrors').strip()
        if errors and errors != 'ok': raise ValueError(errors)
        FILE.parent.mkdir(parents=True, exist_ok=True)
        waybar.atomic(FILE, json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    except Exception:
        for p, text in before.items():
            if text is None: p.unlink(missing_ok=True)
            else: waybar.atomic(p, text)
        try: hyprctl('reload')
        except Exception: pass
        raise
    restart_sunset(data)

def main(action):
    if action == 'read':
        return dict(settings=read(), fields=FIELDS, presets=PRESETS, canRestore=any(STATE.glob('*.json')))
    if action == 'apply':
        data = validate(json.load(sys.stdin))
    elif action == 'restore':
        backups = sorted(STATE.glob('*.json'))
        if not backups: raise ValueError('Нет резервной копии')
        data = validate(dict(DEFAULT, **json.loads(backups[-1].read_text())))
        backups[-1].unlink()
    else:
        raise ValueError('Неизвестная команда')
    previous = read()
    save(data)
    if action == 'apply':
        STATE.mkdir(parents=True, exist_ok=True)
        waybar.atomic(STATE / (datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.json'), json.dumps(previous, ensure_ascii=False))
        for old in sorted(STATE.glob('*.json'))[:-20]: old.unlink()
    return dict(settings=data, canRestore=any(STATE.glob('*.json')), message='Ввод и ночной свет применены')

if __name__ == '__main__':
    try: print(json.dumps(main(sys.argv[1]), ensure_ascii=False))
    except Exception as e: print(json.dumps(dict(error=str(e)), ensure_ascii=False)); sys.exit(1)
