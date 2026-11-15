pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool opened: false
    property int selected: 0
    property int pending: -1
    property real progress: 1
    readonly property int confirmSeconds: 10
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property string home: Quickshell.env("HOME")

    readonly property var pal: Rice.Theme.palette.colors || ({})
    readonly property color fg: pal.foreground || "#eee7fa"
    readonly property color bg: pal.background || "#201a2d"
    readonly property color surface: pal.surface || "#4d3b63"
    readonly property color accent: pal.accent || "#d8b9ff"
    readonly property color edge: pal.border || "#d8c0f2"
    readonly property real glass: Rice.Theme.glassOpacity
    readonly property real ts: Rice.Theme.textScale

    readonly property int cell: 88
    readonly property int gap: 14
    readonly property int pad: 16

    readonly property var actions: [
        { label: "Блокировка", icon: "\u{F033E}", tint: accent, confirm: false,
          command: [home + "/.local/bin/rice-lock"] },
        { label: "Сон", icon: "\u{F04B2}", tint: accent, confirm: false,
          command: ["sh", "-c", home + "/.local/bin/rice-lock & sleep 1; systemctl suspend"] },
        { label: "Выход", icon: "\u{F0343}", tint: accent, confirm: true,
          command: ["hyprctl", "dispatch", "exit"] },
        { label: "Перезагрузка", icon: "\u{F0709}", tint: "#f2d49b", confirm: true,
          command: ["systemctl", "reboot"] },
        { label: "Выключение", icon: "\u{F0425}", tint: "#f28b99", confirm: true,
          command: ["systemctl", "poweroff"] }
    ]
    readonly property var current: actions[pending >= 0 ? pending : selected]

    function open() {
        cancel(); selected = 0; opened = true;
        Qt.callLater(function() { keys.forceActiveFocus(); });
    }
    function close() { cancel(); opened = false; }
    function run(index) {
        Quickshell.execDetached(actions[index].command);
        close();
    }
    function choose(index) {
        selected = index;
        if (!actions[index].confirm) { run(index); return; }
        pending = index; countdown.restart();
    }
    function cancel() { countdown.stop(); pending = -1; progress = 1; }
    function step(delta) { selected = (selected + delta + actions.length) % actions.length; }

    NumberAnimation {
        id: countdown
        target: root; property: "progress"
        from: 1; to: 0; duration: root.confirmSeconds * 1000
        onFinished: if (root.pending >= 0) root.run(root.pending)
    }

    IpcHandler {
        target: "power"
        function toggle(): void { if (root.opened) root.close(); else root.open(); }
        function close(): void { root.close(); }
    }

    PanelWindow {
        id: window
        visible: root.opened || scene.opacity > 0
        screen: Quickshell.screens.find(function(s) { return Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name; }) || Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-power"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        HyprlandFocusGrab { windows: [window]; active: root.opened; onCleared: root.close() }

        Item {
            id: scene
            anchors.fill: parent
            opacity: root.opened ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(root.bg, 0.5)
                MouseArea { anchors.fill: parent; onClicked: root.close() }
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: function(event) {
                    var k = event.key;
                    if (k === Qt.Key_Escape) { if (root.pending >= 0) root.cancel(); else root.close(); }
                    else if (root.pending >= 0) {
                        if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Y) root.run(root.pending);
                        else if (k === Qt.Key_N || k === Qt.Key_Backspace) root.cancel();
                        else return;
                    }
                    else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab) root.step(-1);
                    else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab) root.step(1);
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.choose(root.selected);
                    else if (k >= Qt.Key_1 && k < Qt.Key_1 + root.actions.length) root.choose(k - Qt.Key_1);
                    else return;
                    event.accepted = true;
                }
            }

            Rectangle {
                id: capsule
                anchors.centerIn: parent
                width: root.pending >= 0 ? confirm.implicitWidth + root.pad + 26 : tiles.implicitWidth + 2 * root.pad
                height: root.cell + 2 * root.pad
                radius: height / 2
                scale: root.opened ? 1 : 0.94
                clip: true
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.alpha(root.surface, 0.58 * root.glass) }
                    GradientStop { position: 1; color: Qt.alpha(root.bg, 0.72 * root.glass) }
                }
                border.width: 1; border.color: Qt.alpha(root.edge, 0.34)
                Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                MouseArea { anchors.fill: parent }

                Rectangle {
                    anchors.fill: parent; anchors.margins: 1; radius: height / 2
                    color: "transparent"; border.width: 1; border.color: Qt.alpha("#ffffff", 0.07)
                }

                Item {
                    id: tiles
                    anchors.centerIn: parent
                    implicitWidth: root.actions.length * root.cell + (root.actions.length - 1) * root.gap
                    width: implicitWidth; height: root.cell
                    opacity: root.pending < 0 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Rectangle {
                        x: root.selected * (root.cell + root.gap)
                        width: root.cell; height: root.cell; radius: root.cell / 2
                        color: Qt.alpha(root.actions[root.selected].tint, 0.16)
                        border.width: 1.5; border.color: Qt.alpha(root.actions[root.selected].tint, 0.85)
                        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }

                    Row {
                        spacing: root.gap
                        Repeater {
                            model: root.actions
                            delegate: Item {
                                id: tile
                                required property var modelData
                                required property int index
                                readonly property bool active: root.selected === index
                                property real rise: root.opened ? 0 : 14
                                width: root.cell; height: root.cell
                                Behavior on rise {
                                    SequentialAnimation {
                                        PauseAnimation { duration: tile.index * 30 }
                                        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent; radius: width / 2
                                    color: Qt.alpha(root.fg, 0.05)
                                    border.width: 1; border.color: Qt.alpha(root.fg, 0.1)
                                    opacity: tile.active ? 0 : 1
                                    Behavior on opacity { NumberAnimation { duration: 160 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: tile.rise
                                    opacity: 1 - tile.rise / 14
                                    text: tile.modelData.icon
                                    font.family: root.iconFont; font.pixelSize: 32 * root.ts
                                    color: tile.active ? tile.modelData.tint : Qt.alpha(root.fg, 0.8)
                                    scale: area.pressed ? 0.9 : (tile.active ? 1.12 : 1)
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                                MouseArea {
                                    id: area
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onPositionChanged: root.selected = tile.index
                                    onClicked: root.choose(tile.index)
                                }
                            }
                        }
                    }
                }

                Row {
                    id: confirm
                    x: root.pad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    opacity: root.pending >= 0 ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Item {
                        width: root.cell; height: root.cell
                        Rectangle {
                            anchors.fill: parent; anchors.margins: 4; radius: width / 2
                            color: Qt.alpha(root.current.tint, 0.14)
                        }
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: Qt.alpha(root.fg, 0.12); strokeWidth: 3; fillColor: "transparent"
                                PathAngleArc { centerX: root.cell / 2; centerY: root.cell / 2; radiusX: root.cell / 2 - 2; radiusY: root.cell / 2 - 2; startAngle: 0; sweepAngle: 360 }
                            }
                            ShapePath {
                                strokeColor: root.current.tint; strokeWidth: 3; fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                PathAngleArc { centerX: root.cell / 2; centerY: root.cell / 2; radiusX: root.cell / 2 - 2; radiusY: root.cell / 2 - 2; startAngle: -90; sweepAngle: 360 * root.progress }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: Math.ceil(root.progress * root.confirmSeconds)
                            color: root.current.tint
                            font.family: Rice.Theme.fontFamily; font.pixelSize: 28 * root.ts; font.weight: Font.DemiBold
                        }
                    }
                    Item { width: 8; height: 1 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.current.label
                        color: root.fg
                        font.family: Rice.Theme.fontFamily; font.pixelSize: 20 * root.ts; font.weight: Font.DemiBold
                    }
                    Item { width: 22; height: 1 }
                    Repeater {
                        model: [{ text: "Отмена", primary: false }, { text: "Подтвердить", primary: true }]
                        delegate: Rectangle {
                            id: button
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: caption.implicitWidth + 40; height: 46; radius: 23
                            color: modelData.primary ? Qt.alpha(root.current.tint, press.containsMouse ? 0.36 : 0.22)
                                                     : Qt.alpha(root.fg, press.containsMouse ? 0.14 : 0.06)
                            border.width: 1
                            border.color: modelData.primary ? Qt.alpha(root.current.tint, 0.8) : Qt.alpha(root.fg, 0.14)
                            scale: press.pressed ? 0.96 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Text {
                                id: caption
                                anchors.centerIn: parent
                                text: button.modelData.text
                                color: root.fg
                                font.family: Rice.Theme.fontFamily; font.pixelSize: 13 * root.ts; font.weight: Font.Medium
                            }
                            MouseArea {
                                id: press
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: button.modelData.primary ? root.run(root.pending) : root.cancel()
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: capsule.bottom; anchors.topMargin: 22
                text: root.actions[root.selected].label
                opacity: root.pending < 0 ? 1 : 0
                color: root.fg
                font.family: Rice.Theme.fontFamily; font.pixelSize: 20 * root.ts; font.weight: Font.DemiBold
                style: Text.Raised; styleColor: "#40000000"
                Behavior on opacity { NumberAnimation { duration: 140 } }
            }
        }
    }
}
