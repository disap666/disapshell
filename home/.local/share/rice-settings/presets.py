#!/usr/bin/python3
"""Shared palettes and reversible Waybar layouts; preserve module settings."""
import copy
import json
import sys
from datetime import datetime
from pathlib import Path
import waybar
import kitty_settings

HOME = Path.home()
PALETTE = HOME / '.config/rice-theme/palette.json'
STATE = HOME / '.local/state/rice-settings/presets'
CSS = HOME / '.config/waybar/style.css'
CONFIG = HOME / '.config/waybar/config.jsonc'
DOCK = HOME / '.config/rice-theme/deck.json'
KITTY = HOME / '.config/kitty/kitty.conf'
AUTO = HOME / '.config/rice-theme/autotheme.json'
WALLPAPER_STATE = HOME / '.local/state/wallpaper-picker/current'
PRESETS = [
    dict(id='glass', name='Glass', description='Прозрачный, холодный белый',
         colors=dict(background='#14161b', surface='#2c313a', muted='#a9b1bf', foreground='#f3f6fa', accent='#d6e6ff', highlight='#6b7585', border='#ffffff')),
    dict(id='lavender', name='Lavanda', description='Сиреневый, молочный текст',
         colors=dict(background='#201a2d', surface='#493957', muted='#ac9bbb', foreground='#eee3fa', accent='#c6acee', highlight='#81679c', border='#d8c0f2')),
    dict(id='black', name='Black', description='Чёрный, белые акценты',
         colors=dict(background='#000000', surface='#1c1c1c', muted='#8a8a8a', foreground='#e8e8e8', accent='#ffffff', highlight='#2a2a2a', border='#3a3a3a')),
    dict(id='nord', name='Nord', description='Графит, голубые акценты',
         colors=dict(background='#2e3440', surface='#434c5e', muted='#a4b1c4', foreground='#eceff4', accent='#88c0d0', highlight='#4c566a', border='#8fbcbb')),
    dict(id='navy', name='Navy', description='Тёмно-синий, васильковый акцент',
         colors=dict(background='#0b1426', surface='#1b2a47', muted='#8ea3c4', foreground='#e3ebf7', accent='#5b9bff', highlight='#24365c', border='#3d6bc4')),
    dict(id='orange', name='Orange', description='Тёплый графит, терракотовый акцент',
         colors=dict(background='#1f1e1d', surface='#3a3632', muted='#b0a99f', foreground='#f0eee6', accent='#d97757', highlight='#4a3f37', border='#c96442')),
    dict(id='sakura', name='Sakura', description='Тёмно-вишнёвый, розовый акцент',
         colors=dict(background='#1f171c', surface='#46313d', muted='#bfa3b1', foreground='#f6e6ee', accent='#f4a7c4', highlight='#7a5468', border='#f7c6d9')),
    dict(id='forest', name='Forest', description='Тёмно-зелёный, мягкий зелёный акцент',
         colors=dict(background='#141a16', surface='#2b3a2f', muted='#9fb3a2', foreground='#e4eee3', accent='#8fcf8a', highlight='#3e5443', border='#6fae7a')),
    dict(id='ocean', name='Ocean', description='Тёмно-бирюзовый, холодный акцент',
         colors=dict(background='#0c1a1f', surface='#173640', muted='#8fb3bc', foreground='#e0f2f4', accent='#4fd1c5', highlight='#1f4a56', border='#38b2ac')),
    dict(id='espresso', name='Espresso', description='Кофейный, карамельный акцент',
         colors=dict(background='#1c1613', surface='#3b2d26', muted='#b5a293', foreground='#f1e6dc', accent='#d4a373', highlight='#5a4336', border='#b08968')),
    dict(id='crimson', name='Crimson', description='Почти чёрный, красный акцент',
         colors=dict(background='#140c0e', surface='#331a1f', muted='#b8949a', foreground='#f5e3e5', accent='#e05561', highlight='#4d2228', border='#b33a46')),
]
LAYOUTS = {
    'glass': dict(parts=3, radius=22, gap=12, height=40, margin=10, opacity=38, gradient=True, label='3 прозрачные капсулы'),
    'lavender': dict(parts=3, radius=20, gap=12, height=40, margin=8, opacity=82, gradient=True, label='3 стеклянные капсулы'),
    'black': dict(parts=1, radius=0, gap=0, height=34, margin=0, opacity=100, gradient=False, label='Цельная панель во всю ширину'),
    'nord': dict(parts=2, radius=10, gap=16, height=38, margin=10, opacity=94, gradient=False, label='2 строгих блока'),
    'navy': dict(parts=4, radius=12, gap=10, height=38, margin=8, opacity=92, gradient=False, label='4 отдельных блока'),
    'orange': dict(parts=1, radius=16, gap=0, height=38, margin=10, opacity=96, gradient=False, label='Цельная парящая панель'),
    'sakura': dict(parts=3, radius=18, gap=12, height=40, margin=10, opacity=80, gradient=True, label='3 розовые капсулы'),
    'forest': dict(parts=2, radius=14, gap=16, height=38, margin=10, opacity=90, gradient=False, label='2 мягких блока'),
    'ocean': dict(parts=1, radius=20, gap=0, height=38, margin=12, opacity=85, gradient=True, label='Парящая капсула'),
    'espresso': dict(parts=4, radius=8, gap=10, height=36, margin=8, opacity=96, gradient=False, label='4 плотных блока'),
    'crimson': dict(parts=3, radius=6, gap=10, height=36, margin=8, opacity=94, gradient=False, label='3 острых блока'),
}
DECK_LAYOUTS = {
    'glass': dict(parts=1, radius=24, gap=0, padding=10, opacity=.3, label='прозрачный цельный'),
    'lavender': dict(parts=3, radius=18, gap=10, padding=10, opacity=.55, label='3 стеклянных блока'),
    'black': dict(parts=1, radius=14, gap=0, padding=8, opacity=.97, label='чёрный цельный'),
    'nord': dict(parts=2, radius=10, gap=14, padding=10, opacity=.92, label='2 строгих блока'),
    'navy': dict(parts=1, radius=16, gap=0, padding=10, opacity=.9, label='цельный скруглённый'),
    'orange': dict(parts=1, radius=18, gap=0, padding=10, opacity=.95, label='цельный тёплый'),
    'sakura': dict(parts=1, radius=22, gap=0, padding=10, opacity=.6, label='цельный стеклянный'),
    'forest': dict(parts=2, radius=14, gap=12, padding=10, opacity=.9, label='2 блока'),
    'ocean': dict(parts=1, radius=20, gap=0, padding=10, opacity=.75, label='цельный полупрозрачный'),
    'espresso': dict(parts=4, radius=8, gap=8, padding=8, opacity=.95, label='4 блока'),
    'crimson': dict(parts=1, radius=10, gap=0, padding=8, opacity=.95, label='цельный строгий'),
}
KITTY_VARIANTS = {
    'glass': (.70,18,'beam','fade',['#2a2e36','#f28b99','#a6dba0','#f2d49b','#9cc4ff','#c7b3ff','#9ee0e0','#dfe5ee','#6b7380','#ffadb9','#c2efbc','#fbe4b8','#bcd8ff','#ddd0ff','#bff0f0','#ffffff']),
    'lavender': (.90,18,'beam','separator',['#393348','#eaa2b1','#b4d3ad','#e8cb9d','#a8c9f5','#c6acee','#a8d4ce','#d6cfe2','#8b809d','#ffc0cd','#c9e7c1','#f8dfb3','#c2daff','#dfc8ff','#c2eee7','#faf6ff']),
    'black': (1.0,14,'block','separator',['#000000','#ff5f5f','#87d787','#ffd75f','#5fafff','#d787ff','#5fd7d7','#d0d0d0','#4e4e4e','#ff8787','#afffaf','#ffff87','#87d7ff','#ffafff','#87ffff','#ffffff']),
    'nord': (.97,16,'block','separator',['#3b4252','#bf616a','#a3be8c','#ebcb8b','#81a1c1','#b48ead','#88c0d0','#e5e9f0','#4c566a','#d08770','#b5d4a1','#f3dcab','#a4c4df','#cbb1df','#a7dce9','#eceff4']),
    'navy': (.95,16,'beam','powerline',['#13203a','#f07178','#8fd18b','#f2c472','#5b9bff','#a78bfa','#5ccfe6','#c8d3e6','#3a4e75','#ff8f95','#aee8a9','#ffd893','#8ab8ff','#c4b2ff','#8ae2f2','#eef3fb']),
    'sakura': (.90,18,'beam','fade',['#46313d','#f28ba0','#b5d6a7','#f2d0a4','#a7c0f2','#f4a7c4','#a7dcd5','#e6d3dd','#7a5468','#ffadc0','#cdeac0','#fbe2c0','#c2d5ff','#ffc6dc','#c5efe9','#f6e6ee']),
    'forest': (.96,16,'block','separator',['#2b3a2f','#e08a7e','#8fcf8a','#e3c98a','#8fb3d9','#c3a0d6','#86c9b4','#c9d6c8','#3e5443','#f0a597','#acebaa','#f0dca8','#abcdf0','#dbbdea','#a6e3d0','#e4eee3']),
    'ocean': (.90,18,'beam','powerline',['#173640','#f07c84','#8fd6a0','#ecd08a','#6fb7f2','#b49cf2','#4fd1c5','#c6dfe3','#1f4a56','#ff99a0','#aef0bd','#f8e1a8','#97cdfa','#cbb9fa','#7ee8de','#e0f2f4']),
    'espresso': (1.0,14,'block','separator',['#3b2d26','#d9776b','#a7b97c','#d4a373','#8aa2c0','#b98ea8','#8fb5a5','#d8c9bc','#5a4336','#ec9286','#c1d398','#e8bd91','#a7bdd8','#d3a9c2','#abcfbf','#f1e6dc']),
    'crimson': (.97,16,'beam','slant',['#331a1f','#e05561','#9cc48f','#e6c27a','#8aa5d6','#c98ab8','#86c2bd','#d9c4c7','#4d2228','#f27782','#b8dda9','#f3d699','#a9c0ea','#e0a7d1','#a6dcd7','#f5e3e5']),
    'orange': (.97,18,'beam','separator',['#2b2a28','#e0675f','#9bbb7a','#e5b567','#7f9fc4','#c58fb3','#7fb5a8','#d6d1c4','#5c574f','#f08a7e','#b5d394','#f0c987','#9fbbdc','#d9a9c8','#9ccbbf','#f0eee6']),
}
for preset in PRESETS:
    preset['layout'] = LAYOUTS[preset['id']]
    preset['deck'] = DECK_LAYOUTS[preset['id']]
    opacity,padding,cursor,tab,ansi = KITTY_VARIANTS[preset['id']]
    c=preset['colors']
    preset['kitty'] = dict(background=c['background'],foreground=c['foreground'],cursor=c['accent'],
        cursor_text_color=c['background'],selection_background=c['surface'],selection_foreground=c['foreground'],
        background_opacity=opacity,window_padding_width=padding,cursor_shape=cursor,tab_bar_style=tab,
        active_border_color=c['accent'],inactive_border_color=c['surface'],tab_bar_background=c['background'],
        active_tab_background=c['surface'],active_tab_foreground=c['accent'],
        inactive_tab_background=c['background'],inactive_tab_foreground=c['muted'],url_color=ansi[4],
        **{'color'+str(i):color for i,color in enumerate(ansi)})

# Palette from the wallpaper
def _hls(h, l, s):
    import colorsys
    r, g, b = colorsys.hls_to_rgb(h % 1, max(0, min(1, l)), max(0, min(1, s)))
    return '#%02x%02x%02x' % (round(r * 255), round(g * 255), round(b * 255))

def wallpaper_colors(path):
    """Dominant hue for the surfaces, the most vivid frequent colour for the accent."""
    import colorsys
    from PIL import Image
    with Image.open(path) as im:
        im.seek(0)
        im = im.convert('RGB')
        im.thumbnail((240, 240))
        q = im.quantize(colors=16, method=Image.Quantize.MEDIANCUT)
        pal = q.getpalette()
        counts = sorted(q.getcolors(), reverse=True)
    total = sum(c for c, _ in counts) or 1
    swatches = []
    for count, idx in counts:
        r, g, b = (v / 255 for v in pal[idx * 3: idx * 3 + 3])
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        swatches.append(dict(share=count / total, h=h, l=l, s=s))
    # surface hue: the most common colour that is not grey
    tinted = [w for w in swatches if w['s'] > .12 and .08 < w['l'] < .9]
    base = tinted[0] if tinted else swatches[0]
    # accent: frequent and saturated, not near black/white
    def score(w):
        if w['l'] < .18 or w['l'] > .92 or w['s'] < .22: return 0
        return (w['share'] ** .55) * (w['s'] ** 1.4) * (1 - abs(w['l'] - .55))
    best = max(swatches, key=score)
    mono = score(best) == 0
    bh = base['h']; bs = min(.28, base['s'] * .6) if tinted else 0
    ah = best['h'] if not mono else bh
    as_ = .18 if mono else max(.45, min(.78, best['s']))
    return dict(
        background=_hls(bh, .075, bs), surface=_hls(bh, .17, bs * .9), highlight=_hls(bh, .30, bs * .8),
        muted=_hls(bh, .70, min(.16, bs)), foreground=_hls(bh, .95, min(.20, bs)),
        accent=_hls(ah, .72, as_), border=_hls(ah, .82, as_ * .8),
        _hue=ah, _sat=as_)

def wallpaper_preset(path):
    c = wallpaper_colors(path)
    hue, sat = c.pop('_hue'), c.pop('_sat')
    try: cur = json.loads(PALETTE.read_text())
    except (OSError, ValueError): cur = {}
    base = next(p for p in PRESETS if p['id'] == 'glass')
    layout = cur.get('layout') or base['layout']
    deck = cur.get('deck') or base['deck']
    kitty_old = cur.get('kitty') or base['kitty']
    # ANSI colours: fixed hues, pulled a little towards the accent so they belong together
    def ansi(h, l, s=.62):
        d = ((hue - h + .5) % 1) - .5
        return _hls(h + d * .12, l, s * (.6 + .4 * min(1, sat / .6)))
    hues = [0, .33, .12, .6, .8, .5]
    normal = [ansi(h, .68) for h in hues]
    bright = [ansi(h, .80) for h in hues]
    colors16 = [c['surface']] + normal + [c['muted'], c['highlight']] + bright + [c['foreground']]
    kitty = dict(kitty_old)
    kitty.update(background=c['background'], foreground=c['foreground'], cursor=c['accent'],
        cursor_text_color=c['background'], selection_background=c['surface'], selection_foreground=c['foreground'],
        active_border_color=c['accent'], inactive_border_color=c['surface'], tab_bar_background=c['background'],
        active_tab_background=c['surface'], active_tab_foreground=c['accent'],
        inactive_tab_background=c['background'], inactive_tab_foreground=c['muted'], url_color=normal[3],
        **{'color' + str(i): col for i, col in enumerate(colors16)})
    return dict(id='wallpaper', name='Из обоев', description='Цвета взяты из текущих обоев',
                source=str(path), colors=c, layout=layout, deck=deck, kitty=kitty)

def auto_enabled():
    try: return bool(json.loads(AUTO.read_text()).get('enabled'))
    except (OSError, ValueError): return False

def current_wallpaper():
    try: p = Path(WALLPAPER_STATE.read_text().strip())
    except OSError: p = None
    if not p or not p.is_file(): raise ValueError('Не удалось определить текущие обои')
    return p

def layout_config(config, layout, geometry=True):
    config = copy.deepcopy(config)
    zones = {zone: [] for zone in ('left', 'center', 'right')}
    # Recover original zones from our wrappers when switching between presets.
    for zone in zones:
        for module in config.get('modules-' + zone, []):
            group = config.get(module, {})
            source = group.get('_rice-preset-zone') if isinstance(group, dict) else None
            if module.startswith('group/rice-preset-') and source in zones:
                zones[source].extend(group['modules'])
            else:
                zones[zone].append(module)
    for key in list(config):
        if key.startswith('group/rice-preset-') and isinstance(config[key], dict) and '_rice-preset-zone' in config[key]:
            del config[key]
    for zone, modules in zones.items(): config['modules-' + zone] = modules
    def wrap(zone, suffix, modules):
        if not modules: return []
        key = 'group/rice-preset-' + suffix
        if key in config: raise ValueError('Название группы занято: ' + key)
        config[key] = dict(orientation='inherit', modules=modules, **{'_rice-preset-zone': zone})
        return [key]
    if layout['parts'] == 2:
        config['modules-left'] = wrap('left', 'left', zones['left']) + wrap('center', 'center', zones['center'])
        config['modules-center'] = []
    elif layout['parts'] == 4:
        # Split the center into two islands without duplicating or losing modules.
        # If the center has only one item, split another populated zone instead.
        zone = 'center' if len(zones['center']) >= 2 else max(zones, key=lambda z: len(zones[z]))
        modules = zones[zone]
        if len(modules) >= 2:
            split = max(1, len(modules) // 2)
            config['modules-' + zone] = wrap(zone, 'split-a', modules[:split]) + wrap(zone, 'split-b', modules[split:])
    if not geometry: return config
    config.update({'position': 'top', 'height': layout['height'], 'margin-top': layout['margin'],
                   'margin-bottom': 0, 'margin-left': layout['margin'], 'margin-right': layout['margin'],
                   'spacing': 2, 'fixed-center': layout['parts'] != 2})
    config.pop('width', None)
    return config

def current():
    try: return json.loads(PALETTE.read_text()).get('id', '')
    except (OSError, ValueError): return ''

def snapshot():
    dest = STATE / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    dest.mkdir(parents=True)
    data = {str(p): p.read_text() if p.exists() else None for p in (CSS, PALETTE, CONFIG, DOCK, KITTY)}
    (dest / 'snapshot.json').write_text(json.dumps(data))
    return dest, data

def atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    waybar.atomic(path, text)

def install(data):
    # A null palette restores the original colors, including in running widgets.
    for name, value in data.items():
        path = Path(name)
        atomic(path, value if value is not None else '{}\n')

def apply_preset(preset):
    data = waybar.read()
    a = data['appearance'].copy()
    a.update({key: preset['colors'][key] for key in ('background', 'highlight', 'foreground', 'accent', 'border')})
    layout = preset['layout']
    a.update(radius=layout['radius'], opacity=layout['opacity'], gradient=layout['gradient'],
             borderWidth=1, borderOpacity=34, padding=8, layout=layout['parts'], gap=layout['gap'])
    config = layout_config(data['config'], layout)
    a['splitZone'] = config.get('group/rice-preset-split-a', {}).get('_rice-preset-zone', 'center')
    waybar.validate(dict(config=config, appearance=a))
    c = preset['colors']
    extra = f'''
/* Shared preset: module details and tooltip colors. */
#workspaces button, #custom-media.idle, #network.disconnected, #bluetooth.off, #bluetooth.disabled, #pulseaudio.muted, #custom-notification.dnd-none, #custom-notification.dnd-notification {{ color: {c['muted']}; }}
#workspaces button.active, #workspaces button:hover {{ color: {c['foreground']}; background: {waybar.rgba(c['accent'],40)}; }}
#battery {{ color: {c['background']}; }}
#clock, #clock.date, #custom-media, #custom-play {{ background: {waybar.rgba(c['surface'],35)}; }}
tooltip {{ background: {c['background']}; border-color: {c['border']}; }}
tooltip label {{ color: {c['foreground']}; }}
'''
    # A preset replaces dock styling while keeping the user's pinned apps/behavior.
    try: dock = json.loads(DOCK.read_text())
    except (OSError, ValueError): dock = {}
    dock = {key: value for key, value in dock.items() if key in ('apps', 'showRunning', 'showLauncher', 'autoHide', 'zoom', 'alignment', 'hideDelay', 'tintIcons')}
    return {str(CSS): data['css'] + waybar.stylesheet(a) + extra,
            str(KITTY): kitty_settings.render(KITTY.read_text(),preset['kitty']),
            str(DOCK): json.dumps(dock, ensure_ascii=False, indent=2) + '\n',
            str(CONFIG): json.dumps(config, ensure_ascii=False, indent=2) + '\n',
            str(PALETTE): json.dumps(preset, ensure_ascii=False, indent=2) + '\n'}

def main(args):
    action = args[0] if args else 'list'
    pointer = STATE / 'previous'
    if action == 'list':
        return dict(presets=PRESETS, active=current(), canRestore=pointer.exists(), autoTheme=auto_enabled())
    if action == 'autotheme':
        on = len(args) > 1 and args[1] == 'on'
        atomic(AUTO, json.dumps(dict(enabled=on)) + '\n')
        if not on:
            return dict(ok=True, active=current(), canRestore=pointer.exists(), autoTheme=False,
                        message='Цвета больше не меняются вместе с обоями')
        action, args = 'wallpaper', ['wallpaper']
    if action == 'preview':
        return dict(colors=wallpaper_preset(Path(args[1]) if len(args) > 1 else current_wallpaper())['colors'])
    if action == 'apply':
        preset = next((p for p in PRESETS if p['id'] == args[1]), None)
        if preset is None: raise ValueError('Неизвестная заготовка')
        changes = apply_preset(preset)
    elif action == 'wallpaper':
        changes = apply_preset(wallpaper_preset(Path(args[1]) if len(args) > 1 else current_wallpaper()))
    elif action == 'restore':
        if not pointer.exists(): raise ValueError('Нет сохранённой темы для отката')
        changes = json.loads((Path(pointer.read_text().strip()) / 'snapshot.json').read_text())
        # Accept snapshots made by the earlier color-only version as well.
        if not {str(CSS),str(PALETTE)} <= set(changes) <= {str(CSS),str(PALETTE),str(CONFIG),str(DOCK),str(KITTY)}:
            raise ValueError('Некорректная резервная копия')
    else: raise ValueError('Неизвестная команда')
    dest, before = snapshot()
    try:
        install(changes)
        atomic(pointer, str(dest))
    except Exception:
        install(before)
        raise
    waybar.reload()
    if str(KITTY) in changes: kitty_settings.reload()
    borders = sync_window_borders()
    message = {'apply': 'Waybar, док, виджеты, Kitty и рамки окон оформлены в выбранном стиле.',
               'wallpaper': 'Цвета взяты из обоев: Waybar, док, виджеты, Kitty и рамки окон.'}.get(action, 'Предыдущая конфигурация восстановлена.')
    return dict(ok=True, active=current(), canRestore=True, autoTheme=auto_enabled(), message=message + borders)

def sync_window_borders():
    """Recolour Hyprland window borders from the new palette via the desktop backend."""
    import subprocess
    backend = str(Path(__file__).with_name('environment_settings.py'))
    try:
        read = subprocess.run(['python3', backend, 'desktop', 'read'], capture_output=True, text=True, timeout=20)
        settings = json.loads(read.stdout)['settings']
        c = json.loads(PALETTE.read_text()).get('colors') or {}
        for key, name in (('activeBorder', 'accent'), ('activeBorder2', 'border'), ('inactiveBorder', 'surface')):
            if isinstance(c.get(name), str): settings[key] = c[name]
        done = subprocess.run(['python3', backend, 'desktop', 'apply'], input=json.dumps(settings), capture_output=True, text=True, timeout=30)
        result = json.loads(done.stdout)
        return ' Рамки окон: ' + result['error'] if result.get('error') else ''
    except Exception as error:
        return f' Рамки окон не обновлены: {error}'

if __name__ == '__main__':
    try: print(json.dumps(main(sys.argv[1:]), ensure_ascii=False))
    except Exception as e:
        print(json.dumps(dict(error=str(e)), ensure_ascii=False))
        sys.exit(1)
