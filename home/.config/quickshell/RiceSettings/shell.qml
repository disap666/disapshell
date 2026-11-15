pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

ShellRoot {
    id: root
    property string section: "home"
    property string search: ""

    readonly property var sections: [
        { id: "home",      group: "",           name: "Главная",           icon: 0xF02DC, tint: "#f0d6a8", keys: "дом старт обзор режимы liquid ликвид фокус ночной свет не беспокоить",
          description: "Обзор системы и быстрые режимы" },
        { id: "themes",    group: "Оформление", name: "Темы",              icon: 0xF03D8, tint: "#c6acee", keys: "палитра заготовки шрифт стекло overlayer",
          description: "Готовые палитры для всего райса, шрифт и плотность стекла" },
        { id: "wallpaper", group: "Оформление", name: "Обои",              icon: 0xF02E9, tint: "#eaa2b1", keys: "фон картинка gif галерея",
          description: "Коллекция из ~/wallpapers, анимированные GIF тоже работают" },
        { id: "desktop",   group: "Оформление", name: "Окна",              icon: 0xF05B2, tint: "#a8c9f5", keys: "рабочий стол отступы рамки размытие тени анимации",
          description: "Отступы, рамки, стекло, тени и характер анимаций Hyprland" },
        { id: "widgets",   group: "Оформление", name: "Виджеты",           icon: 0xF072C, tint: "#d9bcff", keys: "виджеты рабочий стол музыка плеер ricemusic караоке текст песни",
          description: "Виджеты на рабочем столе: внешний вид, место и поведение" },
        { id: "skin",      group: "Оформление", name: "Скины",             icon: 0xF07F4, tint: "#ff2e88", keys: "скин стиль интерфейс акцент шрифт окно настроек вид",
          description: "Как выглядит само это окно: скин, акцент и шрифт" },
        { id: "waybar",    group: "Панели",     name: "Waybar",            icon: 0xF08C6, tint: "#a8d4ce", keys: "панель модули виджеты css",
          description: "Верхняя панель: форма, положение, модули и расширения" },
        { id: "deck",      group: "Панели",     name: "Док",               icon: 0xF10A9, tint: "#e8cb9d", keys: "dock приложения закреплённые",
          description: "Нижний док и закреплённые приложения" },
        { id: "apps",      group: "Панели",     name: "Поиск приложений",  icon: 0xF0349, tint: "#b4d3ad", keys: "лаунчер меню сетка",
          description: "Размер окна запуска, сетка и иконки" },
        { id: "lock",      group: "Система",    name: "Блокировка",        icon: 0xF033E, tint: "#d6cfe2", keys: "экран блокировки часы пароль",
          description: "Экран блокировки: фон, часы и поле пароля" },
        { id: "kitty",     group: "Система",    name: "Терминал",          icon: 0xF018D, tint: "#a8c9f5", keys: "kitty zsh приглашение prompt",
          description: "Kitty и приглашение командной строки" },
        { id: "system",    group: "Система",    name: "Ввод и экран",      icon: 0xF062E, tint: "#e8cb9d", keys: "клавиатура раскладка тачпад жесты мышь ночной свет hyprsunset",
          description: "Раскладки, тачпад, жесты и ночной свет" },
        { id: "keys",      group: "Система",    name: "Горячие клавиши",   icon: 0xF030C, tint: "#ac9bbb", keys: "бинды сочетания shortcuts",
          description: "Все сочетания клавиш, прочитанные из Hyprland" },
        { id: "backups",   group: "Система",    name: "Резервные копии",   icon: 0xF006F, tint: "#a8d4ce", keys: "бэкап backup копия откат восстановить архив",
          description: "Копии всех конфигов райса и откат к любой из них" }
    ]
    readonly property var pages: ({ home: homePage, skin: skinPage, widgets: widgetsPage, themes: overlayerPage, wallpaper: wallpaperPage, desktop: desktopPage, waybar: waybarPage, deck: deckPage, apps: appsPage, lock: lockPage, kitty: kittyPage, system: systemPage, keys: keysPage, backups: backupsPage })
    readonly property var current: sections.find(s => s.id === section) || sections[0]
    readonly property var visibleSections: sections.filter(s => !search || (s.name + " " + s.keys + " " + s.description).toLowerCase().includes(search))
    readonly property bool anyDirty: sections.some(s => pages[s.id] && pages[s.id].dirty)

    // Everything the Ctrl+K palette can do.
    readonly property var commands: {
        var list = [];
        sections.forEach(sec => list.push({ title: sec.name, icon: sec.icon, tint: sec.tint, group: "раздел", keys: sec.keys,
            run: () => root.section = sec.id }));
        list.push({ title: "Игровой режим", icon: 0xF0297, group: "режим", keys: "game игра игровой gaming fps производительность",
            run: () => homePage.toggleGame() });
        list.push({ title: "Liquid", icon: 0xF058C, group: "режим", keys: "liquid ликвид фокус focus fps производительность игры",
            run: () => homePage.toggleFocus() });
        list.push({ title: "Не беспокоить", icon: 0xF009B, group: "режим", keys: "dnd тишина уведомления",
            run: () => homePage.toggleDnd() });
        list.push({ title: "Ночной свет", icon: 0xF0594, group: "режим", keys: "hyprsunset night тёплый",
            run: () => homePage.toggleNight() });
        list.push({ title: "Случайный скин", icon: 0xF049D, group: "скин", keys: "random shuffle рандом",
            run: () => Tokens.randomSkin() });
        list.push({ title: "Авто-скин день/ночь", icon: 0xF0F65, group: "скин", keys: "auto день ночь время",
            run: () => Tokens.set("autoSkin", !Tokens.opt.autoSkin) });
        var ru = { glass: "гласс стекло", avatar: "аватар аанг стихии легенда", avengers: "мстители марвел железный человек", anime: "аниме сакура",
                   jedi: "джедай звёздные войны star wars", gargantua: "гаргантюа интерстеллар чёрная дыра" };
        Tokens.skins.forEach(sk => list.push({ title: "Скин · " + sk.name, icon: 0xF07F4, group: "скин", keys: "skin стиль " + (ru[sk.id] || ""),
            run: () => Tokens.setSkin(sk.id) }));
        list.push({ title: "Музыкальный виджет", icon: 0xF075A, group: "раздел", keys: "music плеер ricemusic виджет",
            run: () => root.section = "widgets" });
        list.push({ title: "Виджет погоды", icon: 0xF0590, group: "раздел", keys: "weather погода небо прогноз",
            run: () => { root.section = "widgets"; widgetsPage.tab = "weather"; } });
        list.push({ title: "Виджет памяти", icon: 0xF035B, group: "раздел", keys: "memory ram озу память оперативка",
            run: () => { root.section = "widgets"; widgetsPage.tab = "memory"; } });
        list.push({ title: "Текст песни", icon: 0xF0D72, group: "действие", keys: "lyrics karaoke караоке",
            run: () => Quickshell.execDetached(["qs", "ipc", "-c", "RiceDesktop", "call", "music", "karaoke"]) });
        list.push({ title: "Карусель тем", icon: 0xF03D8, group: "действие", keys: "themes палитра",
            run: () => { window.visible = false; Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/rice-themes"]); } });
        list.push({ title: "Предпросмотр блокировки", icon: 0xF033E, group: "действие", keys: "lock preview",
            run: () => Quickshell.execDetached(["qs", "-d", "-n", "-c", "RiceLockPreview"]) });
        list.push({ title: "Обновить список обоев", icon: 0xF0450, group: "действие", keys: "wallpaper refresh",
            run: () => wallpapers.refresh() });
        list.push({ title: "Закрыть настройки", icon: 0xF0156, group: "действие", keys: "close exit выход",
            run: () => window.visible = false });
        return list;
    }

    function open(id) { if (sections.some(s => s.id === id)) section = id; show(); }
    // A window closed by the compositor (Super+C, Alt+F4) cannot be shown again, so start a new instance.
    function show() {
        window.visible = true;
        if (window.visible) return;
        Quickshell.execDetached(["sh", "-c", "for i in 1 2 3 4 5 6 7 8 9 10; do qs ipc -c RiceSettings show >/dev/null 2>&1 || break; sleep 0.2; done; exec qs -d -n -c RiceSettings"]);
        Qt.quit();
    }
    function step(delta) {
        var i = sections.findIndex(s => s.id === section);
        section = sections[(i + delta + sections.length) % sections.length].id;
    }

    // Shared wallpaper model: sidebar card + wallpaper page + previews.
    QtObject {
        id: wallpapers
        property var items: []
        property string current: ""
        property string root: ""
        property bool loaded: false
        readonly property var currentItem: items.find(i => i.path === current) || null
        readonly property string thumb: currentItem && currentItem.thumb ? "file://" + currentItem.thumb : ""
        function refresh() { if (!lister.running) lister.running = true; }
    }
    Process {
        id: lister
        command: ["python3", Quickshell.env("HOME") + "/.local/share/wallpaper-picker/backend.py", "--list"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { var d = JSON.parse(text); wallpapers.items = d.items; wallpapers.current = d.current; wallpapers.root = d.root || ""; wallpapers.loaded = true; } catch (e) { console.warn("wallpapers:", e); } } }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/wallpaper-picker/current"
        watchChanges: true; printErrors: false
        onFileChanged: { reload(); wallpapers.refresh(); }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { if (window.visible) window.visible = false; else root.show(); }
        function close(): void { window.visible = false; }
        function page(id: string): void { root.open(id); }
        function overlayer(): void { root.open("themes"); }
        function wallpaper(): void { root.open("wallpaper"); }
        function desktop(): void { root.open("desktop"); }
        function waybar(): void { root.open("waybar"); }
        function deck(): void { root.open("deck"); }
        function apps(): void { root.open("apps"); }
        function lock(): void { root.open("lock"); }
        function kitty(): void { root.open("kitty"); }
        function system(): void { root.open("system"); }
        function keys(): void { root.open("keys"); }
        function backups(): void { root.open("backups"); }
        function skin(): void { root.open("skin"); }
        function widgets(): void { root.open("widgets"); }
        function widgetTab(id: string): void { root.open("widgets"); widgetsPage.tab = id; }
        function commandPalette(): void { root.open(root.section); cmdPalette.show(); }
        function waybarTab(index: int): void { root.open("waybar"); waybarPage.tab = Math.max(0, Math.min(6, index)); }
        function deckTab(index: int): void { root.open("deck"); deckPage.tab = Math.max(0, Math.min(2, index)); }
        function status(): string {
            return JSON.stringify({ visible: window.visible, section: root.section, dirty: root.anyDirty,
                pages: root.sections.map(s => ({ id: s.id, dirty: !!root.pages[s.id].dirty, loaded: root.pages[s.id].loaded === undefined ? true : root.pages[s.id].loaded, status: root.pages[s.id].status === undefined ? "" : root.pages[s.id].status })) });
        }
    }

    // Free RAM: a closed settings window exits after a minute (unless there are unsaved edits).
    // ~/.local/bin/rice-settings starts it again on the next Super+I.
    Timer {
        interval: 60000
        running: !window.visible && !root.anyDirty
        onTriggered: Qt.quit()
    }

    FloatingWindow {
        id: window
        title: "Настройки райса"
        visible: true
        implicitWidth: Math.min(1120, screen ? screen.width - 48 : 1120)
        implicitHeight: Math.min(800, screen ? screen.height - 80 : 800)
        minimumSize: Qt.size(860, 560)
        color: Tokens.glass

        Backdrop { anchors.fill: parent; live: window.visible && homePage.ambient }

        Pane {
            anchors.fill: parent; padding: 0; focus: true
            font.family: Tokens.font
            font.pixelSize: Tokens.px(13)
            palette.window: Tokens.base
            palette.windowText: Tokens.text
            palette.text: Tokens.text
            palette.buttonText: Tokens.text
            palette.button: Tokens.control
            palette.base: Tokens.well
            palette.highlight: Tokens.accent
            palette.highlightedText: Tokens.onAccent
            palette.placeholderText: Tokens.text3
            palette.toolTipBase: Qt.lighter(Tokens.base, 1.3)
            palette.toolTipText: Tokens.text
            background: Item {}
            Keys.onEscapePressed: { if (root.search) { sidebar.clearSearch(); } else window.visible = false; }
            Keys.onPressed: event => {
                if (!(event.modifiers & Qt.ControlModifier)) return;
                if (event.key === Qt.Key_K || event.key === Qt.Key_P) { cmdPalette.show(); event.accepted = true; return; }
                if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { root.step(event.modifiers & Qt.ShiftModifier ? -1 : 1); event.accepted = true; }
                else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) { root.section = root.sections[event.key - Qt.Key_1 + 1].id; event.accepted = true; }
                else if (event.key === Qt.Key_0) { root.section = root.sections[10].id; event.accepted = true; }
                else if (event.key === Qt.Key_H) { root.section = "home"; event.accepted = true; }
                else if (event.key === Qt.Key_F) { sidebar.focusSearch(); event.accepted = true; }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Sidebar {
                    id: sidebar
                    shell: root
                    Layout.preferredWidth: window.width < 980 ? 224 : 252
                    Layout.fillHeight: true
                }

                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.leftMargin: 28; Layout.rightMargin: 24; Layout.topMargin: 22; Layout.bottomMargin: 18
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Row {
                                Layout.fillWidth: true
                                visible: root.section !== "home"
                                spacing: 10
                                Rectangle {
                                    width: 4; height: 22; radius: 2; anchors.verticalCenter: pageTitle.verticalCenter
                                    gradient: Gradient { GradientStop { position: 0; color: Tokens.neon } GradientStop { position: 1; color: Tokens.duo ? Tokens.cyan : Tokens.alpha(Tokens.neon, .35) } }
                                }
                                Text { id: pageTitle; text: Tokens.up(root.current.name); font.family: Tokens.display; font.pixelSize: Tokens.px(24); font.weight: Font.Medium; color: Tokens.text }
                            }
                        }
                        StyledButton {
                            text: "Ctrl+K"
                            flat: true
                            onClicked: cmdPalette.show()
                        }
                        StyledButton {
                            visible: root.section === "themes"
                            text: "Карусель тем · Super+T"
                            onClicked: { window.visible = false; Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/rice-themes"]); }
                        }
                        StyledButton {
                            visible: root.section === "lock"
                            text: "Предпросмотр"
                            onClicked: Quickshell.execDetached(["qs", "-d", "-n", "-c", "RiceLockPreview"])
                        }
                        StyledButton {
                            implicitHeight: 30; flat: true
                            text: Tokens.glyph(0xF0156)
                            font.family: Tokens.iconFont; font.pixelSize: 16; font.weight: Font.Bold
                            implicitWidth: 40
                            Accessible.name: "Закрыть настройки"
                            ToolTip.visible: hovered; ToolTip.delay: 500; ToolTip.text: "Закрыть"
                            onClicked: window.visible = false
                        }
                    }

                    HomePage {
                        id: homePage
                        visible: root.section === "home"
                        active: visible && window.visible
                        sections: root.sections
                        wallpaper: wallpapers.thumb
                        Layout.fillWidth: true; Layout.fillHeight: true
                        onOpenSection: id => root.section = id
                    }
                    WidgetsPage { id: widgetsPage; wallpaper: wallpapers.thumb; visible: root.section === "widgets" && window.visible; Layout.fillWidth: true; Layout.fillHeight: true }
                    SkinPage { id: skinPage; visible: root.section === "skin"; Layout.fillWidth: true; Layout.fillHeight: true }
                    OverlayerSettings {
                        id: overlayerPage
                        visible: root.section === "themes"
                        Layout.fillWidth: true; Layout.fillHeight: true
                        wallpaper: wallpapers.thumb
                        waybarDirty: waybarPage.dirty || deckPage.dirty || kittyPage.dirty || waybarPage.busy || deckPage.busy || kittyPage.busy || busy
                        onApplied: { waybarPage.read(); deckPage.read(); kittyPage.read(); }
                    }
                    WallpaperSettings { id: wallpaperPage; store: wallpapers; visible: root.section === "wallpaper" && window.visible; Layout.fillWidth: true; Layout.fillHeight: true }
                    SettingsEditor { id: desktopPage; backendName: "environment_settings.py"; backendArgs: ["desktop"]; kind: "desktop"; wallpaper: wallpapers.thumb; visible: root.section === "desktop"; Layout.fillWidth: true; Layout.fillHeight: true }
                    WaybarSettings { id: waybarPage; wallpaper: wallpapers.thumb; enabled: !overlayerPage.busy; visible: root.section === "waybar"; Layout.fillWidth: true; Layout.fillHeight: true }
                    DeckSettings { id: deckPage; wallpaper: wallpapers.thumb; enabled: !overlayerPage.busy; visible: root.section === "deck"; Layout.fillWidth: true; Layout.fillHeight: true }
                    SettingsEditor { id: appsPage; backendName: "app_searcher.py"; visible: root.section === "apps"; Layout.fillWidth: true; Layout.fillHeight: true }
                    SettingsEditor { id: lockPage; backendName: "environment_settings.py"; backendArgs: ["lock"]; kind: "lock"; visible: root.section === "lock"; Layout.fillWidth: true; Layout.fillHeight: true }
                    KittySettings { id: kittyPage; enabled: !overlayerPage.busy; visible: root.section === "kitty"; Layout.fillWidth: true; Layout.fillHeight: true }
                    SettingsEditor { id: systemPage; backendName: "system_settings.py"; kind: "system"; wallpaper: wallpapers.thumb; visible: root.section === "system"; Layout.fillWidth: true; Layout.fillHeight: true }
                    BackupsPage { id: backupsPage; visible: root.section === "backups"; Layout.fillWidth: true; Layout.fillHeight: true }
                    KeysPage { id: keysPage; visible: root.section === "keys"; Layout.fillWidth: true; Layout.fillHeight: true }
                }
            }
        }
        CommandPalette { id: cmdPalette; anchors.fill: parent; commands: root.commands; z: 50 }
        WindowFrame { anchors.fill: parent; z: 100 }
        SkinTransition { anchors.fill: parent; z: 150 }
    }
}
