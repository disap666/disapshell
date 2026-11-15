pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Inset group: optional caption, rounded card, hairlines between rows.
ColumnLayout {
    id: root
    property string title: ""
    default property alias rows: body.data
    Layout.fillWidth: true
    spacing: 6
    Text {
        visible: root.title.length > 0
        Layout.leftMargin: 4
        text: root.title
        font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.Medium
        color: Tokens.text2
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight
        radius: Tokens.radius
        color: Tokens.card
        border.width: 1; border.color: Tokens.alpha(Tokens.text, .05)
        ColumnLayout { id: body; width: parent.width; spacing: 0 }
    }
}
