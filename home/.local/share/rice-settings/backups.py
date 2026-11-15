#!/usr/bin/python3
"""Rice backups: tar.gz snapshots of every config the rice is made of.

backups.py list | create [label] | restore NAME | delete NAME | tidy
Prints JSON. Restore first makes an automatic snapshot of the current state,
so a restore can itself be undone.
"""
import json
import os
import subprocess
import sys
import tarfile
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
DIR = HOME / '.local/share/rice-backups'
SOURCES = ['.config/quickshell', '.config/hypr', '.config/waybar', '.config/kitty', '.config/rice-theme',
           '.config/rofi', '.local/share/rice-settings', '.local/share/wallpaper-picker', '.local/bin',
           '.zshrc', '.face']
SKIP_DIRS = {'__pycache__', 'lock-assets', '.backup-styles', '.backup-extras'}
AUTO_KEEP = 10


def is_leftover(name):
    return '.before-' in name or name.endswith('.save')


def wanted(rel):
    parts = Path(rel).parts
    if any(p in SKIP_DIRS for p in parts): return False
    if is_leftover(parts[-1]): return False
    full = HOME / rel
    if full.is_symlink(): return False
    # ~/.local/bin also holds unrelated launchers; keep only small text scripts
    if parts[:2] == ('.local', 'bin') and full.is_file() and full.stat().st_size > 64 * 1024: return False
    return True


def collect(predicate):
    out = []
    for src in SOURCES:
        base = HOME / src
        if base.is_file():
            if predicate(src): out.append(src)
            continue
        if not base.is_dir(): continue
        for root, dirs, files in os.walk(base):
            rel_root = Path(root).relative_to(HOME)
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for f in files:
                rel = str(rel_root / f)
                if predicate(rel): out.append(rel)
    return sorted(set(out))


def meta_path(archive):
    return archive.with_suffix('').with_suffix('.json')


def write_archive(files, label, kind):
    DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now()
    name = 'rice-' + stamp.strftime('%Y%m%d-%H%M%S')
    archive = DIR / (name + '.tar.gz')
    n = 1
    while archive.exists():
        archive = DIR / f'{name}-{n}.tar.gz'; n += 1
    tmp = archive.with_name(archive.name + '.part')
    with tarfile.open(tmp, 'w:gz') as tar:
        for rel in files:
            tar.add(HOME / rel, arcname=rel, recursive=False)
    tmp.replace(archive)
    meta = dict(name=archive.name, label=label, kind=kind, created=stamp.isoformat(timespec='seconds'),
                files=len(files), size=archive.stat().st_size)
    meta_path(archive).write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n')
    return meta


def items():
    DIR.mkdir(parents=True, exist_ok=True)
    out = []
    for archive in DIR.glob('rice-*.tar.gz'):
        try: meta = json.loads(meta_path(archive).read_text())
        except (OSError, ValueError):
            meta = dict(name=archive.name, label='', kind='manual', files=0,
                        created=datetime.fromtimestamp(archive.stat().st_mtime).isoformat(timespec='seconds'))
        meta['size'] = archive.stat().st_size
        out.append(meta)
    return sorted(out, key=lambda m: m['created'], reverse=True)


def prune_auto():
    autos = [m for m in items() if m.get('kind') == 'auto']
    for m in autos[AUTO_KEEP:]:
        remove(m['name'])


def archive_of(name):
    path = (DIR / name).resolve()
    if path.parent != DIR.resolve() or not path.name.endswith('.tar.gz') or not path.exists():
        raise ValueError('Копия не найдена')
    return path


def remove(name):
    path = archive_of(name)
    path.unlink()
    try: meta_path(path).unlink()
    except OSError: pass


def reload_desktop():
    def quiet(*cmd):
        try: subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        except Exception: pass
    quiet('hyprctl', 'reload')
    quiet('pkill', '-SIGUSR2', '-x', 'waybar')
    quiet('pkill', '-SIGUSR1', '-x', 'kitty')


def restore(name):
    path = archive_of(name)
    before = write_archive(collect(wanted), 'Перед восстановлением', 'auto')
    with tarfile.open(path, 'r:gz') as tar:
        members = []
        for m in tar.getmembers():
            target = (HOME / m.name).resolve()
            if not str(target).startswith(str(HOME) + os.sep) or not (m.isfile() or m.isdir()):
                continue
            members.append(m)
        tar.extractall(HOME, members=members, filter='data')
    reload_desktop()
    prune_auto()
    return before


def main(args):
    action = args[0] if args else 'list'
    if action == 'list':
        return dict(items=items(), dir=str(DIR))
    if action == 'create':
        label = ' '.join(args[1:]).strip()[:80]
        meta = write_archive(collect(wanted), label, 'manual')
        return dict(ok=True, message=f'Копия создана, файлов: {meta["files"]}', items=items())
    if action == 'auto':
        meta = write_archive(collect(wanted), ' '.join(args[1:]).strip()[:80] or 'Автоматическая', 'auto')
        prune_auto()
        return dict(ok=True, message='Автоматическая копия создана', items=items())
    if action == 'restore':
        if len(args) < 2: raise ValueError('Не указана копия')
        restore(args[1])
        return dict(ok=True, message='Восстановлено. Текущее состояние сохранено отдельной копией', items=items())
    if action == 'delete':
        if len(args) < 2: raise ValueError('Не указана копия')
        remove(args[1])
        return dict(ok=True, message='Копия удалена', items=items())
    if action == 'tidy':
        leftovers = collect(lambda rel: is_leftover(Path(rel).name) and (HOME / rel).is_file() and not (HOME / rel).is_symlink())
        if not leftovers:
            return dict(ok=True, message='Старых файлов не найдено', items=items())
        meta = write_archive(leftovers, f'Старые .before-файлы ({len(leftovers)})', 'manual')
        for rel in leftovers:
            (HOME / rel).unlink()
        return dict(ok=True, message=f'Убрано файлов: {len(leftovers)}. Они сохранены в копии', items=items())
    if action == 'leftovers':
        leftovers = collect(lambda rel: is_leftover(Path(rel).name) and (HOME / rel).is_file() and not (HOME / rel).is_symlink())
        return dict(count=len(leftovers), files=leftovers)
    raise ValueError('Неизвестная команда')


if __name__ == '__main__':
    try: print(json.dumps(main(sys.argv[1:]), ensure_ascii=False))
    except Exception as e:
        print(json.dumps(dict(error=str(e)), ensure_ascii=False))
        sys.exit(1)
