pragma ComponentBehavior: Bound
import QtQuick

// Tiny rendering of a bar/dock split into N capsules. Used by tiles and presets.
Item {
    id: bar
    property int parts: 3
    property real radius: 6
    property real gap: 4
    property color background: "#201a2d"
    property color highlight: "#493957"
    property bool gradient: false
    property real alpha: .85
    property color border: "#ffffff"
    property real borderAlpha: .3
    property real borderWidth: 1
    property color accent: "#c6acee"
    property bool vertical: false
    property bool dots: true
    property bool dock: false
    Repeater {
        model: Math.max(1, bar.parts)
        Rectangle {
            required property int index
            readonly property real len: ((bar.vertical ? bar.height : bar.width) - bar.gap * (bar.parts - 1)) / bar.parts
            x: bar.vertical ? 0 : index * (len + bar.gap)
            y: bar.vertical ? index * (len + bar.gap) : 0
            width: bar.vertical ? bar.width : Math.max(2, len)
            height: bar.vertical ? Math.max(2, len) : bar.height
            radius: Math.min(width / 2, height / 2, bar.radius)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(bar.gradient ? bar.highlight : bar.background, bar.alpha) }
                GradientStop { position: 1; color: Qt.alpha(bar.background, bar.alpha) }
            }
            border.width: bar.borderWidth > 0 ? Math.min(1.5, bar.borderWidth) : 0
            border.color: Qt.alpha(bar.border, bar.borderAlpha)
            Row {
                anchors.centerIn: parent; spacing: bar.dock ? 3 : 2
                visible: bar.dots && !bar.vertical
                Repeater {
                    model: bar.dock ? 3 : 2
                    Rectangle {
                        width: bar.dock ? Math.max(3, bar.height * .42) : 4
                        height: bar.dock ? width : 2
                        radius: bar.dock ? width * .3 : 1
                        color: bar.accent; opacity: .9
                    }
                }
            }
        }
    }
}
