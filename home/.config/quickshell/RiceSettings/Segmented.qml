pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Segmented control for in-page tabs.
Rectangle {
    id: root
    property var model: []
    property int current: 0
    signal activated(int index)
    implicitHeight: 32
    implicitWidth: row.implicitWidth + 6
    radius: Tokens.radius
    color: Tokens.well
    Rectangle {
        id: thumb
        readonly property Item target: rep.count > root.current ? rep.itemAt(root.current) : null
        x: target ? target.x + 3 : 3; y: 3
        width: target ? target.width : 0; height: parent.height - 6
        radius: Math.max(0, Tokens.radius - 2); color: Tokens.cardStrong
        border.width: 1; border.color: Tokens.line
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    Row {
        id: row
        x: 3; y: 3; height: parent.height - 6
        Repeater {
            id: rep
            model: root.model
            Item {
                id: seg
                required property var modelData
                required property int index
                width: label.implicitWidth + 28; height: row.height
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: seg.modelData
                    font.family: Tokens.font; font.pixelSize: Tokens.px(12)
                    font.weight: root.current === seg.index ? Font.Medium : Font.Normal
                    color: root.current === seg.index ? Tokens.text : mouse.containsMouse ? Tokens.text : Tokens.text2
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.activated(seg.index)
                }
            }
        }
    }
}
