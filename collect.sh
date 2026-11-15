#!/bin/bash
# Copies the live rice from $HOME into this repo. Run it before committing.
# Absolute home paths are stored as @HOME@; install.sh puts the real one back.
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)
dst="$repo/home"

paths=(
    .config/hypr
    .config/quickshell
    .config/rice-theme
    .config/kitty
    .config/rofi
    .config/waybar
    .config/fastfetch
    .config/gtk-3.0
    .config/gtk-4.0
    .config/xsettingsd
    .config/cava
    .config/btop
    .config/cmatrix
    .config/nmtui
    .config/zsh/shell.zsh
    .config/kdeglobals
    .gtkrc-2.0
    .local/bin/rice-apps
    .local/bin/rice-desktop
    .local/bin/rice-dock
    .local/bin/rice-gamemode
    .local/bin/rice-lock
    .local/bin/rice-memory
    .local/bin/rice-music
    .local/bin/rice-notifications
    .local/bin/rice-power
    .local/bin/rice-settings
    .local/bin/rice-themes
    .local/bin/rice-weather
    .local/bin/wallpaper-picker
    .local/bin/connectivity-widget
    .local/bin/dolphin-glass
    .local/bin/media-toggle
    .local/bin/aafire
    .local/bin/cmatrix
    .local/bin/nmtui
    .local/bin/tty-clock
    .local/lib/rice
    .local/share/rice-settings
    .local/share/wallpaper-picker
    .local/share/dolphin-glass
    .local/share/color-schemes/DolphinGlass.colors
    .local/share/icons/LavenderGlass
    .local/share/fonts
    .local/share/applications/rice-aafire.desktop
    .local/share/applications/rice-cava.desktop
    .local/share/applications/rice-cmatrix.desktop
    .local/share/applications/rice-tty-clock.desktop
    .local/share/applications/wallpaper-picker.desktop
    .local/share/applications/org.kde.dolphin.desktop
    .local/share/phantomat/spatialoverview.so
    .local/share/phantomat/BUILD.txt
    .local/share/phantomat/LICENSE
    .local/share/phantomat/README.md
    .local/share/phantomat/local-fixes.patch
    .local/share/phantomat/legacy-pan.patch
)

rm -rf "$dst"
for p in "${paths[@]}"; do
    [ -e "$HOME/$p" ] || { echo "missing: $p" >&2; continue; }
    mkdir -p "$dst/$(dirname "$p")"
    cp -a "$HOME/$p" "$dst/$p"
done

find "$dst" -type l -delete
find "$dst" -depth \( -name '__pycache__' -o -name '*.before-*' -o -name '*.bak' -o -name '*.orig' \) -exec rm -rf {} +
strip --strip-debug "$dst/.local/share/phantomat/spatialoverview.so"

grep -rlIF "$HOME" "$dst" | while IFS= read -r f; do
    sed -i "s|$HOME|@HOME@|g" "$f"
done

mkdir -p "$repo/wallpapers"
find "$HOME/wallpapers" -maxdepth 1 -type f ! -name '.*' -exec cp -u {} "$repo/wallpapers/" \;

echo "collected into $repo"
