#!/usr/bin/python3
import html,json,subprocess

def read(*args):
    r=subprocess.run(['playerctl',*args],capture_output=True,text=True,timeout=2)
    return r.stdout.strip() if r.returncode == 0 else ''
try:
    status=read('status')
    title=read('metadata','--format','{{title}}')
    artist=read('metadata','--format','{{artist}}')
    text=('󰎆  '+title) if title else '󰎆  Музыка'
    tip=(artist+'\n' if artist else '')+(title or 'Открыть Spotify')
    print(json.dumps({'text':html.escape(text),'tooltip':html.escape(tip),'class':status.lower() or 'idle'},ensure_ascii=False))
except (OSError,subprocess.TimeoutExpired):
    print(json.dumps({'text':'󰎆  Музыка','tooltip':'Открыть Spotify','class':'idle'},ensure_ascii=False))
