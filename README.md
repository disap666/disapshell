# rice

Hyprland + Quickshell. Док, виджеты, уведомления, меню приложений, меню питания, экран блокировки и окно настроек написаны на QML. Проверено на Arch Linux, Hyprland 0.56.2.

## Установка

```sh
git clone <адрес репозитория> rice
cd rice
./install.sh
```

Скрипт ставит пакеты из `packages.txt` через pacman, копирует `home/` в домашний каталог и обои в `~/wallpapers`. Файлы, которые он заменяет, сохраняются в `~/.rice-backup-<дата>`.

Без установки пакетов: `./install.sh --no-packages`.

Не из репозиториев Arch: `tty-clock` (AUR), нужен только для ярлыка TTY Clock.

## Клавиши

| Клавиши | Действие |
| --- | --- |
| Super+I | настройки райса |
| Super+R, Super+Space | меню приложений |
| Super+Q | терминал |
| Super+E | файлы |
| Super+W | обои, с Shift случайные |
| Super+T | темы |
| Super+M | меню питания |
| Super+L | блокировка |
| Super+A | уведомления, с Shift режим «не беспокоить» |
| Super+N | Wi-Fi, с Shift Bluetooth |
| Super+G | игровой режим |
| Super+B | скрыть панель |
| Super+Shift+P | виджет музыки |
| Super+S, Print | снимок области, всего экрана |
| Super+C | закрыть окно |
| Super+V | плавающее окно |
| Super+F | полный экран |
| Super+1..9 | рабочие столы |
| Ctrl + | холст со всеми окнами |

Раскладки us, ru, ua, переключение Alt+Shift. Меняется в настройках.

## Холст

`home/.local/share/phantomat/spatialoverview.so` собран под Hyprland 0.56.2. На другой версии установщик оставляет его выключенным. Чтобы включить, соберите [phantomat](https://github.com/kaolti/phantomat) под свою версию с патчами из той же папки, положите `.so` в `~/.local/share/phantomat/` и раскомментируйте `source = ~/.config/hypr/phantomat.conf` в `hyprland.conf`.

## Заряд мыши и гарнитуры

`~/.local/lib/rice/*.rules` написаны под конкретные устройства (HyperX 0951:1713, Pulsar 379a:3901). Для них: скопировать правила в `/etc/udev/rules.d/` и выполнить `sudo udevadm control --reload`.

## Обновление репозитория

`./collect.sh` заново собирает `home/` и `wallpapers/` из текущей системы.

## Чужой код и материалы

- Wi-Fi и Bluetooth панель, музыкальный виджет: на основе [MacShell](https://github.com/0-ss/MacShell), MIT.
- Phantomat: [kaolti/phantomat](https://github.com/kaolti/phantomat), лицензия рядом с бинарником.
- Видео на экране блокировки: NASA Goddard Space Flight Center / Jeremy Schnittman.
- Шрифты Manrope и Unbounded: SIL Open Font License.
