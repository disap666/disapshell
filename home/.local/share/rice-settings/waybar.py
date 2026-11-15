#!/usr/bin/python3
import json, os, re, shutil, signal, subprocess, sys, tempfile
from pathlib import Path
from datetime import datetime
BASE = Path.home()/'.config/waybar'
STATE = Path.home()/'.local/state/rice-settings'
START = '/* rice-settings:start */'
GLOBAL_START = '/* rice-global:start */'
GLOBAL_END = '/* rice-global:end */'
GLOBAL_FILE = Path.home()/'.config/rice-theme/global.json'
DEFAULT = dict(background='#201a2d', highlight='#81679c', foreground='#e6ddf2', accent='#bba5d5', border='#d8c0f2', opacity=82, borderOpacity=34, radius=20, borderWidth=1, padding=6, font='JetBrainsMono Nerd Font', fontSize=12, gradient=True)
def read():
    # Waybar's active configuration is JSON; tolerate comments on later edits.
    raw=(BASE/'config.jsonc').read_text()
    raw=re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/', lambda m: m[0] if m[0].startswith('"') else '', raw, flags=re.S)
    raw=re.sub(r',\s*([}\]])', r'\1', raw)
    config=json.loads(raw)
    css=(BASE/'style.css').read_text()
    appearance=DEFAULT.copy()
    if START in css:
        match=re.search(r'/\* rice-settings:data (.*?) \*/',css)
        if match: appearance.update(json.loads(match[1]))
    return dict(config=config, appearance=appearance, css=css.split(START)[0].rstrip())
def validate(data):
    c,a=data['config'],data['appearance']
    if not isinstance(c,dict): raise ValueError('Конфигурация должна быть объектом JSON')
    if c.get('position','top') not in ['top','bottom','left','right']: raise ValueError('Неверное положение панели')
    for key,hi in [('width',16384),('height',2048),('spacing',500),('margin-top',2000),('margin-bottom',2000),('margin-left',2000),('margin-right',2000)]:
        if key in c and (not isinstance(c[key],int) or not 0<=c[key]<=hi): raise ValueError('Недопустимое значение: '+key)
    for group in ['left','center','right']:
        if not isinstance(c.get('modules-'+group,[]),list) or any(not isinstance(x,str) for x in c.get('modules-'+group,[])): raise ValueError('Список модулей должен содержать названия')
    visiting, visited = set(), set()
    def check_group(key):
        if key in visiting: raise ValueError('Группы не могут ссылаться друг на друга по кругу: '+key)
        if key in visited: return
        group = c.get(key)
        if not isinstance(group,dict): raise ValueError('Не найдена группа: '+key)
        children = group.get('modules')
        if not isinstance(children,list) or not children or any(not isinstance(x,str) for x in children): raise ValueError('Группа должна содержать модули: '+key)
        if group.get('orientation','inherit') not in ['inherit','horizontal','vertical','orthogonal']: raise ValueError('Неверная ориентация: '+key)
        visiting.add(key)
        for child in children:
            if child.startswith('group/'): check_group(child)
        visiting.remove(key)
        visited.add(key)
    for key in c:
        if key.startswith('group/'): check_group(key)
    for zone in ['left','center','right']:
        for key in c.get('modules-'+zone,[]):
            if key.startswith('group/'): check_group(key)
    for key in ['background','highlight','foreground','accent','border']:
        if not re.fullmatch(r'#[0-9a-fA-F]{6}',a[key]): raise ValueError('Цвет: #RRGGBB ('+key+')')
    for key,lo,hi in [('opacity',0,100),('borderOpacity',0,100),('radius',0,100),('borderWidth',0,10),('padding',0,60),('fontSize',6,40)]:
        if not isinstance(a[key],(int,float)) or not lo<=a[key]<=hi: raise ValueError('Недопустимое значение: '+key)
    if not re.fullmatch(r'[\w .,+-]{1,100}',a['font']): raise ValueError('Недопустимое имя шрифта')
    offsets=a.get('offsets',{})
    if not isinstance(offsets,dict): raise ValueError('Отступы модулей должны быть объектом')
    for key,o in offsets.items():
        if not isinstance(o,dict) or any(k not in ('l','r','w') or not isinstance(v,int) or not 0<=v<=800 for k,v in o.items()):
            raise ValueError('Недопустимый отступ модуля: '+key)
    if 'layout' in a:
        if a['layout'] not in (1,2,3,4): raise ValueError('Число частей панели: от 1 до 4')
        if not isinstance(a.get('gap'), (int,float)) or not 0 <= a['gap'] <= 100: raise ValueError('Отступ между частями: от 0 до 100')
        if a.get('splitZone', 'center') not in ('left','center','right'): raise ValueError('Неверная зона разделения')
    return c,a
def selector(key):
    # Waybar widget names: clock#date -> #clock.date, custom/x -> #custom-x, hyprland/window -> #window, group/x -> #x
    base,_,cls=key.partition('#')
    if base.startswith('custom/'): name='custom-'+base[7:]
    elif base=='pulseaudio/slider': name='pulseaudio-slider'
    elif '/' in base: name=base.split('/',1)[1]
    else: name=base
    if not re.fullmatch(r'[\w-]+',name) or (cls and not re.fullmatch(r'[\w-]+',cls)): return None
    return '#'+name+('.'+cls if cls else '')
def offsets_css(a):
    # free placement from the builder: per-module margins and fixed-width spacers
    out=''
    for key,o in sorted(a.get('offsets',{}).items()):
        sel=selector(key)
        if not sel: continue
        rules=[]
        if o.get('l'): rules.append(f"margin-left: {o['l']}px;")
        if o.get('r'): rules.append(f"margin-right: {o['r']}px;")
        if key.startswith('custom/rice-gap'):
            rules.append(f"min-width: {o.get('w',40)}px; padding: 0; background: transparent; border: none; box-shadow: none;")
        if rules: out+=f"{sel} {{ {' '.join(rules)} }}\n"
    return out
def rgba(hex,alpha): return 'rgba('+','.join(str(int(hex[i:i+2],16)) for i in (1,3,5))+f',{alpha/100:.3f})'
def global_stylesheet(a, style=None):
    if style is None:
        try: style = json.loads(GLOBAL_FILE.read_text())
        except (OSError, ValueError): style = {}
    if not style: return ''
    font = json.dumps(style.get('fontFamily', a['font']), ensure_ascii=False)
    size = a['fontSize'] * style.get('textScale',1)
    opacity = min(100,a['opacity'] * style.get('glassOpacity',1))
    bg = rgba(a['background'],opacity)
    if a['gradient']: bg=f"linear-gradient(to bottom, {rgba(a['highlight'],opacity*.5)}, {bg})"
    parts=a.get('layout',3)
    if parts==1: surfaces='window#waybar'
    elif parts==2: surfaces='.modules-left, .modules-right'
    elif parts==4:
        zone=a.get('splitZone','center')
        surfaces=', '.join('.modules-'+z for z in ('left','center','right') if z!=zone)+', #rice-preset-split-a, #rice-preset-split-b'
    else: surfaces='.modules-left, .modules-center, .modules-right'
    return f'''\n{GLOBAL_START}
* {{ font-family: {font}, "JetBrainsMono Nerd Font"; }}
window#waybar, window#waybar label, window#waybar button {{ font-size: {size:g}px; }}
{surfaces} {{ background: {bg}; }}
{GLOBAL_END}
'''
def with_global(css, appearance, style=None):
    if GLOBAL_END in css:
        css=re.sub(re.escape(GLOBAL_START)+r'.*?'+re.escape(GLOBAL_END),'',css,flags=re.S)
    else: css=css.split(GLOBAL_START)[0]
    return css.rstrip()+global_stylesheet(appearance,style)+'\n'
def stylesheet(a):
    bg=rgba(a['background'],a['opacity'])
    if a['gradient']: bg=f"linear-gradient(to bottom, {rgba(a['highlight'],a['opacity']*.5)}, {bg})"
    result = '\n'+START+'\n/* rice-settings:data '+json.dumps(a,ensure_ascii=False)+' */\n'+f'''
* {{ font-family: "{a['font']}"; font-size: {a['fontSize']}px; }}
.modules-left, .modules-center, .modules-right {{ background: {bg}; border: {a['borderWidth']}px solid {rgba(a['border'],a['borderOpacity'])}; border-radius: {a['radius']}px; padding: 0 {a['padding']}px; }}
window#waybar, #custom-launcher, #custom-search, #custom-telegram, #clock, #clock.date, #temperature, #language, #network, #bluetooth, #pulseaudio, #custom-notification, #custom-media, #custom-previous, #custom-play, #custom-next {{ color: {a['foreground']}; font-size: {a['fontSize']}px; }}
#battery {{ background: {a['accent']}; font-size: {a['fontSize']}px; }}
#workspaces button.active {{ background: {rgba(a['accent'],40)}; }}
'''
    if 'layout' in a:
        surface = f"background: {bg}; border: {a['borderWidth']}px solid {rgba(a['border'],a['borderOpacity'])}; border-radius: {a['radius']}px; padding: 0 {a['padding']}px;"
        clear = 'background: transparent; border: none; border-radius: 0; box-shadow: none; padding: 0; margin: 0;'
        result += f'\nwindow#waybar {{ {clear} }}\n.modules-left, .modules-center, .modules-right {{ margin: 0; }}\n'
        if a['layout'] == 1:
            result += f'window#waybar {{ {surface} }}\n.modules-left, .modules-center, .modules-right {{ {clear} }}\n'
        elif a['layout'] == 2:
            result += f'.modules-center {{ {clear} }}\n.modules-left {{ margin-right: {a["gap"]}px; }}\n'
        else:
            result += f'.modules-left {{ margin-right: {a["gap"]}px; }}\n.modules-right {{ margin-left: {a["gap"]}px; }}\n'
            if a['layout'] == 4:
                # Paint the two nested groups instead of their common container.
                zone = a.get('splitZone', 'center')
                result += f'.modules-{zone} {{ {clear} }}\n#rice-preset-split-a, #rice-preset-split-b {{ {surface} }}\n#rice-preset-split-a {{ margin-right: {a["gap"]}px; }}\n'
        if a['radius'] == 0:
            result += '#clock, #clock.date, #battery, #custom-media, #custom-play, #workspaces button { border-radius: 0; }\n'
    return with_global(result+offsets_css(a),a)
def atomic(path,content):
    fd,name=tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd,'w') as f: f.write(content)
        os.replace(name,path)
    finally:
        if os.path.exists(name): os.unlink(name)
def backup():
    dest=STATE/datetime.now().strftime('%Y%m%d-%H%M%S-%f'); dest.mkdir(parents=True)
    for name in ['config.jsonc','style.css']: shutil.copy2(BASE/name,dest/name)
    return dest
def reload():
    result=subprocess.run(['pkill','-USR2','-x','waybar'],capture_output=True)
    if result.returncode: subprocess.Popen(['waybar'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
def main():
    action=sys.argv[1]
    if action=='read': return read()
    if action in ('apply','preview'):
        data=json.load(sys.stdin); c,a=validate(data); current=read()
        if 'layout' in a:
            from presets import layout_config
            c = layout_config(c, {'parts': a['layout']}, geometry=False)
            a['splitZone'] = c.get('group/rice-preset-split-a',{}).get('_rice-preset-zone','center')
            validate(dict(config=c, appearance=a))
        dest=backup() if action=='apply' else None
        try:
            atomic(BASE/'config.jsonc',json.dumps(c,ensure_ascii=False,indent=2)+'\n')
            atomic(BASE/'style.css',data.get('css',current['css'])+stylesheet(a))
        except Exception:
            if dest:
                for name in ['config.jsonc','style.css']: shutil.copy2(dest/name,BASE/name)
            raise
        reload()
        return dict(ok=True,message='Применено. Резервная копия сохранена.')
    if action=='restore':
        backups=sorted(p for p in STATE.glob('*') if (p/'config.jsonc').exists())
        if not backups: raise ValueError('Резервных копий пока нет')
        previous=backups[-1]; backup()
        for name in ['config.jsonc','style.css']: atomic(BASE/name,(previous/name).read_text())
        reload(); return dict(ok=True,message='Предыдущая конфигурация восстановлена')
    raise ValueError('Неизвестная команда')
if __name__=='__main__':
    try: print(json.dumps(main(),ensure_ascii=False))
    except Exception as e: print(json.dumps(dict(error=str(e)),ensure_ascii=False)); sys.exit(1)
