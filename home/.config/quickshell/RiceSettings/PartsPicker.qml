pragma ComponentBehavior: Bound
import QtQuick

// Visual tiles: whole / 2 / 3 / 4 capsules. Click to pick.
Row {
    id: root
    property int current: 1
    property var labels: ["Цельная", "2 части", "3 части", "4 части"]
    property bool dock: false
    property color accentColor: Tokens.accent
    signal chosen(int parts)
    spacing: 8
    Repeater {
        model: 4
        Rectangle {
            id: tile
            required property int index
            readonly property bool on: root.current === index + 1
            width: 82; height: 58; radius: Tokens.controlRadius + 2
            color: on ? Tokens.alpha(Tokens.accent, .14) : tileArea.containsMouse ? Tokens.controlHover : Tokens.control
            border.width: on ? 2 : 1
            border.color: on ? Tokens.accent : Tokens.alpha(Tokens.text, .08)
            scale: tileArea.pressed ? .96 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            Behavior on color { ColorAnimation { duration: 120 } }
            MiniBar {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 12
                width: 64; height: root.dock ? 13 : 9
                parts: tile.index + 1; radius: 5; gap: 4; dots: !root.dock || tile.index === 0; dock: root.dock
                background: tile.on ? Tokens.accent : Tokens.text3; alpha: tile.on ? .9 : .55
                accent: tile.on ? Tokens.onAccent : Tokens.surface
                borderWidth: 0
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 7
                text: root.labels[tile.index]
                font.family: Tokens.font; font.pixelSize: Tokens.px(11); font.weight: tile.on ? Font.Bold : Font.Normal
                color: tile.on ? Tokens.text : Tokens.text2
            }
            MouseArea { id: tileArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chosen(tile.index + 1) }
        }
    }
}
