import QtQuick
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice

// The classic player's glass: same gradient, rim and top highlight.
Rectangle {
    id: plate
    gradient: Gradient {
        GradientStop { position: 0; color: Rice.Theme.color("#555c506e") }
        GradientStop { position: 0.45; color: Rice.Theme.color("#402a2438") }
        GradientStop { position: 1; color: Rice.Theme.color("#70201c2a") }
    }
    border.width: 1; border.color: Rice.Theme.color("#60e4d4f6")
    Rectangle { anchors.fill: parent; anchors.margins: 2; radius: Math.max(0, plate.radius - 2); color: "transparent"; border.width: 1; border.color: Rice.Theme.color("#16ffffff") }
    Rectangle { x: plate.radius; y: 1; width: Math.max(0, parent.width - plate.radius * 2); height: 1; color: Rice.Theme.color("#65ffffff") }
}
