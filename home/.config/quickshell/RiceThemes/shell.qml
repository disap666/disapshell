pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Theme carousel (Super+T). Same idea as the wallpaper filmstrip:
// ← -> / wheel to browse, Enter or click on the centre card to apply, Esc to close.
ShellRoot {
    id: root
    property bool opened: false
    property var presets: []
    property string active: ""
    property int selected: 0
    property real position: 0
    property string wallpaper: ""
    property var apps: []
    property bool applying: false
    property string message: ""
    property bool failed: false
    readonly property string backend: Quickshell.env("HOME") + "/.local/share/rice-settings/presets.py"
    readonly property var current: presets.length ? presets[selected] : null

    Behavior on position { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

    function open() {
        message = ""; failed = false;
        lister.running = true; walls.running = true;
        opened = true;
        Qt.callLater(() => stage.forceActiveFocus());
    }
    function close() { if (!applying) opened = false; }
    function move(step) {
        if (applying || !presets.length) return;
        selected = Math.max(0, Math.min(presets.length - 1, selected + step));
        position = selected;
    }
    function jump(index) { if (!applying && index >= 0 && index < presets.length) { selected = index; position = index; } }
    function apply() {
        if (applying || !current) return;
        if (current.id === active) { message = "Эта тема уже включена"; failed = false; return; }
        applying = true; failed = false; message = "Применяю «" + current.name + "»…";
        applier.command = ["python3", backend, "apply", current.id];
        applier.running = true;
    }

    // Free RAM: exit a minute after the carousel closes; rice-themes relaunches it.
    Timer { interval: 60000; running: !root.opened; onTriggered: Qt.quit() }

    IpcHandler {
        target: "themes"
        function toggle(): void { if (root.opened) root.close(); else root.open(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }

    Process {
        id: lister
        command: ["python3", root.backend, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text);
                    root.presets = d.presets; root.active = d.active || "";
                    var i = Math.max(0, d.presets.findIndex(p => p.id === root.active));
                    root.selected = i;
                    root.position = i;
                } catch (e) { root.message = "Не удалось загрузить темы"; root.failed = true; }
            }
        }
    }
    Process {
        id: walls
        command: ["python3", Quickshell.env("HOME") + "/.local/share/wallpaper-picker/backend.py", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { var d = JSON.parse(text); var it = d.items.find(i => i.path === d.current); root.wallpaper = it && it.thumb ? "file://" + it.thumb : ""; } catch (e) {}
            }
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice-theme/deck.json"
        preload: true; printErrors: false
        onLoaded: { try { root.apps = JSON.parse(text()).apps || []; } catch (e) { root.apps = []; } }
    }
    Process {
        id: applier
        stdout: StdioCollector {
            onStreamFinished: {
                root.applying = false;
                try {
                    var d = JSON.parse(text);
                    if (d.error) { root.failed = true; root.message = d.error; return; }
                    root.active = d.active; root.failed = false; root.message = "Готово";
                    closeTimer.restart();
                } catch (e) { root.failed = true; root.message = "Ошибка: " + e; }
            }
        }
    }
    Timer { id: closeTimer; interval: 650; onTriggered: root.opened = false }

    PanelWindow {
        id: window
        visible: root.opened
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) || Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-themes"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            readonly property real cardW: Math.min(760, width * .42)
            readonly property real cardH: cardW * 9 / 16
            readonly property real spacing: cardW * .86
            readonly property real centerY: height * .43

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Left: case Qt.Key_H: case Qt.Key_A: root.move(-1); break;
                case Qt.Key_Right: case Qt.Key_L: case Qt.Key_D: root.move(1); break;
                case Qt.Key_Home: root.jump(0); break;
                case Qt.Key_End: root.jump(root.presets.length - 1); break;
                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: root.apply(); break;
                case Qt.Key_Escape: root.close(); break;
                default:
                    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) root.jump(event.key - Qt.Key_1);
                    else return;
                }
                event.accepted = true;
            }

            // Dim + fade in; Hyprland blurs this layer (layerrule rice-themes).
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: root.opened ? .42 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
                onWheel: wheel => { root.move(wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0 ? -1 : 1); }
            }

            // Filmstrip
            Repeater {
                model: root.presets
                Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property real d: index - root.position
                    readonly property real ad: Math.abs(d)
                    readonly property bool isSelected: index === root.selected
                    visible: ad < 3.4
                    width: stage.cardW; height: stage.cardH
                    x: stage.width / 2 + d * stage.spacing - width / 2
                    y: stage.centerY - height / 2 + Math.min(ad, 3) * 22
                    z: 100 - ad * 10
                    scale: Math.max(.52, 1 - ad * .17)
                    opacity: Math.max(.28, 1 - ad * .26)

                    // layered soft shadow
                    Repeater {
                        model: [26, 16, 8]
                        Rectangle {
                            required property int modelData
                            x: -modelData / 2; y: 12 - modelData / 2
                            width: slot.width + modelData; height: slot.height + modelData
                            radius: 18 + modelData / 2
                            color: "#000000"; opacity: .12
                        }
                    }
                    ThemeCard {
                        anchors.fill: parent
                        preset: slot.modelData
                        wallpaper: root.wallpaper
                        apps: root.apps
                    }
                    // selection ring in the theme's own accent
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -4
                        radius: 22; color: "transparent"
                        border.width: slot.isSelected ? 3 : 1
                        border.color: slot.isSelected ? slot.modelData.colors.accent : Qt.alpha("#ffffff", .14)
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }
                    Rectangle {
                        visible: slot.modelData.id === root.active
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 14
                        anchors.topMargin: parent.height * .14
                        width: nowLabel.implicitWidth + 18; height: 24; radius: 12
                        color: Qt.alpha("#000000", .55)
                        Text { id: nowLabel; anchors.centerIn: parent; text: "сейчас"; font.pixelSize: 12; font.weight: Font.Medium; color: "#ffffff" }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: slot.isSelected ? root.apply() : root.jump(slot.index)
                    }
                }
            }

            // Caption
            Column {
                id: caption
                anchors.horizontalCenter: parent.horizontalCenter
                y: stage.centerY + stage.cardH / 2 + 46
                spacing: 10
                visible: !!root.current
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.current ? root.current.name : ""
                    font.pixelSize: 34; font.weight: Font.DemiBold
                    color: "#ffffff"
                    style: Text.Raised; styleColor: "#40000000"
                }
                // dots
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 7
                    topPadding: 10
                    Repeater {
                        model: root.presets
                        Rectangle {
                            required property var modelData
                            required property int index
                            width: index === root.selected ? 22 : 7; height: 7; radius: 3.5
                            color: index === root.selected ? modelData.colors.accent : Qt.alpha("#ffffff", .35)
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.jump(parent.index) }
                        }
                    }
                }
            }

            // Footer hint / status
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 40
                visible: root.message.length > 0
                width: hint.implicitWidth + 36; height: 38; radius: 19
                color: root.failed ? Qt.alpha("#e05561", .3) : Qt.alpha("#000000", .4)
                border.width: 1; border.color: Qt.alpha("#ffffff", .1)
                Text {
                    id: hint
                    anchors.centerIn: parent
                    text: root.message
                    font.pixelSize: 13; color: "#f0ffffff"
                }
            }
        }
    }
}
