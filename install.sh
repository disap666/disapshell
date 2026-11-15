#!/bin/bash
# Installs the rice into $HOME. Files that would be replaced are saved first.
# ./install.sh               packages, configs, wallpapers
# ./install.sh --no-packages configs and wallpapers only
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)
src="$repo/home"
packages=1
[ "${1-}" = "--no-packages" ] && packages=0

if [ "$(id -u)" = 0 ]; then
    echo "Run as your user, not root." >&2
    exit 1
fi

if [ "$packages" = 1 ]; then
    if command -v pacman >/dev/null; then
        sudo pacman -S --needed $(grep -v '^#' "$repo/packages.txt")
    else
        echo "pacman not found. Install the packages from packages.txt by hand, then run ./install.sh --no-packages" >&2
        exit 1
    fi
fi

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -a "$src/." "$stage/"
grep -rlIF '@HOME@' "$stage" | while IFS= read -r f; do
    sed -i "s|@HOME@|$HOME|g" "$f"
done

# The canvas plugin is a binary built for one Hyprland commit.
plugin_commit=efb50993780079460b0cbed1363e2166a2de1d9f
if ! { hyprctl version 2>/dev/null || Hyprland --version 2>/dev/null; } | grep -q "$plugin_commit"; then
    sed -i 's|^source = ~/.config/hypr/phantomat.conf|# &|' "$stage/.config/hypr/hyprland.conf"
    echo "Hyprland is not 0.56.2: canvas plugin (Ctrl +) left disabled, see README."
fi

backup="$HOME/.rice-backup-$(date +%Y%m%d-%H%M%S)"
saved=0
while IFS= read -r -d '' f; do
    rel=${f#"$stage"/}
    if [ -e "$HOME/$rel" ] && ! cmp -s "$f" "$HOME/$rel"; then
        mkdir -p "$backup/$(dirname "$rel")"
        cp -a "$HOME/$rel" "$backup/$rel"
        saved=1
    fi
done < <(find "$stage" -type f -print0)
[ "$saved" = 1 ] && echo "Previous files saved to $backup"

cp -a "$stage/." "$HOME/"

mkdir -p "$HOME/wallpapers" "$HOME/.local/state/wallpaper-picker"
cp -n "$repo"/wallpapers/* "$HOME/wallpapers/"
[ -e "$HOME/.local/state/wallpaper-picker/current" ] || printf '%s' "$HOME/wallpapers/river.gif" > "$HOME/.local/state/wallpaper-picker/current"

line='[[ -f "$HOME/.config/zsh/shell.zsh" ]] && source "$HOME/.config/zsh/shell.zsh"'
if [ -f "$HOME/.zshrc" ] && ! grep -qF '.config/zsh/shell.zsh' "$HOME/.zshrc"; then
    printf '\n%s\n' "$line" >> "$HOME/.zshrc"
fi

fc-cache -f >/dev/null 2>&1 || true
update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE-}" ]; then
    echo "Done. Log out and back in to Hyprland."
else
    echo "Done. Start Hyprland."
fi
