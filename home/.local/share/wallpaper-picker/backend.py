#!/usr/bin/python
"""Wallpaper gallery for ~/wallpapers; animated GIFs stay animated."""
import hashlib
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys
import time
from PIL import Image, ImageOps

HOME = Path.home()
ROOT = HOME / 'wallpapers'
CACHE = HOME / '.cache/wallpaper-picker'
STATE = HOME / '.local/state/wallpaper-picker/current'
ANIMATION = STATE.with_name('animation')
EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'}

SETTINGS = HOME / '.config/rice-theme/wallpaper.json'
TRANSITIONS = {'none', 'simple', 'fade', 'left', 'right', 'top', 'bottom', 'wipe', 'wave', 'grow', 'center', 'outer', 'any', 'random'}
RESIZE = {'crop', 'fit', 'stretch', 'no'}

def settings():
    import json
    try: saved = json.loads(SETTINGS.read_text())
    except (OSError, ValueError): saved = {}
    transition = saved.get('transition') if saved.get('transition') in TRANSITIONS else 'fade'
    resize = saved.get('resize') if saved.get('resize') in RESIZE else 'crop'
    try: duration = min(5.0, max(0.1, float(saved.get('duration', 0.7))))
    except (TypeError, ValueError): duration = 0.7
    return transition, duration, resize

def run(*args, **kwargs):
    return subprocess.run(args, **kwargs)

def notify(message):
    run('notify-send', 'Обои', message, check=False)

def files():
    ROOT.mkdir(exist_ok=True)
    return sorted((p for p in ROOT.rglob('*') if p.is_file() and p.suffix.lower() in EXTENSIONS), key=lambda p: str(p).casefold())

def apply(path):
    CACHE.mkdir(parents=True, exist_ok=True)
    if run('awww', 'query', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        with (CACHE / 'daemon.log').open('a') as log:
            subprocess.Popen(['awww-daemon'], stdout=log, stderr=log, start_new_session=True)
        for _ in range(50):
            time.sleep(.1)
            if run('awww', 'query', stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                break
        else:
            raise RuntimeError('Не удалось запустить awww-daemon')
    transition, duration, resize = settings()
    animated = path.suffix.lower() == '.gif' and bool(shutil.which('ffmpeg'))
    # awww would keep every decoded GIF frame in RAM, so it gets the first frame
    # and RiceDesktop plays the animation as a video on top of it.
    STATE.parent.mkdir(parents=True, exist_ok=True)
    if ANIMATION.exists() and ANIMATION.read_text().strip():
        layer('clear')
        time.sleep(.25)
    ANIMATION.write_text('')
    run('awww', 'img', '--transition-type', transition, '--transition-duration', str(duration), '--transition-fps', '60',
        '--resize', resize, str(still(path) if animated else path), check=True)
    temporary = STATE.with_suffix('.tmp')
    temporary.write_text(str(path))
    temporary.replace(STATE)
    if animated:
        wait = 0 if transition == 'none' else duration
        subprocess.Popen(['python3', str(HOME / '.local/share/wallpaper-picker/backend.py'), '--animate', str(path), resize, str(wait)],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    autotheme(path)

def animate(path, resize, wait):
    """Detached step of apply(): start the animation once awww's transition is over."""
    started = time.monotonic()
    try:
        clip = str(video(path))
    except (OSError, subprocess.CalledProcessError):
        run('awww', 'img', '--transition-type', 'none', '--resize', resize, str(path), check=False)
        return
    time.sleep(max(0, wait - (time.monotonic() - started)))
    if STATE.read_text() != str(path):
        return
    if not layer('set', clip, resize):
        run(str(HOME / '.local/bin/rice-desktop'), check=False)
        layer('set', clip, resize)
    ANIMATION.write_text(f'{clip}\n{resize}\n')

def layer(*call):
    return run('qs', 'ipc', '-c', 'RiceDesktop', 'call', 'wallpaper', *call,
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0

def still(path):
    key = hashlib.sha256(f'still:{path}:{path.stat().st_mtime_ns}'.encode()).hexdigest()
    target = CACHE / (key + '.png')
    if not target.exists():
        with Image.open(path) as image:
            image.convert('RGB').save(target)
    return target

def video(path):
    key = hashlib.sha256(f'video:{path}:{path.stat().st_mtime_ns}'.encode()).hexdigest()
    target = CACHE / (key + '.mp4')
    if not target.exists():
        temporary = target.with_suffix('.part.mp4')
        run('ffmpeg', '-v', 'error', '-y', '-i', str(path), '-an', '-fps_mode', 'passthrough', '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
            '-pix_fmt', 'yuv420p', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '16', '-movflags', '+faststart',
            str(temporary), check=True)
        temporary.replace(target)
    return target

def autotheme(path):
    """Recolour the rice from the new wallpaper when the user turned that on."""
    import json
    try: enabled = json.loads((HOME / '.config/rice-theme/autotheme.json').read_text()).get('enabled')
    except (OSError, ValueError): enabled = False
    if enabled:
        subprocess.Popen(['python3', str(HOME / '.local/share/rice-settings/presets.py'), 'wallpaper', str(path)],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

def thumbnail(path):
    key = hashlib.sha256(f'carousel-v2:{path}:{path.stat().st_mtime_ns}'.encode()).hexdigest()
    target = CACHE / (key + '.png')
    if not target.exists():
        with Image.open(path) as image:
            image = ImageOps.exif_transpose(image).convert('RGB')
            ImageOps.fit(image, (960, 540), method=Image.Resampling.LANCZOS).save(target)
    return target

def main():
    if len(sys.argv) == 5 and sys.argv[1] == '--animate':
        animate(Path(sys.argv[2]), sys.argv[3], float(sys.argv[4]))
        return
    choices = files()
    if not choices and len(sys.argv) > 1 and sys.argv[1] == '--list':
        print('{"current": "", "items": []}')
        return
    if not choices:
        notify('Добавь изображения или GIF в ~/wallpapers')
        return
    option = sys.argv[1] if len(sys.argv) > 1 else ''
    if option == '--list':
        # Used by Rice Settings: JSON list with cached thumbnails.
        import json
        current = STATE.read_text().strip() if STATE.exists() else ''
        items = []
        for path in choices:
            try: thumb = str(thumbnail(path))
            except (OSError, ValueError): thumb = ''
            items.append(dict(path=str(path), name=str(path.relative_to(ROOT)), thumb=thumb, gif=path.suffix.lower() == '.gif'))
        print(json.dumps(dict(current=current, root=str(ROOT), items=items), ensure_ascii=False))
        return
    if option == '--set':
        target = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else None
        if target not in [c.resolve() for c in choices]:
            raise ValueError('Файл не найден в ~/wallpapers')
        apply(target)
        return
    if option == '--restore':
        saved = Path(STATE.read_text()) if STATE.exists() else None
        apply(saved if saved and saved.is_file() and saved in choices else choices[0])
        return
    if option == '--random':
        current = STATE.read_text() if STATE.exists() else ''
        apply(random.choice([p for p in choices if str(p) != current] or choices))
        return
    CACHE.mkdir(parents=True, exist_ok=True)
    rows = ['↻  Случайные обои']
    for path in choices:
        label = str(path.relative_to(ROOT)).replace('\n', ' ').replace('\x00', '')
        if path.suffix.lower() == '.gif':
            label = 'GIF · ' + label
        try:
            rows.append(label + '\x00icon\x1f' + str(thumbnail(path)))
        except (OSError, ValueError):
            rows.append(label)
    result = run('rofi', '-no-config', '-dmenu', '-i', '-show-icons', '-theme', str(HOME / '.config/rofi/wallpapers.rasi'), '-p', 'ОБОИ', '-format', 'i', '-no-custom', input='\n'.join(rows), text=True, stdout=subprocess.PIPE)
    if result.returncode != 0:
        return
    index = int(result.stdout.strip())
    if index == 0:
        current = STATE.read_text() if STATE.exists() else ''
        apply(random.choice([p for p in choices if str(p) != current] or choices))
    elif 1 <= index <= len(choices):
        apply(choices[index - 1])

if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        notify(f'Не удалось сменить обои: {error}')
        print(error, file=sys.stderr)
        sys.exit(1)
