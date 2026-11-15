pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// One line in a Group: label on the left, control on the right.
Item {
    id: root
    property string label: ""
    property string icon: ""
    property bool divider: !!parent && parent.children.length > 0 && parent.children[0] !== root && firstVisibleBefore()
    default property alias control: slot.data
    Layout.fillWidth: true
    implicitHeight: Math.max(48, texts.implicitHeight + 20, slot.implicitHeight + 16)
    function firstVisibleBefore() {
        var kids = parent.children;
        for (var i = 0; i < kids.length && kids[i] !== root; i++) if (kids[i].visible) return true;
        return false;
    }
    Rectangle { visible: root.divider; x: 14; width: parent.width - 14; height: 1; color: Tokens.line }
    IconImage {
        id: glyph
        visible: root.icon.length > 0
        anchors.left: parent.left; anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 24
        source: root.icon ? Quickshell.iconPath(root.icon, "application-x-executable") : ""
    }
    ColumnLayout {
        id: texts
        anchors.left: glyph.visible ? glyph.right : parent.left; anchors.leftMargin: glyph.visible ? 12 : 14
        anchors.right: slot.left; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text { Layout.fillWidth: true; text: root.label; wrapMode: Text.Wrap; font.family: Tokens.font; font.pixelSize: Tokens.px(13); color: Tokens.text }
    }
    Row {
        id: slot
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
    }
}
