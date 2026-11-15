import QtQuick
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice

// Same button as the classic player's MusicButton, shared by the other looks.
Rectangle {
    id: button
    property string glyph: "play"
    property bool available: true
    property bool highlighted: false
    property int glyphSize: 20
    signal clicked()
    width: 44; height: 38; radius: 13
    color: hit.pressed ? Rice.Theme.color("#35ffffff") : hit.containsMouse ? Rice.Theme.color("#18ffffff") : "transparent"
    opacity: available ? 1 : 0.3
    Behavior on color { ColorAnimation { duration: 120 } }
    PlayerGlyph { anchors.centerIn: parent; width: button.glyphSize; height: button.glyphSize; kind: button.glyph; col: button.highlighted ? Rice.Theme.color("#d9bcff") : Rice.Theme.color("#f2edf8") }
    MouseArea { id: hit; anchors.fill: parent; enabled: button.available; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
}
