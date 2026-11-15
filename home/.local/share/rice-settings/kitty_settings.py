#!/usr/bin/python3
import json,re,sys,subprocess
from pathlib import Path
from datetime import datetime
import waybar
FILE=Path.home()/'.config/kitty/kitty.conf'
STATE=Path.home()/'.local/state/rice-settings/kitty'
MARK='# rice-settings:kitty'
DEFAULT=dict(font_family='JetBrainsMono Nerd Font',font_size=12.,background='#252236',foreground='#eeeaf6',background_opacity=.9,window_padding_width=18,cursor='#d4bafa',cursor_shape='beam',cursor_blink_interval=0,selection_background='#675181',selection_foreground='#fbf8ff',scrollback_lines=20000,tab_bar_edge='top',tab_bar_style='separator',enable_audio_bell=False,remember_window_size=True)
FIELDS=[dict(key='font_family',label='Шрифт терминала',kind='font')]+[
 dict(key=k,label=l,kind='number',min=lo,max=hi,step=step,factor=factor) for k,l,lo,hi,step,factor in [('font_size','Размер шрифта · pt',60,320,5,10),('background_opacity','Непрозрачность · %',10,100,5,100),('window_padding_width','Внутренние отступы · px',0,80,1,1),('scrollback_lines','Строк в истории',1000,100000,1000,1),('cursor_blink_interval','Мигание курсора · мс (0 = выкл.)',0,2000,100,1000)]]+[
 dict(key=k,label=l,kind='color') for k,l in [('background','Фон'),('foreground','Текст'),('cursor','Курсор'),('selection_background','Фон выделения'),('selection_foreground','Текст выделения')]]+[
 dict(key='cursor_shape',label='Форма курсора',kind='choice',values=['beam','block','underline']),dict(key='tab_bar_edge',label='Положение вкладок',kind='choice',values=['top','bottom']),dict(key='tab_bar_style',label='Стиль вкладок',kind='choice',values=['separator','fade','slant','powerline','hidden'])]+[
 dict(key=k,label=l,kind='bool') for k,l in [('enable_audio_bell','Звуковой сигнал'),('remember_window_size','Запоминать размер окна')]]
def read():
    data=DEFAULT.copy()
    for line in FILE.read_text().splitlines():
        parts=line.strip().split(None,1)
        if len(parts)!=2 or parts[0] not in DEFAULT:continue
        key,value=parts
        try:
            if isinstance(DEFAULT[key],bool):data[key]=value.lower() in ('yes','true','1')
            elif isinstance(DEFAULT[key],(int,float)):data[key]=float(value)
            else:data[key]=value
        except ValueError:pass
    return data
def validate(data):
    if set(data)!=set(DEFAULT):raise ValueError('Некорректные настройки терминала')
    for field in FIELDS:
        value=data[field['key']];kind=field['kind']
        if kind=='font':
            if not isinstance(value,str) or not 1<=len(value)<=150 or any(ord(c)<32 for c in value):raise ValueError('Неверный шрифт')
        elif kind=='number':
            if isinstance(value,bool) or not isinstance(value,(int,float)) or not field['min']<=value*field['factor']<=field['max']:raise ValueError(field['label'])
        elif kind=='color':
            if not isinstance(value,str) or not re.fullmatch(r'#[0-9a-fA-F]{6}',value):raise ValueError(field['label'])
        elif kind=='choice':
            if value not in field['values']:raise ValueError(field['label'])
        elif kind=='bool' and not isinstance(value,bool):raise ValueError(field['label'])
    return data
def render(text,data):
    # Keep the preset's ANSI palette and other appearance keys when editing a field.
    previous=text.split(MARK,1)[1] if MARK in text else ''
    retained=[line for line in previous.splitlines() if line.strip() and line.strip().split(None,1)[0] not in data]
    lines=[]
    for key,value in data.items():
        if isinstance(value,bool):value='yes' if value else 'no'
        elif key in ('window_padding_width','scrollback_lines'):value=str(int(value))
        lines.append(f'{key} {value}')
    return text.split(MARK)[0].rstrip()+'\n\n'+MARK+'\n'+'\n'.join(retained+lines)+'\n'
def reload():
    result=subprocess.run(['pkill','-USR1','-x','kitty'],capture_output=True)
    return result.returncode==0
def main(action):
    if action=='read':return dict(settings=read(),fields=FIELDS,presets=[],canRestore=any(STATE.glob('*.conf')))
    before=FILE.read_text()
    if action in ('apply','preview'):text=render(before,validate(json.load(sys.stdin)))
    elif action=='restore':
        backups=sorted(STATE.glob('*.conf'))
        if not backups:raise ValueError('Нет резервной копии')
        text=backups[-1].read_text()
    else:raise ValueError('Неизвестная команда')
    if action!='preview':STATE.mkdir(parents=True,exist_ok=True);(STATE/(datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.conf')).write_text(before)
    waybar.atomic(FILE,text);reloaded=reload()
    return dict(settings=read(),canRestore=True,message='Настройки Kitty сохранены. '+('Отправлена команда перечитать конфигурацию.' if reloaded else 'Будут использованы при следующем запуске.'))
if __name__=='__main__':
    try:print(json.dumps(main(sys.argv[1]),ensure_ascii=False))
    except Exception as e:print(json.dumps(dict(error=str(e)),ensure_ascii=False));sys.exit(1)
