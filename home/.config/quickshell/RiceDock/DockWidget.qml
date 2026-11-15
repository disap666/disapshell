pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import Quickshell.Io
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// One widget of the merged RiceDesktop process (see ../RiceDesktop/shell.qml).
Scope {
    id: root
    readonly property var dockStyle: Rice.Theme.deck
    readonly property int dockParts: Math.max(1, Math.min(dockStyle.parts || 1, dockApps.length))
    readonly property int dockRadius: dockStyle.parts ? dockStyle.radius : 23
    readonly property real dockGap: dockStyle.parts ? dockStyle.gap : 0
    readonly property real dockOpacity: Math.min(1, (dockStyle.parts ? dockStyle.opacity : .86) * Rice.Theme.glassOpacity)
    readonly property color dockSurface: dockStyle.highlight
    readonly property color dockBase: dockStyle.background
    readonly property color dockAccent: dockStyle.accent
    readonly property color dockText: dockStyle.foreground
    readonly property color dockBorder: dockStyle.border
    readonly property bool dockVisible: !dockStyle.autoHide || revealed
    readonly property var dockApps: (dockStyle.showLauncher ? [{id: "rice-launcher", name: "Приложения", icon: "view-app-grid", match: "(?!)", launcher: true}] : []).concat(apps, dockStyle.showRunning ? extraApps : [])
    IpcHandler {
        target: "dock"
        function reveal(): void { hideDelay.stop(); root.revealed = true; }
        function hide(): void { root.revealed = false; }
        function status(): string { return JSON.stringify({parts: root.dockParts, radius: root.dockRadius, apps: root.dockApps.length, visible: root.revealed}); }
    }
    property bool revealed: false
    property int hoveredSlot: -1
    Timer { id: hideDelay; interval: root.dockStyle.hideDelay; onTriggered: root.revealed = false }
    readonly property var apps: dockStyle.apps !== undefined ? dockStyle.apps : [
        { id: "kitty", name: "Терминал", icon: "kitty", match: "^kitty$" },
        { id: "org.kde.dolphin", name: "Файлы", icon: "org.kde.dolphin", match: "dolphin" },
        { id: "google-chrome", name: "Chrome", icon: "google-chrome", match: "google-chrome|chrome" },
        { id: "code", name: "VS Code", icon: "vscode", match: "^code$|code-oss" },
        { id: "org.telegram.desktop", name: "Telegram", icon: "org.telegram.desktop", match: "telegram" },
        { id: "discord", name: "Discord", icon: "discord", match: "discord" },
        { id: "spotify", name: "Spotify", icon: "spotify", match: "spotify" }
    ]
    function windowsFor(app) {
        var pattern = new RegExp(app.match, "i");
        return Hyprland.toplevels.values.filter(function(w) {
            return pattern.test(w.lastIpcObject["class"] || "");
        });
    }
    readonly property var extraApps: {
        var seen = {}, extra = [];
        Hyprland.toplevels.values.forEach(function(w) {
            var cls = w.lastIpcObject["class"] || "";
            if (!cls || seen[cls]) return;
            if (root.apps.some(function(a) { return new RegExp(a.match,"i").test(cls); })) return;
            seen[cls] = true;
            var entry = DesktopEntries.heuristicLookup(cls);
            extra.push({ id: entry ? entry.id : "", name: entry ? entry.name : cls,
                icon: entry ? entry.icon : "application-x-executable", match: "^" + cls.replace(/[.*+?^${}()|[\]\\]/g,"\\$&") + "$" });
        });
        return extra;
    }
    component DockIcon: Item {
        id: tile
        required property var app
        property int slot: 0
        readonly property real proximity: !root.dockStyle.zoom || root.hoveredSlot < 0 ? 0 : Math.max(0, 1 - Math.abs(slot-root.hoveredSlot)/2)
        readonly property var windows: root.windowsFor(app)
        readonly property bool active: windows.some(function(w) { return w.activated; })
        width: 56; height: 64
        Rectangle {
            x: 3; y: 5 - tile.proximity * 5; width: 50; height: 50; radius: root.dockRadius === 0 ? 0 : root.dockStyle.iconRadius
            scale: 1 + tile.proximity * .12
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(root.dockAccent.r,root.dockAccent.g,root.dockAccent.b,tile.active ? .5 : .25) }
                GradientStop { position: 1; color: Qt.rgba(root.dockBase.r,root.dockBase.g,root.dockBase.b,.75) }
            }
            border.width: 1
            border.color: hit.containsMouse ? root.dockAccent : Qt.rgba(root.dockBorder.r,root.dockBorder.g,root.dockBorder.b,.4)
            Rectangle {
                anchors.fill: parent; anchors.margins: 2; radius: root.dockRadius === 0 ? 0 : Math.max(0,root.dockStyle.iconRadius-2); color: "transparent"
                border.width: 1; border.color: Qt.rgba(root.dockBorder.r,root.dockBorder.g,root.dockBorder.b,.16)
            }
            Rectangle {
                x: 7; y: 2; width: parent.width-14; height: 1; radius: 1; color: Qt.rgba(root.dockAccent.r,root.dockAccent.g,root.dockAccent.b,.4)
            }
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }
        Image {
            id: icon
            visible: !tile.app.launcher
            width: 35; height: 35
            x: (parent.width-width)/2
            y: 12 - tile.proximity * 7
            scale: 1 + tile.proximity * .22
            source: tile.app.launcher ? "" : Quickshell.iconPath(tile.app.icon)
            sourceSize: Qt.size(96,96)
            fillMode: Image.PreserveAspectFit
            smooth: true
            layer.enabled: !!root.dockStyle.tintIcons
            layer.effect: MultiEffect { colorization: 1; colorizationColor: root.dockAccent; brightness: .08; saturation: -.35 }
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        Grid {
            visible: !!tile.app.launcher
            anchors.horizontalCenter: parent.horizontalCenter
            y: 20 - tile.proximity * 7
            columns: 3; spacing: 4
            Repeater { model: 9; Rectangle { width: 5; height: 5; radius: root.dockRadius === 0 ? 0 : 1; color: root.dockAccent } }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 60; width: tile.active ? 10 : 3; height: 3; radius: 2
            color: tile.active ? root.dockAccent : Qt.darker(root.dockAccent,1.4)
            visible: tile.windows.length > 0
            Behavior on width { NumberAnimation { duration: 160 } }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -35; width: caption.implicitWidth+20; height: 27; radius: 9
            color: root.dockBase; border.width: 1; border.color: root.dockBorder
            visible: hit.containsMouse
            Text { id: caption; anchors.centerIn: parent; text: tile.app.name; color: root.dockText; font.family: Rice.Theme.fontFamily; font.pixelSize: (11 * Rice.Theme.textScale) }
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onEntered: root.hoveredSlot = tile.slot
            onClicked: mouse => {
                if (tile.app.launcher) { Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/rice-apps"]); return; }
                if (tile.windows.length && mouse.button !== Qt.MiddleButton && !(mouse.modifiers & Qt.ShiftModifier)) {
                    var index = tile.windows.findIndex(function(w) { return w.activated; });
                    var win = tile.windows[(index+1) % tile.windows.length];
                    Hyprland.dispatch("focuswindow address:"+win.address);
                } else {
                    var entry = DesktopEntries.byId(tile.app.id);
                    if (entry) entry.execute();
                }
            }
        }
    }
    PanelWindow {
        id: dockWindow
        anchors.bottom: true
        anchors.left: root.dockStyle.alignment === "left"
        anchors.right: root.dockStyle.alignment === "right"
        margins.bottom: 0
        implicitWidth: Math.min(screen.width, Math.ceil(dockRow.implicitWidth * dockRow.scale) + 26)
        implicitHeight: Math.ceil(100 * dockRow.scale) + root.dockStyle.bottomMargin + 30
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "rice-dock"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            x: 0
            y: root.dockVisible ? 0 : dockWindow.height - 3
            width: dockWindow.width
            height: root.dockVisible ? dockWindow.height : 3
        }
        HoverHandler {
            onHoveredChanged: {
                if (hovered) { hideDelay.stop(); root.revealed = true; }
                else { root.hoveredSlot = -1; hideDelay.restart(); }
            }
        }
        Item {
            id: dockPane
            anchors { left: parent.left; right: parent.right }
            y: root.dockVisible ? dockWindow.height - height - root.dockStyle.bottomMargin : dockWindow.height + 6
            opacity: root.dockVisible ? 1 : 0
            Behavior on y { NumberAnimation { duration: root.revealed ? 340 : 260; easing.type: root.revealed ? Easing.OutCubic : Easing.InCubic } }
            Behavior on opacity { NumberAnimation { duration: root.revealed ? 220 : 180 } }
            height: 68 * dockRow.scale
            Row {
                id: dockRow
                scale: Math.min(root.dockStyle.scale, (dockWindow.screen.width - 26) / Math.max(1,implicitWidth))
                anchors.centerIn: parent
                spacing: root.dockGap / scale
                Repeater {
                    model: root.dockParts
                    Item {
                        id: island
                        required property int index
                        readonly property int first: Math.floor(index * root.dockApps.length / root.dockParts)
                        readonly property int last: Math.floor((index + 1) * root.dockApps.length / root.dockParts)
                        width: islandIcons.implicitWidth + root.dockStyle.padding * 2; height: 68
                        Rectangle {
                            anchors.fill: parent
                            radius: root.dockRadius / dockRow.scale
                            gradient: Gradient {
                                GradientStop { position: 0; color: root.dockStyle.gradient ? Qt.rgba(root.dockSurface.r, root.dockSurface.g, root.dockSurface.b, root.dockOpacity) : Qt.rgba(root.dockBase.r,root.dockBase.g,root.dockBase.b,root.dockOpacity) }
                                GradientStop { position: 1; color: Qt.rgba(root.dockBase.r, root.dockBase.g, root.dockBase.b, root.dockOpacity) }
                            }
                            border.width: root.dockStyle.borderWidth / dockRow.scale; border.color: Qt.rgba(root.dockBorder.r,root.dockBorder.g,root.dockBorder.b,root.dockStyle.borderOpacity)
                        }
                        Row {
                            id: islandIcons
                            anchors.centerIn: parent; spacing: 4
                            Repeater {
                                model: root.dockApps.slice(island.first, island.last)
                                DockIcon { required property var modelData; required property int index; app: modelData; slot: island.first + index }
                            }
                        }
                    }
                }
            }
        }
    }
}
