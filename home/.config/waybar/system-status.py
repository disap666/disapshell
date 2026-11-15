#!/usr/bin/python3
import html
import json
from pathlib import Path
import subprocess
import time

def cpu():
    values=list(map(int,Path('/proc/stat').read_text().splitlines()[0].split()[1:9]))
    return sum(values),values[3]+values[4]

previous=cpu()
while True:
    time.sleep(3)
    now=cpu();total=now[0]-previous[0]
    usage=round(100*(1-(now[1]-previous[1])/total)) if total else 0
    previous=now
    mem={line.split(':')[0]:int(line.split()[1]) for line in Path('/proc/meminfo').read_text().splitlines()}
    used=(mem['MemTotal']-mem['MemAvailable'])/1048576
    processes=subprocess.run(['ps','-eo','comm,pcpu,pmem','--sort=-pcpu'],capture_output=True,text=True,check=True).stdout.splitlines()[1:6]
    details='\n'.join(html.escape(line.strip()) for line in processes)
    tip=f'<b>Система</b>\nCPU: {usage}%\nRAM: {used:.1f} / {mem["MemTotal"]/1048576:.1f} ГиБ\n\n<b>Процесс · CPU% · RAM%</b>\n{details}\n\nCPU процессов: среднее за время работы.\nНажми, чтобы открыть btop.'
    print(json.dumps({'text':f' {usage}%   󰍛 {used:.1f}G','tooltip':tip,'class':'busy' if usage>85 else 'normal'}),flush=True)
