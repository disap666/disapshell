pragma ComponentBehavior: Bound
import QtQuick

// Mini monitor: click an edge to dock the bar there.
Rectangle {
    id: root
    property string current: "top"
    signal chosen(string edge)
    width: 150; height: 92; radius: 8
    color: Tokens.well
    border.width: 1; border.color: Tokens.line
    readonly property var edges: [
        { id: "top",    label: "Сверху" },
        { id: "bottom", label: "Снизу" },
        { id: "left",   label: "Слева" },
        { id: "right",  label: "Справа" }
    ]
    // fake window in the middle
    Rectangle { anchors.centerIn: parent; width: parent.width * .42; height: parent.height * .4; radius: 4; color: Tokens.alpha(Tokens.text, .06); border.width: 1; border.color: Tokens.alpha(Tokens.text, .1) }
    Repeater {
        model: root.edges
        Item {
            id: zone
            required property var modelData
            readonly property bool vertical: modelData.id === "left" || modelData.id === "right"
            readonly property bool on: root.current === modelData.id
            x: modelData.id === "right" ? root.width - width : 0
            y: modelData.id === "bottom" ? root.height - height : 0
            width: vertical ? 26 : root.width
            height: vertical ? root.height : 24
            Rectangle {
                anchors.centerIn: parent
                width: zone.vertical ? 7 : parent.width - 34
                height: zone.vertical ? parent.height - 30 : 7
                radius: 4
                color: zone.on ? Tokens.accent : zoneArea.containsMouse ? Tokens.alpha(Tokens.accent, .5) : Tokens.alpha(Tokens.text, .14)
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea { id: zoneArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chosen(zone.modelData.id) }
        }
    }
    Text {
        anchors.centerIn: parent
        text: (root.edges.find(e => e.id === root.current) || root.edges[0]).label
        font.family: Tokens.font; font.pixelSize: Tokens.px(11); font.weight: Font.Medium; color: Tokens.text2
    }
}
