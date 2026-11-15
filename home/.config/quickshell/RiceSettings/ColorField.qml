pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as C

// Colour chip button: swatch + hex. Click -> ColorPopover right under it.
Rectangle {
    id: root
    property string value: ""
    property string title: ""
    property string fallback: "#c6acee"
    readonly property bool valid: /^#[0-9a-fA-F]{6}$/.test(value)
    signal edited(string hex)

    implicitWidth: 128; implicitHeight: 32
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    radius: Tokens.controlRadius
    color: area.containsMouse || popover.opened ? Tokens.controlHover : Tokens.control
    border.width: popover.opened ? 1 : 0; border.color: Tokens.accent
    Behavior on color { ColorAnimation { duration: 100 } }

    Rectangle {
        id: chip
        x: 4; anchors.verticalCenter: parent.verticalCenter
        width: 24; height: 24; radius: Math.max(4, Tokens.controlRadius - 3)
        color: root.valid ? root.value : "transparent"
        border.width: 1; border.color: Tokens.alpha(Tokens.text, .25)
        Behavior on color { ColorAnimation { duration: 80 } }
        // empty / invalid: diagonal slash
        Rectangle { visible: !root.valid; anchors.centerIn: parent; width: parent.width * 1.2; height: 2; rotation: -45; color: Tokens.danger }
    }
    Text {
        anchors.left: chip.right; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
        text: root.valid ? root.value.toUpperCase() : (root.value || "-")
        font.family: "JetBrains Mono"; font.pixelSize: Tokens.px(12); color: root.valid ? Tokens.text : Tokens.danger
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
        text: "▾"; font.pixelSize: Tokens.px(11); color: Tokens.text3
        rotation: popover.opened ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: 140 } }
    }
    MouseArea {
        id: area
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: { popover.title = root.title; popover.load(root.valid ? root.value : root.fallback); popover.open(); }
    }
    ColorPopover {
        id: popover
        x: root.width - width; y: root.height + 6
        onPicked: h => root.edited(h)
    }
}
