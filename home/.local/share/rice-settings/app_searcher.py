#!/usr/bin/python3
import json,sys
from pathlib import Path
from datetime import datetime
import waybar
FILE=Path.home()/'.config/rice-theme/apps.json'
STATE=Path.home()/'.local/state/rice-settings/apps'
DEFAULT=dict(width=600,height=454,columns=6,rows=3,iconSize=35,showSearch=True,showCategories=True,showLabels=True)
FIELDS=[dict(key=k,label=l,kind='number',min=lo,max=hi,step=step) for k,l,lo,hi,step in [('width','Ширина окна · px',360,1600,20),('height','Высота окна · px',240,1200,20),('columns','Столбцов в сетке',2,12,1),('rows','Видимых строк в сетке',1,8,1),('iconSize','Размер иконок · px',20,64,1)]] + [dict(key=k,label=l,kind='bool') for k,l in [('showSearch','Показывать строку поиска'),('showCategories','Показывать категории'),('showLabels','Показывать названия приложений')]]
PRESETS=[dict(name='Компактный',settings=dict(width=440,height=330,columns=4,rows=2)),dict(name='Стандартный',settings=dict(width=600,height=454,columns=6,rows=3)),dict(name='Большой',settings=dict(width=840,height=610,columns=8,rows=4))]
def read():
    try:return dict(DEFAULT,**json.loads(FILE.read_text()))
    except FileNotFoundError:return DEFAULT.copy()
def validate(data):
    if set(data)!=set(DEFAULT):raise ValueError('Некорректные настройки поиска')
    for field in FIELDS:
        value=data[field['key']]
        if field['kind']=='bool':
            if not isinstance(value,bool):raise ValueError(field['label'])
        elif type(value)!=int or not field['min']<=value<=field['max']:raise ValueError(field['label'])
    return data
def main(action):
    if action=='read':return dict(settings=read(),fields=FIELDS,presets=PRESETS,canRestore=any(STATE.glob('*.json')))
    if action=='apply':data=validate(json.load(sys.stdin))
    elif action=='restore':
        backups=sorted(STATE.glob('*.json'))
        if not backups:raise ValueError('Нет резервной копии')
        data=json.loads(backups[-1].read_text())
    else:raise ValueError('Неизвестная команда')
    STATE.mkdir(parents=True,exist_ok=True);(STATE/(datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.json')).write_text(json.dumps(read()))
    FILE.parent.mkdir(parents=True,exist_ok=True);waybar.atomic(FILE,json.dumps(data,ensure_ascii=False)+'\n')
    return dict(settings=data,canRestore=True,message='Настройки поиска применены')
if __name__=='__main__':
    try:print(json.dumps(main(sys.argv[1]),ensure_ascii=False))
    except Exception as e:print(json.dumps(dict(error=str(e)),ensure_ascii=False));sys.exit(1)
